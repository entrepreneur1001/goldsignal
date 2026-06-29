import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../core/utils/currency_format.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import 'animated_value.dart';
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
  final bool isWatchlisted;
  final VoidCallback? onToggleWatchlist;
  final VoidCallback? onShare;

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
    this.isWatchlisted = false,
    this.onToggleWatchlist,
    this.onShare,
  });

  bool get isPositive =>
      changePercent != 0 ? changePercent >= 0 : change24h >= 0;

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    final theme = Theme.of(context);
    final languageCode = Localizations.localeOf(context).languageCode;
    final isGold = metal.toLowerCase().contains('gold');
    final accent = isGold ? VaultColors.gold : VaultColors.silver;

    // Derive the absolute 24h change in both units from the (reliable) percent,
    // so it's consistent with the displayed prices regardless of the caller's
    // change24h unit.
    double deltaOf(double price) =>
        changePercent == 0 ? 0 : price - price / (1 + changePercent / 100);
    final perGramChange = deltaOf(pricePerGram);
    final perOunceChange = deltaOf(pricePerOunce);
    final changeColor = isPositive ? VaultColors.up : VaultColors.down;
    final sign = isPositive ? '+' : '-';
    String chg(double v) => '$sign${formatCurrency(v.abs(), currency)}';

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
                    Text(
                      context.tr('prices.live_price'),
                      style: AppTypography.microLabel(
                        c,
                        languageCode: languageCode,
                      ),
                    ),
                  ],
                ),
              ),
              DeltaPill(percent: changePercent),
              if (onToggleWatchlist != null)
                IconButton(
                  tooltip: isWatchlisted
                      ? context.tr('prices.remove_from_watchlist')
                      : context.tr('prices.add_to_watchlist'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onToggleWatchlist,
                  icon: Icon(
                    isWatchlisted
                        ? Icons.star_rounded
                        : Icons.star_border_rounded,
                    color: isWatchlisted ? VaultColors.gold : c.textTertiary,
                  ),
                ),
              if (onShare != null)
                IconButton(
                  tooltip: context.tr('prices.share_price'),
                  visualDensity: VisualDensity.compact,
                  onPressed: onShare,
                  icon: Icon(Icons.ios_share_rounded, color: c.textTertiary),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedValue(
            value: pricePerGram,
            formatter: (v) => formatCurrency(v, currency),
            style: AppTypography.hero(c, size: 34, languageCode: languageCode),
          ),
          const SizedBox(height: 2),
          Text(context.tr('prices.per_gram'), style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  context,
                  c,
                  context.tr('prices.per_ounce'),
                  formatCurrency(pricePerOunce, currency),
                ),
              ),
              Container(width: 1, height: 40, color: c.hairline),
              const SizedBox(width: 12),
              Expanded(
                child: _miniStat(
                  context,
                  c,
                  context.tr('prices.change_24h'),
                  '${chg(perGramChange)} /g',
                  valueColor: changeColor,
                  sub: '${chg(perOunceChange)} /oz',
                  subColor: changeColor,
                ),
              ),
            ],
          ),
          if (onSetAlert != null) ...[
            const SizedBox(height: 16),
            GhostButton(
              label: context.tr('prices.set_alert'),
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
    String? sub,
    Color? subColor,
  }) {
    final languageCode = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: AppTypography.microLabel(c, languageCode: languageCode),
        ),
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
        if (sub != null) ...[
          const SizedBox(height: 2),
          Text(
            sub,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: subColor ?? c.textTertiary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }
}
