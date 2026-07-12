import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/api_config.dart';
import '../crash/crash_reporter.dart';
import '../firebase/firestore_price_service.dart';
import 'gold_price_scraper.dart';

class MetalPriceApiService {
  final Dio _dio = Dio();
  final String baseUrl = 'https://api.metalpriceapi.com/v1';
  final FirestorePriceService _firestoreService = FirestorePriceService();
  final GoldPriceScraper _scraper = GoldPriceScraper();
  late Box _cacheBox;

  MetalPriceApiService() {
    _initializeService();
  }
  
  void _initializeService() {
    _cacheBox = Hive.box('goldPrices');
    _dio.options = BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    );
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        debugPrint('cURL: ${_buildCurl(options)}');
        handler.next(options);
      },
    ));
  }

  String _buildCurl(RequestOptions options) {
    final parts = <String>['curl'];
    parts.add('-X ${options.method}');
    options.headers.forEach((key, value) {
      parts.add("-H '$key: $value'");
    });
    if (options.data != null) {
      parts.add("-d '${options.data}'");
    }
    parts.add("'${options.uri}'");
    return parts.join(' ');
  }
  
  static const _cacheKey = 'latest_prices';

  /// How fresh the server-maintained shared cache must be for the client to
  /// use it directly instead of scraping. Slightly above the Cloud Function's
  /// 30-minute refresh cadence to tolerate run-time jitter.
  static const _sharedCacheMaxAge = Duration(minutes: 32);

  /// Return cached prices from Hive instantly (any age). Returns null if empty.
  MetalPricesResponse? getCachedPrices() {
    final cachedData = _cacheBox.get(_cacheKey);
    if (cachedData != null) {
      debugPrint('[Cache] Returning cached prices from Hive');
      return MetalPricesResponse.fromJson(cachedData['data']);
    }
    return null;
  }

  /// Fetch fresh prices for display.
  ///
  /// Prefers the server-maintained shared cache (kept current by the
  /// `refreshPricesScheduled` Cloud Function), falls back to a direct scrape,
  /// then to any stale cache. This client never writes to Firestore — the
  /// Cloud Function is the sole writer of the shared price documents.
  Future<MetalPricesResponse> fetchFreshPrices() async {
    try {
      // --- Primary: server-maintained shared cache (~30 min refresh) ---
      final shared = await _firestoreService.getCachedPrices(
        'latest',
        maxAge: _sharedCacheMaxAge,
      );
      if (shared != null) {
        debugPrint('[Cache] Using shared Firestore price cache');
        final apiData = _firestoreToApiFormat(shared);
        await _savePreviousAndCache(apiData);
        return MetalPricesResponse.fromJson(apiData);
      }

      // Prefer a slightly stale shared cache over a divergent client scrape so
      // users stay aligned with CF goldprice.org primary.
      final staleShared = await _firestoreService.getStalePrices('latest');
      if (staleShared != null) {
        debugPrint('[Cache] Using stale Firestore price cache before scrape');
        final apiData = _firestoreToApiFormat(staleShared);
        await _savePreviousAndCache(apiData);
        return MetalPricesResponse.fromJson(apiData);
      }

      // --- Fallback: direct scrape for an immediate fresh reading ---
      try {
        debugPrint('[Scraper] Scraping livepriceofgold.com');
        final scrapedData = await _scraper.scrapeLatestPrices();
        await _savePreviousAndCache(scrapedData);
        return MetalPricesResponse.fromJson(scrapedData);
      } catch (scrapeError) {
        debugPrint('[Scraper] Scraping failed: $scrapeError');
      }

      // --- Last resort: any stale cache (Firestore or Hive) ---
      return _fallbackToAnyCache();
    } catch (e) {
      debugPrint('Error fetching fresh prices: $e');
      return _fallbackToAnyCache();
    }
  }

  static const _prevBaselineHours = 20;

  /// Minimum/maximum age for a baseline snapshot to count as a 24h reference.
  static const baselineMinHours = 12;
  static const baselineMaxHours = 48;

  /// Returns true when [baselineAt] is absent (legacy docs) or 12–48h old.
  static bool isBaselineAgeValid(DateTime? baselineAt, [DateTime? now]) {
    if (baselineAt == null) return true;
    final hours = (now ?? DateTime.now()).difference(baselineAt).inHours;
    return hours >= baselineMinHours && hours <= baselineMaxHours;
  }

  /// Pure tier selection for 24h change. Null = no trustworthy baseline.
  static ({double change, double changePercent})? select24hChange({
    required double current,
    double? serverPrev,
    DateTime? serverPrevAt,
    double? historyPercent,
    double? hivePrev,
    DateTime? hivePrevAt,
    DateTime? now,
  }) {
    final checkTime = now ?? DateTime.now();

    if (serverPrev != null &&
        serverPrev != 0 &&
        isBaselineAgeValid(serverPrevAt, checkTime)) {
      final delta = current - serverPrev;
      return (change: delta, changePercent: (delta / serverPrev) * 100);
    }

    if (historyPercent != null) {
      final prev = current / (1 + historyPercent / 100);
      return (change: current - prev, changePercent: historyPercent);
    }

    if (hivePrev != null &&
        hivePrev != 0 &&
        isBaselineAgeValid(hivePrevAt, checkTime)) {
      final delta = current - hivePrev;
      return (change: delta, changePercent: (delta / hivePrev) * 100);
    }

    return null;
  }

  /// Save current cache as previous (for 24h change), then write new data.
  /// Previous baseline is only rotated when the outgoing cache is old enough,
  /// so change reflects ~24h movement instead of the last refresh delta.
  Future<void> _savePreviousAndCache(Map<String, dynamic> data) async {
    final oldCached = _cacheBox.get(_cacheKey);
    final prevKey = 'prev_v2_$_cacheKey';
    final existingPrev = _cacheBox.get(prevKey);

    if (oldCached != null) {
      final oldTs = _cacheEntryTime(oldCached);
      final prevTs =
          existingPrev != null ? _cacheEntryTime(existingPrev) : null;

      final shouldRotatePrev = oldTs != null &&
          (prevTs == null
              ? DateTime.now().difference(oldTs).inHours >= _prevBaselineHours
              : oldTs.difference(prevTs).inHours >= _prevBaselineHours);

      if (shouldRotatePrev) {
        await _cacheBox.put(prevKey, oldCached);
      }
    }
    await _saveToHive(data);
  }

  DateTime? _cacheEntryTime(Map entry) {
    final ts = entry['timestamp'];
    if (ts is String) return DateTime.tryParse(ts);
    return null;
  }

  /// 24h-style change vs the stored previous baseline (not the last refresh).
  ({double change, double changePercent}) computeChange({
    required double current,
    required double? Function(MetalPricesResponse response) previousPrice,
  }) {
    final prev = getPreviousPrices();
    if (prev == null) return (change: 0.0, changePercent: 0.0);

    final prevValue = previousPrice(prev);
    if (prevValue == null || prevValue == 0) {
      return (change: 0.0, changePercent: 0.0);
    }

    final delta = current - prevValue;
    return (
      change: delta,
      changePercent: (delta / prevValue) * 100,
    );
  }

  /// Save API response data to Hive local cache.
  Future<void> _saveToHive(Map<String, dynamic> data) async {
    await _cacheBox.put(_cacheKey, {
      'timestamp': DateTime.now().toIso8601String(),
      'data': data,
    });
  }

  /// Convert Firestore document format back to API response format.
  Map<String, dynamic> _firestoreToApiFormat(Map<String, dynamic> firestoreData) {
    dynamic prevRatesAt = firestoreData['prevRatesAt'];
    if (prevRatesAt is Timestamp) {
      prevRatesAt = prevRatesAt.toDate().toIso8601String();
    }

    return {
      'success': firestoreData['success'] ?? true,
      'base': firestoreData['base'] ?? 'USD',
      'timestamp': firestoreData['apiTimestamp'],
      'rates': firestoreData['rates'],
      // Keep the server's 24h baseline so the change can be computed reliably.
      'prevRates': firestoreData['prevRates'],
      'prevRatesAt': prevRatesAt,
    };
  }

  /// Reliable 24h change for the global market, in priority order:
  /// 1) server-maintained `prevRates` baseline carried on [response],
  /// 2) [historyPercent] computed from the app's recorded price history,
  /// 3) the local Hive `prev_v2` baseline (for scrape-sourced data).
  ///
  /// Returns null when no baseline in the 12–48h window exists.
  ({double change, double changePercent})? change24hFor({
    required MetalPricesResponse response,
    required String metal, // 'gold' | 'silver'
    required String currency,
    double? historyPercent,
  }) {
    final isGold = metal == 'gold';
    final current =
        isGold ? response.goldPriceIn(currency) : response.silverPriceIn(currency);
    if (current == null) return null;

    final serverPrev =
        isGold ? response.goldPreviousIn(currency) : response.silverPreviousIn(currency);

    final hivePrevResponse = getPreviousPrices();
    final hivePrev = hivePrevResponse == null
        ? null
        : (isGold
            ? hivePrevResponse.goldPriceIn(currency)
            : hivePrevResponse.silverPriceIn(currency));

    return select24hChange(
      current: current,
      serverPrev: serverPrev,
      serverPrevAt: response.previousRatesAt,
      historyPercent: historyPercent,
      hivePrev: hivePrev,
      hivePrevAt: getPreviousPricesTime(),
    );
  }

  /// Fallback: try Hive first, then Firestore (even if stale), then throw.
  Future<MetalPricesResponse> _fallbackToAnyCache() async {
    // Try Hive (even stale)
    final cachedData = _cacheBox.get(_cacheKey);
    if (cachedData != null) {
      return MetalPricesResponse.fromJson(cachedData['data']);
    }

    // Try Firestore (even stale)
    try {
      final doc = await _firestoreService.getStalePrices('latest');
      if (doc != null) {
        return MetalPricesResponse.fromJson(_firestoreToApiFormat(doc));
      }
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'Firestore stale price fallback failed');
    }

    throw Exception('Failed to fetch metal prices');
  }

  // Get the previous cached response for 24h change calculation
  MetalPricesResponse? getPreviousPrices() {
    final prevData = _cacheBox.get('prev_v2_$_cacheKey');
    if (prevData != null) {
      return MetalPricesResponse.fromJson(prevData['data']);
    }
    return null;
  }

  /// Timestamp of the Hive `prev_v2` baseline, if present.
  DateTime? getPreviousPricesTime() {
    final prevData = _cacheBox.get('prev_v2_$_cacheKey');
    if (prevData == null) return null;
    return _cacheEntryTime(prevData);
  }

  // Get historical prices
  Future<Map<String, dynamic>> getHistoricalPrices({
    required String metal,
    required String currency,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      // Use date-only ISO strings for the key. DateTime.toString() carries
      // microsecond precision, so the raw values would make every call a unique
      // key and the 24h cache below would never hit.
      final startKey = startDate.toIso8601String().split('T')[0];
      final endKey = endDate.toIso8601String().split('T')[0];
      final cacheKey = 'v2_historical_${metal}_${currency}_${startKey}_$endKey';
      final cachedData = _cacheBox.get(cacheKey);
      
      // Return cached data if available (24 hours cache for historical)
      if (cachedData != null) {
        final cacheTime = DateTime.parse(cachedData['timestamp']);
        final now = DateTime.now();
        
        if (now.difference(cacheTime).inHours < 24) {
          return cachedData['data'];
        }
      }

      if (ApiConfig.metalPriceApiKey.isEmpty) {
        debugPrint(
          '[Historical] METAL_PRICE_API_KEY empty — skipping metalpriceapi',
        );
        throw Exception('Historical price API is not configured');
      }
      
      final response = await _dio.get(
        '/timeframe',
        queryParameters: {
          'api_key': ApiConfig.metalPriceApiKey,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'base': 'USD',
          'currencies': currency == 'USD' ? metal : '$metal,$currency',
        },
      );
      
      // Cache the response
      await _cacheBox.put(cacheKey, {
        'timestamp': DateTime.now().toIso8601String(),
        'data': response.data,
      });
      
      return response.data;
    } catch (e) {
      debugPrint('Error fetching historical prices: $e');
      throw Exception('Failed to fetch historical prices');
    }
  }
  
  // Get supported currencies
  Future<List<Currency>> getSupportedCurrencies() async {
    try {
      final cacheKey = 'supported_currencies';
      final cachedData = _cacheBox.get(cacheKey);
      
      // Return cached data if available (7 days cache)
      if (cachedData != null) {
        final cacheTime = DateTime.parse(cachedData['timestamp']);
        final now = DateTime.now();
        
        if (now.difference(cacheTime).inDays < 7) {
          return (cachedData['data'] as List)
              .map((e) => Currency.fromJson(e))
              .toList();
        }
      }
      
      final response = await _dio.get(
        '/symbols',
        queryParameters: {
          'api_key': ApiConfig.metalPriceApiKey,
        },
      );
      
      final currencies = _parseCurrencies(response.data);
      
      // Cache the response
      await _cacheBox.put(cacheKey, {
        'timestamp': DateTime.now().toIso8601String(),
        'data': currencies.map((e) => e.toJson()).toList(),
      });
      
      return currencies;
    } catch (e) {
      debugPrint('Error fetching currencies: $e');
      
      // Return default currencies if API fails
      return _getDefaultCurrencies();
    }
  }
  
  List<Currency> _parseCurrencies(Map<String, dynamic> data) {
    final List<Currency> currencies = [];
    
    if (data['symbols'] != null) {
      data['symbols'].forEach((code, name) {
        currencies.add(Currency(
          code: code,
          name: name,
          flag: _getFlagEmoji(code),
          isArabCurrency: _isArabCurrency(code),
        ));
      });
    }
    
    // Sort currencies with priority
    currencies.sort((a, b) {
      // USD first
      if (a.code == 'USD') return -1;
      if (b.code == 'USD') return 1;
      
      // Arab currencies second
      if (a.isArabCurrency && !b.isArabCurrency) return -1;
      if (!a.isArabCurrency && b.isArabCurrency) return 1;
      
      // Alphabetical for the rest
      return a.code.compareTo(b.code);
    });
    
    return currencies;
  }
  
  bool _isArabCurrency(String code) {
    const arabCurrencies = [
      'SAR', 'AED', 'EGP', 'KWD', 'BHD', 'OMR', 'QAR',
      'JOD', 'LBP', 'IQD', 'SYP', 'YER', 'LYD', 'TND',
      'DZD', 'MAD', 'SDG',
    ];
    return arabCurrencies.contains(code);
  }
  
  String _getFlagEmoji(String code) {
    const flags = {
      'USD': '🇺🇸',
      'SAR': '🇸🇦',
      'AED': '🇦🇪',
      'EGP': '🇪🇬',
      'KWD': '🇰🇼',
      'BHD': '🇧🇭',
      'OMR': '🇴🇲',
      'QAR': '🇶🇦',
      'JOD': '🇯🇴',
      'LBP': '🇱🇧',
      'IQD': '🇮🇶',
      'SYP': '🇸🇾',
      'YER': '🇾🇪',
      'LYD': '🇱🇾',
      'TND': '🇹🇳',
      'DZD': '🇩🇿',
      'MAD': '🇲🇦',
      'SDG': '🇸🇩',
      'EUR': '🇪🇺',
      'GBP': '🇬🇧',
      'JPY': '🇯🇵',
      'CNY': '🇨🇳',
      'INR': '🇮🇳',
      'PKR': '🇵🇰',
      'TRY': '🇹🇷',
    };
    return flags[code] ?? '💱';
  }
  
  List<Currency> _getDefaultCurrencies() {
    return [
      Currency(code: 'USD', name: 'US Dollar', flag: '🇺🇸', isArabCurrency: false),
      Currency(code: 'SAR', name: 'Saudi Riyal', flag: '🇸🇦', isArabCurrency: true),
      Currency(code: 'AED', name: 'UAE Dirham', flag: '🇦🇪', isArabCurrency: true),
      Currency(code: 'EGP', name: 'Egyptian Pound', flag: '🇪🇬', isArabCurrency: true),
      Currency(code: 'KWD', name: 'Kuwaiti Dinar', flag: '🇰🇼', isArabCurrency: true),
      Currency(code: 'EUR', name: 'Euro', flag: '🇪🇺', isArabCurrency: false),
      Currency(code: 'GBP', name: 'British Pound', flag: '🇬🇧', isArabCurrency: false),
    ];
  }
}

