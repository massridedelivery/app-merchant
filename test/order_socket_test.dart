import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/core/services/socket_service.dart';
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

/// The `order_created` frame from section 6.2 of the API guide.
Map<String, dynamic> orderCreated(String id) => {
  'type': 'order_created',
  'order_id': id,
  'status': 'PLACED',
  'order': {
    'id': id,
    'customer_id': 'cust-456',
    'restaurant_id': 'rest-123',
    'driver_id': null,
    'status': 'PLACED',
    'delivery_address': '456 Customer St, Bangkok',
    'food_total': 250.0,
    'delivery_fee': 25.0,
    'total_amount': 275.0,
    'payment_method': 'credit_card',
    'placed_at': '2024-01-01T12:00:00Z',
    'original_eta_min': 25,
    'items': [
      {
        'id': 'orderitem-1',
        'order_id': id,
        'menu_item_id': 'item-456',
        'name': 'Spring Rolls',
        'quantity': 2,
        'unit_price': 89.0,
        'selected_modifiers': [],
        'subtotal': 178.0,
      },
    ],
  },
};

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

  group('order_created', () {
    test('reads the order from `order`, not `data`', () {
      notifier.handleSocketEvent(orderCreated('order-123'));

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.preparing.single.items.single.name, 'Spring Rolls');
      expect(state.preparing.single.totalAmount, 275.0);
      expect(state.hasNewOrder, isTrue);
      expect(state.newestIncomingOrder?.id, 'order-123');
    });
  });

  group('status frames', () {
    setUp(() => notifier.handleSocketEvent(orderCreated('order-123')));

    test('order_accepted updates status but stays in the kitchen bucket', () {
      notifier.handleSocketEvent({
        'type': 'order_accepted',
        'order_id': 'order-123',
        'status': 'RESTAURANT_ACCEPTED',
      });

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.preparing.single.status, OrderStatus.restaurantAccepted);
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
          'type': 'order_picked_up',
          'order_id': 'order-123',
          'status': 'DRIVER_PICKED_UP',
        },
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
        'reason': 'Customer cancelled before restaurant accepted',
      });

      expect(idsIn(container.read(orderProvider).history), ['order-123']);
    });
  });

  group('frames that must not corrupt state', () {
    setUp(() => notifier.handleSocketEvent(orderCreated('order-123')));

    test('the retired NEW_ORDER / ORDER_STATUS_UPDATED names are ignored', () {
      notifier.handleSocketEvent({
        'type': 'NEW_ORDER',
        'data': {'id': 'order-999', 'status': 'PLACED'},
      });
      notifier.handleSocketEvent({
        'type': 'ORDER_STATUS_UPDATED',
        'data': {'orderId': 'order-123', 'status': 'READY_FOR_PICKUP'},
      });

      final state = container.read(orderProvider);
      expect(idsIn(state.preparing), ['order-123']);
      expect(state.ready, isEmpty);
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
        {'type': 'order_created'}, // no `order`
        {'type': 'order_created', 'order': 'not-a-map'},
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

  group('SocketService mock frames', () {
    test('simulateNewOrder emits the documented order_created shape', () async {
      final socket = SocketService();
      addTearDown(socket.dispose);

      final frame = socket.stream.first;
      socket.simulateNewOrder();

      final event = await frame;
      expect(event['type'], 'order_created');
      expect(event['order_id'], isA<String>());
      expect(event['order'], isA<Map<String, dynamic>>());
      expect(event.containsKey('data'), isFalse);
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
