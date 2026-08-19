import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/menu/models/menu.dart';

/// Covers the menu section of SCRUM-53 (§5-§6).
///
/// RESTAURANT_API_GUIDE.md is superseded and wrong — do not use it.
///
/// The update and delete endpoints answer with `{"message": ...}` or 204 — no
/// entity comes back — so callers apply the change to their own state rather
/// than waiting for a server copy.
class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  // ─── Menu ────────────────────────────────────────────────────────────────

  /// `GET /api/food/restaurant/{id}/menu` (SCRUM-53 §5) — the only read that
  /// nests items inside their categories. [restaurantId] is the merchant's own
  /// `user_id` from the JWT.
  ///
  /// With `lang=th` the server overwrites `name`/`description` with the Thai
  /// values in place, so nothing is swapped client-side.
  Future<List<MenuCategory>> fetchMenu(String restaurantId) async {
    final response = await _api.dio
        .get('/api/food/restaurant/$restaurantId/menu', queryParameters: {
      'lang': 'th',
    });
    return ((response.data as Map<String, dynamic>?)?['categories'] as List? ?? [])
        .map((json) => MenuCategory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  // ─── Categories (3.1 – 3.4) ──────────────────────────────────────────────

  /// The merchant-side category list. Flat — no items attached.
  Future<List<MenuCategory>> fetchCategories() async {
    final response = await _api.dio.get('/api/food/restaurant/menu/categories');
    return (response.data as List? ?? [])
        .map((j) => MenuCategory.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  /// Returns the created category, or null when the server did not report 201.
  Future<MenuCategory?> createCategory({
    required String name,
    required int sortOrder,
  }) async {
    final response = await _api.dio.post(
      '/api/food/restaurant/menu/categories',
      data: {'name': name, 'sort_order': sortOrder},
    );
    if (response.statusCode != 201) return null;
    return MenuCategory.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) =>
      _api.dio.put('/api/food/restaurant/menu/categories/$id', data: {
        'name': name,
        'sort_order': sortOrder,
        'is_active': isActive,
      });

  Future<void> deleteCategory(String id) =>
      _api.dio.delete('/api/food/restaurant/menu/categories/$id');

  // ─── Items (3.5 – 3.7) ───────────────────────────────────────────────────

  /// Returns the created item, or null when the server did not report 201.
  Future<MenuItem?> createItem({
    required String categoryId,
    required String name,
    required String description,
    required double price,
    String? imageUrl,
    String? options,
  }) async {
    final response = await _api.dio.post('/api/food/restaurant/menu/items', data: {
      'category_id': categoryId,
      'name': name,
      'description': description,
      'price': price,
      'image_url': ?imageUrl,
      'options': ?options,
    });
    if (response.statusCode != 201) return null;
    return MenuItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateItem({
    required String id,
    required String categoryId,
    required String name,
    required String description,
    required double price,
    required bool isAvailable,
    String? imageUrl,
    String? options,
  }) =>
      _api.dio.put('/api/food/restaurant/menu/items/$id', data: {
        'category_id': categoryId,
        'name': name,
        'description': description,
        'price': price,
        'is_available': isAvailable,
        'image_url': ?imageUrl,
        'options': ?options,
      });

  Future<void> deleteItem(String id) =>
      _api.dio.delete('/api/food/restaurant/menu/items/$id');

  // ─── Modifier groups (3.8 – 3.12) ────────────────────────────────────────

  /// There is no list endpoint for modifier groups (SCRUM-53 §6) — they only
  /// come back nested under menu items, so the menu is the source and the
  /// groups are flattened out of it.
  ///
  /// A group attached to several items appears several times in the payload;
  /// the first copy wins and `itemCount` is how many items reference it.
  Future<List<ModifierGroup>> fetchModifierGroups(String restaurantId) async {
    final categories = await fetchMenu(restaurantId);

    final byId = <String, ModifierGroup>{};
    final uses = <String, int>{};
    for (final category in categories) {
      for (final item in category.items) {
        for (final group in item.modifierGroups) {
          byId.putIfAbsent(group.id, () => group);
          uses[group.id] = (uses[group.id] ?? 0) + 1;
        }
      }
    }

    return [
      for (final entry in byId.entries)
        entry.value.copyWith(itemCount: uses[entry.key]),
    ];
  }

  /// Returns the created group, or null when the server did not report 201.
  Future<ModifierGroup?> createModifierGroup({
    required String name,
    required int minSelect,
    required int maxSelect,
  }) async {
    final response = await _api.dio.post('/api/food/restaurant/modifier-groups', data: {
      'name': name,
      'min_select': minSelect,
      'max_select': maxSelect,
    });
    if (response.statusCode != 201) return null;
    return ModifierGroup.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateModifierGroup({
    required String id,
    required String name,
    required int minSelect,
    required int maxSelect,
    required bool isActive,
  }) =>
      _api.dio.put('/api/food/restaurant/modifier-groups/$id', data: {
        'name': name,
        'min_select': minSelect,
        'max_select': maxSelect,
        'is_active': isActive,
      });

  Future<void> deleteModifierGroup(String id) =>
      _api.dio.delete('/api/food/restaurant/modifier-groups/$id');

  Future<void> linkModifierGroupToItem({
    required String itemId,
    required String groupId,
    required int sortOrder,
  }) =>
      _api.dio.post('/api/food/restaurant/items/$itemId/modifier-groups', data: {
        'modifier_group_id': groupId,
        'sort_order': sortOrder,
      });

  Future<void> unlinkModifierGroupFromItem({
    required String itemId,
    required String groupId,
  }) =>
      _api.dio.delete('/api/food/restaurant/items/$itemId/modifier-groups/$groupId');

  // ─── Modifiers (3.13 – 3.15) ─────────────────────────────────────────────

  /// Returns the created modifier, or null when the server did not report 201.
  Future<ModifierItem?> createModifier({
    required String groupId,
    required String name,
    required double price,
  }) async {
    final response = await _api.dio.post(
      '/api/food/restaurant/modifier-groups/$groupId/modifiers',
      data: {'name': name, 'price': price},
    );
    if (response.statusCode != 201) return null;
    return ModifierItem.fromJson(response.data as Map<String, dynamic>);
  }

  Future<void> updateModifier({
    required String id,
    required String name,
    required double price,
    required bool isAvailable,
    int? sortOrder,
  }) =>
      _api.dio.put('/api/food/restaurant/modifiers/$id', data: {
        'name': name,
        'price': price,
        'is_available': isAvailable,
        'sort_order': ?sortOrder,
      });

  Future<void> deleteModifier(String id) =>
      _api.dio.delete('/api/food/restaurant/modifiers/$id');
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(apiClientProvider)),
);
