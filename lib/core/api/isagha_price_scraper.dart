import 'package:dio/dio.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart';
import '../../shared/models/local_market_prices.dart';

class IsaghaPriceScraper {
  static const _url = 'https://market.isagha.com/prices';
  static const _cacheKey = 'egypt_latest';

  final Dio _dio;

  IsaghaPriceScraper()
      : _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; GoldSignal/1.0)',
            'Accept-Language': 'ar-EG,ar;q=0.9,en;q=0.8',
          },
        ));

  LocalMarketPrices? getCachedPrices() {
    if (!Hive.isBoxOpen('localMarketPrices')) return null;
    final box = Hive.box('localMarketPrices');
    final cached = box.get(_cacheKey);
    if (cached == null) return null;
    return LocalMarketPrices.fromJson(Map<String, dynamic>.from(cached));
  }

  Future<LocalMarketPrices> fetchLatestPrices() async {
    final response = await _dio.get<String>(_url);
    final html = response.data;
    if (html == null || html.isEmpty) {
      throw const FormatException('Empty response from iSagha');
    }

    final document = html_parser.parse(html);
    final gold = _parseMetalRows(document, 'gold');
    final silver = _parseMetalRows(document, 'silver');
    final fxRates = _parseFxRows(document);

    if (gold.length < 4) {
      throw FormatException('Too few gold rows parsed: ${gold.length}');
    }

    double? globalOunce;
    for (final row in gold) {
      if (row.karat == 'gold_ounce') {
        globalOunce = row.sellPerGram;
        break;
      }
    }

    final result = LocalMarketPrices(
      country: 'EG',
      currency: 'EGP',
      source: 'isagha',
      gold: gold.where((r) => r.karat != 'gold_ounce').toList(),
      silver: silver.where((r) => r.karat != 'silver_ounce').toList(),
      globalGoldOunceUsd: globalOunce,
      fxRates: fxRates,
      updatedAt: DateTime.now(),
    );

    await _cache(result);
    return result;
  }

  List<LocalKaratPrice> _parseMetalRows(Document document, String metalClass) {
    final rows = <LocalKaratPrice>[];

    for (final tr in document.querySelectorAll('tr')) {
      final icon = tr.querySelector('.metal-icon.$metalClass');
      if (icon == null) continue;

      final labelSpan = tr.querySelector('.purity-cell span:last-child');
      final label = labelSpan?.text.trim() ?? '';
      if (label.isEmpty) continue;

      final cells = tr.querySelectorAll('td');
      if (cells.length < 7) continue;

      final karat = _normalizeKaratLabel(label, metalClass);
      if (karat == null) continue;

      final sell = _parsePriceCell(cells[1].text);
      final gapSell = _parsePriceCell(cells[2].text);
      final buy = _parsePriceCell(cells[3].text);
      final gapBuy = _parsePriceCell(cells[4].text);
      final changeCell = cells[5];
      final changePercentCell = cells[6];
      final change = _signedChange(changeCell, _parsePriceCell(changeCell.text));
      final changePercent = _signedChange(
        changePercentCell,
        _parsePercentCell(changePercentCell.text),
      );

      if (sell == null || buy == null) continue;

      rows.add(LocalKaratPrice(
        karat: karat,
        sellPerGram: sell,
        buyPerGram: buy,
        globalGapSell: gapSell ?? 0,
        globalGapBuy: gapBuy ?? 0,
        change: change ?? 0,
        changePercent: changePercent ?? 0,
        isPerUnit: karat == 'gold_pound' || karat == 'silver_pound',
      ));
    }

    return rows;
  }

  List<LocalFxRate> _parseFxRows(Document document) {
    const currencyMap = {
      'الدولار الأمريكي': 'USD',
      'الريال السعودي': 'SAR',
      'الدينار الكويتي': 'KWD',
      'الدرهم الإماراتي': 'AED',
    };

    final rates = <LocalFxRate>[];

    for (final tr in document.querySelectorAll('tr')) {
      if (tr.querySelector('.currency-flag') == null) continue;

      final labelSpan = tr.querySelector('.purity-cell span:last-child');
      final label = labelSpan?.text.trim() ?? '';
      final code = currencyMap[label];
      if (code == null) continue;

      final cells = tr.querySelectorAll('td');
      if (cells.length < 4) continue;

      final sell = _parsePriceCell(cells[1].text);
      final buy = _parsePriceCell(cells[2].text);
      if (sell == null || buy == null) continue;

      final changeCell = cells[3];
      final changePercentCell = cells.length > 4 ? cells[4] : null;
      rates.add(LocalFxRate(
        code: code,
        name: label,
        sell: sell,
        buy: buy,
        change: _signedChange(changeCell, _parsePriceCell(changeCell.text)) ?? 0,
        changePercent: changePercentCell == null
            ? 0
            : _signedChange(
                  changePercentCell,
                  _parsePercentCell(changePercentCell.text),
                ) ??
                0,
      ));
    }

    return rates;
  }

  String? _normalizeKaratLabel(String label, String metalClass) {
    if (metalClass == 'gold') {
      if (label.contains('عيار 24')) return '24';
      if (label.contains('عيار 22')) return '22';
      if (label.contains('عيار 21')) return '21';
      if (label.contains('عيار 18')) return '18';
      if (label.contains('جنيه ذهب')) return 'gold_pound';
      if (label.contains('أوقية الذهب')) return 'gold_ounce';
    } else {
      if (label.contains('عيار 999')) return '999';
      if (label.contains('عيار 925')) return '925';
      if (label.contains('عيار 900')) return '900';
      if (label.contains('عيار 800')) return '800';
      if (label.contains('عيار 600')) return '600';
      if (label.contains('الجنيه الفضة')) return 'silver_pound';
      if (label.contains('أوقية الفضة')) return 'silver_ounce';
    }
    return null;
  }

  double? _parsePriceCell(String raw) {
    final cleaned = raw
        .replaceAll('\u200E', '')
        .replaceAll('\u200F', '')
        .replaceAll('ج.م', '')
        .replaceAll('\$', '')
        .replaceAll('—', '')
        .replaceAll(',', '')
        .trim();
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  double? _signedChange(Element cell, double? value) {
    if (value == null) return null;
    if (cell.classes.contains('change-down') && value > 0) {
      return -value;
    }
    return value;
  }

  double? _parsePercentCell(String raw) {
    final cleaned = raw
        .replaceAll('\u200E', '')
        .replaceAll('\u200F', '')
        .replaceAll('%', '')
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
