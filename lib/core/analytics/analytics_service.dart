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
  ///
  /// NOTE: the observer only logs a `screen_view` for routes that carry a
  /// `RouteSettings.name`. Always push routes with
  /// `MaterialPageRoute(settings: RouteSettings(name: 'X'), ...)` or call
  /// [logScreenView] manually for non-route screens (e.g. bottom-nav tabs).
  FirebaseAnalyticsObserver get navigatorObserver =>
      FirebaseAnalyticsObserver(analytics: _analytics);

  /// Explicitly enable analytics collection. Collection is on by default, but
  /// calling this on startup makes the behaviour deterministic across builds.
  Future<void> initialize() async {
    try {
      await _analytics.setAnalyticsCollectionEnabled(true);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

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

  /// Manually log a screen view. Use for screens that aren't pushed as named
  /// routes — e.g. the bottom-nav tabs that live inside an `IndexedStack` and
  /// therefore never trigger the navigator observer.
  Future<void> logScreenView(String screenName) async {
    try {
      await _analytics.logScreenView(screenName: screenName);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  /// Standard GA `app_open` event. Logged on each foreground resume so
  /// engagement funnels and re-engagement campaigns have a consistent open
  /// signal alongside Firebase's auto-logged `session_start`.
  Future<void> logAppOpen() async {
    try {
      await _analytics.logAppOpen();
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  /// Bottom of the notification funnel: a push was opened. [source] is the
  /// push `data.type`, e.g. 'price_alert', 'daily_digest', 're_engagement'.
  Future<void> logNotificationOpened(String source) =>
      logEvent('notification_opened', parameters: {'source': source});

  /// Top of the alert funnel: the user opened the Alerts screen.
  /// Pairs with the existing `alert_created` event to form
  /// `alerts_viewed → alert_created → notification_opened`.
  Future<void> logAlertsViewed() => logEvent('alerts_viewed');

  /// Set a user property for cohort segmentation (e.g. `has_alerts`,
  /// `has_portfolio`, `currency`, `app_language`). Pass null to clear.
  Future<void> setUserProperty(String name, String? value) async {
    try {
      await _analytics.setUserProperty(name: name, value: value);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  /// Standard GA `login` event. [method] e.g. 'password', 'guest'.
  Future<void> logLogin(String method) async {
    try {
      await _analytics.logLogin(loginMethod: method);
    } catch (e, st) {
      await FirebaseCrashlytics.instance.recordError(e, st, fatal: false);
    }
  }

  /// Standard GA `sign_up` event. [method] e.g. 'password', 'guest_upgrade'.
  Future<void> logSignUp(String method) async {
    try {
      await _analytics.logSignUp(signUpMethod: method);
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
