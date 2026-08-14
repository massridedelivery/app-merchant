import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/presentation/widgets/auth_step_indicator.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthConfirmationScreen extends ConsumerStatefulWidget {
  const AuthConfirmationScreen({super.key});

  @override
  ConsumerState<AuthConfirmationScreen> createState() =>
      _AuthConfirmationScreenState();
}

class _AuthConfirmationScreenState
    extends ConsumerState<AuthConfirmationScreen> {
  bool _agreedToTerms = false;
  bool _agreedToCampaign = false;
  bool _agreedToMarketing = false;
  bool _hasReferralCode = false;

  bool _isInputValid = false;

  void _validateInput() {
    setState(() {
      _isInputValid = _agreedToTerms && _agreedToCampaign && _agreedToMarketing;
    });
  }

  Widget _buildAgreementRow(
    bool value,
    String text,
    Function(bool?) onChanged, {
    List<TextSpan>? richText,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: Checkbox(
              value: value,
              onChanged: onChanged,
              activeColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              side: const BorderSide(color: Color(0xFFE2E8F0), width: 1.5),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: richText != null
                ? RichText(
                    text: TextSpan(
                      style: AppTypography.body2.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        height: 1.5,
                      ),
                      children: richText,
                    ),
                  )
                : Text(
                    text,
                    style: AppTypography.body2.copyWith(
                      color: AppColors.semanticGrayNeutralFgHigh,
                      height: 1.5,
                    ),
                  ),
          ),
        ],
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthStepIndicator(currentStep: 7),
                    const SizedBox(height: 32),
                    Text(
                      'การยืนยันข้อมูล',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ตรวจสอบข้อมูลและยอมรับเงื่อนไขการใช้บริการเพื่อเสร็จสิ้นการลงทะเบียน',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.semanticGrayNeutralFgMidOnWhite,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card: Agreements
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.premiumCardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ข้อกำหนดและเงื่อนไข',
                            style: AppTypography.label1.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Divider(height: 32, color: Color(0xFFF1F5F9)),
                          _buildAgreementRow(
                            _agreedToTerms,
                            '',
                            (value) {
                              setState(() {
                                _agreedToTerms = value ?? false;
                                _validateInput();
                              });
                            },
                            richText: [
                              const TextSpan(text: 'ฉันได้อ่านและยอมรับ '),
                              TextSpan(
                                text: 'ข้อตกลงการใช้งาน',
                                style: AppTypography.body2.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ', '),
                              TextSpan(
                                text: 'นโยบายความเป็นส่วนตัว',
                                style: AppTypography.body2.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' และ '),
                              TextSpan(
                                text: 'เงื่อนไขร้านค้า',
                                style: AppTypography.body2.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' ของ Mass Merchant'),
                            ],
                          ),
                          _buildAgreementRow(
                            _agreedToCampaign,
                            'ตกลงเข้าร่วมแคมเปญทดลองใช้ฟรีสำหรับร้านค้าใหม่ เพื่อรับสิทธิพิเศษในการยกเว้นค่าธรรมเนียมในช่วงเริ่มต้น',
                            (value) {
                              setState(() {
                                _agreedToCampaign = value ?? false;
                                _validateInput();
                              });
                            },
                          ),
                          _buildAgreementRow(
                            _agreedToMarketing,
                            'ยินยอมรับข้อมูลข่าวสาร โปรโมชัน และเทคนิคการเพิ่มยอดขายผ่านช่องทางการตลาดต่างๆ',
                            (value) {
                              setState(() {
                                _agreedToMarketing = value ?? false;
                                _validateInput();
                              });
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Card: Referral
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: AppTheme.premiumCardDecoration,
                      child: Row(
                        children: [
                          const AppIcon(
                            AppIcons.couponLine,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'ฉันมีรหัสผู้แนะนำ',
                              style: AppTypography.body2.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Switch.adaptive(
                            value: _hasReferralCode,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setState(() {
                                _hasReferralCode = value;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    if (_hasReferralCode) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: AppTheme.premiumCardDecoration,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'กรอกรหัสผู้แนะนำ (ถ้ามี)',
                            hintStyle: AppTypography.body2.copyWith(
                              color: const Color(0xFF94A3B8),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
            // Bottom Button
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInputValid
                      ? () async {
                          await ref.read(authProvider.notifier).mockLogin();
                          if (context.mounted) {
                            context.go('/');
                          }
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
                  child: Text(
                    'เสร็จสิ้นการลงทะเบียน',
                    style: AppTypography.label1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
