import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../shared/models/price_alert.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../auth/presentation/widgets/auth_wall_sheet.dart';
import '../widgets/create_alert_sheet.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(priceAlertsProvider);
    final notifier = ref.read(priceAlertsProvider.notifier);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Price Alerts'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Active (${state.activeCount})'),
              Tab(text: 'History (${state.historyAlerts.length})'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Enable notifications',
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () async {
                await notifier.requestNotificationPermission();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification permission updated'),
                    ),
                  );
                }
              },
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            if (!await requireAccount(context, 'price alerts')) return;
            if (context.mounted) CreateAlertSheet.show(context);
          },
          icon: const Icon(Icons.add_alert),
          label: const Text('New alert'),
        ),
        body: Column(
          children: [
            if (state.isSyncing)
              const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: TabBarView(
                children: [
                  _ActiveAlertsTab(state: state),
                  _HistoryTab(alerts: state.historyAlerts),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveAlertsTab extends ConsumerWidget {
  final PriceAlertsState state;

  const _ActiveAlertsTab({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(priceAlertsProvider.notifier);
    final active = state.activeAlerts;
    final snoozed = state.snoozedAlerts;
    final paused = state.pausedAlerts;

    if (active.isEmpty && snoozed.isEmpty && paused.isEmpty) {
      return _buildEmpty(
        context,
        icon: Icons.notifications_off_outlined,
        title: 'No active alerts',
        message:
            'Create a price or percent-change alert for gold or silver. '
            'Alerts sync to your account and notify you in the background.',
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (active.isNotEmpty) ...[
          for (var i = 0; i < active.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ActiveAlertTile(
              alert: active[i],
              currentPrice: notifier.resolveCurrentPrice(active[i]),
            ),
          ],
        ],
        if (snoozed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Snoozed', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < snoozed.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _SnoozedAlertTile(alert: snoozed[i]),
          ],
        ],
        if (paused.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text('Paused', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < paused.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _PausedAlertTile(
              alert: paused[i],
              currentPrice: notifier.resolveCurrentPrice(paused[i]),
            ),
          ],
        ],
      ],
    );
  }
}

class _HistoryTab extends ConsumerWidget {
  final List<PriceAlert> alerts;

  const _HistoryTab({required this.alerts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (alerts.isEmpty) {
      return _buildEmpty(
        context,
        icon: Icons.history,
        title: 'No triggered alerts yet',
        message:
            'When an alert fires, it moves here with the price and time '
            'it triggered. You can reactivate any alert from history.',
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear history?'),
                    content: Text(
                      'Delete ${alerts.length} triggered alert(s) from history? '
                      'Active and snoozed alerts are not affected.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(priceAlertsProvider.notifier).clearHistory();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: const Text('Clear history'),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
            itemCount: alerts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) =>
                _HistoryAlertTile(alert: alerts[index]),
          ),
        ),
      ],
    );
  }
}

class _ActiveAlertTile extends ConsumerWidget {
  final PriceAlert alert;
  final double? currentPrice;

  const _ActiveAlertTile({
    required this.alert,
    required this.currentPrice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.notifications_active,
          color: Theme.of(context).colorScheme.primary,
        ),
        title: Text(alert.label),
        subtitle: _buildActiveSubtitle(alert, currentPrice, ref),
        isThreeLine: alert.autoRepeats || alert.isPercent24h,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: true,
              onChanged: (v) => ref
                  .read(priceAlertsProvider.notifier)
                  .toggleAlert(alert.id, v),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref
                  .read(priceAlertsProvider.notifier)
                  .deleteAlert(alert.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnoozedAlertTile extends ConsumerWidget {
  final PriceAlert alert;

  const _SnoozedAlertTile({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('MMM d, HH:mm');
    final subtitle = StringBuffer('Waiting to repeat');
    if (alert.reactivateAt != null) {
      subtitle.write(' · ${dateFmt.format(alert.reactivateAt!)}');
    }
    if (alert.triggeredAt != null) {
      subtitle.write('\nTriggered ${dateFmt.format(alert.triggeredAt!)}');
    }

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(Icons.snooze, color: Colors.orange.shade700),
        title: Text(alert.label),
        subtitle: Text(subtitle.toString()),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Reactivate now',
              icon: const Icon(Icons.replay),
              onPressed: () => ref
                  .read(priceAlertsProvider.notifier)
                  .reactivateAlert(alert.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref
                  .read(priceAlertsProvider.notifier)
                  .deleteAlert(alert.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _PausedAlertTile extends ConsumerWidget {
  final PriceAlert alert;
  final double? currentPrice;

  const _PausedAlertTile({
    required this.alert,
    required this.currentPrice,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: Icon(Icons.notifications_paused, color: Colors.grey.shade600),
        title: Text(alert.label),
        subtitle: _buildLiveSubtitle(alert, currentPrice, ref),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: false,
              onChanged: (v) => ref
                  .read(priceAlertsProvider.notifier)
                  .toggleAlert(alert.id, v),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref
                  .read(priceAlertsProvider.notifier)
                  .deleteAlert(alert.id),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryAlertTile extends ConsumerWidget {
  final PriceAlert alert;

  const _HistoryAlertTile({required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFmt = DateFormat('MMM d, yyyy · HH:mm');
    final subtitle = StringBuffer();

    if (alert.triggeredAt != null) {
      subtitle.write(dateFmt.format(alert.triggeredAt!));
    }
    if (alert.triggeredPrice != null) {
      subtitle.write(
        '\nAt ${alert.triggeredPrice!.toStringAsFixed(2)} ${alert.currency}/g',
      );
      if (alert.isPercentChange && alert.baselinePrice != null) {
        final change = alert.changePercentFrom(alert.triggeredPrice!) ?? 0;
        final sign = change >= 0 ? '+' : '';
        subtitle.write(' ($sign${change.toStringAsFixed(2)}% from baseline)');
      }
    }
    if (alert.isSnoozed && alert.reactivateAt != null) {
      subtitle.write('\nRepeats ${dateFmt.format(alert.reactivateAt!)}');
    } else if (alert.autoRepeats) {
      subtitle.write('\n${alert.repeatDescription}');
    }

    return Card(
      child: ListTile(
        leading: Icon(
          Icons.check_circle_outline,
          color: Theme.of(context).colorScheme.tertiary,
        ),
        title: Text(alert.label),
        subtitle: subtitle.isEmpty ? null : Text(subtitle.toString()),
        isThreeLine: alert.triggeredPrice != null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Reactivate',
              icon: const Icon(Icons.replay),
              onPressed: () => ref
                  .read(priceAlertsProvider.notifier)
                  .reactivateAlert(alert.id),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () => ref
                  .read(priceAlertsProvider.notifier)
                  .deleteAlert(alert.id),
            ),
          ],
        ),
      ),
    );
  }
}

Widget? _buildActiveSubtitle(
  PriceAlert alert,
  double? currentPrice,
  WidgetRef ref,
) {
  final rolling24h = alert.isPercent24h
      ? ref.read(priceAlertsProvider.notifier).resolveRolling24hPercent(alert)
      : null;
  final lines = <String>[];
  final live = _liveSubtitleText(
    alert,
    currentPrice,
    rolling24hPercent: rolling24h,
  );
  if (live != null) lines.add(live);
  if (alert.repeatDescription != null) lines.add(alert.repeatDescription!);
  if (lines.isEmpty) return null;
  return Text(lines.join('\n'));
}

String? _liveSubtitleText(
  PriceAlert alert,
  double? currentPrice, {
  double? rolling24hPercent,
}) {
  if (currentPrice == null &&
      alert.baselinePrice == null &&
      rolling24hPercent == null) {
    return null;
  }

  final subtitle = StringBuffer();
  if (currentPrice != null) {
    subtitle.write(
      'Now: ${currentPrice.toStringAsFixed(2)} ${alert.currency}/g',
    );
    if (alert.isPercent24h && rolling24hPercent != null) {
      final sign = rolling24hPercent >= 0 ? '+' : '';
      subtitle.write(' · 24h: $sign${rolling24hPercent.toStringAsFixed(2)}%');
    } else if (alert.type == AlertType.percentChange &&
        alert.baselinePrice != null) {
      final change = alert.changePercentFrom(currentPrice) ?? 0;
      final sign = change >= 0 ? '+' : '';
      subtitle.write(' ($sign${change.toStringAsFixed(2)}% from baseline)');
    }
  } else if (alert.isPercent24h && rolling24hPercent != null) {
    final sign = rolling24hPercent >= 0 ? '+' : '';
    subtitle.write('24h: $sign${rolling24hPercent.toStringAsFixed(2)}%');
  } else if (alert.type == AlertType.percentChange && alert.baselinePrice != null) {
    subtitle.write(
      'Baseline: ${alert.baselinePrice!.toStringAsFixed(2)} ${alert.currency}/g',
    );
  }
  return subtitle.toString();
}

Widget? _buildLiveSubtitle(
  PriceAlert alert,
  double? currentPrice,
  WidgetRef ref,
) {
  final rolling24h = alert.isPercent24h
      ? ref.read(priceAlertsProvider.notifier).resolveRolling24hPercent(alert)
      : null;
  final text = _liveSubtitleText(
    alert,
    currentPrice,
    rolling24hPercent: rolling24h,
  );
  return text == null ? null : Text(text);
}

Widget _buildEmpty(
  BuildContext context, {
  required IconData icon,
  required String title,
  required String message,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 56, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ),
  );
}
