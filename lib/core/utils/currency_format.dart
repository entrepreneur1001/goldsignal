// Single source of truth for currency display formatting, replacing the
// per-screen `_formatCurrency` symbol maps (portfolio/calculator/zakat).

import 'package:intl/intl.dart';

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
  final formatted = NumberFormat('#,##0.00').format(value);
  return '$sign$symbol$formatted';
}

/// Compact symbol + value for tight spaces such as chart axis labels.
/// Drops decimals and adds thousands separators, e.g. `₹3,500` or `$1,235`.
/// High-magnitude values are abbreviated (`₹1.2M`) to keep labels short.
String formatCurrencyCompact(double value, String currency) {
  final symbol = _symbols[currency] ?? '$currency ';
  final pattern = value.abs() >= 100000 ? NumberFormat.compact() : NumberFormat('#,##0');
  return '$symbol${pattern.format(value)}';
}
