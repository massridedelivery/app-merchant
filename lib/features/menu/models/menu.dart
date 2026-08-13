class MenuCategory {
  final String id;
  final String name;

  /// With `lang=th` the server overwrites `name` with this value in place, so
  /// the two can be identical — do not swap again client-side.
  final String? nameTh;

  /// VARCHAR(50) with no CHECK constraint and nothing server-side reading it;
  /// default is uppercase `GRID`. Free-form by design (SCRUM-53 §5).
  final String style;
  final int sortOrder;
  final bool isActive;
  final List<MenuItem> items;

  MenuCategory({
    required this.id,
    required this.name,
    this.nameTh,
    this.style = 'GRID',
    required this.sortOrder,
    required this.isActive,
    this.items = const [],
  });

  factory MenuCategory.fromJson(Map<String, dynamic> json) {
    return MenuCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameTh: json['name_th'],
      style: json['style'] ?? 'GRID',
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
      nameTh: nameTh,
      style: style,
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
  final String? nameTh;
  final String description;
  final String? descriptionTh;
  final double price;

  /// Strike-through price when the item is discounted.
  final double? originalPrice;

  /// A JSON **string**, not an object: the column is JSONB but every read
  /// casts it to text (SCRUM-53 §5). Parse it a second time. Nothing
  /// server-side validates the shape, and an item created without it comes
  /// back as `"[]"` — an array — so handle both.
  final String? options;

  /// Modifier groups attached to this item. This is the only way to read them:
  /// there is no list endpoint for modifier groups.
  final List<ModifierGroup> modifierGroups;
  final String? imageUrl;
  final bool isAvailable;
  final List<dynamic>? modifiers;

  MenuItem({
    required this.id,
    required this.categoryId,
    required this.name,
    this.nameTh,
    required this.description,
    this.descriptionTh,
    required this.price,
    this.originalPrice,
    this.options,
    this.modifierGroups = const [],
    this.imageUrl,
    required this.isAvailable,
    this.modifiers,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'] ?? '',
      categoryId: json['category_id'] ?? '',
      name: json['name'] ?? '',
      nameTh: json['name_th'],
      description: json['description'] ?? '',
      descriptionTh: json['description_th'],
      price: json['price']?.toDouble() ?? 0.0,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      options: json['options'] as String?,
      modifierGroups: (json['modifier_groups'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ModifierGroup.fromJson)
          .toList(),
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
      nameTh: nameTh,
      description: description ?? this.description,
      descriptionTh: descriptionTh,
      price: price ?? this.price,
      originalPrice: originalPrice,
      options: options,
      modifierGroups: modifierGroups,
      imageUrl: imageUrl ?? this.imageUrl,
      isAvailable: isAvailable ?? this.isAvailable,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}

class ModifierItem {
  final String id;
  final String name;
  final String? nameTh;
  final double price;
  final bool isAvailable;

  ModifierItem({
    required this.id,
    required this.name,
    this.nameTh,
    required this.price,
    required this.isAvailable,
  });

  factory ModifierItem.fromJson(Map<String, dynamic> json) {
    return ModifierItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      nameTh: json['name_th'],
      price: (json['price'] ?? 0.0).toDouble(),
      isAvailable: json['is_available'] ?? true,
    );
  }

  ModifierItem copyWith({String? name, double? price, bool? isAvailable}) {
    return ModifierItem(
      id: id,
      name: name ?? this.name,
      nameTh: nameTh,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class ModifierGroup {
  final String id;
  final String name;
  final String? nameTh;
  final int minSelect;
  final int maxSelect;
  final bool isActive;
  final int itemCount;
  final List<ModifierItem> modifiers;

  ModifierGroup({
    required this.id,
    required this.name,
    this.nameTh,
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
      nameTh: json['name_th'],
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
      nameTh: nameTh,
      minSelect: minSelect ?? this.minSelect,
      maxSelect: maxSelect ?? this.maxSelect,
      isActive: isActive ?? this.isActive,
      itemCount: itemCount ?? this.itemCount,
      modifiers: modifiers ?? this.modifiers,
    );
  }
}
