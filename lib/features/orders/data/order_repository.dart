import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/orders/models/order.dart';

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  /// Everything still on the restaurant's plate, including orders already
  /// handed to a driver — `GET /restaurant/orders/pending?status=`.
  Future<List<Order>> fetchPending() async {
    final statuses = [
      ...OrderStatus.inKitchen,
      OrderStatus.readyForPickup,
      ...OrderStatus.withDriver,
    ].join(',');
    final response =
        await _api.dio.get('/restaurant/orders/pending?status=$statuses');
    return _parseList(response.data);
  }

  Future<List<Order>> fetchHistory() async {
    final response = await _api.dio.get('/restaurant/orders/history');
    return _parseList(response.data);
  }

  Future<void> accept(String id) =>
      _api.dio.post('/restaurant/orders/$id/accept');

  Future<void> reject(String id) =>
      _api.dio.post('/restaurant/orders/$id/reject');

  Future<void> markPreparing(String id) =>
      _api.dio.post('/restaurant/orders/$id/preparing');

  Future<void> markReady(String id) =>
      _api.dio.post('/restaurant/orders/$id/ready');

  List<Order> _parseList(dynamic data) => (data as List)
      .map((j) => Order.fromJson(j as Map<String, dynamic>))
      .toList();
}

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(apiClientProvider)),
);
