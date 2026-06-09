import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Thin wrapper around Firebase Analytics + Crashlytics.
///
/// Centralizes event logging and the navigator observer used for automatic
/// screen-view tracking, so call sites don't depend on the Firebase SDK
/// directly and event names stay consistent.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  FirebaseAnalytics get analytics => _analytics;

  /// Attach to `MaterialApp.navigatorObservers` for automatic screen tracking.
  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Log a custom event. Failures are swallowed (and reported to Crashlytics)
  /// so analytics never crashes the app.
  Future<void> logEvent(
    String name, {
    Map<String, Object>? parameters,
  }) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  /// Associate analytics + crash reports with a user (e.g. on sign-in).
  /// Pass null on sign-out to clear the association.
  Future<void> setUser(String? userId) async {
    try {
      await _analytics.setUserId(id: userId);
      await FirebaseCrashlytics.instance.setUserIdentifier(userId ?? '');
    } catch (_) {
      // Non-fatal; ignore.
    }
  }
}
