import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/widgets/currency_selector.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  const CalculatorScreen({super.key});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController(text: '1');
  
  int _selectedKarat = 24;
  double _totalValue = 0.0;
  
  final List<int> _karatOptions = [24, 22, 21, 18];
  
  @override
  void dispose() {
    _weightController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
  
  void _calculateValue() {
    final goldPrice = ref.read(metalPriceProvider);

    if (goldPrice == null || _weightController.text.isEmpty) {
      setState(() {
        _totalValue = 0.0;
      });
      return;
    }
    
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    
    // Get price per gram in selected currency
    final pricePerGram = goldPrice.getPricePerGram();
    
    // Calculate karat price
    final karatPrice = pricePerGram * (_selectedKarat / 24);
    
    // Calculate total value
    setState(() {
      _totalValue = karatPrice * weight * quantity;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Gold Calculator',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Consumer(
                      builder: (context, ref, child) {
                        final currency = ref.watch(selectedCurrencyProvider);
                        return CurrencySelector(
                          selectedCurrency: currency,
                          onCurrencyChanged: (newCurrency) {
                            ref.read(selectedCurrencyProvider.notifier).setCurrency(newCurrency);
                            _calculateValue();
                          },
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                
                // Karat Selection
                Text(
                  'Select Karat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: _karatOptions.map((karat) {
                    final isSelected = _selectedKarat == karat;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedKarat = karat;
                            });
                            _calculateValue();
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFFFB800)
                                  : isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFFFFB800)
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '${karat}K',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : isDark
                                          ? Colors.white70
                                          : Colors.black87,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                
                // Weight Input
                Text(
                  'Weight (grams)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (_) => _calculateValue(),
                  decoration: InputDecoration(
                    hintText: 'Enter weight in grams',
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.scale),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Quantity Input
                Text(
                  'Quantity',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onChanged: (_) => _calculateValue(),
                  decoration: InputDecoration(
                    hintText: 'Number of items',
                    filled: true,
                    fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(Icons.inventory_2),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Result Card
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFFFB800),
                        const Color(0xFFFFB800).withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFB800).withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Value',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final currency = ref.watch(selectedCurrencyProvider);
                          return Text(
                            _formatCurrency(_totalValue, currency),
                            style: theme.textTheme.headlineLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      if (_totalValue > 0) ...[
                        const SizedBox(height: 16),
                        const Divider(color: Colors.white24),
                        const SizedBox(height: 16),
                        _buildCalculationDetails(),
                      ],
                    ],
                  ),
                ),
                
                // Info Card
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue[700],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This calculator provides estimated values based on current market prices. Actual prices may vary.',
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildCalculationDetails() {
    final goldPrice = ref.read(metalPriceProvider);
    final currency = ref.read(selectedCurrencyProvider);
    
    if (goldPrice == null || _weightController.text.isEmpty) {
      return const SizedBox.shrink();
    }
    
    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final quantity = int.tryParse(_quantityController.text) ?? 1;
    final pricePerGram = goldPrice.getPricePerGram();
    final karatPrice = pricePerGram * (_selectedKarat / 24);
    
    return Column(
      children: [
        _buildDetailRow('Weight', '${weight.toStringAsFixed(2)} g'),
        const SizedBox(height: 8),
        _buildDetailRow('Karat', '${_selectedKarat}K'),
        const SizedBox(height: 8),
        _buildDetailRow('Quantity', quantity.toString()),
        const SizedBox(height: 8),
        _buildDetailRow(
          'Price per gram',
          _formatCurrency(karatPrice, currency),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
  
  String _formatCurrency(double value, String currency) {
    final symbols = {
      'USD': '\$',
      'SAR': 'SAR ',
      'AED': 'AED ',
      'EGP': 'EGP ',
      'KWD': 'KWD ',
      'EUR': '€',
      'GBP': '£',
    };
    
    final symbol = symbols[currency] ?? '$currency ';
    return '$symbol${value.toStringAsFixed(2)}';
  }
}