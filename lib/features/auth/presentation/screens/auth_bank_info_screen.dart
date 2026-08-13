import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/presentation/widgets/auth_step_indicator.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthBankInfoScreen extends StatefulWidget {
  const AuthBankInfoScreen({super.key});

  @override
  State<AuthBankInfoScreen> createState() => _AuthBankInfoScreenState();
}

class _AuthBankInfoScreenState extends State<AuthBankInfoScreen> {
  final TextEditingController _accountOwnerController = TextEditingController(
    text: '',
  );
  String? _selectedBank;
  final TextEditingController _accountNumberController =
      TextEditingController();

  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();
    _accountOwnerController.addListener(_validateInput);
    _accountNumberController.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      _isInputValid =
          _accountOwnerController.text.isNotEmpty &&
          _selectedBank != null &&
          _accountNumberController.text.length >= 10;
    });
  }

  @override
  void dispose() {
    _accountOwnerController.dispose();
    _accountNumberController.dispose();
    super.dispose();
  }

  Widget _buildFieldLabel(String label, {bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: RichText(
        text: TextSpan(
          text: label,
          style: AppTypography.label2.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
            fontWeight: FontWeight.bold,
          ),
          children: isRequired
              ? [
                  TextSpan(
                    text: ' *',
                    style: AppTypography.label2.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ]
              : [],
        ),
      ),
    );
  }

  Widget _buildBankCard(
    String name,
    String iconUrl,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const AppIcon(
                AppIcons.buildingLine,
                size: 18,
                color: Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: AppTypography.body2.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const AppIcon(
                AppIcons.circleCheckFill,
                color: AppColors.primary,
                size: 20,
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
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AuthStepIndicator(currentStep: 6),
                    const SizedBox(height: 32),
                    Text(
                      'ข้อมูลธนาคาร',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'รายได้จากการขายจะถูกโอนเข้าบัญชีธนาคารที่คุณระบุไว้ด้านล่างนี้',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.semanticGrayNeutralFgMidOnWhite,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card 1: Bank Details
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.premiumCardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppIcon(
                                AppIcons.buildingLine,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'รายละเอียดบัญชี',
                                style: AppTypography.label1.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: Color(0xFFF1F5F9)),
                          _buildFieldLabel('เจ้าของบัญชี'),
                          TextField(
                            controller: _accountOwnerController,
                            decoration: InputDecoration(
                              labelStyle: AppTypography.body2,
                              hintText: 'ระบุชื่อภาษาอังกฤษตามสมุดบัญชี',
                              hintStyle: AppTypography.body2.copyWith(
                                color: const Color(0xFF94A3B8),
                              ),
                              border: const OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel('ธนาคาร'),
                          _buildBankCard(
                            'กสิกรไทย (K-Bank)',
                            '',
                            _selectedBank == 'กสิกรไทย',
                            () {
                              setState(() => _selectedBank = 'กสิกรไทย');
                              _validateInput();
                            },
                          ),
                          _buildBankCard(
                            'ไทยพาณิชย์ (SCB)',
                            '',
                            _selectedBank == 'ไทยพาณิชย์',
                            () {
                              setState(() => _selectedBank = 'ไทยพาณิชย์');
                              _validateInput();
                            },
                          ),
                          _buildBankCard(
                            'กรุงไทย (KTB)',
                            '',
                            _selectedBank == 'กรุงไทย',
                            () {
                              setState(() => _selectedBank = 'กรุงไทย');
                              _validateInput();
                            },
                          ),
                          const SizedBox(height: 12),
                          _buildFieldLabel('เลขที่บัญชี'),
                          TextField(
                            controller: _accountNumberController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '000-0-00000-0',
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Card 2: Document
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.premiumCardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'เอกสารที่ต้องใช้',
                            style: AppTypography.label1.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: Column(
                              children: [
                                const AppIcon(
                                  AppIcons.photoLine,
                                  color: AppColors.primary,
                                  size: 32,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'อัปโหลดรูปหน้าสมุดบัญชี',
                                  style: AppTypography.label2.copyWith(
                                    color: AppColors.semanticGrayNeutralFgHigh,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'JPG, PNG หรือ PDF (ไม่เกิน 5MB)',
                                  style: AppTypography.caption5.copyWith(
                                    color: const Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppIcon(
                                AppIcons.circleInformationLine,
                                size: 16,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'ชื่อบัญชีธนาคารต้องตรงกับชื่อที่ใช้ลงทะเบียนสมัครสมาชิก',
                                  style: AppTypography.caption5.copyWith(
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Card 3: Finance Manager Summary
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
                                'ผู้จัดการฝ่ายการเงิน',
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
                          const Divider(height: 32, color: Color(0xFFF1F5F9)),
                          Text(
                            'นาย ธนนันต์ อนุรักษ์',
                            style: AppTypography.body2,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '+66 892616445 | bankzapse@gmail.com',
                            style: AppTypography.caption5.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                      ? () {
                          context.push('/register/confirmation');
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
                  child: const Text('บันทึกและดำเนินการต่อ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
