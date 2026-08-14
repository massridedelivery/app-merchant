import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/presentation/widgets/auth_step_indicator.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthPhoneScreen extends ConsumerStatefulWidget {
  final String flow;

  const AuthPhoneScreen({super.key, this.flow = 'login'});

  @override
  ConsumerState<AuthPhoneScreen> createState() => _AuthPhoneScreenState();
}

class _AuthPhoneScreenState extends ConsumerState<AuthPhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isInputValid = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      setState(() {
        _isInputValid = _phoneController.text.length == 10;
      });
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isLogin = widget.flow == 'login';

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.chevronLeftLine, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isLogin) ...[
                const AuthStepIndicator(currentStep: 1),
                const SizedBox(height: 32),
              ] else ...[
                const SizedBox(height: 20),
              ],
              // Header Section
              Text(
                isLogin ? 'เข้าสู่ระบบ' : 'เริ่มสร้างร้านค้าของคุณ',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isLogin
                    ? 'ยินดีต้อนรับกลับมา! กรุณาระบุเบอร์โทรศัพท์เพื่อดำเนินการต่อ'
                    : 'ระบุเบอร์โทรศัพท์ของคุณเพื่อเริ่มต้นการสมัครสมาชิก Mass Merchant',
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Input Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.premiumCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'เบอร์โทรศัพท์',
                      style: AppTypography.label2.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 10,
                      style: AppTypography.label2.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(left: 16, right: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '+66',
                                style: AppTypography.label2.copyWith(
                                  color:
                                      AppColors.semanticGrayNeutralFgLowOnWhite,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 24,
                                color: const Color(0xFFE2E8F0),
                              ),
                            ],
                          ),
                        ),
                        hintText: '00 000 0000',
                        hintStyle: AppTypography.label2.copyWith(
                          color: const Color(0xFFE2E8F0),
                        ),
                        counterText: '',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_isInputValid && !_sending) ? _requestOtp : null,
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
                  child: _sending
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          'รับรหัส OTP',
                          style: AppTypography.label1.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 32),

              // Footer Links
              if (isLogin) ...[
                Center(
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => context.push('/register/phone'),
                        child: RichText(
                          text: TextSpan(
                            style: AppTypography.body2.copyWith(
                              color: AppColors.semanticGrayNeutralFgMidOnWhite,
                            ),
                            children: [
                              const TextSpan(text: 'ยังไม่มีบัญชี? '),
                              TextSpan(
                                text: 'สมัครสมาชิก',
                                style: AppTypography.body2.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton.icon(
                        onPressed: () => context.push('/login/email'),
                        icon: const Icon(
                          Icons.email_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        label: Text(
                          'เข้าสู่ระบบด้วยอีเมล',
                          style: AppTypography.label2.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              AppColors.semanticGrayNeutralFgMidOnWhite,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Center(
                  child: GestureDetector(
                    onTap: () => context.push('/login/phone'),
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.body2.copyWith(
                          color: AppColors.semanticGrayNeutralFgMidOnWhite,
                        ),
                        children: [
                          const TextSpan(text: 'มีบัญชีอยู่แล้ว? '),
                          TextSpan(
                            text: 'เข้าสู่ระบบ',
                            style: AppTypography.body2.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _requestOtp() async {
    if (!_isInputValid || _sending) return;
    setState(() => _sending = true);
    final phone = _phoneController.text;
    final isLogin = widget.flow == 'login';
    try {
      final result = await ref.read(authProvider.notifier).requestOtp(phone);
      ref.read(otpFlowProvider.notifier).state = OtpFlow(
        phone: phone,
        refId: result.refId,
        isRegistered: result.isRegistered,
        isLogin: isLogin,
      );
      if (!mounted) return;
      context.push(isLogin ? '/login/otp' : '/register/otp');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}
