import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/metalpriceapi_service.dart';
import '../../../../shared/models/metal_price.dart';
import '../../../../shared/providers/metal_price_provider.dart';
import '../../../../shared/providers/currency_provider.dart';
import '../../../../shared/widgets/price_card.dart';
import '../../../../shared/widgets/currency_selector.dart';

class PricesScreen extends ConsumerStatefulWidget {
  const PricesScreen({super.key});

  @override
  ConsumerState<PricesScreen> createState() => _PricesScreenState();
}

class _PricesScreenState extends ConsumerState<PricesScreen> {
  final MetalPriceApiService _apiService = MetalPriceApiService();
  
  bool _isLoading = false;
  bool _isRefreshing = false;
  MetalPricesResponse? _pricesData;
  DateTime _lastUpdated = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Show cached data instantly if available
    final cached = _apiService.getCachedPrices();
    if (cached != null) {
      _pricesData = cached;
      _lastUpdated = cached.timestamp;
      // Delay provider update to after widget tree finishes building
      Future(() => _pushToProviders(cached, ref.read(selectedCurrencyProvider)));
      setState(() {}); // render immediately with cached data
    } else {
      setState(() => _isLoading = true);
    }

    // Always fetch fresh data in background
    await _fetchFresh();
    if (_isLoading) setState(() => _isLoading = false);
  }

  Future<void> _fetchFresh() async {
    try {
      final response = await _apiService.fetchFreshPrices();

      setState(() {
        _pricesData = response;
        _lastUpdated = response.timestamp;
      });

      _pushToProviders(response, ref.read(selectedCurrencyProvider));
    } catch (e) {
      // Only show error if we have nothing to display
      if (_pricesData == null) {
        _showErrorSnackBar('Failed to fetch prices');
      }
    }
  }

  void _pushToProviders(MetalPricesResponse response, String currency) {
    final goldPrice = response.goldPriceIn(currency);
    if (goldPrice != null) {
      ref.read(metalPriceProvider.notifier).updatePrice(MetalPrice(
        metal: 'Gold',
        pricePerOunce: goldPrice,
        pricePerGram: goldPrice / 31.1034768,
        currency: currency,
        timestamp: response.timestamp,
        change24h: 0,
        changePercent24h: 0,
      ));
    }
    final silverPrice = response.silverPriceIn(currency);
    if (silverPrice != null) {
      ref.read(silverPriceProvider.notifier).updatePrice(MetalPrice(
        metal: 'Silver',
        pricePerOunce: silverPrice,
        pricePerGram: silverPrice / 31.1034768,
        currency: currency,
        timestamp: response.timestamp,
        change24h: 0,
        changePercent24h: 0,
      ));
    }
  }

  Future<void> _handleManualRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchFresh();
    setState(() => _isRefreshing = false);
  }

  void _onCurrencyChanged(String currency) {
    // Update global provider (persists to SharedPreferences automatically)
    ref.read(selectedCurrencyProvider.notifier).setCurrency(currency);

    // Push converted prices to other screens
    if (_pricesData != null) {
      _pushToProviders(_pricesData!, currency);
    }
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final selectedCurrency = ref.watch(selectedCurrencyProvider);

    // Re-push prices when currency changes from another screen
    ref.listen<String>(selectedCurrencyProvider, (prev, next) {
      if (_pricesData != null && prev != next) {
        _pushToProviders(_pricesData!, next);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gold & Silver Prices'),
        actions: [
          // Refresh button
          IconButton(
            onPressed: _isRefreshing ? null : _handleManualRefresh,
            icon: AnimatedRotation(
              turns: _isRefreshing ? 1 : 0,
              duration: const Duration(seconds: 1),
              child: const Icon(Icons.refresh),
            ),
          ),

          // Currency selector
          CurrencySelector(
            selectedCurrency: selectedCurrency,
            onCurrencyChanged: _onCurrencyChanged,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _handleManualRefresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Last updated time
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withValues(alpha:0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Updated: ${DateFormat('MMM dd, HH:mm').format(_lastUpdated)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(),
                  
                  const SizedBox(height: 16),
                  
                  // Gold price card
                  if (_pricesData != null) ...[
                    Builder(builder: (_) {
                      final prevPrices = _apiService.getPreviousPrices();
                      final goldPrice = _pricesData!.goldPriceIn(selectedCurrency) ?? 0;
                      final prevGoldPrice = prevPrices?.goldPriceIn(selectedCurrency) ?? goldPrice;
                      final goldChange = goldPrice - prevGoldPrice;
                      final goldChangePercent = prevGoldPrice != 0
                          ? (goldChange / prevGoldPrice) * 100
                          : 0.0;
                      final silverPrice = _pricesData!.silverPriceIn(selectedCurrency) ?? 0;
                      final prevSilverPrice = prevPrices?.silverPriceIn(selectedCurrency) ?? silverPrice;
                      final silverChange = silverPrice - prevSilverPrice;
                      final silverChangePercent = prevSilverPrice != 0
                          ? (silverChange / prevSilverPrice) * 100
                          : 0.0;

                      return Column(children: [
                    PriceCard(
                      metal: 'Gold',
                      icon: Icons.monetization_on,
                      color: const Color(0xFFFFD700),
                      pricePerOunce: goldPrice,
                      pricePerGram: goldPrice / 31.1034768,
                      currency: selectedCurrency,
                      change24h: goldChange,
                      changePercent: goldChangePercent,
                    ).animate().slideX(begin: -1, duration: 600.ms),

                    const SizedBox(height: 16),

                    // Silver price card
                    PriceCard(
                      metal: 'Silver',
                      icon: Icons.paid,
                      color: const Color(0xFFC0C0C0),
                      pricePerOunce: silverPrice,
                      pricePerGram: silverPrice / 31.1034768,
                      currency: selectedCurrency,
                      change24h: silverChange,
                      changePercent: silverChangePercent,
                    ).animate().slideX(begin: 1, duration: 600.ms),
                      ]);
                    }),
                    
                    const SizedBox(height: 24),
                    
                    // Quick karat prices
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Gold Karat Prices (per gram)',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            _buildKaratPrice('24K', 1.0),
                            _buildKaratPrice('22K', 0.916),
                            _buildKaratPrice('21K', 0.875),
                            _buildKaratPrice('18K', 0.75),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 300.ms),
                  ],
                ],
              ),
            ),
    );
  }
  
  Widget _buildKaratPrice(String karat, double purity) {
    final selectedCurrency = ref.read(selectedCurrencyProvider);
    final goldPricePerGram = (_pricesData?.goldPriceIn(selectedCurrency) ?? 0) / 31.1034768;
    final karatPrice = goldPricePerGram * purity;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha:0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  karat,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${(purity * 100).toInt()}% Pure',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          Text(
            '$selectedCurrency ${karatPrice.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}