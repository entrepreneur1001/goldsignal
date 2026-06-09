import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/config/app_remote_config.dart';

final remoteConfigServiceProvider = Provider<RemoteConfigService>((ref) {
  return RemoteConfigService();
});

/// Holds the [AppRemoteConfig] fetched at launch (by the splash screen) so the
/// rest of the app (rating store id, soft-update prompt) can read it without
/// re-fetching. Null until the first fetch completes.
final appRemoteConfigProvider = NotifierProvider<AppRemoteConfigNotifier,
    AppRemoteConfig?>(() {
  return AppRemoteConfigNotifier();
});

class AppRemoteConfigNotifier extends Notifier<AppRemoteConfig?> {
  @override
  AppRemoteConfig? build() => null;

  void set(AppRemoteConfig config) => state = config;
}
