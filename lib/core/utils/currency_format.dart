// Single source of truth for currency display formatting, replacing the
// per-screen `_formatCurrency` symbol maps (portfolio/calculator/zakat).

const Map<String, String> _symbols = {
  'USD': '\$',
  'SAR': 'SAR ',
  'AED': 'AED ',
  'EGP': 'EGP ',
  'KWD': 'KWD ',
  'BHD': 'BHD ',
  'OMR': 'OMR ',
  'QAR': 'QAR ',
  'JOD': 'JOD ',
  'EUR': '€',
  'GBP': '£',
  'JPY': '¥',
  'CNY': '¥',
  'INR': '₹',
  'PKR': 'PKR ',
  'TRY': '₺',
};

/// Format [value] in [currency], e.g. `$1234.56` or `EGP 1234.56`.
/// When [showSign] is true a leading `+` is added for positive values.
String formatCurrency(double value, String currency, {bool showSign = false}) {
  final symbol = _symbols[currency] ?? '$currency ';
  final sign = showSign && value > 0 ? '+' : '';
  return '$sign$symbol${value.toStringAsFixed(2)}';
}
