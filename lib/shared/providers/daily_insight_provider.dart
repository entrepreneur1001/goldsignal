import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'currency_provider.dart';
import 'market_prices_provider.dart';
import 'metal_price_provider.dart';

const _insightDateKey = 'daily_insight_ymd';
const _insightTextKey = 'daily_insight_text';

class DailyInsight {
  final String text;
  final bool isLoading;
  final bool expanded;

  const DailyInsight({
    this.text = '',
    this.isLoading = false,
    this.expanded = true,
  });

  DailyInsight copyWith({String? text, bool? isLoading, bool? expanded}) {
    return DailyInsight(
      text: text ?? this.text,
      isLoading: isLoading ?? this.isLoading,
      expanded: expanded ?? this.expanded,
    );
  }
}

final dailyInsightProvider =
    NotifierProvider<DailyInsightNotifier, DailyInsight>(() {
  return DailyInsightNotifier();
});

class DailyInsightNotifier extends Notifier<DailyInsight> {
  @override
  DailyInsight build() {
    Future.microtask(loadIfNeeded);
    return const DailyInsight(isLoading: true);
  }

  String _todayYmd() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> loadIfNeeded() async {
    final ymd = _todayYmd();
    final prefs = await SharedPreferences.getInstance();
    final cachedYmd = prefs.getString(_insightDateKey);
    final cachedText = prefs.getString(_insightTextKey);
    if (cachedYmd == ymd && cachedText != null && cachedText.isNotEmpty) {
      state = DailyInsight(text: cachedText);
      return;
    }

    state = state.copyWith(isLoading: true);

    // Prefer server-cached insight (written by Cloud Functions).
    try {
      final doc = await FirebaseFirestore.instance
          .collection('metadata')
          .doc('dailyInsight')
          .get();
      final data = doc.data();
      if (data != null &&
          data['ymd'] == ymd &&
          (data['text'] as String?)?.isNotEmpty == true) {
        final text = data['text'] as String;
        await _cache(text, ymd);
        state = DailyInsight(text: text);
        return;
      }
    } catch (_) {
      // Fall through to local generation.
    }

    final text = _buildLocalInsight();
    if (text.isNotEmpty) {
      await _cache(text, ymd);
    }
    state = DailyInsight(text: text, isLoading: false);
  }

  String _buildLocalInsight() {
    final currency = ref.read(selectedCurrencyProvider);
    final isLocal = currency == 'EGP';
    final global = ref.read(marketPricesControllerProvider).globalData;

    double? goldPct;
    double? silverPct;
    double? goldPerGram;

    if (isLocal) {
      final local = ref.read(localMarketPricesProvider);
      final row = local?.goldKarat('21');
      if (row != null) {
        goldPct = row.changePercent;
        goldPerGram = row.sellPerGram;
      }
      final silverRow = local?.silverKarat('999');
      silverPct = silverRow?.changePercent;
    } else if (global != null) {
      final api = ref.read(metalPriceApiProvider);
      final g = api.change24hFor(
        response: global,
        metal: 'gold',
        currency: currency,
      );
      final s = api.change24hFor(
        response: global,
        metal: 'silver',
        currency: currency,
      );
      goldPct = g.changePercent;
      silverPct = s.changePercent;
      final ounce = global.goldPriceIn(currency);
      if (ounce != null) goldPerGram = ounce / 31.1034768;
    }

    if (goldPct == null && silverPct == null) return '';

    String dir(double? p) {
      if (p == null) return 'flat';
      if (p > 0.05) return 'up';
      if (p < -0.05) return 'down';
      return 'flat';
    }

    final gDir = dir(goldPct);
    final sDir = dir(silverPct);
    final gStr = goldPct != null ? '${goldPct >= 0 ? '+' : ''}${goldPct.toStringAsFixed(1)}%' : '';
    final sStr = silverPct != null ? '${silverPct >= 0 ? '+' : ''}${silverPct.toStringAsFixed(1)}%' : '';
    final priceBit = goldPerGram != null
        ? ' at ${goldPerGram.toStringAsFixed(0)} $currency/g'
        : '';

    return 'Gold is $gDir $gStr$priceBit · Silver $sDir $sStr (24h).';
  }

  Future<void> _cache(String text, String ymd) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_insightDateKey, ymd);
    await prefs.setString(_insightTextKey, text);
  }

  void toggleExpanded() {
    state = state.copyWith(expanded: !state.expanded);
  }
}
