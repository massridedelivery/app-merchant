import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../network/api_client.dart';

/// Events the **restaurant** socket receives (SCRUM-53 §11, read from
/// `internal/ws` on main@2ac3bec).
///
/// `order_accepted`, `order_rejected`, `order_picked_up` and admin-initiated
/// `order_cancelled` go to the customer socket only — they are deliberately
/// absent here. The gap means READY_FOR_PICKUP -> DELIVERED cannot be followed
/// from the socket alone; reconcile with `GET /orders/pending`.
class SocketEventType {
  const SocketEventType._();

  /// A new order. Note the name: not `order_created` (`service.go:424`).
  static const String newFoodOrder = 'new_food_order';
  static const String orderPreparing = 'order_preparing';
  static const String orderReady = 'order_ready';
  static const String driverAssigned = 'driver_assigned';
  static const String orderDelivered = 'order_delivered';
  static const String orderCancelled = 'order_cancelled';
}

/// Connects to `{host}/ws?token=...`.
///
/// The server PINGs every 54s and closes if no PONG lands within 60s
/// (SCRUM-53 §11). That is protocol-level and `web_socket_channel` answers on
/// its own — there is deliberately no app-level heartbeat here.
///
/// Merchants only receive; every state change is an HTTP call.
class SocketService {
  /// Full WebSocket URL, injected at build time from `env/<flavor>.json` via
  /// `--dart-define-from-file`. The localhost default is for a bare
  /// `flutter run` with no env file.
  static const String wsUrl = String.fromEnvironment(
    'WS_URL',
    defaultValue: 'ws://localhost:8080/ws',
  );

  /// Optional so tests can build a bare service; the provider injects the
  /// app's real client.
  SocketService([ApiClient? api]) : _api = api ?? ApiClient();

  final ApiClient _api;

  WebSocketChannel? _channel;
  Timer? _mockTimer;
  Timer? _reconnectTimer;

  /// Consecutive failed attempts, used for the backoff delay. Reset the moment
  /// a connection is actually established.
  int _attempt = 0;

  /// Whether a token refresh has already been tried since the last successful
  /// connection, so a dead refresh token cannot spin the loop.
  bool _refreshTried = false;

  /// A connect() awaiting its handshake outlives dispose(), and so can a
  /// reconnect timer that fired first. Adding to a closed controller throws, so
  /// every emit goes through the guards below.
  bool _disposed = false;

  /// Doubles from [_baseReconnectDelay] and stops at [_maxReconnectDelay].
  /// SCRUM-53 §11 asks for backoff; a fixed retry hammers the host for as long
  /// as it is down, and with an expired token that is forever.
  static const Duration _baseReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(seconds: 60);

  @visibleForTesting
  Duration delayForAttempt(int attempt) {
    final ms = _baseReconnectDelay.inMilliseconds * (1 << attempt.clamp(0, 10));
    return ms >= _maxReconnectDelay.inMilliseconds
        ? _maxReconnectDelay
        : Duration(milliseconds: ms);
  }

  /// Mirrors [ApiClient.useMock] unless [connect] is told otherwise, so HTTP
  /// and the socket can never end up in different modes — a half-mocked app
  /// shows fake orders while real requests go out, which reads as "it works".
  bool _isMockMode = ApiClient.useMock;

  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  /// Emits true when the socket is live, false when it drops.
  ///
  /// Messages sent while disconnected are never queued or replayed
  /// (SCRUM-53 §11), so listeners must refetch on every reconnect rather than
  /// assume they missed nothing.
  final StreamController<bool> _connection = StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  Stream<bool> get connectionStatus => _connection.stream;
  bool get isConnected => _channel != null || _isMockMode;

