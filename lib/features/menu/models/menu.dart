class MenuCategory {
  final String id;
  final String name;
  final String nameTh;
  final int sortOrder;
  final bool isActive;
  final List<MenuItem> items;

  MenuCategory({
    required this.id,
    required this.name,
    this.nameTh = '',
    required this.sortOrder,
    required this.isActive,
    this.items = const [],
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? json['name_th'] ?? '',
      nameTh: json['name_th'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      items: (json['items'] as List?)?.map((i) => MenuItem.fromJson(i)).toList() ?? [],
    );
  }

  MenuCategory copyWith({
    String? name,
    String? nameTh,
    int? sortOrder,
    bool? isActive,
    List<MenuItem>? items,
  }) {
    return MenuCategory(
      id: id,
      name: name ?? this.name,
      nameTh: nameTh ?? this.nameTh,
      sortOrder: sortOrder ?? this.sortOrder,
      isActive: isActive ?? this.isActive,
      items: items ?? this.items,
    );
  }
}

class MenuItem {
  final String id;
  final String categoryId;
  final String name;
  final String nameTh;
  final String description;
  final double price;
  final double? originalPrice;
  final String? imageUrl;
  final bool isAvailable;
  final List<dynamic>? modifiers;

  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.nameTh = '',
    required this.description,
    required this.price,
    this.originalPrice,
    this.imageUrl,
    required this.isAvailable,
    this.modifiers,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] ?? '',
      categoryId: json['category_id'] ?? '',
      name: json['name'] ?? json['name_th'] ?? '',
      nameTh: json['name_th'] ?? '',
      description: json['description'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
      modifiers: (json['modifiers'] ?? json['modifier_groups']) as List?,
    );
  }

  MenuItem copyWith({
    String? name,
    String? nameTh,
    String? description,
    double? price,
    double? originalPrice,
    String? imageUrl,
    bool? isAvailable,
  }) {
    return MenuItem(
      id: id,
      categoryId: categoryId,
      name: name ?? this.name,
      nameTh: nameTh ?? this.nameTh,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      modifiers: modifiers,
    );
  }
}
