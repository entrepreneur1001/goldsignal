import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'currency_provider.dart';
import 'market_prices_provider.dart';
import 'metal_price_provider.dart';

const _ounceToGram = 31.1034768;
const _metalKey = 'widget_metal';
const _karatKey = 'widget_karat';

class WidgetPreferences {
  final String metal;
  final String karat;

  const WidgetPreferences({
    required this.metal,
    required this.karat,
  });

  WidgetPreferences copyWith({String? metal, String? karat}) {
    return WidgetPreferences(
      metal: metal ?? this.metal,
      karat: karat ?? this.karat,
    );
  }
}

class WidgetDisplayData {
  final double pricePerGram;
  final double changePercent;
  final String label;
  final String currency;

  const WidgetDisplayData({
    required this.pricePerGram,
    required this.changePercent,
    required this.label,
    required this.currency,
  });

  bool get isPositive => changePercent >= 0;

  String get formattedChangePercent {
    final sign = isPositive ? '+' : '';
    return '$sign${changePercent.toStringAsFixed(2)}%';
  }
}

List<String> karatOptionsFor({
  required String metal,
  required String currency,
}) {
  if (metal == 'gold') {
    return ['24', '22', '21', '18'];
  }
  return currency == 'EGP' ? ['999', '925', '900', '800'] : ['999'];
}

String defaultKaratFor({
  required String metal,
  required String currency,
}) {
  if (metal == 'silver') {
    return '999';
  }
  return currency == 'EGP' ? '21' : '24';
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
    return WidgetPreferences(
      metal: 'gold',
      karat: defaultKaratFor(
        metal: 'gold',
        currency: ref.read(selectedCurrencyProvider),
      ),
    );
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final currency = ref.read(selectedCurrencyProvider);
    final metal = prefs.getString(_metalKey) ?? 'gold';
    final savedKarat = prefs.getString(_karatKey);
    final karat = savedKarat != null &&
            karatOptionsFor(metal: metal, currency: currency).contains(savedKarat)
        ? savedKarat
        : defaultKaratFor(metal: metal, currency: currency);
    state = WidgetPreferences(metal: metal, karat: karat);
    ref.read(marketPricesControllerProvider.notifier).applyCurrentPrices();
  }

  Future<void> setMetal(String metal) async {
    final currency = ref.read(selectedCurrencyProvider);
    final options = karatOptionsFor(metal: metal, currency: currency);
    final karat = options.contains(state.karat)
        ? state.karat
        : defaultKaratFor(metal: metal, currency: currency);
    state = WidgetPreferences(metal: metal, karat: karat);
    await _persist();
  }

  Future<void> setKarat(String karat) async {
    final currency = ref.read(selectedCurrencyProvider);
    final options =
        karatOptionsFor(metal: state.metal, currency: currency);
    if (!options.contains(karat)) return;
    state = state.copyWith(karat: karat);
    await _persist();
  }

  Future<void> normalizeForCurrency(String currency) async {
    final options =
        karatOptionsFor(metal: state.metal, currency: currency);
    if (options.contains(state.karat)) return;
    state = state.copyWith(
      karat: defaultKaratFor(metal: state.metal, currency: currency),
    );
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_metalKey, state.metal);
    await prefs.setString(_karatKey, state.karat);
  }
}

final widgetDisplayProvider = Provider<WidgetDisplayData?>((ref) {
  return _resolveWidgetDisplay(ref);
});

WidgetDisplayData? _resolveWidgetDisplay(Ref ref) {
  final prefs = ref.read(widgetPreferencesProvider);
  final currency = ref.read(selectedCurrencyProvider);
  final isLocal = currency == 'EGP';
  final side = ref.read(priceSideProvider);

  if (isLocal) {
    final local = ref.read(localMarketPricesProvider);
    if (local == null) return null;

    final row = prefs.metal == 'gold'
        ? local.goldKarat(prefs.karat)
        : local.silverKarat(prefs.karat);
    if (row == null) return null;

    return WidgetDisplayData(
      pricePerGram: row.priceFor(side),
      changePercent: row.changePercent,
      label: widgetLabelFor(metal: prefs.metal, karat: prefs.karat),
      currency: currency,
    );
  }

  // Use the Hive-cached prices (written by the controller on every refresh
  // before this runs). Reading marketPricesControllerProvider here would be a
  // self-dependency, since this is invoked with the controller's own `ref`.
  final global = ref.read(metalPriceApiProvider).getCachedPrices();
  if (global == null) return null;

  final api = ref.read(metalPriceApiProvider);
  final ounce = prefs.metal == 'gold'
      ? global.goldPriceIn(currency)
      : global.silverPriceIn(currency);
  if (ounce == null) return null;

  double perGram;
  if (prefs.metal == 'gold') {
    final purity = (int.tryParse(prefs.karat) ?? 24) / 24;
    perGram = (ounce / _ounceToGram) * purity;
  } else {
    perGram = ounce / _ounceToGram;
  }

  final delta = api.computeChange(
    current: ounce,
    previousPrice: (prev) => prefs.metal == 'gold'
        ? prev.goldPriceIn(currency)
        : prev.silverPriceIn(currency),
  );

  return WidgetDisplayData(
    pricePerGram: perGram,
    changePercent: delta.changePercent,
    label: widgetLabelFor(metal: prefs.metal, karat: prefs.karat),
    currency: currency,
  );
}

WidgetDisplayData? resolveWidgetDisplayForUpdate(Ref ref) =>
    _resolveWidgetDisplay(ref);
