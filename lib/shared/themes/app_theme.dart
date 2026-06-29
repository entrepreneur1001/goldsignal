import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_dimens.dart';
import '../design/app_typography.dart';

/// Vault theme — dark-first luxury. Built from the [VaultColors] / [AppDimens]
/// / [AppTypography] design tokens. Legacy color constants are kept (mapped to
/// the new palette) so existing screens keep compiling during the migration.
class AppTheme {
  // ---- Legacy constants (kept; now point at the Vault palette) ----
  static const Color primaryColor = VaultColors.gold;
  static const Color secondaryColor = VaultColors.silver;
  static const Color accentColor = Color(0xFF1E88E5);
  static const Color successColor = VaultColors.up;
  static const Color errorColor = VaultColors.down;
  static const Color warningColor = Color(0xFFFF9800);

  static const Color gold = VaultColors.gold;
  static const Color goldBright = VaultColors.goldHighlight;
  static const Color goldDeep = VaultColors.goldDeep;
  static const Color silver = VaultColors.silver;

  static ThemeData get darkTheme => _build(VaultColors.dark);
  static ThemeData get lightTheme => _build(VaultColors.light);
  static ThemeData darkThemeFor(Locale locale) =>
      _build(VaultColors.dark, languageCode: locale.languageCode);
  static ThemeData lightThemeFor(Locale locale) =>
      _build(VaultColors.light, languageCode: locale.languageCode);

  static ThemeData _build(VaultColors c, {String languageCode = 'en'}) {
    final isDark = c.brightness == Brightness.dark;
    final text = AppTypography.textTheme(c, languageCode: languageCode);
    const onGold = Color(0xFF1A1410); // ink on gold surfaces

    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: VaultColors.gold,
      onPrimary: onGold,
      secondary: VaultColors.silver,
      onSecondary: onGold,
      tertiary: VaultColors.gold,
      onTertiary: onGold,
      error: VaultColors.down,
      onError: Colors.white,
      surface: c.bgElevated,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.bgSurface,
      outline: c.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      scaffoldBackgroundColor: c.bgBase,
      canvasColor: c.bgBase,
      colorScheme: scheme,
      textTheme: text,
      primaryColor: VaultColors.gold,
      dividerColor: c.hairline,
      iconTheme: IconThemeData(color: c.textSecondary),
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: c.textPrimary,
        titleTextStyle: text.titleLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: c.textPrimary,
        ),
      ),

      cardTheme: CardThemeData(
        elevation: 0,
        color: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimens.cardRadius,
          side: BorderSide(color: c.hairline),
        ),
        margin: EdgeInsets.zero,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? c.bgSurface : c.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: _inputBorder(c.hairline),
        enabledBorder: _inputBorder(c.hairline),
        focusedBorder: _inputBorder(VaultColors.gold, width: 1.5),
        errorBorder: _inputBorder(VaultColors.down),
        labelStyle: text.bodyMedium,
        hintStyle: text.bodySmall,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: VaultColors.gold,
          foregroundColor: onGold,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: VaultColors.gold,
          foregroundColor: onGold,
          elevation: 0,
          textStyle: text.labelLarge,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: VaultColors.gold,
          textStyle: text.labelLarge,
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: c.bgSurface,
        side: BorderSide(color: c.hairline),
        labelStyle: text.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusPill),
        ),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onGold : c.textTertiary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? VaultColors.gold : c.bgSurface,
        ),
        trackOutlineColor: WidgetStateProperty.all(c.hairline),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusXl),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.bgElevated,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: AppDimens.sheetRadius,
        ),
        showDragHandle: true,
      ),

      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: c.bgElevated,
        contentTextStyle: text.bodyMedium?.copyWith(color: c.textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
          side: BorderSide(color: c.hairline),
        ),
      ),

      dividerTheme: DividerThemeData(color: c.hairline, thickness: 1, space: 1),

      listTileTheme: ListTileThemeData(
        iconColor: c.textSecondary,
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall,
      ),

      // Stock nav kept as a sensible fallback; app uses FloatingNavBar.
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: c.bgElevated,
        selectedItemColor: VaultColors.gold,
        unselectedItemColor: c.textTertiary,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true,
      ),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
