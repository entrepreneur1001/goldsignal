import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../core/storage/spread_history_service.dart';
import '../../core/utils/currency_format.dart';
import '../design/app_colors.dart';
import '../models/local_market_prices.dart';

/// Egypt jeweler buy/sell spread for 21K gold with a 7-day mini chart.
class EgpSpreadCard extends ConsumerStatefulWidget {
  const EgpSpreadCard({super.key, required this.localPrices});

  final LocalMarketPrices localPrices;

  @override
  ConsumerState<EgpSpreadCard> createState() => _EgpSpreadCardState();
}

class _EgpSpreadCardState extends ConsumerState<EgpSpreadCard> {
  List<SpreadPoint> _history = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void didUpdateWidget(covariant EgpSpreadCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.localPrices.updatedAt != widget.localPrices.updatedAt) {
      _recordAndReload();
    }
  }

  Future<void> _loadHistory() async {
    final history = await SpreadHistoryService.instance.last7Days();
    if (mounted) {
      setState(() {
        _history = history;
        _loading = false;
      });
    }
  }

  Future<void> _recordAndReload() async {
    final row = widget.localPrices.goldKarat('21');
    if (row == null || row.isPerUnit) return;
    final spread = row.buyPerGram - row.sellPerGram;
    await SpreadHistoryService.instance.record(spread, widget.localPrices.updatedAt);
    await _loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.localPrices.goldKarat('21');
    if (row == null || row.isPerUnit) return const SizedBox.shrink();

    final spread = row.buyPerGram - row.sellPerGram;
    final spreadPct = row.sellPerGram > 0 ? (spread / row.sellPerGram) * 100 : 0.0;
    final theme = Theme.of(context);
    final c = VaultColors.of(theme.brightness);

    double? avg7;
    if (_history.isNotEmpty) {
      avg7 = _history.map((e) => e.spread).reduce((a, b) => a + b) / _history.length;
    }
    final narrowed = avg7 != null && spread < avg7 * 0.95;
    final widened = avg7 != null && spread > avg7 * 1.05;

    String hint;
    if (narrowed) {
      hint = context.tr('growth.spread_narrow');
    } else if (widened) {
      hint = context.tr('growth.spread_wide');
    } else {
      hint = context.tr('growth.spread_normal');
    }

    return Material(
      color: c.bgElevated,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('growth.egp_spread_title'),
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatCurrency(spread, 'EGP'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        context.tr('growth.spread_gap',
                            namedArgs: {'pct': spreadPct.toStringAsFixed(2)}),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (!_loading && _history.length >= 2)
                  SizedBox(
                    width: 100,
                    height: 48,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [
                              for (var i = 0; i < _history.length; i++)
                                FlSpot(i.toDouble(), _history[i].spread),
                            ],
                            isCurved: true,
                            color: VaultColors.gold,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(hint, style: theme.textTheme.bodySmall?.copyWith(color: c.textSecondary)),
            const SizedBox(height: 4),
            Text(
              context.tr('growth.spread_sell_buy', namedArgs: {
                'sell': formatCurrency(row.sellPerGram, 'EGP'),
                'buy': formatCurrency(row.buyPerGram, 'EGP'),
              }),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
