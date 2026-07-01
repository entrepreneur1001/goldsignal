import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/shared/widgets/ad_list_builder.dart';

void main() {
  group('adListItemCount', () {
    test('empty content has no slots', () {
      expect(adListItemCount(0), 0);
    });

    test('short lists append one trailing ad', () {
      expect(adListItemCount(1), 2);
      expect(adListItemCount(2), 3);
    });

    test('full lists insert ads every 3 items but not after the last', () {
      expect(adListItemCount(3), 3);
      expect(adListItemCount(4), 5);
      expect(adListItemCount(6), 7);
      expect(adListItemCount(9), 11);
    });
  });

  group('adListIndexIsAd', () {
    test('short list ad is only at the end', () {
      expect(adListIndexIsAd(0, 1), isFalse);
      expect(adListIndexIsAd(1, 1), isTrue);
      expect(adListIndexIsAd(2, 2), isTrue);
    });

    test('periodic ads skip the final group of exactly 3', () {
      expect(adListIndexIsAd(3, 3), isFalse);
      expect(adListIndexIsAd(3, 4), isTrue);
      expect(adListIndexIsAd(7, 6), isFalse);
      expect(adListIndexIsAd(3, 6), isTrue);
    });
  });

  group('adListContentIndex', () {
    test('maps list indices back to content indices', () {
      expect(adListContentIndex(4, 4), 3);
      expect(adListContentIndex(6, 6), 5);
    });
  });
}
