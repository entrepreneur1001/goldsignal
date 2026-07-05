import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../local_market/local_market_config.dart';
import 'currency_provider.dart';
import 'market_prices_provider.dart';
import 'metal_price_provider.dart';

const _ounceToGram = 31.1034768;
const _goldKaratKey = 'widget_gold_karat';
const _silverKaratKey = 'widget_silver_karat';
// Legacy single-metal keys, read once for backward compatibility.
const _legacyMetalKey = 'widget_metal';
const _legacyKaratKey = 'widget_karat';

/// User-selected karats for the two-row home widget (Gold + Silver).
class WidgetPreferences {
  final String goldKarat;
  final String silverKarat;

  const WidgetPreferences({
    required this.goldKarat,
    required this.silverKarat,
  });

  WidgetPreferences copyWith({String? goldKarat, String? silverKarat}) {
    return WidgetPreferences(
      goldKarat: goldKarat ?? this.goldKarat,
      silverKarat: silverKarat ?? this.silverKarat,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is WidgetPreferences &&
      other.goldKarat == goldKarat &&
      other.silverKarat == silverKarat;

  @override
  int get hashCode => Object.hash(goldKarat, silverKarat);
}

/// A single metal row in the widget board (price + 24h change, per gram).
class WidgetMetalRow {
  final String metal; // 'gold' | 'silver'
  final String label;
  final double pricePerGram;
  final double changeValue;
  final double changePercent;

  const WidgetMetalRow({
    required this.metal,
    required this.label,
    required this.pricePerGram,
    required this.changeValue,
    required this.changePercent,
  });

  bool get isPositive => changePercent >= 0;

  String get formattedPrice => _formatNumber(pricePerGram, decimals: 2);

  String get formattedChange {
    final sign = changeValue > 0 ? '+' : '';
    return '$sign${_formatNumber(changeValue, decimals: 2)}';
  }

  String get formattedChangePercent {
    final sign = isPositive ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }
}

/// The full data set pushed to the native widget: header + both metal rows.
class WidgetBoardData {
  final String currency;
  final DateTime updatedAt;
  final WidgetMetalRow? gold;
  final WidgetMetalRow? silver;

  const WidgetBoardData({
    required this.currency,
    required this.updatedAt,
    required this.gold,
    required this.silver,
  });

  bool get isEmpty => gold == null && silver == null;
}

String _formatNumber(double value, {int decimals = 2}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final intPart = parts[0];
  final negative = intPart.startsWith('-');
  final digits = negative ? intPart.substring(1) : intPart;
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  final grouped = '${negative ? '-' : ''}$buffer';
  return decimals > 0 ? '$grouped.${parts[1]}' : grouped;
}

List<String> karatOptionsFor({
  required String metal,
  required String currency,
}) {
  if (metal == 'gold') {
    return LocalMarketConfig.goldKarats(currency);
  }
  return LocalMarketConfig.silverKarats(currency);
}

String defaultKaratFor({
  required String metal,
  required String currency,
}) {
  if (metal == 'silver') {
    return LocalMarketConfig.defaultSilverKarat(currency);
  }
  return LocalMarketConfig.defaultGoldKaratStr(currency);
}

String widgetLabelFor({
  required String metal,
  required String karat,
}) {
  final metalLabel = metal == 'gold' ? 'Gold' : 'Silver';
  final karatLabel = metal == 'gold' ? '${karat}K' : karat;
  return '$karatLabel $metalLabel';
}

final widgetPreferencesProvider =
    NotifierProvider<WidgetPreferencesNotifier, WidgetPreferences>(() {
  return WidgetPreferencesNotifier();
});

class WidgetPreferencesNotifier extends Notifier<WidgetPreferences> {
  @override
  WidgetPreferences build() {
    Future.microtask(_loadSaved);
    final currency = ref.read(selectedCurrencyProvider);
    return WidgetPreferences(
      goldKarat: defaultKaratFor(metal: 'gold', currency: currency),
      silverKarat: defaultKaratFor(metal: 'silver', currency: currency),
    );
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = ref.read(selectedCurrencyProvider);

    final goldOptions = karatOptionsFor(metal: 'gold', currency: currency);
    final silverOptions = karatOptionsFor(metal: 'silver', currency: currency);

    // Backward-compat: migrate the old single-metal karat onto its metal.
    final legacyMetal = prefs.getString(_legacyMetalKey);
    final legacyKarat = prefs.getString(_legacyKaratKey);

    String resolve(List<String> options, String key, String metal) {
      final saved = prefs.getString(key);
      if (saved != null && options.contains(saved)) return saved;
      if (legacyMetal == metal &&
          legacyKarat != null &&
          options.contains(legacyKarat)) {
        return legacyKarat;
      }
      return defaultKaratFor(metal: metal, currency: currency);
    }

    state = WidgetPreferences(
      goldKarat: resolve(goldOptions, _goldKaratKey, 'gold'),
      silverKarat: resolve(silverOptions, _silverKaratKey, 'silver'),
    );
    ref.read(marketPricesControllerProvider.notifier).applyCurrentPrices();
  }

  Future<void> setGoldKarat(String karat) async {
    final currency = ref.read(selectedCurrencyProvider);
    if (!karatOptionsFor(metal: 'gold', currency: currency).contains(karat)) {
      return;
    }
    state = state.copyWith(goldKarat: karat);
    await _persist();
  }

  Future<void> setSilverKarat(String karat) async {
    final currency = ref.read(selectedCurrencyProvider);
    if (!karatOptionsFor(metal: 'silver', currency: currency).contains(karat)) {
      return;
    }
    state = state.copyWith(silverKarat: karat);
    await _persist();
  }

  Future<void> normalizeForCurrency(String currency) async {
    final goldOptions = karatOptionsFor(metal: 'gold', currency: currency);
    final silverOptions = karatOptionsFor(metal: 'silver', currency: currency);
    final goldKarat = goldOptions.contains(state.goldKarat)
        ? state.goldKarat
        : defaultKaratFor(metal: 'gold', currency: currency);
    final silverKarat = silverOptions.contains(state.silverKarat)
        ? state.silverKarat
        : defaultKaratFor(metal: 'silver', currency: currency);
    if (goldKarat == state.goldKarat && silverKarat == state.silverKarat) {
      return;
    }
    state = WidgetPreferences(goldKarat: goldKarat, silverKarat: silverKarat);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_goldKaratKey, state.goldKarat);
    await prefs.setString(_silverKaratKey, state.silverKarat);
  }
}

/// The board model for the live settings preview.
final widgetBoardProvider = Provider<WidgetBoardData?>((ref) {
  return _resolveWidgetBoard(ref);
});

WidgetBoardData? _resolveWidgetBoard(Ref ref) {
  final prefs = ref.read(widgetPreferencesProvider);
  final currency = ref.read(selectedCurrencyProvider);
  final isLocal = LocalMarketConfig.isLocalCurrency(currency);
  final side = ref.read(priceSideProvider);

  if (isLocal) {
    final local = ref.read(localMarketPricesProvider);
    if (local == null) return null;

    WidgetMetalRow? rowFor(String metal, String karat) {
      final row = metal == 'gold'
          ? local.goldKarat(karat)
          : local.silverKarat(karat);
      if (row == null) return null;
      return WidgetMetalRow(
        metal: metal,
        label: widgetLabelFor(metal: metal, karat: karat),
        pricePerGram: row.priceFor(side),
        changeValue: row.change,
        changePercent: row.changePercent,
      );
    }

    return WidgetBoardData(
      currency: currency,
      updatedAt: local.updatedAt,
      gold: rowFor('gold', prefs.goldKarat),
      silver: rowFor('silver', prefs.silverKarat),
    );
  }

  // Global market: per-ounce prices from the cached response (written by the
  // controller before this runs). Reading marketPricesControllerProvider here
  // would be a self-dependency, since this is invoked with the controller's ref.
  final api = ref.read(metalPriceApiProvider);
  final global = api.getCachedPrices();
  if (global == null) return null;

  WidgetMetalRow? rowFor(String metal, String karat) {
    final ounce = metal == 'gold'
        ? global.goldPriceIn(currency)
        : global.silverPriceIn(currency);
    if (ounce == null) return null;

    final purity = metal == 'gold' ? (int.tryParse(karat) ?? 24) / 24 : 1.0;
    final perGram = (ounce / _ounceToGram) * purity;

    final delta = api.change24hFor(
      response: global,
      metal: metal,
      currency: currency,
      historyPercent: ref
          .read(priceHistoryServiceProvider)
          .globalChange24hPercent(currency: currency, metal: metal),
    );

    return WidgetMetalRow(
      metal: metal,
      label: widgetLabelFor(metal: metal, karat: karat),
      pricePerGram: perGram,
      changeValue: (delta.change / _ounceToGram) * purity,
      changePercent: delta.changePercent,
    );
  }

  return WidgetBoardData(
    currency: currency,
    updatedAt: global.timestamp,
    gold: rowFor('gold', prefs.goldKarat),
    silver: rowFor('silver', prefs.silverKarat),
  );
}

WidgetBoardData? resolveWidgetBoardForUpdate(Ref ref) =>
    _resolveWidgetBoard(ref);
