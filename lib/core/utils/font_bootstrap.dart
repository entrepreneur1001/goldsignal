import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../crash/crash_reporter.dart';

/// Bundled Google Font families used by [AppTypography].
const _licenseAssets = <String, List<String>>{
  'Sora': ['assets/google_fonts/Sora-OFL.txt'],
  'Fraunces': ['assets/google_fonts/Fraunces-OFL.txt'],
  'Inter': ['assets/google_fonts/Inter-OFL.txt'],
  'Noto Sans Arabic': ['assets/google_fonts/NotoSansArabic-OFL.txt'],
  'Noto Nastaliq Urdu': ['assets/google_fonts/NotoNastaliqUrdu-OFL.txt'],
};

/// Configures Google Fonts for offline asset loading and preloads typography.
class FontBootstrap {
  FontBootstrap._();

  /// Disables HTTP font fetching; fonts must be present in [assets/google_fonts].
  static void configure() {
    GoogleFonts.config.allowRuntimeFetching = false;
  }

  /// Registers OFL licenses for bundled fonts (shown in the app license page).
  static void registerLicenses() {
    for (final entry in _licenseAssets.entries) {
      final packageName = entry.key;
      final assetPaths = entry.value;
      LicenseRegistry.addLicense(() async* {
        final buffer = StringBuffer();
        for (final path in assetPaths) {
          buffer.writeln(await rootBundle.loadString(path));
        }
        yield LicenseEntryWithLineBreaks(
          <String>[packageName],
          buffer.toString(),
        );
      });
    }
  }

  /// Preloads all typography variants so the first frame uses bundled fonts.
  ///
  /// Failures are reported non-fatally; the app continues with system fallbacks.
  static Future<void> preload() async {
    try {
      await GoogleFonts.pendingFonts(_typographyStyles);
    } catch (error, stack) {
      reportNonFatal(
        error,
        stack,
        reason: 'font_bootstrap_preload_failed',
      );
      if (kDebugMode) {
        debugPrint('FontBootstrap.preload failed: $error');
      }
    }
  }

  static final List<TextStyle> _typographyStyles = [
    GoogleFonts.sora(),
    GoogleFonts.sora(fontWeight: FontWeight.w600),
    GoogleFonts.sora(fontWeight: FontWeight.w700),
    GoogleFonts.fraunces(fontWeight: FontWeight.w600),
    GoogleFonts.inter(),
    GoogleFonts.notoSansArabic(),
    GoogleFonts.notoSansArabic(fontWeight: FontWeight.w600),
    GoogleFonts.notoNastaliqUrdu(),
    GoogleFonts.notoNastaliqUrdu(fontWeight: FontWeight.w600),
  ];
}
