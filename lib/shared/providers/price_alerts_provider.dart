import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/firebase/firestore_price_alerts_service.dart';
import '../../core/notifications/alert_notification_service.dart';
import '../../core/notifications/push_messaging_service.dart';
import '../../core/storage/price_alerts_service.dart';
import '../models/local_market_prices.dart';
import '../models/price_alert.dart';
import 'currency_provider.dart';
import 'market_prices_provider.dart';
import 'metal_price_provider.dart';

const _ounceToGram = 31.1034768;

final priceAlertsServiceProvider = Provider<PriceAlertsService>((ref) {
  return PriceAlertsService();
});

final firestorePriceAlertsServiceProvider =
    Provider<FirestorePriceAlertsService>((ref) {
  return FirestorePriceAlertsService();
});

class PriceAlertsState {
  final List<PriceAlert> alerts;
  final String? snackbarMessage;
  final bool isSyncing;

  const PriceAlertsState({
    this.alerts = const [],
    this.snackbarMessage,
    this.isSyncing = false,
  });

  int get activeCount => alerts.where((a) => a.isActive).length;

  List<PriceAlert> get activeAlerts =>
      alerts.where((a) => a.isActive).toList();

  List<PriceAlert> get snoozedAlerts => alerts.where((a) => a.isSnoozed).toList();

  List<PriceAlert> get pausedAlerts => alerts
      .where((a) => !a.isActive && !a.isSnoozed && a.triggeredAt == null)
      .toList();

  List<PriceAlert> get historyAlerts {
    final history = alerts
        .where((a) => a.triggeredAt != null && !a.isSnoozed)
        .toList();
    history.sort((a, b) => b.triggeredAt!.compareTo(a.triggeredAt!));
    return history;
  }

  PriceAlertsState copyWith({
    List<PriceAlert>? alerts,
    String? snackbarMessage,
    bool? isSyncing,
    bool clearSnackbar = false,
  }) {
    return PriceAlertsState(
      alerts: alerts ?? this.alerts,
      snackbarMessage:
          clearSnackbar ? null : (snackbarMessage ?? this.snackbarMessage),
      isSyncing: isSyncing ?? this.isSyncing,
    );
  }
}

final priceAlertsProvider =
    NotifierProvider<PriceAlertsNotifier, PriceAlertsState>(() {
  return PriceAlertsNotifier();
});

class PriceAlertsNotifier extends Notifier<PriceAlertsState> {
  @override
  PriceAlertsState build() {
    Future.microtask(_bootstrap);
    final service = ref.read(priceAlertsServiceProvider);
    return PriceAlertsState(alerts: service.getAll());
  }

