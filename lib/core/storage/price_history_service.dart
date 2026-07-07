import 'package:hive_flutter/hive_flutter.dart';
import '../../shared/local_market/local_market_config.dart';
import '../../shared/models/local_market_prices.dart';
import '../../shared/models/price_snapshot.dart';
import '../api/metalpriceapi_service.dart';

class PriceHistoryService {
  static const boxName = 'priceHistory';
  static const _minInterval = Duration(minutes: 15);
  static const _maxAge = Duration(days: 120);
  static const _ounceToGram = 31.1034768;

  Box? _box;

  Future<Box> _openBox() async {
    if (_box != null && _box!.isOpen) return _box!;
    if (Hive.isBoxOpen(boxName)) {
      _box = Hive.box(boxName);
      return _box!;
    }
    _box = await Hive.openBox(boxName);
    return _box!;
  }

  Future<void> recordLocalSnapshot(LocalMarketPrices local) async {
    final box = await _openBox();
    final ts = local.updatedAt;

    for (final row in local.gold) {
      if (row.isPerUnit) continue;
      await _append(
        box,
        PriceSnapshot(
          timestamp: ts,
          currency: local.currency,
          source: local.source,
          metal: 'gold',
          karat: row.karat,
          sellPerGram: row.sellPerGram,
          buyPerGram: row.buyPerGram,
          globalGap: row.globalGapSell,
        ),
      );
    }

    for (final row in local.silver) {
      if (row.karat == 'silver_ounce' || row.isPerUnit) continue;
      await _append(
        box,
        PriceSnapshot(
          timestamp: ts,
          currency: local.currency,
          source: local.source,
          metal: 'silver',
          karat: row.karat,
          sellPerGram: row.sellPerGram,
          buyPerGram: row.buyPerGram,
          globalGap: row.globalGapSell,
        ),
      );
    }
  }

  Future<void> recordGlobalSnapshot(
    MetalPricesResponse response,
    String displayCurrency,
  ) async {
    final box = await _openBox();
    final ts = response.timestamp;
    final goldOunce = response.goldPriceIn(displayCurrency);
    final silverOunce = response.silverPriceIn(displayCurrency);

    if (goldOunce != null) {
      final perGram24 = goldOunce / _ounceToGram;
      for (final karat in ['24', '22', '21', '18']) {
        final purity = int.parse(karat) / 24;
        await _append(
          box,
          PriceSnapshot(
            timestamp: ts,
            currency: displayCurrency,
            source: 'livepriceofgold',
            metal: 'gold',
            karat: karat,
            sellPerGram: perGram24 * purity,
            spotPerOunce: karat == '24' ? goldOunce : null,
          ),
        );
      }
    }

    if (silverOunce != null) {
      final perGram = silverOunce / _ounceToGram;
      await _append(
        box,
        PriceSnapshot(
          timestamp: ts,
          currency: displayCurrency,
          source: 'livepriceofgold',
          metal: 'silver',
          karat: '999',
          sellPerGram: perGram,
          spotPerOunce: silverOunce,
        ),
      );
    }
  }

