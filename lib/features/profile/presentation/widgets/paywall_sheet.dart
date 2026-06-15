import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

import '../../../../shared/providers/purchase_provider.dart';

class PaywallSheet {
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final result = await RevenueCatUI.presentPaywallIfNeeded('pro');
    if (result == PaywallResult.purchased || result == PaywallResult.restored) {
      ref.read(isProProvider.notifier).refresh();
    }
  }
}
