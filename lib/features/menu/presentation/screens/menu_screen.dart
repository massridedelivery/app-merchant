import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/menu/presentation/widgets/add_category_dialog.dart';
import 'package:merchant_app/features/menu/presentation/widgets/add_menu_item_dialog.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

class MenuScreen extends ConsumerStatefulWidget {
  const MenuScreen({super.key});

  @override
  ConsumerState<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends ConsumerState<MenuScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              alignment: Alignment.centerLeft,
              child: Text(
                'เมนู',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            // ─── Tabs ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: AppColors.primary.withOpacity(0.1),
                ),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                dividerColor: Colors.transparent,
                labelStyle: AppTypography.label2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: AppTypography.label3,
                tabs: const [
                  Tab(text: 'กลุ่มเมนูและรายการ'),
                  Tab(text: 'ตัวเลือกเสริม'),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [_buildMenuTab(), _buildModifiersTab()],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFAB(context),
    );
  }

  // ─── MENU TAB ───────────────────────────────────────────────────────────────

  Widget _buildMenuTab() {
    final menuState = ref.watch(menuProvider);
    return menuState.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(
        child: Text(
          'เกิดข้อผิดพลาด: $e',
          style: AppTypography.body1.copyWith(
            color: AppColors.semanticErrorFgHigh,
          ),
        ),
      ),
      data: (categories) {
        if (categories.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_menu_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ยังไม่มีรายการเมนู',
                  style: AppTypography.heading5.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'กดปุ่ม + เพื่อเพิ่มหมวดหมู่แรก',
                  style: AppTypography.body2.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: AppTheme.premiumCardDecoration.copyWith(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ExpansionTile(
                  backgroundColor: Colors.white,
                  collapsedBackgroundColor: Colors.white,
                  shape: const Border(),
                  collapsedShape: const Border(),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 20),
                  iconColor: AppColors.primary,
                  collapsedIconColor: const Color(0xFF64748B),
                  title: Text(
                    cat.name,
                    style: AppTypography.heading6.copyWith(
                      color: AppColors.semanticGrayNeutralFgHigh,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  subtitle: Text(
                    '${cat.items.length} รายการ',
                    style: AppTypography.caption5.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  children: cat.items.map((item) {
                    return Column(
                      children: [
                        const Divider(height: 1, color: Color(0xFFF1F5F9)),
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          leading: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: item.imageUrl != null
                                  ? Image.network(
                                      item.imageUrl!,
                                      width: 56,
                                      height: 56,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _imagePlaceholder(),
                                    )
                                  : _imagePlaceholder(),
                            ),
                          ),
                          title: Text(
                            item.name,
                            style: AppTypography.body2.copyWith(
                              color: AppColors.semanticGrayNeutralFgHigh,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(
                              children: [
                                Text(
                                  '฿${item.price.toStringAsFixed(0)}',
                                  style: AppTypography.body2.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: item.isAvailable
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.isAvailable ? 'พร้อมขาย' : 'สินค้าหมด',
                                    style: AppTypography.label3.copyWith(
                                      color: item.isAvailable
                                          ? const Color(0xFF166534)
                                          : const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                          ),
                          onTap: () => _showItemActions(item),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(color: Color(0xFFF1F5F9)),
      child: const Icon(
        Icons.restaurant_outlined,
        color: Color(0xFF94A3B8),
        size: 24,
      ),
    );
  }

  // ─── ITEM ACTIONS (edit / availability / delete) ──────────────────────────

  void _showItemActions(MenuItem item) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.body1.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.semanticGrayNeutralFgHigh,
                        ),
                      ),
                    ),
                    Text(
                      '฿${item.price.toStringAsFixed(0)}',
                      style: AppTypography.body1.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  item.isAvailable
                      ? Icons.remove_shopping_cart_outlined
                      : Icons.check_circle_outline,
                ),
                title: Text(item.isAvailable ? 'ทำเครื่องหมายสินค้าหมด' : 'กลับมาพร้อมขาย'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _runMenuAction(
                    () => ref
                        .read(menuProvider.notifier)
                        .toggleItemAvailability(item),
                    item.isAvailable ? 'ทำเครื่องหมายสินค้าหมดแล้ว' : 'กลับมาพร้อมขายแล้ว',
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Color(0xFFDC2626)),
                title: const Text('ลบเมนูนี้',
                    style: TextStyle(color: Color(0xFFDC2626))),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('ลบเมนู'),
                      content: Text('ต้องการลบ "${item.name}" ใช่หรือไม่?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, false),
                          child: const Text('ยกเลิก'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dCtx, true),
                          child: const Text('ลบ',
                              style: TextStyle(color: Color(0xFFDC2626))),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await _runMenuAction(
                      () => ref
                          .read(menuProvider.notifier)
                          .deleteItem(item.categoryId, item.id),
                      'ลบเมนูแล้ว',
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _runMenuAction(
      Future<void> Function() action, String successMsg) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(successMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  // ─── MODIFIER GROUPS TAB ──────────────────────────────────────────────────

  Widget _buildModifiersTab() {
    final groupsAsync = ref.watch(modifierGroupProvider);
    return groupsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (groups) {
        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF1F5F9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    size: 48,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ยังไม่มีตัวเลือกเสริม',
                  style: AppTypography.heading5.copyWith(
                    color: const Color(0xFF475569),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          itemCount: groups.length,
          itemBuilder: (_, i) => _buildModifierGroupTile(groups[i]),
        );
      },
    );
  }

  Widget _buildModifierGroupTile(ModifierGroup group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: AppTheme.premiumCardDecoration.copyWith(
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          shape: const Border(),
          collapsedShape: const Border(),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          iconColor: AppColors.primary,
          collapsedIconColor: const Color(0xFF64748B),
          title: Text(
            group.name,
            style: AppTypography.heading6.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            'ใช้กับ ${group.itemCount} รายการ',
            style: AppTypography.caption5.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
          children: [
            const Divider(height: 1, color: Color(0xFFF1F5F9)),
            ...group.modifiers.map(
              (mod) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          mod.name,
                          style: AppTypography.body2.copyWith(
                            color: AppColors.semanticGrayNeutralFgHigh,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      mod.price > 0
                          ? '+฿${mod.price.toStringAsFixed(0)}'
                          : 'ฟรี',
                      style: AppTypography.body3.copyWith(
                        color: mod.price > 0
                            ? AppColors.primary
                            : const Color(0xFF64748B),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── FAB ────────────────────────────────────────────────────────────────────

  Widget _buildFAB(BuildContext context) {
    return FloatingActionButton.extended(
      backgroundColor: AppColors.primary,
      onPressed: () => _showAddMenu(context),
      icon: const Icon(Icons.add, color: Colors.white),
      label: Text(
        'เพิ่มเมนู',
        style: AppTypography.label2.copyWith(
          color: AppColors.semanticGrayNeutralBgWhite,
          fontWeight: FontWeight.bold,
        ),
      ),
      elevation: 4,
    );
  }

  void _showAddMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                _buildActionTile(
                  context,
                  icon: Icons.category_outlined,
                  title: 'เพิ่มหมวดหมู่ใหม่',
                  subtitle: 'จัดกลุ่มเมนูของคุณ',
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => const AddCategoryDialog(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  context,
                  icon: Icons.fastfood_outlined,
                  title: 'เพิ่มรายการอาหาร',
                  subtitle: 'เพิ่มเมนูใหม่ให้ลูกค้าเลือก',
                  onTap: () {
                    Navigator.pop(context);
                    showDialog(
                      context: context,
                      builder: (_) => const AddMenuItemDialog(),
                    );
                  },
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  context,
                  icon: Icons.tune_rounded,
                  title: 'เพิ่มกลุ่มตัวเลือกเสริม',
                  subtitle: 'ความหวาน, ขนาดไซส์',
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: AppColors.primary, size: 24),
        ),
        title: Text(
          title,
          style: AppTypography.body1.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.caption5.copyWith(
            color: const Color(0xFF64748B),
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Color(0xFF94A3B8),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
