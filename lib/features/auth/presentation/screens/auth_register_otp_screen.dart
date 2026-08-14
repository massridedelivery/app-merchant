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

class AuthRegisterOtpScreen extends ConsumerStatefulWidget {
  const AuthRegisterOtpScreen({super.key});

  @override
  ConsumerState<AuthRegisterOtpScreen> createState() =>
      _AuthRegisterOtpScreenState();
}

class _AuthRegisterOtpScreenState extends ConsumerState<AuthRegisterOtpScreen> {
  int _secondsRemaining = 174;
  Timer? _timer;
  bool _verifying = false;
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
    if (_verifying) return;
    final flow = ref.read(otpFlowProvider);
    if (flow == null) return;
    setState(() => _verifying = true);
    try {
      await ref.read(authProvider.notifier).confirmOtp(
            phone: flow.phone,
            otp: otp,
            refId: flow.refId,
            fullName: 'ร้านค้าใหม่',
          );
      // Success: the account/session now exists and the router redirects to '/'.
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        setState(() {
          _verifying = false;
          _attempt++; // reset the boxes for another try
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'ขั้นตอนที่ 2 จาก 7',
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
              Text(
                'ยืนยันตัวตนการสมัคร',
                style: AppTypography.heading3.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'ระบุรหัส OTP 6 หลัก ที่เราส่งไปยังเบอร์โทรศัพท์ของคุณเพื่อยืนยันตัวตนเบื้องต้น',
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 48),
              Container(
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: AppTheme.premiumCardDecoration,
                child: Column(
                  children: [
                    OtpInput(key: ValueKey(_attempt), onCompleted: _onCompleted),
                    const SizedBox(height: 40),
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
