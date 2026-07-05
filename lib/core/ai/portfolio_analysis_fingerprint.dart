import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../shared/local_market/local_market_config.dart';
import '../../shared/models/local_market_prices.dart';
import '../../shared/models/metal_price.dart';
import '../../shared/models/portfolio_item.dart';
/// Snapshot of 24h market moves used to decide when to refresh AI analysis.
class PortfolioPriceSnapshot {
  const PortfolioPriceSnapshot({
    this.goldChange24hPct,
    this.silverChange24hPct,
    required this.currency,
    required this.isLocalMarket,
  });

  final double? goldChange24hPct;
  final double? silverChange24hPct;
  final String currency;
  final bool isLocalMarket;

  Map<String, dynamic> toMap() => {
        'goldChange24hPct': goldChange24hPct,
        'silverChange24hPct': silverChange24hPct,
        'currency': currency,
        'isLocalMarket': isLocalMarket,
      };

  factory PortfolioPriceSnapshot.fromMap(Map<String, dynamic> map) {
    return PortfolioPriceSnapshot(
      goldChange24hPct: (map['goldChange24hPct'] as num?)?.toDouble(),
      silverChange24hPct: (map['silverChange24hPct'] as num?)?.toDouble(),
      currency: map['currency'] as String? ?? 'USD',
      isLocalMarket: map['isLocalMarket'] as bool? ?? false,
    );
  }
}

/// Stable hash of portfolio holdings + display currency (locale excluded).
String computePortfolioInputHash(List<PortfolioItem> items, String currency) {
  final sorted = [...items]
    ..sort((a, b) {
      final aId = a.firestoreId ?? '';
      final bId = b.firestoreId ?? '';
      final byId = aId.compareTo(bId);
      if (byId != 0) return byId;
      return '${a.metal}_${a.karat}_${a.weight}'.compareTo(
        '${b.metal}_${b.karat}_${b.weight}',
      );
    });

  final payload = {
    'currency': currency,
    'items': sorted.map((item) {
      return {
        'firestoreId': item.firestoreId ?? '',
        'metal': item.metal,
        'karat': item.karat,
        'weight': item.weight,
        'purchasePrice': item.purchasePrice,
        'purchaseCurrency': item.purchaseCurrency,
        'purchaseDate': item.purchaseDate.millisecondsSinceEpoch,
        'notes': item.notes ?? '',
      };
    }).toList(),
  };

  final bytes = utf8.encode(jsonEncode(payload));
  return sha256.convert(bytes).toString();
}

PortfolioPriceSnapshot buildPriceSnapshot({
  required String currency,
  required MetalPrice? gold,
  required MetalPrice? silver,
  required LocalMarketPrices? local,
}) {
  final isLocal = LocalMarketConfig.isLocalCurrency(currency);

  if (isLocal && local != null) {
    final goldRow = local.headlineGold;
    final silverRow = local.headlineSilver;
    return PortfolioPriceSnapshot(
      goldChange24hPct: goldRow?.changePercent,
      silverChange24hPct: silverRow?.changePercent,
      currency: currency,
      isLocalMarket: true,
    );
  }

  return PortfolioPriceSnapshot(
    goldChange24hPct: gold?.changePercent24h,
    silverChange24hPct: silver?.changePercent24h,
    currency: currency,
    isLocalMarket: false,
  );
}

/// Returns true when gold or silver 24h % moved more than [thresholdPct].
bool isPriceStale(
  PortfolioPriceSnapshot cached,
  PortfolioPriceSnapshot current, {
  double thresholdPct = 1.0,
}) {
  if (cached.currency != current.currency) return true;
  if (cached.isLocalMarket != current.isLocalMarket) return true;

  bool metalMoved(double? cachedPct, double? currentPct) {
    if (cachedPct == null && currentPct == null) return false;
    if (cachedPct == null || currentPct == null) return true;
    return (currentPct - cachedPct).abs() > thresholdPct;
  }

  return metalMoved(cached.goldChange24hPct, current.goldChange24hPct) ||
      metalMoved(cached.silverChange24hPct, current.silverChange24hPct);
}

/// Parses the trilingual JSON shape returned by the portfolio analysis prompt.
Map<String, String> parseTrilingualAnalysisJson(String raw) {
  var body = raw.trim();
  if (body.startsWith('```')) {
    body = body.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
    body = body.replaceFirst(RegExp(r'\s*```$'), '');
  }
  final decoded = jsonDecode(body);
  if (decoded is! Map) {
    throw const FormatException('Expected JSON object');
  }
  final result = <String, String>{};
  for (final key in ['en', 'ar', 'ur']) {
    final value = decoded[key];
    if (value != null) result[key] = value.toString();
  }
  if (result.isEmpty) {
    throw const FormatException('Missing en/ar/ur fields');
  }
  return result;
}
