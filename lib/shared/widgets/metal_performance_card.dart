import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/app_colors.dart';
import '../models/metal_performance.dart';
import '../providers/metal_performance_provider.dart';
import 'delta_pill.dart';
import 'shimmer.dart';
import 'vault_card.dart';

const _periodI18n = {
  'Today': 'prices.perf_today',
  '30 Days': 'prices.perf_30_days',
  '6 Months': 'prices.perf_6_months',
  '1 Year': 'prices.perf_1_year',
  '5 Year': 'prices.perf_5_years',
  '20 Years': 'prices.perf_20_years',
};

/// Multi-period gold & silver performance from goldprice.org.
class MetalPerformanceCard extends ConsumerWidget {
  const MetalPerformanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(metalPerformanceProvider);

    return async.when(
      loading: () => const _PerformanceSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data == null || data.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.gold.isNotEmpty) ...[
              _MetalSection(
                title: context.tr('prices.gold_performance'),
                accent: VaultColors.gold,
                periods: data.gold,
              ),
              if (data.silver.isNotEmpty) const SizedBox(height: 12),
            ],
            if (data.silver.isNotEmpty)
              _MetalSection(
                title: context.tr('prices.silver_performance'),
                accent: VaultColors.silver,
                periods: data.silver,
              ),
          ],
        );
      },
    );
  }
}

class _MetalSection extends StatelessWidget {
  const _MetalSection({
    required this.title,
    required this.accent,
    required this.periods,
  });

  final String title;
  final Color accent;
  final List<MetalPerformancePeriod> periods;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);

    return VaultCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < periods.length; i++) ...[
            _PeriodRow(period: periods[i]),
            if (i < periods.length - 1)
              Divider(height: 1, color: c.hairline.withValues(alpha: 0.6)),
          ],
        ],
      ),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  const _PeriodRow({required this.period});

  final MetalPerformancePeriod period;

  String _localizedLabel(BuildContext context) {
    final key = _periodI18n[period.label];
    if (key == null) return period.label;
    return context.tr(key);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);
    final amountColor = period.isPositive ? VaultColors.up : VaultColors.down;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _localizedLabel(context),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            period.amount,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w600,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 10),
          DeltaPill(percent: period.percentValue, compact: true),
        ],
      ),
    );
  }
}

class _PerformanceSkeleton extends StatelessWidget {
  const _PerformanceSkeleton();

  @override
  Widget build(BuildContext context) {
    final c = VaultColors.of(Theme.of(context).brightness);
    return VaultCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(width: 140, height: 14),
          const SizedBox(height: 14),
          for (var i = 0; i < 4; i++) ...[
            Row(
              children: [
                const Expanded(child: ShimmerBox(height: 12)),
                const SizedBox(width: 24),
                ShimmerBox(
                  width: 72,
                  height: 12,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(width: 10),
                ShimmerBox(
                  width: 52,
                  height: 20,
                  borderRadius: BorderRadius.circular(999),
                ),
              ],
            ),
            if (i < 3) ...[
              const SizedBox(height: 12),
              Divider(height: 1, color: c.hairline.withValues(alpha: 0.4)),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}
