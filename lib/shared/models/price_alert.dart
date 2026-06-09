import 'local_market_prices.dart';

enum AlertType { price, percentChange }

enum AlertCondition { above, below }

class PriceAlert {
  final String id;
  final String metal;
  final String karat;
  final String currency;
  final PriceSide? side;
  final AlertType type;
  final AlertCondition condition;
  final double targetValue;
  final double? baselinePrice;
  final int? repeatAfterHours;
  final DateTime? reactivateAt;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? triggeredAt;
  final double? triggeredPrice;

  const PriceAlert({
    required this.id,
    required this.metal,
    required this.karat,
    required this.currency,
    this.side,
    this.type = AlertType.price,
    required this.condition,
    required this.targetValue,
    this.baselinePrice,
    this.repeatAfterHours,
    this.reactivateAt,
    this.isActive = true,
    required this.createdAt,
    this.triggeredAt,
    this.triggeredPrice,
  });

  bool get isLocal => currency == 'EGP';
  bool get isPercentChange => type == AlertType.percentChange;
  bool get autoRepeats => repeatAfterHours != null && repeatAfterHours! > 0;

  bool get isSnoozed {
    if (isActive || reactivateAt == null) return false;
    return reactivateAt!.isAfter(DateTime.now());
  }

  String get label {
    final metalLabel = metal == 'gold' ? 'Gold' : 'Silver';
    final karatLabel = metal == 'gold' ? '${karat}K' : karat;
    final sideLabel = isLocal && side != null ? ' (${side!.name})' : '';

    if (isPercentChange) {
      final dir = condition == AlertCondition.above ? 'up' : 'down';
      return '$metalLabel $karatLabel$sideLabel $dir $targetValue%';
    }

    final cond = condition == AlertCondition.above ? 'above' : 'below';
    return '$metalLabel $karatLabel$sideLabel $cond $targetValue $currency/g';
  }

  String? get repeatDescription {
    if (!autoRepeats) return null;
    final hours = repeatAfterHours!;
    if (hours == 1) return 'Repeats 1 hour after each trigger';
    if (hours == 6) return 'Repeats 6 hours after each trigger';
    if (hours == 24) return 'Repeats daily after each trigger';
    if (hours == 168) return 'Repeats weekly after each trigger';
    if (hours < 24) return 'Repeats every $hours hours after trigger';
    return 'Repeats every ${hours ~/ 24} days after trigger';
  }

  double? changePercentFrom(double? current) {
    if (current == null || baselinePrice == null || baselinePrice == 0) {
      return null;
    }
    return ((current - baselinePrice!) / baselinePrice!) * 100;
  }

  factory PriceAlert.fromJson(Map<String, dynamic> json) {
    final typeRaw = json['type'] as String?;
    return PriceAlert(
      id: json['id'] as String,
      metal: json['metal'] as String,
      karat: json['karat'] as String,
      currency: json['currency'] as String,
      side: json['side'] == 'buy'
          ? PriceSide.buy
          : json['side'] == 'sell'
              ? PriceSide.sell
              : null,
      type: typeRaw == 'percentChange'
          ? AlertType.percentChange
          : AlertType.price,
      condition: json['condition'] == 'below'
          ? AlertCondition.below
          : AlertCondition.above,
      targetValue: (json['targetValue'] as num).toDouble(),
      baselinePrice: (json['baselinePrice'] as num?)?.toDouble(),
      repeatAfterHours: json['repeatAfterHours'] as int?,
      reactivateAt: json['reactivateAt'] != null
          ? DateTime.parse(json['reactivateAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String),
      triggeredAt: json['triggeredAt'] != null
          ? DateTime.parse(json['triggeredAt'] as String)
          : null,
      triggeredPrice: (json['triggeredPrice'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'metal': metal,
        'karat': karat,
        'currency': currency,
        'side': side?.name,
        'type': type.name,
        'condition': condition.name,
        'targetValue': targetValue,
        'baselinePrice': baselinePrice,
        'repeatAfterHours': repeatAfterHours,
        'reactivateAt': reactivateAt?.toIso8601String(),
        'isActive': isActive,
        'createdAt': createdAt.toIso8601String(),
        'triggeredAt': triggeredAt?.toIso8601String(),
        'triggeredPrice': triggeredPrice,
      };

  PriceAlert copyWith({
    bool? isActive,
    DateTime? triggeredAt,
    double? baselinePrice,
    double? triggeredPrice,
    int? repeatAfterHours,
    DateTime? reactivateAt,
    bool clearTrigger = false,
    bool clearReactivate = false,
  }) {
    return PriceAlert(
      id: id,
      metal: metal,
      karat: karat,
      currency: currency,
      side: side,
      type: type,
      condition: condition,
      targetValue: targetValue,
      baselinePrice: baselinePrice ?? this.baselinePrice,
      repeatAfterHours: repeatAfterHours ?? this.repeatAfterHours,
      reactivateAt:
          clearReactivate ? null : (reactivateAt ?? this.reactivateAt),
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      triggeredAt: clearTrigger ? null : (triggeredAt ?? this.triggeredAt),
      triggeredPrice:
          clearTrigger ? null : (triggeredPrice ?? this.triggeredPrice),
    );
  }
}
