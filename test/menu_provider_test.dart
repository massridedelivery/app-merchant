import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/menu/data/menu_repository.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

MenuItem item(String id, String categoryId, {String name = 'item'}) => MenuItem(
      id: id,
      categoryId: categoryId,
      name: name,
      description: '',
      price: 10,
      isAvailable: true,
    );

/// The update and delete endpoints hand back no entity, so the notifier has to
/// keep state right on its own. This fake stands in for the server so those
/// local updates are what the tests actually exercise.
class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository() : super(ApiClient());

  @override
  Future<List<MenuCategory>> fetchMenu(String restaurantId) async => [
        MenuCategory(
          id: 'cat-1',
          name: 'Appetizers',
          sortOrder: 1,
          isActive: true,
          items: [item('item-1', 'cat-1'), item('item-2', 'cat-1')],
        ),
        MenuCategory(
          id: 'cat-2',
          name: 'Mains',
          sortOrder: 2,
          isActive: true,
          items: [item('item-3', 'cat-2')],
        ),
      ];

  @override
  Future<List<ModifierGroup>> fetchModifierGroups(String restaurantId) async => [
        ModifierGroup(
          id: 'group-1',
          name: 'Spiciness',
          minSelect: 0,
          maxSelect: 1,
          isActive: true,
          itemCount: 1,
          modifiers: [
            ModifierItem(id: 'mod-1', name: 'Mild', price: 0, isAvailable: true),
          ],
        ),
        ModifierGroup(
          id: 'group-2',
          name: 'Size',
          minSelect: 1,
          maxSelect: 1,
          isActive: true,
          itemCount: 0,
          modifiers: const [],
        ),
      ];

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) async {}

  @override
  Future<void> deleteCategory(String id) async {}

  @override
  Future<void> updateItem({
    required String id,
    required String categoryId,
    required String name,
    required String description,
    required double price,
    required bool isAvailable,
    String? imageUrl,
    String? options,
  }) async {}

  @override
  Future<void> deleteItem(String id) async {}

  @override
  Future<ModifierItem?> createModifier({
    required String groupId,
    required String name,
    required double price,
  }) async =>
      ModifierItem(id: 'mod-new', name: name, price: price, isAvailable: true);

  @override
  Future<void> updateModifier({
    required String id,
    required String name,
    required double price,
    required bool isAvailable,
    int? sortOrder,
  }) async {}

  @override
  Future<void> deleteModifier(String id) async {}

  @override
  Future<void> deleteModifierGroup(String id) async {}
}

void main() {
  late ProviderContainer container;

  setUp(() async {
    container = ProviderContainer(
      overrides: [
        menuRepositoryProvider.overrideWithValue(_FakeMenuRepository()),
        restaurantIdProvider.overrideWithValue('rest-1'),
      ],
    );
    addTearDown(container.dispose);
  });

  Future<List<MenuCategory>> loadedMenu() async {
    container.read(menuProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(menuProvider).value!;
  }

  Future<List<ModifierGroup>> loadedGroups() async {
    container.read(modifierGroupProvider);
    await Future<void>.delayed(Duration.zero);
    return container.read(modifierGroupProvider).value!;
  }

  List<String> ids(Iterable<dynamic> xs) => xs.map((x) => x.id as String).toList();

  group('categories', () {
    test('updateCategory replaces the category in place', () async {
      await loadedMenu();

      await container
          .read(menuProvider.notifier)
          .updateCategory(id: 'cat-1', name: 'Starters', sortOrder: 5);

      final categories = container.read(menuProvider).value!;
      expect(ids(categories), ['cat-1', 'cat-2']); // order preserved
      expect(categories.first.name, 'Starters');
      expect(categories.first.sortOrder, 5);
      // Untouched fields survive.
      expect(ids(categories.first.items), ['item-1', 'item-2']);
    });

    test('deleteCategory removes it and leaves the rest alone', () async {
      await loadedMenu();

      await container.read(menuProvider.notifier).deleteCategory('cat-1');

      expect(ids(container.read(menuProvider).value!), ['cat-2']);
    });
  });

  group('items', () {
    test('updateItem edits in place when the category is unchanged', () async {
      await loadedMenu();

      await container.read(menuProvider.notifier).updateItem(
            id: 'item-1',
            categoryId: 'cat-1',
            name: 'Renamed',
            description: 'new',
            price: 99,
            isAvailable: false,
          );

      final categories = container.read(menuProvider).value!;
      expect(ids(categories[0].items), ['item-2', 'item-1']);
      final edited = categories[0].items.firstWhere((i) => i.id == 'item-1');
      expect(edited.name, 'Renamed');
      expect(edited.price, 99);
      expect(edited.isAvailable, isFalse);
    });

    test('updateItem moves the item when the category changes', () async {
      await loadedMenu();

      await container.read(menuProvider.notifier).updateItem(
            id: 'item-1',
            categoryId: 'cat-2',
            name: 'Moved',
            description: '',
            price: 10,
            isAvailable: true,
          );

      final categories = container.read(menuProvider).value!;
      expect(ids(categories[0].items), ['item-2']);
      expect(ids(categories[1].items), ['item-3', 'item-1']);
      expect(
        categories[1].items.firstWhere((i) => i.id == 'item-1').categoryId,
        'cat-2',
      );
    });

    test('deleteItem removes it from whichever category holds it', () async {
      await loadedMenu();

      await container.read(menuProvider.notifier).deleteItem('item-3');

      final categories = container.read(menuProvider).value!;
      expect(ids(categories[0].items), ['item-1', 'item-2']);
      expect(categories[1].items, isEmpty);
    });
  });

  group('modifier groups', () {
    test('addModifier appends into the targeted group only', () async {
      await loadedGroups();

      await container
          .read(modifierGroupProvider.notifier)
          .addModifier(groupId: 'group-2', name: 'Large', price: 20);

      final groups = container.read(modifierGroupProvider).value!;
      expect(ids(groups[0].modifiers), ['mod-1']); // untouched
      expect(ids(groups[1].modifiers), ['mod-new']);
      expect(groups[1].modifiers.single.price, 20);
    });

    test('updateModifier edits the modifier inside its group', () async {
      await loadedGroups();

      await container.read(modifierGroupProvider.notifier).updateModifier(
            groupId: 'group-1',
            modifierId: 'mod-1',
            name: 'Very Mild',
            price: 3,
            isAvailable: false,
          );

      final modifier =
          container.read(modifierGroupProvider).value!.first.modifiers.single;
      expect(modifier.name, 'Very Mild');
      expect(modifier.price, 3);
      expect(modifier.isAvailable, isFalse);
    });

    test('deleteModifier removes it from its group', () async {
      await loadedGroups();

      await container
          .read(modifierGroupProvider.notifier)
          .deleteModifier(groupId: 'group-1', modifierId: 'mod-1');

      final groups = container.read(modifierGroupProvider).value!;
      expect(groups.first.modifiers, isEmpty);
      expect(ids(groups), ['group-1', 'group-2']);
    });

    test('deleteGroup removes the whole group', () async {
      await loadedGroups();

      await container.read(modifierGroupProvider.notifier).deleteGroup('group-1');

      expect(ids(container.read(modifierGroupProvider).value!), ['group-2']);
    });
  });
}
