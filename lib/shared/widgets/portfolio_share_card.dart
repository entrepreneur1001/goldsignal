import 'package:flutter/material.dart';
import '../../core/utils/currency_format.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';

/// Portfolio performance snapshot for social sharing.
class PortfolioShareCard extends StatelessWidget {
  const PortfolioShareCard({
    super.key,
    required this.totalValue,
    required this.profitLoss,
    required this.profitLossPercent,
    required this.currency,
    this.languageCode = 'en',
  });

  final double totalValue;
  final double profitLoss;
  final double profitLossPercent;
  final String currency;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    const c = VaultColors.dark;
    final up = profitLoss >= 0;
    final sign = profitLoss >= 0 ? '+' : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0B0B0F), Color(0xFF1C1C26), Color(0xFF2A2418)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VaultColors.gold.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'MY PORTFOLIO',
                  style: AppTypography.microLabel(c, languageCode: languageCode)
                      .copyWith(color: VaultColors.gold),
                ),
                Text(
                  'GoldSignal',
                  style: AppTypography.microLabel(c, languageCode: languageCode)
                      .copyWith(color: VaultColors.gold, letterSpacing: 1.2),
                ),
              ],
            ),
            Text(
              formatCurrency(totalValue, currency),
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
                    '$sign${profitLossPercent.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: up ? VaultColors.up : VaultColors.down,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$sign${formatCurrency(profitLoss, currency)} all-time',
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
