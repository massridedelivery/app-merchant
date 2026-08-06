/// Order statuses, matching the status-flow appendix of the API guide:
///
/// ```
/// PLACED
///   ├─→ RESTAURANT_ACCEPTED → PREPARING → READY_FOR_PICKUP
///   │      → DRIVER_ASSIGNED → DRIVER_PICKED_UP → DELIVERED
///   ├─→ RESTAURANT_REJECTED
///   └─→ CANCELLED
/// ```
class OrderStatus {
  const OrderStatus._();

  static const String placed = 'PLACED';
  static const String restaurantAccepted = 'RESTAURANT_ACCEPTED';
  static const String preparing = 'PREPARING';
  static const String readyForPickup = 'READY_FOR_PICKUP';
  static const String driverAssigned = 'DRIVER_ASSIGNED';
  static const String driverPickedUp = 'DRIVER_PICKED_UP';
  static const String delivered = 'DELIVERED';
  static const String restaurantRejected = 'RESTAURANT_REJECTED';
  static const String cancelled = 'CANCELLED';

  /// Still the restaurant's responsibility.
  static const List<String> inKitchen = [
    placed,
    restaurantAccepted,
    preparing,
  ];

  /// Handed over to a driver.
  static const List<String> withDriver = [driverAssigned, driverPickedUp];

  /// Terminal — nothing left for the restaurant to do.
  static const List<String> finished = [
    delivered,
    restaurantRejected,
    cancelled,
  ];
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final List<String> selectedModifiers;

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.selectedModifiers = const [],
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final mods = json['selected_modifiers'] ?? json['modifiers'];
    List<String> modList = [];
    if (mods is List) {
      modList = mods.map((m) => m.toString()).toList();
    }
    return OrderItem(
      id: json['id'] ?? '',
      menuItemId: json['menu_item_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      selectedModifiers: modList,
    );
  }
}

class Order {
  final String id;
  final String customerId;
  final String status;
  final double totalAmount;
  final double foodTotal;
  final double deliveryFee;
  final String deliveryAddress;
  final String paymentMethod;
  final int originalEtaMin;
  final String placedAt;
  final List<OrderItem> items;

  Order({
    required this.id,
    required this.customerId,
    required this.status,
    required this.totalAmount,
    required this.foodTotal,
    required this.deliveryFee,
    required this.deliveryAddress,
    required this.paymentMethod,
    required this.originalEtaMin,
    required this.placedAt,
    required this.items,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id'] ?? '',
      customerId: json['customer_id'] ?? '',
      status: json['status'] ?? 'UNKNOWN',
      totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
      foodTotal: (json['food_total'] ?? 0.0).toDouble(),
      deliveryFee: (json['delivery_fee'] ?? 0.0).toDouble(),
      deliveryAddress: json['delivery_address'] ?? '',
      paymentMethod: json['payment_method'] ?? 'cash',
      originalEtaMin: json['original_eta_min'] ?? 30,
      placedAt: json['placed_at'] ?? '',
      items: (json['items'] as List? ?? []).map((i) => OrderItem.fromJson(i as Map<String, dynamic>)).toList(),
    );
  }

  Order copyWith({String? status}) {
    return Order(
      id: id,
      customerId: customerId,
      status: status ?? this.status,
      totalAmount: totalAmount,
      foodTotal: foodTotal,
      deliveryFee: deliveryFee,
      deliveryAddress: deliveryAddress,
      paymentMethod: paymentMethod,
      originalEtaMin: originalEtaMin,
      placedAt: placedAt,
      items: items,
    );
  }

  String get shortId => id.length > 9 ? id.substring(id.length - 9) : id;

  Duration get timeSincePlaced {
    try {
      final placed = DateTime.parse(placedAt);
      return DateTime.now().difference(placed);
    } catch (_) {
      return Duration.zero;
    }
  }
}
