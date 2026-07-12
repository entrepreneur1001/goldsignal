const cheerio = require('cheerio');
const admin = require('firebase-admin');
const { logger } = require('firebase-functions');
const {
  absoluteChangeFromPercent,
  changePercentFromDelta,
  toFirestoreLocalMaps,
} = require('./price_helpers');

const OUNCE_TO_GRAM = 31.1034768;
const ISAGHA_URL = 'https://market.isagha.com/prices';
const GOODRETURNS_GOLD_URL = 'https://www.goodreturns.in/gold-rates/';
const GOODRETURNS_SILVER_URL = 'https://www.goodreturns.in/silver-rates/';
const LIVE_GOLD_URL = 'https://www.livepriceofgold.com/usa-gold-price.html';
const LIVE_FX_URL = 'https://www.livepriceofgold.com/exchange-rate';
const GOLDPRICE_DBXRATES_URL = 'https://data-asg.goldprice.org/dbXRates';
const GOLDPRICE_GETDATA_URL = 'https://data-asg.goldprice.org/GetData';
/** Target points written to Firestore for the intraday chart seed. */
const INTRADAY_CHART_TARGET_POINTS = 120;
/** Assumed session window when GetData/0 has no timestamps. */
const INTRADAY_CHART_WINDOW_MS = 24 * 60 * 60 * 1000;
const CURRENCY_SELECTORS = {
  SAR: 'USDSAR',
  AED: 'USDAED',
  EGP: 'USDEGP',
  KWD: 'USDKWD',
  BHD: 'USDBHD',
  OMR: 'USDOMR',
  QAR: 'USDQAR',
  JOD: 'USDJOD',
  EUR: 'USDEUR',
  GBP: 'USDGBP',
  JPY: 'USDJPY',
  CNY: 'USDCNY',
  INR: 'USDINR',
  PKR: 'USDPKR',
  CAD: 'USDCAD',
  AUD: 'USDAUD',
  TRY: 'USDTL',
};

const FETCH_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (compatible; GoldSignal/1.0)',
  'Accept-Language': 'ar-EG,ar;q=0.9,en;q=0.8',
};

/** Browser-like headers for goldprice.org; Cookie / if-none-match intentionally omitted. */
const GOLDPRICE_HEADERS = {
  accept: 'application/json, text/javascript, */*; q=0.01',
  'accept-language': 'en-US,en;q=0.9',
  origin: 'https://goldprice.org',
  priority: 'u=1, i',
  referer: 'https://goldprice.org/',
  'sec-ch-ua': '"Google Chrome";v="149", "Chromium";v="149", "Not)A;Brand";v="24"',
  'sec-ch-ua-mobile': '?0',
  'sec-ch-ua-platform': '"macOS"',
  'sec-fetch-dest': 'empty',
  'sec-fetch-mode': 'cors',
  'sec-fetch-site': 'same-site',
  'user-agent':
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36',
};

/** Local EGP/INR markets update less frequently than global spot. */
const LOCAL_REFRESH_MAX_AGE_MS = 60 * 60 * 1000;
const FETCH_TIMEOUT_MS = 20_000;
const FETCH_MAX_ATTEMPTS = 2;

function stableHash(value) {
  return JSON.stringify(value);
}

function docUpdatedAtMs(data) {
  const updatedAt = data?.updatedAt;
  if (!updatedAt) return null;
  if (typeof updatedAt.toDate === 'function') return updatedAt.toDate().getTime();
  if (updatedAt instanceof Date) return updatedAt.getTime();
  return null;
}

async function isPriceDocStale(db, docId, maxAgeMs) {
  const snap = await db.collection('prices').doc(docId).get();
  if (!snap.exists) return true;
  const updatedMs = docUpdatedAtMs(snap.data());
  if (updatedMs == null) return true;
  return Date.now() - updatedMs > maxAgeMs;
}

async function fetchWithTimeout(url, { headers = {}, timeoutMs = FETCH_TIMEOUT_MS } = {}) {
  let lastError;
  for (let attempt = 1; attempt <= FETCH_MAX_ATTEMPTS; attempt += 1) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), timeoutMs);
    try {
      const response = await fetch(url, { headers, signal: controller.signal });
      if (!response.ok) {
        throw new Error(`HTTP ${response.status} for ${url}`);
      }
      return response;
    } catch (err) {
      lastError = err;
      if (attempt < FETCH_MAX_ATTEMPTS) {
        logger.warn('Fetch attempt failed; retrying', {
          url,
          attempt,
          error: err?.message ?? String(err),
        });
      }
    } finally {
      clearTimeout(timer);
    }
  }
  throw lastError ?? new Error(`Fetch failed for ${url}`);
}

