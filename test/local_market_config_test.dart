import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/shared/local_market/local_market_config.dart';

void main() {
  group('LocalMarketConfig', () {
    test('isLocalCurrency', () {
      expect(LocalMarketConfig.isLocalCurrency('EGP'), isTrue);
      expect(LocalMarketConfig.isLocalCurrency('INR'), isTrue);
      expect(LocalMarketConfig.isLocalCurrency('USD'), isFalse);
    });

    test('defaultGoldKarat', () {
      expect(LocalMarketConfig.defaultGoldKarat('EGP'), 21);
      expect(LocalMarketConfig.defaultGoldKarat('INR'), 22);
      expect(LocalMarketConfig.defaultGoldKarat('USD'), 24);
    });

    test('goldKarats', () {
      expect(LocalMarketConfig.goldKarats('INR'), ['24', '22', '18']);
      expect(LocalMarketConfig.goldKarats('EGP'), contains('21'));
    });

    test('silverKarats', () {
      expect(LocalMarketConfig.silverKarats('INR'), ['999']);
      expect(LocalMarketConfig.silverKarats('EGP'), contains('925'));
    });

    test('hasBuySellSide', () {
      expect(LocalMarketConfig.hasBuySellSide('EGP'), isTrue);
      expect(LocalMarketConfig.hasBuySellSide('INR'), isFalse);
    });

    test('historySource', () {
      expect(LocalMarketConfig.historySource('EGP'), 'isagha');
      expect(LocalMarketConfig.historySource('INR'), 'goodreturns');
      expect(LocalMarketConfig.historySource('USD'), 'livepriceofgold');
    });
  });
}
