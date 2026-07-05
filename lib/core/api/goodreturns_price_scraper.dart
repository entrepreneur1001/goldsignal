import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import '../../shared/models/local_market_prices.dart';

class GoodreturnsPriceScraper {
  static const _goldUrl = 'https://www.goodreturns.in/gold-rates/';
  static const _silverUrl = 'https://www.goodreturns.in/silver-rates/';
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
    final responses = await Future.wait([
      _dio.get<String>(_goldUrl),
      _dio.get<String>(_silverUrl),
    ]);

    final goldHtml = responses[0].data;
    final silverHtml = responses[1].data;
    if (goldHtml == null || goldHtml.isEmpty) {
      throw const FormatException('Empty response from Goodreturns gold page');
    }
    if (silverHtml == null || silverHtml.isEmpty) {
      throw const FormatException('Empty response from Goodreturns silver page');
    }

    final prices = _parseKaratPrices(goldHtml);
    if (prices['22'] == null) {
      throw const FormatException('Missing 22K gold price from Goodreturns');
    }
    if (prices.length < 3) {
      throw FormatException(
        'Too few karat prices parsed: ${prices.length}',
      );
    }

    final changes = _parseGoldDailyChanges(goldHtml);
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

    final silverPerGram = _parseSilverPerGram(silverHtml);
    if (silverPerGram == null) {
      throw const FormatException('Missing silver per-gram price from Goodreturns');
    }
    final silverChange = _parseSilverDailyChange(silverHtml);
    final silverPrevious = silverPerGram - silverChange;
    final silverChangePercent = silverPrevious != 0
        ? (silverChange / silverPrevious) * 100
        : 0.0;

    final silver = [
      LocalKaratPrice(
        karat: '999',
        sellPerGram: silverPerGram,
        buyPerGram: silverPerGram,
        change: silverChange,
        changePercent: silverChangePercent,
      ),
    ];

    final result = LocalMarketPrices(
      country: 'IN',
      currency: 'INR',
      source: 'goodreturns',
      gold: gold,
      silver: silver,
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

  Map<String, double> _parseGoldDailyChanges(String html) {
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

  double? _parseSilverPerGram(String html) {
    final document = html_parser.parse(html);
    final span = document.querySelector('#silver-1g-price');
    if (span == null) return null;
    return _parseInrPrice(span.text);
  }

  double _parseSilverDailyChange(String html) {
    final document = html_parser.parse(html);
    final rows = document.querySelectorAll('tbody.tablebody tr');
    if (rows.isEmpty) return 0;

    final cells = rows.first.querySelectorAll('td');
    if (cells.length < 4) return 0;

    final kgChange = _parseChangeSpan(cells[3]);
    return kgChange / 1000;
  }

  double _parseChangeSpan(Element cell) {
    final span = cell.querySelector('span');
    if (span == null) return 0;
    final match = RegExp(r'\(([+\-]?\d[\d,]*)\)').firstMatch(span.text);
    if (match == null) return 0;
    final raw = match.group(1)!.replaceAll(',', '');
    return double.tryParse(raw) ?? 0;
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
