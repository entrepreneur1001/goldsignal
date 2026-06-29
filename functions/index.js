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

function resolveRolling24hPercent(alert, ctx) {
  if (alert.currency === 'EGP') {
    const map =
      alert.metal === 'gold' ? ctx.localEgp?.gold : ctx.localEgp?.silver;
    const row = map?.[alert.karat];
    return row?.changePercent ?? null;
  }

  if (!ctx.globalRates || !ctx.prevRates) return null;
  const current = globalPricePerGram(
    ctx.globalRates,
    alert.metal,
    alert.karat,
    alert.currency,
  );
  const previous = globalPricePerGram(
    ctx.prevRates,
    alert.metal,
    alert.karat,
    alert.currency,
  );
  return changePercentFrom(current, previous);
}

function isTriggered(alert, current, ctx) {
  if (alert.targetValue == null) return false;

  if (alert.type === 'percentChange24h') {
    const change = resolveRolling24hPercent(alert, ctx);
    if (change == null) return false;
    if (alert.condition === 'below') return change <= -alert.targetValue;
    return change >= alert.targetValue;
  }

  if (current == null) return false;

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

  if (alert.type === 'percentChange' || alert.type === 'percentChange24h') {
    const dir = alert.condition === 'below' ? 'down' : 'up';
    const window = alert.type === 'percentChange24h' ? ' (24h)' : '';
    return `${metal} ${karat}${side} ${dir} ${alert.targetValue}%${window}`;
  }

  const cond = alert.condition === 'below' ? 'below' : 'above';
  return `${metal} ${karat}${side} ${cond} ${alert.targetValue} ${alert.currency}/g`;
}

function triggerMessage(alert, current, ctx) {
  if (alert.type === 'percentChange24h') {
    const change = resolveRolling24hPercent(alert, ctx) ?? 0;
    const sign = change >= 0 ? '+' : '';
    const price =
      current != null
        ? ` (${current.toFixed(2)} ${alert.currency}/g)`
        : '';
    return `${alertLabel(alert)} — now ${sign}${change.toFixed(2)}%${price}`;
  }
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
    globalRates:
      globalResult.status === 'fulfilled' ? globalResult.value : ctx.globalRates,
    prevRates: ctx.prevRates,
    localEgp:
      localResult.status === 'fulfilled' && localResult.value
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
      if (!isTriggered(alert, current, ctx)) {
        continue;
      }

      const message = triggerMessage(alert, current, ctx);

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

// Keeps the shared price cache fresh. This is now the ONLY writer of the
// `prices/*` documents — clients read them but no longer write (Firestore
// rules deny client writes). Runs more often than the hourly alert check so
// the in-app data stays current.
exports.refreshPricesScheduled = onSchedule(
  {
    schedule: 'every 15 minutes',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '256MiB',
    timeoutSeconds: 120,
    maxInstances: 1,
  },
  async () => {
    const ctx = await refreshPrices();
    if (!ctx.globalRates && !ctx.localEgp) {
      logger.warn('Scheduled price refresh produced no data');
      return;
    }
    logger.info('Scheduled price refresh complete', {
      global: !!ctx.globalRates,
      local: !!ctx.localEgp,
    });
  },
);

// ---------------------------------------------------------------------------
// Daily price digest
// ---------------------------------------------------------------------------

function formatDigestNum(n) {
  return Number(n).toLocaleString('en-US', { maximumFractionDigits: 2 });
}

/// Per-gram gold & silver + 24h gold change for the user's currency.
function digestNumbers(ctx, currency) {
  if (currency === 'EGP' && ctx.localEgp) {
    const g = ctx.localEgp.gold && ctx.localEgp.gold['21'];
    const s = ctx.localEgp.silver && ctx.localEgp.silver['999'];
    return {
      goldPerGram: g ? g.sellPerGram : null,
      silverPerGram: s ? s.sellPerGram : null,
      goldPct: g && g.changePercent != null ? g.changePercent : null,
    };
  }
  const goldPerGram = globalPricePerGram(ctx.globalRates, 'gold', '24', currency);
  const silverPerGram = globalPricePerGram(ctx.globalRates, 'silver', '999', currency);
  const prevGold = globalPricePerGram(ctx.prevRates, 'gold', '24', currency);
  return {
    goldPerGram,
    silverPerGram,
    goldPct: changePercentFrom(goldPerGram, prevGold),
  };
}

function digestBody(nums, currency) {
  const parts = [];
  if (nums.goldPerGram != null) {
    let g = `Gold ${formatDigestNum(nums.goldPerGram)} ${currency}/g`;
    if (nums.goldPct != null) {
      const sign = nums.goldPct >= 0 ? '+' : '';
      g += ` (${sign}${nums.goldPct.toFixed(2)}% 24h)`;
    }
    parts.push(g);
  }
  if (nums.silverPerGram != null) {
    parts.push(`Silver ${formatDigestNum(nums.silverPerGram)} ${currency}/g`);
  }
  return parts.join(' · ');
}

/// Optional one-line AI summary. Returns null unless GROQ_API_KEY is configured
/// (set via `firebase functions:secrets` or env); failures fall back to null.
async function aiDigestLine(nums, currency) {
  const key = process.env.GROQ_API_KEY;
  if (!key) return null;
  try {
    const pct = nums.goldPct != null ? nums.goldPct.toFixed(2) : 'n/a';
    const prompt =
      `In one short, friendly sentence (max 20 words), summarize today's gold move ` +
      `for an investor. Gold ${nums.goldPerGram?.toFixed(2)} ${currency}/g, ` +
      `24h change ${pct}%. No disclaimers, no preamble.`;
    const res = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model: 'llama-3.3-70b-versatile',
        max_completion_tokens: 60,
        temperature: 0.7,
        messages: [{ role: 'user', content: prompt }],
      }),
    });
    if (!res.ok) return null;
    const data = await res.json();
    const text = data?.choices?.[0]?.message?.content?.trim();
    return text || null;
  } catch (err) {
    logger.warn('AI digest line failed', err);
    return null;
  }
}

