import 'package:flutter/services.dart';

/// Utilities for numeric text input that tolerate localized keyboards.
///
/// Arabic (٠١٢٣٤٥٦٧٨٩) and Urdu (۰۱۲۳۴۵۶۷۸۹) number pads emit non-ASCII
/// digits, and several locales use a comma or the Arabic decimal separator
/// (٫) instead of a dot. Plain `double.tryParse` and `\d`-based input
/// formatters reject all of these, so every numeric field in the app should
/// go through the helpers here.

const _arabicIndicZero = 0x0660; // ٠
const _extendedArabicIndicZero = 0x06F0; // ۰ (Urdu/Persian)
const _asciiZero = 0x30;

/// Converts Arabic-Indic and Extended Arabic-Indic digits to ASCII and
/// normalizes decimal separators (`,` and `٫`) to a dot.
String normalizeDigits(String input) {
  final buffer = StringBuffer();
  for (final code in input.runes) {
    if (code >= _arabicIndicZero && code <= _arabicIndicZero + 9) {
      buffer.writeCharCode(_asciiZero + (code - _arabicIndicZero));
    } else if (code >= _extendedArabicIndicZero &&
        code <= _extendedArabicIndicZero + 9) {
      buffer.writeCharCode(_asciiZero + (code - _extendedArabicIndicZero));
    } else if (code == 0x066B /* ٫ */ || code == 0x2C /* , */) {
      buffer.writeCharCode(0x2E); // .
    } else {
      buffer.writeCharCode(code);
    }
  }
  return buffer.toString();
}

/// Parses [input] as a non-negative double, accepting localized digits and
/// decimal separators. Returns null for empty or unparseable text.
double? parseFlexibleDouble(String input) {
  final normalized = normalizeDigits(input.trim());
  if (normalized.isEmpty) return null;
  return double.tryParse(normalized);
}

/// Accepts ASCII, Arabic-Indic, and Extended Arabic-Indic digits with at most
/// one decimal separator (`.`, `,`, or `٫`). Set [allowDecimal] to false for
/// integer-only fields.
class LocalizedNumberInputFormatter extends TextInputFormatter {
  LocalizedNumberInputFormatter({this.allowDecimal = true});

  final bool allowDecimal;

  static final _decimalPattern = RegExp(
    r'^[0-9٠-٩۰-۹]*[.,٫]?[0-9٠-٩۰-۹]*$',
  );
  static final _integerPattern = RegExp(
    r'^[0-9٠-٩۰-۹]*$',
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final pattern = allowDecimal ? _decimalPattern : _integerPattern;
    return pattern.hasMatch(newValue.text) ? newValue : oldValue;
  }
}
