import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/core/api/metalpriceapi_service.dart';
import 'package:goldsignal/core/config/app_remote_config.dart';
import 'package:goldsignal/features/zakat/zakat.dart';

void main() {
  group('isVersionLower', () {
    test('lower patch is lower', () {
      expect(isVersionLower('1.2.0', '1.2.1'), isTrue);
    });
    test('equal is not lower', () {
      expect(isVersionLower('1.2.0', '1.2.0'), isFalse);
    });
    test('higher is not lower', () {
      expect(isVersionLower('1.3.0', '1.2.9'), isFalse);
    });
    test('compares numerically, not lexically', () {
      expect(isVersionLower('1.2.0', '1.10.0'), isTrue);
    });
    test('ignores build suffix', () {
      expect(isVersionLower('1.2.0+5', '1.2.0'), isFalse);
    });
    test('empty target returns false (no gating)', () {
      expect(isVersionLower('1.0.0', ''), isFalse);
    });
  });

  group('Zakat', () {
    test('below nisab → not due, zero owed', () {
      final r = Zakat.compute(totalWealth: 100, nisabValue: 500);
      expect(r.isDue, isFalse);
      expect(r.amount, 0);
    });
    test('at/above nisab → 2.5% owed', () {
      final r = Zakat.compute(totalWealth: 1000, nisabValue: 500);
      expect(r.isDue, isTrue);
      expect(r.amount, closeTo(25, 1e-9));
    });
    test('silver nisab value = 595g × silver price', () {
      final v = Zakat.nisabValue(
        basis: NisabBasis.silver,
        gold24PerGram: 60,
        silverPerGram: 0.8,
      );
      expect(v, closeTo(595 * 0.8, 1e-9));
    });
    test('gold nisab value = 85g × gold price', () {
      final v = Zakat.nisabValue(
        basis: NisabBasis.gold,
        gold24PerGram: 60,
        silverPerGram: 0.8,
      );
      expect(v, closeTo(85 * 60, 1e-9));
    });
  });

  group('MetalPricesResponse 24h baseline (server prevRates)', () {
    final resp = MetalPricesResponse.fromJson({
      'rates': {'USDXAU': 2000.0, 'USDXAG': 25.0, 'SAR': 3.75},
      'prevRates': {'USDXAU': 1980.0, 'USDXAG': 25.5, 'SAR': 3.75},
      'base': 'USD',
    });

    test('goldPreviousIn USD reads the prev baseline', () {
      expect(resp.goldPreviousIn('USD'), 1980.0);
    });
    test('goldPreviousIn converts to other currencies', () {
      expect(resp.goldPreviousIn('SAR'), closeTo(1980.0 * 3.75, 1e-6));
    });
    test('silverPreviousIn USD reads the prev baseline', () {
      expect(resp.silverPreviousIn('USD'), 25.5);
    });
    test('previous is null when prevRates absent (→ Hive fallback path)', () {
      final r = MetalPricesResponse.fromJson({
        'rates': {'USDXAU': 2000.0},
      });
      expect(r.previousRates, isNull);
      expect(r.goldPreviousIn('USD'), isNull);
    });
    test('24h % is computed from current vs prev baseline', () {
      final cur = resp.goldPriceIn('USD')!;
      final prev = resp.goldPreviousIn('USD')!;
      expect((cur - prev) / prev * 100, closeTo(1.0101, 0.001));
    });
  });
}
