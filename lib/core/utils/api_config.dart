/// API keys are supplied at build/run time — never commit real values.
///
/// JSON keys in `secrets.json` must match these compile-time names exactly
/// (same strings as in [String.fromEnvironment]):
///   METAL_PRICE_API_KEY  → https://metalpriceapi.com (used by [MetalPriceApiService])
///   GROQ_API_KEY         → https://console.groq.com/keys (used by chatbot)
///
/// Local: `cp secrets.json.example secrets.json`, fill in values, then:
///   flutter run --dart-define-from-file=secrets.json
///
/// CI: `--dart-define=METAL_PRICE_API_KEY=...` etc., or a secrets file from your vault.
class ApiConfig {
  /// metalpriceapi.com — same key as query param `api_key` in API requests.
  static const String metalPriceApiKey = String.fromEnvironment(
    'METAL_PRICE_API_KEY',
    defaultValue: '',
  );

  /// Groq API key (`gsk_...`).
  static const String groqApiKey = String.fromEnvironment(
    'GROQ_API_KEY',
    defaultValue: '',
  );

  static const int metalApiDailyLimit = 100;
  static const int chatMessagesDailyLimit = 50;

  static const Duration hiveCacheDuration = Duration(minutes: 5);
  static const Duration firestoreCacheDuration = Duration(minutes: 15);
  static const Duration historicalCacheDuration = Duration(hours: 24);
  static const Duration currencyCacheDuration = Duration(days: 7);
}
