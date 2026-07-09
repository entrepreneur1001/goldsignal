import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../crash/crash_reporter.dart';
import '../../shared/providers/widget_preferences_provider.dart';

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
  Future<void> registerInteractivity(
    Future<void> Function(Uri?) callback,
  ) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.registerInteractivityCallback(callback);
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
      await HomeWidget.saveWidgetData<String>('unit_label', board.unitLabel);
      await HomeWidget.saveWidgetData<String>('locale', board.locale);
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
        qualifiedAndroidName: _qualifiedAndroidName,
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
