import 'package:app_settings/app_settings.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/providers/notification_permission_provider.dart';
import '../../shared/providers/price_alerts_provider.dart';

Future<void> enableNotifications(BuildContext context, WidgetRef ref) async {
  final granted = await ref
      .read(priceAlertsProvider.notifier)
      .requestNotificationPermission();
  await ref.read(notificationPermissionProvider.notifier).refresh();
  if (!context.mounted) return;

  if (granted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.tr('profile.notif_enabled'))),
    );
  } else {
    await _showDeniedDialog(context);
  }
}

Future<void> showDisableInSettingsDialog(BuildContext context) async {
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('profile.notif_disable_in_settings_title')),
      content: Text(context.tr('profile.notif_disable_in_settings_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('profile.open_settings')),
        ),
      ],
    ),
  );

  if (openSettings == true) {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }
}

Future<void> _showDeniedDialog(BuildContext context) async {
  final openSettings = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.tr('profile.notif_denied_title')),
      content: Text(context.tr('profile.notif_denied_body')),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.tr('common.cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(context.tr('profile.open_settings')),
        ),
      ],
    ),
  );

  if (openSettings == true) {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }
}
