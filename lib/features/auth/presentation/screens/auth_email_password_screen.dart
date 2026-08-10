import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthEmailPasswordScreen extends ConsumerStatefulWidget {
  final String flow;

  const AuthEmailPasswordScreen({super.key, this.flow = 'login'});

  @override
  ConsumerState<AuthEmailPasswordScreen> createState() =>
      _AuthEmailPasswordScreenState();
}

class _AuthEmailPasswordScreenState
    extends ConsumerState<AuthEmailPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateInput);
    _passwordController.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      _isInputValid =
          _emailController.text.isNotEmpty &&
          _passwordController.text.isNotEmpty;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isRegister = widget.flow == 'register';

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.chevronLeftLine, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isRegister ? 'ขั้นตอนที่ 2 จาก 7' : '',
          style: AppTypography.heading6.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Header
              Text(
                isRegister ? 'ตั้งค่าความปลอดภัย' : 'เข้าสู่ระบบด้วยอีเมล',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isRegister
                    ? 'กำหนดอีเมลและรหัสผ่านเพื่อใช้ในการเข้าสู่ระบบครั้งถัดไป'
                    : 'กรุณากรอกอีเมลและรหัสผ่านที่คุณได้ลงทะเบียนไว้กับเรา',
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),

              // Inputs Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.premiumCardDecoration,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'อีเมล',
                      style: AppTypography.label2.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: AppTypography.body1.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: const InputDecoration(
                        hintText: 'example@email.com',
                        filled: true,
                        fillColor: Color(0xFFF8FAFC),
                        border: OutlineInputBorder(borderSide: BorderSide.none),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'รหัสผ่าน',
                      style: AppTypography.label2.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: AppTypography.body1.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                      ),
                      cursorColor: AppColors.primary,
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: const OutlineInputBorder(
                          borderSide: BorderSide.none,
                        ),
                        suffixIcon: IconButton(
                          icon: AppIcon(
                            _obscurePassword
                                ? AppIcons.closedEyeLine
                                : AppIcons.openedEyeFill,
                            color: AppColors.semanticGrayNeutralFgLowOnWhite,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                    ),
                    if (!isRegister) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () => context.push('/forgot-password'),
                          child: Text(
                            'ลืมรหัสผ่าน?',
                            style: AppTypography.label2.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInputValid
                      ? () async {
                          if (isRegister) {
                            context.push('/register/business_info');
                          } else {
                            final ok = await ref
                                .read(authProvider.notifier)
                                .login(
                                  _emailController.text.trim(),
                                  _passwordController.text,
                                );
                            if (ok && context.mounted) {
                              context.go('/');
                            } else if (context.mounted) {
                              final err =
                                  ref.read(authProvider).error ?? 'เข้าสู่ระบบไม่สำเร็จ';
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(err)),
                              );
                            }
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
                    isRegister ? 'ถัดไป' : 'เข้าสู่ระบบ',
                    style: AppTypography.label1.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