  Future<void> _append(Box box, PriceSnapshot snapshot) async {
    final key = snapshot.cacheKey;
    final existing = (box.get(key) ?? <dynamic>[])
        .map((e) => PriceSnapshot.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    if (existing.isNotEmpty) {
      final last = existing.last;
      if (snapshot.timestamp.difference(last.timestamp) < _minInterval) {
        return;
      }
    }

    existing.add(snapshot);
    final cutoff = DateTime.now().subtract(_maxAge);
    final pruned = existing.where((s) => s.timestamp.isAfter(cutoff)).toList();
    await box.put(key, pruned.map((s) => s.toJson()).toList());
  }

  List<ChartDataPoint> getChartPoints({
    required String currency,
    required String metal,
    required String karat,
    required ChartRange range,
    required PriceSide side,
    String? source,
  }) {
    if (!Hive.isBoxOpen(boxName)) return [];

    final box = Hive.box(boxName);
    final key = '$currency|$metal|$karat|${source ?? _defaultSource(currency)}';
    final raw = box.get(key);
    if (raw == null) return [];

    final snapshots = raw
        .map((e) => PriceSnapshot.fromJson(Map<String, dynamic>.from(e)))
        .where((s) =>
            s.timestamp.isAfter(DateTime.now().subtract(Duration(days: range.days))))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final daily = _aggregateDaily(snapshots, side);
    if (daily.length >= 2) return daily;
    if (snapshots.length >= 2) return _toIntradayPoints(snapshots, side);
    return daily;
  }

  int countPoints({
    required String currency,
    required String metal,
    required String karat,
    required ChartRange range,
    String? source,
  }) {
    return getChartPoints(
      currency: currency,
      metal: metal,
      karat: karat,
      range: range,
      side: PriceSide.sell,
      source: source,
    ).length;
  }

  String _defaultSource(String currency) =>
      LocalMarketConfig.historySource(currency);

  /// 24h change % for the global market computed from recorded snapshots.
  /// Per-gram and karat-invariant, so '24'/'999' is fine. Returns null if there
  /// is no snapshot ~24h old to compare against.
  double? globalChange24hPercent({
    required String currency,
    required String metal,
  }) {
    if (!Hive.isBoxOpen(boxName)) return null;
    final box = Hive.box(boxName);
    final key = '$currency|$metal|${metal == 'gold' ? '24' : '999'}|livepriceofgold';
    final raw = box.get(key);
    if (raw == null) return null;

    final snaps = (raw as List)
        .map((e) => PriceSnapshot.fromJson(Map<String, dynamic>.from(e)))
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    if (snaps.length < 2) return null;

    final current = snaps.last;
    final target = current.timestamp.subtract(const Duration(hours: 24));

    // Pick the snapshot closest to 24h before the latest, but only count one
    // that is between ~12h and ~48h old so it's a meaningful "previous day".
    PriceSnapshot? prev;
    Duration? best;
    for (final s in snaps) {
      if (identical(s, current)) continue;
      final age = current.timestamp.difference(s.timestamp);
      if (age < const Duration(hours: 12) || age > const Duration(hours: 48)) {
        continue;
      }
      final diff = (s.timestamp.difference(target)).abs();
      if (best == null || diff < best) {
        best = diff;
        prev = s;
      }
    }
    if (prev == null) return null;

    final curVal = current.sellPerGram;
    final prevVal = prev.sellPerGram;
    if (curVal == null || prevVal == null || prevVal == 0) return null;
    return (curVal - prevVal) / prevVal * 100;
  }

  List<ChartDataPoint> _aggregateDaily(
    List<PriceSnapshot> snapshots,
    PriceSide side,
  ) {
    if (snapshots.isEmpty) return [];

    final byDay = <String, PriceSnapshot>{};
    for (final s in snapshots) {
      final dayKey = '${s.timestamp.year}-${s.timestamp.month}-${s.timestamp.day}';
      byDay[dayKey] = s;
    }

    final days = byDay.keys.toList()..sort();
    return days.map((dayKey) {
      final s = byDay[dayKey]!;
      final parts = dayKey.split('-');
      return ChartDataPoint(
        date: DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
        value: s.valueFor(side),
      );
    }).toList();
  }

  List<ChartDataPoint> _toIntradayPoints(
    List<PriceSnapshot> snapshots,
    PriceSide side,
  ) {
    return snapshots
        .map((s) => ChartDataPoint(
              date: s.timestamp,
              value: s.valueFor(side),
            ))
        .toList();
  }

  List<ChartDataPoint> seedFromCachedPrices({
    required MetalPriceApiService api,
    required String currency,
    required String metal,
    required String karat,
  }) {
    final current = api.getCachedPrices();
    if (current == null) return [];

    final points = <ChartDataPoint>[];

    double? valueFrom(MetalPricesResponse response) {
      final ounce = metal == 'gold'
          ? response.goldPriceIn(currency)
          : response.silverPriceIn(currency);
      if (ounce == null) return null;
      if (metal == 'gold') {
        final purity = (int.tryParse(karat) ?? 24) / 24;
        return (ounce / _ounceToGram) * purity;
      }
      return ounce / _ounceToGram;
    }

    double? previousValueFromServerBaseline() {
      final ounce = metal == 'gold'
          ? current.goldPreviousIn(currency)
          : current.silverPreviousIn(currency);
      if (ounce == null) return null;
      if (metal == 'gold') {
        final purity = (int.tryParse(karat) ?? 24) / 24;
        return (ounce / _ounceToGram) * purity;
      }
      return ounce / _ounceToGram;
    }

    final serverPrev = previousValueFromServerBaseline();
    if (serverPrev != null) {
      points.add(ChartDataPoint(
        date: current.timestamp.subtract(const Duration(hours: 24)),
        value: serverPrev,
      ));
    } else {
      final previous = api.getPreviousPrices();
      if (previous != null) {
        final prevValue = valueFrom(previous);
        if (prevValue != null) {
          points.add(ChartDataPoint(date: previous.timestamp, value: prevValue));
        }
      }
    }

    final currentValue = valueFrom(current);
    if (currentValue != null) {
      points.add(ChartDataPoint(date: current.timestamp, value: currentValue));
    }

    return points;
  }

  List<ChartDataPoint> seedFromLocalPrices(
    LocalMarketPrices local, {
    required String metal,
    required String karat,
    required PriceSide side,
  }) {
    final row = metal == 'gold'
        ? local.goldKarat(karat)
        : local.silverKarat(karat);
    if (row == null) return [];

    final current = row.priceFor(side);
    final previous = current - row.change;
    if (row.change.abs() < 0.001 || (previous - current).abs() < 0.001) {
      return [];
    }
    final now = local.updatedAt;

    return [
      ChartDataPoint(
        date: now.subtract(const Duration(hours: 24)),
        value: previous,
      ),
      ChartDataPoint(date: now, value: current),
    ];
  }

  List<ChartDataPoint> parseApiFallback({
    required Map<String, dynamic> apiData,
    required String currency,
    required String metal,
    required String karat,
  }) {
    final rates = apiData['rates'] as Map<String, dynamic>?;
    if (rates == null) return [];

    final points = <ChartDataPoint>[];
    final sortedDates = rates.keys.toList()..sort();

    for (final dateStr in sortedDates) {
      final dayRates = rates[dateStr] as Map<String, dynamic>?;
      if (dayRates == null) continue;

      final metalKey = metal == 'gold' ? 'XAU' : 'XAG';
      final usdKey = metal == 'gold' ? 'USDXAU' : 'USDXAG';

      // The /timeframe response (base=USD) gives the metal price in USD and FX
      // rates as units-per-USD. The metal price in the target currency is always
      // ounceUsd * fx(currency) — never the raw FX rate. (A previous version read
      // dayRates[currency] as if it were the price, which produced garbage for
      // higher-magnitude rates like INR/JPY/PKR.)
      double? ounceUsd = (dayRates[usdKey] as num?)?.toDouble();
      if (ounceUsd == null) {
        final metalRate = (dayRates[metalKey] as num?)?.toDouble();
        if (metalRate != null) {
          ounceUsd = metalRate < 0.01 ? 1 / metalRate : metalRate;
        }
      }
      if (ounceUsd == null) continue;

      double ounceInCurrency;
      if (currency == 'USD') {
        ounceInCurrency = ounceUsd;
      } else {
        final fx = (dayRates[currency] as num?)?.toDouble();
        if (fx == null) continue;
        ounceInCurrency = ounceUsd * fx;
      }

      double value;
      if (metal == 'gold') {
        final purity = (int.tryParse(karat) ?? 24) / 24;
        value = (ounceInCurrency / _ounceToGram) * purity;
      } else {
        value = ounceInCurrency / _ounceToGram;
      }

      points.add(ChartDataPoint(
        date: DateTime.parse(dateStr),
        value: value,
      ));
    }

    return points;
  }
}
