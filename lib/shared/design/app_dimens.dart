import 'package:flutter/widgets.dart';

/// Spacing, radii, durations and blur — the geometric system for the Vault UI.
/// 8pt scale; rounded, soft shapes.
class AppDimens {
  AppDimens._();

  // Spacing (8pt scale)
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  // Radii
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 20;
  static const double radiusXl = 24;
  static const double radiusPill = 999;

  static const BorderRadius cardRadius =
      BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius sheetRadius =
      BorderRadius.vertical(top: Radius.circular(radiusXl));

  // Motion
  static const Duration fast = Duration(milliseconds: 180);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 600);

  // Effects
  static const double navBlur = 18;
  static const double pressScale = 0.98;

  // Standard page padding
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(20, 16, 20, 24);
}
