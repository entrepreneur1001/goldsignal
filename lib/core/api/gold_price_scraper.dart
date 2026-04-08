import 'package:dio/dio.dart';
import 'package:html/parser.dart' as html_parser;

class GoldPriceScraper {
  static const _baseUrl = 'https://www.livepriceofgold.com';
  static const _goldPagePath = '/usa-gold-price.html';
  static const _exchangeRatePath = '/exchange-rate';

  // Map of app currency key → website data-price attribute
  static const _currencySelectors = {
    'SAR': 'USDSAR',
    'AED': 'USDAED',
    'EGP': 'USDEGP',
    'KWD': 'USDKWD',
    'BHD': 'USDBHD',
    'OMR': 'USDOMR',
    'QAR': 'USDQAR',
    'JOD': 'USDJOD',
    'EUR': 'USDEUR',
    'GBP': 'USDGBP',
    'JPY': 'USDJPY',
    'CNY': 'USDCNY',
    'INR': 'USDINR',
    'PKR': 'USDPKR',
    'TRY': 'USDTL',
  };

  final Dio _dio;

  GoldPriceScraper() : _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 8),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': 'Mozilla/5.0 (compatible; GoldSignal/1.0)',
    },
  ));

  /// Scrape latest prices and return in MetalpriceAPI response format.
  Future<Map<String, dynamic>> scrapeLatestPrices() async {
    final results = await Future.wait([
      _dio.get('$_baseUrl$_goldPagePath'),
      _dio.get('$_baseUrl$_exchangeRatePath'),
    ]);

    final goldSilver = _parseGoldSilverPrices(results[0].data as String);
    final exchangeRates = _parseExchangeRates(results[1].data as String);

    // Validate critical data
    if (goldSilver['USDXAU'] == null || goldSilver['USDXAG'] == null) {
      throw FormatException('Failed to scrape gold/silver prices');
    }
    if (exchangeRates.length < 5) {
      throw FormatException('Too few exchange rates scraped: ${exchangeRates.length}');
    }

    return {
      'success': true,
      'base': 'USD',
      'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'rates': {
        ...goldSilver,
        ...exchangeRates,
      },
    };
  }

  Map<String, double> _parseGoldSilverPrices(String html) {
    final document = html_parser.parse(html);
    final rates = <String, double>{};

    final goldEl = document.querySelector('[data-price="XAUUSD"]');
    if (goldEl != null) {
      final price = _cleanPrice(goldEl.text);
      if (price != null && price > 500 && price < 50000) {
        rates['USDXAU'] = price;
      }
    }

    final silverEl = document.querySelector('[data-price="XAGUSD"]');
    if (silverEl != null) {
      final price = _cleanPrice(silverEl.text);
      if (price != null && price > 5 && price < 500) {
        rates['USDXAG'] = price;
      }
    }

    return rates;
  }

  Map<String, double> _parseExchangeRates(String html) {
    final document = html_parser.parse(html);
    final rates = <String, double>{};

    for (final entry in _currencySelectors.entries) {
      final el = document.querySelector('[data-price="${entry.value}"]');
      if (el != null) {
        final rate = _cleanPrice(el.text);
        if (rate != null && rate > 0) {
          rates[entry.key] = rate;
        }
      }
    }

    return rates;
  }

  double? _cleanPrice(String raw) {
    final cleaned = raw.replaceAll(',', '').replaceAll(' ', '').trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }
}
