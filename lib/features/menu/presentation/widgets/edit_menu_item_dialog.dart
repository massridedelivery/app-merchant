import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/menu/models/menu.dart';
import 'package:merchant_app/features/menu/presentation/widgets/confirm_delete_dialog.dart';
import 'package:merchant_app/features/menu/providers/menu_provider.dart';

class EditMenuItemDialog extends ConsumerStatefulWidget {
  const EditMenuItemDialog({super.key, required this.item});

  final MenuItem item;

  @override
  ConsumerState<EditMenuItemDialog> createState() => _EditMenuItemDialogState();
}

class _EditMenuItemDialogState extends ConsumerState<EditMenuItemDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.item.name);
  late final _descController =
      TextEditingController(text: widget.item.description);
  late final _priceController =
      TextEditingController(text: widget.item.price.toStringAsFixed(0));

  late String _categoryId = widget.item.categoryId;
  late bool _isAvailable = widget.item.isAvailable;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
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
    try {
      await ref.read(menuProvider.notifier).updateItem(
            id: widget.item.id,
            categoryId: _categoryId,
            name: _nameController.text,
            description: _descController.text,
            price: double.tryParse(_priceController.text) ?? widget.item.price,
            isAvailable: _isAvailable,
          );
      if (!mounted) return;
      _report('บันทึกเมนูแล้ว', AppColors.success);
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
      title: 'ลบเมนูนี้?',
      message: '"${widget.item.name}" จะถูกลบออกจากเมนูถาวร',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(menuProvider.notifier).deleteItem(widget.item.id);
      if (!mounted) return;
      _report('ลบเมนูแล้ว', AppColors.success);
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
    final categories = ref.watch(menuProvider).value ?? const <MenuCategory>[];

    return Dialog(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'แก้ไขรายการเมนู',
                style: AppTypography.heading6
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              ),
              const SizedBox(height: 24),

              if (categories.isNotEmpty)
                DropdownButtonFormField<String>(
                  initialValue: _categoryId,
                  dropdownColor: AppColors.semanticGrayNeutralBgWhite,
                  style: AppTypography.body1
                      .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                  decoration: const InputDecoration(labelText: 'หมวดหมู่'),
                  items: categories
                      .map((cat) => DropdownMenuItem(
                            value: cat.id,
                            child: Text(
                              cat.name,
                              style: AppTypography.body1.copyWith(
                                  color: AppColors.semanticGrayNeutralFgHigh),
                            ),
                          ))
                      .toList(),
                  onChanged: _isLoading
                      ? null
                      : (val) => setState(() => _categoryId = val ?? _categoryId),
                ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameController,
                style: AppTypography.body1
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                decoration: const InputDecoration(labelText: 'ชื่อเมนู'),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'กรุณากรอกชื่อเมนู' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _priceController,
                style: AppTypography.body1
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                decoration: const InputDecoration(labelText: 'ราคา (บาท)'),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'กรุณากรอกราคา';
                  if (double.tryParse(val) == null) return 'ราคาต้องเป็นตัวเลข';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                style: AppTypography.body1
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                decoration: const InputDecoration(labelText: 'คำอธิบาย (เผื่อเลือก)'),
                maxLines: 2,
              ),
              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: _isAvailable,
                activeThumbColor: AppColors.primary,
                title: Text(
                  _isAvailable ? 'พร้อมขาย' : 'สินค้าหมด',
                  style: AppTypography.body2
                      .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                ),
                onChanged: _isLoading
                    ? null
                    : (val) => setState(() => _isAvailable = val),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : _delete,
                    child: Text(
                      'ลบเมนู',
                      style: AppTypography.label2
                          .copyWith(color: AppColors.semanticErrorFgHigh),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed:
                        _isLoading ? null : () => Navigator.pop(context, false),
                    child: Text(
                      'ยกเลิก',
                      style: AppTypography.label2.copyWith(
                          color: AppColors.semanticGrayNeutralFgMidOnWhite),
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
                            style: AppTypography.label2
                                .copyWith(color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
