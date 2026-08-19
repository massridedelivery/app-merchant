import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:merchant_app/features/orders/data/order_repository.dart';
import 'package:merchant_app/features/orders/models/order.dart';
import 'package:merchant_app/features/orders/providers/order_provider.dart';

class _SpyApiClient extends ApiClient {
  final List<RequestOptions> requests = [];

  late final Dio _spy = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(requestOptions: options, data: {}, statusCode: 200),
          );
        },
      ),
    );

  @override
  Dio get dio => _spy;

  RequestOptions get last => requests.last;
}

/// Serves one accepted order and swallows the ops call.
class _FakeOrderRepository extends OrderRepository {
  _FakeOrderRepository() : super(ApiClient());

  Map<String, Object?>? lastOps;
  bool failOps = false;

  @override
  Future<List<Order>> fetchPending() async => [
        Order.fromJson({
          'id': 'order-123',
          'status': 'RESTAURANT_ACCEPTED',
          'original_eta_min': 25,
          'items': [
            {'id': 'orderitem-1', 'name': 'Spring Rolls', 'quantity': 2},
            {'id': 'orderitem-2', 'name': 'Pad Thai', 'quantity': 1},
          ],
        }),
      ];

  @override
  Future<({List<Order> orders, bool hasMore})> fetchHistory({
    int limit = 20,
    int offset = 0,
  }) async =>
      (orders: <Order>[], hasMore: false);

  @override
  Future<void> updateOps({
    required String id,
    required int prepTimeAdjustmentMin,
    required List<String> oosOrderItemIds,
  }) async {
    if (failOps) throw Exception('boom');
    lastOps = {
      'id': id,
      'prep': prepTimeAdjustmentMin,
      'oos': oosOrderItemIds,
    };
  }
}

void main() {
  group('Order model', () {
    test('reads the ops fields from a pending order', () {
      final order = Order.fromJson({
        'id': 'order-123',
        'original_eta_min': 25,
        'prep_time_adjustment_min': 5,
        'oos_items': ['orderitem-1'],
      });

      expect(order.prepTimeAdjustmentMin, 5);
      expect(order.oosItemIds, ['orderitem-1']);
      expect(order.effectiveEtaMin, 30);
    });

    test('oos_items is accepted as objects too', () {
      expect(
        Order.fromJson({
          'oos_items': [
            {'id': 'orderitem-1'},
            {'order_item_id': 'orderitem-2'},
          ],
        }).oosItemIds,
        ['orderitem-1', 'orderitem-2'],
      );
    });

    test('a negative adjustment pulls the ETA in', () {
      expect(
        Order.fromJson({'original_eta_min': 25, 'prep_time_adjustment_min': -10})
            .effectiveEtaMin,
        15,
      );
    });

    test('missing ops fields fall back to no adjustment', () {
      final order = Order.fromJson({'id': 'order-123'});
      expect(order.prepTimeAdjustmentMin, 0);
      expect(order.oosItemIds, isEmpty);
    });
  });

  group('OrderRepository.updateOps', () {
    test('PUTs the documented body', () async {
      final api = _SpyApiClient();

      await OrderRepository(api).updateOps(
        id: 'order-123',
        prepTimeAdjustmentMin: 5,
        oosOrderItemIds: ['orderitem-1'],
      );

      expect(api.last.method, 'PUT');
      expect(api.last.path, '/api/food/restaurant/orders/order-123/ops');
      expect(api.last.data, {
        'prep_time_adjustment_min': 5,
        'oos_order_item_ids': ['orderitem-1'],
      });
    });
  });

  group('OrderNotifier.updateOps', () {
    late _FakeOrderRepository repo;
    late ProviderContainer container;

    setUp(() async {
      repo = _FakeOrderRepository();
      container = ProviderContainer(
        overrides: [
          orderRepositoryProvider.overrideWithValue(repo),
          socketServiceProvider.overrideWithValue(SocketService()),
        ],
      );
      addTearDown(container.dispose);
      container.read(orderProvider);
      await Future<void>.delayed(Duration.zero);
    });

    test('patches the order without moving it out of its bucket', () async {
      await container.read(orderProvider.notifier).updateOps(
            id: 'order-123',
            prepTimeAdjustmentMin: 10,
            oosItemIds: ['orderitem-2'],
          );

      expect(repo.lastOps, {
        'id': 'order-123',
        'prep': 10,
        'oos': ['orderitem-2'],
      });

      final state = container.read(orderProvider);
      expect(state.preparing.single.id, 'order-123');
      expect(state.preparing.single.prepTimeAdjustmentMin, 10);
      expect(state.preparing.single.oosItemIds, ['orderitem-2']);
      expect(state.preparing.single.effectiveEtaMin, 35);
      // Status is untouched, so the order stays where it was.
      expect(state.preparing.single.status, OrderStatus.restaurantAccepted);
      expect(state.ready, isEmpty);
    });

    test('clearing the flags is sent as an empty list', () async {
      await container.read(orderProvider.notifier).updateOps(
            id: 'order-123',
            prepTimeAdjustmentMin: 0,
            oosItemIds: const [],
          );

      expect(repo.lastOps!['oos'], isEmpty);
      expect(container.read(orderProvider).preparing.single.oosItemIds, isEmpty);
    });

    test('a failed call throws AppFailure and leaves state alone', () async {
      repo.failOps = true;

      await expectLater(
        container.read(orderProvider.notifier).updateOps(
              id: 'order-123',
              prepTimeAdjustmentMin: 30,
              oosItemIds: ['orderitem-1'],
            ),
        throwsA(isA<AppFailure>()),
      );

      final order = container.read(orderProvider).preparing.single;
      expect(order.prepTimeAdjustmentMin, 0);
      expect(order.oosItemIds, isEmpty);
    });
  });
}
