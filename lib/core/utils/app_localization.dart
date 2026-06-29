import 'package:flutter/widgets.dart';

/// Localization config shared across the app. Translation loading, the `.tr()`
/// extension, locale persistence, and RTL are handled by the
/// `easy_localization` package (see `main.dart`). This file only holds the
/// constants both `main.dart` and the language picker need.

/// Locales the app ships translations for (assets/translations/<code>.json).
const List<Locale> kSupportedLocales = [
  Locale('en'),
  Locale('ar'),
  Locale('ur'),
];

/// Native display name for each supported language code (locale-independent).
const Map<String, String> kLanguageNames = {
  'en': 'English',
  'ar': 'العربية',
  'ur': 'اردو',
};
