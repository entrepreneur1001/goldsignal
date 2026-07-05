import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../shared/models/local_market_prices.dart';

class GoodreturnsPriceScraper {
  static const _url = 'https://www.goodreturns.in/gold-rates/';
  static const _cacheKey = 'india_latest';

  final Dio _dio;

  GoodreturnsPriceScraper()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; GoldSignal/1.0)',
            'Accept-Language': 'en-IN,en;q=0.9',
          },
        ));

  LocalMarketPrices? getCachedPrices() {
    if (!Hive.isBoxOpen('localMarketPrices')) return null;
    final cached = Hive.box('localMarketPrices').get(_cacheKey);
    if (cached == null) return null;
    return LocalMarketPrices.fromJson(Map<String, dynamic>.from(cached));
  }

  Future<LocalMarketPrices> fetchLatestPrices() async {
    final response = await _dio.get<String>(_url);
    final html = response.data;
    if (html == null || html.isEmpty) {
      throw const FormatException('Empty response from Goodreturns');
    }

    final prices = _parseKaratPrices(html);
    if (prices['22'] == null) {
      throw const FormatException('Missing 22K gold price from Goodreturns');
    }
    if (prices.length < 3) {
      throw FormatException(
        'Too few karat prices parsed: ${prices.length}',
      );
    }

    final changes = _parseDailyChanges(html);
    final gold = _karatsInOrder
        .where((k) => prices[k] != null)
        .map((karat) {
          final price = prices[karat]!;
          final change = changes[karat] ?? 0.0;
          final previous = price - change;
          final changePercent =
              previous != 0 ? (change / previous) * 100 : 0.0;
          return LocalKaratPrice(
            karat: karat,
            sellPerGram: price,
            buyPerGram: price,
            change: change,
            changePercent: changePercent,
          );
        })
        .toList();

    final result = LocalMarketPrices(
      country: 'IN',
      currency: 'INR',
      source: 'goodreturns',
      gold: gold,
      silver: const [],
      updatedAt: DateTime.now(),
    );

    await _cache(result);
    return result;
  }

  static const _karatsInOrder = ['24', '22', '18'];

  Map<String, double> _parseKaratPrices(String html) {
    final fromJs = _parseFromJsObject(html);
    if (fromJs.length >= 3) return fromJs;

    final document = html_parser.parse(html);
    final fromDom = _parseFromPriceSpans(document);
    if (fromDom.length >= 3) return fromDom;

    if (fromJs.isNotEmpty) return fromJs;
    if (fromDom.isNotEmpty) return fromDom;
    return {};
  }

  Map<String, double> _parseFromJsObject(String html) {
    final match = RegExp(
      r'currentMetalPrices\s*=\s*\{([^}]+)\}',
      dotAll: true,
    ).firstMatch(html);
    if (match == null) return {};

    final block = match.group(1)!;
    final prices = <String, double>{};
    for (final karat in _karatsInOrder) {
      final priceMatch = RegExp("'$karat'\\s*:\\s*(\\d+)").firstMatch(block);
      if (priceMatch != null) {
        prices[karat] = double.parse(priceMatch.group(1)!);
      }
    }
    return prices;
  }

  Map<String, double> _parseFromPriceSpans(Document document) {
    final prices = <String, double>{};
    for (final karat in _karatsInOrder) {
      final span = document.querySelector('#${karat}K-price');
      if (span == null) continue;
      final value = _parseInrPrice(span.text);
      if (value != null) prices[karat] = value;
    }
    return prices;
  }

  Map<String, double> _parseDailyChanges(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('tbody.tablebody tr');
    if (rows.isEmpty) return {};

    final cells = rows.first.querySelectorAll('td');
    if (cells.length < 3) return {};

    return {
      '24': _parseChangeSpan(cells[1]),
      '22': _parseChangeSpan(cells[2]),
    };
  }

  double _parseChangeSpan(Element cell) {
    final span = cell.querySelector('span');
    if (span == null) return 0;
    final match = RegExp(r'\(([+\-]?\d+)\)').firstMatch(span.text);
    if (match == null) return 0;
    return double.parse(match.group(1)!);
  }

  double? _parseInrPrice(String raw) {
    final cleaned = raw
        .replaceAll('\u20b9', '')
        .replaceAll('₹', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  Future<void> _cache(LocalMarketPrices prices) async {
    if (!Hive.isBoxOpen('localMarketPrices')) {
      await Hive.openBox('localMarketPrices');
    }
    await Hive.box('localMarketPrices').put(_cacheKey, prices.toJson());
  }
}
