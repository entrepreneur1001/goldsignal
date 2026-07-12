const { onSchedule } = require('firebase-functions/v2/scheduler');
const { logger } = require('firebase-functions');
const admin = require('firebase-admin');
const {
  fetchAndUpdateGlobalPrices,
  fetchAndUpdateIntradayChart,
  fetchAndUpdateLocalEgp,
  fetchAndUpdateLocalInr,
  loadPriceContextFromFirestore,
} = require('./price_fetchers');
const {
  globalPricePerGram,
  changePercentFrom,
} = require('./price_helpers');

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

function userTokens(userData) {
  const tokens = new Set();
  if (userData?.fcmTokens && typeof userData.fcmTokens === 'object') {
    for (const token of Object.keys(userData.fcmTokens)) {
      if (token) tokens.add(token);
    }
  }
  if (userData?.fcmToken) tokens.add(userData.fcmToken);
  return tokens;
}

async function sendPushToUser(uid, userData, { title, body, data }) {
  const tokens = [...userTokens(userData)];
  if (tokens.length === 0) {
    return { sent: 0, transientErrors: 0, tokensTried: 0 };
  }

  const response = await messaging.sendEachForMulticast({
    tokens,
    notification: { title, body },
    data,
    android: { priority: 'high' },
    apns: { payload: { aps: { sound: 'default' } } },
  });

  const staleCodes = new Set([
    'messaging/registration-token-not-registered',
    'messaging/invalid-registration-token',
  ]);

  const stale = [];
  let sent = 0;
  let transientErrors = 0;

  response.responses.forEach((res, i) => {
    if (res.success) {
      sent += 1;
      return;
    }
    const code = res.error?.code;
    if (staleCodes.has(code)) {
      stale.push(tokens[i]);
    } else {
      logger.warn('FCM send failed', {
        uid,
        token: tokens[i],
        code,
        message: res.error?.message,
      });
      transientErrors += 1;
    }
  });

  if (stale.length > 0) {
    const updates = {};
    for (const token of stale) {
      updates[new admin.firestore.FieldPath('fcmTokens', token)] =
        admin.firestore.FieldValue.delete();
    }
    if (userData?.fcmToken && stale.includes(userData.fcmToken)) {
      updates.fcmToken = admin.firestore.FieldValue.delete();
    }
    await db.collection('users').doc(uid).update(updates);
  }

  return { sent, transientErrors, tokensTried: tokens.length };
}

function localPricePerGram(localDoc, metal, karat, side) {
  if (!localDoc) return null;
  const map = metal === 'gold' ? localDoc.gold : localDoc.silver;
  if (!map || !map[karat]) return null;
  const row = map[karat];
  if (side === 'buy' && row.buyPerGram != null) return row.buyPerGram;
  return row.sellPerGram ?? row.buyPerGram ?? null;
}

function isLocalCurrency(currency) {
  return currency === 'EGP' || currency === 'INR';
}

function localDocFor(currency, ctx) {
  if (currency === 'EGP') return ctx.localEgp;
  if (currency === 'INR') return ctx.localInr;
  return null;
}

function headlineGoldKarat(currency) {
  if (currency === 'EGP') return '21';
  if (currency === 'INR') return '22';
  return '24';
}

