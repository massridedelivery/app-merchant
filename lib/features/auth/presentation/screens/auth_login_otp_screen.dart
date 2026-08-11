import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/core/widgets/otp_input.dart';

class AuthLoginOtpScreen extends ConsumerStatefulWidget {
  const AuthLoginOtpScreen({super.key});

  @override
  ConsumerState<AuthLoginOtpScreen> createState() => _AuthLoginOtpScreenState();
}

class _AuthLoginOtpScreenState extends ConsumerState<AuthLoginOtpScreen> {
  int _secondsRemaining = 174;
  Timer? _timer;
  bool _submitting = false;
  int _attempt = 0; // bumping this clears the OtpInput after a failed try

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Future<void> _onCompleted(String otp) async {
    if (_submitting) return;
    final flow = ref.read(otpFlowProvider);
    if (flow == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(authProvider.notifier).confirmOtp(
            phone: flow.phone,
            otp: otp,
            refId: flow.refId,
          );
      // Success: the session is live and the router redirects to '/'.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() {
          _submitting = false;
          _attempt++;
        });
      }
    }
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Text(
                'ยืนยันตัวตน',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'กรุณากรอกรหัส OTP 4 หลัก ที่เราส่งไปยังเบอร์โทรศัพท์ของคุณ',
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite,
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: AppTheme.premiumCardDecoration,
                child: Column(
                  children: [
                    OtpInput(key: ValueKey(_attempt), onCompleted: _onCompleted),
                    const SizedBox(height: 24),
                    if (_submitting)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 8),
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    GestureDetector(
                      onTap: _secondsRemaining == 0
                          ? () {
                              setState(() => _secondsRemaining = 174);
                              _startTimer();
                            }
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: _secondsRemaining == 0
                              ? AppColors.primary.withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _secondsRemaining > 0
                              ? 'ส่งรหัสใหม่อีกครั้งใน ${_formatTime(_secondsRemaining)}'
                              : 'ส่งรหัส OTP ใหม่',
                          style: AppTypography.label2.copyWith(
                            color: _secondsRemaining > 0
                                ? AppColors.semanticGrayNeutralFgMidOnWhite
                                : AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
