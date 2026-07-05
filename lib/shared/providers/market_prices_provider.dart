import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/firebase/firestore_price_service.dart';
import '../../core/api/isagha_price_scraper.dart';
import '../../core/api/goodreturns_price_scraper.dart';
import '../../core/crash/crash_reporter.dart';
import '../../core/firebase/firestore_price_history_service.dart';
import '../../core/storage/price_history_service.dart';
import '../../core/api/metalpriceapi_service.dart';
import '../../core/widget/home_widget_service.dart';
import '../local_market/local_market_config.dart';
import '../models/local_market_prices.dart';
import '../models/metal_price.dart';
import 'currency_provider.dart';
import 'metal_price_provider.dart';
import 'price_alerts_provider.dart';
import 'widget_preferences_provider.dart';

const _ounceToGram = 31.1034768;

final priceHistoryServiceProvider = Provider<PriceHistoryService>((ref) {
  return PriceHistoryService();
});

final firestorePriceHistoryServiceProvider =
    Provider<FirestorePriceHistoryService>((ref) {
  return FirestorePriceHistoryService();
});

final firestorePriceServiceProvider = Provider<FirestorePriceService>((ref) {
  return FirestorePriceService();
});

final isaghaScraperProvider = Provider<IsaghaPriceScraper>((ref) {
  return IsaghaPriceScraper();
});

final goodreturnsScraperProvider = Provider<GoodreturnsPriceScraper>((ref) {
  return GoodreturnsPriceScraper();
});

final isLocalMarketProvider = Provider<bool>((ref) {
  final currency = ref.watch(selectedCurrencyProvider);
  return LocalMarketConfig.isLocalCurrency(currency);
});

final priceSideProvider = NotifierProvider<PriceSideNotifier, PriceSide>(() {
  return PriceSideNotifier();
});

class PriceSideNotifier extends Notifier<PriceSide> {
  @override
  PriceSide build() {
    _loadSaved();
    return PriceSide.sell;
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('price_side');
    if (saved == 'buy') {
      state = PriceSide.buy;
    }
  }

  Future<void> setSide(PriceSide side) async {
    state = side;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('price_side', side.name);
    // applyCurrentPrices is triggered by MarketPricesController's
    // ref.listen(priceSideProvider) — do not read that provider here
    // or Riverpod reports a circular dependency.
  }
}

final localMarketPricesProvider =
    NotifierProvider<LocalMarketPricesNotifier, LocalMarketPrices?>(() {
  return LocalMarketPricesNotifier();
});

class LocalMarketPricesNotifier extends Notifier<LocalMarketPrices?> {
  @override
  LocalMarketPrices? build() => null;

  void update(LocalMarketPrices? prices) => state = prices;
}

class MarketPricesState {
  final MetalPricesResponse? globalData;
  final bool isRefreshing;
  final String? error;
  final DateTime? lastUpdated;

  const MarketPricesState({
    this.globalData,
    this.isRefreshing = false,
    this.error,
    this.lastUpdated,
  });

  MarketPricesState copyWith({
    MetalPricesResponse? globalData,
    bool? isRefreshing,
    String? error,
    DateTime? lastUpdated,
    bool clearError = false,
  }) {
    return MarketPricesState(
      globalData: globalData ?? this.globalData,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      error: clearError ? null : (error ?? this.error),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

final marketPricesControllerProvider =
    NotifierProvider<MarketPricesController, MarketPricesState>(() {
  return MarketPricesController();
});

class MarketPricesController extends Notifier<MarketPricesState> {
  Timer? _hourlyTimer;

  @override
  MarketPricesState build() {
    ref.listen<String>(selectedCurrencyProvider, (prev, next) {
      if (prev != next) {
        ref.read(widgetPreferencesProvider.notifier).normalizeForCurrency(next);
        refresh();
      }
    });
    ref.listen<PriceSide>(priceSideProvider, (prev, next) {
      if (prev != next) applyCurrentPrices();
    });
    ref.listen<WidgetPreferences>(widgetPreferencesProvider, (prev, next) {
      if (prev != next) _updateHomeWidget();
    });

    _hourlyTimer?.cancel();
    _hourlyTimer = Timer.periodic(const Duration(hours: 1), (_) => refresh());
    ref.onDispose(() => _hourlyTimer?.cancel());

    Future.microtask(refresh);
    return const MarketPricesState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isRefreshing: true, clearError: true);

    try {
      final currency = ref.read(selectedCurrencyProvider);
      if (currency == 'EGP') {
        await _refreshLocalEgypt();
      } else if (currency == 'INR') {
        await _refreshLocalIndia();
      } else {
        await _refreshGlobal(currency);
      }
      applyCurrentPrices();
      state = state.copyWith(
        isRefreshing: false,
        lastUpdated: DateTime.now(),
        clearError: true,
      );
      try {
        await ref.read(priceAlertsProvider.notifier).checkAgainstLatestPrices();
      } catch (e, st) {
        reportNonFatal(e, st, reason: 'price alert check failed');
      }
    } catch (e) {
      state = state.copyWith(
        isRefreshing: false,
        error: e.toString(),
      );
    }
  }

  Future<void> _refreshLocalEgypt() async {
    final firestore = ref.read(firestorePriceServiceProvider);
    final scraper = ref.read(isaghaScraperProvider);
    LocalMarketPrices? local;

    local = await firestore.getCachedLocalMarketPrices('EGP');
    if (local == null) {
      try {
        local = await scraper.fetchLatestPrices();
      } catch (_) {
        local = await firestore.getStaleLocalMarketPrices('EGP') ??
            scraper.getCachedPrices();
        if (local == null) rethrow;
      }
    }

    ref.read(localMarketPricesProvider.notifier).update(local);
    try {
      await ref.read(priceHistoryServiceProvider).recordLocalSnapshot(local);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'recordLocalSnapshot failed');
    }
    try {
      await ref
          .read(firestorePriceHistoryServiceProvider)
          .tryRecordHourlyLocal(local);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'tryRecordHourlyLocal failed');
    }
    // Note: the shared `prices/local_EGP` cache is written server-side by the
    // Cloud Function (refreshPricesScheduled); clients no longer write it.
  }

