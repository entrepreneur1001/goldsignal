const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const {
  fetchAndUpdateGlobalPrices,
  fetchAndUpdateLocalEgp,
  loadPriceContextFromFirestore,
} = require('./price_fetchers');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

const OUNCE_TO_GRAM = 31.1034768;

function globalPricePerGram(rates, metal, karat, currency) {
  if (!rates) return null;

  const usdGold = rates.USDXAU;
  const usdSilver = rates.USDXAG;

  if (metal === 'gold') {
    if (usdGold == null) return null;
    let ounceInCurrency = currency === 'USD' ? usdGold : usdGold * rates[currency];
    if (ounceInCurrency == null) return null;
    const purity = (parseInt(karat, 10) || 24) / 24;
    return (ounceInCurrency / OUNCE_TO_GRAM) * purity;
  }

  if (usdSilver == null) return null;
  const ounceInCurrency =
    currency === 'USD' ? usdSilver : usdSilver * rates[currency];
  if (ounceInCurrency == null) return null;
  return ounceInCurrency / OUNCE_TO_GRAM;
}

function localPricePerGram(localDoc, metal, karat, side) {
  if (!localDoc) return null;
  const map = metal === 'gold' ? localDoc.gold : localDoc.silver;
  if (!map || !map[karat]) return null;
  const row = map[karat];
  if (side === 'buy' && row.buyPerGram != null) return row.buyPerGram;
  return row.sellPerGram ?? row.buyPerGram ?? null;
}

function changePercentFrom(current, baseline) {
  if (current == null || baseline == null || baseline === 0) return null;
  return ((current - baseline) / baseline) * 100;
}

function isTriggered(alert, current) {
  if (current == null || alert.targetValue == null) return false;

  if (alert.type === 'percentChange') {
    const change = changePercentFrom(current, alert.baselinePrice);
    if (change == null) return false;
    if (alert.condition === 'below') return change <= -alert.targetValue;
    return change >= alert.targetValue;
  }

  if (alert.condition === 'below') return current <= alert.targetValue;
  return current >= alert.targetValue;
}

function alertLabel(alert) {
  const metal = alert.metal === 'gold' ? 'Gold' : 'Silver';
  const karat = alert.metal === 'gold' ? `${alert.karat}K` : alert.karat;
  const side =
    alert.currency === 'EGP' && alert.side ? ` (${alert.side})` : '';

  if (alert.type === 'percentChange') {
    const dir = alert.condition === 'below' ? 'down' : 'up';
    return `${metal} ${karat}${side} ${dir} ${alert.targetValue}%`;
  }

  const cond = alert.condition === 'below' ? 'below' : 'above';
  return `${metal} ${karat}${side} ${cond} ${alert.targetValue} ${alert.currency}/g`;
}

function triggerMessage(alert, current) {
  if (alert.type === 'percentChange') {
    const change = changePercentFrom(current, alert.baselinePrice) ?? 0;
    const sign = change >= 0 ? '+' : '';
    return `${alertLabel(alert)} — now ${sign}${change.toFixed(2)}% (${current.toFixed(2)} ${alert.currency}/g)`;
  }
  return `${alertLabel(alert)} — now ${current.toFixed(2)} ${alert.currency}/g`;
}

function resolvePrice(alert, ctx) {
  if (alert.currency === 'EGP') {
    return localPricePerGram(
      ctx.localEgp,
      alert.metal,
      alert.karat,
      alert.side || 'sell',
    );
  }
  return globalPricePerGram(
    ctx.globalRates,
    alert.metal,
    alert.karat,
    alert.currency,
  );
}

async function sendAlertPush(fcmToken, title, body, alertId) {
  try {
    await messaging.send({
      token: fcmToken,
      notification: { title, body },
      data: {
        type: 'price_alert',
        alertId: String(alertId),
      },
      android: { priority: 'high' },
      apns: { payload: { aps: { sound: 'default' } } },
    });
    return true;
  } catch (err) {
    if (
      err.code === 'messaging/registration-token-not-registered' ||
      err.code === 'messaging/invalid-registration-token'
    ) {
      return false;
    }
    throw err;
  }
}

