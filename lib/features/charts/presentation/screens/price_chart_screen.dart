import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/ads/ad_service.dart';
import '../../../../core/utils/currency_format.dart';
import '../../../../shared/local_market/local_market_config.dart';
import '../../../../shared/models/local_market_prices.dart';
import '../../../../shared/models/price_snapshot.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/price_history_provider.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';
import '../../chart_span_label.dart';

class PriceChartScreen extends ConsumerWidget {
  const PriceChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(chartQueryProvider);
    final chartState = ref.watch(chartDataProvider);
    final isLocal = ref.watch(isLocalMarketProvider);
    final hasBuySell = LocalMarketConfig.hasBuySellSide(query.currency);
    final theme = Theme.of(context);

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) AdService.instance.showInterstitial();
      },
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.tr('charts.title')),
        actions: [
          const AlertsNavButton(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: chartState.isLoading
                ? null
                : () => ref.read(chartDataProvider.notifier).load(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(chartDataProvider.notifier).load(),
        child: ListView(
        // Always scrollable so pull-to-refresh works even when the chart is
        // short or empty.
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildMetalToggle(context, ref, query.metal),
          const SizedBox(height: 12),
          _buildKaratSelector(ref, query, isLocal),
          const SizedBox(height: 12),
          if (hasBuySell) ...[
            _buildSideToggle(context, ref, query.side),
            const SizedBox(height: 12),
          ],
          _buildRangeSelector(ref, query.range),
          const SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: chartState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chartState.points.length < 2
                    ? _buildEmptyState(context, chartState)
                    : _buildChart(context, chartState.points, query.currency),
          ),
          const SizedBox(height: 16),
          if (chartState.points.isNotEmpty)
            _buildSummary(context, chartState.points, query.currency, query.range),
          if (chartState.error != null) ...[
            const SizedBox(height: 12),
            Text(
              chartState.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
          ],
        ],
      ),
      ),
    ),
    );
  }

  Widget _buildMetalToggle(BuildContext context, WidgetRef ref, String metal) {
    return SegmentedButton<String>(
      segments: [
        ButtonSegment(
          value: 'gold',
          label: Text(context.tr('charts.gold')),
          icon: const Icon(Icons.monetization_on),
        ),
        ButtonSegment(
          value: 'silver',
          label: Text(context.tr('charts.silver')),
          icon: const Icon(Icons.paid),
        ),
      ],
      selected: {metal},
      onSelectionChanged: (s) => ref.read(chartQueryProvider.notifier).setMetal(s.first),
    );
  }

  Widget _buildKaratSelector(WidgetRef ref, ChartQuery query, bool isLocal) {
    final karats = query.metal == 'gold'
        ? LocalMarketConfig.goldKarats(query.currency)
        : (isLocal
            ? LocalMarketConfig.silverKarats(query.currency)
            : const ['999']);

    return Wrap(
      spacing: 8,
      children: karats.map((k) {
        final label = query.metal == 'gold' ? '${k}K' : k;
        final selected = query.karat == k;
        return ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => ref.read(chartQueryProvider.notifier).setKarat(k),
        );
      }).toList(),
    );
  }

  Widget _buildSideToggle(BuildContext context, WidgetRef ref, PriceSide side) {
    return SegmentedButton<PriceSide>(
      segments: [
        ButtonSegment(
          value: PriceSide.sell,
          label: Text(context.tr('charts.sell')),
        ),
        ButtonSegment(
          value: PriceSide.buy,
          label: Text(context.tr('charts.buy')),
        ),
      ],
      selected: {side},
      onSelectionChanged: (s) => ref.read(chartQueryProvider.notifier).setSide(s.first),
    );
  }

  Widget _buildRangeSelector(WidgetRef ref, ChartRange range) {
    return SegmentedButton<ChartRange>(
      segments: ChartRange.values
          .map((r) => ButtonSegment(value: r, label: Text(r.label)))
          .toList(),
      selected: {range},
      onSelectionChanged: (s) => ref.read(chartQueryProvider.notifier).setRange(s.first),
    );
  }

  Widget _buildEmptyState(BuildContext context, ChartState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.insights_outlined, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              state.source != ChartDataSource.apiFallback
                  ? context.tr('charts.building')
                  : context.tr('charts.not_enough'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('charts.empty_hint'),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(
    BuildContext context,
    List<ChartDataPoint> points,
    String currency,
  ) {
    final spots = points
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final minY = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final maxY = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final range = (maxY - minY).abs();
    final padding = range > 0 ? range * 0.1 : maxY * 0.01;
    final yInterval = range > 0 ? range / 4 : 1.0;

    final lineColor = Theme.of(context).colorScheme.primary;

    // Include the year on axis labels when the range crosses a year boundary
    // (e.g. a 90-day range spanning Dec→Feb) to avoid ambiguous dates.
    final spansYears = points.first.date.year != points.last.date.year;
    final axisDateFormat = DateFormat(spansYears ? 'MM/dd/yy' : 'MM/dd');
    final tooltipDateFormat = DateFormat(spansYears ? 'MMM d, yyyy' : 'MMM d');

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: yInterval,
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 56,
              getTitlesWidget: (value, meta) => Text(
                formatCurrencyCompact(value, currency),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (points.length / 4).clamp(1, points.length).toDouble(),
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= points.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    axisDateFormat.format(points[i].date),
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: true),
        minX: 0,
        maxX: (points.length - 1).toDouble(),
        minY: minY - padding,
        maxY: maxY + padding,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2.5,
            dotData: FlDotData(show: points.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.12),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touched) => touched.map((bar) {
              final i = bar.x.toInt();
              if (i < 0 || i >= points.length) return null;
              return LineTooltipItem(
                '${formatCurrency(bar.y, currency)}\n${tooltipDateFormat.format(points[i].date)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildSummary(
    BuildContext context,
    List<ChartDataPoint> points,
    String currency,
    ChartRange selectedRange,
  ) {
    final firstPoint = points.first;
    final lastPoint = points.last;
    final first = firstPoint.value;
    final last = lastPoint.value;
    final change = last - first;
    final changePct = first != 0 ? (change / first) * 100 : 0.0;
    final isUp = change >= 0;
    final span = lastPoint.date.difference(firstPoint.date);
    final spanLabel = formatChartChangeSpanLabel(span);
    final selectedDuration = Duration(days: selectedRange.days);
    final isPartialRange =
        selectedDuration.inMilliseconds > 0 &&
        span < selectedDuration * 0.6;
    final firstDay = DateTime(
      firstPoint.date.year,
      firstPoint.date.month,
      firstPoint.date.day,
    );
    final lastDay = DateTime(
      lastPoint.date.year,
      lastPoint.date.month,
      lastPoint.date.day,
    );
    final isFlatSameDay = change.abs() < 0.001 && firstDay == lastDay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _summaryItem(
                  context,
                  context.tr('charts.start'),
                  formatCurrency(first, currency),
                  subtitle: DateFormat('MMM d, yyyy').format(firstPoint.date),
                ),
                _summaryItem(
                  context,
                  context.tr('charts.change_over', namedArgs: {'span': spanLabel}),
                  '${formatCurrency(change, currency, showSign: true)} (${isUp ? '+' : ''}${changePct.toStringAsFixed(2)}%)',
                  color: isUp ? Colors.green : Colors.red,
                ),
                _summaryItem(
                  context,
                  context.tr('charts.latest'),
                  formatCurrency(last, currency),
                  subtitle: DateFormat('MMM d, yyyy').format(lastPoint.date),
                ),
              ],
            ),
            if (isFlatSameDay) ...[
              const SizedBox(height: 8),
              Text(
                context.tr('charts.flat'),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (isPartialRange && !isFlatSameDay) ...[
              const SizedBox(height: 8),
              Text(
                context.tr(
                  'charts.partial_range',
                  namedArgs: {'span': formatChartSpanCaption(span)},
                ),
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
    BuildContext context,
    String label,
    String value, {
    String? subtitle,
    Color? color,
  }) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}
