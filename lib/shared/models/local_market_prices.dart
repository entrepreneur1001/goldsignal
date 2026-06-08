enum PriceSide { sell, buy }

class LocalKaratPrice {
  final String karat;
  final double sellPerGram;
  final double buyPerGram;
  final double globalGapSell;
  final double globalGapBuy;
  final double change;
  final double changePercent;
  final bool isPerUnit;

  const LocalKaratPrice({
    required this.karat,
    required this.sellPerGram,
    required this.buyPerGram,
    this.globalGapSell = 0,
    this.globalGapBuy = 0,
    this.change = 0,
    this.changePercent = 0,
    this.isPerUnit = false,
  });

  double priceFor(PriceSide side) =>
      side == PriceSide.sell ? sellPerGram : buyPerGram;

  factory LocalKaratPrice.fromJson(Map<String, dynamic> json) {
    return LocalKaratPrice(
      karat: json['karat'] as String,
      sellPerGram: (json['sellPerGram'] as num).toDouble(),
      buyPerGram: (json['buyPerGram'] as num).toDouble(),
      globalGapSell: (json['globalGapSell'] as num?)?.toDouble() ?? 0,
      globalGapBuy: (json['globalGapBuy'] as num?)?.toDouble() ?? 0,
      change: (json['change'] as num?)?.toDouble() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0,
      isPerUnit: json['isPerUnit'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'karat': karat,
        'sellPerGram': sellPerGram,
        'buyPerGram': buyPerGram,
        'globalGapSell': globalGapSell,
        'globalGapBuy': globalGapBuy,
        'change': change,
        'changePercent': changePercent,
        'isPerUnit': isPerUnit,
      };
}

class LocalFxRate {
  final String code;
  final String name;
  final double sell;
  final double buy;
  final double change;
  final double changePercent;

  const LocalFxRate({
    required this.code,
    required this.name,
    required this.sell,
    required this.buy,
    this.change = 0,
    this.changePercent = 0,
  });

  factory LocalFxRate.fromJson(Map<String, dynamic> json) {
    return LocalFxRate(
      code: json['code'] as String,
      name: json['name'] as String,
      sell: (json['sell'] as num).toDouble(),
      buy: (json['buy'] as num).toDouble(),
      change: (json['change'] as num?)?.toDouble() ?? 0,
      changePercent: (json['changePercent'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'sell': sell,
        'buy': buy,
        'change': change,
        'changePercent': changePercent,
      };
}

class LocalMarketPrices {
  final String country;
  final String currency;
  final String source;
  final List<LocalKaratPrice> gold;
  final List<LocalKaratPrice> silver;
  final double? globalGoldOunceUsd;
  final List<LocalFxRate> fxRates;
  final DateTime updatedAt;

  const LocalMarketPrices({
    required this.country,
    required this.currency,
    required this.source,
    required this.gold,
    required this.silver,
    this.globalGoldOunceUsd,
    this.fxRates = const [],
    required this.updatedAt,
  });

  bool get isEgypt => country == 'EG' && currency == 'EGP';

  LocalKaratPrice? goldKarat(String karat) {
    for (final item in gold) {
      if (item.karat == karat) return item;
    }
    return null;
  }

  LocalKaratPrice? silverKarat(String karat) {
    for (final item in silver) {
      if (item.karat == karat) return item;
    }
    return null;
  }

  double? goldPriceForKarat(int karat, PriceSide side) {
    return goldKarat('$karat')?.priceFor(side);
  }

  double? silverPriceForKarat(int purity, PriceSide side) {
    return silverKarat('$purity')?.priceFor(side);
  }

  LocalKaratPrice? get headlineGold => goldKarat('21');
  LocalKaratPrice? get headlineSilver => silverKarat('999');

  factory LocalMarketPrices.fromJson(Map<String, dynamic> json) {
    return LocalMarketPrices(
      country: json['country'] as String? ?? 'EG',
      currency: json['currency'] as String? ?? 'EGP',
      source: json['source'] as String? ?? 'isagha',
      gold: (json['gold'] as List<dynamic>? ?? [])
          .map((e) => LocalKaratPrice.fromJson(e as Map<String, dynamic>))
          .toList(),
      silver: (json['silver'] as List<dynamic>? ?? [])
          .map((e) => LocalKaratPrice.fromJson(e as Map<String, dynamic>))
          .toList(),
      globalGoldOunceUsd: (json['globalGoldOunceUsd'] as num?)?.toDouble(),
      fxRates: (json['fxRates'] as List<dynamic>? ?? [])
          .map((e) => LocalFxRate.fromJson(e as Map<String, dynamic>))
          .toList(),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'country': country,
        'currency': currency,
        'source': source,
        'gold': gold.map((e) => e.toJson()).toList(),
        'silver': silver.map((e) => e.toJson()).toList(),
        'globalGoldOunceUsd': globalGoldOunceUsd,
        'fxRates': fxRates.map((e) => e.toJson()).toList(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}