  Future<void> _refreshLocalIndia() async {
    final firestore = ref.read(firestorePriceServiceProvider);
    final scraper = ref.read(goodreturnsScraperProvider);
    LocalMarketPrices? local;

    local = await firestore.getCachedLocalMarketPrices('INR');
    if (local == null) {
      try {
        local = await scraper.fetchLatestPrices();
      } catch (_) {
        local = await firestore.getStaleLocalMarketPrices('INR') ??
            scraper.getCachedPrices();
        if (local == null) rethrow;
      }
    }

    ref.read(localMarketPricesProvider.notifier).update(local);
    try {
      await ref.read(priceHistoryServiceProvider).recordLocalSnapshot(local);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'recordLocalSnapshot failed');
    }
    try {
      await ref
          .read(firestorePriceHistoryServiceProvider)
          .tryRecordHourlyLocal(local);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'tryRecordHourlyLocal failed');
    }
  }

  Future<void> _refreshGlobal(String currency) async {
    final api = ref.read(metalPriceApiProvider);
    MetalPricesResponse? response;

    try {
      response = await api.fetchFreshPrices();
    } catch (_) {
      response = api.getCachedPrices();
      if (response == null) rethrow;
    }

    state = state.copyWith(globalData: response);
    ref.read(localMarketPricesProvider.notifier).update(null);
    _pushGlobalToMetalProviders(response, currency);
    try {
      await ref.read(priceHistoryServiceProvider).recordGlobalSnapshot(response, currency);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'recordGlobalSnapshot failed');
    }
    try {
      await ref
          .read(firestorePriceHistoryServiceProvider)
          .tryRecordHourlyGlobal(response, currency);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'tryRecordHourlyGlobal failed');
    }
  }

  void applyCurrentPrices() {
    final currency = ref.read(selectedCurrencyProvider);
    if (LocalMarketConfig.isLocalCurrency(currency)) {
      final local = ref.read(localMarketPricesProvider);
      if (local != null) {
        _pushLocalToMetalProviders(local, ref.read(priceSideProvider));
      }
      _updateHomeWidget();
      return;
    }

    final global = state.globalData ?? ref.read(metalPriceApiProvider).getCachedPrices();
    if (global != null) {
      _pushGlobalToMetalProviders(global, currency);
    }
    _updateHomeWidget();
  }

  void _updateHomeWidget() {
    final board = resolveWidgetBoardForUpdate(ref);
    if (board == null || board.isEmpty) return;
    HomeWidgetService.instance.updateBoard(board);
  }

  void _pushGlobalToMetalProviders(MetalPricesResponse response, String currency) {
    final api = ref.read(metalPriceApiProvider);

    final history = ref.read(priceHistoryServiceProvider);
    final goldOunce = response.goldPriceIn(currency);
    if (goldOunce != null) {
      final goldChange = api.change24hFor(
        response: response,
        metal: 'gold',
        currency: currency,
        historyPercent:
            history.globalChange24hPercent(currency: currency, metal: 'gold'),
      );
      ref.read(metalPriceProvider.notifier).updatePrice(MetalPrice(
        metal: 'Gold',
        pricePerOunce: goldOunce,
        pricePerGram: goldOunce / _ounceToGram,
        currency: currency,
        timestamp: response.timestamp,
        change24h: goldChange.change,
        changePercent24h: goldChange.changePercent,
      ));
    }

    final silverOunce = response.silverPriceIn(currency);
    if (silverOunce != null) {
      final silverChange = api.change24hFor(
        response: response,
        metal: 'silver',
        currency: currency,
        historyPercent:
            history.globalChange24hPercent(currency: currency, metal: 'silver'),
      );
      ref.read(silverPriceProvider.notifier).updatePrice(MetalPrice(
        metal: 'Silver',
        pricePerOunce: silverOunce,
        pricePerGram: silverOunce / _ounceToGram,
        currency: currency,
        timestamp: response.timestamp,
        change24h: silverChange.change,
        changePercent24h: silverChange.changePercent,
      ));
    }
  }

  void _pushLocalToMetalProviders(LocalMarketPrices local, PriceSide side) {
    final headline = local.headlineGold;
    if (headline != null) {
      final perGram = headline.priceFor(side);
      ref.read(metalPriceProvider.notifier).updatePrice(MetalPrice(
        metal: 'Gold',
        pricePerOunce: perGram * _ounceToGram,
        pricePerGram: perGram,
        currency: local.currency,
        timestamp: local.updatedAt,
        change24h: headline.change,
        changePercent24h: headline.changePercent,
      ));
    }

    if (LocalMarketConfig.hasLocalSilver(local.currency)) {
      final silver999 = local.silverKarat('999');
      if (silver999 != null) {
        final perGram = silver999.priceFor(side);
        ref.read(silverPriceProvider.notifier).updatePrice(MetalPrice(
          metal: 'Silver',
          pricePerOunce: perGram * _ounceToGram,
          pricePerGram: perGram,
          currency: local.currency,
          timestamp: local.updatedAt,
          change24h: silver999.change,
          changePercent24h: silver999.changePercent,
        ));
      }
    }
  }
}

