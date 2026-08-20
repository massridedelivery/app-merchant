import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:merchant_app/core/router/app_router_holder.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

/// Requests notification permission and returns the resulting iOS/Firebase
/// [AuthorizationStatus] name.
///
/// On Android 13+ (API 33+), POST_NOTIFICATIONS is a runtime permission that
/// `FirebaseMessaging.requestPermission()` alone does not reliably prompt for;
/// permission_handler's `request()` is the version that actually shows the
/// system dialog when the permission has never been decided.
Future<String> requestNotificationPermission() async {
  if (defaultTargetPlatform == TargetPlatform.android) {
    final status = await ph.Permission.notification.status;
    if (!status.isGranted) {
      await ph.Permission.notification.request();
    }
  }
  final settings = await FirebaseMessaging.instance.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  return settings.authorizationStatus.name;
}

/// Default channel for ordinary notifications (system-drawn while backgrounded).
/// The id MUST match `default_notification_channel_id` in AndroidManifest.xml.
const AndroidNotificationChannel _defaultChannel = AndroidNotificationChannel(
  'high_importance_channel',
  'การแจ้งเตือน',
  description: 'ใช้สำหรับการแจ้งเตือนทั่วไป',
  importance: Importance.high,
);

/// Loud channel for new orders — custom sound (res/raw/order_alert), max
/// importance, vibration, alarm audio, so the merchant notices like Grab/LINEMAN.
/// The id is versioned because a channel's sound is immutable once created:
/// bump `_vN` to roll out a new sound. MUST match the backend (SCRUM-72).
const AndroidNotificationChannel _orderChannel = AndroidNotificationChannel(
  'order_offer_channel_v1',
  'ออเดอร์ใหม่',
  description: 'แจ้งเตือนเมื่อมีออเดอร์เข้าใหม่ (เสียงดังพิเศษ)',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('order_alert'),
  playSound: true,
  enableVibration: true,
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

/// A new-order push. `data.type` is the contract key agreed with the backend
/// (SCRUM-72): `new_food_order`.
bool _isNewOrder(RemoteMessage message) =>
    message.data['type'] == 'new_food_order';

/// A payout push — the money for a withdrawal has been transferred (or the
/// request was updated). `data.type` is the contract key agreed with the
/// backend (SCRUM-60): one of `withdrawal_completed` / `withdrawal_paid` /
/// `withdrawal_rejected` / `withdrawal_update`. Tapping it lands on the
/// Finance tab so the merchant sees the updated balance and history.
bool _isWithdrawal(RemoteMessage message) {
  final type = message.data['type'];
  return type is String && type.startsWith('withdrawal');
}

/// Where a tapped notification should land. Order pushes open the app home
/// (orders live there); everything else opens home too.
String _routeFor(RemoteMessage message) {
  final route = message.data['route'];
  if (route is String && route.startsWith('/')) return route;
  return '/';
}

/// Handles messages delivered while the app is backgrounded or terminated.
///
/// MUST be a top-level/static function so the AOT tree-shaker keeps it; runs in
/// its own isolate. The backend sends a `notification` block + sets the Android
/// channel_id / APNs sound on the FCM message, so the OS draws the (loud) push
/// itself — this handler only runs for side effects, never draws a
/// notification (or the merchant would see it twice).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('FCM(bg): id=${message.messageId} data=${message.data}');
}

/// Foreground / tap / launch message handling + the local notification used to
/// display foreground order alerts on Android. Token registration is handled
/// separately by [PushTokenRegistrar].
class PushNotificationService {
  PushNotificationService._();

  static final PushNotificationService instance = PushNotificationService._();

  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final messaging = FirebaseMessaging.instance;
    await _initLocalNotifications();

    // iOS: present alert/badge/sound even while foregrounded (no-op on Android).
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_onForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleTap(initial));
    }
  }

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // firebase_messaging handles iOS permission prompts, so don't re-request.
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _localNotifications.initialize(
      const InitializationSettings(android: androidInit, iOS: darwinInit),
      onDidReceiveNotificationResponse: (response) {
        final route = response.payload;
        if (route != null && route.isNotEmpty) _navigateTo(route);
      },
    );

    final android =
        _localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(_defaultChannel);
    await android?.createNotificationChannel(_orderChannel);
  }

  void _onForegroundMessage(RemoteMessage message) {
    debugPrint('FCM(fg): id=${message.messageId} data=${message.data}');
    // iOS presents foreground notifications itself (incl. the loud sound set in
    // apns.aps.sound); drawing one too would double the alert. Android does not
    // display notification messages while foregrounded, so draw one here.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    final notification = message.notification;
    final isOrder = _isNewOrder(message);
    final title = notification?.title ??
        (isOrder ? 'ออเดอร์ใหม่' : 'การแจ้งเตือน');
    final body = notification?.body ??
        (isOrder ? 'มีออเดอร์เข้ามาใหม่ แตะเพื่อดูรายละเอียด' : '');

    final channel = isOrder ? _orderChannel : _defaultChannel;
    _localNotifications.show(
      (message.messageId?.hashCode) ?? notification.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          icon: '@mipmap/ic_launcher',
          importance: isOrder ? Importance.max : Importance.high,
          priority: isOrder ? Priority.max : Priority.high,
          category: isOrder ? AndroidNotificationCategory.call : null,
          fullScreenIntent: isOrder,
          sound: isOrder
              ? const RawResourceAndroidNotificationSound('order_alert')
              : null,
          playSound: true,
          audioAttributesUsage: isOrder
              ? AudioAttributesUsage.alarm
              : AudioAttributesUsage.notification,
        ),
      ),
      payload: _routeFor(message),
    );
  }

  void _handleTap(RemoteMessage message) {
    debugPrint('FCM(tap): id=${message.messageId} data=${message.data}');
    if (_isNewOrder(message)) {
      // Land on the Orders tab (index 1 in the main screen) and remember the
      // order id for the list to highlight/open.
      pendingOrderId = message.data['order_id'] as String?;
      pendingTabIndex = 1;
      appRouter?.go('/');
      return;
    }
    if (_isWithdrawal(message)) {
      // Land on the Finance tab (index 3) so the updated balance + withdrawal
      // history are front and centre.
      pendingTabIndex = 3;
      appRouter?.go('/');
      return;
    }
    _navigateTo(_routeFor(message));
  }

  /// Clears delivered notifications — also stops the order-alert sound if it is
  /// still ringing. Call when the merchant acts on the order.
  Future<void> cancelOrderAlerts() async {
    try {
      await _localNotifications.cancelAll();
    } catch (_) {}
  }

  void _navigateTo(String route) {
    if (route.startsWith('/')) appRouter?.go(route);
  }
}