async function fetchHtml(url, headers = FETCH_HEADERS) {
  const response = await fetchWithTimeout(url, { headers });
  return response.text();
}

function cleanPrice(raw) {
  const cleaned = String(raw).replaceAll(',', '').replaceAll(' ', '').trim();
  if (!cleaned) return null;
  const value = Number.parseFloat(cleaned);
  return Number.isFinite(value) ? value : null;
}

function parsePercentCell(raw) {
  const cleaned = String(raw)
    .replaceAll('\u200E', '')
    .replaceAll('\u200F', '')
    .replaceAll('%', '')
    .replaceAll(',', '')
    .trim();
  if (!cleaned) return null;
  const value = Number.parseFloat(cleaned);
  return Number.isFinite(value) ? value : null;
}

function signedChange($cell, value) {
  if (value == null) return null;
  const classes = ($cell.attr('class') || '').split(/\s+/);
  if (classes.includes('change-down') && value > 0) return -value;
  return value;
}

function parsePriceCell(raw) {
  const cleaned = String(raw)
    .replaceAll('\u200E', '')
    .replaceAll('\u200F', '')
    .replaceAll('ج.م', '')
    .replaceAll('$', '')
    .replaceAll('—', '')
    .replaceAll(',', '')
    .trim();
  if (!cleaned) return null;
  const value = Number.parseFloat(cleaned);
  return Number.isFinite(value) ? value : null;
}

function normalizeKaratLabel(label, metalClass) {
  if (metalClass === 'gold') {
    if (label.includes('عيار 24')) return '24';
    if (label.includes('عيار 22')) return '22';
    if (label.includes('عيار 21')) return '21';
    if (label.includes('عيار 18')) return '18';
    if (label.includes('جنيه ذهب')) return 'gold_pound';
    if (label.includes('أوقية الذهب')) return 'gold_ounce';
  } else {
    if (label.includes('عيار 999')) return '999';
    if (label.includes('عيار 925')) return '925';
    if (label.includes('عيار 900')) return '900';
    if (label.includes('عيار 800')) return '800';
    if (label.includes('عيار 600')) return '600';
    if (label.includes('الجنيه الفضة')) return 'silver_pound';
    if (label.includes('أوقية الفضة')) return 'silver_ounce';
  }
  return null;
}

function parseMetalRows($, metalClass) {
  const rows = [];

  $('tr').each((_, tr) => {
    const $tr = $(tr);
    if ($tr.find(`.metal-icon.${metalClass}`).length === 0) return;

    const label = $tr.find('.purity-cell span:last-child').text().trim();
    if (!label) return;

    const cells = $tr.find('td');
    if (cells.length < 7) return;

    const karat = normalizeKaratLabel(label, metalClass);
    if (!karat) return;

    const sell = parsePriceCell($(cells[1]).text());
    const buy = parsePriceCell($(cells[3]).text());
    if (sell == null || buy == null) return;

    const changePercentCell = $(cells[6]);
    const changePercent = signedChange(
      changePercentCell,
      parsePercentCell(changePercentCell.text()),
    );

    rows.push({
      karat,
      sellPerGram: sell,
      buyPerGram: buy,
      changePercent: changePercent ?? 0,
      change: absoluteChangeFromPercent(sell, changePercent ?? 0),
      isPerUnit: karat === 'gold_pound' || karat === 'silver_pound',
    });
  });

  return rows;
}

function assertSpotMetalPrices(goldPrice, silverPrice) {
  if (goldPrice == null || goldPrice <= 500 || goldPrice >= 50000) {
    throw new Error('Failed to obtain gold price');
  }
  if (silverPrice == null || silverPrice <= 5 || silverPrice >= 500) {
    throw new Error('Failed to obtain silver price');
  }
}

/**
 * Primary global source: goldprice.org dbXRates (spot metals + FX derived from
 * local-currency ounce prices vs USD ounce).
 */
