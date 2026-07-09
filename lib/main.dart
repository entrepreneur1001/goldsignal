import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goldsignal/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/utils/font_bootstrap.dart';
import 'core/ads/ad_service.dart';
import 'core/utils/app_session.dart';
import 'core/analytics/analytics_service.dart';
import 'core/firebase/firestore_user_service.dart';
import 'core/notifications/alert_notification_service.dart';
import 'core/widget/home_widget_service.dart';
import 'core/utils/app_config.dart';
import 'core/utils/app_localization.dart';
import 'shared/themes/app_theme.dart';
import 'shared/providers/app_info_provider.dart';
import 'shared/providers/currency_provider.dart';
import 'shared/providers/market_prices_provider.dart';
import 'shared/providers/notification_permission_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';
import 'features/profile/presentation/widgets/widget_settings_sheet.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FontBootstrap.configure();
  FontBootstrap.registerLicenses();

  // easy_localization storage for the persisted language selection.
  await EasyLocalization.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Firestore is the single source of truth for user data; enable offline
  // persistence explicitly with an unbounded cache for full offline support.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Route uncaught Flutter + async errors to Crashlytics.
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize other configurations
  await AppConfig.initialize();
  await AlertNotificationService.instance.initialize();
  await HomeWidgetService.instance.initialize();
  await HomeWidgetService.instance.registerInteractivity();
  await AdService.instance.initialize();
  await AnalyticsService.instance.initialize();
  await FontBootstrap.preload();

  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    EasyLocalization(
      supportedLocales: kSupportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        overrides: [packageInfoProvider.overrideWith((ref) => packageInfo)],
        child: const GoldSignalApp(),
      ),
    ),
  );
}

/// Throttle Firestore activity writes: a foreground bounce shouldn't write on
/// every resume. Survives app restarts via shared_preferences.
const _lastActivityWriteKey = 'last_activity_write_ms';
const _activityWriteThrottle = Duration(hours: 1);

class GoldSignalApp extends ConsumerStatefulWidget {
  const GoldSignalApp({super.key});

  @override
  ConsumerState<GoldSignalApp> createState() => _GoldSignalAppState();
}

final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>();

class _GoldSignalAppState extends ConsumerState<GoldSignalApp>
    with WidgetsBindingObserver {
  StreamSubscription<Uri?>? _widgetClickSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // App launch counts as a foreground — record activity once the first frame
    // is up so providers/auth are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onForeground());
    _initWidgetDeepLinks();
  }

  @override
  void dispose() {
    _widgetClickSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Routes taps on the home-screen widget into the app. The settings gear
  /// opens the widget settings sheet; any tap also refreshes prices.
  Future<void> _initWidgetDeepLinks() async {
    _widgetClickSub = HomeWidget.widgetClicked.listen(_handleWidgetUri);
    try {
      final launchUri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      _handleWidgetUri(launchUri);
    } catch (_) {
      // Non-fatal; ignore if the launch URI can't be read.
    }
  }

  void _handleWidgetUri(Uri? uri) {
    if (uri == null) return;
    switch (uri.queryParameters['action']) {
      case 'settings':
        // Defer so the navigator is ready (e.g. on cold launch).
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final ctx = rootNavigatorKey.currentContext;
          if (ctx != null) WidgetSettingsSheet.show(ctx);
        });
        break;
      case 'refresh':
        ref.read(marketPricesControllerProvider.notifier).refresh();
        break;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onForeground();
    }
  }

  /// Logs the open, refreshes cohort user properties, and writes the throttled
  /// activity signal the re-engagement function reads.
  Future<void> _onForeground() async {
    ref.invalidate(notificationPermissionProvider);
    // Read context/provider state up front, before any await crosses a frame.
    final currency = ref.read(selectedCurrencyProvider);
    final localeCode = context.locale.languageCode;
    final appVersion = ref.read(packageInfoProvider).version;

    await AnalyticsService.instance.logAppOpen();
    await incrementSessionCount();
    await AnalyticsService.instance.setUserProperty('currency', currency);
    await AnalyticsService.instance.setUserProperty('app_language', localeCode);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastActivityWriteKey) ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (nowMs - last < _activityWriteThrottle.inMilliseconds) return;
    await prefs.setInt(_lastActivityWriteKey, nowMs);

    try {
      await FirestoreUserService().recordActivity(
        uid,
        appVersion: appVersion,
        locale: localeCode,
      );
    } catch (_) {
      // Non-fatal; activity will be recorded on the next foreground.
    }
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;

    return MaterialApp(
      title: 'GoldSignal',
      navigatorKey: rootNavigatorKey,
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      locale: locale,
      theme: AppTheme.lightThemeFor(locale),
      darkTheme: AppTheme.darkThemeFor(locale),
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      // Tap anywhere outside a text field to dismiss the keyboard. Essential
      // on iOS where the numeric keypad has no Done key.
      builder: (context, child) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: child,
      ),
      navigatorObservers: [AnalyticsService.instance.navigatorObserver],
      // Use a named initial route so the analytics observer logs the first
      // screen as 'Splash' instead of the default '/'. No other route uses
      // named navigation, so this only handles app launch.
      onGenerateRoute: (_) => MaterialPageRoute(
        settings: const RouteSettings(name: 'Splash'),
        builder: (_) => const SplashScreen(),
      ),
    );
  }
}
