import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../api/goodreturns_price_scraper.dart';
import '../api/isagha_price_scraper.dart';
import '../crash/crash_reporter.dart';
import '../../shared/local_market/local_market_config.dart';
import '../../shared/models/local_market_prices.dart';
import '../../shared/providers/widget_preferences_provider.dart';

/// Background entry point invoked when the widget's refresh button is tapped.
///
/// Runs in a separate isolate, so it cannot touch the app's Riverpod state.
/// For local markets (EGP/INR) it performs a real scrape and re-pushes the
/// board; the global market relies on the Firebase/Hive stack and is left to
/// the next in-app refresh (OS still updates the widget every ~30 min).
@pragma('vm:entry-point')
Future<void> widgetRefreshCallback(Uri? uri) async {
  if (uri == null || uri.queryParameters['action'] != 'refresh') return;
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final currency = prefs.getString('selected_currency') ?? 'USD';
    if (!LocalMarketConfig.isLocalCurrency(currency)) return;

    final side =
        prefs.getString('price_side') == 'buy' ? PriceSide.buy : PriceSide.sell;
    final goldKarat = prefs.getString('widget_gold_karat') ??
        defaultKaratFor(metal: 'gold', currency: currency);
    final silverKarat = prefs.getString('widget_silver_karat') ??
        defaultKaratFor(metal: 'silver', currency: currency);

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
        label: widgetLabelFor(metal: metal, karat: karat),
        pricePerGram: row.priceFor(side),
        changeValue: row.change,
        changePercent: row.changePercent,
      );
    }

    await HomeWidgetService.instance.initialize();
    await HomeWidgetService.instance.updateBoard(
      WidgetBoardData(
        currency: currency,
        updatedAt: local.updatedAt,
        gold: rowFor('gold', goldKarat),
        silver: rowFor('silver', silverKarat),
      ),
    );
  } catch (e, st) {
    reportNonFatal(e, st, reason: 'widget refresh callback failed');
  }
}

class HomeWidgetService {
  static final HomeWidgetService instance = HomeWidgetService._();
  HomeWidgetService._();

  static const _widgetName = 'GoldPriceWidget';
  static const _qualifiedAndroidName =
      'com.goldsignal.goldsignal.GoldPriceWidget';
  static const _appGroupId = 'group.com.goldsignal.goldsignal';

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId(_appGroupId);
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'HomeWidget.setAppGroupId failed');
    }
  }

  /// Registers the background handler for the widget's refresh button.
  /// Call once from the foreground isolate during app startup.
  Future<void> registerInteractivity() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.registerInteractivityCallback(widgetRefreshCallback);
    } catch (e, st) {
      reportNonFatal(e, st,
          reason: 'HomeWidget.registerInteractivityCallback failed');
    }
  }

  /// Pushes the full two-row board (Gold + Silver) to the native widget.
  Future<void> updateBoard(WidgetBoardData board) async {
    if (kIsWeb) return;

    try {
      await HomeWidget.saveWidgetData<String>('currency', board.currency);
      await HomeWidget.saveWidgetData<String>(
        'last_updated',
        _formatTime(board.updatedAt),
      );
      await _saveRow('gold', board.gold);
      await _saveRow('silver', board.silver);
      await HomeWidget.updateWidget(
        name: _widgetName,
        androidName: _widgetName,
        iOSName: _widgetName,
      );
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'HomeWidget.updateBoard failed');
    }
  }

  Future<void> _saveRow(String prefix, WidgetMetalRow? row) async {
    if (row == null) {
      await HomeWidget.saveWidgetData<bool>('${prefix}_present', false);
      return;
    }
    await HomeWidget.saveWidgetData<bool>('${prefix}_present', true);
    await HomeWidget.saveWidgetData<String>('${prefix}_label', row.label);
    await HomeWidget.saveWidgetData<String>(
        '${prefix}_price', row.formattedPrice);
    await HomeWidget.saveWidgetData<String>(
        '${prefix}_change', row.formattedChange);
    await HomeWidget.saveWidgetData<String>(
        '${prefix}_change_pct', row.formattedChangePercent);
    await HomeWidget.saveWidgetData<bool>('${prefix}_positive', row.isPositive);
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  Future<bool> isPinSupported() async {
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      return await HomeWidget.isRequestPinWidgetSupported() ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestPin() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      await HomeWidget.requestPinWidget(
        name: _widgetName,
        androidName: _widgetName,
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    } catch (e, st) {
      reportNonFatal(e, st, reason: 'HomeWidget.requestPin failed');
    }
  }
}
