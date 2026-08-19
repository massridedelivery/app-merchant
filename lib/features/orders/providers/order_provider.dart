import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/orders/data/order_repository.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:merchant_app/features/orders/models/order.dart';
import 'package:merchant_app/core/errors/app_failure.dart';

class OrderState {
  final List<Order> preparing; // OrderStatus.inKitchen
  final List<Order> ready; // OrderStatus.readyForPickup
  final List<Order> delivering; // OrderStatus.withDriver
  final List<Order> history; // OrderStatus.finished
  final bool historyHasMore;
  final bool isLoading;
  final bool hasNewOrder;
  final Order? newestIncomingOrder;

  const OrderState({
    this.preparing = const [],
    this.ready = const [],
    this.delivering = const [],
    this.history = const [],
    this.historyHasMore = false,
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
    bool? historyHasMore,
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
      historyHasMore: historyHasMore ?? this.historyHasMore,
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
  StreamSubscription<bool>? _connectionSub;
  Timer? _reconcileTimer;

  /// The socket never reports `order_picked_up` to a restaurant, so an order
  /// sitting with a driver would otherwise never leave the delivering bucket.
  /// A slow poll closes that gap; at this interval it costs well under the
  /// 100 req/min budget (SCRUM-53 §1, §11).
  static const Duration reconcileInterval = Duration(seconds: 90);

  /// The status each flat event implies. `driver_assigned` is the reason this
  /// map exists at all — it carries `order_id` and `driver_id` only, no status,
  /// so the event name is the only signal.
  static const Map<String, String> _statusForEvent = {
    SocketEventType.orderPreparing: OrderStatus.preparing,
    SocketEventType.orderReady: OrderStatus.readyForPickup,
    SocketEventType.driverAssigned: OrderStatus.driverAssigned,
    SocketEventType.orderDelivered: OrderStatus.delivered,
    SocketEventType.orderCancelled: OrderStatus.cancelled,
  };

  void _init() {
    fetchOrders();
    fetchHistory();
    _subscribeToSocket();
    _reconcileTimer =
        Timer.periodic(reconcileInterval, (_) => _reconcile());
  }

  void _subscribeToSocket() {
    _socketSub = _socket.stream.listen(handleSocketEvent);
    // Anything that happened while the socket was down was dropped, not
    // buffered — so a reconnect means refetching, not resuming.
    _connectionSub = _socket.connectionStatus.listen((connected) {
      if (connected) _reconcile();
    });
  }

  /// Pulls authoritative state back from the server. Failures are swallowed by
  /// the fetches themselves; this runs unattended.
  void _reconcile() {
    if (!mounted) return;
    fetchOrders();
    fetchHistory();
  }

  /// Handles one server frame (SCRUM-53 §11). `new_food_order` nests the order
  /// under `order`; every other event is flat and identifies it by `order_id`.
  ///
  /// The nested order is a `FoodOrderWSResponse`, which omits `food_total`,
  /// `delivery_fee` and friends — [Order.fromJson] defaults them. Nothing in
  /// the order list renders those, so no backfill fetch is issued; add one here
  /// if a screen starts needing them.
  void handleSocketEvent(Map<String, dynamic> event) {
    final type = event['type'];
    if (type is! String) return;

    if (type == SocketEventType.newFoodOrder) {
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

  static const int _historyPageSize = 20;
  bool _historyLoadingMore = false;

  Future<void> fetchHistory() async {
    try {
      final page = await _repository.fetchHistory(limit: _historyPageSize);
      if (!mounted) return;
      state = state.copyWith(
        history: page.orders,
        historyHasMore: page.hasMore,
      );
    } catch (_) {}
  }

  /// Appends the next page of terminal orders (SCRUM-62 pagination).
  Future<void> loadMoreHistory() async {
    if (!state.historyHasMore || _historyLoadingMore) return;
    _historyLoadingMore = true;
    try {
      final page = await _repository.fetchHistory(
        limit: _historyPageSize,
        offset: state.history.length,
      );
      if (!mounted) return;
      state = state.copyWith(
        history: [...state.history, ...page.orders],
        historyHasMore: page.hasMore,
      );
    } catch (_) {
      // keep what we have
    } finally {
      _historyLoadingMore = false;
    }
  }

  Future<void> acceptOrder(String id) async {
    try {
      await _repository.accept(id);
      _applyStatus(id, OrderStatus.restaurantAccepted);
    } catch (e) {
      throw AppFailure('ไม่สามารถรับออเดอร์ได้', e);
    }
  }

  Future<void> rejectOrder(String id) async {
    try {
      await _repository.reject(id);
      _applyStatus(id, OrderStatus.restaurantRejected);
    } catch (e) {
      throw AppFailure('ไม่สามารถปฏิเสธออเดอร์ได้', e);
    }
  }

  Future<void> markPreparing(String id) async {
    try {
      await _repository.markPreparing(id);
      _applyStatus(id, OrderStatus.preparing);
    } catch (e) {
      throw AppFailure('ไม่สามารถอัปเดตสถานะเป็นกำลังเตรียมได้', e);
    }
  }

  Future<void> markReady(String id) async {
    try {
      await _repository.markReady(id);
      _applyStatus(id, OrderStatus.readyForPickup);
    } catch (e) {
      throw AppFailure('ไม่สามารถอัปเดตสถานะเป็นพร้อมส่งได้', e);
    }
  }

  /// Adjusts prep time and out-of-stock flags without changing the order's
  /// status, so the order stays in whichever bucket it is already in.
  Future<void> updateOps({
    required String id,
    required int prepTimeAdjustmentMin,
    required List<String> oosItemIds,
  }) async {
    try {
      await _repository.updateOps(
        id: id,
        prepTimeAdjustmentMin: prepTimeAdjustmentMin,
        oosOrderItemIds: oosItemIds,
      );
      if (!mounted) return;

      Order patch(Order o) => o.id == id
          ? o.copyWith(
              prepTimeAdjustmentMin: prepTimeAdjustmentMin,
              oosItemIds: oosItemIds,
            )
          : o;

      state = state.copyWith(
        preparing: state.preparing.map(patch).toList(),
        ready: state.ready.map(patch).toList(),
        delivering: state.delivering.map(patch).toList(),
      );
    } catch (e) {
      throw AppFailure('ไม่สามารถอัปเดตออเดอร์ได้', e);
    }
  }

  void dismissNewOrderNotification() {
    state = state.copyWith(clearNew: true);
  }

  @override
  void dispose() {
    _socketSub?.cancel();
    _connectionSub?.cancel();
    _reconcileTimer?.cancel();
    super.dispose();
  }
}

final orderProvider = StateNotifierProvider<OrderNotifier, OrderState>(
  (ref) => OrderNotifier(
    ref.watch(orderRepositoryProvider),
    ref.watch(socketServiceProvider),
  ),
);
