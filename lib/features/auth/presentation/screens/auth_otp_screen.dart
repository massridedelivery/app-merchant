import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/core/widgets/otp_input.dart';

class AuthOtpScreen extends StatefulWidget {
  final String flow;
  const AuthOtpScreen({super.key, this.flow = 'register'});

  @override
  State<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends State<AuthOtpScreen> {
  int _secondsRemaining = 174; // 02:54 starting
  Timer? _timer;

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

  void _onCompleted(String otp) {
    if (otp.length != 4) return;
    if (widget.flow == 'login') {
      context.go('/');
    } else {
      context.push('/register/email_password?flow=register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      appBar: AppBar(
        backgroundColor: AppColors.semanticGrayNeutralBgWhite,
        elevation: 0,
        leading: IconButton(
          icon: const AppIcon(AppIcons.arrowLeft,
              color: AppColors.semanticGrayNeutralFgHigh),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'ขั้นตอนที่ 2 จาก 7',
          style: AppTypography.heading6
              .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.circleQuestionLine,
                color: AppColors.semanticGrayNeutralFgHigh),
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
                'ใส่รหัส OTP ยืนยันตัวตน',
                style: AppTypography.heading4
                    .copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              ),
              const SizedBox(height: 8),
              Text(
                'ส่งรหัส OTP ไปยัง +66 892616445 ทาง SMS แล้ว',
                style: AppTypography.caption5
                    .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
              ),
              const SizedBox(height: 48),
              OtpInput(onCompleted: _onCompleted),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  _secondsRemaining > 0
                      ? 'ส่งใหม่ใน ${_formatTime(_secondsRemaining)}'
                      : 'ส่งรหัส OTP ใหม่',
                  style: AppTypography.caption5.copyWith(
                    color: _secondsRemaining > 0
                        ? AppColors.semanticGrayNeutralFgMidOnWhite
                        : AppColors.primary,
                    fontWeight:
                        _secondsRemaining > 0 ? FontWeight.normal : FontWeight.bold,
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