async function refreshPrices() {
  const [globalResult, localResult] = await Promise.allSettled([
    fetchAndUpdateGlobalPrices(db),
    fetchAndUpdateLocalEgp(db),
  ]);

  if (globalResult.status === 'fulfilled') {
    logger.info('Global prices updated from server fetch');
  } else {
    logger.warn('Global price fetch failed', globalResult.reason);
  }

  if (localResult.status === 'fulfilled' && localResult.value) {
    logger.info('EGP local prices updated from iSagha');
  } else if (localResult.status === 'rejected') {
    logger.warn('EGP local price fetch failed', localResult.reason);
  }

  const ctx = await loadPriceContextFromFirestore(db);
  return {
    globalRates: globalResult.status === 'fulfilled' ? globalResult.value : ctx.globalRates,
    localEgp: localResult.status === 'fulfilled' && localResult.value
      ? localResult.value
      : ctx.localEgp,
  };
}

async function processDueReactivations(ctx) {
  const now = new Date().toISOString();
  const snap = await db
    .collectionGroup('alerts')
    .where('isActive', '==', false)
    .where('reactivateAt', '<=', now)
    .get();

  if (snap.empty) return 0;

  let reactivated = 0;
  for (const alertDoc of snap.docs) {
    const alert = alertDoc.data();
    const current = resolvePrice(alert, ctx);
    const updates = {
      isActive: true,
      triggeredAt: admin.firestore.FieldValue.delete(),
      triggeredPrice: admin.firestore.FieldValue.delete(),
      reactivateAt: admin.firestore.FieldValue.delete(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (alert.type === 'percentChange' && current != null) {
      updates.baselinePrice = current;
    }
    await alertDoc.ref.update(updates);
    reactivated += 1;
  }

  return reactivated;
}

exports.checkPriceAlerts = onSchedule(
  {
    schedule: 'every 60 minutes',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '256MiB',
    timeoutSeconds: 120,
    maxInstances: 1,
  },
  async () => {
    const ctx = await refreshPrices();

    const reactivated = await processDueReactivations(ctx);
    if (reactivated > 0) {
      logger.info(`Reactivated ${reactivated} snoozed alerts`);
    }

    if (!ctx.globalRates && !ctx.localEgp) {
      logger.warn('No price data available for alert check');
      return;
    }

    const alertsSnap = await db
      .collectionGroup('alerts')
      .where('isActive', '==', true)
      .get();

    if (alertsSnap.empty) {
      logger.info('No active alerts');
      return;
    }

    const tokenCache = new Map();
    let triggered = 0;

    for (const alertDoc of alertsSnap.docs) {
      const alert = alertDoc.data();
      const uid = alertDoc.ref.parent.parent?.id;
      if (!uid) continue;

      const current = resolvePrice(alert, ctx);
      if (!isTriggered(alert, current)) {
        continue;
      }

      const message = triggerMessage(alert, current);

      const triggeredAt = new Date();
      const updates = {
        isActive: false,
        triggeredAt: triggeredAt.toISOString(),
        triggeredPrice: current,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      };
      if (alert.repeatAfterHours != null && alert.repeatAfterHours > 0) {
        updates.reactivateAt = new Date(
          triggeredAt.getTime() + alert.repeatAfterHours * 60 * 60 * 1000,
        ).toISOString();
      }
      await alertDoc.ref.update(updates);

      let fcmToken = tokenCache.get(uid);
      if (fcmToken === undefined) {
        const userSnap = await db.collection('users').doc(uid).get();
        fcmToken = userSnap.exists ? userSnap.data()?.fcmToken ?? null : null;
        tokenCache.set(uid, fcmToken);
      }

      if (fcmToken) {
        const sent = await sendAlertPush(
          fcmToken,
          'GoldSignal price alert',
          message,
          alert.id || alertDoc.id,
        );
        if (!sent) {
          await db.collection('users').doc(uid).set(
            { fcmToken: admin.firestore.FieldValue.delete() },
            { merge: true },
          );
          tokenCache.set(uid, null);
        }
      }

      triggered += 1;
      logger.info(`Triggered alert ${alertDoc.id} for user ${uid}`);
    }

    logger.info(`Alert check complete: ${triggered} triggered`);
  },
);
