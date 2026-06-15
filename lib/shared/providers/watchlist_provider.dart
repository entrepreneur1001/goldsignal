import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/local_market_prices.dart';
import '../models/watchlist_entry.dart';
import 'currency_provider.dart';
import 'market_prices_provider.dart';
import 'metal_price_provider.dart';

const _prefsKey = 'price_watchlist';
const _maxItems = 8;
const _ounceToGram = 31.1034768;

enum WatchlistToggleResult { added, removed, full }

final watchlistProvider =
    NotifierProvider<WatchlistNotifier, List<WatchlistEntry>>(() {
  return WatchlistNotifier();
});

class WatchlistNotifier extends Notifier<List<WatchlistEntry>> {
  @override
  List<WatchlistEntry> build() {
    Future.microtask(_load);
    return const [];
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => WatchlistEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      state = list;
    } catch (_) {}
  }

  bool contains(WatchlistEntry entry) =>
      state.any((e) => e.id == entry.id);

  Future<WatchlistToggleResult> toggle(WatchlistEntry entry) async {
    if (contains(entry)) {
      state = state.where((e) => e.id != entry.id).toList();
      await _persist();
      return WatchlistToggleResult.removed;
    }
    if (state.length >= _maxItems) return WatchlistToggleResult.full;
    state = [...state, entry];
    await _persist();
    return WatchlistToggleResult.added;
  }

  Future<void> remove(WatchlistEntry entry) async {
    state = state.where((e) => e.id != entry.id).toList();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded =
        jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_prefsKey, encoded);
  }
}

/// Resolves live prices for every pinned watchlist entry.
final watchlistQuotesProvider = Provider<List<WatchlistQuote>>((ref) {
  final entries = ref.watch(watchlistProvider);
  if (entries.isEmpty) return const [];

  final currency = ref.watch(selectedCurrencyProvider);
  final isLocal = currency == 'EGP';
  final side = ref.watch(priceSideProvider);
  final quotes = <WatchlistQuote>[];

  for (final entry in entries) {
    final quote = _resolveEntry(ref, entry, currency, isLocal, side);
    if (quote != null) quotes.add(quote);
  }
  return quotes;
});

WatchlistQuote? _resolveEntry(
  Ref ref,
  WatchlistEntry entry,
  String currency,
  bool isLocal,
  PriceSide side,
) {
  if (isLocal) {
    final local = ref.watch(localMarketPricesProvider);
    if (local == null) return null;

    final row = entry.metal == 'gold'
        ? local.goldKarat(entry.karat)
        : local.silverKarat(entry.karat);
    if (row == null || row.isPerUnit) return null;

    return WatchlistQuote(
      entry: entry,
      pricePerGram: row.priceFor(side),
      changePercent: row.changePercent,
      currency: currency,
    );
  }

  ref.watch(metalPriceProvider);
  ref.watch(silverPriceProvider);
  final global = ref.read(metalPriceApiProvider).getCachedPrices();
  if (global == null) return null;

  final api = ref.read(metalPriceApiProvider);
  final ounce = entry.metal == 'gold'
      ? global.goldPriceIn(currency)
      : global.silverPriceIn(currency);
  if (ounce == null) return null;

  double perGram;
  if (entry.metal == 'gold') {
    final purity = (int.tryParse(entry.karat) ?? 24) / 24;
    perGram = (ounce / _ounceToGram) * purity;
  } else {
    perGram = ounce / _ounceToGram;
  }

  final delta = api.change24hFor(
    response: global,
    metal: entry.metal,
    currency: currency,
    historyPercent: ref
        .read(priceHistoryServiceProvider)
        .globalChange24hPercent(currency: currency, metal: entry.metal),
  );

  return WatchlistQuote(
    entry: entry,
    pricePerGram: perGram,
    changePercent: delta.changePercent,
    currency: currency,
  );
}

/// Build a [WatchlistEntry] from a local karat row id.
WatchlistEntry entryForLocalRow(String karat, {required bool isGold}) {
  return WatchlistEntry(
    metal: isGold ? 'gold' : 'silver',
    karat: karat,
  );
}
