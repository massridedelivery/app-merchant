import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/features/menu/data/menu_repository.dart';
import 'package:merchant_app/features/menu/models/menu.dart';

// ─── Menu Notifier ─────────────────────────────────────────────────────────

class MenuNotifier extends StateNotifier<AsyncValue<List<MenuCategory>>> {
  MenuNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetchMenu('rest-123');
  }

  final MenuRepository _repository;

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

  Future<void> addCategory(String name) async {
    try {
      final newCategory = await _repository.createCategory(
        name: name,
        sortOrder: (state.value?.length ?? 0) + 1,
      );
      if (newCategory == null || !mounted) return;
      state = AsyncValue.data([...?state.value, newCategory]);
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
      final newItem = await _repository.createItem(
        categoryId: categoryId,
        name: name,
        description: description,
        price: price,
      );
      if (newItem == null || !mounted) return;

      final updated = (state.value ?? []).map((cat) {
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
    } catch (e) {
      throw Exception('ไม่สามารถเพิ่มเมนูได้');
    }
  }
}

// ─── Modifier Groups Notifier ──────────────────────────────────────────────

class ModifierGroupNotifier
    extends StateNotifier<AsyncValue<List<ModifierGroup>>> {
  ModifierGroupNotifier(this._repository) : super(const AsyncValue.loading()) {
    fetch();
  }

  final MenuRepository _repository;

  Future<void> fetch() async {
    try {
      final groups = await _repository.fetchModifierGroups();
      if (!mounted) return;
      state = AsyncValue.data(groups);
    } catch (e, st) {
      if (!mounted) return;
      state = AsyncValue.error(e, st);
    }
  }
}

// ─── Providers ─────────────────────────────────────────────────────────────

final menuProvider =
    StateNotifierProvider<MenuNotifier, AsyncValue<List<MenuCategory>>>(
        (ref) => MenuNotifier(ref.watch(menuRepositoryProvider)));

final modifierGroupProvider =
    StateNotifierProvider<ModifierGroupNotifier, AsyncValue<List<ModifierGroup>>>(
        (ref) => ModifierGroupNotifier(ref.watch(menuRepositoryProvider)));
