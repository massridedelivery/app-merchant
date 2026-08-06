import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/presentation/widgets/confirm_delete_dialog.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

/// Adds a modifier to [groupId], or edits one when [modifier] is given.
class ModifierDialog extends ConsumerStatefulWidget {
  const ModifierDialog({super.key, required this.groupId, this.modifier});

  final String groupId;
  final ModifierItem? modifier;

  @override
  ConsumerState<ModifierDialog> createState() => _ModifierDialogState();
}

class _ModifierDialogState extends ConsumerState<ModifierDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.modifier?.name ?? '');
  late final _priceController = TextEditingController(
    text: widget.modifier?.price.toStringAsFixed(0) ?? '0',
  );
  late bool _isAvailable = widget.modifier?.isAvailable ?? true;
  bool _isLoading = false;

  bool get _isEditing => widget.modifier != null;

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
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
    final notifier = ref.read(modifierGroupProvider.notifier);
    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    try {
      if (_isEditing) {
        await notifier.updateModifier(
          groupId: widget.groupId,
          modifierId: widget.modifier!.id,
          name: _nameController.text.trim(),
          price: price,
          isAvailable: _isAvailable,
        );
      } else {
        await notifier.addModifier(
          groupId: widget.groupId,
          name: _nameController.text.trim(),
          price: price,
        );
      }
      if (!mounted) return;
      _report(_isEditing ? 'บันทึกตัวเลือกแล้ว' : 'เพิ่มตัวเลือกแล้ว',
          AppColors.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _report('เกิดข้อผิดพลาด: $e', AppColors.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'ลบตัวเลือกนี้?',
      message: '"${widget.modifier!.name}" จะถูกลบออกจากกลุ่มถาวร',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(modifierGroupProvider.notifier).deleteModifier(
            groupId: widget.groupId,
            modifierId: widget.modifier!.id,
          );
      if (!mounted) return;
      _report('ลบตัวเลือกแล้ว', AppColors.success);
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
        _isEditing ? 'แก้ไขตัวเลือก' : 'เพิ่มตัวเลือก',
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
              decoration: const InputDecoration(
                labelText: 'ชื่อตัวเลือก (เช่น เผ็ดมาก, ไซส์ใหญ่)',
              ),
              validator: (val) => val == null || val.trim().isEmpty
                  ? 'กรุณากรอกชื่อตัวเลือก'
                  : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              style: AppTypography.body1
                  .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              decoration: const InputDecoration(
                labelText: 'ราคาเพิ่ม (บาท) — ใส่ 0 ถ้าไม่คิดเงิน',
              ),
              keyboardType: TextInputType.number,
              validator: (val) {
                if (val == null || val.trim().isEmpty) return 'กรุณากรอกราคา';
                final parsed = double.tryParse(val.trim());
                if (parsed == null) return 'ราคาต้องเป็นตัวเลข';
                if (parsed < 0) return 'ราคาต้องไม่ติดลบ';
                return null;
              },
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isAvailable,
                activeThumbColor: AppColors.primary,
                title: Text(
                  _isAvailable ? 'พร้อมให้เลือก' : 'ของหมด',
                  style: AppTypography.body2
                      .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                ),
                onChanged: _isLoading
                    ? null
                    : (val) => setState(() => _isAvailable = val),
              ),
            ],
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        Row(
          children: [
            if (_isEditing)
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
                  : Text(_isEditing ? 'บันทึก' : 'เพิ่ม',
                      style: AppTypography.label2.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ],
    );
  }
}
