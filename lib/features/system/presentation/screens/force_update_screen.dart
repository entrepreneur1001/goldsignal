import 'package:flutter/material.dart';
import '../../../../shared/design/app_colors.dart';
import '../../../../core/config/app_remote_config.dart';
import '../../store_launcher.dart';
import 'package:easy_localization/easy_localization.dart';

/// Full-screen, non-dismissible "update required" gate shown at launch when the
/// installed version is below `metadata/app.minimumVersion`.
class ForceUpdateScreen extends StatelessWidget {
  final AppRemoteConfig config;

  const ForceUpdateScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.system_update,
                      size: 88, color: VaultColors.gold),
                  const SizedBox(height: 24),
                  Text(
                    context.tr('system.update_required'),
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    config.updateMessage,
                    style: theme.textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => openAppStore(config),
                    icon: const Icon(Icons.download),
                    label: Text(context.tr('system.update_now')),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
