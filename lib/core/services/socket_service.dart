import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class SocketService {
  static const String wsUrl = 'wss://driver-api-dev.nutchaphut.dev/ws';
  WebSocketChannel? _channel;
  Timer? _mockTimer;
  Timer? _reconnectTimer;
  bool _isMockMode = false; // Set to true only for offline/demo testing

  final StreamController<Map<String, dynamic>> _controller =
      StreamController.broadcast();

  Stream<Map<String, dynamic>> get stream => _controller.stream;
  bool get isConnected => _channel != null || _isMockMode;

  Future<void> connect({bool mockMode = false}) async {
    _isMockMode = mockMode;

    if (_isMockMode) {
      debugPrint('[SocketService] Running in mock mode');
      _startMockBroadcasting();
      return;
    }

    if (_channel != null) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) return;

    try {
      final uri = Uri.parse('$wsUrl?token=$token');
      _channel = WebSocketChannel.connect(uri);

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
          _scheduleReconnect();
        },
        onDone: () {
          debugPrint('WebSocket Connection Closed');
          _scheduleReconnect();
        },
      );
    } catch (e) {
      debugPrint('Could not connect to WebSocket: $e');
      _scheduleReconnect();
    }
  }

  /// Sends a mock NEW_ORDER event – call this to simulate receiving an order
  void simulateNewOrder() {
    final mockOrderId = 'order_mock_${DateTime.now().millisecondsSinceEpoch}';
    _controller.add({
      'type': 'NEW_ORDER',
      'data': {
        'id': mockOrderId,
        'customer_id': 'cust_mock',
        'status': 'PLACED',
        'total_amount': 320.0,
        'food_total': 300.0,
        'delivery_fee': 20.0,
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
            'selected_modifiers': ['เผ็ดปกติ'],
          },
        ],
      }
    });
  }

  /// Sends a mock ORDER_STATUS_UPDATED event
  void simulateOrderStatusUpdate(String orderId, String status) {
    _controller.add({
      'type': 'ORDER_STATUS_UPDATED',
      'data': {
        'orderId': orderId,
        'status': status,
      }
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
  }
}

final socketService = SocketService();
