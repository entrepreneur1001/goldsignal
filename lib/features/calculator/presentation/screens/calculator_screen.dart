import '../../../../core/utils/app_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../core/utils/currency_format.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/widgets/currency_selector.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';
import '../../../../shared/widgets/native_ad_widget.dart';
import 'package:easy_localization/easy_localization.dart';

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
  void initState() {
    super.initState();
    // Default to 24K globally; Egypt's local market conventionally uses 21K.
    _selectedKarat =
        ref.read(selectedCurrencyProvider) == 'EGP' ? 21 : 24;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
  
  void _calculateValue() {
    final goldPrice = ref.read(metalPriceProvider);
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    final side = ref.read(priceSideProvider);

    if (_weightController.text.isEmpty) {
      setState(() => _totalValue = 0.0);
      return;
    }

    final weight = double.tryParse(_weightController.text) ?? 0.0;
    final quantity = (int.tryParse(_quantityController.text) ?? 1).clamp(1, 1 << 30);

    final karatPrice = activeGoldKaratPrice(
      isLocal: isLocal,
      local: local,
      globalGold: goldPrice,
      karat: _selectedKarat,
      side: side,
    );

    if (karatPrice == null) {
      setState(() => _totalValue = 0.0);
      return;
    }

    setState(() {
      _totalValue = karatPrice * weight * quantity;
    });
    _syncCalculatorUse();
  }

  Future<void> _syncCalculatorUse() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final count = await incrementCalculatorUseCount();
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'calculatorUseCount': count,
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal.
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final isLocal = ref.watch(isLocalMarketProvider);
    final priceSide = ref.watch(priceSideProvider);

    ref.listen(selectedCurrencyProvider, (prev, next) {
      if (next == 'EGP' && _selectedKarat == 24) {
        setState(() => _selectedKarat = 21);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('calculator.egypt_21k_note')),
            duration: const Duration(seconds: 3),
          ),
        );
      }
      _calculateValue();
    });
    ref.listen(priceSideProvider, (_, _) => _calculateValue());
    ref.listen(metalPriceProvider, (_, _) => _calculateValue());
    ref.listen(localMarketPricesProvider, (_, _) => _calculateValue());

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
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('calculator.screen_title'),
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const AlertsNavButton(),
                    const SizedBox(width: 4),
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

                if (isLocal) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VaultColors.goldDeep.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      // TODO(i18n-review): verify ar/ur wording for 'calculator.local_note'
                      context.tr('calculator.local_note', namedArgs: {
                        'side': priceSide.name == 'sell'
                            ? context.tr('charts.sell')
                            : context.tr('charts.buy'),
                      }),
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                // Karat Selection
                Text(
                  context.tr('calculator.select_karat'),
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
                                  ? VaultColors.gold
                                  : isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? VaultColors.gold
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                context.tr(
                                  'calculator.karat_label',
                                  namedArgs: {'karat': '$karat'},
                                ),
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
                  context.tr('calculator.weight_grams'),
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
                    hintText: context.tr('calculator.weight_hint'),
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
                  context.tr('calculator.quantity'),
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
                    hintText: context.tr('calculator.quantity_hint'),
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
                        VaultColors.gold,
                        VaultColors.gold.withValues(alpha: 0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: VaultColors.gold.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.tr('calculator.total_value'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Consumer(
                        builder: (context, ref, child) {
                          final currency = ref.watch(selectedCurrencyProvider);
                          return Text(
                            formatCurrency(_totalValue, currency),
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
                
                const SizedBox(height: 24),

                // Info Card
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
                          context.tr('calculator.disclaimer'),
                          style: TextStyle(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const NativeAdWidget(),
                const SizedBox(height: 88),
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
    final quantity = (int.tryParse(_quantityController.text) ?? 1).clamp(1, 1 << 30);
    final isLocal = ref.read(isLocalMarketProvider);
    final local = ref.read(localMarketPricesProvider);
    final side = ref.read(priceSideProvider);
    final karatPrice = activeGoldKaratPrice(
      isLocal: isLocal,
      local: local,
      globalGold: goldPrice,
      karat: _selectedKarat,
      side: side,
    ) ?? 0.0;
    
    return Column(
      children: [
        _buildDetailRow(
            context.tr('calculator.weight'), '${weight.toStringAsFixed(2)} g'),
        const SizedBox(height: 8),
        _buildDetailRow(
          context.tr('calculator.karat'),
          context.tr('calculator.karat_label', namedArgs: {'karat': '$_selectedKarat'}),
        ),
        const SizedBox(height: 8),
        _buildDetailRow(context.tr('calculator.quantity'), quantity.toString()),
        const SizedBox(height: 8),
        _buildDetailRow(
          context.tr('calculator.price_per_gram'),
          formatCurrency(karatPrice, currency),
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
  
}