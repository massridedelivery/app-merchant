import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'dart:async';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthOtpScreen extends StatefulWidget {
  final String flow;
  const AuthOtpScreen({super.key, this.flow = 'register'});

  @override
  State<AuthOtpScreen> createState() => _AuthOtpScreenState();
}

class _AuthOtpScreenState extends State<AuthOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  int _secondsRemaining = 174; // 02:54 starting
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    for (int i = 0; i < 4; i++) {
        _controllers[i].addListener(() {
          if (mounted) setState(() {});
        });
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _onInputComplete() {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length == 4) {
       if (widget.flow == 'login') {
         context.go('/');
       } else {
         context.push('/register/email_password?flow=register');
       }
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
          icon: const AppIcon(AppIcons.arrowLeft, color: AppColors.semanticGrayNeutralFgHigh),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'ขั้นตอนที่ 2 จาก 7',
          style: AppTypography.heading6.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const AppIcon(AppIcons.circleQuestionLine, color: AppColors.semanticGrayNeutralFgHigh),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'ใส่รหัส OTP ยืนยันตัวตน',
                style: AppTypography.heading4.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
              ),
              const SizedBox(height: 8),
              Text(
                'ส่งรหัส OTP ไปยัง +66 892616445 ทาง SMS แล้ว',
                style: AppTypography.caption5.copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite),
              ),
              const SizedBox(height: 48),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    width: 60,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _focusNodes[index].hasFocus ? AppColors.primary : AppColors.semanticGrayNeutralBorderLightGray,
                        width: _focusNodes[index].hasFocus ? 2 : 1,
                      ),
                    ),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      showCursor: false,
                      style: AppTypography.heading3.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(1),
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          if (index < 3) {
                            FocusScope.of(context).requestFocus(_focusNodes[index + 1]);
                          } else {
                            _focusNodes[index].unfocus();
                            _onInputComplete();
                          }
                        } else if (value.isEmpty && index > 0) {
                          FocusScope.of(context).requestFocus(_focusNodes[index - 1]);
                        }
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  _secondsRemaining > 0 ? 'ส่งใหม่ใน ${_formatTime(_secondsRemaining)}' : 'ส่งรหัส OTP ใหม่',
                  style: AppTypography.caption5.copyWith(
                    color: _secondsRemaining > 0 ? AppColors.semanticGrayNeutralFgMidOnWhite : AppColors.primary,
                    fontWeight: _secondsRemaining > 0 ? FontWeight.normal : FontWeight.bold,
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
