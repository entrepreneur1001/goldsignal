import 'package:flutter/material.dart';

/// "Vault" palette. Dark-first; a warm light counterpart is provided for the
/// secondary light theme. Pull all colors from here — no scattered hex.
class VaultColors {
  const VaultColors({
    required this.brightness,
    required this.bgBase,
    required this.bgSurface,
    required this.bgElevated,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.hairline,
  });

  final Brightness brightness;

  /// Layered backgrounds (base → elevated card).
  final Color bgBase;
  final Color bgSurface;
  final Color bgElevated;

  /// Text ramp.
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// 1px borders / dividers.
  final Color hairline;

  // ---- Brand constants (shared by both themes) ----
  static const Color gold = Color(0xFFF2C94C);
  static const Color goldDeep = Color(0xFFC89B3C);
  static const Color goldHighlight = Color(0xFFFFE08A);
  static const Color silver = Color(0xFFC7CBD1);
  static const Color up = Color(0xFF3FB985);
  static const Color down = Color(0xFFF0616D);

  /// Gold gradient for CTAs / headline accents.
  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldHighlight, gold, goldDeep],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft gold glow used as a card/box shadow.
  static List<BoxShadow> goldGlow({double opacity = 0.18, double blur = 28}) =>
      [
        BoxShadow(
          color: gold.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: -6,
          offset: const Offset(0, 8),
        ),
      ];

  /// Generic soft elevation shadow (depth without Material elevation).
  static List<BoxShadow> softShadow(Brightness b) => [
        BoxShadow(
          color: Colors.black.withValues(alpha: b == Brightness.dark ? 0.45 : 0.10),
          blurRadius: 24,
          spreadRadius: -8,
          offset: const Offset(0, 12),
        ),
      ];

  static const VaultColors dark = VaultColors(
    brightness: Brightness.dark,
    bgBase: Color(0xFF0B0B0F),
    bgSurface: Color(0xFF13131A),
    bgElevated: Color(0xFF1C1C26),
    textPrimary: Color(0xFFF5F5F7),
    textSecondary: Color(0xFFA0A2AD),
    textTertiary: Color(0xFF6B6D78),
    hairline: Color(0x12FFFFFF), // white @ ~7%
  );

  static const VaultColors light = VaultColors(
    brightness: Brightness.light,
    bgBase: Color(0xFFF6F4EF),
    bgSurface: Color(0xFFFBFAF7),
    bgElevated: Color(0xFFFFFFFF),
    textPrimary: Color(0xFF1A1A1E),
    textSecondary: Color(0xFF5C5E68),
    textTertiary: Color(0xFF8A8C96),
    hairline: Color(0x14000000), // black @ ~8%
  );

  /// Resolve the palette for a brightness.
  static VaultColors of(Brightness b) => b == Brightness.dark ? dark : light;
}
