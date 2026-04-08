import 'package:flutter/material.dart';
import '../../core/api/metalpriceapi_service.dart';

class CurrencySelector extends StatelessWidget {
  final String selectedCurrency;
  final Function(String) onCurrencyChanged;
  
  const CurrencySelector({
    super.key,
    required this.selectedCurrency,
    required this.onCurrencyChanged,
  });
  
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: onCurrencyChanged,
      itemBuilder: (context) => _buildCurrencyMenu(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Text(
              selectedCurrency,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).primaryColor,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: Theme.of(context).primaryColor,
            ),
          ],
        ),
      ),
    );
  }
  
  List<PopupMenuItem<String>> _buildCurrencyMenu(BuildContext context) {
    final List<PopupMenuItem<String>> items = [];
    
    // Priority currencies
    final priorityCurrencies = [
      Currency(code: 'USD', name: 'US Dollar', flag: '🇺🇸', isArabCurrency: false),
      Currency(code: 'SAR', name: 'Saudi Riyal', flag: '🇸🇦', isArabCurrency: true),
      Currency(code: 'AED', name: 'UAE Dirham', flag: '🇦🇪', isArabCurrency: true),
      Currency(code: 'EGP', name: 'Egyptian Pound', flag: '🇪🇬', isArabCurrency: true),
      Currency(code: 'KWD', name: 'Kuwaiti Dinar', flag: '🇰🇼', isArabCurrency: true),
      Currency(code: 'BHD', name: 'Bahraini Dinar', flag: '🇧🇭', isArabCurrency: true),
      Currency(code: 'OMR', name: 'Omani Rial', flag: '🇴🇲', isArabCurrency: true),
      Currency(code: 'QAR', name: 'Qatari Riyal', flag: '🇶🇦', isArabCurrency: true),
      Currency(code: 'JOD', name: 'Jordanian Dinar', flag: '🇯🇴', isArabCurrency: true),
    ];
    
    // Recent section header
    items.add(
      const PopupMenuItem(
        enabled: false,
        child: Text(
          'ARAB CURRENCIES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        
      ),
    );
    
    // Add Arab currencies
    for (final currency in priorityCurrencies) {
      items.add(_buildCurrencyItem(currency));
    }
    
    items.add(const PopupMenuItem(child: Divider()));
    
    // Other currencies header
    items.add(
      const PopupMenuItem(
        enabled: false,
        child: Text(
          'OTHER CURRENCIES',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
      ),
    );
    
    // Add other major currencies
    final otherCurrencies = [
      Currency(code: 'EUR', name: 'Euro', flag: '🇪🇺', isArabCurrency: false),
      Currency(code: 'GBP', name: 'British Pound', flag: '🇬🇧', isArabCurrency: false),
      Currency(code: 'JPY', name: 'Japanese Yen', flag: '🇯🇵', isArabCurrency: false),
      Currency(code: 'CNY', name: 'Chinese Yuan', flag: '🇨🇳', isArabCurrency: false),
      Currency(code: 'INR', name: 'Indian Rupee', flag: '🇮🇳', isArabCurrency: false),
      Currency(code: 'PKR', name: 'Pakistani Rupee', flag: '🇵🇰', isArabCurrency: false),
      Currency(code: 'TRY', name: 'Turkish Lira', flag: '🇹🇷', isArabCurrency: false),
    ];
    
    for (final currency in otherCurrencies) {
      items.add(_buildCurrencyItem(currency));
    }
    
    return items;
  }
  
  PopupMenuItem<String> _buildCurrencyItem(Currency currency) {
    return PopupMenuItem<String>(
      value: currency.code,
      child: Row(
        children: [
          Text(
            currency.flag,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  currency.code,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  currency.name,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          if (currency.code == selectedCurrency)
            const Icon(
              Icons.check,
              color: Colors.green,
              size: 20,
            ),
        ],
      ),
    );
  }
}