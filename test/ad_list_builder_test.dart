import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/shared/widgets/ad_list_builder.dart';

void main() {
  group('adListItemCount', () {
    test('empty content has no slots', () {
      expect(adListItemCount(0), 0);
    });

    test('single-item list appends one trailing ad', () {
      expect(adListItemCount(1), 2);
    });

    test('two-item list has no ad slot', () {
      expect(adListItemCount(2), 2);
    });

    test('full lists insert ads every 2 items but not after the last', () {
      expect(adListItemCount(3), 4);
      expect(adListItemCount(4), 5);
      expect(adListItemCount(6), 8);
      expect(adListItemCount(9), 13);
    });
  });

  group('adListIndexIsAd', () {
    test('short list ad is only at the end', () {
      expect(adListIndexIsAd(0, 1), isFalse);
      expect(adListIndexIsAd(1, 1), isTrue);
    });

    test('two items have no ad slot', () {
      expect(adListIndexIsAd(0, 2), isFalse);
      expect(adListIndexIsAd(1, 2), isFalse);
    });

    test('periodic ads skip the final group of exactly 2', () {
      expect(adListIndexIsAd(2, 2), isFalse);
      expect(adListIndexIsAd(2, 3), isTrue);
      expect(adListIndexIsAd(5, 6), isTrue);
      expect(adListIndexIsAd(2, 4), isTrue);
    });
  });

  group('adListContentIndex', () {
    test('maps list indices back to content indices', () {
      expect(adListContentIndex(3, 4), 2);
      expect(adListContentIndex(4, 6), 3);
    });
  });
}
