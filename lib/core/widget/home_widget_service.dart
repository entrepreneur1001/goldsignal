import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

class HomeWidgetService {
  static final HomeWidgetService instance = HomeWidgetService._();
  HomeWidgetService._();

  static const _androidProvider = 'GoldPriceWidget';
  static const _qualifiedAndroidName =
      'com.goldsignal.goldsignal.GoldPriceWidget';

  Future<void> initialize() async {
    if (kIsWeb) return;
    try {
      await HomeWidget.setAppGroupId('group.com.goldsignal.goldsignal');
    } catch (_) {}
  }

  Future<void> updateDisplay({
    required String label,
    required String pricePerGram,
    required String currency,
    required String changePercent,
    required bool isPositive,
  }) async {
    if (kIsWeb) return;

    try {
      await HomeWidget.saveWidgetData<String>('widget_label', label);
      await HomeWidget.saveWidgetData<String>('gold_price', pricePerGram);
      await HomeWidget.saveWidgetData<String>('currency', currency);
      await HomeWidget.saveWidgetData<String>('gold_change', changePercent);
      await HomeWidget.saveWidgetData<bool>('change_positive', isPositive);
      await HomeWidget.updateWidget(
        name: _androidProvider,
        androidName: _androidProvider,
      );
    } catch (_) {}
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
        name: _androidProvider,
        androidName: _androidProvider,
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    } catch (_) {}
  }
}
