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
}
