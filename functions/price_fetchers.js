const cheerio = require('cheerio');
const admin = require('firebase-admin');

const OUNCE_TO_GRAM = 31.1034768;
const ISAGHA_URL = 'https://market.isagha.com/prices';
const GOODRETURNS_GOLD_URL = 'https://www.goodreturns.in/gold-rates/';
const GOODRETURNS_SILVER_URL = 'https://www.goodreturns.in/silver-rates/';
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
      changePercent: row.changePercent ?? 0,
    };
  }

  const silver = {};
  for (const row of silverRows) {
    if (row.isPerUnit || row.karat === 'silver_ounce') continue;
    silver[row.karat] = {
      sellPerGram: row.sellPerGram,
      buyPerGram: row.buyPerGram,
      changePercent: row.changePercent ?? 0,
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
  const docRef = db.collection('prices').doc('latest');
  const existing = await docRef.get();
  const existingData = existing.exists ? existing.data() : null;

  let prevRates = existingData?.prevRates ?? null;
  if (existingData?.rates && existingData.updatedAt) {
    const updatedAt = existingData.updatedAt.toDate();
    const hours = (Date.now() - updatedAt.getTime()) / (1000 * 60 * 60);
    if (hours >= 20 || !prevRates) {
      prevRates = existingData.rates;
    }
  } else if (existingData?.rates && !prevRates) {
    prevRates = existingData.rates;
  }

  await docRef.set({
    rates: apiResponse.rates,
    prevRates,
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

async function writeLocalInrPrices(db, gold, silver) {
  if (Object.keys(gold).length === 0 && Object.keys(silver).length === 0) {
    return null;
  }

  const data = {
    marketType: 'local',
    currency: 'INR',
    source: 'goodreturns',
    gold,
    silver,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  await db.collection('prices').doc('local_INR').set(data);
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

function changePercentFromDelta(price, delta) {
  if (price == null || delta == null) return 0;
  const previous = price - delta;
  if (previous === 0) return 0;
  return (delta / previous) * 100;
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
    999: {
      sellPerGram: price,
      buyPerGram: price,
      changePercent: changePercentFromDelta(price, gramDelta),
    },
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
  const apiResponse = await scrapeLivePriceOfGold();
  apiResponse.source = 'scraper';
  await writeGlobalPrices(db, apiResponse);
  return apiResponse.rates;
}

async function fetchAndUpdateLocalEgp(db) {
  const { gold, silver } = await scrapeIsaghaLocal();
  return writeLocalEgpPrices(db, gold, silver);
}

async function fetchAndUpdateLocalInr(db) {
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
  fetchAndUpdateGlobalPrices,
  fetchAndUpdateLocalEgp,
  fetchAndUpdateLocalInr,
  loadPriceContextFromFirestore,
};
