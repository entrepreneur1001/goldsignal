import 'package:flutter_riverpod/flutter_riverpod.dart';

final isProProvider = NotifierProvider<ProNotifier, bool>(() {
  return ProNotifier();
});

class ProNotifier extends Notifier<bool> {
  @override
  bool build() {
    // Paid plans are temporarily disabled; keep all users on the free tier.
    return false;
  }

  void refresh() => state = false;
}
