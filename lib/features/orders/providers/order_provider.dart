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
  OrderNotifier() : super(const OrderState()) {
    _init();
  }

  void _init() {
    fetchOrders();
    fetchHistory();
    _subscribeToSocket();
  }

  // Real backend WebSocket contract (see docs/MERCHANT_API_INTEGRATION.md §4).
  // Payload is FLAT: { type, order_id, status, order?, driver_id?, reason? }.
  void _subscribeToSocket() {
    socketService.stream.listen((event) {
      final type = event['type'] as String?;
      if (type == null) return;

      switch (type) {
        case 'order_created':
          final orderJson = event['order'] as Map<String, dynamic>?;
          if (orderJson == null) return;
          final order = Order.fromJson(orderJson);
          if (state.allActive.any((o) => o.id == order.id)) return; // de-dupe
          state = state.copyWith(
            preparing: [order, ...state.preparing],
            hasNewOrder: true,
            newestIncomingOrder: order,
          );
          break;

        case 'order_accepted': // RESTAURANT_ACCEPTED
        case 'order_preparing': // PREPARING
        case 'order_ready': // READY_FOR_PICKUP
        case 'order_picked_up': // DRIVER_PICKED_UP
        case 'order_delivered': // DELIVERED
        case 'order_rejected': // RESTAURANT_REJECTED
        case 'order_cancelled': // CANCELLED
          final orderId = event['order_id'] as String?;
          final newStatus = event['status'] as String?;
          if (orderId != null && newStatus != null) {
            _handleStatusUpdate(orderId, newStatus);
          }
          break;

        case 'driver_assigned':
          // A rider was matched. Status stays READY_FOR_PICKUP; the order keeps
          // sitting in the Ready bucket until `order_picked_up` arrives.
          // (driver_id is available at event['driver_id'] once the model stores it.)
          break;
      }
    });
  }

  void _handleStatusUpdate(String orderId, String newStatus) {
    _updateOrderInAll(orderId, newStatus);
    // re-bucket if needed
    _rebucketOrder(orderId, newStatus);
  }

  void _updateOrderInAll(String id, String status) {
    Order mapUpdate(Order o) => o.id == id ? o.copyWith(status: status) : o;
    state = state.copyWith(
      preparing: state.preparing.map(mapUpdate).toList(),
      ready: state.ready.map(mapUpdate).toList(),
      delivering: state.delivering.map(mapUpdate).toList(),
    );
  }

  void _rebucketOrder(String id, String status) {
    // Locate the order in any active bucket.
    Order? found;
    for (final o in [...state.preparing, ...state.ready, ...state.delivering]) {
      if (o.id == id) {
        found = o.copyWith(status: status);
        break;
      }
    }
    if (found == null) return;

    // Remove from every active list, then drop into the bucket for `status`.
    List<Order> newPreparing = state.preparing.where((o) => o.id != id).toList();
    List<Order> newReady = state.ready.where((o) => o.id != id).toList();
    List<Order> newDelivering = state.delivering.where((o) => o.id != id).toList();
    List<Order> newHistory = state.history;

    switch (status) {
      case 'PLACED':
      case 'RESTAURANT_ACCEPTED':
      case 'PREPARING':
        newPreparing = [found, ...newPreparing];
        break;
      case 'READY_FOR_PICKUP':
      case 'DRIVER_ASSIGNED':
        newReady = [found, ...newReady];
        break;
      case 'DRIVER_PICKED_UP':
        newDelivering = [found, ...newDelivering];
        break;
      case 'DELIVERED':
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
      final response = await apiClient.dio.get(
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
      final response = await apiClient.dio.get('/restaurant/orders/history');
      final orders = (response.data as List)
          .map((j) => Order.fromJson(j as Map<String, dynamic>))
          .toList();
      state = state.copyWith(history: orders);
    } catch (_) {}
  }

  Future<bool> acceptOrder(String id) async {
    try {
      await apiClient.dio.post('/restaurant/orders/$id/accept');
      _updateOrderInAll(id, 'RESTAURANT_ACCEPTED');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectOrder(String id) async {
    try {
      await apiClient.dio.post('/restaurant/orders/$id/reject');
      _rebucketOrder(id, 'RESTAURANT_REJECTED');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markPreparing(String id) async {
    try {
      await apiClient.dio.post('/restaurant/orders/$id/preparing');
      _updateOrderInAll(id, 'PREPARING');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markReady(String id) async {
    try {
      await apiClient.dio.post('/restaurant/orders/$id/ready');
      _rebucketOrder(id, 'READY_FOR_PICKUP');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Adjust prep time and/or flag out-of-stock items on an order.
  /// PUT /api/food/restaurant/orders/{id}/ops
  Future<bool> updateOps(
    String id, {
    int? prepTimeAdjustmentMin,
    List<String> oosOrderItemIds = const [],
  }) async {
    try {
      await apiClient.dio.put('/restaurant/orders/$id/ops', data: {
        if (prepTimeAdjustmentMin != null)
          'prep_time_adjustment_min': prepTimeAdjustmentMin,
        'oos_order_item_ids': oosOrderItemIds,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  void dismissNewOrderNotification() {
    state = state.copyWith(clearNew: true);
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>(
  (ref) => OrderNotifier(),
);
