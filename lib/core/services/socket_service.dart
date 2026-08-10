import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
  WebSocketChannel? _channel;
  Timer? _mockTimer;
  Timer? _reconnectTimer;
  bool _isMockMode = false; // Set to true only for offline/demo testing

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

  Future<void> connect({bool mockMode = false}) async {
    _isMockMode = mockMode;

    if (_isMockMode) {
      debugPrint('[SocketService] Running in mock mode');
      _startMockBroadcasting();
      _connection.add(true);
      return;
    }

    if (_channel != null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    try {
      final uri = Uri.parse('$wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);
      _connection.add(true);

      _channel!.stream.listen(
        (message) {
          try {
            final data = jsonDecode(message as String);
            _controller.add(data as Map<String, dynamic>);
          } catch (e) {
            debugPrint('Error parsing WebSocket message: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket Error: $error');
          _connection.add(false);
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket Connection Closed');
          _connection.add(false);
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('Could not connect to WebSocket: $e');
      _scheduleReconnect();
    }
  }

  /// Emits a `new_food_order` frame. The `order` payload is the narrower
  /// `FoodOrderWSResponse`: no `food_total`, `delivery_fee`, `payment_status`,
  /// `tier`, `driver_info` or `polyline` (SCRUM-53 §11).
  void simulateNewOrder() {
    final mockOrderId = 'order_mock_${DateTime.now().millisecondsSinceEpoch}';
    _controller.add({
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
      }
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
    _controller.add({
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

  void _scheduleReconnect() {
    _channel = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () {
      connect(mockMode: _isMockMode);
    });
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
  }

  void dispose() {
    disconnect();
    _controller.close();
    _connection.close();
  }
}

/// The app's realtime connection. Lives for as long as the [ProviderScope], and
/// is torn down with it. Override in tests with
/// `socketServiceProvider.overrideWithValue(fake)`.
final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});
