import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/analytics/analytics_service.dart';
import 'currency_provider.dart';
import 'watchlist_provider.dart';

const _enabledKey = 'watchlist_alerts_enabled';
const _thresholdKey = 'watchlist_alerts_threshold';
const defaultWatchlistMoveThreshold = 2.0;

class WatchlistAlertsPrefs {
  final bool enabled;
  final double thresholdPercent;

  const WatchlistAlertsPrefs({
    this.enabled = false,
    this.thresholdPercent = defaultWatchlistMoveThreshold,
  });

  WatchlistAlertsPrefs copyWith({bool? enabled, double? thresholdPercent}) {
    return WatchlistAlertsPrefs(
      enabled: enabled ?? this.enabled,
      thresholdPercent: thresholdPercent ?? this.thresholdPercent,
    );
  }
}

final watchlistAlertsProvider =
    NotifierProvider<WatchlistAlertsNotifier, WatchlistAlertsPrefs>(() {
  return WatchlistAlertsNotifier();
});

class WatchlistAlertsNotifier extends Notifier<WatchlistAlertsPrefs> {
  @override
  WatchlistAlertsPrefs build() {
    _load();
    ref.listen(watchlistProvider, (_, _) => _syncToCloud());
    return const WatchlistAlertsPrefs();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = WatchlistAlertsPrefs(
      enabled: prefs.getBool(_enabledKey) ?? false,
      thresholdPercent:
          prefs.getDouble(_thresholdKey) ?? defaultWatchlistMoveThreshold,
    );
    await _syncToCloud();
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _persist();
    if (enabled) {
      await AnalyticsService.instance.logEvent('watchlist_alerts_enabled');
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, state.enabled);
    await prefs.setDouble(_thresholdKey, state.thresholdPercent);
    await _syncToCloud();
  }

  Future<void> _syncToCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final entries = ref.read(watchlistProvider);
    final currency = ref.read(selectedCurrencyProvider);

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'watchlistAlerts': {
          'enabled': state.enabled,
          'thresholdPercent': state.thresholdPercent,
          'currency': currency,
          'entries': entries
              .map((e) => {
                    'metal': e.metal,
                    'karat': e.karat,
                  })
              .toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal; re-sync on next toggle.
    }
  }
}
