const OUNCE_TO_GRAM = 31.1034768;

function globalPricePerGram(rates, metal, karat, currency) {
  if (!rates) return null;

  const usdGold = rates.USDXAU;
  const usdSilver = rates.USDXAG;

  if (metal === 'gold') {
    if (!Number.isFinite(usdGold)) return null;
    const fx = currency === 'USD' ? 1 : rates[currency];
    if (!Number.isFinite(fx)) return null;
    const ounceInCurrency = currency === 'USD' ? usdGold : usdGold * fx;
    if (!Number.isFinite(ounceInCurrency)) return null;
    const purity = (parseInt(karat, 10) || 24) / 24;
    const result = (ounceInCurrency / OUNCE_TO_GRAM) * purity;
    return Number.isFinite(result) ? result : null;
  }

  if (!Number.isFinite(usdSilver)) return null;
  const fx = currency === 'USD' ? 1 : rates[currency];
  if (!Number.isFinite(fx)) return null;
  const ounceInCurrency = currency === 'USD' ? usdSilver : usdSilver * fx;
  if (!Number.isFinite(ounceInCurrency)) return null;
  const result = ounceInCurrency / OUNCE_TO_GRAM;
  return Number.isFinite(result) ? result : null;
}

function changePercentFrom(current, baseline) {
  if (!Number.isFinite(current) || !Number.isFinite(baseline) || baseline === 0) {
    return null;
  }
  const result = ((current - baseline) / baseline) * 100;
  return Number.isFinite(result) ? result : null;
}

function absoluteChangeFromPercent(sell, changePercent) {
  if (!Number.isFinite(sell) || !Number.isFinite(changePercent) || changePercent === 0) {
    return 0;
  }
  const result = sell - sell / (1 + changePercent / 100);
  return Number.isFinite(result) ? result : 0;
}

function changePercentFromDelta(price, delta) {
  if (!Number.isFinite(price) || delta == null || !Number.isFinite(delta)) return 0;
  const previous = price - delta;
  if (previous === 0) return 0;
  const result = (delta / previous) * 100;
  return Number.isFinite(result) ? result : 0;
}

function toFirestoreLocalMaps(goldRows, silverRows) {
  const gold = {};
  for (const row of goldRows) {
    if (row.isPerUnit || row.karat === 'gold_ounce') continue;
    const pct = row.changePercent ?? 0;
    gold[row.karat] = {
      sellPerGram: row.sellPerGram,
      buyPerGram: row.buyPerGram,
      changePercent: pct,
      change: row.change ?? absoluteChangeFromPercent(row.sellPerGram, pct),
    };
  }

  const silver = {};
  for (const row of silverRows) {
    if (row.isPerUnit || row.karat === 'silver_ounce') continue;
    const pct = row.changePercent ?? 0;
    silver[row.karat] = {
      sellPerGram: row.sellPerGram,
      buyPerGram: row.buyPerGram,
      changePercent: pct,
      change: row.change ?? absoluteChangeFromPercent(row.sellPerGram, pct),
    };
  }

  return { gold, silver };
}

module.exports = {
  OUNCE_TO_GRAM,
  globalPricePerGram,
  changePercentFrom,
  absoluteChangeFromPercent,
  changePercentFromDelta,
  toFirestoreLocalMaps,
};
