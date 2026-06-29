import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:goldsignal/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/ads/ad_service.dart';
import 'core/analytics/analytics_service.dart';
import 'core/notifications/alert_notification_service.dart';
import 'core/widget/home_widget_service.dart';
import 'core/utils/app_config.dart';
import 'core/utils/app_localization.dart';
import 'shared/themes/app_theme.dart';
import 'shared/providers/app_info_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
  await AdService.instance.initialize();
  await AnalyticsService.instance.initialize();

  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    EasyLocalization(
      supportedLocales: kSupportedLocales,
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: ProviderScope(
        overrides: [
          packageInfoProvider.overrideWith((ref) => packageInfo),
        ],
        child: const GoldSignalApp(),
      ),
    ),
  );
}

class GoldSignalApp extends StatelessWidget {
  const GoldSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoldSignal',
      supportedLocales: context.supportedLocales,
      localizationsDelegates: context.localizationDelegates,
      locale: context.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
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
