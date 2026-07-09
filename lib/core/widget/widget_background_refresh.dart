import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../../firebase_options.dart';
import '../../shared/local_market/local_market_config.dart';
import '../../shared/models/local_market_prices.dart';
import '../../shared/providers/widget_preferences_provider.dart';
import '../api/goodreturns_price_scraper.dart';
import '../api/isagha_price_scraper.dart';
import '../api/metalpriceapi_service.dart';
import '../crash/crash_reporter.dart';
import 'home_widget_service.dart';
import 'widget_strings.dart';

const widgetBackgroundTaskName = 'goldsignal.widgetPriceRefresh';
const widgetBackgroundTaskUniqueName = 'goldsignal.widgetPriceRefresh.periodic';

/// Background entry point for the widget refresh button (home_widget).
@pragma('vm:entry-point')
Future<void> widgetRefreshCallback(Uri? uri) async {
  if (uri == null || uri.queryParameters['action'] != 'refresh') return;
  try {
    await refreshWidgetPricesInBackground();
  } catch (e, st) {
    reportNonFatal(e, st, reason: 'widget refresh callback failed');
  }
}

/// Workmanager entry point — must be a top-level or static function.
@pragma('vm:entry-point')
void widgetWorkmanagerDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      await refreshWidgetPricesInBackground();
      return true;
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'widget workmanager task failed');
      return false;
    }
  });
}

/// Fetches latest prices and pushes a localized board to the home widget.
///
/// Safe to call from the home_widget interactivity isolate, Workmanager, or
/// a foreground helper. Initializes Firebase/Hive when needed.
Future<void> refreshWidgetPricesInBackground() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  try {
    await Hive.initFlutter();
  } catch (_) {
    // Already initialized in this isolate.
  }
  if (!Hive.isBoxOpen('goldPrices')) {
    await Hive.openBox('goldPrices');
  }
  if (!Hive.isBoxOpen('localMarketPrices')) {
    await Hive.openBox('localMarketPrices');
  }

  final prefs = await SharedPreferences.getInstance();
  final currency = prefs.getString('selected_currency') ?? 'USD';
  final language = prefs.getString('language') ?? 'en';
  final strings = WidgetStrings.forLanguage(language);
  final side =
      prefs.getString('price_side') == 'buy' ? PriceSide.buy : PriceSide.sell;
  final goldKarat = prefs.getString('widget_gold_karat') ??
      defaultKaratFor(metal: 'gold', currency: currency);
  final silverKarat = prefs.getString('widget_silver_karat') ??
      defaultKaratFor(metal: 'silver', currency: currency);

  await HomeWidgetService.instance.initialize();

  if (LocalMarketConfig.isLocalCurrency(currency)) {
    final LocalMarketPrices local;
    if (currency == 'INR') {
      local = await GoodreturnsPriceScraper().fetchLatestPrices();
    } else {
      local = await IsaghaPriceScraper().fetchLatestPrices();
    }

    WidgetMetalRow? rowFor(String metal, String karat) {
      final row =
          metal == 'gold' ? local.goldKarat(karat) : local.silverKarat(karat);
      if (row == null) return null;
      return WidgetMetalRow(
        metal: metal,
        label: strings.rowLabel(metal: metal, karat: karat),
        pricePerGram: row.priceFor(side),
        changeValue: row.change,
        changePercent: row.changePercent,
      );
    }

    await HomeWidgetService.instance.updateBoard(
      WidgetBoardData(
        currency: currency,
        unitLabel: strings.unitLabel(currency),
        locale: language,
        updatedAt: local.updatedAt,
        gold: rowFor('gold', goldKarat),
        silver: rowFor('silver', silverKarat),
      ),
    );
    return;
  }

  // Global market: Firestore shared cache → scrape → stale cache.
  const ounceToGram = 31.1034768;
  final api = MetalPriceApiService();
  final global = await api.fetchFreshPrices();

  WidgetMetalRow? rowFor(String metal, String karat) {
    final ounce = metal == 'gold'
        ? global.goldPriceIn(currency)
        : global.silverPriceIn(currency);
    if (ounce == null) return null;
    final purity = metal == 'gold' ? (int.tryParse(karat) ?? 24) / 24 : 1.0;
    final perGram = (ounce / ounceToGram) * purity;
    final delta = api.change24hFor(
      response: global,
      metal: metal,
      currency: currency,
    );
    return WidgetMetalRow(
      metal: metal,
      label: strings.rowLabel(metal: metal, karat: karat),
      pricePerGram: perGram,
      changeValue:
          delta == null ? null : (delta.change / ounceToGram) * purity,
      changePercent: delta?.changePercent,
    );
  }

  await HomeWidgetService.instance.updateBoard(
    WidgetBoardData(
      currency: currency,
      unitLabel: strings.unitLabel(currency),
      locale: language,
      updatedAt: global.timestamp,
      gold: rowFor('gold', goldKarat),
      silver: rowFor('silver', silverKarat),
    ),
  );
}

/// Registers the periodic ~30 min background refresh (Android WorkManager /
/// iOS BGAppRefresh via workmanager). No-op on web.
Future<void> scheduleWidgetBackgroundRefresh() async {
  if (kIsWeb) return;
  try {
    await Workmanager().initialize(
      widgetWorkmanagerDispatcher,
      isInDebugMode: kDebugMode,
    );
    // Android minimum periodic interval is 15 minutes; iOS is best-effort.
    await Workmanager().registerPeriodicTask(
      widgetBackgroundTaskUniqueName,
      widgetBackgroundTaskName,
      frequency: const Duration(minutes: 30),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  } catch (e, st) {
    reportNonFatal(e, st, reason: 'scheduleWidgetBackgroundRefresh failed');
  }
}

/// Whether the current platform supports workmanager scheduling.
bool get supportsWidgetBackgroundRefresh =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);
