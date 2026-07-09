import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/market_prices_provider.dart';
import 'app_config.dart';

/// Applies [locale] app-wide: EasyLocalization persistence, AppConfig mirror,
/// analytics-friendly language pref, and a home-widget label rebuild.
Future<void> setAppLocale(
  BuildContext context,
  Locale locale, {
  WidgetRef? ref,
}) async {
  await context.setLocale(locale);
  await AppConfig.setLanguage(locale.languageCode);
  if (ref != null) {
    ref.read(marketPricesControllerProvider.notifier).applyCurrentPrices();
  }
}
