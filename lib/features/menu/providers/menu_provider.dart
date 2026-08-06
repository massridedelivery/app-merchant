import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/menu/models/menu.dart';

// ─── Modifier Group Models ─────────────────────────────────────────────────

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

// ─── Menu Notifier ─────────────────────────────────────────────────────────

class MenuNotifier extends StateNotifier<AsyncValue<List<MenuCategory>>> {
  MenuNotifier(this._api) : super(const AsyncValue.loading()) {
    fetchMenu('rest-123');
  }

  final ApiClient _api;

  Future<void> fetchMenu(String restaurantId) async {
    state = const AsyncValue.loading();
    try {
      final response =
          await _api.dio.get('/customer/restaurants/$restaurantId/menu');
      final categories = (response.data['categories'] as List)
          .map((json) => MenuCategory.fromJson(json as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(categories);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> addCategory(String name) async {
    try {
      final response = await _api.dio.post('/restaurant/menu/categories',
          data: {
            'name': name,
            'sort_order': (state.value?.length ?? 0) + 1,
          });
      if (response.statusCode == 201) {
        final newCategory = MenuCategory.fromJson(
            response.data as Map<String, dynamic>);
        final current = state.value ?? [];
        state = AsyncValue.data([...current, newCategory]);
      }
    } catch (e) {
      throw Exception('ไม่สามารถเพิ่มหมวดหมู่ได้');
    }
  }

  Future<void> addItem({
    required String categoryId,
    required String name,
    required String description,
    required double price,
  }) async {
    try {
      final response = await _api.dio.post('/restaurant/menu/items',
          data: {
            'category_id': categoryId,
            'name': name,
            'description': description,
            'price': price,
          });
      if (response.statusCode == 201) {
        final newItem = MenuItem.fromJson(response.data as Map<String, dynamic>);
        final current = state.value ?? [];
        final updated = current.map((cat) {
          if (cat.id == categoryId) {
            return MenuCategory(
              id: cat.id,
              name: cat.name,
              sortOrder: cat.sortOrder,
              isActive: cat.isActive,
              items: [...cat.items, newItem],
            );
          }
          return cat;
        }).toList();
        state = AsyncValue.data(updated);
      }
    } catch (e) {
      throw Exception('ไม่สามารถเพิ่มเมนูได้');
    }
  }
}

// ─── Modifier Groups Notifier ──────────────────────────────────────────────

class ModifierGroupNotifier
    extends StateNotifier<AsyncValue<List<ModifierGroup>>> {
  ModifierGroupNotifier(this._api) : super(const AsyncValue.loading()) {
    fetch();
  }

  final ApiClient _api;

  Future<void> fetch() async {
    try {
      final response = await _api.dio.get('/restaurant/modifier-groups');
      final groups = (response.data as List)
          .map((j) => ModifierGroup.fromJson(j as Map<String, dynamic>))
          .toList();
      state = AsyncValue.data(groups);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────

final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuCategory>>>(
        (ref) => MenuNotifier(ref.watch(apiClientProvider)));

final modifierGroupProvider = StateNotifierProvider<ModifierGroupNotifier,
        AsyncValue<List<ModifierGroup>>>(
    (ref) => ModifierGroupNotifier(ref.watch(apiClientProvider)));
