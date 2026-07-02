import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/core/ai/portfolio_analysis_fingerprint.dart';
import 'package:goldsignal/shared/models/portfolio_item.dart';

void main() {
  group('isPriceStale', () {
    const cached = PortfolioPriceSnapshot(
      goldChange24hPct: 1.0,
      silverChange24hPct: 0.5,
      currency: 'USD',
      isLocalMarket: false,
    );

    test('returns false when prices are within threshold', () {
      const current = PortfolioPriceSnapshot(
        goldChange24hPct: 1.4,
        silverChange24hPct: 0.8,
        currency: 'USD',
        isLocalMarket: false,
      );
      expect(isPriceStale(cached, current), isFalse);
    });

    test('returns true when gold moves beyond threshold', () {
      const current = PortfolioPriceSnapshot(
        goldChange24hPct: 2.5,
        silverChange24hPct: 0.5,
        currency: 'USD',
        isLocalMarket: false,
      );
      expect(isPriceStale(cached, current), isTrue);
    });

    test('returns true when currency changes', () {
      const current = PortfolioPriceSnapshot(
        goldChange24hPct: 1.0,
        silverChange24hPct: 0.5,
        currency: 'SAR',
        isLocalMarket: false,
      );
      expect(isPriceStale(cached, current), isTrue);
    });

    test('returns true when one side goes from null to value', () {
      const current = PortfolioPriceSnapshot(
        goldChange24hPct: 1.0,
        silverChange24hPct: null,
        currency: 'USD',
        isLocalMarket: false,
      );
      expect(isPriceStale(cached, current), isTrue);
    });
  });

  group('computePortfolioInputHash', () {
    final itemA = PortfolioItem(
      firestoreId: 'a',
      metal: 'Gold',
      karat: 21,
      weight: 10,
      purchasePrice: 100,
      purchaseCurrency: 'USD',
      purchaseDate: DateTime(2024, 1, 1),
    );
    final itemB = PortfolioItem(
      firestoreId: 'b',
      metal: 'Silver',
      karat: 999,
      weight: 5,
      purchasePrice: 20,
      purchaseCurrency: 'USD',
      purchaseDate: DateTime(2024, 2, 1),
    );

    test('same inputs produce the same hash', () {
      final h1 = computePortfolioInputHash([itemA, itemB], 'USD');
      final h2 = computePortfolioInputHash([itemA, itemB], 'USD');
      expect(h1, h2);
    });

    test('different currency changes hash', () {
      final usd = computePortfolioInputHash([itemA], 'USD');
      final sar = computePortfolioInputHash([itemA], 'SAR');
      expect(usd, isNot(sar));
    });

    test('order of items does not change hash', () {
      final ab = computePortfolioInputHash([itemA, itemB], 'USD');
      final ba = computePortfolioInputHash([itemB, itemA], 'USD');
      expect(ab, ba);
    });
  });

  group('parseTrilingualAnalysisJson', () {
    test('parses plain JSON', () {
      final result = parseTrilingualAnalysisJson(
        '{"en":"Hello","ar":"مرحبا","ur":"سلام"}',
      );
      expect(result['en'], 'Hello');
      expect(result['ar'], 'مرحبا');
      expect(result['ur'], 'سلام');
    });

    test('strips markdown fences', () {
      final result = parseTrilingualAnalysisJson(
        '```json\n{"en":"Hi","ar":"أهلا","ur":"ہیلو"}\n```',
      );
      expect(result['en'], 'Hi');
    });

    test('accepts partial locales when at least one is present', () {
      final result = parseTrilingualAnalysisJson('{"en":"only english"}');
      expect(result['en'], 'only english');
    });

    test('throws when no locale fields are present', () {
      expect(
        () => parseTrilingualAnalysisJson('{"foo":"bar"}'),
        throwsFormatException,
      );
    });
  });
}
