import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/metal_performance_service.dart';
import '../models/metal_performance.dart';
import 'currency_provider.dart';

const _cacheTtl = Duration(minutes: 20);

final metalPerformanceServiceProvider = Provider<MetalPerformanceService>((ref) {
  return MetalPerformanceService();
});

/// Cached gold + silver performance for the selected currency.
final metalPerformanceProvider =
    NotifierProvider<MetalPerformanceNotifier, AsyncValue<MetalPerformanceData?>>(
  MetalPerformanceNotifier.new,
);

class MetalPerformanceNotifier
    extends Notifier<AsyncValue<MetalPerformanceData?>> {
  MetalPerformanceData? _cache;
  String? _cacheCurrency;
  DateTime? _cacheAt;

  @override
  AsyncValue<MetalPerformanceData?> build() {
    ref.listen<String>(selectedCurrencyProvider, (prev, next) {
      if (prev != next) {
        Future.microtask(() => load(force: false));
      }
    });
    Future.microtask(() => load(force: false));
    return const AsyncValue.loading();
  }

  Future<void> load({bool force = false}) async {
    final currency = ref.read(selectedCurrencyProvider);
    final now = DateTime.now();
    if (!force &&
        _cache != null &&
        _cacheCurrency == currency &&
        _cacheAt != null &&
        now.difference(_cacheAt!) < _cacheTtl) {
      state = AsyncValue.data(_cache);
      return;
    }

    final hadData = state.hasValue && state.value != null;
    if (!hadData) {
      state = const AsyncValue.loading();
    }

    try {
      final data =
          await ref.read(metalPerformanceServiceProvider).fetch(currency);
      if (data.isEmpty) {
        _cache = null;
        _cacheCurrency = currency;
        _cacheAt = now;
        state = const AsyncValue.data(null);
        return;
      }
      _cache = data;
      _cacheCurrency = currency;
      _cacheAt = now;
      state = AsyncValue.data(data);
    } catch (_) {
      // Soft-fail: keep previous data if any, otherwise hide the section.
      if (!hadData) {
        state = const AsyncValue.data(null);
      }
    }
  }

  /// Force refetch (Prices pull-to-refresh / refresh button).
  Future<void> refresh() => load(force: true);
}