async function sendDigestPush(token, title, body) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: { type: 'daily_digest' },
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

// Sends each subscribed user a daily digest at their chosen local time. Runs
// every 30 minutes and fires for users whose local time falls in the current
// slot, de-duplicated per local calendar day via `digest.lastSentYmd`.
exports.sendDailyDigest = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '256MiB',
    timeoutSeconds: 120,
    maxInstances: 1,
  },
  async () => {
    const ctx = await loadPriceContextFromFirestore(db);
    if (!ctx.globalRates && !ctx.localEgp) {
      logger.warn('Digest: no price data available');
      return;
    }

    const usersSnap = await db
      .collection('users')
      .where('digest.enabled', '==', true)
      .get();

    if (usersSnap.empty) {
      logger.info('Digest: no subscribers');
      return;
    }

    const now = Date.now();
    const pad = (n) => String(n).padStart(2, '0');
    let sent = 0;

    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data();
      const d = data.digest || {};
      const token = data.fcmToken;
      if (!token) continue;

      // Shift "now" into the user's local time using their stored offset.
      const offset = Number(d.utcOffsetMinutes) || 0;
      const local = new Date(now + offset * 60000);
      const localMinutes = local.getUTCHours() * 60 + local.getUTCMinutes();
      const target = (Number(d.hour) || 0) * 60 + (Number(d.minute) || 0);
      const diff = localMinutes - target;
      if (diff < 0 || diff >= 30) continue; // not in this 30-min slot

      const ymd =
        `${local.getUTCFullYear()}-${pad(local.getUTCMonth() + 1)}-` +
        `${pad(local.getUTCDate())}`;
      if (d.lastSentYmd === ymd) continue; // already sent today

      const currency = d.currency || 'USD';
      const nums = digestNumbers(ctx, currency);
      if (nums.goldPerGram == null) continue;

      let body = digestBody(nums, currency);
      const ai = await aiDigestLine(nums, currency);
      if (ai) body = `${ai}\n${body}`;

      const ok = await sendDigestPush(token, 'GoldSignal daily digest', body);
      if (ok) {
        await userDoc.ref.update({ 'digest.lastSentYmd': ymd });
        sent += 1;
      } else {
        await userDoc.ref.update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
      }
    }

    logger.info(`Digest sent to ${sent} user(s)`);
  },
);

// ---------------------------------------------------------------------------
// Re-engagement campaign
// ---------------------------------------------------------------------------

// Inactivity thresholds (days) at which a lapsed user becomes eligible. The
// largest tier whose threshold the user has crossed is recorded for analytics.
const REENGAGE_TIERS_DAYS = [3, 7, 14];
// Minimum gap between two re-engagement pushes to the same user.
const REENGAGE_COOLDOWN_DAYS = 7;
// 24h gold move (absolute %) that promotes a generic win-back into a market nudge.
const BIG_MOVE_PCT = 2;

