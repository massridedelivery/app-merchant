/// Order statuses, matching the status-flow appendix of the API guide:
///
/// ```
/// PLACED
///   ├─→ RESTAURANT_ACCEPTED → PREPARING → READY_FOR_PICKUP
///   │      → DRIVER_ASSIGNED → DRIVER_PICKED_UP → DELIVERED
///   ├─→ RESTAURANT_REJECTED
///   └─→ CANCELLED
/// ```
///
/// Plus the failure exits reachable from most states: FAILED_DISPATCH,
/// FAILED_DELIVERY and EXTERNALLY_DISPATCHED (SCRUM-53 §9).
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
  static const String failedDispatch = 'FAILED_DISPATCH';
  static const String failedDelivery = 'FAILED_DELIVERY';
  static const String externallyDispatched = 'EXTERNALLY_DISPATCHED';

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
    failedDispatch,
    failedDelivery,
    externallyDispatched,
  ];
}

/// One chosen modifier on an order line. `selected_modifiers` is unmarshalled
/// server-side, so it arrives as a real array — unlike `variant_options`, which
/// comes through as an escaped JSON string (SCRUM-53 §4).
class OrderItemModifier {
  final String id;
  final String name;
  final double price;

  const OrderItemModifier({
    required this.id,
    required this.name,
    required this.price,
  });

  factory OrderItemModifier.fromJson(Map<String, dynamic> json) {
    return OrderItemModifier(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
    );
  }
}

/// Who is collecting the order. Present only once dispatch has assigned
/// someone (SCRUM-53 §4).
class DriverInfo {
  const DriverInfo({
    required this.fullName,
    required this.phone,
    this.vehiclePlate,
    this.vehicleModel,
    this.rating,
  });

  final String fullName;
  final String phone;
  final String? vehiclePlate;
  final String? vehicleModel;
  final double? rating;

  factory DriverInfo.fromJson(Map<String, dynamic> json) {
    return DriverInfo(
      fullName: json['full_name'] ?? '',
      phone: json['phone'] ?? '',
      vehiclePlate: json['vehicle_plate'],
      vehicleModel: json['vehicle_model'],
      rating: (json['rating'] as num?)?.toDouble(),
    );
  }
}

class OrderItem {
  final String id;
  final String menuItemId;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  final List<OrderItemModifier> selectedModifiers;
  final String? notes;

  /// Escaped JSON — the column is JSONB but every read casts it to text, so it
  /// arrives as a string that has to be parsed a second time. Unlike
  /// `selected_modifiers`, which the server unmarshals for us (SCRUM-53 §4).
  final String? variantOptions;

  OrderItem({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
    this.selectedModifiers = const [],
    this.notes,
    this.variantOptions,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final mods = json['selected_modifiers'] ?? json['modifiers'];
    return OrderItem(
      id: json['id'] ?? '',
      menuItemId: json['menu_item_id'] ?? '',
      name: json['name'] ?? '',
      quantity: json['quantity'] ?? 0,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      subtotal: (json['subtotal'] ?? 0.0).toDouble(),
      selectedModifiers: mods is List
          ? mods
              .whereType<Map<String, dynamic>>()
              .map(OrderItemModifier.fromJson)
              .toList()
          : const [],
      notes: json['notes'],
      variantOptions: json['variant_options'],
    );
  }

  /// What the line actually costs: the item plus its modifiers, times quantity
  /// (SCRUM-53 §4).
  double get computedSubtotal =>
      (unitPrice + selectedModifiers.fold<double>(0, (sum, m) => sum + m.price)) *
      quantity;
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

  /// Extra minutes the restaurant added to the original ETA (may be negative).
  final int prepTimeAdjustmentMin;

  /// Order-item ids the restaurant flagged as out of stock.
  final List<String> oosItemIds;

  final String? customerName;
  final String? customerPhone;

  /// Gate codes, "call on arrival" — the kitchen and the rider both need it.
  final String? deliveryNotes;

  /// PENDING | PAID | FAILED, absent on postpaid orders that never went
  /// through the gateway. PENDING never reaches this app: unpaid prepaid
  /// orders are excluded from /orders/pending (SCRUM-53 §4, §10).
  final String? paymentStatus;

  /// SAVER | STANDARD | PRIORITY.
  final String? tier;

  final double promoDiscount;

  /// Display-only; the merchant does not act on it.
  final double platformCommission;

  final String? driverId;
  final DriverInfo? driverInfo;
  final String? deliveredAt;

  // Deliberately not modelled — no screen consumes them and they would be
  // noise: polyline, trace_id, batch_id/batch_sequence, batched_eta_min,
  // delay_queue_until, restaurant_* (our own data), delivery_lat/lng,
  // customer_distance_km, fulfillment_distance_km, original_total_amount,
  // promo_min_spend, batching_enabled.

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
    this.prepTimeAdjustmentMin = 0,
    this.oosItemIds = const [],
    this.customerName,
    this.customerPhone,
    this.deliveryNotes,
    this.paymentStatus,
    this.tier,
    this.promoDiscount = 0,
    this.platformCommission = 0,
    this.driverId,
    this.driverInfo,
    this.deliveredAt,
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
      prepTimeAdjustmentMin: json['prep_time_adjustment_min'] ?? 0,
      oosItemIds: _parseOosItems(json['oos_items']),
      customerName: json['customer_name'],
      customerPhone: json['customer_phone'],
      deliveryNotes: json['delivery_notes'],
      paymentStatus: json['payment_status'],
      tier: json['tier'],
      promoDiscount: (json['promo_discount'] ?? 0).toDouble(),
      platformCommission: (json['platform_commission'] ?? 0).toDouble(),
      driverId: json['driver_id'],
      driverInfo: json['driver_info'] is Map<String, dynamic>
          ? DriverInfo.fromJson(json['driver_info'] as Map<String, dynamic>)
          : null,
      deliveredAt: json['delivered_at'],
    );
  }

  /// The guide shows `oos_items` only as an empty array, so both an id list and
  /// a list of objects are accepted.
  static List<String> _parseOosItems(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e is Map ? (e['id'] ?? e['order_item_id']) : e)
        .whereType<String>()
        .toList();
  }

  Order copyWith({
    String? status,
    int? prepTimeAdjustmentMin,
    List<String>? oosItemIds,
  }) {
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
      prepTimeAdjustmentMin: prepTimeAdjustmentMin ?? this.prepTimeAdjustmentMin,
      oosItemIds: oosItemIds ?? this.oosItemIds,
      customerName: customerName,
      customerPhone: customerPhone,
      deliveryNotes: deliveryNotes,
      paymentStatus: paymentStatus,
      tier: tier,
      promoDiscount: promoDiscount,
      platformCommission: platformCommission,
      driverId: driverId,
      driverInfo: driverInfo,
      deliveredAt: deliveredAt,
    );
  }

  /// CASH and CORPORATE are collected on delivery; CARD and PROMPTPAY were
  /// already paid before the order was ever released to the restaurant.
  bool get isPrepaid =>
      paymentMethod == 'CARD' || paymentMethod == 'PROMPTPAY';

  /// The ETA the customer should now expect.
  int get effectiveEtaMin => originalEtaMin + prepTimeAdjustmentMin;

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
