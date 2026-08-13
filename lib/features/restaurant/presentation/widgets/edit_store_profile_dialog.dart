import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';

/// Edits the fields `PUT /restaurant/profile` accepts. Phone, manager contacts
/// and the tax id are deliberately absent — the endpoint takes none of them.
class EditStoreProfileDialog extends ConsumerStatefulWidget {
  const EditStoreProfileDialog({super.key, required this.profile});

  final RestaurantProfile profile;

  @override
  ConsumerState<EditStoreProfileDialog> createState() =>
      _EditStoreProfileDialogState();
}

class _EditStoreProfileDialogState
    extends ConsumerState<EditStoreProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.profile.name);
  late final _descController =
      TextEditingController(text: widget.profile.description ?? '');
  late final _cuisineController =
      TextEditingController(text: widget.profile.cuisineType ?? '');
  late final _addressController =
      TextEditingController(text: widget.profile.address ?? '');
  late final _minOrderController = TextEditingController(
    text: widget.profile.minOrderAmount?.toStringAsFixed(0) ?? '',
  );
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _cuisineController.dispose();
    _addressController.dispose();
    _minOrderController.dispose();
    super.dispose();
  }

  String? _trimmedOrNull(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(restaurantProfileProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            description: _trimmedOrNull(_descController),
            cuisineType: _trimmedOrNull(_cuisineController),
            address: _trimmedOrNull(_addressController),
            minOrderAmount: double.tryParse(_minOrderController.text.trim()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลร้านแล้ว'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'แก้ไขข้อมูลร้าน',
                style: AppTypography.heading6
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              ),
              const SizedBox(height: 24),

              _field(
                controller: _nameController,
                label: 'ชื่อร้าน',
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'กรุณากรอกชื่อร้าน'
                    : null,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _cuisineController,
                label: 'ประเภทอาหาร (เผื่อเลือก)',
              ),
              const SizedBox(height: 16),
              _field(
                controller: _addressController,
                label: 'ที่อยู่ (เผื่อเลือก)',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _descController,
                label: 'คำอธิบายร้าน (เผื่อเลือก)',
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              _field(
                controller: _minOrderController,
                label: 'ยอดสั่งซื้อขั้นต่ำ (บาท)',
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return null;
                  final parsed = double.tryParse(val.trim());
                  if (parsed == null) return 'ยอดขั้นต่ำต้องเป็นตัวเลข';
                  if (parsed < 0) return 'ยอดขั้นต่ำต้องไม่ติดลบ';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      style: AppTypography.body1
          .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
      decoration: InputDecoration(labelText: label),
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      enabled: !_isLoading,
    );
  }
}
