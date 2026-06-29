import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../../firebase_options.dart';
import '../analytics/analytics_service.dart';
import '../firebase/firestore_price_alerts_service.dart';
import 'alert_notification_service.dart';

typedef PriceAlertPushCallback = void Function();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AlertNotificationService.instance.initialize();

  final notification = message.notification;
  if (notification == null) return;

  await AlertNotificationService.instance.showPriceAlert(
    title: notification.title ?? 'GoldSignal price alert',
    body: notification.body ?? '',
  );
}

class PushMessagingService {
  static final PushMessagingService instance = PushMessagingService._();
  PushMessagingService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirestorePriceAlertsService _firestoreAlerts =
      FirestorePriceAlertsService();
  bool _initialized = false;
  PriceAlertPushCallback? onPriceAlertReceived;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpenedMessage);

    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      _handleOpenedMessage(initial);
    }

    _messaging.onTokenRefresh.listen(_persistToken);

    _initialized = true;
    await refreshToken();
  }

  void _handleForegroundMessage(RemoteMessage message) {
    final notification = message.notification;
    if (notification == null) return;

    AlertNotificationService.instance.showPriceAlert(
      title: notification.title ?? 'GoldSignal',
      body: notification.body ?? '',
    );

    if (message.data['type'] == 'price_alert') {
      onPriceAlertReceived?.call();
    }
  }

  void _handleOpenedMessage(RemoteMessage message) {
    // A tap (or cold-launch from a notification) is the bottom of the funnel.
    // Logged for every known push type: price_alert, daily_digest, re_engagement.
    final type = message.data['type'];
    if (type is String && type.isNotEmpty) {
      AnalyticsService.instance.logNotificationOpened(type);
    }
    if (type == 'price_alert') {
      onPriceAlertReceived?.call();
    }
  }

  Future<void> refreshToken() async {
    if (kIsWeb) return;

    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await _messaging.getToken();
      if (token != null) await _persistToken(token);
    } catch (_) {}
  }

  Future<void> _persistToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _firestoreAlerts.saveFcmToken(uid, token);
    } catch (_) {}
  }
}
