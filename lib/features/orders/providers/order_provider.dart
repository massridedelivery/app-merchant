import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/orders/data/order_repository.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:merchant_app/features/orders/models/order.dart';

class OrderState {
  final List<Order> preparing; // OrderStatus.inKitchen
  final List<Order> ready; // OrderStatus.readyForPickup
  final List<Order> delivering; // OrderStatus.withDriver
  final List<Order> history; // OrderStatus.finished
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
  int get preparingCount =>
      preparing.where((o) => o.status != OrderStatus.placed).length;

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
      newestIncomingOrder:
          clearNew ? null : (newestIncomingOrder ?? this.newestIncomingOrder),
    );
  }
}

class OrderNotifier extends StateNotifier<OrderState> {
  OrderNotifier(this._repository, this._socket) : super(const OrderState()) {
    _init();
  }

  final OrderRepository _repository;
  final SocketService _socket;
  StreamSubscription<Map<String, dynamic>>? _socketSub;

  /// The status each flat event implies. `driver_assigned` is the reason this
  /// map exists at all — the guide defines it without a `status` field, so the
  /// event name is the only signal.
  static const Map<String, String> _statusForEvent = {
    SocketEventType.orderAccepted: OrderStatus.restaurantAccepted,
    SocketEventType.orderRejected: OrderStatus.restaurantRejected,
    SocketEventType.orderPreparing: OrderStatus.preparing,
    SocketEventType.orderReady: OrderStatus.readyForPickup,
    SocketEventType.driverAssigned: OrderStatus.driverAssigned,
    SocketEventType.orderPickedUp: OrderStatus.driverPickedUp,
    SocketEventType.orderDelivered: OrderStatus.delivered,
    SocketEventType.orderCancelled: OrderStatus.cancelled,
  };

  void _init() {
    fetchOrders();
    fetchHistory();
    _subscribeToSocket();
  }

  void _subscribeToSocket() {
    _socketSub = _socket.stream.listen(handleSocketEvent);
  }

  /// Handles one server frame. Shapes are defined in section 6.2 of the API
  /// guide: `order_created` nests the whole order under `order`, every other
  /// event is flat and identifies the order by `order_id`.
  void handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type is! String) return;

    if (type == SocketEventType.orderCreated) {
      final payload = event['order'];
      if (payload is! Map<String, dynamic>) return;
      final order = Order.fromJson(payload);
      state = state.copyWith(
        preparing: [order, ...state.preparing],
        hasNewOrder: true,
        newestIncomingOrder: order,
      );
      return;
    }

    final impliedStatus = _statusForEvent[type];
    if (impliedStatus == null) return; // not an event this screen reacts to

    final orderId = event['order_id'];
    if (orderId is! String) return;

    // Trust the server's own status when it sends one.
    final status = event['status'];
    _applyStatus(orderId, status is String ? status : impliedStatus);
  }

  /// Moves the order into whichever bucket [status] belongs to, wherever it
  /// currently sits. Searching every bucket matters for the later half of the
  /// flow — an order already in `delivering` still has DELIVERED to come.
  void _applyStatus(String id, String status) {
    if (!mounted) return;

    Order? found;
    for (final bucket in [
      state.preparing,
      state.ready,
      state.delivering,
      state.history,
    ]) {
      final index = bucket.indexWhere((o) => o.id == id);
      if (index != -1) {
        found = bucket[index];
        break;
      }
    }
    if (found == null) return; // an order we never loaded

    final updated = found.copyWith(status: status);
    List<Order> without(List<Order> orders) =>
        orders.where((o) => o.id != id).toList();

    var preparing = without(state.preparing);
    var ready = without(state.ready);
    var delivering = without(state.delivering);
    var history = without(state.history);

    if (OrderStatus.inKitchen.contains(status)) {
      preparing = [updated, ...preparing];
    } else if (status == OrderStatus.readyForPickup) {
      ready = [updated, ...ready];
    } else if (OrderStatus.withDriver.contains(status)) {
      delivering = [updated, ...delivering];
    } else if (OrderStatus.finished.contains(status)) {
      history = [updated, ...history];
    } else {
      return; // unrecognised status: leave the order where it is
    }

    state = state.copyWith(
      preparing: preparing,
      ready: ready,
      delivering: delivering,
      history: history,
    );
  }

  Future<void> fetchOrders() async {
    state = state.copyWith(isLoading: true);
    try {
      final orders = await _repository.fetchPending();

      if (!mounted) return;
      state = state.copyWith(
        preparing: orders
            .where((o) => OrderStatus.inKitchen.contains(o.status))
            .toList(),
        ready: orders
            .where((o) => o.status == OrderStatus.readyForPickup)
            .toList(),
        delivering: orders
            .where((o) => OrderStatus.withDriver.contains(o.status))
            .toList(),
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchHistory() async {
    try {
      final orders = await _repository.fetchHistory();
      if (!mounted) return;
      state = state.copyWith(history: orders);
    } catch (_) {}
  }

  Future<bool> acceptOrder(String id) async {
    try {
      await _repository.accept(id);
      _applyStatus(id, OrderStatus.restaurantAccepted);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rejectOrder(String id) async {
    try {
      await _repository.reject(id);
      _applyStatus(id, OrderStatus.restaurantRejected);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markPreparing(String id) async {
    try {
      await _repository.markPreparing(id);
      _applyStatus(id, OrderStatus.preparing);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> markReady(String id) async {
    try {
      await _repository.markReady(id);
      _applyStatus(id, OrderStatus.readyForPickup);
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
    ref.watch(orderRepositoryProvider),
    ref.watch(socketServiceProvider),
  ),
);
