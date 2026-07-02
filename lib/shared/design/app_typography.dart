import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Type system for the Vault UI:
/// - Display / hero numerals → Fraunces (elegant serif), tabular figures.
/// - Headings / labels → Sora.
/// - Body → Inter.
/// - Arabic / Urdu → script-specific Google Fonts for better shaping and legibility.
class AppTypography {
  AppTypography._();

  static const List<FontFeature> _tabular = [FontFeature.tabularFigures()];

  /// Style for the big hero number (price, net worth). Use directly where a
  /// single oversized figure should feel luxurious.
  static TextStyle hero(
    VaultColors c, {
    double size = 40,
    String languageCode = 'en',
  }) => _displayFont(
    languageCode,
    fontSize: size,
    fontWeight: FontWeight.w600,
    height: 1.0,
    letterSpacing: -0.5,
    color: c.textPrimary,
    fontFeatures: _tabular,
  );

  /// Uppercase micro-label, e.g. "GOLD · 24K".
  static TextStyle microLabel(VaultColors c, {String languageCode = 'en'}) =>
      _headingFont(
        languageCode,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
        color: c.textSecondary,
      );

  static TextTheme textTheme(VaultColors c, {String languageCode = 'en'}) {
    final display = _displayFont(
      languageCode,
      color: c.textPrimary,
      fontWeight: FontWeight.w600,
      fontFeatures: _tabular,
      height: 1.05,
    );
    final heading = _headingFont(
      languageCode,
      color: c.textPrimary,
      fontWeight: FontWeight.w600,
    );
    final body = _bodyFont(languageCode, color: c.textSecondary);

    return TextTheme(
      displayLarge: display.copyWith(fontSize: 40, letterSpacing: -0.5),
      displayMedium: display.copyWith(fontSize: 32, letterSpacing: -0.5),
      displaySmall: display.copyWith(fontSize: 26),
      headlineLarge: heading.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      headlineMedium: heading.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      headlineSmall: heading.copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: heading.copyWith(fontSize: 16, fontWeight: FontWeight.w600),
      titleMedium: heading.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      titleSmall: heading.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
      ),
      bodyLarge: body.copyWith(fontSize: 15, color: c.textPrimary, height: 1.4),
      bodyMedium: body.copyWith(fontSize: 14, height: 1.4),
      bodySmall: body.copyWith(
        fontSize: 12,
        color: c.textTertiary,
        height: 1.35,
      ),
      labelLarge: heading.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelMedium: heading.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: c.textSecondary,
      ),
      labelSmall: _headingFont(
        languageCode,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: c.textTertiary,
      ),
    );
  }

  static TextStyle _displayFont(
    String languageCode, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
    List<FontFeature>? fontFeatures,
  }) {
    switch (languageCode) {
      case 'ar':
        return GoogleFonts.notoSansArabic(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
          fontFeatures: fontFeatures,
        );
      case 'ur':
        return GoogleFonts.notoNastaliqUrdu(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
          fontFeatures: fontFeatures,
        );
      default:
        return GoogleFonts.fraunces(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
          fontFeatures: fontFeatures,
        );
    }
  }

  static TextStyle _headingFont(
    String languageCode, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    switch (languageCode) {
      case 'ar':
        return GoogleFonts.notoSansArabic(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
      case 'ur':
        return GoogleFonts.notoNastaliqUrdu(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
      default:
        return GoogleFonts.sora(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
    }
  }

  static TextStyle _bodyFont(
    String languageCode, {
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    double? height,
    double? letterSpacing,
  }) {
    switch (languageCode) {
      case 'ar':
        return GoogleFonts.notoSansArabic(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
      case 'ur':
        return GoogleFonts.notoNastaliqUrdu(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
      default:
        return GoogleFonts.inter(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
          height: height,
          letterSpacing: letterSpacing,
        );
    }
  }
}
