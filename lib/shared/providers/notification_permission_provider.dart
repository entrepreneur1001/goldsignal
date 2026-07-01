import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/notifications/alert_notification_service.dart';

class NotificationPermissionNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return AlertNotificationService.instance.isPermissionGranted();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      AlertNotificationService.instance.isPermissionGranted,
    );
  }
}

final notificationPermissionProvider =
    AsyncNotifierProvider<NotificationPermissionNotifier, bool>(
  NotificationPermissionNotifier.new,
);
