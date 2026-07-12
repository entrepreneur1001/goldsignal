import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../../../core/analytics/analytics_service.dart';
import '../../../../shared/models/price_alert.dart';
import '../../../../core/notifications/notification_permission_ui.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../../shared/widgets/ad_list_builder.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/native_ad_widget.dart';
import '../../../auth/presentation/widgets/auth_wall_sheet.dart';
import '../widgets/create_alert_sheet.dart';

class AlertsScreen extends ConsumerStatefulWidget {
  const AlertsScreen({super.key});

  @override
  ConsumerState<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends ConsumerState<AlertsScreen> {
  @override
  void initState() {
    super.initState();
    // Top of the alert funnel: alerts_viewed → alert_created → notification_opened.
    AnalyticsService.instance.logAlertsViewed();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(priceAlertsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.tr('alerts.title')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.tr('alerts.tab_active',
                  namedArgs: {'count': '${state.activeCount}'})),
              Tab(text: context.tr('alerts.tab_history',
                  namedArgs: {'count': '${state.historyAlerts.length}'})),
            ],
          ),
          actions: [
            IconButton(
              tooltip: context.tr('alerts.enable_notifications'),
              icon: const Icon(Icons.notifications_active_outlined),
              onPressed: () => enableNotifications(context, ref),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () async {
            if (!await requireAccount(context, 'price_alerts')) return;
            if (context.mounted) CreateAlertSheet.show(context);
          },
          icon: const Icon(Icons.add_alert),
          label: Text(context.tr('alerts.new_alert')),
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
      return EmptyState(
        icon: Icons.notifications_off_outlined,
        title: context.tr('profile.no_active_alerts'),
        message: context.tr('alerts.empty_active_msg'),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
      children: [
        if (active.isNotEmpty) ...[
          for (var i = 0; i < adListItemCount(active.length); i++) ...[
            if (i > 0) const SizedBox(height: 8),
            if (adListIndexIsAd(i, active.length))
              const NativeAdWidget.list()
            else
              _ActiveAlertTile(
                alert: active[adListContentIndex(i, active.length)],
                currentPrice: notifier.resolveCurrentPrice(
                  active[adListContentIndex(i, active.length)],
                ),
              ),
          ],
        ],
        if (snoozed.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(context.tr('alerts.snoozed'),
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (var i = 0; i < snoozed.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _SnoozedAlertTile(alert: snoozed[i]),
          ],
        ],
        if (paused.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(context.tr('alerts.paused'),
              style: Theme.of(context).textTheme.titleSmall),
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
      return EmptyState(
        icon: Icons.history,
        title: context.tr('alerts.empty_history_title'),
        message: context.tr('alerts.empty_history_msg'),
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
                    title: Text(context.tr('alerts.clear_history_title')),
                    content: Text(
                      context.tr('alerts.clear_history_confirm',
                          namedArgs: {'count': '${alerts.length}'}),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(context.tr('common.cancel')),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(context.tr('alerts.clear')),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await ref.read(priceAlertsProvider.notifier).clearHistory();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
              label: Text(context.tr('alerts.clear_history')),
            ),
          ),
        ),
        Expanded(
          child: _buildHistoryList(alerts),
        ),
      ],
    );
  }

  /// History list with at most one native ad after the first few alerts.
  Widget _buildHistoryList(List<PriceAlert> alerts) {
    final itemCount = adListItemCount(alerts.length);

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
      itemCount: itemCount,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (adListIndexIsAd(index, alerts.length)) {
          return const NativeAdWidget.list();
        }
        return _HistoryAlertTile(
          alert: alerts[adListContentIndex(index, alerts.length)],
        );
      },
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
        subtitle: _buildActiveSubtitle(context, alert, currentPrice, ref),
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
    final subtitle = StringBuffer(context.tr('alerts.waiting_repeat'));
    if (alert.reactivateAt != null) {
      subtitle.write(' · ${dateFmt.format(alert.reactivateAt!)}');
    }
    if (alert.triggeredAt != null) {
      subtitle.write('\n${context.tr('alerts.triggered_at', namedArgs: {
            'date': dateFmt.format(alert.triggeredAt!)
          })}');
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
              tooltip: context.tr('alerts.reactivate_now'),
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
        subtitle: _buildLiveSubtitle(context, alert, currentPrice, ref),
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
      subtitle.write('\n${context.tr('alerts.at_price', namedArgs: {
            'price': alert.triggeredPrice!.toStringAsFixed(2),
            'currency': alert.currency,
          })}');
      if (alert.isPercentChange && alert.baselinePrice != null) {
        final change = alert.changePercentFrom(alert.triggeredPrice!) ?? 0;
        final sign = change >= 0 ? '+' : '';
        subtitle.write(' ${context.tr('alerts.from_baseline', namedArgs: {
              'value': '$sign${change.toStringAsFixed(2)}%'
            })}');
      }
    }
    if (alert.isSnoozed && alert.reactivateAt != null) {
      subtitle.write('\n${context.tr('alerts.repeats', namedArgs: {
            'date': dateFmt.format(alert.reactivateAt!)
          })}');
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
              tooltip: context.tr('alerts.reactivate'),
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
  BuildContext context,
  PriceAlert alert,
  double? currentPrice,
  WidgetRef ref,
) {
  final rolling24h = alert.isPercent24h
      ? ref.read(priceAlertsProvider.notifier).resolveRolling24hPercent(alert)
      : null;
  final lines = <String>[];
  final live = _liveSubtitleText(
    context,
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
  BuildContext context,
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
    subtitle.write(context.tr('alerts.now', namedArgs: {
      'price': currentPrice.toStringAsFixed(2),
      'currency': alert.currency,
    }));
    if (alert.isPercent24h && rolling24hPercent != null) {
      final sign = rolling24hPercent >= 0 ? '+' : '';
      subtitle.write(' · ${context.tr('alerts.h24', namedArgs: {
            'value': '$sign${rolling24hPercent.toStringAsFixed(2)}%'
          })}');
    } else if (alert.type == AlertType.percentChange &&
        alert.baselinePrice != null) {
      final change = alert.changePercentFrom(currentPrice) ?? 0;
      final sign = change >= 0 ? '+' : '';
      subtitle.write(' ${context.tr('alerts.from_baseline', namedArgs: {
            'value': '$sign${change.toStringAsFixed(2)}%'
          })}');
    }
  } else if (alert.isPercent24h && rolling24hPercent != null) {
    final sign = rolling24hPercent >= 0 ? '+' : '';
    subtitle.write(context.tr('alerts.h24', namedArgs: {
      'value': '$sign${rolling24hPercent.toStringAsFixed(2)}%'
    }));
  } else if (alert.type == AlertType.percentChange && alert.baselinePrice != null) {
    subtitle.write(context.tr('alerts.baseline', namedArgs: {
      'price': alert.baselinePrice!.toStringAsFixed(2),
      'currency': alert.currency,
    }));
  }
  return subtitle.toString();
}

Widget? _buildLiveSubtitle(
  BuildContext context,
  PriceAlert alert,
  double? currentPrice,
  WidgetRef ref,
) {
  final rolling24h = alert.isPercent24h
      ? ref.read(priceAlertsProvider.notifier).resolveRolling24hPercent(alert)
      : null;
  final text = _liveSubtitleText(
    context,
    alert,
    currentPrice,
    rolling24hPercent: rolling24h,
  );
  return text == null ? null : Text(text);
}
