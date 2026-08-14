import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/presentation/widgets/auth_step_indicator.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthBusinessTypeScreen extends StatefulWidget {
  const AuthBusinessTypeScreen({super.key});

  @override
  State<AuthBusinessTypeScreen> createState() => _AuthBusinessTypeScreenState();
}

class _AuthBusinessTypeScreenState extends State<AuthBusinessTypeScreen> {
  String? _selectedBusinessType;

  bool _isInputValid = false;

  void _validateInput() {
    setState(() {
      _isInputValid = _selectedBusinessType != null;
    });
  }

  // [icon] is a Widget so cards can mix [AppIcon] with the Material fallbacks.
  Widget _buildTypeCard(String title, String subtitle, Widget icon) {
    bool isSelected = _selectedBusinessType == title;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedBusinessType = title;
          _validateInput();
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : const Color(0xFFF8FAFC),
                shape: BoxShape.circle,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color:
                      isSelected ? AppColors.primary : const Color(0xFF94A3B8),
                  size: 24,
                ),
                child: icon,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.label1.copyWith(
                      color: AppColors.semanticGrayNeutralFgHigh,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.caption5.copyWith(
                      color: AppColors.semanticGrayNeutralFgMidOnWhite,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const AppIcon(
                AppIcons.circleCheckFill,
                color: AppColors.primary,
                size: 24,
              ),
          ],
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
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AuthStepIndicator(currentStep: 4),
              const SizedBox(height: 32),
              Text(
                'เลือกประเภทธุรกิจ',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ข้อมูลนี้จะช่วยให้เราเตรียมเอกสารและรูปแบบภาษีที่ถูกต้องสำหรับร้านค้าของคุณ',
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),

              _buildTypeCard(
                'ธุรกิจส่วนตัว',
                'เจ้าของคนเดียว ไม่ได้จดทะเบียนนิติบุคคล',
                const AppIcon(AppIcons.circleUserLine),
              ),
              _buildTypeCard(
                'ห้างหุ้นส่วนจำกัด',
                'จดทะเบียนในรูปแบบ หจก.',
                // No multi-person equivalent in the SVG icon set yet.
                const Icon(Icons.group_outlined),
              ),
              _buildTypeCard(
                'บริษัทจำกัด',
                'จดทะเบียนในรูปแบบบริษัท (บจก.)',
                const AppIcon(AppIcons.officeLine),
              ),

              const SizedBox(height: 24),

              // Contact Summary Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.premiumCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ช่องทางการติดต่อร่วมกับแอป',
                          style: AppTypography.label1.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const AppIcon(
                          AppIcons.pencilFill,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const AppIcon(
                          AppIcons.callCenterLine,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text('08X-XXX-XXXX', style: AppTypography.body2),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.mail_outline,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 8),
                        Text('name@email.com', style: AppTypography.body2),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInputValid
                      ? () {
                          context.push('/register/personal_info');
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    padding: const EdgeInsets.symmetric(vertical: 20),
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
