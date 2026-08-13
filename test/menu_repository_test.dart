import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/menu/data/menu_repository.dart';

/// Records the request each repository call makes, then hands back a canned
/// response. Asserting on `(method, path, body)` is how these tests pin the
/// repository to section 3 of RESTAURANT_API_GUIDE.md.
class _SpyApiClient extends ApiClient {
  final List<RequestOptions> requests = [];
  Object? nextBody;
  int nextStatus = 200;

  late final Dio _spy = Dio(BaseOptions(baseUrl: ApiClient.baseUrl))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          requests.add(options);
          handler.resolve(
            Response(
              requestOptions: options,
              data: nextBody,
              statusCode: nextStatus,
            ),
          );
        },
      ),
    );

  @override
  Dio get dio => _spy;

  RequestOptions get last => requests.last;
}

void main() {
  late _SpyApiClient api;
  late MenuRepository repo;

  setUp(() {
    api = _SpyApiClient();
    repo = MenuRepository(api);
  });

  void expectCall(String method, String path) {
    expect(api.last.method, method);
    expect(api.last.path, path);
  }

  group('categories', () {
    test('fetchCategories reads the merchant list endpoint', () async {
      api.nextBody = [
        {'id': 'cat-123', 'name': 'Appetizers', 'sort_order': 1, 'is_active': true},
      ];

      final categories = await repo.fetchCategories();

      expectCall('GET', '/api/food/restaurant/menu/categories');
      expect(categories.single.id, 'cat-123');
      expect(categories.single.name, 'Appetizers');
    });

    test('updateCategory PUTs the documented body', () async {
      await repo.updateCategory(
        id: 'cat-123',
        name: 'Starters',
        sortOrder: 2,
        isActive: true,
      );

      expectCall('PUT', '/api/food/restaurant/menu/categories/cat-123');
      expect(api.last.data, {
        'name': 'Starters',
        'sort_order': 2,
        'is_active': true,
      });
    });

    test('deleteCategory hits the id path', () async {
      api.nextStatus = 204;
      await repo.deleteCategory('cat-123');
      expectCall('DELETE', '/api/food/restaurant/menu/categories/cat-123');
    });
  });

  group('items', () {
    test('createItem omits optional fields when absent', () async {
      api.nextStatus = 201;
      api.nextBody = {'id': 'item-456', 'category_id': 'cat-123', 'price': 89.0};

      await repo.createItem(
        categoryId: 'cat-123',
        name: 'Spring Rolls',
        description: 'Crispy',
        price: 89.0,
      );

      expectCall('POST', '/api/food/restaurant/menu/items');
      final body = api.last.data as Map<String, dynamic>;
      expect(body['category_id'], 'cat-123');
      expect(body.containsKey('image_url'), isFalse);
      expect(body.containsKey('options'), isFalse);
    });

    test('createItem returns null when the server does not report 201', () async {
      api.nextStatus = 200;
      api.nextBody = {'id': 'item-456'};

      expect(
        await repo.createItem(
          categoryId: 'cat-123',
          name: 'Spring Rolls',
          description: '',
          price: 89.0,
        ),
        isNull,
      );
    });

    test('updateItem PUTs the documented body', () async {
      await repo.updateItem(
        id: 'item-456',
        categoryId: 'cat-123',
        name: 'Spring Rolls (Large)',
        description: 'Large crispy vegetable spring rolls',
        price: 129.0,
        isAvailable: true,
        imageUrl: 'spring-rolls-large.jpg',
      );

      expectCall('PUT', '/api/food/restaurant/menu/items/item-456');
      expect(api.last.data, {
        'category_id': 'cat-123',
        'name': 'Spring Rolls (Large)',
        'description': 'Large crispy vegetable spring rolls',
        'price': 129.0,
        'is_available': true,
        'image_url': 'spring-rolls-large.jpg',
      });
    });

    test('deleteItem hits the id path', () async {
      api.nextStatus = 204;
      await repo.deleteItem('item-456');
      expectCall('DELETE', '/api/food/restaurant/menu/items/item-456');
    });
  });

  group('modifier groups', () {
    test('createModifierGroup returns the parsed group', () async {
      api.nextStatus = 201;
      api.nextBody = {
        'id': 'group-789',
        'name': 'Spiciness Level',
        'min_select': 0,
        'max_select': 1,
        'is_active': true,
        'modifiers': [],
      };

      final group = await repo.createModifierGroup(
        name: 'Spiciness Level',
        minSelect: 0,
        maxSelect: 1,
      );

      expectCall('POST', '/api/food/restaurant/modifier-groups');
      expect(api.last.data,
          {'name': 'Spiciness Level', 'min_select': 0, 'max_select': 1});
      expect(group?.id, 'group-789');
      expect(group?.modifiers, isEmpty);
    });

    test('updateModifierGroup PUTs the documented body', () async {
      await repo.updateModifierGroup(
        id: 'group-789',
        name: 'Spice Level',
        minSelect: 0,
        maxSelect: 2,
        isActive: true,
      );

      expectCall('PUT', '/api/food/restaurant/modifier-groups/group-789');
      expect(api.last.data, {
        'name': 'Spice Level',
        'min_select': 0,
        'max_select': 2,
        'is_active': true,
      });
    });

    test('deleteModifierGroup hits the id path', () async {
      api.nextStatus = 204;
      await repo.deleteModifierGroup('group-789');
      expectCall('DELETE', '/api/food/restaurant/modifier-groups/group-789');
    });

    test('linkModifierGroupToItem posts under the item', () async {
      await repo.linkModifierGroupToItem(
        itemId: 'item-456',
        groupId: 'group-789',
        sortOrder: 1,
      );

      expectCall('POST', '/api/food/restaurant/items/item-456/modifier-groups');
      expect(api.last.data, {'modifier_group_id': 'group-789', 'sort_order': 1});
    });

    test('unlinkModifierGroupFromItem deletes the pair', () async {
      api.nextStatus = 204;
      await repo.unlinkModifierGroupFromItem(
        itemId: 'item-456',
        groupId: 'group-789',
      );
      expectCall('DELETE', '/api/food/restaurant/items/item-456/modifier-groups/group-789');
    });
  });

  group('modifier groups are flattened out of the menu', () {
    // §6 has no list endpoint — nested under items is the only source.
    setUp(() {
      api.nextBody = {
        'categories': [
          {
            'id': 'cat-1',
            'name': 'Salads',
            'items': [
              {
                'id': 'item-1',
                'name': 'Som Tam',
                'price': 60.0,
                'modifier_groups': [
                  {'id': 'grp-1', 'name': 'Add-ons', 'max_select': 3},
                  {'id': 'grp-2', 'name': 'Spice', 'max_select': 1},
                ],
              },
              {
                'id': 'item-2',
                'name': 'Larb',
                'price': 80.0,
                // grp-1 again: the same group attached to a second item.
                'modifier_groups': [
                  {'id': 'grp-1', 'name': 'Add-ons', 'max_select': 3},
                ],
              },
            ],
          },
        ],
      };
    });

    test('reads the menu rather than a list endpoint', () async {
      await repo.fetchModifierGroups('rest-1');
      expectCall('GET', '/api/food/restaurant/rest-1/menu');
    });

    test('a group used twice appears once, with a use count', () async {
      final groups = await repo.fetchModifierGroups('rest-1');

      expect(groups.map((g) => g.id).toList()..sort(), ['grp-1', 'grp-2']);
      expect(groups.firstWhere((g) => g.id == 'grp-1').itemCount, 2);
      expect(groups.firstWhere((g) => g.id == 'grp-2').itemCount, 1);
    });

    test('a menu with no modifiers yields no groups', () async {
      api.nextBody = {
        'categories': [
          {
            'id': 'cat-1',
            'items': [
              {'id': 'item-1', 'name': 'Plain', 'price': 10.0},
            ],
          },
        ],
      };

      expect(await repo.fetchModifierGroups('rest-1'), isEmpty);
    });
  });

  group('modifiers', () {
    test('createModifier posts under its group', () async {
      api.nextStatus = 201;
      api.nextBody = {
        'id': 'mod-111',
        'name': 'Extra Spicy',
        'price': 0.0,
        'is_available': true,
      };

      final modifier = await repo.createModifier(
        groupId: 'group-789',
        name: 'Extra Spicy',
        price: 0.0,
      );

      expectCall('POST', '/api/food/restaurant/modifier-groups/group-789/modifiers');
      expect(api.last.data, {'name': 'Extra Spicy', 'price': 0.0});
      expect(modifier?.id, 'mod-111');
    });

    test('updateModifier targets the flat path and drops a null sortOrder',
        () async {
      await repo.updateModifier(
        id: 'mod-111',
        name: 'Very Spicy',
        price: 5.0,
        isAvailable: true,
      );

      expectCall('PUT', '/api/food/restaurant/modifiers/mod-111');
      expect(api.last.data, {
        'name': 'Very Spicy',
        'price': 5.0,
        'is_available': true,
      });
    });

    test('updateModifier includes sortOrder when given', () async {
      await repo.updateModifier(
        id: 'mod-111',
        name: 'Very Spicy',
        price: 5.0,
        isAvailable: true,
        sortOrder: 2,
      );

      expect((api.last.data as Map<String, dynamic>)['sort_order'], 2);
    });

    test('deleteModifier hits the id path', () async {
      api.nextStatus = 204;
      await repo.deleteModifier('mod-111');
      expectCall('DELETE', '/api/food/restaurant/modifiers/mod-111');
    });
  });
}
