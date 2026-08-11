import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';

/// Shown instead of the app when the profile is still the row registration
/// created (SCRUM-53 §2).
///
/// Coordinates are the reason this blocks rather than nags: a restaurant left
/// at 0,0 is filtered out of customer search by distance and receives no orders
/// at all, with nothing anywhere to say why.
class StoreOnboardingScreen extends ConsumerStatefulWidget {
  const StoreOnboardingScreen({super.key, required this.profile});

  final RestaurantProfile profile;

  @override
  ConsumerState<StoreOnboardingScreen> createState() =>
      _StoreOnboardingScreenState();
}

class _StoreOnboardingScreenState
    extends ConsumerState<StoreOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();

  late final _nameController = TextEditingController(
    text: widget.profile.isPlaceholder && widget.profile.name == 'New Restaurant'
        ? ''
        : widget.profile.name,
  );
  late final _addressController = TextEditingController(
    text: widget.profile.address == 'Pending Address'
        ? ''
        : (widget.profile.address ?? ''),
  );
  late final _latController = TextEditingController(
    text: widget.profile.hasLocation ? '${widget.profile.lat}' : '',
  );
  late final _lngController = TextEditingController(
    text: widget.profile.hasLocation ? '${widget.profile.lng}' : '',
  );
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  String? _validateCoordinate(String? value, {required double limit}) {
    if (value == null || value.trim().isEmpty) return 'กรุณากรอกพิกัด';
    final parsed = double.tryParse(value.trim());
    if (parsed == null) return 'พิกัดต้องเป็นตัวเลข';
    if (parsed.abs() > limit) return 'พิกัดอยู่นอกช่วงที่เป็นไปได้';
    if (parsed == 0) return 'พิกัด 0 ทำให้ลูกค้าหาร้านไม่เจอ';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(restaurantProfileProvider.notifier).updateProfile(
            name: _nameController.text.trim(),
            address: _addressController.text.trim(),
            lat: double.parse(_latController.text.trim()),
            lng: double.parse(_lngController.text.trim()),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกข้อมูลร้านแล้ว'),
          backgroundColor: AppColors.success,
        ),
      );
    } on AppFailure catch (failure) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(failure.message),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            24,
            24,
            24,
            24 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const AppIcon(
                      AppIcons.storeLine,
                      size: 40,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'ตั้งค่าร้านให้เสร็จก่อนเริ่มขาย',
                  textAlign: TextAlign.center,
                  style: AppTypography.heading4.copyWith(
                    color: AppColors.semanticGrayNeutralFgHigh,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ร้านของคุณยังใช้ข้อมูลตั้งต้นอยู่ '
                  'ตราบใดที่ยังไม่มีพิกัดจริง ลูกค้าจะค้นหาร้านไม่เจอ '
                  'และจะไม่มีออเดอร์เข้ามาเลย',
                  textAlign: TextAlign.center,
                  style: AppTypography.body2.copyWith(
                    color: AppColors.semanticGrayNeutralFgMidOnWhite,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                _field(
                  controller: _nameController,
                  label: 'ชื่อร้าน',
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'กรุณากรอกชื่อร้าน'
                      : null,
                ),
                const SizedBox(height: 16),
                _field(
                  controller: _addressController,
                  label: 'ที่อยู่ร้าน',
                  maxLines: 2,
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'กรุณากรอกที่อยู่'
                      : null,
                ),
                const SizedBox(height: 24),

                Text(
                  'พิกัดร้าน',
                  style: AppTypography.label2
                      .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                ),
                const SizedBox(height: 4),
                Text(
                  'เปิด Google Maps ค้างที่ตำแหน่งร้าน แล้วคัดลอกตัวเลขสองชุดมาวาง',
                  style: AppTypography.caption5.copyWith(
                    color: AppColors.semanticGrayNeutralFgMidOnWhite,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _field(
                        controller: _latController,
                        label: 'ละติจูด',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) => _validateCoordinate(v, limit: 90),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _field(
                        controller: _lngController,
                        label: 'ลองจิจูด',
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                          signed: true,
                        ),
                        validator: (v) => _validateCoordinate(v, limit: 180),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : const Text(
                            'บันทึกและเริ่มใช้งาน',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
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
