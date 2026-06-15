import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../core/purchases/purchase_service.dart';

final isProProvider = NotifierProvider<ProNotifier, bool>(() {
  return ProNotifier();
});

class ProNotifier extends Notifier<bool> {
  @override
  bool build() {
    _check();
    return false;
  }

  Future<void> _check() async {
    final isPro = await PurchaseService.instance.isPro();
    state = isPro;
  }

  Future<bool> purchase(Package package) async {
    final success = await PurchaseService.instance.purchase(package);
    if (success) state = true;
    return success;
  }

  Future<bool> restore() async {
    final success = await PurchaseService.instance.restore();
    if (success) state = true;
    return success;
  }

  void refresh() => _check();
}