/// Portfolio uses jeweler buy price (what you receive when selling gold).
double? localGoldPortfolioPrice(LocalMarketPrices local, int karat) {
  return local.goldPriceForKarat(karat, PriceSide.buy);
}

double? localSilverPortfolioPrice(LocalMarketPrices local, int purity) {
  if (purity >= 900) {
    return local.silverPriceForKarat(999, PriceSide.buy) ??
        local.silverPriceForKarat(925, PriceSide.buy);
  }
  return local.silverPriceForKarat(purity, PriceSide.buy);
}

double? activeGoldKaratPrice({
  required bool isLocal,
  required LocalMarketPrices? local,
  required MetalPrice? globalGold,
  required int karat,
  required PriceSide side,
}) {
  if (isLocal && local != null) {
    return local.goldPriceForKarat(karat, side);
  }
  if (globalGold == null) return null;
  return globalGold.getPricePerGram() * (karat / 24);
}

String buildLocalMarketPrompt(LocalMarketPrices local, PriceSide side) {
  final buffer = StringBuffer();
  final unit = local.currency;
  final marketLabel = local.isIndia ? 'India' : 'Egypt';

  if (LocalMarketConfig.hasBuySellSide(local.currency)) {
    buffer.writeln('$marketLabel local market prices (${side.name} prices):');
    for (final row in local.gold) {
      final label = row.karat == 'gold_pound' ? 'Gold Pound' : '${row.karat}K';
      buffer.writeln(
        '- Gold $label: sell ${row.sellPerGram.toStringAsFixed(2)} $unit/g, '
        'buy ${row.buyPerGram.toStringAsFixed(2)} $unit/g, '
        'gap ${row.globalGapSell.toStringAsFixed(2)} $unit',
      );
    }
    for (final row in local.silver) {
      if (row.karat == 'silver_pound') {
        buffer.writeln(
          '- Silver Pound: sell ${row.sellPerGram.toStringAsFixed(2)} $unit, '
          'buy ${row.buyPerGram.toStringAsFixed(2)} $unit',
        );
      } else {
        buffer.writeln(
          '- Silver ${row.karat}: sell ${row.sellPerGram.toStringAsFixed(2)} $unit/g, '
          'buy ${row.buyPerGram.toStringAsFixed(2)} $unit/g',
        );
      }
    }
    if (local.globalGoldOunceUsd != null) {
      buffer.writeln(
        'Global gold ounce reference: \$${local.globalGoldOunceUsd!.toStringAsFixed(2)}',
      );
    }
    for (final fx in local.fxRates) {
      buffer.writeln(
        '- ${fx.code}/$unit: sell ${fx.sell.toStringAsFixed(2)}, buy ${fx.buy.toStringAsFixed(2)}',
      );
    }
  } else {
    buffer.writeln('$marketLabel local market prices (indicative, excl. GST):');
    for (final row in local.gold) {
      buffer.writeln(
        '- Gold ${row.karat}K: ${row.sellPerGram.toStringAsFixed(2)} $unit/g '
        '(${row.changePercent >= 0 ? '+' : ''}${row.changePercent.toStringAsFixed(2)}% today)',
      );
    }
    for (final row in local.silver) {
      buffer.writeln(
        '- Silver ${row.karat}: ${row.sellPerGram.toStringAsFixed(2)} $unit/g '
        '(${row.changePercent >= 0 ? '+' : ''}${row.changePercent.toStringAsFixed(2)}% today)',
      );
    }
  }
  return buffer.toString();
}