async function fetchGoldpriceDbXRates() {
  const currencies = ['USD', ...Object.keys(CURRENCY_SELECTORS)].join(',');
  const url = `${GOLDPRICE_DBXRATES_URL}/${currencies}`;
  const response = await fetchWithTimeout(url, { headers: GOLDPRICE_HEADERS });
  const data = await response.json();
  const items = Array.isArray(data?.items) ? data.items : [];
  const byCurr = new Map(items.map((item) => [item.curr, item]));
  const usd = byCurr.get('USD');
  if (!usd) {
    throw new Error('dbXRates response missing USD item');
  }

  const goldPrice = Number(usd.xauPrice);
  const silverPrice = Number(usd.xagPrice);
  assertSpotMetalPrices(
    Number.isFinite(goldPrice) ? goldPrice : null,
    Number.isFinite(silverPrice) ? silverPrice : null,
  );

  const rates = {
    USDXAU: goldPrice,
    USDXAG: silverPrice,
  };

  for (const currency of Object.keys(CURRENCY_SELECTORS)) {
    const item = byCurr.get(currency);
    const localXau = Number(item?.xauPrice);
    if (!Number.isFinite(localXau) || localXau <= 0) continue;
    const fx = localXau / goldPrice;
    if (Number.isFinite(fx) && fx > 0) rates[currency] = fx;
  }

  const missingFx = Object.keys(CURRENCY_SELECTORS).filter((c) => rates[c] == null);
  if (missingFx.length > 0) {
    logger.warn('Missing FX rates after goldprice.org dbXRates', { currencies: missingFx });
  }

  if (Object.keys(rates).length < 7) {
    throw new Error(`Too few exchange rates from goldprice.org: ${Object.keys(rates).length}`);
  }

  const apiTsMs = Number(data.tsj ?? data.ts);
  const timestamp = Number.isFinite(apiTsMs)
    ? Math.floor(apiTsMs / 1000)
    : Math.floor(Date.now() / 1000);

  return {
    success: true,
    base: 'USD',
    timestamp,
    rates,
    source: 'goldprice',
  };
}

/**
 * Parse GetData/{PAIR}/0 CSV-in-JSON into a downsampled USD/oz series.
 * Consecutive duplicate prices are collapsed; remaining points are evenly
 * spaced over the last [INTRADAY_CHART_WINDOW_MS] ending at now.
 */
function parseGetDataSeries(payload, pairPrefix) {
  if (!Array.isArray(payload) || payload.length === 0) {
    throw new Error('GetData response is not a non-empty array');
  }
  const raw = String(payload[0] ?? '');
  const parts = raw.split(',');
  if (parts.length < 3) {
    throw new Error('GetData series too short');
  }
  const prefix = parts[0].trim();
  if (pairPrefix && prefix !== pairPrefix) {
    throw new Error(`GetData pair mismatch: expected ${pairPrefix}, got ${prefix}`);
  }

  const prices = [];
  for (let i = 1; i < parts.length; i += 1) {
    const value = Number.parseFloat(parts[i]);
    if (!Number.isFinite(value)) continue;
    if (prices.length === 0 || Math.abs(prices[prices.length - 1] - value) > 1e-9) {
      prices.push(value);
    }
  }
  if (prices.length < 2) {
    throw new Error('GetData series has fewer than 2 distinct prices');
  }

  const step = Math.max(1, Math.floor(prices.length / INTRADAY_CHART_TARGET_POINTS));
  const sampled = [];
  for (let i = 0; i < prices.length; i += step) {
    sampled.push(prices[i]);
  }
  if (sampled[sampled.length - 1] !== prices[prices.length - 1]) {
    sampled.push(prices[prices.length - 1]);
  }

  const endMs = Date.now();
  const startMs = endMs - INTRADAY_CHART_WINDOW_MS;
  const denom = Math.max(1, sampled.length - 1);
  return sampled.map((v, i) => ({
    t: new Date(startMs + ((endMs - startMs) * i) / denom).toISOString(),
    v,
  }));
}

async function fetchGoldpriceGetDataSeries(pair) {
  const url = `${GOLDPRICE_GETDATA_URL}/${pair}/0`;
  const response = await fetchWithTimeout(url, {
    headers: GOLDPRICE_HEADERS,
    timeoutMs: 45_000,
  });
  const payload = await response.json();
  return parseGetDataSeries(payload, pair);
}

