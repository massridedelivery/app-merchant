import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:merchant_app/core/network/api_client.dart';

/// Backend device-token registration for push notifications.
///
/// Endpoints (see docs/MERCHANT_API_INTEGRATION.md §6):
///   POST /api/notifications/register-device   { device_type, token }
///   POST /api/notifications/unregister-device  { token }
///   GET  /api/notifications
///   PATCH /api/notifications/{id}/read
///
/// This class only speaks to the backend. Acquiring the actual FCM token is
/// delegated to a [PushTokenProvider] so the app compiles and runs before
/// Firebase native config (google-services.json / GoogleService-Info.plist) is
/// added. Wire a real provider once Firebase Messaging is set up — see
/// `PushTokenProvider` below.
class NotificationService {
  NotificationService({PushTokenProvider? tokenProvider})
      : _tokenProvider = tokenProvider ?? const NoopPushTokenProvider();

  final PushTokenProvider _tokenProvider;
  String? _registeredToken;

  String get _deviceType {
    try {
      if (Platform.isIOS) return 'ios';
      if (Platform.isAndroid) return 'android';
    } catch (_) {}
    return 'unknown';
  }

  /// Obtain the FCM token and register it with the backend. Safe to call after
  /// every successful login — a no-op if no token is available yet.
  Future<void> registerCurrentDevice() async {
    final token = await _tokenProvider.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('[NotificationService] no FCM token yet — skipping register');
      return;
    }
    try {
      await apiClient.dio.post(
        '${ApiClient.host}/api/notifications/register-device',
        data: {'device_type': _deviceType, 'token': token},
      );
      _registeredToken = token;
      debugPrint('[NotificationService] device registered for push');
    } catch (e) {
      debugPrint('[NotificationService] register-device failed: $e');
    }
  }

  /// Unregister on logout so the device stops receiving this account's pushes.
  Future<void> unregisterCurrentDevice() async {
    final token = _registeredToken ?? await _tokenProvider.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await apiClient.dio.post(
        '${ApiClient.host}/api/notifications/unregister-device',
        data: {'token': token},
      );
      _registeredToken = null;
    } catch (e) {
      debugPrint('[NotificationService] unregister-device failed: $e');
    }
  }

  /// In-app notification inbox.
  Future<List<Map<String, dynamic>>> listNotifications() async {
    try {
      final res = await apiClient.dio.get('${ApiClient.host}/api/notifications');
      return (res.data as List? ?? [])
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markRead(String id) async {
    try {
      await apiClient.dio.patch('${ApiClient.host}/api/notifications/$id/read');
    } catch (_) {}
  }
}

/// Supplies the FCM registration token. Swap the default for a real
/// implementation once Firebase Messaging is configured.
abstract class PushTokenProvider {
  Future<String?> getToken();
}

/// Default: no Firebase configured yet → no token. Keeps the app runnable.
class NoopPushTokenProvider implements PushTokenProvider {
  const NoopPushTokenProvider();
  @override
  Future<String?> getToken() async => null;
}

// ── How to enable real FCM (follow-up, needs native Firebase setup) ──────────
//
// 1. Add to pubspec.yaml:
//      firebase_core: ^3.x
//      firebase_messaging: ^15.x
//    then `flutter pub get`.
// 2. Add native config:
//      android/app/google-services.json
//      ios/Runner/GoogleService-Info.plist  (+ APNs key in Firebase console)
// 3. In main() before runApp:  await Firebase.initializeApp();
// 4. Implement PushTokenProvider:
//
//    class FirebasePushTokenProvider implements PushTokenProvider {
//      @override
//      Future<String?> getToken() async {
//        await FirebaseMessaging.instance.requestPermission();
//        return FirebaseMessaging.instance.getToken();
//      }
//    }
//
// 5. Construct the provider once (see `notificationServiceProvider`) with
//    NotificationService(tokenProvider: FirebasePushTokenProvider()).
// 6. Handle FirebaseMessaging.onMessage / onMessageOpenedApp to route taps.
//    Per the driver-app pattern the push carries no order data — only a
//    route/deeplink — so on tap just navigate; the order is loaded via WS/REST.

/// Global instance. Replace the tokenProvider argument once Firebase is wired.
final notificationService = NotificationService();
