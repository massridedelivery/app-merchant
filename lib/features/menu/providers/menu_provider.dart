import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/menu/data/menu_repository.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/core/errors/app_failure.dart';

// ─── Menu Notifier ─────────────────────────────────────────────────────────

class MenuNotifier extends StateNotifier<AsyncValue<List<MenuCategory>>> {
  MenuNotifier(this._repository, this._restaurantId)
      : super(const AsyncValue.loading()) {
    if (_restaurantId != null) fetchMenu(_restaurantId);
  }

  final MenuRepository _repository;

  /// The merchant's own `user_id` — the menu endpoint takes it in the path.
  /// Null before a session is loaded, in which case nothing is fetched.
  final String? _restaurantId;

  List<MenuCategory> get _categories => state.value ?? const [];

  Future<void> fetchMenu(String restaurantId) async {
    state = const AsyncValue.loading();
    try {
      final categories = await _repository.fetchMenu(restaurantId);
      if (!mounted) return;
      state = AsyncValue.data(categories);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  // ─── Categories ──────────────────────────────────────────────────────────

  Future<void> addCategory(String name) async {
    try {
      final newCategory = await _repository.createCategory(
        name: name,
        sortOrder: _categories.length + 1,
      );
      if (newCategory == null || !mounted) return;
      state = AsyncValue.data([..._categories, newCategory]);
    } catch (e) {
      throw AppFailure('ไม่สามารถเพิ่มหมวดหมู่ได้', e);
    }
  }

  Future<void> updateCategory({
    required String id,
    required String name,
    int? sortOrder,
    bool? isActive,
  }) async {
    final current = _categories.firstWhere((c) => c.id == id);
    final updated = current.copyWith(
      name: name,
      sortOrder: sortOrder,
      isActive: isActive,
    );
    try {
      await _repository.updateCategory(
        id: id,
        name: updated.name,
        sortOrder: updated.sortOrder,
        isActive: updated.isActive,
      );
      if (!mounted) return;
      // The endpoint answers with a message, so the local copy is the new truth.
      state = AsyncValue.data(
        [for (final c in _categories) c.id == id ? updated : c],
      );
    } catch (e) {
      throw AppFailure('ไม่สามารถแก้ไขหมวดหมู่ได้', e);
    }
  }

  Future<void> deleteCategory(String id) async {
    try {
      await _repository.deleteCategory(id);
      if (!mounted) return;
      state = AsyncValue.data(
        _categories.where((c) => c.id != id).toList(),
      );
    } catch (e) {
      throw AppFailure('ไม่สามารถลบหมวดหมู่ได้', e);
    }
  }

  // ─── Items ───────────────────────────────────────────────────────────────

  Future<void> addItem({
    required String categoryId,
    required String name,
    required String description,
    required double price,
  }) async {
    try {
      final newItem = await _repository.createItem(
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
      );
      if (newItem == null || !mounted) return;
      state = AsyncValue.data([
        for (final c in _categories)
          c.id == categoryId ? c.copyWith(items: [...c.items, newItem]) : c,
      ]);
    } catch (e) {
      throw AppFailure('ไม่สามารถเพิ่มเมนูได้', e);
    }
  }

  Future<void> updateItem({
    required String id,
    required String categoryId,
    required String name,
    required String description,
    required double price,
    required bool isAvailable,
  }) async {
    final updated = _findItem(id)?.copyWith(
      categoryId: categoryId,
      name: name,
      description: description,
      price: price,
      isAvailable: isAvailable,
    );
    if (updated == null) return;

    try {
      await _repository.updateItem(
        id: id,
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
        isAvailable: isAvailable,
      );
      if (!mounted) return;
      // Drop it everywhere first, then re-add — the edit may have moved the
      // item to a different category.
      state = AsyncValue.data([
        for (final c in _categories)
          c.copyWith(
            items: [
              ...c.items.where((i) => i.id != id),
              if (c.id == categoryId) updated,
            ],
          ),
      ]);
    } catch (e) {
      throw AppFailure('ไม่สามารถแก้ไขเมนูได้', e);
    }
  }

  Future<void> deleteItem(String id) async {
    try {
      await _repository.deleteItem(id);
      if (!mounted) return;
      state = AsyncValue.data([
        for (final c in _categories)
          c.copyWith(items: c.items.where((i) => i.id != id).toList()),
      ]);
    } catch (e) {
      throw AppFailure('ไม่สามารถลบเมนูได้', e);
    }
  }

  MenuItem? _findItem(String id) {
    for (final category in _categories) {
      for (final item in category.items) {
        if (item.id == id) return item;
      }
    }
    return null;
  }
}

// ─── Modifier Groups Notifier ──────────────────────────────────────────────

class ModifierGroupNotifier
    extends StateNotifier<AsyncValue<List<ModifierGroup>>> {
  ModifierGroupNotifier(this._repository, this._restaurantId)
      : super(const AsyncValue.loading()) {
    if (_restaurantId != null) fetch();
  }

  final MenuRepository _repository;
  final String? _restaurantId;

  List<ModifierGroup> get _groups => state.value ?? const [];

  Future<void> fetch() async {
    final restaurantId = _restaurantId;
    if (restaurantId == null) return;
    try {
      final groups = await _repository.fetchModifierGroups(restaurantId);
      if (!mounted) return;
      state = AsyncValue.data(groups);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }

  // ─── Groups ──────────────────────────────────────────────────────────────

  Future<void> addGroup({
    required String name,
    int minSelect = 0,
    int maxSelect = 1,
  }) async {
    try {
      final group = await _repository.createModifierGroup(
        name: name,
        minSelect: minSelect,
        maxSelect: maxSelect,
      );
      if (group == null || !mounted) return;
      state = AsyncValue.data([..._groups, group]);
    } catch (e) {
      throw AppFailure('ไม่สามารถเพิ่มกลุ่มตัวเลือกได้', e);
    }
  }

  Future<void> updateGroup({
    required String id,
    required String name,
    int? minSelect,
    int? maxSelect,
    bool? isActive,
  }) async {
    final updated = _groups.firstWhere((g) => g.id == id).copyWith(
          name: name,
          minSelect: minSelect,
          maxSelect: maxSelect,
          isActive: isActive,
        );
    try {
      await _repository.updateModifierGroup(
        id: id,
        name: updated.name,
        minSelect: updated.minSelect,
        maxSelect: updated.maxSelect,
        isActive: updated.isActive,
      );
      if (!mounted) return;
      state = AsyncValue.data(
        [for (final g in _groups) g.id == id ? updated : g],
      );
    } catch (e) {
      throw AppFailure('ไม่สามารถแก้ไขกลุ่มตัวเลือกได้', e);
    }
  }

  Future<void> deleteGroup(String id) async {
    try {
      await _repository.deleteModifierGroup(id);
      if (!mounted) return;
      state = AsyncValue.data(_groups.where((g) => g.id != id).toList());
    } catch (e) {
      throw AppFailure('ไม่สามารถลบกลุ่มตัวเลือกได้', e);
    }
  }

  // ─── Modifiers inside a group ────────────────────────────────────────────

  Future<void> addModifier({
    required String groupId,
    required String name,
    required double price,
  }) async {
    try {
      final modifier = await _repository.createModifier(
        groupId: groupId,
        name: name,
        price: price,
      );
      if (modifier == null || !mounted) return;
      state = AsyncValue.data(_mapGroup(
        groupId,
        (g) => g.copyWith(modifiers: [...g.modifiers, modifier]),
      ));
    } catch (e) {
      throw AppFailure('ไม่สามารถเพิ่มตัวเลือกได้', e);
    }
  }

  Future<void> updateModifier({
    required String groupId,
    required String modifierId,
    required String name,
    required double price,
    required bool isAvailable,
  }) async {
    try {
      await _repository.updateModifier(
        id: modifierId,
        name: name,
        price: price,
        isAvailable: isAvailable,
      );
      if (!mounted) return;
      state = AsyncValue.data(_mapGroup(
        groupId,
        (g) => g.copyWith(modifiers: [
          for (final m in g.modifiers)
            m.id == modifierId
                ? m.copyWith(name: name, price: price, isAvailable: isAvailable)
                : m,
        ]),
      ));
    } catch (e) {
      throw AppFailure('ไม่สามารถแก้ไขตัวเลือกได้', e);
    }
  }

  Future<void> deleteModifier({
    required String groupId,
    required String modifierId,
  }) async {
    try {
      await _repository.deleteModifier(modifierId);
      if (!mounted) return;
      state = AsyncValue.data(_mapGroup(
        groupId,
        (g) => g.copyWith(
          modifiers: g.modifiers.where((m) => m.id != modifierId).toList(),
        ),
      ));
    } catch (e) {
      throw AppFailure('ไม่สามารถลบตัวเลือกได้', e);
    }
  }

  // ─── Item ↔ group links ──────────────────────────────────────────────────
  //
  // Which groups a given item uses is not part of this notifier's state, so
  // these only talk to the server. Refresh the menu afterwards if the screen
  // needs the new wiring.

  Future<void> linkToItem({
    required String itemId,
    required String groupId,
    int sortOrder = 1,
  }) async {
    try {
      await _repository.linkModifierGroupToItem(
        itemId: itemId,
        groupId: groupId,
        sortOrder: sortOrder,
      );
    } catch (e) {
      throw AppFailure('ไม่สามารถผูกกลุ่มตัวเลือกกับเมนูได้', e);
    }
  }

  Future<void> unlinkFromItem({
    required String itemId,
    required String groupId,
  }) async {
    try {
      await _repository.unlinkModifierGroupFromItem(
        itemId: itemId,
        groupId: groupId,
      );
    } catch (e) {
      throw AppFailure('ไม่สามารถถอดกลุ่มตัวเลือกออกจากเมนูได้', e);
    }
  }

  List<ModifierGroup> _mapGroup(
    String groupId,
    ModifierGroup Function(ModifierGroup) transform,
  ) =>
      [for (final g in _groups) g.id == groupId ? transform(g) : g];
}

// ─── Providers ─────────────────────────────────────────────────────────────

final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuCategory>>>(
  (ref) => MenuNotifier(
    ref.watch(menuRepositoryProvider),
    ref.watch(restaurantIdProvider),
  ),
);

final modifierGroupProvider = StateNotifierProvider<ModifierGroupNotifier,
    AsyncValue<List<ModifierGroup>>>(
  (ref) => ModifierGroupNotifier(
    ref.watch(menuRepositoryProvider),
    ref.watch(restaurantIdProvider),
  ),
);
