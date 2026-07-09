// Shared zakat math, used by both the full Zakat calculator and the small
// portfolio indicator so the rules stay in one place.

/// Basis for the nisab threshold. Silver (lower value) is the common, more
/// cautious choice when combining gold + silver + cash, as it makes zakat
/// due on smaller holdings.
enum NisabBasis { silver, gold }

class ZakatResult {
  /// Total zakatable wealth (in the display currency).
  final double total;

  /// The nisab threshold value (in the display currency).
  final double nisabValue;

  /// Whether wealth reaches the nisab and zakat is therefore due.
  final bool isDue;

  /// Zakat owed (0 when below nisab).
  final double amount;

  const ZakatResult({
    required this.total,
    required this.nisabValue,
    required this.isDue,
    required this.amount,
  });

  /// How far below the nisab the wealth is (0 if at/above).
  double get shortfall =>
      nisabValue > total ? nisabValue - total : 0.0;
}

class Zakat {
  Zakat._();

  static const double rate = 0.025; // 2.5%
  static const double goldNisabGrams = 85.0; // 85g of pure (24K) gold
  static const double silverNisabGrams = 595.0; // 595g of silver

  /// Nisab threshold value in the display currency, given live per-gram prices.
  static double nisabValue({
    required NisabBasis basis,
    required double gold24PerGram,
    required double silverPerGram,
  }) {
    return basis == NisabBasis.silver
        ? silverNisabGrams * silverPerGram
        : goldNisabGrams * gold24PerGram;
  }

  /// Grams that define the nisab for the selected [basis].
  static double nisabGrams(NisabBasis basis) =>
      basis == NisabBasis.silver ? silverNisabGrams : goldNisabGrams;

  /// Compute zakat owed on [totalWealth] against a [nisabValue] threshold.
  ///
  /// A non-positive [nisabValue] means the underlying price feed is broken
  /// (a zero/garbage per-gram price); in that case zakat is never flagged as
  /// due rather than treating every positive wealth as above the threshold.
  static ZakatResult compute({
    required double totalWealth,
    required double nisabValue,
  }) {
    final isDue = nisabValue > 0 && totalWealth >= nisabValue && totalWealth > 0;
    return ZakatResult(
      total: totalWealth,
      nisabValue: nisabValue,
      isDue: isDue,
      amount: isDue ? totalWealth * rate : 0.0,
    );
  }
}
