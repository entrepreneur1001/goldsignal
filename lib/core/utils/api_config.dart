/// API keys are supplied at build/run time — never commit real values.
///
/// Local: copy [secrets.json.example] to `secrets.json` (gitignored), then run:
///   flutter run --dart-define-from-file=secrets.json
///
/// CI: inject the same keys via `--dart-define=KEY=value` or your secret store.
class ApiConfig {
  static const String metalPriceApiKey = String.fromEnvironment(
    'METAL_PRICE_API_KEY',
    defaultValue: '',
  );

  static const String exchangeRateApiKey = String.fromEnvironment(
    'EXCHANGE_RATE_API_KEY',
    defaultValue: '',
  );

  static const String openAiApiKey = String.fromEnvironment(
    'OPENAI_API_KEY',
    defaultValue: '',
  );

  static const int metalApiDailyLimit = 3;
  static const int currencyApiDailyLimit = 50;
  static const int userRefreshDailyLimit = 10;
  static const int chatMessagesDailyLimit = 50;

  static const Duration priceCacheDuration = Duration(minutes: 5);
  static const Duration historicalCacheDuration = Duration(hours: 24);
  static const Duration currencyCacheDuration = Duration(days: 7);
}
