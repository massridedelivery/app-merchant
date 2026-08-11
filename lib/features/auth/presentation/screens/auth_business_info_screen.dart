import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/presentation/widgets/auth_step_indicator.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthBusinessInfoScreen extends StatefulWidget {
  const AuthBusinessInfoScreen({super.key});

  @override
  State<AuthBusinessInfoScreen> createState() => _AuthBusinessInfoScreenState();
}

class _AuthBusinessInfoScreenState extends State<AuthBusinessInfoScreen> {
  final _storeNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailsController = TextEditingController();
  final _contactNameController = TextEditingController();

  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();
    _storeNameController.addListener(_validateInput);
    _addressController.addListener(_validateInput);
    _contactNameController.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      _isInputValid =
          _storeNameController.text.isNotEmpty &&
          _addressController.text.isNotEmpty &&
          _contactNameController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _storeNameController.dispose();
    _addressController.dispose();
    _detailsController.dispose();
    _contactNameController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: RichText(
        text: TextSpan(
          text: label,
          style: AppTypography.label2.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
            fontWeight: FontWeight.bold,
          ),
          children: isRequired
              ? [
                  TextSpan(
                    text: ' *',
                    style: AppTypography.label2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ]
              : [],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.chevronLeftLine, size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthStepIndicator(currentStep: 3),
              const SizedBox(height: 32),
              Text(
                'ข้อมูลธุรกิจ',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ระบุรายละเอียดร้านค้าของคุณเพื่อให้ลูกค้าเข้าถึงและรู้จักแบรนด์ได้ง่ายขึ้น',
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              // Business Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.premiumCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildFieldLabel('ชื่อร้านค้า'),
                    TextField(
                      controller: _storeNameController,
                      decoration: const InputDecoration(
                        hintText: 'เช่น กล้วยทอดมหาชัย',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFieldLabel('ชื่ออาคาร/ถนน'),
                    TextField(
                      controller: _addressController,
                      decoration: const InputDecoration(
                        hintText: 'เช่น ไอคอนสยาม หรือ ซอยสุขุมวิท',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildFieldLabel('ที่ตั้งร้านค้า'),
                    InkWell(
                      onTap: () {}, // Map picker logic
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Row(
                          children: [
                            AppIcon(
                              AppIcons.locationPinLine,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 12),
                            Text('เลือกหมุดร้านค้าของคุณ'),
                            Spacer(),
                            AppIcon(AppIcons.chevronRightLine, color: Color(0xFF94A3B8)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Contact Form Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.premiumCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ข้อมูลติดต่อ (เจ้าของร้าน)',
                      style: AppTypography.heading6.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildFieldLabel('ชื่อผู้ติดต่อ'),
                    TextField(
                      controller: _contactNameController,
                      decoration: const InputDecoration(
                        hintText: 'ระบุชื่อ-นามสกุล',
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInputValid
                      ? () {
                          context.push('/register/business_type');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: _isInputValid ? 8 : 0,
                    shadowColor: AppColors.primary.withOpacity(0.4),
                  ),
                  child: const Text('บันทึกและดำเนินการต่อ'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
