/// One performance period from goldprice.org (e.g. Today, 1 Year).
class MetalPerformancePeriod {
  final String label;
  final String amount;
  final String percentage;
  final bool isPositive;
  final double? percentValue;

  const MetalPerformancePeriod({
    required this.label,
    required this.amount,
    required this.percentage,
    required this.isPositive,
    this.percentValue,
  });
}

/// Gold + silver multi-period performance for a currency.
class MetalPerformanceData {
  final String currency;
  final List<MetalPerformancePeriod> gold;
  final List<MetalPerformancePeriod> silver;
  final DateTime fetchedAt;

  const MetalPerformanceData({
    required this.currency,
    required this.gold,
    required this.silver,
    required this.fetchedAt,
  });

  bool get isEmpty => gold.isEmpty && silver.isEmpty;
}
