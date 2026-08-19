import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/orders/models/order.dart';

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  /// Everything still on the restaurant's plate, including orders already
  /// handed to a driver (SCRUM-53 §4). No pagination exists server-side and
  /// prepaid orders awaiting payment are excluded, so everything returned is
  /// either paid or cash-on-delivery.
  Future<List<Order>> fetchPending() async {
    final statuses = [
      ...OrderStatus.inKitchen,
      OrderStatus.readyForPickup,
      ...OrderStatus.withDriver,
    ].join(',');
    final response =
        await _api.dio.get('/api/food/restaurant/orders/pending?status=$statuses');
    return _parseList(response.data);
  }

  /// `GET /restaurant/orders/history` (SCRUM-62) — paginated, terminal orders
  /// only (COMPLETED / REJECTED / CANCELLED). Same order shape as pending.
  Future<({List<Order> orders, bool hasMore})> fetchHistory({
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _api.dio.get(
      '/api/food/restaurant/orders/history',
      queryParameters: {'limit': limit, 'offset': offset},
    );
    final data = response.data as Map<String, dynamic>;
    final orders = (data['orders'] as List? ?? [])
        .map((j) => Order.fromJson(j as Map<String, dynamic>))
        .toList();
    return (orders: orders, hasMore: data['has_more'] == true);
  }

  Future<void> accept(String id) =>
      _api.dio.post('/api/food/restaurant/orders/$id/accept');

  Future<void> reject(String id) =>
      _api.dio.post('/api/food/restaurant/orders/$id/reject');

  Future<void> markPreparing(String id) =>
      _api.dio.post('/api/food/restaurant/orders/$id/preparing');

  Future<void> markReady(String id) =>
      _api.dio.post('/api/food/restaurant/orders/$id/ready');

  /// `PUT /restaurant/orders/{id}/ops` (4.6). Adjusts the promised prep time
  /// and flags order items the kitchen cannot make.
  Future<void> updateOps({
    required String id,
    required int prepTimeAdjustmentMin,
    required List<String> oosOrderItemIds,
  }) =>
      _api.dio.put('/api/food/restaurant/orders/$id/ops', data: {
        'prep_time_adjustment_min': prepTimeAdjustmentMin,
        'oos_order_item_ids': oosOrderItemIds,
      });

  List<Order> _parseList(dynamic data) => (data as List)
      .map((j) => Order.fromJson(j as Map<String, dynamic>))
      .toList();
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(apiClientProvider)),
);
