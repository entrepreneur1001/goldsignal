const cheerio = require('cheerio');
const admin = require('firebase-admin');

const OUNCE_TO_GRAM = 31.1034768;
const ISAGHA_URL = 'https://market.isagha.com/prices';
const LIVE_GOLD_URL = 'https://www.livepriceofgold.com/usa-gold-price.html';
const LIVE_FX_URL = 'https://www.livepriceofgold.com/exchange-rate';
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
  TRY: 'USDTL',
};

const FETCH_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (compatible; GoldSignal/1.0)',
  'Accept-Language': 'ar-EG,ar;q=0.9,en;q=0.8',
};

async function fetchHtml(url, headers = FETCH_HEADERS) {
  const response = await fetch(url, { headers });
  if (!response.ok) {
    throw new Error(`HTTP ${response.status} for ${url}`);
  }
  return response.text();
}

function cleanPrice(raw) {
  const cleaned = String(raw).replaceAll(',', '').replaceAll(' ', '').trim();
  if (!cleaned) return null;
  const value = Number.parseFloat(cleaned);
  return Number.isFinite(value) ? value : null;
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

function signedChange($cell, value) {
  if (value == null) return null;
  const classes = ($cell.attr('class') || '').split(/\s+/);
  if (classes.includes('change-down') && value > 0) return -value;
  return value;
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

    rows.push({
      karat,
      sellPerGram: sell,
      buyPerGram: buy,
      isPerUnit: karat === 'gold_pound' || karat === 'silver_pound',
    });
  });

  return rows;
}

function toFirestoreLocalMaps(goldRows, silverRows) {
  const gold = {};
  for (const row of goldRows) {
    if (row.isPerUnit || row.karat === 'gold_ounce') continue;
    gold[row.karat] = {
      sellPerGram: row.sellPerGram,
      buyPerGram: row.buyPerGram,
    };
  }

  const silver = {};
  for (const row of silverRows) {
    if (row.isPerUnit || row.karat === 'silver_ounce') continue;
    silver[row.karat] = {
      sellPerGram: row.sellPerGram,
      buyPerGram: row.buyPerGram,
    };
  }

  return { gold, silver };
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

  if (goldPrice == null || goldPrice <= 500 || goldPrice >= 50000) {
    throw new Error('Failed to scrape gold price');
  }
  if (silverPrice == null || silverPrice <= 5 || silverPrice >= 500) {
    throw new Error('Failed to scrape silver price');
  }

  rates.USDXAU = goldPrice;
  rates.USDXAG = silverPrice;

  for (const [currency, selector] of Object.entries(CURRENCY_SELECTORS)) {
    const rate = cleanPrice($fx(`[data-price="${selector}"]`).first().text());
    if (rate != null && rate > 0) rates[currency] = rate;
  }

  if (Object.keys(rates).length < 7) {
    throw new Error(`Too few exchange rates scraped: ${Object.keys(rates).length}`);
  }

  return {
    success: true,
    base: 'USD',
    timestamp: Math.floor(Date.now() / 1000),
    rates,
  };
}

async function writeGlobalPrices(db, apiResponse) {
  await db.collection('prices').doc('latest').set({
    rates: apiResponse.rates,
    base: apiResponse.base ?? 'USD',
    success: apiResponse.success ?? true,
    apiTimestamp: apiResponse.timestamp,
    source: apiResponse.source ?? 'cloud_function',
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function writeLocalEgpPrices(db, gold, silver) {
  if (Object.keys(gold).length === 0 && Object.keys(silver).length === 0) {
    return null;
  }

  const data = {
    marketType: 'local',
    currency: 'EGP',
    source: 'isagha',
    gold,
    silver,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('prices').doc('local_EGP').set(data);
  return data;
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
  const apiResponse = await scrapeLivePriceOfGold();
  apiResponse.source = 'scraper';
  await writeGlobalPrices(db, apiResponse);
  return apiResponse.rates;
}

async function fetchAndUpdateLocalEgp(db) {
  const { gold, silver } = await scrapeIsaghaLocal();
  return writeLocalEgpPrices(db, gold, silver);
}

async function loadPriceContextFromFirestore(db) {
  const [latestSnap, localSnap] = await Promise.all([
    db.collection('prices').doc('latest').get(),
    db.collection('prices').doc('local_EGP').get(),
  ]);

  return {
    globalRates: latestSnap.exists ? latestSnap.data()?.rates ?? null : null,
    localEgp: localSnap.exists ? localSnap.data() : null,
  };
}

module.exports = {
  OUNCE_TO_GRAM,
  fetchAndUpdateGlobalPrices,
  fetchAndUpdateLocalEgp,
  loadPriceContextFromFirestore,
};
