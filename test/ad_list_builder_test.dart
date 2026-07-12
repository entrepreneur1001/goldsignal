import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/shared/widgets/ad_list_builder.dart';

void main() {
  group('adListItemCount', () {
    test('empty content has no slots', () {
      expect(adListItemCount(0), 0);
    });

    test('fewer than min content has no ad', () {
      expect(adListItemCount(1), 1);
      expect(adListItemCount(3), 3);
    });

    test('at least min content inserts one ad', () {
      expect(adListItemCount(4), 5);
      expect(adListItemCount(6), 7);
      expect(adListItemCount(9), 10);
    });
  });

  group('adListIndexIsAd', () {
    test('short lists never show an ad', () {
      expect(adListIndexIsAd(0, 1), isFalse);
      expect(adListIndexIsAd(1, 1), isFalse);
      expect(adListIndexIsAd(3, 3), isFalse);
    });

    test('ad sits after the first four content items', () {
      expect(adListIndexIsAd(3, 4), isFalse);
      expect(adListIndexIsAd(4, 4), isTrue);
      expect(adListIndexIsAd(4, 6), isTrue);
      expect(adListIndexIsAd(5, 6), isFalse);
    });
  });

  group('adListContentIndex', () {
    test('maps list indices back to content indices', () {
      expect(adListContentIndex(0, 4), 0);
      expect(adListContentIndex(3, 4), 3);
      expect(adListContentIndex(5, 6), 4);
      expect(adListContentIndex(6, 6), 5);
    });

    test('short lists map 1:1', () {
      expect(adListContentIndex(2, 3), 2);
    });
  });
}
