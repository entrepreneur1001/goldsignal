const test = require('node:test');
const assert = require('node:assert/strict');

const {
  globalPricePerGram,
  changePercentFrom,
  absoluteChangeFromPercent,
  toFirestoreLocalMaps,
  changePercentFromDelta,
} = require('./price_helpers');

test('globalPricePerGram returns null when FX missing (not NaN)', () => {
  const rates = { USDXAU: 2000, USDXAG: 25 };
  assert.equal(globalPricePerGram(rates, 'gold', '24', 'CAD'), null);
});

test('changePercentFrom rejects NaN inputs', () => {
  assert.equal(changePercentFrom(Number.NaN, 5), null);
  assert.equal(changePercentFrom(10, Number.NaN), null);
});

test('local maps include absolute change', () => {
  const { gold } = toFirestoreLocalMaps(
    [
      {
        karat: '24',
        sellPerGram: 100,
        buyPerGram: 99,
        changePercent: 2,
        change: 1.96,
      },
    ],
    [],
  );
  assert.ok(Number.isFinite(gold['24'].change));
  assert.equal(gold['24'].changePercent, 2);
});

test('18K percent matches 24K when derived from delta helper', () => {
  const pct24 = changePercentFromDelta(5000, 50);
  const pct18 = pct24;
  assert.equal(pct18, pct24);
  assert.ok(Math.abs(pct24) > 0);
});

test('absoluteChangeFromPercent derives sell delta from percent', () => {
  const change = absoluteChangeFromPercent(100, 2);
  assert.ok(Math.abs(change - 1.960784) < 0.001);
});
