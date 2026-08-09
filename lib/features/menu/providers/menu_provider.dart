import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/menu/models/menu.dart';

// ─── Modifier Group Models ─────────────────────────────────────────────────

class ModifierItem {
  final String id;
  final String name;
  final String nameTh;
  final double price;
  final bool isAvailable;

  ModifierItem({
    required this.id,
    required this.name,
    this.nameTh = '',
    required this.price,
    required this.isAvailable,
  });

  factory ModifierItem.fromJson(Map<String, dynamic> json) {
    return ModifierItem(
      id: json['id'] ?? '',
      name: json['name'] ?? json['name_th'] ?? '',
      nameTh: json['name_th'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      isAvailable: json['is_available'] ?? true,
    );
  }
}

class ModifierGroup {
  final String id;
  final String name;
  final String nameTh;
  final int minSelect;
  final int maxSelect;
  final bool isActive;
  final int itemCount;
  final List<ModifierItem> modifiers;

  ModifierGroup({
    required this.id,
    required this.name,
    this.nameTh = '',
    required this.minSelect,
    required this.maxSelect,
    required this.isActive,
    required this.itemCount,
    required this.modifiers,
  });

  factory ModifierGroup.fromJson(Map<String, dynamic> json) {
    final mods = (json['modifiers'] as List? ?? [])
        .map((m) => ModifierItem.fromJson(m as Map<String, dynamic>))
        .toList();
    return ModifierGroup(
      id: json['id'] ?? '',
      name: json['name'] ?? json['name_th'] ?? '',
      nameTh: json['name_th'] ?? '',
      minSelect: json['min_select'] ?? 0,
      maxSelect: json['max_select'] ?? 1,
      isActive: json['is_active'] ?? true,
      itemCount: json['item_count'] ?? mods.length,
      modifiers: mods,
    );
  }
}

// ─── Menu Notifier ─────────────────────────────────────────────────────────
//
// All CRUD endpoints are under /api/food/restaurant/menu/* (see
// docs/MERCHANT_API_INTEGRATION.md §5.2). The displayable menu (categories +
// their items) is read from the customer surface
// GET /customer/restaurants/{id}/menu, so we first resolve the restaurant's own
// id from its profile instead of hard-coding it.

class MenuNotifier extends StateNotifier<AsyncValue<List<MenuCategory>>> {
  MenuNotifier() : super(const AsyncValue.loading()) {
    fetchMenu();
  }

  String? _restaurantId;

  Future<String?> _resolveRestaurantId() async {
    if (_restaurantId != null) return _restaurantId;
    try {
      final res = await apiClient.dio.get('/restaurant/profile');
      _restaurantId = res.data['user_id'] as String?;
    } catch (_) {
      _restaurantId = null;
    }
    return _restaurantId;
  }

