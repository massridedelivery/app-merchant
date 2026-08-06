import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/presentation/widgets/confirm_delete_dialog.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

/// Creates a modifier group, or edits one when [group] is given.
class ModifierGroupDialog extends ConsumerStatefulWidget {
  const ModifierGroupDialog({super.key, this.group});

  final ModifierGroup? group;

  @override
  ConsumerState<ModifierGroupDialog> createState() =>
      _ModifierGroupDialogState();
}

class _ModifierGroupDialogState extends ConsumerState<ModifierGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.group?.name ?? '');
  late int _minSelect = widget.group?.minSelect ?? 0;
  late int _maxSelect = widget.group?.maxSelect ?? 1;
  late bool _isActive = widget.group?.isActive ?? true;
  bool _isLoading = false;

  bool get _isEditing => widget.group != null;

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
    final notifier = ref.read(modifierGroupProvider.notifier);
    try {
      if (_isEditing) {
        await notifier.updateGroup(
          id: widget.group!.id,
          name: _nameController.text.trim(),
          minSelect: _minSelect,
          maxSelect: _maxSelect,
          isActive: _isActive,
        );
      } else {
        await notifier.addGroup(
          name: _nameController.text.trim(),
          minSelect: _minSelect,
          maxSelect: _maxSelect,
        );
      }
      if (!mounted) return;
      _report(_isEditing ? 'บันทึกกลุ่มตัวเลือกแล้ว' : 'เพิ่มกลุ่มตัวเลือกแล้ว',
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
    final group = widget.group!;
    final confirmed = await confirmDelete(
      context,
      title: 'ลบกลุ่มตัวเลือกนี้?',
      message: group.itemCount == 0
          ? '"${group.name}" จะถูกลบถาวร'
          : '"${group.name}" ถูกใช้กับ ${group.itemCount} เมนู '
              'การลบจะทำให้เมนูเหล่านั้นไม่มีตัวเลือกนี้อีก',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(modifierGroupProvider.notifier).deleteGroup(group.id);
      if (!mounted) return;
      _report('ลบกลุ่มตัวเลือกแล้ว', AppColors.success);
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
        _isEditing ? 'แก้ไขกลุ่มตัวเลือก' : 'เพิ่มกลุ่มตัวเลือก',
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
                labelText: 'ชื่อกลุ่ม (เช่น ระดับความเผ็ด, ขนาด)',
              ),
              validator: (val) =>
                  val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อกลุ่ม' : null,
              autofocus: !_isEditing,
            ),
            const SizedBox(height: 16),
            _counter(
              label: 'เลือกอย่างน้อย',
              value: _minSelect,
              // The guide requires min_select >= 0 and never above max.
              onChanged: (v) => setState(() {
                _minSelect = v.clamp(0, _maxSelect);
              }),
            ),
            const SizedBox(height: 8),
            _counter(
              label: 'เลือกได้สูงสุด',
              value: _maxSelect,
              minimum: 1,
              onChanged: (v) => setState(() {
                _maxSelect = v < 1 ? 1 : v;
                if (_minSelect > _maxSelect) _minSelect = _maxSelect;
              }),
            ),
            if (_isEditing) ...[
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isActive,
                activeThumbColor: AppColors.primary,
                title: Text(
                  'เปิดใช้งานกลุ่มนี้',
                  style: AppTypography.body2
                      .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                ),
                onChanged:
                    _isLoading ? null : (val) => setState(() => _isActive = val),
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

  Widget _counter({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int minimum = 0,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.body2
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
          ),
        ),
        IconButton(
          onPressed: _isLoading || value <= minimum
              ? null
              : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline, size: 22),
          color: const Color(0xFF64748B),
        ),
        SizedBox(
          width: 24,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: AppTypography.label1
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
          ),
        ),
        IconButton(
          onPressed: _isLoading ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline, size: 22),
          color: const Color(0xFF64748B),
        ),
      ],
    );
  }
}