  Future<void> _bootstrap() async {
    await AlertNotificationService.instance.initialize();
    PushMessagingService.instance.onPriceAlertReceived = () {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) refreshFromCloud(uid);
    };
    await PushMessagingService.instance.initialize();

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      state = state.copyWith(isSyncing: true);
      try {
        await _mergeFromFirestore(uid);
      } catch (_) {}
      state = state.copyWith(isSyncing: false);
    }
    _reload();
    await _processDueReactivations();
  }

  Future<void> refreshFromCloud(String uid) async {
    state = state.copyWith(isSyncing: true);
    try {
      await _mergeFromFirestore(uid);
    } catch (_) {}
    state = state.copyWith(isSyncing: false);
    _reload();
  }

  Future<void> _mergeFromFirestore(String uid) async {
    final localService = ref.read(priceAlertsServiceProvider);
    final firestore = ref.read(firestorePriceAlertsServiceProvider);
    final local = localService.getAll();
    final cloud = await firestore.loadAll(uid);

    if (cloud.isEmpty && local.isNotEmpty) {
      await firestore.syncLocalToCloud(uid, local);
      return;
    }

    if (cloud.isNotEmpty) {
      await localService.replaceAll(cloud);
    }
  }

  Future<void> _syncAlertToCloud(PriceAlert alert) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(firestorePriceAlertsServiceProvider).saveAlert(uid, alert);
    } catch (_) {}
  }

  Future<void> _deleteFromCloud(String id) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await ref.read(firestorePriceAlertsServiceProvider).deleteAlert(uid, id);
    } catch (_) {}
  }

  void _reload() {
    final service = ref.read(priceAlertsServiceProvider);
    state = state.copyWith(alerts: service.getAll(), clearSnackbar: true);
  }

  void clearSnackbar() {
    state = state.copyWith(clearSnackbar: true);
  }

  Future<void> requestNotificationPermission() async {
    await AlertNotificationService.instance.requestPermission();
    await PushMessagingService.instance.refreshToken();
  }

  Future<void> createAlert({
    required String metal,
    required String karat,
    required String currency,
    PriceSide? side,
    required AlertType type,
    required AlertCondition condition,
    required double targetValue,
    int? repeatAfterHours,
  }) async {
    final preview = PriceAlert(
      id: 'preview',
      metal: metal,
      karat: karat,
      currency: currency,
      side: currency == 'EGP' ? (side ?? PriceSide.sell) : null,
      type: type,
      condition: condition,
      targetValue: targetValue,
      createdAt: DateTime.now(),
    );
    final baseline = type == AlertType.percentChange
        ? resolveCurrentPrice(preview)
        : null;

    final alert = PriceAlert(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      metal: metal,
      karat: karat,
      currency: currency,
      side: currency == 'EGP' ? (side ?? PriceSide.sell) : null,
      type: type,
      condition: condition,
      targetValue: targetValue,
      baselinePrice: baseline,
      repeatAfterHours: repeatAfterHours,
      createdAt: DateTime.now(),
    );
    await ref.read(priceAlertsServiceProvider).save(alert);
    await _syncAlertToCloud(alert);
    _reload();
  }

  Future<void> deleteAlert(String id) async {
    await ref.read(priceAlertsServiceProvider).delete(id);
    await _deleteFromCloud(id);
    _reload();
  }

  Future<void> clearHistory() async {
    final service = ref.read(priceAlertsServiceProvider);
    final toClear = service
        .getAll()
        .where((a) => a.triggeredAt != null && !a.isSnoozed)
        .toList();
    if (toClear.isEmpty) return;

    for (final alert in toClear) {
      await service.delete(alert.id);
      await _deleteFromCloud(alert.id);
    }
    _reload();
  }

  Future<void> toggleAlert(String id, bool active) async {
    final alert = state.alerts.firstWhere((a) => a.id == id);
    final updated = active
        ? alert.copyWith(isActive: true, clearReactivate: true)
        : alert.copyWith(isActive: false, clearReactivate: true);
    await ref.read(priceAlertsServiceProvider).update(updated);
    await _syncAlertToCloud(updated);
    _reload();
  }

  Future<void> reactivateAlert(String id) async {
    final alert = state.alerts.firstWhere((a) => a.id == id);
    final baseline = alert.type == AlertType.percentChange
        ? resolveCurrentPrice(alert)
        : null;
    final updated = alert.copyWith(
      isActive: true,
      clearTrigger: true,
      clearReactivate: true,
      baselinePrice: baseline ?? alert.baselinePrice,
    );
    await ref.read(priceAlertsServiceProvider).update(updated);
    await _syncAlertToCloud(updated);
    _reload();
  }

  Future<void> _processDueReactivations() async {
    final service = ref.read(priceAlertsServiceProvider);
    final now = DateTime.now();
    var changed = false;

    for (final alert in service.getAll()) {
      if (alert.isActive) continue;
      final reactivateAt = alert.reactivateAt;
      if (reactivateAt == null || reactivateAt.isAfter(now)) continue;

      final baseline = alert.type == AlertType.percentChange
          ? resolveCurrentPrice(alert)
          : alert.baselinePrice;
      final updated = alert.copyWith(
        isActive: true,
        clearTrigger: true,
        clearReactivate: true,
        baselinePrice: baseline ?? alert.baselinePrice,
      );
      await service.update(updated);
      await _syncAlertToCloud(updated);
      changed = true;
    }

    if (changed) _reload();
  }

  double? resolveCurrentPrice(PriceAlert alert) {
    if (alert.isLocal) {
      final local = ref.read(localMarketPricesProvider);
      if (local == null) return null;
      final row = alert.metal == 'gold'
          ? local.goldKarat(alert.karat)
          : local.silverKarat(alert.karat);
      return row?.priceFor(alert.side ?? PriceSide.sell);
    }

    final global = ref.read(marketPricesControllerProvider).globalData ??
        ref.read(metalPriceApiProvider).getCachedPrices();
    if (global == null) return null;

    final ounce = alert.metal == 'gold'
        ? global.goldPriceIn(alert.currency)
        : global.silverPriceIn(alert.currency);
    if (ounce == null) return null;

    if (alert.metal == 'gold') {
      final purity = (int.tryParse(alert.karat) ?? 24) / 24;
      return (ounce / _ounceToGram) * purity;
    }
    return ounce / _ounceToGram;
  }

  double? resolveRolling24hPercent(PriceAlert alert) {
    if (alert.isLocal) {
      final local = ref.read(localMarketPricesProvider);
      if (local == null) return null;
      final row = alert.metal == 'gold'
          ? local.goldKarat(alert.karat)
          : local.silverKarat(alert.karat);
      return row?.changePercent;
    }

    final api = ref.read(metalPriceApiProvider);
    final global = ref.read(marketPricesControllerProvider).globalData ??
        api.getCachedPrices();
    if (global == null) return null;

    final currentOunce = alert.metal == 'gold'
        ? global.goldPriceIn(alert.currency)
        : global.silverPriceIn(alert.currency);
    if (currentOunce == null) return null;

    final delta = api.computeChange(
      current: currentOunce,
      previousPrice: (prev) => alert.metal == 'gold'
          ? prev.goldPriceIn(alert.currency)
          : prev.silverPriceIn(alert.currency),
    );
    return delta.changePercent;
  }

  bool _isTriggered(PriceAlert alert, double? current) {
    if (alert.isPercent24h) {
      final change = resolveRolling24hPercent(alert);
      if (change == null) return false;
      return switch (alert.condition) {
        AlertCondition.above => change >= alert.targetValue,
        AlertCondition.below => change <= -alert.targetValue,
      };
    }

    if (alert.type == AlertType.percentChange) {
      if (current == null) return false;
      final change = alert.changePercentFrom(current);
      if (change == null) return false;
      return switch (alert.condition) {
        AlertCondition.above => change >= alert.targetValue,
        AlertCondition.below => change <= -alert.targetValue,
      };
    }

    if (current == null) return false;
    return switch (alert.condition) {
      AlertCondition.above => current >= alert.targetValue,
      AlertCondition.below => current <= alert.targetValue,
    };
  }

  String _triggerMessage(PriceAlert alert, double? current) {
    if (alert.isPercent24h) {
      final change = resolveRolling24hPercent(alert) ?? 0;
      final sign = change >= 0 ? '+' : '';
      final price = current != null
          ? ' (${current.toStringAsFixed(2)} ${alert.currency}/g)'
          : '';
      return '${alert.label} — now $sign${change.toStringAsFixed(2)}%$price';
    }
    if (alert.type == AlertType.percentChange && current != null) {
      final change = alert.changePercentFrom(current) ?? 0;
      final sign = change >= 0 ? '+' : '';
      return '${alert.label} — now $sign${change.toStringAsFixed(2)}% '
          '(${current.toStringAsFixed(2)} ${alert.currency}/g)';
    }
    return '${alert.label} — now ${current?.toStringAsFixed(2) ?? '—'} ${alert.currency}/g';
  }

  Future<void> checkAgainstLatestPrices() async {
    await _processDueReactivations();

    final service = ref.read(priceAlertsServiceProvider);
    final active = service.getActive();
    if (active.isEmpty) return;

    final triggered = <String>[];

    for (final alert in active) {
      final current = resolveCurrentPrice(alert);
      if (!alert.isPercent24h && current == null) continue;
      if (!_isTriggered(alert, current)) continue;

      final now = DateTime.now();
      final updated = alert.copyWith(
        isActive: false,
        triggeredAt: now,
        triggeredPrice: current,
        reactivateAt: alert.autoRepeats
            ? now.add(Duration(hours: alert.repeatAfterHours!))
            : null,
      );
      await service.update(updated);
      await _syncAlertToCloud(updated);

      final message = _triggerMessage(alert, current);
      triggered.add(message);

      await AlertNotificationService.instance.showPriceAlert(
        title: 'GoldSignal price alert',
        body: message,
      );
    }

    if (triggered.isEmpty) return;

    _reload();
    state = state.copyWith(
      snackbarMessage: triggered.length == 1
          ? 'Price alert: ${triggered.first}'
          : '${triggered.length} price alerts triggered',
    );
  }
}

