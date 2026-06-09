import 'package:flutter_test/flutter_test.dart';
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
}