// Models
class MetalPricesResponse {
  final bool success;
  final String base;
  final DateTime timestamp;
  final Map<String, double> rates;

  /// Server-maintained snapshot of [rates] from ~24h ago (Cloud Function
  /// `prevRates`). Used as the reliable 24h baseline when present.
  final Map<String, double>? previousRates;

  /// When [previousRates] was last rotated (Firestore `prevRatesAt`).
  final DateTime? previousRatesAt;

  MetalPricesResponse({
    required this.success,
    required this.base,
    required this.timestamp,
    required this.rates,
    this.previousRates,
    this.previousRatesAt,
  });

  static Map<String, double>? _parseRates(dynamic raw) {
    if (raw == null) return null;
    final out = <String, double>{};
    (raw as Map).forEach((key, value) {
      if (value is num) out[key.toString()] = value.toDouble();
    });
    return out.isEmpty ? null : out;
  }

  static DateTime? _parseDateTime(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is num) {
      final ms = raw > 1e12 ? raw.toInt() : (raw * 1000).toInt();
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    return null;
  }

  factory MetalPricesResponse.fromJson(Map json) {
    final rates = _parseRates(json['rates']) ?? <String, double>{};

    return MetalPricesResponse(
      success: json['success'] ?? true,
      base: json['base'] ?? 'USD',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt() * 1000)
          : DateTime.now(),
      rates: rates,
      previousRates: _parseRates(json['prevRates']),
      previousRatesAt: _parseDateTime(json['prevRatesAt']),
    );
  }

  static double? _priceIn(Map<String, double>? r, String usdKey, String currency) {
    if (r == null) return null;
    final usd = r[usdKey];
    if (usd == null) return null;
    if (currency == 'USD') return usd;
    final rate = r[currency];
    if (rate == null) return null;
    return usd * rate;
  }

  /// Gold/silver price ~24h ago in [currency], from the server baseline.
  double? goldPreviousIn(String currency) =>
      _priceIn(previousRates, 'USDXAU', currency);
  double? silverPreviousIn(String currency) =>
      _priceIn(previousRates, 'USDXAG', currency);
  
  // Gold/silver price in USD
  double? get goldPriceUsd => rates['USDXAU'];
  double? get silverPriceUsd => rates['USDXAG'];

  // Gold price converted to any currency
  double? goldPriceIn(String currency) {
    final usdGold = rates['USDXAU'];
    if (usdGold == null) return null;
    if (currency == 'USD') return usdGold;
    final rate = rates[currency]; // e.g., SAR = 3.75 per 1 USD
    if (rate == null) return null;
    return usdGold * rate;
  }

  // Silver price converted to any currency
  double? silverPriceIn(String currency) {
    final usdSilver = rates['USDXAG'];
    if (usdSilver == null) return null;
    if (currency == 'USD') return usdSilver;
    final rate = rates[currency];
    if (rate == null) return null;
    return usdSilver * rate;
  }
}

class Currency {
  final String code;
  final String name;
  final String flag;
  final bool isArabCurrency;
  
  Currency({
    required this.code,
    required this.name,
    this.flag = '',
    required this.isArabCurrency,
  });
  
  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'flag': flag,
    'isArabCurrency': isArabCurrency,
  };
  
  factory Currency.fromJson(Map<String, dynamic> json) {
    return Currency(
      code: json['code'],
      name: json['name'],
      flag: json['flag'] as String? ?? '',
      isArabCurrency: json['isArabCurrency'],
    );
  }
}