import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/menu/data/menu_repository.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/presentation/widgets/link_modifier_group_sheet.dart';
import 'package:merchant_app/features/menu/presentation/widgets/modifier_dialog.dart';
import 'package:merchant_app/features/menu/presentation/widgets/modifier_group_dialog.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository() : super(ApiClient());

  final List<String> calls = [];

  @override
  Future<List<MenuCategory>> fetchMenu(String restaurantId) async => [
        MenuCategory(
          id: 'cat-1',
          name: 'Appetizers',
          sortOrder: 1,
          isActive: true,
          items: [
            MenuItem(
              id: 'item-1',
              categoryId: 'cat-1',
              name: 'Spring Rolls',
              description: '',
              price: 89,
              isAvailable: true,
            ),
          ],
        ),
      ];

  @override
  Future<List<ModifierGroup>> fetchModifierGroups() async => [
        ModifierGroup(
          id: 'group-1',
          name: 'Spiciness',
          minSelect: 0,
          maxSelect: 1,
          isActive: true,
          itemCount: 2,
          modifiers: [
            ModifierItem(id: 'mod-1', name: 'Mild', price: 0, isAvailable: true),
          ],
        ),
      ];

  @override
  Future<ModifierGroup?> createModifierGroup({
    required String name,
    required int minSelect,
    required int maxSelect,
  }) async {
    calls.add('createGroup $name min=$minSelect max=$maxSelect');
    return ModifierGroup(
      id: 'group-new',
      name: name,
      minSelect: minSelect,
      maxSelect: maxSelect,
      isActive: true,
      itemCount: 0,
      modifiers: const [],
    );
  }

  @override
  Future<void> updateModifierGroup({
    required String id,
    required String name,
    required int minSelect,
    required int maxSelect,
    required bool isActive,
  }) async {
    calls.add('updateGroup $id name=$name max=$maxSelect active=$isActive');
  }

  @override
  Future<void> deleteModifierGroup(String id) async =>
      calls.add('deleteGroup $id');

  @override
  Future<ModifierItem?> createModifier({
    required String groupId,
    required String name,
    required double price,
  }) async {
    calls.add('createModifier $groupId $name $price');
    return ModifierItem(
        id: 'mod-new', name: name, price: price, isAvailable: true);
  }

  @override
  Future<void> updateModifier({
    required String id,
    required String name,
    required double price,
    required bool isAvailable,
    int? sortOrder,
  }) async {
    calls.add('updateModifier $id name=$name price=$price');
  }

  @override
  Future<void> linkModifierGroupToItem({
    required String itemId,
    required String groupId,
    required int sortOrder,
  }) async {
    calls.add('link $groupId -> $itemId');
  }

  @override
  Future<void> unlinkModifierGroupFromItem({
    required String itemId,
    required String groupId,
  }) async {
    calls.add('unlink $groupId -> $itemId');
  }
}

void main() {
  late _FakeMenuRepository repo;

  Future<ProviderContainer> pumpWithDialog(
    WidgetTester tester,
    Widget Function() child, {
    bool asSheet = false,
  }) async {
    final container = ProviderContainer(
      overrides: [menuRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => asSheet
                    ? showModalBottomSheet(
                        context: context, builder: (_) => child())
                    : showDialog(context: context, builder: (_) => child()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    container.read(menuProvider);
    container.read(modifierGroupProvider);
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  setUp(() => repo = _FakeMenuRepository());

  group('modifier group dialog', () {
    testWidgets('creates a group with the counters it was left at',
        (tester) async {
      final container =
          await pumpWithDialog(tester, () => const ModifierGroupDialog());

      await tester.enterText(find.byType(TextFormField), 'Size');
      // Bump max_select from 1 to 2.
      await tester.tap(find.byIcon(Icons.add_circle_outline).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('เพิ่ม'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['createGroup Size min=0 max=2']);
      expect(
        container.read(modifierGroupProvider).value!.map((g) => g.id),
        ['group-1', 'group-new'],
      );
    });

    testWidgets('min_select can never exceed max_select', (tester) async {
      await pumpWithDialog(tester, () => const ModifierGroupDialog());
      await tester.enterText(find.byType(TextFormField), 'Size');

      // max stays at 1; push min up three times.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add_circle_outline).first);
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('เพิ่ม'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['createGroup Size min=1 max=1']);
    });

    testWidgets('deleting a group in use says how many menus it affects',
        (tester) async {
      await pumpWithDialog(
        tester,
        () => ModifierGroupDialog(
          group: ModifierGroup(
            id: 'group-1',
            name: 'Spiciness',
            minSelect: 0,
            maxSelect: 1,
            isActive: true,
            itemCount: 2,
            modifiers: const [],
          ),
        ),
      );

      await tester.tap(find.text('ลบ'));
      await tester.pumpAndSettle();

      expect(find.textContaining('ใช้กับ 2 เมนู'), findsOneWidget);
    });
  });

  group('modifier dialog', () {
    testWidgets('adds a modifier into the group it was opened from',
        (tester) async {
      final container = await pumpWithDialog(
        tester,
        () => const ModifierDialog(groupId: 'group-1'),
      );

      await tester.enterText(
          find.widgetWithText(TextFormField, '').first, 'Extra Spicy');
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '15');
      await tester.tap(find.text('เพิ่ม'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['createModifier group-1 Extra Spicy 15.0']);
      final modifiers =
          container.read(modifierGroupProvider).value!.single.modifiers;
      expect(modifiers.map((m) => m.name), ['Mild', 'Extra Spicy']);
    });

    testWidgets('a negative price is rejected', (tester) async {
      await pumpWithDialog(
        tester,
        () => const ModifierDialog(groupId: 'group-1'),
      );

      await tester.enterText(
          find.widgetWithText(TextFormField, '').first, 'Extra Spicy');
      await tester.enterText(find.widgetWithText(TextFormField, '0'), '-5');
      await tester.tap(find.text('เพิ่ม'));
      await tester.pumpAndSettle();

      expect(find.text('ราคาต้องไม่ติดลบ'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });
  });

  group('link sheet', () {
    testWidgets('links the group to every selected item', (tester) async {
      await pumpWithDialog(
        tester,
        () => LinkModifierGroupSheet(
          group: ModifierGroup(
            id: 'group-1',
            name: 'Spiciness',
            minSelect: 0,
            maxSelect: 1,
            isActive: true,
            itemCount: 0,
            modifiers: const [],
          ),
        ),
        asSheet: true,
      );

      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('ผูกกับ 1 เมนู'));
      await tester.pumpAndSettle();

      expect(repo.calls, ['link group-1 -> item-1']);
    });

    testWidgets('both actions stay disabled until something is picked',
        (tester) async {
      await pumpWithDialog(
        tester,
        () => LinkModifierGroupSheet(
          group: ModifierGroup(
            id: 'group-1',
            name: 'Spiciness',
            minSelect: 0,
            maxSelect: 1,
            isActive: true,
            itemCount: 0,
            modifiers: const [],
          ),
        ),
        asSheet: true,
      );

      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      expect(repo.calls, isEmpty);
    });
  });
}
