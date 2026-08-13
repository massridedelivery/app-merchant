import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';

/// Device registration for FCM (SCRUM-53 §12).
///
/// The WebSocket only runs while the app is foregrounded, so a backgrounded
/// merchant hears about a new order through push or not at all. Register after
/// every login and on every FCM token refresh; unregister on logout.
///
/// The push payload for a new order carries `data.type = new_food_order` and
/// `data.order_id` to deep-link with. Status-change pushes carry title and body
/// only — no `data` — so those can only open the order list.
///
/// **Not wired to a real FCM token yet.** Adding firebase_messaging needs the
/// project's Firebase config (google-services.json / GoogleService-Info.plist),
/// which is not in this repo; until then nothing calls these with a live token.
class NotificationRepository {
  NotificationRepository(this._api);

  final ApiClient _api;

  Future<void> registerDevice({
    required String token,
    required String deviceType,
  }) =>
      _api.dio.post('/api/notifications/register-device', data: {
        'token': token,
        // Server lowercases it; ios | android | web.
        'device_type': deviceType.toLowerCase(),
      });

  Future<void> unregisterDevice({
    required String token,
    required String deviceType,
  }) =>
      _api.dio.post('/api/notifications/unregister-device', data: {
        'token': token,
        'device_type': deviceType.toLowerCase(),
      });
}

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(ref.watch(apiClientProvider)),
);
