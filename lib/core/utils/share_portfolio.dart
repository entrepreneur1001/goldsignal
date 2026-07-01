import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../analytics/analytics_service.dart';
import '../config/app_remote_config.dart';
import 'currency_format.dart';
import 'share_links.dart';
import '../../shared/widgets/portfolio_share_card.dart';
import '../../shared/widgets/share_card_capture.dart';

/// Share portfolio net worth and P/L as an image card.
Future<void> sharePortfolioPerformance({
  required BuildContext context,
  required double totalValue,
  required double profitLoss,
  required double profitLossPercent,
  required String currency,
  required AppRemoteConfig config,
}) async {
  if (totalValue <= 0) return;

  final languageCode = Localizations.localeOf(context).languageCode;
  final sign = profitLoss >= 0 ? '+' : '';
  final footer = shareMessageFooter(config, campaign: 'portfolio_share');
  final text =
      'GoldSignal — My Portfolio\n'
      '${formatCurrency(totalValue, currency)} '
      '($sign${profitLossPercent.toStringAsFixed(1)}% all-time)\n'
      '$footer';

  final card = PortfolioShareCard(
    totalValue: totalValue,
    profitLoss: profitLoss,
    profitLossPercent: profitLossPercent,
    currency: currency,
    languageCode: languageCode,
  );

  final bytes = await captureShareCard(
    context,
    card,
    size: const Size(360, 220),
  );
  await AnalyticsService.instance.logEvent(
    'share',
    parameters: {'content_type': 'portfolio'},
  );

  if (bytes != null) {
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/png',
            name: 'goldsignal_portfolio.png',
          ),
        ],
      ),
    );
  } else {
    await SharePlus.instance.share(ShareParams(text: text));
  }
}