const DAY_MS = 24 * 60 * 60 * 1000;

function reengageTier(inactivityDays) {
  let tier = 0;
  for (const t of REENGAGE_TIERS_DAYS) {
    if (inactivityDays >= t) tier = t;
  }
  return tier; // 0 == not yet lapsed
}

function reengageMessage(nums, currency) {
  const pct = nums.goldPct;
  if (pct != null && Math.abs(pct) >= BIG_MOVE_PCT) {
    const dir = pct >= 0 ? 'up' : 'down';
    const body =
      `Gold is ${dir} ${Math.abs(pct).toFixed(1)}% today` +
      (nums.goldPerGram != null
        ? ` at ${formatDigestNum(nums.goldPerGram)} ${currency}/g.`
        : '.') +
      ' Check the latest prices.';
    return { title: 'Gold is on the move', body };
  }
  return {
    title: 'We miss you',
    body: "See today's gold & silver prices and how your portfolio is doing.",
  };
}

async function sendReEngagePush(token, title, body) {
  try {
    await messaging.send({
      token,
      notification: { title, body },
      data: { type: 're_engagement' },
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

// Nudges lapsed users back. Runs daily, targets users inactive >= the smallest
// tier, respects a per-user cooldown, the `reengage.enabled` opt-out, and a
// `metadata/app.reengageEnabled` kill switch. De-duped per local calendar day.
exports.sendReEngagement = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '256MiB',
    timeoutSeconds: 300,
    maxInstances: 1,
  },
  async () => {
    const cfgSnap = await db.collection('metadata').doc('app').get();
    if (cfgSnap.exists && cfgSnap.data()?.reengageEnabled === false) {
      logger.info('Re-engagement disabled via metadata/app kill switch');
      return;
    }

    const ctx = await loadPriceContextFromFirestore(db);
    if (!ctx.globalRates && !ctx.localEgp) {
      logger.warn('Re-engagement: no price data available');
      return;
    }

    const now = Date.now();
    const minTier = REENGAGE_TIERS_DAYS[0];
    const cutoff = admin.firestore.Timestamp.fromDate(
      new Date(now - minTier * DAY_MS),
    );

    // Only users with a recorded activity signal older than the smallest tier
    // can be lapsed; users active more recently are excluded by the query.
    const usersSnap = await db
      .collection('users')
      .where('lastActiveAt', '<=', cutoff)
      .get();

    if (usersSnap.empty) {
      logger.info('Re-engagement: no lapsed users');
      return;
    }

    const pad = (n) => String(n).padStart(2, '0');
    let sent = 0;

    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data();
      const token = data.fcmToken;
      if (!token) continue;

      const reengage = data.reengage || {};
      if (reengage.enabled === false) continue; // opted out

      const cooldownPassed = (lastSentAt) => {
        if (!lastSentAt) return true;
        const ms =
          typeof lastSentAt.toDate === 'function'
            ? lastSentAt.toDate().getTime()
            : 0;
        return now - ms >= REENGAGE_COOLDOWN_DAYS * DAY_MS;
      };
      if (!cooldownPassed(reengage.lastSentAt)) continue;

      const lastActive = data.lastActiveAt?.toDate?.();
      if (!lastActive) continue;
      const inactivityDays = (now - lastActive.getTime()) / DAY_MS;
      const tier = reengageTier(inactivityDays);
      if (tier === 0) continue;

      const currency = data.digest?.currency || 'USD';
      const nums = digestNumbers(ctx, currency);
      const { title, body } = reengageMessage(nums, currency);

      const ok = await sendReEngagePush(token, title, body);
      if (!ok) {
        await userDoc.ref.update({
          fcmToken: admin.firestore.FieldValue.delete(),
        });
        continue;
      }

      const ymd = `${new Date(now).getUTCFullYear()}-${pad(
        new Date(now).getUTCMonth() + 1,
      )}-${pad(new Date(now).getUTCDate())}`;
      await userDoc.ref.set(
        {
          reengage: {
            lastSentAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSentYmd: ymd,
            lastTier: tier,
          },
        },
        { merge: true },
      );
      sent += 1;
    }

    logger.info(`Re-engagement sent to ${sent} user(s)`);
  },
);
