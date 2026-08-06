import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:merchant_app/features/orders/models/order.dart';

class OrderState {
  final List<Order> preparing;   // PLACED + RESTAURANT_ACCEPTED + PREPARING
  final List<Order> ready;       // READY_FOR_PICKUP
  final List<Order> delivering;  // DELIVERY (driver picked up)
  final List<Order> history;     // COMPLETED + CANCELLED
  final bool isLoading;
  final bool hasNewOrder;
  final Order? newestIncomingOrder;

  const OrderState({
    this.preparing = const [],
    this.ready = const [],
    this.delivering = const [],
    this.history = const [],
    this.isLoading = true,
    this.hasNewOrder = false,
    this.newestIncomingOrder,
  });

  List<Order> get allActive => [...preparing, ...ready, ...delivering];
  int get preparingCount => preparing.where((o) => o.status != 'PLACED').length;

  OrderState copyWith({
    List<Order>? preparing,
    List<Order>? ready,
    List<Order>? delivering,
    List<Order>? history,
    bool? isLoading,
    bool? hasNewOrder,
    Order? newestIncomingOrder,
    bool clearNew = false,
  }) {
    return OrderState(
      preparing: preparing ?? this.preparing,
      ready: ready ?? this.ready,
      delivering: delivering ?? this.delivering,
      history: history ?? this.history,
      isLoading: isLoading ?? this.isLoading,
      hasNewOrder: clearNew ? false : (hasNewOrder ?? this.hasNewOrder),
      newestIncomingOrder: clearNew ? null : (newestIncomingOrder ?? this.newestIncomingOrder),
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier(this._api, this._socket) : super(const OrderState()) {
    _init();
  }

  final ApiClient _api;
  final SocketService _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  void _init() {
    fetchOrders();
    fetchHistory();
    _subscribeToSocket();
  }

  void _subscribeToSocket() {
    _socketSub = _socket.stream.listen((event) {
      final type = event['type'];
      final data = event['data'] as Map<String, dynamic>?;
      if (data == null) return;

      if (type == 'NEW_ORDER') {
        final order = Order.fromJson(data);
        state = state.copyWith(
          preparing: [order, ...state.preparing],
          hasNewOrder: true,
          newestIncomingOrder: order,
        );
      } else if (type == 'ORDER_STATUS_UPDATED') {
        final orderId = data['orderId'] as String?;
        final newStatus = data['status'] as String?;
        if (orderId != null && newStatus != null) {
          _handleStatusUpdate(orderId, newStatus);
        }
      }
    });
  }

  void _handleStatusUpdate(String orderId, String newStatus) {
    _updateOrderInAll(orderId, newStatus);
    // re-bucket if needed
    _rebucketOrder(orderId, newStatus);
  }

  void _updateOrderInAll(String id, String status) {
    Order? updated;
    final newPreparing = state.preparing.map((o) {
      if (o.id == id) {
        updated = o.copyWith(status: status);
        return updated!;
      }
      return o;
    }).toList();
    final newReady = state.ready.map((o) {
      if (o.id == id) {
        updated = o.copyWith(status: status);
        return updated!;
      }
      return o;
    }).toList();
    state = state.copyWith(preparing: newPreparing, ready: newReady);
  }

  void _rebucketOrder(String id, String status) {
    Order? found;
    List<Order> newPreparing = state.preparing;
    List<Order> newReady = state.ready;
    List<Order> newDelivering = state.delivering;
    List<Order> newHistory = state.history;

    // Find in preparing
    final pIdx = state.preparing.indexWhere((o) => o.id == id);
    if (pIdx != -1) found = state.preparing[pIdx].copyWith(status: status);

    // Find in ready
    if (found == null) {
      final rIdx = state.ready.indexWhere((o) => o.id == id);
      if (rIdx != -1) found = state.ready[rIdx].copyWith(status: status);
    }

    if (found == null) return;

    // Remove from all lists
    newPreparing = newPreparing.where((o) => o.id != id).toList();
    newReady = newReady.where((o) => o.id != id).toList();

    // Add to correct bucket
    switch (status) {
      case 'PLACED':
      case 'RESTAURANT_ACCEPTED':
      case 'PREPARING':
        newPreparing = [found, ...newPreparing];
        break;
      case 'READY_FOR_PICKUP':
        newReady = [found, ...newReady];
        break;
      case 'DELIVERY':
        newDelivering = [found, ...newDelivering];
        break;
      case 'COMPLETED':
      case 'RESTAURANT_REJECTED':
      case 'CANCELLED':
        newHistory = [found, ...newHistory];
        break;
    }

    state = state.copyWith(
      preparing: newPreparing,
      ready: newReady,
      delivering: newDelivering,
      history: newHistory,
    );
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _api.dio.get(
          '/restaurant/orders/pending?status=PLACED,RESTAURANT_ACCEPTED,PREPARING,READY_FOR_PICKUP');
      final orders =
          (response.data as List).map((j) => Order.fromJson(j as Map<String, dynamic>)).toList();

      final preparing = orders
          .where((o) => ['PLACED', 'RESTAURANT_ACCEPTED', 'PREPARING'].contains(o.status))
          .toList();
      final ready =
          orders.where((o) => o.status == 'READY_FOR_PICKUP').toList();

      state = state.copyWith(
        preparing: preparing,
        ready: ready,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchHistory() async {
    try {
      final response = await _api.dio.get('/restaurant/orders/history');
      final orders = (response.data as List)
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(history: orders);
    } catch (_) {}
  }

  Future<bool> acceptOrder(String id) async {
    try {
      await _api.dio.post('/restaurant/orders/$id/accept');
      _updateOrderInAll(id, 'RESTAURANT_ACCEPTED');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectOrder(String id) async {
    try {
      await _api.dio.post('/restaurant/orders/$id/reject');
      _rebucketOrder(id, 'RESTAURANT_REJECTED');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markPreparing(String id) async {
    try {
      await _api.dio.post('/restaurant/orders/$id/preparing');
      _updateOrderInAll(id, 'PREPARING');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markReady(String id) async {
    try {
      await _api.dio.post('/restaurant/orders/$id/ready');
      _rebucketOrder(id, 'READY_FOR_PICKUP');
      return true;
    } catch (_) {
      return false;
    }
  }

  void dismissNewOrderNotification() {
    state = state.copyWith(clearNew: true);
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    super.dispose();
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>(
  (ref) => OrderNotifier(
    ref.watch(apiClientProvider),
    ref.watch(socketServiceProvider),
  ),
);
