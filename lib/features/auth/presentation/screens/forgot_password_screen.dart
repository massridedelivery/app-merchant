import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() {
      setState(() {
        _isInputValid =
            _emailController.text.contains('@') &&
            _emailController.text.contains('.');
      });
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(
            AppIcons.chevronLeftLine,
            size: 20,
            color: Colors.black,
          ),
          onPressed: () => context.pop(),
        ),
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
                'ลืมรหัสผ่าน?',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ระบุอีเมลที่คุณใช้ลงทะเบียนเพื่อรับลิงก์สำหรับตั้งรหัสผ่านใหม่',
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),

              // Input Card
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
                    const SizedBox(height: 16),
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
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isInputValid
                      ? () {
                          // Show success dialog or snackbar
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'ส่งลิงก์ตั้งค่ารหัสผ่านใหม่แล้ว',
                                style: AppTypography.label1.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          );
                          context.pop();
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
                    'ส่งลิงก์ตั้งรหัสผ่านใหม่',
                    style: AppTypography.label1.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
