import 'package:share_plus/share_plus.dart';
import 'currency_format.dart';

/// Share a formatted live price line (WhatsApp, Telegram, etc.).
Future<void> shareMetalPrice({
  required String label,
  required double pricePerGram,
  required String currency,
  required double changePercent,
}) async {
  final sign = changePercent >= 0 ? '+' : '';
  final pct = '$sign${changePercent.toStringAsFixed(2)}%';
  final text =
      'GoldSignal — $label\n'
      '${formatCurrency(pricePerGram, currency)}/g ($pct 24h)\n'
      'Track live gold & silver prices';
  await SharePlus.instance.share(ShareParams(text: text));
}
