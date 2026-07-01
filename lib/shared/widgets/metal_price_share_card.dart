import 'package:flutter/material.dart';
import '../../core/utils/currency_format.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// Branded card rendered to PNG for social sharing.
class MetalPriceShareCard extends StatelessWidget {
  const MetalPriceShareCard({
    super.key,
    required this.label,
    required this.pricePerGram,
    required this.currency,
    required this.changePercent,
    required this.isGold,
    this.languageCode = 'en',
  });

  final String label;
  final double pricePerGram;
  final String currency;
  final double changePercent;
  final bool isGold;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    const c = VaultColors.dark;
    final accent = isGold ? VaultColors.gold : VaultColors.silver;
    final sign = changePercent >= 0 ? '+' : '';
    final pct = '$sign${changePercent.toStringAsFixed(2)}%';
    final up = changePercent >= 0;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.bgBase,
            c.bgElevated,
            accent.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  isGold ? Icons.monetization_on : Icons.diamond_outlined,
                  color: accent,
                  size: 28,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  'GoldSignal',
                  style: AppTypography.microLabel(c, languageCode: languageCode)
                      .copyWith(color: accent, letterSpacing: 1.2),
                ),
              ],
            ),
            Text(
              formatCurrency(pricePerGram, currency),
              style: AppTypography.hero(c, size: 36, languageCode: languageCode),
            ),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (up ? VaultColors.up : VaultColors.down)
                        .withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$pct 24h',
                    style: TextStyle(
                      color: up ? VaultColors.up : VaultColors.down,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '/g',
                  style: TextStyle(color: c.textSecondary, fontSize: 14),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
