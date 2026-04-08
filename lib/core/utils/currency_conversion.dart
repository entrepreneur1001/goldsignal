/// Converts a cash amount using USD-base FX rates from [MetalPricesResponse.rates]
/// (fiat codes = units of that currency per 1 USD).
double? convertWithUsdBaseRates(
  double amount,
  String from,
  String to,
  Map<String, double> rates,
) {
  if (from == to) return amount;

  double? toUsd(String code, double a) {
    if (code == 'USD') return a;
    final r = rates[code];
    if (r == null || r == 0) return null;
    return a / r;
  }

  double? fromUsd(String code, double usd) {
    if (code == 'USD') return usd;
    final r = rates[code];
    if (r == null) return null;
    return usd * r;
  }

  final inUsd = toUsd(from, amount);
  if (inUsd == null) return null;
  return fromUsd(to, inUsd);
}
