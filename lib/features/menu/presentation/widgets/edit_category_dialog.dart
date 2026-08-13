import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/presentation/widgets/confirm_delete_dialog.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

class EditCategoryDialog extends ConsumerStatefulWidget {
  const EditCategoryDialog({super.key, required this.category});

  final MenuCategory category;

  @override
  ConsumerState<EditCategoryDialog> createState() => _EditCategoryDialogState();
}

class _EditCategoryDialogState extends ConsumerState<EditCategoryDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.category.name);
  late bool _isActive = widget.category.isActive;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _report(String message, Color background) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: background),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(menuProvider.notifier).updateCategory(
            id: widget.category.id,
            name: _nameController.text,
            isActive: _isActive,
          );
      if (!mounted) return;
      _report('บันทึกหมวดหมู่แล้ว', AppColors.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _report('เกิดข้อผิดพลาด: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final itemCount = widget.category.items.length;
    final confirmed = await confirmDelete(
      context,
      title: 'ลบหมวดหมู่นี้?',
      message: itemCount == 0
          ? 'หมวดหมู่ "${widget.category.name}" จะถูกลบถาวร'
          : 'หมวดหมู่ "${widget.category.name}" มี $itemCount รายการอยู่ '
              'การลบจะทำให้รายการเหล่านี้หายไปจากเมนูด้วย',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(menuProvider.notifier).deleteCategory(widget.category.id);
      if (!mounted) return;
      _report('ลบหมวดหมู่แล้ว', AppColors.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _report('เกิดข้อผิดพลาด: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      title: Text(
        'แก้ไขหมวดหมู่',
        style: AppTypography.heading6
            .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _nameController,
              style: AppTypography.body1
                  .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              decoration: const InputDecoration(labelText: 'ชื่อหมวดหมู่'),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อหมวดหมู่' : null,
              autofocus: true,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isActive,
              activeThumbColor: AppColors.primary,
              title: Text(
                'แสดงหมวดหมู่นี้ในเมนู',
                style: AppTypography.body2
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              ),
              onChanged: _isLoading
                  ? null
                  : (val) => setState(() => _isActive = val),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: _isLoading ? null : _delete,
              child: Text(
                'ลบ',
                style: AppTypography.label2
                    .copyWith(color: AppColors.semanticErrorFgHigh),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context, false),
              child: Text(
                'ยกเลิก',
                style: AppTypography.label2
                    .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.semanticSuccessBgHigh,
                foregroundColor: Colors.white,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Text('บันทึก',
                      style: AppTypography.label2.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}
