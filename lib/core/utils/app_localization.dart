import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppLocale {
  static const Map<String, dynamic> EN = {
    'name': 'English',
    'code': 'en',
    'locale': Locale('en'),
  };
  
  static const Map<String, dynamic> AR = {
    'name': 'العربية',
    'code': 'ar',
    'locale': Locale('ar'),
  };
  
  static const Map<String, dynamic> UR = {
    'name': 'اردو',
    'code': 'ur',
    'locale': Locale('ur'),
  };
}

class AppLocalization {
  final Locale locale;
  late Map<String, dynamic> _localizedStrings;
  
  AppLocalization(this.locale);
  
  static AppLocalization? of(BuildContext context) {
    return Localizations.of<AppLocalization>(context, AppLocalization);
  }
  
  Future<bool> load() async {
    String jsonString = await rootBundle.loadString(
      'assets/translations/${locale.languageCode}.json',
    );
    Map<String, dynamic> jsonMap = json.decode(jsonString);
    
    _localizedStrings = jsonMap;
    
    return true;
  }
  
  String translate(String key) {
    // Split the key to handle nested keys
    List<String> keys = key.split('.');
    dynamic value = _localizedStrings;
    
    for (String k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Return the key itself if translation not found
      }
    }
    
    return value.toString();
  }
  
  // Helper method for easy access
  String get appName => translate('app_name');
  String get welcome => translate('welcome');
}

class AppLocalizationDelegate extends LocalizationsDelegate<AppLocalization> {
  const AppLocalizationDelegate();
  
  @override
  bool isSupported(Locale locale) {
    return ['en', 'ar', 'ur'].contains(locale.languageCode);
  }
  
  @override
  Future<AppLocalization> load(Locale locale) async {
    AppLocalization localization = AppLocalization(locale);
    await localization.load();
    return localization;
  }
  
  @override
  bool shouldReload(AppLocalizationDelegate old) => false;
}