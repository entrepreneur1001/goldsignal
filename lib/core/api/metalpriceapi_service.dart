import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/api_config.dart';
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
        print('cURL: ${_buildCurl(options)}');
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
  
  // All supported currencies fetched in a single API call
  static const _allCurrencies = 'XAU,XAG,SAR,AED,EGP,KWD,BHD,OMR,QAR,JOD,EUR,GBP,JPY,CNY,INR,PKR,TRY';
  static const _cacheKey = 'latest_prices';

  /// Return cached prices from Hive instantly (any age). Returns null if empty.
  MetalPricesResponse? getCachedPrices() {
    final cachedData = _cacheBox.get(_cacheKey);
    if (cachedData != null) {
      print('[Cache] Returning cached prices from Hive');
      return MetalPricesResponse.fromJson(cachedData['data']);
    }
    return null;
  }

  /// Fetch fresh prices: Scraper → Firestore (race guard) → API fallback.
  /// Always goes to the network. Updates Hive + Firestore caches.
  Future<MetalPricesResponse> fetchFreshPrices() async {
    try {
      // Race guard: check if another user just refreshed Firestore
      final freshCheck = await _firestoreService.checkAndLock('latest');
      if (freshCheck != null) {
        print('[Cache] Race guard HIT - another user just refreshed');
        final apiData = _firestoreToApiFormat(freshCheck);
        await _savePreviousAndCache(apiData);
        return MetalPricesResponse.fromJson(apiData);
      }

      // --- Primary: Web Scraper ---
      try {
        print('[Scraper] Scraping livepriceofgold.com');
        final scrapedData = await _scraper.scrapeLatestPrices();
        await _savePreviousAndCache(scrapedData);
        return MetalPricesResponse.fromJson(scrapedData);
      } catch (scrapeError) {
        print('[Scraper] Scraping failed: $scrapeError');
      }

      // --- Fallback: MetalpriceAPI ---
      final allowed = await _firestoreService.tryIncrementApiCallCount();
      if (!allowed) {
        print('[API] Daily quota (100) exhausted.');
        return _fallbackToAnyCache();
      }

      print('[API] Falling back to MetalpriceAPI');
      final response = await _dio.get(
        '/latest',
        queryParameters: {
          'api_key': ApiConfig.metalPriceApiKey,
          'base': 'USD',
          'currencies': _allCurrencies,
        },
      );

      await _savePreviousAndCache(response.data);
      return MetalPricesResponse.fromJson(response.data);
    } catch (e) {
      print('Error fetching fresh prices: $e');
      return _fallbackToAnyCache();
    }
  }

  /// Save current cache as previous (for 24h change), then write new data.
  Future<void> _savePreviousAndCache(Map<String, dynamic> data) async {
    final oldCached = _cacheBox.get(_cacheKey);
    if (oldCached != null) {
      await _cacheBox.put('prev_$_cacheKey', oldCached);
    }
    await _firestoreService.cachePrices('latest', data);
    await _saveToHive(data);
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
    return {
      'success': firestoreData['success'] ?? true,
      'base': firestoreData['base'] ?? 'USD',
      'timestamp': firestoreData['apiTimestamp'],
      'rates': firestoreData['rates'],
    };
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
    } catch (_) {}

    throw Exception('Failed to fetch metal prices');
  }

  // Get the previous cached response for 24h change calculation
  MetalPricesResponse? getPreviousPrices() {
    final prevData = _cacheBox.get('prev_$_cacheKey');
    if (prevData != null) {
      return MetalPricesResponse.fromJson(prevData['data']);
    }
    return null;
  }

  // Get historical prices
  Future<Map<String, dynamic>> getHistoricalPrices({
    required String metal,
    required String currency,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final cacheKey = 'historical_${metal}_${currency}_${startDate}_$endDate';
      final cachedData = _cacheBox.get(cacheKey);
      
      // Return cached data if available (24 hours cache for historical)
      if (cachedData != null) {
        final cacheTime = DateTime.parse(cachedData['timestamp']);
        final now = DateTime.now();
        
        if (now.difference(cacheTime).inHours < 24) {
          return cachedData['data'];
        }
      }
      
      final response = await _dio.get(
        '/timeframe',
        queryParameters: {
          'api_key': ApiConfig.metalPriceApiKey,
          'start_date': startDate.toIso8601String().split('T')[0],
          'end_date': endDate.toIso8601String().split('T')[0],
          'base': metal,
          'currencies': currency,
        },
      );
      
      // Cache the response
      await _cacheBox.put(cacheKey, {
        'timestamp': DateTime.now().toIso8601String(),
        'data': response.data,
      });
      
      return response.data;
    } catch (e) {
      print('Error fetching historical prices: $e');
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
      print('Error fetching currencies: $e');
      
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
  
  MetalPricesResponse({
    required this.success,
    required this.base,
    required this.timestamp,
    required this.rates,
  });
  
  factory MetalPricesResponse.fromJson(Map json) {
    final rawRates = json['rates'] ?? {};
    final rates = <String, double>{};
    rawRates.forEach((key, value) {
      rates[key.toString()] = (value as num).toDouble();
    });

    return MetalPricesResponse(
      success: json['success'] ?? true,
      base: json['base'] ?? 'USD',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch((json['timestamp'] as num).toInt() * 1000)
          : DateTime.now(),
      rates: rates,
    );
  }
  
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