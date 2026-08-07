import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:merchant_app/features/orders/data/order_repository.dart';
import 'package:merchant_app/features/orders/models/order.dart';
import 'package:merchant_app/features/orders/providers/order_provider.dart';

/// Fails every request so the notifier's initial fetches resolve to empty state
/// without touching the network. The socket frames are what these tests drive.
class _OfflineApiClient extends ApiClient {
  late final Dio _offline = Dio()
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.reject(
          DioException(requestOptions: options, error: 'offline'),
        ),
      ),
    );

  @override
  Dio get dio => _offline;
}

/// The `new_food_order` frame from SCRUM-53 §11. The nested order is the
/// narrower `FoodOrderWSResponse` — no `food_total`, `delivery_fee`,
/// `payment_status`, `tier` or `driver_info`.
Map<String, dynamic> newFoodOrder(String id) => {
  'type': 'new_food_order',
  'order': {
    'id': id,
    'customer_id': 'c0ffee00-1111-2222-3333-444455556666',
    'customer_name': 'Nid Wattana',
    'customer_phone': '+66898887777',
    'restaurant_id': '9f1c0f6e-3b3a-4a1e-9c2d-6a5e4b3c2d10',
    'status': 'PLACED',
    'total_amount': 295.0,
    'payment_method': 'CASH',
    'delivery_address': '55/3 Soi Ruamrudee, Lumphini, Bangkok',
    'placed_at': '2026-08-07T11:02:19Z',
    'items': [
      {
        'id': 'orderitem-1',
        'order_id': id,
        'menu_item_id': 'aaaaaaa1-0000-0000-0000-000000000001',
        'name': 'Som Tam Thai',
        'quantity': 2,
        'unit_price': 60.0,
        'selected_modifiers': [
          {
            'id': 'm0000001-0000-0000-0000-000000000001',
            'name': 'Extra Peanuts',
            'price': 10.0,
          },
        ],
        'subtotal': 140.0,
        'notes': 'no fish sauce',
      },
    ],
  },
};

/// Counts how often the notifier goes back to the server.
class _CountingOrderRepository extends OrderRepository {
  _CountingOrderRepository() : super(ApiClient());

  int pendingFetches = 0;
  int historyFetches = 0;

  @override
  Future<List<Order>> fetchPending() async {
    pendingFetches++;
    return [];
  }

  @override
  Future<List<Order>> fetchHistory() async {
    historyFetches++;
    return [];
  }
}