  /// [mockMode] defaults to whatever the HTTP client is doing. Pass it
  /// explicitly only to force one transport for a test or a demo.
  Future<void> connect({bool? mockMode}) async {
    if (_disposed) return;
    _isMockMode = mockMode ?? ApiClient.useMock;

    if (_isMockMode) {
      debugPrint('[SocketService] mock mode — orders come from a local timer');
      _startMockBroadcasting();
      _emitConnection(true);
      return;
    }

    if (_channel != null) return;

    // Read through ApiClient rather than SharedPreferences directly, so the
    // storage key lives in exactly one place.
    final token = await _api.readToken();
    if (token == null) {
      // Previously a silent return: no signal, no retry, and since MainScreen
      // calls connect() once in initState the socket stayed dead for the whole
      // session.
      debugPrint('[SocketService] no access token yet — will retry');
      _emitConnection(false);
      _scheduleReconnect();
      return;
    }

    try {
      debugPrint('[SocketService] connecting to $wsUrl');
      final channel = WebSocketChannel.connect(
        Uri.parse('$wsUrl?token=$token'),
      );
      // `connect` is lazy — it returns before the handshake. Announcing the
      // connection here rather than after `ready` told listeners to reconcile
      // against a socket that might never come up.
      await channel.ready;

      _channel = channel;
      _attempt = 0;
      _refreshTried = false;
      _emitConnection(true);

      channel.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            _emitEvent(data as Map<String, dynamic>);
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _emitConnection(false);
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket Connection Closed');
          _emitConnection(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('[SocketService] handshake failed: $e');
      _channel = null;
      _emitConnection(false);
      await _retryAfterFailedHandshake();
    }
  }

  /// The token is checked at upgrade only (SCRUM-53 §11), so an expired one
  /// fails the handshake exactly like an outage — there is no 401 for the HTTP
  /// retry interceptor to see. Refresh once per connection cycle before falling
  /// back to plain backoff; without this the merchant's socket dies silently
  /// after the access token's 24h and no new-order alert ever arrives again.
  Future<void> _retryAfterFailedHandshake() async {
    if (!_refreshTried) {
      _refreshTried = true;
      if (await _api.refreshSession()) {
        debugPrint('[SocketService] token refreshed — reconnecting now');
        return connect(mockMode: _isMockMode);
      }
      // Refresh itself failed: the session is gone, so the app is about to be
      // sent back to login. Keep backing off rather than spinning.
      debugPrint('[SocketService] refresh failed — session is likely gone');
    }
    _scheduleReconnect();
  }

  /// Emits a `new_food_order` frame. The `order` payload is the narrower
  /// `FoodOrderWSResponse`: no `food_total`, `delivery_fee`, `payment_status`,
  /// `tier`, `driver_info` or `polyline` (SCRUM-53 §11).
  void simulateNewOrder() {
    final mockOrderId = 'order_mock_${DateTime.now().millisecondsSinceEpoch}';
    _emitEvent({
      'type': SocketEventType.newFoodOrder,
      'order': {
        'id': mockOrderId,
        'customer_id': 'cust_mock',
        'customer_name': 'คุณนิด',
        'customer_phone': '+66898887777',
        'status': 'PLACED',
        'total_amount': 320.0,
        'delivery_address': '888 ถนนลาดพร้าว กรุงเทพฯ',
        'payment_method': 'grab_pay',
        'original_eta_min': 30,
        'placed_at': DateTime.now().toIso8601String(),
        'items': [
          {
            'id': 'oi_mock_1',
            'menu_item_id': 'item_1',
            'name': 'แกงมัสมั่นไก่',
            'quantity': 2,
            'unit_price': 150.0,
            'subtotal': 300.0,
            'selected_modifiers': [
              {'id': 'mod_mock_1', 'name': 'เผ็ดปกติ', 'price': 0.0},
            ],
          },
        ],
      },
    });
  }

  /// Emits one of the flat status frames (`order_accepted`, `order_ready`,
  /// `driver_assigned`, …). [status] is omitted for `driver_assigned`, which
  /// the guide defines without one.
  void simulateStatusEvent(
    String type,
    String orderId, {
    String? status,
    String? driverId,
    String? reason,
  }) {
    _emitEvent({
      'type': type,
      'order_id': orderId,
      'status': ?status,
      'driver_id': ?driverId,
      'reason': ?reason,
    });
  }

  void _startMockBroadcasting() {
    _mockTimer?.cancel();
    // Send a new order after 20 seconds for demo, then every 60 seconds
    _mockTimer = Timer(const Duration(seconds: 20), () {
      simulateNewOrder();
      // Repeat every 60s
      _mockTimer = Timer.periodic(const Duration(seconds: 60), (_) {
        simulateNewOrder();
      });
    });
  }

  void _emitConnection(bool connected) {
    if (_disposed) return;
    _connection.add(connected);
  }

  void _emitEvent(Map<String, dynamic> event) {
    if (_disposed) return;
    _controller.add(event);
  }

  void _scheduleReconnect() {
    if (_disposed) return;
    _channel = null;
    _reconnectTimer?.cancel();
    final delay = delayForAttempt(_attempt);
    _attempt++;
    debugPrint(
      '[SocketService] reconnecting in ${delay.inSeconds}s '
      '(attempt $_attempt)',
    );
    _reconnectTimer = Timer(delay, () => connect(mockMode: _isMockMode));
  }

  void sendEvent(Map<String, dynamic> event) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(event));
    }
  }

  void disconnect() {
    _mockTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _attempt = 0;
    _refreshTried = false;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _controller.close();
    _connection.close();
  }
}

/// The app's realtime connection. Lives for as long as the [ProviderScope], and
/// is torn down with it. Override in tests with
/// `socketServiceProvider.overrideWithValue(fake)`.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService(ref.watch(apiClientProvider));
  ref.onDispose(service.dispose);
  return service;
});
