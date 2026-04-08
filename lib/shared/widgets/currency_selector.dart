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
      itemBuilder: (context) => _buildCurrencyMenu(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
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

  List<PopupMenuItem<String>> _buildCurrencyMenu() {
    final List<PopupMenuItem<String>> items = [];

    final priorityCurrencies = [
      Currency(code: 'USD', name: 'US Dollar', isArabCurrency: false),
      Currency(code: 'SAR', name: 'Saudi Riyal', isArabCurrency: true),
      Currency(code: 'AED', name: 'UAE Dirham', isArabCurrency: true),
      Currency(code: 'EGP', name: 'Egyptian Pound', isArabCurrency: true),
      Currency(code: 'KWD', name: 'Kuwaiti Dinar', isArabCurrency: true),
      Currency(code: 'BHD', name: 'Bahraini Dinar', isArabCurrency: true),
      Currency(code: 'OMR', name: 'Omani Rial', isArabCurrency: true),
      Currency(code: 'QAR', name: 'Qatari Riyal', isArabCurrency: true),
      Currency(code: 'JOD', name: 'Jordanian Dinar', isArabCurrency: true),
    ];

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

    for (final currency in priorityCurrencies) {
      items.add(_buildCurrencyItem(currency));
    }

    items.add(const PopupMenuItem(child: Divider()));

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

    final otherCurrencies = [
      Currency(code: 'EUR', name: 'Euro', isArabCurrency: false),
      Currency(code: 'GBP', name: 'British Pound', isArabCurrency: false),
      Currency(code: 'JPY', name: 'Japanese Yen', isArabCurrency: false),
      Currency(code: 'CNY', name: 'Chinese Yuan', isArabCurrency: false),
      Currency(code: 'INR', name: 'Indian Rupee', isArabCurrency: false),
      Currency(code: 'PKR', name: 'Pakistani Rupee', isArabCurrency: false),
      Currency(code: 'TRY', name: 'Turkish Lira', isArabCurrency: false),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
