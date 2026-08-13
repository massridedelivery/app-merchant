import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:merchant_app/core/network/api_client.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/menu/data/menu_repository.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/presentation/widgets/edit_category_dialog.dart';
import 'package:merchant_app/features/menu/presentation/widgets/edit_menu_item_dialog.dart';
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
              description: 'Crispy',
              price: 89,
              isAvailable: true,
            ),
          ],
        ),
        MenuCategory(
          id: 'cat-2',
          name: 'Mains',
          sortOrder: 2,
          isActive: true,
          items: const [],
        ),
      ];

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
  }) async {
    calls.add('updateItem $id name=$name price=$price available=$isAvailable');
  }

  @override
  Future<void> deleteItem(String id) async => calls.add('deleteItem $id');

  @override
  Future<void> updateCategory({
    required String id,
    required String name,
    required int sortOrder,
    required bool isActive,
  }) async {
    calls.add('updateCategory $id name=$name active=$isActive');
  }

  @override
  Future<void> deleteCategory(String id) async => calls.add('deleteCategory $id');
}

void main() {
  late _FakeMenuRepository repo;

  /// Pumps a page whose only job is to open [dialog], so Navigator.pop inside
  /// the dialog behaves the way it does in the app.
  Future<ProviderContainer> pumpWithDialog(
    WidgetTester tester,
    Widget Function() dialog,
  ) async {
    final container = ProviderContainer(
      overrides: [menuRepositoryProvider.overrideWithValue(repo),
        restaurantIdProvider.overrideWithValue('rest-1')],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showDialog(context: context, builder: (_) => dialog()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    container.read(menuProvider); // kick off the initial load
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return container;
  }

  MenuItem itemUnderTest(ProviderContainer c) => c
      .read(menuProvider)
      .value!
      .expand((cat) => cat.items)
      .firstWhere((i) => i.id == 'item-1');

  setUp(() => repo = _FakeMenuRepository());

  testWidgets('the item dialog prefills from the item it was given',
      (tester) async {
    await pumpWithDialog(
      tester,
      () => EditMenuItemDialog(
        item: MenuItem(
          id: 'item-1',
          categoryId: 'cat-1',
          name: 'Spring Rolls',
          description: 'Crispy',
          price: 89,
          isAvailable: true,
        ),
      ),
    );

    expect(find.text('แก้ไขรายการเมนู'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Spring Rolls'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '89'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, 'Crispy'), findsOneWidget);
  });

  testWidgets('saving the item dialog reaches the repository and the state',
      (tester) async {
    final container = await pumpWithDialog(
      tester,
      () => EditMenuItemDialog(
        item: MenuItem(
          id: 'item-1',
          categoryId: 'cat-1',
          name: 'Spring Rolls',
          description: 'Crispy',
          price: 89,
          isAvailable: true,
        ),
      ),
    );

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Spring Rolls'), 'Fresh Rolls');
    await tester.enterText(find.widgetWithText(TextFormField, '89'), '120');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(repo.calls, [
      'updateItem item-1 name=Fresh Rolls price=120.0 available=true',
    ]);
    final item = itemUnderTest(container);
    expect(item.name, 'Fresh Rolls');
    expect(item.price, 120);
    expect(find.text('แก้ไขรายการเมนู'), findsNothing); // dialog closed
  });

  testWidgets('an empty name blocks the save', (tester) async {
    await pumpWithDialog(
      tester,
      () => EditMenuItemDialog(
        item: MenuItem(
          id: 'item-1',
          categoryId: 'cat-1',
          name: 'Spring Rolls',
          description: '',
          price: 89,
          isAvailable: true,
        ),
      ),
    );

    await tester.enterText(
        find.widgetWithText(TextFormField, 'Spring Rolls'), '');
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(find.text('กรุณากรอกชื่อเมนู'), findsOneWidget);
    expect(repo.calls, isEmpty);
    expect(find.text('แก้ไขรายการเมนู'), findsOneWidget); // still open
  });

  testWidgets('deleting an item asks first and can be backed out of',
      (tester) async {
    final container = await pumpWithDialog(
      tester,
      () => EditMenuItemDialog(
        item: MenuItem(
          id: 'item-1',
          categoryId: 'cat-1',
          name: 'Spring Rolls',
          description: '',
          price: 89,
          isAvailable: true,
        ),
      ),
    );

    await tester.tap(find.text('ลบเมนู'));
    await tester.pumpAndSettle();
    expect(find.text('ลบเมนูนี้?'), findsOneWidget);

    await tester.tap(find.text('ยกเลิก').last);
    await tester.pumpAndSettle();
    expect(repo.calls, isEmpty);
    expect(itemUnderTest(container).id, 'item-1'); // still there

    await tester.tap(find.text('ลบเมนู'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ElevatedButton, 'ลบ'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['deleteItem item-1']);
    expect(container.read(menuProvider).value!.expand((c) => c.items), isEmpty);
  });

  testWidgets('the category dialog warns that deleting takes its items',
      (tester) async {
    await pumpWithDialog(
      tester,
      () => EditCategoryDialog(
        category: MenuCategory(
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
      ),
    );

    await tester.tap(find.text('ลบ'));
    await tester.pumpAndSettle();

    expect(find.textContaining('มี 1 รายการอยู่'), findsOneWidget);
  });

  testWidgets('toggling visibility saves through the notifier', (tester) async {
    final container = await pumpWithDialog(
      tester,
      () => EditCategoryDialog(
        category: MenuCategory(
          id: 'cat-1',
          name: 'Appetizers',
          sortOrder: 1,
          isActive: true,
          items: const [],
        ),
      ),
    );

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    await tester.tap(find.text('บันทึก'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['updateCategory cat-1 name=Appetizers active=false']);
    expect(container.read(menuProvider).value!.first.isActive, isFalse);
  });
}