async function writeIntradayChart(db, { gold, silver }) {
  const docRef = db.collection('prices').doc('chart_intraday');
  await docRef.set({
    source: 'goldprice',
    base: 'USD',
    unit: 'per_ounce',
    windowHours: INTRADAY_CHART_WINDOW_MS / (60 * 60 * 1000),
    gold,
    silver,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  return { goldPoints: gold.length, silverPoints: silver.length };
}

async function fetchAndUpdateIntradayChart(db) {
  const [gold, silver] = await Promise.all([
    fetchGoldpriceGetDataSeries('USD-XAU'),
    fetchGoldpriceGetDataSeries('USD-XAG'),
  ]);
  return writeIntradayChart(db, { gold, silver });
}

async function scrapeLivePriceOfGold() {
  const [goldHtml, fxHtml] = await Promise.all([
    fetchHtml(LIVE_GOLD_URL),
    fetchHtml(LIVE_FX_URL),
  ]);

  const $gold = cheerio.load(goldHtml);
  const $fx = cheerio.load(fxHtml);
  const rates = {};

  const goldPrice = cleanPrice($gold('[data-price="XAUUSD"]').first().text());
  const silverPrice = cleanPrice($gold('[data-price="XAGUSD"]').first().text());
  assertSpotMetalPrices(goldPrice, silverPrice);

  rates.USDXAU = goldPrice;
  rates.USDXAG = silverPrice;

  for (const [currency, selector] of Object.entries(CURRENCY_SELECTORS)) {
    const rate = cleanPrice($fx(`[data-price="${selector}"]`).first().text());
    if (rate != null && rate > 0) rates[currency] = rate;
  }

  const missingFx = Object.keys(CURRENCY_SELECTORS).filter((c) => rates[c] == null);
  if (missingFx.length > 0) {
    logger.warn('Missing FX rates after scrape', { currencies: missingFx });
  }

  if (Object.keys(rates).length < 7) {
    throw new Error(`Too few exchange rates scraped: ${Object.keys(rates).length}`);
  }

  return {
    success: true,
    base: 'USD',
    timestamp: Math.floor(Date.now() / 1000),
    rates,
    source: 'scraper',
  };
}

async function writeGlobalPrices(db, apiResponse) {
  const docRef = db.collection('prices').doc('latest');
  const existing = await docRef.get();
  const existingData = existing.exists ? existing.data() : null;

  let prevRates = existingData?.prevRates ?? null;
  let prevRatesRotated = false;
  // Legacy docs may have prevRates without prevRatesAt. Never use updatedAt as
  // the rotation clock (it bumps every refresh even when rates are unchanged).
  let backfillPrevRatesAt = false;

  const prevRatesAtMs = docUpdatedAtMs({ updatedAt: existingData?.prevRatesAt });

  if (existingData?.rates) {
    if (!prevRates) {
      prevRates = existingData.rates;
      prevRatesRotated = true;
    } else if (prevRatesAtMs == null) {
      backfillPrevRatesAt = true;
    } else {
      const hoursSincePrevRotation =
        (Date.now() - prevRatesAtMs) / (1000 * 60 * 60);
      if (hoursSincePrevRotation >= 20) {
        prevRates = existingData.rates;
        prevRatesRotated = true;
      }
    }
  }

  const nextHash = stableHash(apiResponse.rates);
  const hashEqual =
    existingData?.rates && stableHash(existingData.rates) === nextHash;

  if (hashEqual) {
    const patch = {
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };
    if (prevRatesRotated) {
      patch.prevRates = prevRates;
      patch.prevRatesAt = admin.firestore.FieldValue.serverTimestamp();
    } else if (backfillPrevRatesAt) {
      patch.prevRatesAt = admin.firestore.FieldValue.serverTimestamp();
    }
    await docRef.set(patch, { merge: true });
    return { rates: existingData.rates, prevRates, skippedWrite: true };
  }

  const writeData = {
    rates: apiResponse.rates,
    prevRates,
    base: apiResponse.base ?? 'USD',
    success: apiResponse.success ?? true,
    apiTimestamp: apiResponse.timestamp,
    source: apiResponse.source ?? 'cloud_function',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
  if (prevRatesRotated || backfillPrevRatesAt) {
    writeData.prevRatesAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await docRef.set(writeData);
  return { rates: apiResponse.rates, prevRates, skippedWrite: false };
}

async function writeLocalEgpPrices(db, gold, silver) {
  if (Object.keys(gold).length === 0 && Object.keys(silver).length === 0) {
    return null;
  }

  const docRef = db.collection('prices').doc('local_EGP');
  const existing = await docRef.get();
  const existingData = existing.exists ? existing.data() : null;
  const nextHash = stableHash({ gold, silver });
  if (
    existingData?.gold &&
    existingData?.silver &&
    stableHash({ gold: existingData.gold, silver: existingData.silver }) === nextHash
  ) {
    return { ...existingData, skippedWrite: true };
  }

  const data = {
    marketType: 'local',
    currency: 'EGP',
    source: 'isagha',
    gold,
    silver,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await docRef.set(data);
  return data;
}

async function writeLocalInrPrices(db, gold, silver) {
  if (Object.keys(gold).length === 0 && Object.keys(silver).length === 0) {
    return null;
  }

  const docRef = db.collection('prices').doc('local_INR');
  const existing = await docRef.get();
  const existingData = existing.exists ? existing.data() : null;
  const nextHash = stableHash({ gold, silver });
  if (
    existingData?.gold &&
    existingData?.silver &&
    stableHash({ gold: existingData.gold, silver: existingData.silver }) === nextHash
  ) {
    return { ...existingData, skippedWrite: true };
  }

  const data = {
    marketType: 'local',
    currency: 'INR',
    source: 'goodreturns',
    gold,
    silver,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await docRef.set(data);
  return data;
}

function parseInrPrice(raw) {
  const cleaned = String(raw)
    .replaceAll('\u20b9', '')
    .replaceAll('₹', '')
    .replaceAll(',', '')
    .trim();
  if (!cleaned) return null;
  const value = Number.parseFloat(cleaned);
  return Number.isFinite(value) ? value : null;
}

function parseParentheticalChange(raw) {
  const match = String(raw).match(/\(([+\-]?\d[\d,]*)\)/);
  if (!match) return 0;
  const value = Number.parseFloat(match[1].replaceAll(',', ''));
  return Number.isFinite(value) ? value : 0;
}

function enrichLocalKaratRow(row) {
  const pct = row.changePercent ?? 0;
  row.change = absoluteChangeFromPercent(row.sellPerGram, pct);
  return row;
}

function parseGoodreturnsGold(goldHtml) {
  const gold = {};
  const jsMatch = goldHtml.match(/currentMetalPrices\s*=\s*\{([^}]+)\}/);
  if (jsMatch) {
    for (const karat of ['24', '22', '18']) {
      const priceMatch = jsMatch[1].match(new RegExp(`'${karat}'\\s*:\\s*(\\d+)`));
      if (priceMatch) {
        const price = Number.parseInt(priceMatch[1], 10);
        gold[karat] = {
          sellPerGram: price,
          buyPerGram: price,
          changePercent: 0,
        };
      }
    }
  }

  if (Object.keys(gold).length < 3) {
    const $ = cheerio.load(goldHtml);
    for (const karat of ['24', '22', '18']) {
      const price = parseInrPrice($(`#${karat}K-price`).text());
      if (price != null) {
        gold[karat] = {
          sellPerGram: price,
          buyPerGram: price,
          changePercent: 0,
        };
      }
    }
  }

  const $ = cheerio.load(goldHtml);
  const cells = $('tbody.tablebody tr').first().find('td');
  if (cells.length >= 3) {
    if (gold['24']) {
      const delta = parseParentheticalChange($(cells[1]).text());
      gold['24'].changePercent = changePercentFromDelta(gold['24'].sellPerGram, delta);
    }
    if (gold['22']) {
      const delta = parseParentheticalChange($(cells[2]).text());
      gold['22'].changePercent = changePercentFromDelta(gold['22'].sellPerGram, delta);
    }
  }

  if (gold['18']) {
    gold['18'].changePercent =
      gold['24']?.changePercent ?? gold['22']?.changePercent ?? 0;
  }

  for (const karat of ['24', '22', '18']) {
    if (gold[karat]) enrichLocalKaratRow(gold[karat]);
  }

  return gold;
}

function parseGoodreturnsSilver(silverHtml) {
  const $ = cheerio.load(silverHtml);
  const price = parseInrPrice($('#silver-1g-price').text());
  if (price == null) return {};

  const cells = $('tbody.tablebody tr').first().find('td');
  const kgDelta = cells.length >= 4 ? parseParentheticalChange($(cells[3]).text()) : 0;
  const gramDelta = kgDelta / 1000;

  return {
    999: enrichLocalKaratRow({
      sellPerGram: price,
      buyPerGram: price,
      changePercent: changePercentFromDelta(price, gramDelta),
    }),
  };
}

async function scrapeGoodreturnsIndia() {
  const inHeaders = {
    ...FETCH_HEADERS,
    'Accept-Language': 'en-IN,en;q=0.9',
  };
  const [goldHtml, silverHtml] = await Promise.all([
    fetchHtml(GOODRETURNS_GOLD_URL, inHeaders),
    fetchHtml(GOODRETURNS_SILVER_URL, inHeaders),
  ]);

  const gold = parseGoodreturnsGold(goldHtml);
  const silver = parseGoodreturnsSilver(silverHtml);

  if (!gold['22']) {
    throw new Error('Missing 22K gold price from Goodreturns');
  }
  if (!silver['999']) {
    throw new Error('Missing silver per-gram price from Goodreturns');
  }

  return { gold, silver };
}

async function scrapeIsaghaLocal() {
  const html = await fetchHtml(ISAGHA_URL);
  const $ = cheerio.load(html);
  const goldRows = parseMetalRows($, 'gold');
  const silverRows = parseMetalRows($, 'silver');

  if (goldRows.filter((r) => !r.isPerUnit && r.karat !== 'gold_ounce').length < 4) {
    throw new Error(`Too few gold rows parsed: ${goldRows.length}`);
  }

  const { gold, silver } = toFirestoreLocalMaps(goldRows, silverRows);
  return { gold, silver };
}

async function fetchAndUpdateGlobalPrices(db) {
  let apiResponse;
  try {
    apiResponse = await fetchGoldpriceDbXRates();
  } catch (err) {
    logger.warn('goldprice.org dbXRates failed; falling back to livepriceofgold scrape', {
      error: err?.message ?? String(err),
    });
    apiResponse = await scrapeLivePriceOfGold();
  }
  const result = await writeGlobalPrices(db, apiResponse);
  return result.rates;
}

async function fetchAndUpdateLocalEgp(db, { force = false } = {}) {
  if (!force && !(await isPriceDocStale(db, 'local_EGP', LOCAL_REFRESH_MAX_AGE_MS))) {
    const snap = await db.collection('prices').doc('local_EGP').get();
    return snap.exists ? snap.data() : null;
  }
  const { gold, silver } = await scrapeIsaghaLocal();
  return writeLocalEgpPrices(db, gold, silver);
}

async function fetchAndUpdateLocalInr(db, { force = false } = {}) {
  if (!force && !(await isPriceDocStale(db, 'local_INR', LOCAL_REFRESH_MAX_AGE_MS))) {
    const snap = await db.collection('prices').doc('local_INR').get();
    return snap.exists ? snap.data() : null;
  }
  const { gold, silver } = await scrapeGoodreturnsIndia();
  return writeLocalInrPrices(db, gold, silver);
}

async function loadPriceContextFromFirestore(db) {
  const [latestSnap, localEgpSnap, localInrSnap] = await Promise.all([
    db.collection('prices').doc('latest').get(),
    db.collection('prices').doc('local_EGP').get(),
    db.collection('prices').doc('local_INR').get(),
  ]);

  const latest = latestSnap.exists ? latestSnap.data() : null;
  return {
    globalRates: latest?.rates ?? null,
    prevRates: latest?.prevRates ?? null,
    localEgp: localEgpSnap.exists ? localEgpSnap.data() : null,
    localInr: localInrSnap.exists ? localInrSnap.data() : null,
  };
}

module.exports = {
  OUNCE_TO_GRAM,
  LOCAL_REFRESH_MAX_AGE_MS,
  fetchAndUpdateGlobalPrices,
  fetchAndUpdateIntradayChart,
  fetchAndUpdateLocalEgp,
  fetchAndUpdateLocalInr,
  loadPriceContextFromFirestore,
  toFirestoreLocalMaps,
};
