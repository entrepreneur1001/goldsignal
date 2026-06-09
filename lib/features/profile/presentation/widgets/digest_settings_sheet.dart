import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/digest_provider.dart';
import '../../../../shared/providers/price_alerts_provider.dart';

class DigestSettingsSheet extends ConsumerWidget {
  const DigestSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const Padding(
        padding: EdgeInsets.only(bottom: 24),
        child: DigestSettingsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final prefs = ref.watch(digestProvider);
    final notifier = ref.read(digestProvider.notifier);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text('Daily Price Digest',
                style: theme.textTheme.titleLarge),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.summarize_outlined),
            title: const Text('Send a daily digest'),
            subtitle: const Text('Today\'s gold & silver and 24h move'),
            value: prefs.enabled,
            onChanged: (value) async {
              if (value) {
                // Ensure notifications are permitted before enabling.
                await ref
                    .read(priceAlertsProvider.notifier)
                    .requestNotificationPermission();
              }
              await notifier.setEnabled(value);
            },
          ),
          ListTile(
            enabled: prefs.enabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Delivery time'),
            subtitle: Text(prefs.formattedTime),
            trailing: const Icon(Icons.edit_outlined),
            onTap: prefs.enabled
                ? () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime:
                          TimeOfDay(hour: prefs.hour, minute: prefs.minute),
                    );
                    if (picked != null) {
                      await notifier.setTime(picked.hour, picked.minute);
                    }
                  }
                : null,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'Delivered within ~30 minutes of your chosen time, even when the '
              'app is closed. Uses your selected currency. Requires '
              'notifications to be enabled.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
