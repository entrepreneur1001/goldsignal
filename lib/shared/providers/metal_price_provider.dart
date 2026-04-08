import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api/metalpriceapi_service.dart';
import '../models/metal_price.dart';

final metalPriceApiProvider = Provider<MetalPriceApiService>((ref) {
  return MetalPriceApiService();
});

final metalPriceProvider = NotifierProvider<MetalPriceNotifier, MetalPrice?>(() {
  return MetalPriceNotifier();
});

class MetalPriceNotifier extends Notifier<MetalPrice?> {
  late MetalPriceApiService _apiService;
  
  @override
  MetalPrice? build() {
    _apiService = ref.watch(metalPriceApiProvider);
    fetchLatestPrices();
    return null;
  }
  
  Future<void> fetchLatestPrices({String currency = 'USD'}) async {
    try {
      final response = await _apiService.getLatestPrices(currency: currency);
      final goldPrice = response.goldPrice;
      if (goldPrice != null) {
        state = MetalPrice(
          metal: 'Gold',
          pricePerOunce: goldPrice,
          pricePerGram: goldPrice / 31.1034768,
          currency: currency,
          timestamp: response.timestamp,
          change24h: 0,
          changePercent24h: 0,
        );
      }
    } catch (e) {
      // State remains null on error
    }
  }

  void updatePrice(MetalPrice price) {
    state = price;
  }
}

final silverPriceProvider = NotifierProvider<SilverPriceNotifier, MetalPrice?>(() {
  return SilverPriceNotifier();
});

class SilverPriceNotifier extends Notifier<MetalPrice?> {
  late MetalPriceApiService _apiService;

  @override
  MetalPrice? build() {
    _apiService = ref.watch(metalPriceApiProvider);
    fetchLatestPrices();
    return null;
  }

  Future<void> fetchLatestPrices({String currency = 'USD'}) async {
    try {
      final response = await _apiService.getLatestPrices(currency: currency);
      final silverPrice = response.silverPrice;
      if (silverPrice != null) {
        state = MetalPrice(
          metal: 'Silver',
          pricePerOunce: silverPrice,
          pricePerGram: silverPrice / 31.1034768,
          currency: currency,
          timestamp: response.timestamp,
          change24h: 0,
          changePercent24h: 0,
        );
      }
    } catch (e) {
      // State remains null on error
    }
  }

  void updatePrice(MetalPrice price) {
    state = price;
  }
}