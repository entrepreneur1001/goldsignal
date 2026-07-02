import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:goldsignal/core/utils/font_bootstrap.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FontBootstrap.configure();
  });

  test('bundled google font assets are declared', () async {
    const expected = [
      'assets/google_fonts/Sora-Regular.ttf',
      'assets/google_fonts/Sora-SemiBold.ttf',
      'assets/google_fonts/Sora-Bold.ttf',
      'assets/google_fonts/Fraunces-SemiBold.ttf',
      'assets/google_fonts/Inter-Regular.ttf',
      'assets/google_fonts/NotoSansArabic-Regular.ttf',
      'assets/google_fonts/NotoSansArabic-SemiBold.ttf',
      'assets/google_fonts/NotoNastaliqUrdu-Regular.ttf',
      'assets/google_fonts/NotoNastaliqUrdu-SemiBold.ttf',
    ];

    for (final path in expected) {
      final data = await rootBundle.load(path);
      expect(data.lengthInBytes, greaterThan(1000), reason: path);
    }
  });

  test('typography fonts preload from bundled assets without HTTP', () async {
    await FontBootstrap.preload();

    expect(GoogleFonts.config.allowRuntimeFetching, isFalse);
    expect(
      GoogleFonts.sora().fontFamily,
      contains('Sora'),
    );
    expect(
      GoogleFonts.notoSansArabic(fontWeight: FontWeight.w600).fontFamily,
      contains('NotoSansArabic'),
    );
    expect(
      GoogleFonts.notoNastaliqUrdu().fontFamily,
      contains('NotoNastaliqUrdu'),
    );
  });
}
