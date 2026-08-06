import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/menu/models/menu.dart';

class MenuRepository {
  MenuRepository(this._api);

  final ApiClient _api;

  /// Reads the menu through the customer-facing endpoint. The guide also
  /// defines `GET /restaurant/menu/categories` for the merchant side, which the
  /// app does not use yet.
  Future<List<MenuCategory>> fetchMenu(String restaurantId) async {
    final response =
        await _api.dio.get('/customer/restaurants/$restaurantId/menu');
    return (response.data['categories'] as List)
        .map((json) => MenuCategory.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  /// Returns the created category, or null when the server did not report 201.
  Future<MenuCategory?> createCategory({
    required String name,
    required int sortOrder,
  }) async {
    final response = await _api.dio.post(
      '/restaurant/menu/categories',
      data: {'name': name, 'sort_order': sortOrder},
    );
    if (response.statusCode != 201) return null;
    return MenuCategory.fromJson(response.data as Map<String, dynamic>);
  }

  /// Returns the created item, or null when the server did not report 201.
  Future<MenuItem?> createItem({
    required String categoryId,
    required String name,
    required String description,
    required double price,
  }) async {
    final response = await _api.dio.post(
      '/restaurant/menu/items',
      data: {
        'category_id': categoryId,
        'name': name,
        'description': description,
        'price': price,
      },
    );
    if (response.statusCode != 201) return null;
    return MenuItem.fromJson(response.data as Map<String, dynamic>);
  }

  /// Note: the guide defines POST/PUT/DELETE for modifier groups but no list
  /// endpoint. This one is served by MockInterceptor only.
  Future<List<ModifierGroup>> fetchModifierGroups() async {
    final response = await _api.dio.get('/restaurant/modifier-groups');
    return (response.data as List)
        .map((j) => ModifierGroup.fromJson(j as Map<String, dynamic>))
        .toList();
  }
}

final menuRepositoryProvider = Provider<MenuRepository>(
  (ref) => MenuRepository(ref.watch(apiClientProvider)),
);
