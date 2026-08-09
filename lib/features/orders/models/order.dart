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
    // Real backend sends `selected_modifiers` as an array of
    // { id, name, price } objects (internal_foodorder.SelectedModifier).
    // Legacy mock data sends an array of plain strings. Support both, and
    // surface the modifier *name* for display.
    final mods = json['selected_modifiers'] ?? json['modifiers'];
    List<String> modList = [];
    if (mods is List) {
      modList = mods
          .map((m) => m is Map ? (m['name']?.toString() ?? '') : m.toString())
          .where((s) => s.isNotEmpty)
          .toList();
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
