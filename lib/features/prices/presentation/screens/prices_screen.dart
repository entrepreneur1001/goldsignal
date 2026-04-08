import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:goldsignal/core/utils/api_config.dart';
import 'package:intl/intl.dart';
import '../../../../core/api/metalpriceapi_service.dart';
import '../../../../core/utils/app_config.dart';
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
  String _selectedCurrency = 'USD';
  DateTime _lastUpdated = DateTime.now();
  int _refreshCount = 0;
  
  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    
    // Get saved currency preference
    _selectedCurrency = AppConfig.defaultCurrency;
    
    await _fetchPrices();
    
    setState(() => _isLoading = false);
  }
  
  Future<void> _fetchPrices({bool forceRefresh = false}) async {
    try {
      final response = await _apiService.getLatestPrices(
        currency: _selectedCurrency,
        forceRefresh: forceRefresh,
      );
      
      setState(() {
        _pricesData = response;
        _lastUpdated = response.timestamp;
      });
    } catch (e) {
      _showErrorSnackBar('Failed to fetch prices');
    }
  }
  
  Future<void> _handleManualRefresh() async {
    // Check daily refresh limit
    if (_refreshCount >= ApiConfig.userRefreshDailyLimit) {
      _showErrorSnackBar('Daily refresh limit reached');
      return;
    }
    
    setState(() => _isRefreshing = true);
    
    await _fetchPrices(forceRefresh: true);
    _refreshCount++;
    
    setState(() => _isRefreshing = false);
  }
  
  void _onCurrencyChanged(String currency) async {
    setState(() {
      _selectedCurrency = currency;
      _isLoading = true;
    });
    
    // Save preference
    await AppConfig.setCurrency(currency);
    
    // Fetch new prices
    await _fetchPrices();
    
    setState(() => _isLoading = false);
  }
  
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
  
  @override
  Widget build(BuildContext context) {
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
            selectedCurrency: _selectedCurrency,
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
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                        const Spacer(),
                        if (_refreshCount > 0)
                          Chip(
                            label: Text(
                              'Refreshes: $_refreshCount/${ApiConfig.userRefreshDailyLimit}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ).animate().fadeIn(),
                  
                  const SizedBox(height: 16),
                  
                  // Gold price card
                  if (_pricesData != null) ...[
                    PriceCard(
                      metal: 'Gold',
                      icon: Icons.monetization_on,
                      color: const Color(0xFFFFD700),
                      pricePerOunce: _pricesData!.goldPrice ?? 0,
                      pricePerGram: (_pricesData!.goldPrice ?? 0) / 31.1034768,
                      currency: _selectedCurrency,
                      change24h: 2.5, // Mock data - would come from API
                      changePercent: 0.13, // Mock data
                    ).animate().slideX(begin: -1, duration: 600.ms),
                    
                    const SizedBox(height: 16),
                    
                    // Silver price card
                    PriceCard(
                      metal: 'Silver',
                      icon: Icons.paid,
                      color: const Color(0xFFC0C0C0),
                      pricePerOunce: _pricesData!.silverPrice ?? 0,
                      pricePerGram: (_pricesData!.silverPrice ?? 0) / 31.1034768,
                      currency: _selectedCurrency,
                      change24h: 0.05, // Mock data
                      changePercent: 0.21, // Mock data
                    ).animate().slideX(begin: 1, duration: 600.ms),
                    
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
    final goldPricePerGram = (_pricesData?.goldPrice ?? 0) / 31.1034768;
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
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
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
            '$_selectedCurrency ${karatPrice.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}