void main() {
  late OrderNotifier notifier;
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        apiClientProvider.overrideWithValue(_OfflineApiClient()),
        socketServiceProvider.overrideWithValue(SocketService()),
      ],
    );
    addTearDown(container.dispose);
    notifier = container.read(orderProvider.notifier);
    // Let the initial (failing) fetches settle before driving socket frames.
    await Future<void>.delayed(Duration.zero);
  });

  List<String> idsIn(List<Order> bucket) => bucket.map((o) => o.id).toList();

  group('new_food_order', () {
    test('reads the order from `order`, not `data`', () {
      notifier.handleSocketEvent(newFoodOrder('order-123'));

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.preparing.single.items.single.name, 'Som Tam Thai');
      expect(state.preparing.single.totalAmount, 295.0);
      expect(state.hasNewOrder, isTrue);
      expect(state.newestIncomingOrder?.id, 'order-123');
    });

    test('selected_modifiers arrive as objects, not strings', () {
      notifier.handleSocketEvent(newFoodOrder('order-123'));

      final item = container.read(orderProvider).preparing.single.items.single;
      expect(item.selectedModifiers.single.name, 'Extra Peanuts');
      expect(item.selectedModifiers.single.price, 10.0);
      expect(item.notes, 'no fish sauce');
      // (60 + 10) * 2
      expect(item.computedSubtotal, 140.0);
    });
  });

  group('status frames', () {
    setUp(() => notifier.handleSocketEvent(newFoodOrder('order-123')));

    test('order_preparing keeps the order in the kitchen bucket', () {
      notifier.handleSocketEvent({
        'type': 'order_preparing',
        'order_id': 'order-123',
        'status': 'PREPARING',
      });

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.preparing.single.status, OrderStatus.preparing);
    });

    test('order_ready moves the order to the ready bucket', () {
      notifier.handleSocketEvent({
        'type': 'order_ready',
        'order_id': 'order-123',
        'status': 'READY_FOR_PICKUP',
      });

      final state = container.read(orderProvider);
      expect(state.preparing, isEmpty);
      expect(idsIn(state.ready), ['order-123']);
    });

    test('driver_assigned carries no status and still moves to delivering', () {
      notifier.handleSocketEvent({
        'type': 'driver_assigned',
        'order_id': 'order-123',
        'driver_id': 'driver-789',
      });

      final state = container.read(orderProvider);
      expect(state.preparing, isEmpty);
      expect(idsIn(state.delivering), ['order-123']);
      expect(state.delivering.single.status, OrderStatus.driverAssigned);
    });

    test('an order already with a driver can still reach history', () {
      for (final frame in [
        {
          'type': 'order_ready',
          'order_id': 'order-123',
          'status': 'READY_FOR_PICKUP',
        },
        {'type': 'driver_assigned', 'order_id': 'order-123'},
        {
          'type': 'order_delivered',
          'order_id': 'order-123',
          'status': 'DELIVERED',
        },
      ]) {
        notifier.handleSocketEvent(frame);
      }

      final state = container.read(orderProvider);
      expect(state.preparing, isEmpty);
      expect(state.ready, isEmpty);
      expect(state.delivering, isEmpty);
      expect(idsIn(state.history), ['order-123']);
      expect(state.history.single.status, OrderStatus.delivered);
    });

    test('order_cancelled moves the order to history', () {
      notifier.handleSocketEvent({
        'type': 'order_cancelled',
        'order_id': 'order-123',
        'status': 'CANCELLED',
      });

      expect(idsIn(container.read(orderProvider).history), ['order-123']);
    });

    test('the dispatch failure states are terminal too', () {
      notifier.handleSocketEvent({
        'type': 'order_cancelled',
        'order_id': 'order-123',
        'status': 'FAILED_DISPATCH',
      });

      final state = container.read(orderProvider);
      expect(state.preparing, isEmpty);
      expect(idsIn(state.history), ['order-123']);
    });
  });

  group('frames that must not corrupt state', () {
    setUp(() => notifier.handleSocketEvent(newFoodOrder('order-123')));

    test('events the restaurant socket never receives are ignored', () {
      // order_accepted / order_rejected / order_picked_up go to the customer
      // socket only (SCRUM-53 §11) — and order_created never existed.
      for (final frame in <Map<String, dynamic>>[
        {
          'type': 'order_created',
          'order': {'id': 'order-999', 'status': 'PLACED'},
        },
        {
          'type': 'order_accepted',
          'order_id': 'order-123',
          'status': 'RESTAURANT_ACCEPTED',
        },
        {
          'type': 'order_picked_up',
          'order_id': 'order-123',
          'status': 'DRIVER_PICKED_UP',
        },
      ]) {
        notifier.handleSocketEvent(frame);
      }

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.preparing.single.status, OrderStatus.placed);
      expect(state.delivering, isEmpty);
    });

    test('an event for an unknown order is dropped', () {
      notifier.handleSocketEvent({
        'type': 'order_ready',
        'order_id': 'never-loaded',
        'status': 'READY_FOR_PICKUP',
      });

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.ready, isEmpty);
    });

    test('malformed frames are dropped', () {
      for (final frame in <Map<String, dynamic>>[
        {},
        {'type': 42},
        {'type': 'new_food_order'}, // no `order`
        {'type': 'new_food_order', 'order': 'not-a-map'},
        {'type': 'order_ready'}, // no `order_id`
        {'type': 'something_new', 'order_id': 'order-123'},
      ]) {
        notifier.handleSocketEvent(frame);
      }

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.ready, isEmpty);
      expect(state.delivering, isEmpty);
      expect(state.history, isEmpty);
    });
  });

  group('reconciliation', () {
    test('a reconnect refetches, because nothing is replayed', () async {
      final repo = _CountingOrderRepository();
      final socket = SocketService();
      final c = ProviderContainer(overrides: [
        orderRepositoryProvider.overrideWithValue(repo),
        socketServiceProvider.overrideWithValue(socket),
      ]);
      addTearDown(c.dispose);

      c.read(orderProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repo.pendingFetches, 1); // initial load
      expect(repo.historyFetches, 1);

      await socket.connect(mockMode: true); // emits connected
      await Future<void>.delayed(Duration.zero);

      expect(repo.pendingFetches, 2);
      expect(repo.historyFetches, 2);
      socket.dispose();
    });

    test('the poll interval stays inside the rate-limit budget', () {
      // 100 req/min per user (SCRUM-53 §1); this timer costs 2 requests
      // per tick.
      final perMinute = 2 * 60 / OrderNotifier.reconcileInterval.inSeconds;
      expect(perMinute, lessThan(5));
    });
  });

  group('SocketService mock frames', () {
    test('simulateNewOrder emits the documented new_food_order shape', () async {
      final socket = SocketService();
      addTearDown(socket.dispose);

      final frame = socket.stream.first;
      socket.simulateNewOrder();

      final event = await frame;
      expect(event['type'], 'new_food_order');
      expect(event['order'], isA<Map<String, dynamic>>());
      expect(event.containsKey('data'), isFalse);
      // FoodOrderWSResponse carries none of these.
      final order = event['order'] as Map<String, dynamic>;
      expect(order.containsKey('food_total'), isFalse);
      expect(order.containsKey('delivery_fee'), isFalse);
    });

    test('simulateStatusEvent omits absent optional fields', () async {
      final socket = SocketService();
      addTearDown(socket.dispose);

      final frame = socket.stream.first;
      socket.simulateStatusEvent('driver_assigned', 'order-1',
          driverId: 'driver-789');

      final event = await frame;
      expect(event, {
        'type': 'driver_assigned',
        'order_id': 'order-1',
        'driver_id': 'driver-789',
      });
      expect(event.containsKey('status'), isFalse);
    });
  });
}
