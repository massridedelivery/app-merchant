class MenuCategory {
  final String id;
  final String name;
  final int sortOrder;
  final bool isActive;
  final List<MenuItem> items;

  MenuCategory({
    required this.id,
    required this.name,
    required this.sortOrder,
    required this.isActive,
    this.items = const [],
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      sortOrder: json['sort_order'] ?? 0,
      isActive: json['is_active'] ?? true,
      items: (json['items'] as List?)?.map((i) => MenuItem.fromJson(i)).toList() ?? [],
    );
  }

  MenuCategory copyWith({
    String? name,
    int? sortOrder,
    bool? isActive,
    List<MenuItem>? items,
  }) {
    return MenuCategory(
      id: id,
      name: name ?? this.name,
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
  final String description;
  final double price;
  final String? imageUrl;
  final bool isAvailable;
  final List<dynamic>? modifiers;

  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.description,
    required this.price,
    this.imageUrl,
    required this.isAvailable,
    this.modifiers,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] ?? '',
      categoryId: json['category_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      price: json['price']?.toDouble() ?? 0.0,
      imageUrl: json['image_url'],
      isAvailable: json['is_available'] ?? true,
      modifiers: json['modifiers'] as List?,
    );
  }

  MenuItem copyWith({
    String? categoryId,
    String? name,
    String? description,
    double? price,
    String? imageUrl,
    bool? isAvailable,
    List<dynamic>? modifiers,
  }) {
    return MenuItem(
      id: id,
      categoryId: categoryId ?? this.categoryId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}

class ModifierItem {
  final String id;
  final String name;
  final double price;
  final bool isAvailable;

  ModifierItem({
    required this.id,
    required this.name,
    required this.price,
    required this.isAvailable,
  });

  factory ModifierItem.fromJson(Map<String, dynamic> json) {
    return ModifierItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      isAvailable: json['is_available'] ?? true,
    );
  }

  ModifierItem copyWith({String? name, double? price, bool? isAvailable}) {
    return ModifierItem(
      id: id,
      name: name ?? this.name,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class ModifierGroup {
  final String id;
  final String name;
  final int minSelect;
  final int maxSelect;
  final bool isActive;
  final int itemCount;
  final List<ModifierItem> modifiers;

  ModifierGroup({
    required this.id,
    required this.name,
    required this.minSelect,
    required this.maxSelect,
    required this.isActive,
    required this.itemCount,
    required this.modifiers,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    return ModifierGroup(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      minSelect: json['min_select'] ?? 0,
      maxSelect: json['max_select'] ?? 1,
      isActive: json['is_active'] ?? true,
      itemCount: json['item_count'] ?? 0,
      modifiers: (json['modifiers'] as List? ?? [])
          .map((m) => ModifierItem.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  ModifierGroup copyWith({
    String? name,
    int? minSelect,
    int? maxSelect,
    bool? isActive,
    int? itemCount,
    List<ModifierItem>? modifiers,
  }) {
    return ModifierGroup(
      id: id,
      name: name ?? this.name,
      minSelect: minSelect ?? this.minSelect,
      maxSelect: maxSelect ?? this.maxSelect,
      isActive: isActive ?? this.isActive,
      itemCount: itemCount ?? this.itemCount,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}
