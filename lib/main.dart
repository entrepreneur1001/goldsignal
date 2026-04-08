import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:goldsignal/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'core/utils/app_config.dart';
import 'shared/themes/app_theme.dart';
import 'shared/providers/app_info_provider.dart';
import 'features/auth/presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Initialize Hive
  await Hive.initFlutter();

  // Initialize other configurations
  await AppConfig.initialize();

  final packageInfo = await PackageInfo.fromPlatform();

  runApp(
    ProviderScope(
      overrides: [
        packageInfoProvider.overrideWith((ref) => packageInfo),
      ],
      child: const GoldSignalApp(),
    ),
  );
}

class GoldSignalApp extends ConsumerStatefulWidget {
  const GoldSignalApp({super.key});

  @override
  ConsumerState<GoldSignalApp> createState() => _GoldSignalAppState();
}

class _GoldSignalAppState extends ConsumerState<GoldSignalApp> {
  Locale _currentLocale = const Locale('en');
  
  @override
  void initState() {
    super.initState();
    // Initialize with saved locale preference if available
    _loadSavedLocale();
  }
  
  Future<void> _loadSavedLocale() async {
    // You can load saved locale from SharedPreferences here
    // For now, default to English
    setState(() {
      _currentLocale = const Locale('en');
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GoldSignal',
      supportedLocales: const [
        Locale('en', ''),
        Locale('ar', ''),
        Locale('ur', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      locale: _currentLocale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}