import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _savePassword = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) return;

    final success = await ref.read(authProvider.notifier).login(
          _usernameController.text.trim(),
          _passwordController.text,
        );

    if (success && mounted) {
      context.go('/');
    } else if (mounted) {
      final error = ref.read(authProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error ?? 'Login failed'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isInputValid = _usernameController.text.isNotEmpty && _passwordController.text.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/welcome');
            }
          },
        ),
        title: Text(
          'เข้าสู่ระบบ',
          style: AppTypography.heading5.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.circleQuestionLine, color: AppColors.textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ระบุชื่อผู้ใช้งานของคุณ',
                style: AppTypography.label2.copyWith(color: AppColors.semanticGrayNeutralFgHigh, fontWeight: FontWeight.normal),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _usernameController.text.isNotEmpty ? AppColors.primary : AppColors.semanticGrayNeutralBorderLightGray,
                  ),
                ),
                child: TextField(
                  controller: _usernameController,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.body2.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'รหัสผ่าน',
                style: AppTypography.label2.copyWith(color: AppColors.semanticGrayNeutralFgHigh, fontWeight: FontWeight.normal),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _passwordController.text.isNotEmpty ? AppColors.primary : AppColors.semanticGrayNeutralBorderLightGray,
                  ),
                ),
                child: TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  style: AppTypography.body2.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                  decoration: InputDecoration(
                    hintText: 'ระบุรหัสผ่าน',
                    hintStyle: AppTypography.body2.copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    suffixIcon: IconButton(
                      icon: AppIcon(
                        _obscurePassword ? AppIcons.closedEyeLine : AppIcons.openedEyeFill,
                        color: AppColors.textPrimary,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                   SizedBox(
                     height: 24,
                     width: 24,
                     child: Checkbox(
                       value: _savePassword,
                       onChanged: (value) {
                         setState(() {
                           _savePassword = value ?? false;
                         });
                       },
                       activeColor: AppColors.primary,
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                     ),
                   ),
                   const SizedBox(width: 8),
                   Text('บันทึกรหัสผ่าน', style: AppTypography.body2.copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
                ],
              ),
              const SizedBox(height: 24),
              RichText(
                  text: TextSpan(
                    style: AppTypography.caption5.copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
                    children: [
                      const TextSpan(text: 'ลืม '),
                      TextSpan(text: 'ชื่อผู้ใช้งาน', style: AppTypography.caption5.copyWith(color: AppColors.semanticSecondaryFgHigh)),
                      const TextSpan(text: ' หรือ '),
                      TextSpan(text: 'รหัสผ่าน', style: AppTypography.caption5.copyWith(color: AppColors.semanticSecondaryFgHigh)),
                      const TextSpan(text: ' ของคุณ?'),
                    ],
                  ),
                ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: (!authState.isLoading && isInputValid) ? _login : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: isInputValid ? AppColors.primary : AppColors.background, 
                  foregroundColor: isInputValid ? Colors.white : AppColors.semanticGrayNeutralFgMidOnWhite,
                  disabledBackgroundColor: AppColors.background,
                  disabledForegroundColor: AppColors.semanticGrayNeutralFgMidOnWhite,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: authState.isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'เข้าสู่ระบบ',
                        style: AppTypography.label2.copyWith(color: isInputValid ? Colors.white : AppColors.semanticGrayNeutralFgMidOnWhite),
                      ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                   context.push('/register/phone');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: AppColors.primaryDark,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text('เข้าสู่ระบบด้วยโทรศัพท์', style: AppTypography.label2.copyWith(color: AppColors.primaryDark)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
