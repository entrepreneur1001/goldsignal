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
  
  Future<void> fetchLatestPrices() async {
    try {
      final response = await _apiService.getLatestPrices(currency: 'USD');
      // Assuming the response contains gold price data
      // You'll need to adjust this based on the actual API response structure
    } catch (e) {
      // Handle error
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
  
  Future<void> fetchLatestPrices() async {
    try {
      final response = await _apiService.getLatestPrices(currency: 'USD');
      // Assuming the response contains silver price data
      // You'll need to adjust this based on the actual API response structure
    } catch (e) {
      // Handle error
    }
  }
  
  void updatePrice(MetalPrice price) {
    state = price;
  }
}