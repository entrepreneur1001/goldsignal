import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../core/config/app_remote_config.dart';
import '../../../core/utils/currency_format.dart';
import '../../../core/utils/share_price.dart';
import '../providers/app_config_provider.dart';
import '../design/app_colors.dart';
import '../models/watchlist_entry.dart';
import '../providers/watchlist_provider.dart';
import 'delta_pill.dart';

/// Horizontal strip of pinned watchlist quotes at the top of Markets.
class WatchlistStrip extends ConsumerWidget {
  const WatchlistStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quotes = ref.watch(watchlistQuotesProvider);
    if (quotes.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, size: 18, color: VaultColors.gold),
            const SizedBox(width: 6),
            Text(
              context.tr('prices.watchlist'),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 108,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: quotes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final q = quotes[index];
              return _WatchlistTile(quote: q);
            },
          ),
        ),
      ],
    );
  }
}

class _WatchlistTile extends ConsumerWidget {
  const _WatchlistTile({required this.quote});

  final WatchlistQuote quote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark ? Colors.grey[850] : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () async {
          final config = ref.read(appRemoteConfigProvider) ??
              const AppRemoteConfig();
          await shareMetalPrice(
            context: context,
            label: quote.entry.label,
            pricePerGram: quote.pricePerGram,
            currency: quote.currency,
            changePercent: quote.changePercent,
            config: config,
            isGold: quote.entry.metal == 'gold',
          );
        },
        child: Container(
          width: 156,
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      quote.entry.label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () =>
                        ref.read(watchlistProvider.notifier).remove(quote.entry),
                    child: const Icon(Icons.close, size: 16),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                formatCurrency(quote.pricePerGram, quote.currency),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              DeltaPill(percent: quote.changePercent, compact: true),
            ],
          ),
        ),
      ),
    );
  }
}