class AlertFormDefaults {
  final String currency;
  final String metal;
  final String karat;
  final PriceSide side;
  final double? currentPerGram;

  const AlertFormDefaults({
    required this.currency,
    required this.metal,
    required this.karat,
    required this.side,
    this.currentPerGram,
  });
}

/// Pre-fill data when opening the create sheet from a price card.
class AlertDraft {
  final String metal;
  final String karat;
  final String currency;
  final PriceSide? side;
  final double pricePerGram;

  const AlertDraft({
    required this.metal,
    required this.karat,
    required this.currency,
    this.side,
    required this.pricePerGram,
  });
}

final alertFormDefaultsProvider = Provider<AlertFormDefaults>((ref) {
  final currency = ref.watch(selectedCurrencyProvider);
  final isLocal = currency == 'EGP';
  final side = ref.watch(priceSideProvider);
  const metal = 'gold';
  final karat = isLocal ? '21' : '24';

  final current = ref.read(priceAlertsProvider.notifier).resolveCurrentPrice(
        PriceAlert(
          id: 'preview',
          metal: metal,
          karat: karat,
          currency: currency,
          side: isLocal ? side : null,
          condition: AlertCondition.above,
          targetValue: 0,
          createdAt: DateTime.now(),
        ),
      );

  return AlertFormDefaults(
    currency: currency,
    metal: metal,
    karat: karat,
    side: side,
    currentPerGram: current,
  );
});