function resolveRolling24hPercent(alert, ctx) {
  if (isLocalCurrency(alert.currency)) {
    const local = localDocFor(alert.currency, ctx);
    const map =
      alert.metal === 'gold' ? local?.gold : local?.silver;
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
  if (!Number.isFinite(alert.targetValue)) return false;

  if (alert.type === 'percentChange24h') {
    const change = resolveRolling24hPercent(alert, ctx);
    if (change == null) return false;
    if (alert.condition === 'below') return change <= -alert.targetValue;
    return change >= alert.targetValue;
  }

  if (!Number.isFinite(current)) return false;

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
  if (isLocalCurrency(alert.currency)) {
    return localPricePerGram(
      localDocFor(alert.currency, ctx),
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

async function refreshPrices() {
  const [globalResult, chartResult, localEgpResult, localInrResult] =
    await Promise.allSettled([
      fetchAndUpdateGlobalPrices(db),
      fetchAndUpdateIntradayChart(db),
      fetchAndUpdateLocalEgp(db),
      fetchAndUpdateLocalInr(db),
    ]);

  if (globalResult.status === 'fulfilled') {
    logger.info('Global prices updated from server fetch');
  } else {
    logger.warn('Global price fetch failed', globalResult.reason);
  }

  if (chartResult.status === 'fulfilled') {
    logger.info('Intraday chart seed updated from goldprice.org GetData', chartResult.value);
  } else {
    logger.warn('Intraday chart seed failed', chartResult.reason);
  }

  if (localEgpResult.status === 'fulfilled' && localEgpResult.value) {
    if (localEgpResult.value.skippedWrite) {
      logger.info('EGP local prices unchanged — skipped Firestore write');
    } else {
      logger.info('EGP local prices updated from iSagha');
    }
  } else if (localEgpResult.status === 'rejected') {
    logger.warn('EGP local price fetch failed', localEgpResult.reason);
  }

  if (localInrResult.status === 'fulfilled' && localInrResult.value) {
    if (localInrResult.value.skippedWrite) {
      logger.info('INR local prices unchanged — skipped Firestore write');
    } else {
      logger.info('INR local prices updated from Goodreturns');
    }
  } else if (localInrResult.status === 'rejected') {
    logger.warn('INR local price fetch failed', localInrResult.reason);
  }

  const ctx = await loadPriceContextFromFirestore(db);
  return {
    globalRates:
      globalResult.status === 'fulfilled' ? globalResult.value : ctx.globalRates,
    prevRates: ctx.prevRates,
    localEgp:
      localEgpResult.status === 'fulfilled' && localEgpResult.value
        ? localEgpResult.value
        : ctx.localEgp,
    localInr:
      localInrResult.status === 'fulfilled' && localInrResult.value
        ? localInrResult.value
        : ctx.localInr,
  };
}

function utcYmd(date = new Date()) {
  const pad = (n) => String(n).padStart(2, '0');
  return `${date.getUTCFullYear()}-${pad(date.getUTCMonth() + 1)}-${pad(
    date.getUTCDate(),
  )}`;
}

/// Cached Groq one-liner from metadata/dailyInsight (at most one call/day).
async function loadCachedDailyInsightAiLine() {
  const doc = await db.collection('metadata').doc('dailyInsight').get();
  if (!doc.exists) return null;
  const data = doc.data();
  if (data?.ymd !== utcYmd()) return null;
  return data?.aiLine ?? null;
}

async function processDueReactivations(ctx) {
  const toleranceMs = 5 * 60 * 1000;
  const now = new Date(Date.now() + toleranceMs).toISOString();
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
    schedule: 'every 30 minutes',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '128MiB',
    timeoutSeconds: 120,
    maxInstances: 1,
  },
  async () => {
    // Read server-maintained cache only — refreshPricesScheduled keeps prices fresh.
    const ctx = await loadPriceContextFromFirestore(db);

    const reactivated = await processDueReactivations(ctx);
    if (reactivated > 0) {
      logger.info(`Reactivated ${reactivated} snoozed alerts`);
    }

    if (!ctx.globalRates && !ctx.localEgp && !ctx.localInr) {
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

    const userCache = new Map();
    let triggered = 0;

    for (const alertDoc of alertsSnap.docs) {
      try {
        const alert = alertDoc.data();
        const uid = alertDoc.ref.parent.parent?.id;
        if (!uid) continue;

        const current = resolvePrice(alert, ctx);
        if (!isTriggered(alert, current, ctx)) {
          continue;
        }

        let userData = userCache.get(uid);
        if (userData === undefined) {
          const userSnap = await db.collection('users').doc(uid).get();
          userData = userSnap.exists ? userSnap.data() : null;
          userCache.set(uid, userData);
        }

        const message = triggerMessage(alert, current, ctx);
        const pushResult = userData
          ? await sendPushToUser(uid, userData, {
              title: 'GoldSignal price alert',
              body: message,
              data: {
                type: 'price_alert',
                alertId: String(alert.id || alertDoc.id),
              },
            })
          : { sent: 0, transientErrors: 0, tokensTried: 0 };

        // Always deactivate on trigger so a failed push cannot leave the alert
        // stuck active forever. Retry delivery is best-effort only.
        if (pushResult.sent === 0) {
          logger.warn('Alert triggered but push not delivered; deactivating anyway', {
            uid,
            alertId: alertDoc.id,
            tokensTried: pushResult.tokensTried,
            transientErrors: pushResult.transientErrors,
          });
        }

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

        triggered += 1;
        logger.info(`Triggered alert ${alertDoc.id} for user ${uid}`, {
          pushSent: pushResult.sent,
        });
      } catch (err) {
        logger.error('Alert check failed for document', {
          alertId: alertDoc.id,
          err,
        });
      }
    }

    logger.info(`Alert check complete: ${triggered} triggered`);

    const watchlistTriggered = await processWatchlistMoveAlerts(ctx);
    if (watchlistTriggered > 0) {
      logger.info(`Watchlist move alerts: ${watchlistTriggered} sent`);
    }
  },
);

// Keeps the shared price cache fresh. This is now the ONLY writer of the
// `prices/*` documents — clients read them but no longer write (Firestore
// rules deny client writes). Global spot refreshes every 30 min; local
// EGP/INR markets refresh at most once per hour when unchanged.
exports.refreshPricesScheduled = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '256MiB',
    timeoutSeconds: 120,
    maxInstances: 1,
  },
  async () => {
    const ctx = await refreshPrices();
    if (!ctx.globalRates && !ctx.localEgp && !ctx.localInr) {
      logger.warn('Scheduled price refresh produced no data');
      return;
    }
    await updateDailyInsightCache(ctx);
    logger.info('Scheduled price refresh complete', {
      global: !!ctx.globalRates,
      localEgp: !!ctx.localEgp,
      localInr: !!ctx.localInr,
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
  const local = localDocFor(currency, ctx);
  if (isLocalCurrency(currency) && local) {
    const goldKarat = headlineGoldKarat(currency);
    const g = local.gold && local.gold[goldKarat];
    const s = local.silver && local.silver['999'];
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

async function sendDigestPush(userData, uid, title, body) {
  const result = await sendPushToUser(uid, userData, {
    title,
    body,
    data: { type: 'daily_digest' },
  });
  return result.sent > 0;
}

// Sends each subscribed user a daily digest at their chosen local time. Runs
// every 30 minutes and fires for users whose local time falls in the current
// slot, de-duplicated per local calendar day via `digest.lastSentYmd`.
exports.sendDailyDigest = onSchedule(
  {
    schedule: 'every 30 minutes',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '128MiB',
    timeoutSeconds: 120,
    maxInstances: 1,
  },
  async () => {
    const ctx = await loadPriceContextFromFirestore(db);
    if (!ctx.globalRates && !ctx.localEgp && !ctx.localInr) {
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

    // Reuse the single daily Groq line from metadata/dailyInsight (not per user).
    const cachedAiLine = await loadCachedDailyInsightAiLine();

    const now = Date.now();
    const pad = (n) => String(n).padStart(2, '0');
    let sent = 0;

    for (const userDoc of usersSnap.docs) {
      const data = userDoc.data();
      const d = data.digest || {};
      if (!userTokens(data).size) continue;

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
      if (cachedAiLine) body = `${cachedAiLine}\n${body}`;

      const ok = await sendDigestPush(data, userDoc.id, 'GoldSignal daily digest', body);
      if (ok) {
        await userDoc.ref.update({ 'digest.lastSentYmd': ymd });
        sent += 1;
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

async function portfolioMarketValue(uid, ctx, currency) {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('portfolio')
    .get();
  if (snap.empty) return null;

  let total = 0;
  for (const doc of snap.docs) {
    const item = doc.data();
    const metal = String(item.metal || 'Gold').toLowerCase();
    const karat = String(item.karat || 24);
    const weight = Number(item.weight) || 0;
    let perGram;
    if (isLocalCurrency(currency) && localDocFor(currency, ctx)) {
      perGram = localPricePerGram(
        localDocFor(currency, ctx),
        metal,
        karat,
        currency === 'EGP' ? 'buy' : 'sell',
      );
    } else {
      perGram = globalPricePerGram(ctx.globalRates, metal, karat, currency);
    }
    if (perGram != null) total += perGram * weight;
  }
  return total > 0 ? total : null;
}

async function userHasActiveAlerts(uid) {
  const snap = await db
    .collection('users')
    .doc(uid)
    .collection('alerts')
    .where('isActive', '==', true)
    .limit(1)
    .get();
  return !snap.empty;
}

async function reengageMessageForUser(uid, data, ctx, currency) {
  const nums = digestNumbers(ctx, currency);
  const portfolioVal = await portfolioMarketValue(uid, ctx, currency);
  if (portfolioVal != null) {
    const pct = nums.goldPct;
    const pctStr =
      pct != null
        ? ` (${pct >= 0 ? '+' : ''}${pct.toFixed(1)}% today)`
        : '';
    return {
      title: 'Your portfolio update',
      body: `Your gold is worth ${formatDigestNum(portfolioVal)} ${currency} today${pctStr}.`,
    };
  }

  if (data.isGuest === true && Number(data.calculatorUseCount) >= 3) {
    return {
      title: 'Save your calculations',
      body: 'Create a free account to save your gold calculations across devices.',
    };
  }

  const hasAlerts = await userHasActiveAlerts(uid);
  if (!hasAlerts) {
    return {
      title: 'Set your first alert',
      body: 'Get notified when gold hits your target price.',
    };
  }

  return reengageMessage(nums, currency);
}

function watchlistEntryLabel(entry) {
  const metal = entry.metal === 'silver' ? 'Silver' : 'Gold';
  const k = entry.karat || '24';
  return entry.metal === 'silver' ? `Silver ${k}` : `${metal} ${k}K`;
}

function resolveWatchlistQuote(entry, ctx, currency) {
  const local = localDocFor(currency, ctx);
  if (isLocalCurrency(currency) && local) {
    const map = entry.metal === 'gold' ? local.gold : local.silver;
    const row = map?.[entry.karat];
    if (!row) return null;
    return {
      pricePerGram: row.sellPerGram,
      changePercent: row.changePercent ?? 0,
    };
  }
  const perGram = globalPricePerGram(
    ctx.globalRates,
    entry.metal || 'gold',
    entry.karat || '24',
    currency,
  );
  const prev = globalPricePerGram(
    ctx.prevRates,
    entry.metal || 'gold',
    entry.karat || '24',
    currency,
  );
  return {
    pricePerGram: perGram,
    changePercent: changePercentFrom(perGram, prev) ?? 0,
  };
}

async function processWatchlistMoveAlerts(ctx) {
  const usersSnap = await db
    .collection('users')
    .where('watchlistAlerts.enabled', '==', true)
    .get();
  if (usersSnap.empty) return 0;

  const pad = (n) => String(n).padStart(2, '0');
  const now = Date.now();
  const ymd = `${new Date(now).getUTCFullYear()}-${pad(
    new Date(now).getUTCMonth() + 1,
  )}-${pad(new Date(now).getUTCDate())}`;

  let sent = 0;
  for (const userDoc of usersSnap.docs) {
    const data = userDoc.data();
    const wa = data.watchlistAlerts || {};
    if (!userTokens(data).size) continue;
    if (wa.lastNotifiedYmd === ymd) continue;

    const threshold = Number(wa.thresholdPercent) || 2;
    const currency = wa.currency || data.digest?.currency || 'USD';
    const entries = Array.isArray(wa.entries) ? wa.entries : [];
    if (entries.length === 0) continue;

    const movers = [];
    for (const entry of entries) {
      const quote = resolveWatchlistQuote(entry, ctx, currency);
      if (!quote) continue;
      const pct = quote.changePercent;
      if (pct != null && Math.abs(pct) >= threshold) {
        movers.push({
          label: watchlistEntryLabel(entry),
          pct,
          price: quote.pricePerGram,
        });
      }
    }
    if (movers.length === 0) continue;

    const top = movers.sort((a, b) => Math.abs(b.pct) - Math.abs(a.pct))[0];
    const sign = top.pct >= 0 ? '+' : '';
    const body =
      `${top.label} moved ${sign}${top.pct.toFixed(1)}% (24h)` +
      (top.price != null
        ? ` — now ${formatDigestNum(top.price)} ${currency}/g`
        : '') +
      '.';

    const pushResult = await sendPushToUser(userDoc.id, data, {
      title: 'Watchlist price move',
      body,
      data: {
        type: 'price_alert',
        alertId: 'watchlist_move',
      },
    });
    if (pushResult.sent > 0) {
      await userDoc.ref.set(
        { watchlistAlerts: { lastNotifiedYmd: ymd } },
        { merge: true },
      );
      sent += 1;
    }
  }
  return sent;
}

async function updateDailyInsightCache(ctx) {
  const ymd = utcYmd();

  const doc = await db.collection('metadata').doc('dailyInsight').get();
  if (doc.exists && doc.data()?.ymd === ymd) return;

  const nums = digestNumbers(ctx, 'USD');
  const priceBody = digestBody(nums, 'USD');
  const aiLine = await aiDigestLine(nums, 'USD');
  const text = aiLine || priceBody;

  await db.collection('metadata').doc('dailyInsight').set({
    ymd,
    text,
    aiLine: aiLine ?? null,
    priceBody,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function sendReEngagePush(userData, uid, title, body) {
  const result = await sendPushToUser(uid, userData, {
    title,
    body,
    data: { type: 're_engagement' },
  });
  return result.sent > 0;
}

// Nudges lapsed users back. Runs daily, targets users inactive >= the smallest
// tier, respects a per-user cooldown, the `reengage.enabled` opt-out, and a
// `metadata/app.reengageEnabled` kill switch. De-duped per local calendar day.
exports.sendReEngagement = onSchedule(
  {
    schedule: 'every 24 hours',
    timeZone: 'UTC',
    retryCount: 0,
    memory: '128MiB',
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
    if (!ctx.globalRates && !ctx.localEgp && !ctx.localInr) {
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
      if (!userTokens(data).size) continue;

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
      const { title, body } = await reengageMessageForUser(
        userDoc.id,
        data,
        ctx,
        currency,
      );

      const ok = await sendReEngagePush(data, userDoc.id, title, body);
      if (!ok) continue;

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
