import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/firebase/firestore_price_alerts_service.dart';
import 'currency_provider.dart';

const _enabledKey = 'digest_enabled';
const _hourKey = 'digest_hour';
const _minuteKey = 'digest_minute';

class DigestPrefs {
  final bool enabled;
  final int hour; // local hour, 0-23
  final int minute; // local minute, 0-59

  const DigestPrefs({
    this.enabled = false,
    this.hour = 9,
    this.minute = 0,
  });

  /// 24h HH:mm label.
  String get formattedTime =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  DigestPrefs copyWith({bool? enabled, int? hour, int? minute}) {
    return DigestPrefs(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

final digestProvider = NotifierProvider<DigestNotifier, DigestPrefs>(() {
  return DigestNotifier();
});

class DigestNotifier extends Notifier<DigestPrefs> {
  @override
  DigestPrefs build() {
    _load();
    return const DigestPrefs();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = DigestPrefs(
      enabled: prefs.getBool(_enabledKey) ?? false,
      hour: prefs.getInt(_hourKey) ?? 9,
      minute: prefs.getInt(_minuteKey) ?? 0,
    );
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _persist();
    if (enabled) {
      await AnalyticsService.instance.logEvent('digest_enabled');
    }
  }

  Future<void> setTime(int hour, int minute) async {
    state = state.copyWith(hour: hour, minute: minute);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, state.enabled);
    await prefs.setInt(_hourKey, state.hour);
    await prefs.setInt(_minuteKey, state.minute);
    await _syncToCloud();
  }

  /// Mirror the preference to the user's Firestore doc so the scheduled Cloud
  /// Function can deliver the digest. Also refreshes offset + currency, which
  /// the function needs to localize timing and prices.
  Future<void> _syncToCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final currency = ref.read(selectedCurrencyProvider);
    try {
      await FirestorePriceAlertsService().saveDigestPrefs(uid, {
        'enabled': state.enabled,
        'hour': state.hour,
        'minute': state.minute,
        'utcOffsetMinutes': DateTime.now().timeZoneOffset.inMinutes,
        'currency': currency,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Non-fatal; will re-sync next time the user changes the setting.
    }
  }
}
