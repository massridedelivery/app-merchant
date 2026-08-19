import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/notifications/notification_repository.dart';
import 'package:merchant_app/core/notifications/push_notification_service.dart';

/// Keeps the backend's FCM device token in sync with the signed-in merchant.
///
/// Driven by auth state (see `main.dart`'s `ref.listen(authProvider)`):
/// [onAuthenticated] after login and on token refresh, [onLoggedOut] on logout.
/// Registration re-binds the token to whoever is signed in, so a different
/// merchant on the same device gets their own pushes.
class PushTokenRegistrar {
  PushTokenRegistrar(this._repo);

  final NotificationRepository _repo;

  StreamSubscription<String>? _refreshSub;
  bool _registering = false;
  String? _registeredToken;

  String get _deviceType =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  /// Acquire the FCM token and register it for the current merchant. Also keeps
  /// registration in sync when FCM rotates the token.
  Future<void> onAuthenticated() async {
    if (_registering) return;
    _registering = true;
    try {
      final token = await _acquireToken();
      if (token == null || token.isEmpty) return;
      if (kDebugMode) debugPrint('FCM_TOKEN: $token');
      await _send(token);
      _refreshSub ??= FirebaseMessaging.instance.onTokenRefresh
          .listen((t) => unawaited(_sendQuietly(t)));
    } catch (e) {
      debugPrint('FCM: register error: $e');
    } finally {
      _registering = false;
    }
  }

  /// Unregister the current token and stop mirroring refreshes.
  Future<void> onLoggedOut() async {
    final token = _registeredToken;
    _refreshSub?.cancel();
    _refreshSub = null;
    _registeredToken = null;
    if (token == null) return;
    try {
      await _repo.unregisterDevice(token: token, deviceType: _deviceType);
    } catch (e) {
      debugPrint('FCM: unregister error: $e');
    }
  }

  Future<void> _sendQuietly(String token) async {
    try {
      await _send(token);
    } catch (e) {
      debugPrint('FCM: refresh register failed: $e');
    }
  }

  Future<void> _send(String token) async {
    if (token == _registeredToken) return; // unchanged; skip round trip
    await _repo.registerDevice(token: token, deviceType: _deviceType);
    _registeredToken = token;
    debugPrint('FCM: device registered');
  }

  /// Permission prompt, then the platform token (waiting for the iOS APNs token
  /// which is momentarily null on a cold start). Returns null when push can't
  /// be set up (denied, no APNs token, no token vended).
  Future<String?> _acquireToken() async {
    final messaging = FirebaseMessaging.instance;

    final status = await requestNotificationPermission();
    if (status == AuthorizationStatus.denied.name) {
      debugPrint('FCM: notification permission denied');
      return null;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      String? apns;
      for (var i = 0; i < 5 && apns == null; i++) {
        apns = await messaging.getAPNSToken();
        if (apns == null) await Future.delayed(const Duration(seconds: 1));
      }
      if (apns == null) {
        debugPrint('FCM: APNs token unavailable (Simulator?), skip');
        return null;
      }
    }

    final token = await messaging.getToken();
    if (token == null || token.isEmpty) {
      debugPrint('FCM: token unavailable, skip register');
      return null;
    }
    return token;
  }
}

final pushTokenRegistrarProvider = Provider<PushTokenRegistrar>(
  (ref) => PushTokenRegistrar(ref.watch(notificationRepositoryProvider)),
);
