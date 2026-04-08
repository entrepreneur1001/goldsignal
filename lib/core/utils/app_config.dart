import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static late SharedPreferences _prefs;
  static SharedPreferences get prefs => _prefs;
  
  static Future<void> initialize() async {
    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();
    
    // Initialize Hive boxes
    await _initHiveBoxes();
    
    // Set default values if first run
    await _setDefaults();
  }
  
  static Future<void> _initHiveBoxes() async {
    // Open Hive boxes for caching
    await Hive.openBox('goldPrices');
    await Hive.openBox('silverPrices');
    await Hive.openBox('currencyRates');
    await Hive.openBox('userAlerts');
    await Hive.openBox('portfolio');
    await Hive.openBox('chatHistory');
  }
  
  static Future<void> _setDefaults() async {
    // Set default preferences if not already set
    if (!_prefs.containsKey('currency')) {
      await _prefs.setString('currency', 'USD');
    }
    if (!_prefs.containsKey('language')) {
      await _prefs.setString('language', 'en');
    }
    if (!_prefs.containsKey('karat')) {
      await _prefs.setString('karat', '24K');
    }
    if (!_prefs.containsKey('unit')) {
      await _prefs.setString('unit', 'gram');
    }
    if (!_prefs.containsKey('theme')) {
      await _prefs.setString('theme', 'system');
    }
  }
  
  // Helper methods for preferences
  static String get defaultCurrency => _prefs.getString('currency') ?? 'USD';
  static String get defaultLanguage => _prefs.getString('language') ?? 'en';
  static String get defaultKarat => _prefs.getString('karat') ?? '24K';
  static String get defaultUnit => _prefs.getString('unit') ?? 'gram';
  static String get themeMode => _prefs.getString('theme') ?? 'system';
  
  static Future<void> setCurrency(String currency) async {
    await _prefs.setString('currency', currency);
  }
  
  static Future<void> setLanguage(String language) async {
    await _prefs.setString('language', language);
  }
  
  static Future<void> setKarat(String karat) async {
    await _prefs.setString('karat', karat);
  }
  
  static Future<void> setUnit(String unit) async {
    await _prefs.setString('unit', unit);
  }
  
  static Future<void> setThemeMode(String mode) async {
    await _prefs.setString('theme', mode);
  }
}