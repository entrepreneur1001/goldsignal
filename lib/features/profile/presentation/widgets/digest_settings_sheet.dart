import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/providers/digest_provider.dart';
import '../../../../shared/providers/price_alerts_provider.dart';
import '../../../../shared/providers/reengage_provider.dart';
import 'package:easy_localization/easy_localization.dart';

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
    final reengageEnabled = ref.watch(reengageEnabledProvider);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(context.tr('profile.digest'),
                style: theme.textTheme.titleLarge),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.summarize_outlined),
            title: Text(context.tr('profile.digest_send')),
            subtitle: Text(context.tr('profile.digest_send_sub')),
            value: prefs.enabled,
            onChanged: (value) async {
              if (value) {
                // Only enable if notifications are actually permitted —
                // otherwise the digest could never be delivered.
                final granted = await ref
                    .read(priceAlertsProvider.notifier)
                    .requestNotificationPermission();
                if (!granted) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.tr('profile.digest_enable_notif')),
                      ),
                    );
                  }
                  return;
                }
              }
              await notifier.setEnabled(value);
            },
          ),
          ListTile(
            enabled: prefs.enabled,
            leading: const Icon(Icons.schedule),
            title: Text(context.tr('profile.digest_delivery_time')),
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
              context.tr('profile.digest_note'),
              style: theme.textTheme.bodySmall,
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Icons.campaign_outlined),
            title: Text(context.tr('profile.reengage_title')),
            subtitle: Text(context.tr('profile.reengage_sub')),
            value: reengageEnabled,
            onChanged: (value) =>
                ref.read(reengageEnabledProvider.notifier).setEnabled(value),
          ),
        ],
      ),
    );
  }
}
