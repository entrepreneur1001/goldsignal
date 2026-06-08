import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/local_market_prices.dart';
import '../models/price_snapshot.dart';
import 'currency_provider.dart';
import 'market_prices_provider.dart';
import 'metal_price_provider.dart';

class ChartQuery {
  final String currency;
  final String metal;
  final String karat;
  final ChartRange range;
  final PriceSide side;

  const ChartQuery({
    required this.currency,
    required this.metal,
    required this.karat,
    required this.range,
    required this.side,
  });
}

class ChartState {
  final List<ChartDataPoint> points;
  final ChartDataSource source;
  final bool isLoading;
  final String? error;

  const ChartState({
    this.points = const [],
    this.source = ChartDataSource.snapshots,
    this.isLoading = false,
    this.error,
  });

  ChartState copyWith({
    List<ChartDataPoint>? points,
    ChartDataSource? source,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChartState(
      points: points ?? this.points,
      source: source ?? this.source,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final chartQueryProvider = NotifierProvider<ChartQueryNotifier, ChartQuery>(() {
  return ChartQueryNotifier();
});

class ChartQueryNotifier extends Notifier<ChartQuery> {
  @override
  ChartQuery build() {
    final currency = ref.watch(selectedCurrencyProvider);
    final isLocal = currency == 'EGP';
    return ChartQuery(
      currency: currency,
      metal: 'gold',
      karat: isLocal ? '21' : '24',
      range: ChartRange.days7,
      side: ref.watch(priceSideProvider),
    );
  }

  void setMetal(String metal) => state = ChartQuery(
        currency: state.currency,
        metal: metal,
        karat: state.karat,
        range: state.range,
        side: state.side,
      );

  void setKarat(String karat) => state = ChartQuery(
        currency: state.currency,
        metal: state.metal,
        karat: karat,
        range: state.range,
        side: state.side,
      );

  void setRange(ChartRange range) => state = ChartQuery(
        currency: state.currency,
        metal: state.metal,
        karat: state.karat,
        range: range,
        side: state.side,
      );

  void setSide(PriceSide side) => state = ChartQuery(
        currency: state.currency,
        metal: state.metal,
        karat: state.karat,
        range: state.range,
        side: side,
      );

  void syncCurrency(String currency) {
    state = ChartQuery(
      currency: currency,
      metal: state.metal,
      karat: currency == 'EGP' ? '21' : '24',
      range: state.range,
      side: state.side,
    );
  }
}

final chartDataProvider =
    NotifierProvider<ChartDataNotifier, ChartState>(() => ChartDataNotifier());

class ChartDataNotifier extends Notifier<ChartState> {
  @override
  ChartState build() {
    ref.listen<ChartQuery>(chartQueryProvider, (prev, next) {
      if (prev != next) load();
    });
    ref.listen<String>(selectedCurrencyProvider, (prev, next) {
      if (prev != next) {
        ref.read(chartQueryProvider.notifier).syncCurrency(next);
      }
    });
    Future.microtask(load);
    return const ChartState(isLoading: true);
  }

  Future<void> load() async {
    final query = ref.read(chartQueryProvider);
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final history = ref.read(priceHistoryServiceProvider);
      final hivePoints = history.getChartPoints(
        currency: query.currency,
        metal: query.metal,
        karat: query.karat,
        range: query.range,
        side: query.side,
      );

      final firestoreService = ref.read(firestorePriceHistoryServiceProvider);
      final firestorePoints = await firestoreService.getChartPoints(
        currency: query.currency,
        metal: query.metal,
        karat: query.karat,
        range: query.range,
        side: query.side,
      );

      var points = _mergeChartPoints(hivePoints, firestorePoints);
      final usedCommunity = firestorePoints.isNotEmpty &&
          (hivePoints.length < 2 || firestorePoints.length >= hivePoints.length);

      if (points.length < 2) {
        if (query.currency == 'EGP') {
          final local = ref.read(localMarketPricesProvider);
          if (local != null) {
            points = history.seedFromLocalPrices(
              local,
              metal: query.metal,
              karat: query.karat,
              side: query.side,
            );
          }
        } else {
          points = history.seedFromCachedPrices(
            api: ref.read(metalPriceApiProvider),
            currency: query.currency,
            metal: query.metal,
            karat: query.karat,
          );
        }
      }

      if (points.length >= 2) {
        state = ChartState(
          points: points,
          source: usedCommunity && hivePoints.length < 2
              ? ChartDataSource.community
              : ChartDataSource.snapshots,
          isLoading: false,
        );
        return;
      }

      final api = ref.read(metalPriceApiProvider);
      final end = DateTime.now();
      final start = end.subtract(Duration(days: query.range.days));
      final metalCode = query.metal == 'gold' ? 'XAU' : 'XAG';

      final apiData = await api.getHistoricalPrices(
        metal: metalCode,
        currency: query.currency,
        startDate: start,
        endDate: end,
      );

      final fallbackPoints = history.parseApiFallback(
        apiData: apiData,
        currency: query.currency,
        metal: query.metal,
        karat: query.karat,
      );

      state = ChartState(
        points: fallbackPoints.isNotEmpty ? fallbackPoints : points,
        source: fallbackPoints.isNotEmpty
            ? ChartDataSource.apiFallback
            : ChartDataSource.snapshots,
        isLoading: false,
        error: fallbackPoints.isEmpty && points.isEmpty
            ? 'Not enough history yet. Pull to refresh prices and try again.'
            : null,
      );
    } catch (e) {
      final history = ref.read(priceHistoryServiceProvider);
      final query = ref.read(chartQueryProvider);
      var partial = history.getChartPoints(
        currency: query.currency,
        metal: query.metal,
        karat: query.karat,
        range: query.range,
        side: query.side,
      );
      final firestorePartial = await ref
          .read(firestorePriceHistoryServiceProvider)
          .getChartPoints(
            currency: query.currency,
            metal: query.metal,
            karat: query.karat,
            range: query.range,
            side: query.side,
          );
      partial = _mergeChartPoints(partial, firestorePartial);
      if (partial.length < 2 && query.currency != 'EGP') {
        partial = history.seedFromCachedPrices(
          api: ref.read(metalPriceApiProvider),
          currency: query.currency,
          metal: query.metal,
          karat: query.karat,
        );
      }
      state = ChartState(
        points: partial,
        source: firestorePartial.isNotEmpty && partial.length >= 2
            ? ChartDataSource.community
            : ChartDataSource.snapshots,
        isLoading: false,
        error: partial.length < 2 ? e.toString() : null,
      );
    }
  }

  List<ChartDataPoint> _mergeChartPoints(
    List<ChartDataPoint> hive,
    List<ChartDataPoint> firestore,
  ) {
    final byHour = <String, ChartDataPoint>{};

    String hourKey(DateTime d) =>
        '${d.toUtc().year}-${d.toUtc().month}-${d.toUtc().day}-${d.toUtc().hour}';

    for (final p in firestore) {
      byHour[hourKey(p.date)] = p;
    }
    for (final p in hive) {
      byHour[hourKey(p.date)] = p;
    }

    final merged = byHour.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return merged;
  }
}
