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
  @override
  MetalPrice? build() => null;

  void updatePrice(MetalPrice price) {
    state = price;
  }
}

final silverPriceProvider = NotifierProvider<SilverPriceNotifier, MetalPrice?>(() {
  return SilverPriceNotifier();
});

class SilverPriceNotifier extends Notifier<MetalPrice?> {
  @override
  MetalPrice? build() => null;

  void updatePrice(MetalPrice price) {
    state = price;
  }
}