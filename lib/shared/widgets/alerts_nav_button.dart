import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../features/alerts/presentation/screens/alerts_screen.dart';
import '../providers/price_alerts_provider.dart';

class AlertsNavButton extends ConsumerWidget {
  const AlertsNavButton({super.key});

  static void open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: 'Alerts'),
        builder: (_) => const AlertsScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final count = ref.watch(priceAlertsProvider).activeCount;

    return IconButton(
      tooltip: context.tr('alerts.title'),
      onPressed: () => open(context),
      icon: Badge(
        isLabelVisible: count > 0,
        label: Text('$count'),
        child: const Icon(Icons.notifications_outlined),
      ),
    );
  }
}
