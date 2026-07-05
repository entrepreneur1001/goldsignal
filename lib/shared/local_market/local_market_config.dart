/// Shared rules for Egypt (EGP) and India (INR) local market modes.
class LocalMarketConfig {
  LocalMarketConfig._();

  static bool isLocalCurrency(String currency) =>
      currency == 'EGP' || currency == 'INR';

  static int defaultGoldKarat(String currency) => switch (currency) {
        'EGP' => 21,
        'INR' => 22,
        _ => 24,
      };

  static String defaultGoldKaratStr(String currency) =>
      '${defaultGoldKarat(currency)}';

  static List<String> goldKarats(String currency) => switch (currency) {
        'INR' => const ['24', '22', '18'],
        _ => const ['24', '22', '21', '18'],
      };

  static bool hasLocalSilver(String currency) =>
      currency == 'EGP' || currency == 'INR';

  static List<String> silverKarats(String currency) => switch (currency) {
        'EGP' => const ['999', '925', '900', '800'],
        _ => const ['999'],
      };

  static String defaultSilverKarat(String currency) => '999';

  static bool hasBuySellSide(String currency) => currency == 'EGP';

  static String historySource(String currency) => switch (currency) {
        'EGP' => 'isagha',
        'INR' => 'goodreturns',
        _ => 'livepriceofgold',
      };
}
