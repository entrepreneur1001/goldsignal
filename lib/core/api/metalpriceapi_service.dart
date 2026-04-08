import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../utils/api_config.dart';

class MetalPriceApiService {
  final Dio _dio = Dio();
  final String baseUrl = 'https://api.metalpriceapi.com/v1';
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
  }
  
  // Get latest gold and silver prices
  Future<MetalPricesResponse> getLatestPrices({
    required String currency,
    bool forceRefresh = false,
  }) async {
    try {
      // Check cache first (5 minutes cache)
      final cacheKey = 'latest_prices_$currency';
      final cachedData = _cacheBox.get(cacheKey);
      
      if (!forceRefresh && cachedData != null) {
        final cacheTime = DateTime.parse(cachedData['timestamp']);
        final now = DateTime.now();
        
        // Return cached data if less than 5 minutes old
        if (now.difference(cacheTime).inMinutes < 5) {
          return MetalPricesResponse.fromJson(cachedData['data']);
        }
      }
      
      // Fetch from API
      final response = await _dio.get(
        '/latest',
        queryParameters: {
          'api_key': ApiConfig.metalPriceApiKey,
          'base': 'USD',
          'currencies': '$currency,XAU,XAG',
        },
      );
      
      // Cache the response
      await _cacheBox.put(cacheKey, {
        'timestamp': DateTime.now().toIso8601String(),
        'data': response.data,
      });
      
      return MetalPricesResponse.fromJson(response.data);
    } catch (e) {
      print('Error fetching metal prices: $e');
      
      // Return cached data if available
      final cacheKey = 'latest_prices_$currency';
      final cachedData = _cacheBox.get(cacheKey);
      
      if (cachedData != null) {
        return MetalPricesResponse.fromJson(cachedData['data']);
      }
      
      throw Exception('Failed to fetch metal prices');
    }
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
  
  factory MetalPricesResponse.fromJson(Map<String, dynamic> json) {
    return MetalPricesResponse(
      success: json['success'] ?? true,
      base: json['base'] ?? 'USD',
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] * 1000)
          : DateTime.now(),
      rates: Map<String, double>.from(json['rates'] ?? {}),
    );
  }
  
  double? get goldPrice => rates['XAU'];
  double? get silverPrice => rates['XAG'];
  
  double? getPriceInCurrency(String currency) => rates[currency];
}

class Currency {
  final String code;
  final String name;
  final String flag;
  final bool isArabCurrency;
  
  Currency({
    required this.code,
    required this.name,
    required this.flag,
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
      flag: json['flag'],
      isArabCurrency: json['isArabCurrency'],
    );
  }
}