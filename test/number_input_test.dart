import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/core/utils/number_input.dart';

TextEditingValue _format(
  LocalizedNumberInputFormatter formatter,
  String oldText,
  String newText,
) {
  return formatter.formatEditUpdate(
    TextEditingValue(text: oldText),
    TextEditingValue(text: newText),
  );
}

void main() {
  group('normalizeDigits', () {
    test('converts Arabic-Indic digits to ASCII', () {
      expect(normalizeDigits('٠١٢٣٤٥٦٧٨٩'), '0123456789');
    });

    test('converts Extended Arabic-Indic (Urdu) digits to ASCII', () {
      expect(normalizeDigits('۰۱۲۳۴۵۶۷۸۹'), '0123456789');
    });

    test('normalizes comma and Arabic decimal separator to dot', () {
      expect(normalizeDigits('1,5'), '1.5');
      expect(normalizeDigits('١٢٫٥'), '12.5');
    });

    test('leaves ASCII input untouched', () {
      expect(normalizeDigits('123.45'), '123.45');
    });
  });

  group('parseFlexibleDouble', () {
    test('parses ASCII decimals', () {
      expect(parseFlexibleDouble('25.5'), 25.5);
    });

    test('parses Arabic-Indic digits with Arabic decimal separator', () {
      expect(parseFlexibleDouble('١٢٫٥'), 12.5);
    });

    test('parses Urdu digits', () {
      expect(parseFlexibleDouble('۲۵'), 25.0);
    });

    test('parses comma decimal separator', () {
      expect(parseFlexibleDouble('1,5'), 1.5);
    });

    test('returns null for empty and whitespace input', () {
      expect(parseFlexibleDouble(''), isNull);
      expect(parseFlexibleDouble('   '), isNull);
    });

    test('returns null for multi-dot garbage', () {
      expect(parseFlexibleDouble('1.2.3'), isNull);
    });

    test('returns null for non-numeric text', () {
      expect(parseFlexibleDouble('abc'), isNull);
    });
  });

  group('LocalizedNumberInputFormatter', () {
    test('accepts ASCII, Arabic, and Urdu digits', () {
      final f = LocalizedNumberInputFormatter();
      expect(_format(f, '', '123').text, '123');
      expect(_format(f, '', '١٢٣').text, '١٢٣');
      expect(_format(f, '', '۱۲۳').text, '۱۲۳');
    });

    test('accepts a single decimal separator of any style', () {
      final f = LocalizedNumberInputFormatter();
      expect(_format(f, '', '1.5').text, '1.5');
      expect(_format(f, '', '1,5').text, '1,5');
      expect(_format(f, '', '١٫٥').text, '١٫٥');
    });

    test('rejects a second decimal separator', () {
      final f = LocalizedNumberInputFormatter();
      expect(_format(f, '1.2', '1.2.').text, '1.2');
      expect(_format(f, '1,2', '1,2,').text, '1,2');
    });

    test('rejects letters and negatives', () {
      final f = LocalizedNumberInputFormatter();
      expect(_format(f, '12', '12a').text, '12');
      expect(_format(f, '', '-1').text, '');
    });

    test('integer mode rejects decimal separators', () {
      final f = LocalizedNumberInputFormatter(allowDecimal: false);
      expect(_format(f, '12', '12.').text, '12');
      expect(_format(f, '', '٣٤').text, '٣٤');
    });
  });
}
