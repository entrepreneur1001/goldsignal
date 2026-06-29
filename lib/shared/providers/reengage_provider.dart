import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/firebase/firestore_user_service.dart';

/// Whether the user is opted in to re-engagement / price-news pushes.
///
/// Defaults to ON. Mirrors to `users/{uid}.reengage.enabled` so the scheduled
/// re-engagement Cloud Function can skip opted-out users.
const _reengageEnabledKey = 'reengage_enabled';

final reengageEnabledProvider =
    NotifierProvider<ReengageNotifier, bool>(() => ReengageNotifier());

class ReengageNotifier extends Notifier<bool> {
  @override
  bool build() {
    _load();
    return true;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_reengageEnabledKey) ?? true;
  }

  Future<void> setEnabled(bool enabled) async {
    state = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_reengageEnabledKey, enabled);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirestoreUserService().setReengageEnabled(uid, enabled);
    } catch (_) {
      // Non-fatal; re-syncs next time the user toggles the setting.
    }
  }
}
