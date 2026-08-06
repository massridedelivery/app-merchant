import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

/// Attaches a modifier group to menu items, or detaches it.
///
/// The selection is the set of items an action applies to, not the group's
/// current wiring: no endpoint reports which groups an item already uses, so
/// showing ticks for the existing links would be a guess.
class LinkModifierGroupSheet extends ConsumerStatefulWidget {
  const LinkModifierGroupSheet({super.key, required this.group});

  final ModifierGroup group;

  @override
  ConsumerState<LinkModifierGroupSheet> createState() =>
      _LinkModifierGroupSheetState();
}

class _LinkModifierGroupSheetState
    extends ConsumerState<LinkModifierGroupSheet> {
  final Set<String> _selected = {};
  bool _isLoading = false;

  Future<void> _apply({required bool link}) async {
    if (_selected.isEmpty) return;
    setState(() => _isLoading = true);

    final notifier = ref.read(modifierGroupProvider.notifier);
    var failures = 0;
    for (final itemId in _selected) {
      final ok = link
          ? await notifier.linkToItem(
              itemId: itemId, groupId: widget.group.id)
          : await notifier.unlinkFromItem(
              itemId: itemId, groupId: widget.group.id);
      if (!ok) failures++;
    }
    if (!mounted) return;
    setState(() => _isLoading = false);

    final done = _selected.length - failures;
    final verb = link ? 'ผูก' : 'ถอด';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(failures == 0
            ? '$verb กับ $done เมนูแล้ว'
            : '$verb สำเร็จ $done เมนู ล้มเหลว $failures เมนู'),
        backgroundColor: failures == 0 ? AppColors.success : AppColors.error,
      ),
    );
    if (failures == 0) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(menuProvider).value ?? const <MenuCategory>[];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'ใช้ "${widget.group.name}" กับเมนู',
            style: AppTypography.heading6
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
          ),
          const SizedBox(height: 4),
          Text(
            'เลือกเมนูแล้วกดผูกหรือถอด — ระบบยังไม่มี API '
            'ให้ดึงว่าเมนูไหนใช้กลุ่มนี้อยู่ จึงยังแสดงสถานะปัจจุบันไม่ได้',
            style: AppTypography.caption5
                .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
          ),
          const SizedBox(height: 12),

          if (categories.every((c) => c.items.isEmpty))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'ยังไม่มีเมนูให้เลือก',
                style: AppTypography.body2
                    .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final category
                        in categories.where((c) => c.items.isNotEmpty)) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 4),
                        child: Text(
                          category.name,
                          style: AppTypography.label3.copyWith(
                            color: AppColors.semanticGrayNeutralFgMidOnWhite,
                          ),
                        ),
                      ),
                      for (final item in category.items)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          value: _selected.contains(item.id),
                          activeColor: AppColors.primary,
                          title: Text(
                            item.name,
                            style: AppTypography.body2.copyWith(
                              color: AppColors.semanticGrayNeutralFgHigh,
                            ),
                          ),
                          onChanged: _isLoading
                              ? null
                              : (checked) => setState(() {
                                    if (checked ?? false) {
                                      _selected.add(item.id);
                                    } else {
                                      _selected.remove(item.id);
                                    }
                                  }),
                        ),
                    ],
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isLoading || _selected.isEmpty
                      ? null
                      : () => _apply(link: false),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'ถอดออก',
                    style: AppTypography.label2.copyWith(
                      color: AppColors.semanticGrayNeutralFgHigh,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _isLoading || _selected.isEmpty
                      ? null
                      : () => _apply(link: true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _selected.isEmpty
                              ? 'ผูกกับเมนู'
                              : 'ผูกกับ ${_selected.length} เมนู',
                          style:
                              AppTypography.label2.copyWith(color: Colors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
