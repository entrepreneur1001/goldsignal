import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import 'animated_value.dart';
import 'delta_pill.dart';
import 'sparkline.dart';
import 'vault_card.dart';
import 'vault_buttons.dart';

/// Hero price card: metal glyph + micro-label, big serif price (count-up),
/// 24h delta pill, inline sparkline, optional actions. The headline metal gets
/// a gold glow.
class MetalPriceCard extends StatelessWidget {
  final String metal; // 'Gold' | 'Silver'
  final String? karatLabel; // '24K'
  final double price;
  final String Function(double) priceFormatter;
  final double changePercent;
  final String unitLabel; // 'per gram'
  final List<double> spark;
  final bool headline;
  final VoidCallback? onAlert;
  final VoidCallback? onHistory;

  const MetalPriceCard({
    super.key,
    required this.metal,
    required this.price,
    required this.priceFormatter,
    required this.changePercent,
    this.karatLabel,
    this.unitLabel = 'per gram',
    this.spark = const [],
    this.headline = false,
    this.onAlert,
    this.onHistory,
  });

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final isGold = metal.toLowerCase() == 'gold';
    final accent = isGold ? VaultColors.gold : VaultColors.silver;
    final label = karatLabel != null
        ? '${metal.toUpperCase()} · $karatLabel'
        : metal.toUpperCase();

    return VaultCard(
      glow: headline,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isGold ? Icons.savings_rounded : Icons.circle,
                  size: 18,
                  color: accent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppTypography.microLabel(c))),
              DeltaPill(percent: changePercent),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedValue(
            value: price,
            formatter: priceFormatter,
            style: AppTypography.hero(c, size: 38),
          ),
          const SizedBox(height: 2),
          Text(unitLabel, style: Theme.of(context).textTheme.bodySmall),
          if (spark.length >= 2) ...[
            const SizedBox(height: 14),
            Sparkline(values: spark, color: accent),
          ],
          if (onAlert != null || onHistory != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (onAlert != null)
                  GhostButton(
                    label: 'Set alert',
                    icon: Icons.notifications_none_rounded,
                    onPressed: onAlert,
                  ),
                if (onAlert != null && onHistory != null)
                  const SizedBox(width: 8),
                if (onHistory != null)
                  GhostButton(
                    label: 'History',
                    icon: Icons.show_chart_rounded,
                    onPressed: onHistory,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