  Future<void> fetchMenu({String? restaurantId}) async {
    state = const AsyncValue.loading();
    try {
      final id = restaurantId ?? await _resolveRestaurantId();
      if (id == null) {
        state = AsyncValue.error('ไม่พบร้าน', StackTrace.current);
        return;
      }
      final response =
          await apiClient.dio.get('/customer/restaurants/$id/menu');
      final categories = (response.data['categories'] as List? ?? [])
          .map((json) => MenuCategory.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // ── Categories ──────────────────────────────────────────────────────────

  Future<void> addCategory(String name) async {
    try {
      final response = await apiClient.dio.post(
        '/restaurant/menu/categories',
        data: {
          'name': name,
          'name_th': name,
          'sort_order': (state.value?.length ?? 0) + 1,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final newCategory =
            MenuCategory.fromJson(response.data as Map<String, dynamic>);
        state = AsyncValue.data([...(state.value ?? []), newCategory]);
      }
    } catch (e) {
      throw Exception('ไม่สามารถเพิ่มหมวดหมู่ได้');
    }
  }

  Future<void> updateCategory(
    String id, {
    String? name,
    int? sortOrder,
    bool? isActive,
  }) async {
    try {
      await apiClient.dio.put('/restaurant/menu/categories/$id', data: {
        if (name != null) ...{'name': name, 'name_th': name},
        if (sortOrder != null) 'sort_order': sortOrder,
        if (isActive != null) 'is_active': isActive,
      });
      final updated = (state.value ?? [])
          .map((c) => c.id == id
              ? c.copyWith(name: name, sortOrder: sortOrder, isActive: isActive)
              : c)
          .toList();
      state = AsyncValue.data(updated);
    } catch (e) {
      throw Exception('ไม่สามารถแก้ไขหมวดหมู่ได้');
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await apiClient.dio.delete('/restaurant/menu/categories/$id');
      state = AsyncValue.data(
          (state.value ?? []).where((c) => c.id != id).toList());
    } catch (e) {
      throw Exception('ไม่สามารถลบหมวดหมู่ได้');
    }
  }

  // ── Items ───────────────────────────────────────────────────────────────

  Future<void> addItem({
    required String categoryId,
    required String name,
    required String description,
    required double price,
    String? imageUrl,
    double? originalPrice,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/restaurant/menu/items',
        data: {
          'category_id': categoryId,
          'name': name,
          'name_th': name,
          'description': description,
          'description_th': description,
          'price': price,
          if (originalPrice != null) 'original_price': originalPrice,
          if (imageUrl != null) 'image_url': imageUrl,
        },
      );
      if (response.statusCode == 201 || response.statusCode == 200) {
        final newItem = MenuItem.fromJson(response.data as Map<String, dynamic>);
        _replaceInCategory(categoryId, (items) => [...items, newItem]);
      }
    } catch (e) {
      throw Exception('ไม่สามารถเพิ่มเมนูได้');
    }
  }

  Future<void> updateItem(
    MenuItem item, {
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? imageUrl,
    bool? isAvailable,
  }) async {
    try {
      await apiClient.dio.put('/restaurant/menu/items/${item.id}', data: {
        'category_id': item.categoryId,
        if (name != null) ...{'name': name, 'name_th': name},
        if (description != null)
          ...{'description': description, 'description_th': description},
        if (price != null) 'price': price,
        if (originalPrice != null) 'original_price': originalPrice,
        if (imageUrl != null) 'image_url': imageUrl,
        if (isAvailable != null) 'is_available': isAvailable,
      });
      final updatedItem = item.copyWith(
        name: name,
        description: description,
        price: price,
        originalPrice: originalPrice,
        imageUrl: imageUrl,
        isAvailable: isAvailable,
      );
      _replaceInCategory(item.categoryId,
          (items) => items.map((i) => i.id == item.id ? updatedItem : i).toList());
    } catch (e) {
      throw Exception('ไม่สามารถแก้ไขเมนูได้');
    }
  }

  /// Quick out-of-stock / back-in-stock toggle.
  Future<void> toggleItemAvailability(MenuItem item) =>
      updateItem(item, isAvailable: !item.isAvailable);

  Future<void> deleteItem(String categoryId, String itemId) async {
    try {
      await apiClient.dio.delete('/restaurant/menu/items/$itemId');
      _replaceInCategory(
          categoryId, (items) => items.where((i) => i.id != itemId).toList());
    } catch (e) {
      throw Exception('ไม่สามารถลบเมนูได้');
    }
  }

  void _replaceInCategory(
      String categoryId, List<MenuItem> Function(List<MenuItem>) transform) {
    final updated = (state.value ?? []).map((cat) {
      if (cat.id == categoryId) {
        return cat.copyWith(items: transform(cat.items));
      }
      return cat;
    }).toList();
    state = AsyncValue.data(updated);
  }
}

// ─── Modifier Groups Notifier ──────────────────────────────────────────────

class ModifierGroupNotifier
    extends StateNotifier<AsyncValue<List<ModifierGroup>>> {
  ModifierGroupNotifier() : super(const AsyncValue.loading()) {
    fetch();
  }

  Future<void> fetch() async {
    try {
      // NOTE: backend currently exposes only POST/PUT/DELETE for
      // modifier-groups — there is no GET list endpoint yet (see
      // docs/BACKEND_GAPS.md §5). This will 404 until backend adds it; we keep
      // the local list authoritative after each mutation.
      final response = await apiClient.dio.get('/restaurant/modifier-groups');
      final groups = (response.data as List)
          .map((j) => ModifierGroup.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(groups);
    } catch (e, st) {
      // Degrade to an empty (editable) list rather than a hard error so the
      // create flow still works before the GET endpoint exists.
      if (!state.hasValue) state = AsyncValue.error(e, st);
    }
  }

  Future<ModifierGroup?> createGroup({
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
  }) async {
    try {
      final res = await apiClient.dio.post('/restaurant/modifier-groups', data: {
        'name': name,
        'name_th': name,
        'min_select': minSelect,
        'max_select': maxSelect,
      });
      final group = ModifierGroup.fromJson(res.data as Map<String, dynamic>);
      state = AsyncValue.data([...(state.value ?? []), group]);
      return group;
    } catch (e) {
      throw Exception('ไม่สามารถสร้างกลุ่มตัวเลือกได้');
    }
  }

  Future<void> updateGroup(
    String id, {
    String? name,
    int? minSelect,
    int? maxSelect,
    bool? isActive,
  }) async {
    try {
      await apiClient.dio.put('/restaurant/modifier-groups/$id', data: {
        if (name != null) ...{'name': name, 'name_th': name},
        if (minSelect != null) 'min_select': minSelect,
        if (maxSelect != null) 'max_select': maxSelect,
        if (isActive != null) 'is_active': isActive,
      });
      await fetch();
    } catch (e) {
      throw Exception('ไม่สามารถแก้ไขกลุ่มตัวเลือกได้');
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      await apiClient.dio.delete('/restaurant/modifier-groups/$id');
      state = AsyncValue.data(
          (state.value ?? []).where((g) => g.id != id).toList());
    } catch (e) {
      throw Exception('ไม่สามารถลบกลุ่มตัวเลือกได้');
    }
  }

  Future<void> addModifier(
    String groupId, {
    required String name,
    required double price,
  }) async {
    try {
      await apiClient.dio
          .post('/restaurant/modifier-groups/$groupId/modifiers', data: {
        'name': name,
        'name_th': name,
        'price': price,
      });
      await fetch();
    } catch (e) {
      throw Exception('ไม่สามารถเพิ่มตัวเลือกได้');
    }
  }

  Future<void> updateModifier(
    String id, {
    String? name,
    double? price,
    bool? isAvailable,
  }) async {
    try {
      await apiClient.dio.put('/restaurant/modifiers/$id', data: {
        if (name != null) ...{'name': name, 'name_th': name},
        if (price != null) 'price': price,
        if (isAvailable != null) 'is_available': isAvailable,
      });
      await fetch();
    } catch (e) {
      throw Exception('ไม่สามารถแก้ไขตัวเลือกได้');
    }
  }

  Future<void> deleteModifier(String id) async {
    try {
      await apiClient.dio.delete('/restaurant/modifiers/$id');
      await fetch();
    } catch (e) {
      throw Exception('ไม่สามารถลบตัวเลือกได้');
    }
  }

  /// Attach a modifier group to a menu item.
  /// POST /restaurant/items/{itemID}/modifier-groups
  Future<void> linkGroupToItem(String itemId, String groupId,
      {int sortOrder = 0}) async {
    try {
      await apiClient.dio.post('/restaurant/items/$itemId/modifier-groups',
          data: {'modifier_group_id': groupId, 'sort_order': sortOrder});
    } catch (e) {
      throw Exception('ไม่สามารถผูกกลุ่มตัวเลือกกับเมนูได้');
    }
  }

  Future<void> unlinkGroupFromItem(String itemId, String groupId) async {
    try {
      await apiClient.dio
          .delete('/restaurant/items/$itemId/modifier-groups/$groupId');
    } catch (e) {
      throw Exception('ไม่สามารถถอดกลุ่มตัวเลือกได้');
    }
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────

final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuCategory>>>(
        (ref) => MenuNotifier());

final modifierGroupProvider = StateNotifierProvider<ModifierGroupNotifier,
    AsyncValue<List<ModifierGroup>>>((ref) => ModifierGroupNotifier());
