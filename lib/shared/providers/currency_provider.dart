import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final selectedCurrencyProvider = NotifierProvider<CurrencyNotifier, String>(() {
  return CurrencyNotifier();
});

class CurrencyNotifier extends Notifier<String> {
  @override
  String build() {
    _loadSavedCurrency();
    return 'USD';
  }
  
  Future<void> _loadSavedCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    final savedCurrency = prefs.getString('selected_currency');
    if (savedCurrency != null) {
      state = savedCurrency;
    }
  }
  
  Future<void> setCurrency(String currency) async {
    state = currency;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_currency', currency);
  }
}

// Available currencies with prioritization for Arab currencies
final availableCurrenciesProvider = Provider<List<String>>((ref) {
  return [
    'USD',  // Default
    'SAR',  // Saudi Arabia
    'AED',  // UAE
    'EGP',  // Egypt
    'KWD',  // Kuwait
    'BHD',  // Bahrain
    'OMR',  // Oman
    'QAR',  // Qatar
    'JOD',  // Jordan
    'EUR',
    'GBP',
    'INR',
    'PKR',
    'CAD',
    'AUD',
    'JPY',
    'CNY',
  ];
});