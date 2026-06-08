import 'local_market_prices.dart';

class PriceSnapshot {
  final DateTime timestamp;
  final String currency;
  final String source;
  final String metal;
  final String karat;
  final double? sellPerGram;
  final double? buyPerGram;
  final double? spotPerOunce;
  final double? globalGap;

  const PriceSnapshot({
    required this.timestamp,
    required this.currency,
    required this.source,
    required this.metal,
    required this.karat,
    this.sellPerGram,
    this.buyPerGram,
    this.spotPerOunce,
    this.globalGap,
  });

  double valueFor(PriceSide side) {
    if (side == PriceSide.buy && buyPerGram != null) return buyPerGram!;
    if (sellPerGram != null) return sellPerGram!;
    if (spotPerOunce != null) return spotPerOunce!;
    return 0;
  }

  String get cacheKey => '$currency|$metal|$karat|$source';

  factory PriceSnapshot.fromJson(Map<String, dynamic> json) {
    return PriceSnapshot(
      timestamp: DateTime.parse(json['timestamp'] as String),
      currency: json['currency'] as String,
      source: json['source'] as String,
      metal: json['metal'] as String,
      karat: json['karat'] as String,
      sellPerGram: (json['sellPerGram'] as num?)?.toDouble(),
      buyPerGram: (json['buyPerGram'] as num?)?.toDouble(),
      spotPerOunce: (json['spotPerOunce'] as num?)?.toDouble(),
      globalGap: (json['globalGap'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'currency': currency,
        'source': source,
        'metal': metal,
        'karat': karat,
        'sellPerGram': sellPerGram,
        'buyPerGram': buyPerGram,
        'spotPerOunce': spotPerOunce,
        'globalGap': globalGap,
      };
}

class ChartDataPoint {
  final DateTime date;
  final double value;

  const ChartDataPoint({required this.date, required this.value});
}

enum ChartDataSource { snapshots, community, apiFallback }

enum ChartRange { days7, days30, days90 }

extension ChartRangeExt on ChartRange {
  int get days => switch (this) {
        ChartRange.days7 => 7,
        ChartRange.days30 => 30,
        ChartRange.days90 => 90,
      };

  String get label => switch (this) {
        ChartRange.days7 => '7D',
        ChartRange.days30 => '30D',
        ChartRange.days90 => '90D',
      };

  int get minSnapshotPoints => switch (this) {
        ChartRange.days7 => 3,
        ChartRange.days30 => 8,
        ChartRange.days90 => 20,
      };
}
