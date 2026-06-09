import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/local_market_prices.dart';
import '../../../../shared/models/price_snapshot.dart';
import '../../../../shared/providers/market_prices_provider.dart';
import '../../../../shared/providers/price_history_provider.dart';
import '../../../../shared/widgets/alerts_nav_button.dart';

class PriceChartScreen extends ConsumerWidget {
  const PriceChartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(chartQueryProvider);
    final chartState = ref.watch(chartDataProvider);
    final isLocal = ref.watch(isLocalMarketProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Price History'),
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
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSourceBadge(context, chartState.source),
          const SizedBox(height: 12),
          _buildMetalToggle(ref, query.metal),
          const SizedBox(height: 12),
          _buildKaratSelector(ref, query, isLocal),
          const SizedBox(height: 12),
          if (isLocal) ...[
            _buildSideToggle(ref, query.side),
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
            _buildSummary(context, chartState.points, query.currency),
          if (chartState.error != null) ...[
            const SizedBox(height: 12),
            Text(
              chartState.error!,
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.orange),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceBadge(BuildContext context, ChartDataSource source) {
    final isApiFallback = source == ChartDataSource.apiFallback;
    final isCommunity = source == ChartDataSource.community;
    final color = isApiFallback
        ? Colors.orange
        : isCommunity
            ? Colors.blue
            : Colors.green;
    final icon = isApiFallback
        ? Icons.cloud_download_outlined
        : isCommunity
            ? Icons.people_outline
            : Icons.timeline;
    final label = switch (source) {
      ChartDataSource.apiFallback => 'Reference data (delayed API fallback)',
      ChartDataSource.community => 'Community price history (Firestore)',
      ChartDataSource.snapshots => 'Live history from scraper snapshots',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildMetalToggle(WidgetRef ref, String metal) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'gold', label: Text('Gold'), icon: Icon(Icons.monetization_on)),
        ButtonSegment(value: 'silver', label: Text('Silver'), icon: Icon(Icons.paid)),
      ],
      selected: {metal},
      onSelectionChanged: (s) => ref.read(chartQueryProvider.notifier).setMetal(s.first),
    );
  }

  Widget _buildKaratSelector(WidgetRef ref, ChartQuery query, bool isLocal) {
    final karats = query.metal == 'gold'
        ? (isLocal ? ['24', '22', '21', '18'] : ['24', '22', '21', '18'])
        : (isLocal ? ['999', '925', '900', '800'] : ['999']);

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

  Widget _buildSideToggle(WidgetRef ref, PriceSide side) {
    return SegmentedButton<PriceSide>(
      segments: const [
        ButtonSegment(value: PriceSide.sell, label: Text('Sell')),
        ButtonSegment(value: PriceSide.buy, label: Text('Buy')),
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
                  ? 'Building price history…'
                  : 'Not enough data yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Prices are recorded automatically on each refresh. '
              'Pull to refresh on the Prices tab, then reopen this chart.',
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
              reservedSize: 52,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(0),
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
                    DateFormat('MM/dd').format(points[i].date),
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
                '$currency ${bar.y.toStringAsFixed(2)}\n${DateFormat('MMM d').format(points[i].date)}',
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
  ) {
    final firstPoint = points.first;
    final lastPoint = points.last;
    final first = firstPoint.value;
    final last = lastPoint.value;
    final change = last - first;
    final changePct = first != 0 ? (change / first) * 100 : 0.0;
    final isUp = change >= 0;
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
                  'Start',
                  '$currency ${first.toStringAsFixed(2)}',
                  subtitle: DateFormat('MMM d').format(firstPoint.date),
                ),
                _summaryItem(
                  context,
                  'Change',
                  '${isUp ? '+' : ''}${change.toStringAsFixed(2)} (${changePct.toStringAsFixed(2)}%)',
                  color: isUp ? Colors.green : Colors.red,
                ),
                _summaryItem(
                  context,
                  'Latest',
                  '$currency ${last.toStringAsFixed(2)}',
                  subtitle: DateFormat('MMM d').format(lastPoint.date),
                ),
              ],
            ),
            if (isFlatSameDay) ...[
              const SizedBox(height: 8),
              Text(
                'Flat over selected range',
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
