import 'package:flutter/material.dart';
import '../../core/utils/currency_format.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import 'delta_pill.dart';
import 'vault_buttons.dart';
import 'vault_card.dart';

/// Vault-styled metal price card. API unchanged so existing call sites
/// (Markets screen) keep working.
class PriceCard extends StatelessWidget {
  final String metal;
  final IconData icon;
  final Color color;
  final double pricePerOunce;
  final double pricePerGram;
  final String currency;
  final double change24h;
  final double changePercent;
  final VoidCallback? onSetAlert;

  const PriceCard({
    super.key,
    required this.metal,
    required this.icon,
    required this.color,
    required this.pricePerOunce,
    required this.pricePerGram,
    required this.currency,
    required this.change24h,
    required this.changePercent,
    this.onSetAlert,
  });

  bool get isPositive =>
      changePercent != 0 ? changePercent >= 0 : change24h >= 0;

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final isGold = metal.toLowerCase().contains('gold');
    final accent = isGold ? VaultColors.gold : VaultColors.silver;

    return VaultCard(
      glow: isGold,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(metal, style: theme.textTheme.titleMedium),
                    Text('LIVE PRICE', style: AppTypography.microLabel(c)),
                  ],
                ),
              ),
              DeltaPill(percent: changePercent),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            formatCurrency(pricePerGram, currency),
            style: AppTypography.hero(c, size: 34),
          ),
          const SizedBox(height: 2),
          Text('per gram', style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniStat(context, c, 'Per ounce',
                    formatCurrency(pricePerOunce, currency)),
              ),
              Container(width: 1, height: 32, color: c.hairline),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                  context,
                  c,
                  '24h change',
                  '${isPositive ? '+' : ''}${formatCurrency(change24h, currency)}',
                  valueColor: isPositive ? VaultColors.up : VaultColors.down,
                ),
              ),
            ],
          ),
          if (onSetAlert != null) ...[
            const SizedBox(height: 16),
            GhostButton(
              label: 'Set alert',
              icon: Icons.notifications_none_rounded,
              onPressed: onSetAlert,
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniStat(
    BuildContext context,
    VaultColors c,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: AppTypography.microLabel(c)),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor ?? c.textPrimary,
                fontWeight: FontWeight.w700,
              ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
