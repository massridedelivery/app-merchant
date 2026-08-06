import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/auth/presentation/widgets/auth_step_indicator.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class AuthPersonalInfoScreen extends StatefulWidget {
  const AuthPersonalInfoScreen({super.key});

  @override
  State<AuthPersonalInfoScreen> createState() => _AuthPersonalInfoScreenState();
}

class _AuthPersonalInfoScreenState extends State<AuthPersonalInfoScreen> {
  String? _selectedNationality = 'Thailand';
  String? _selectedTitle;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  String? _selectedBirthDate;
  String? _selectedExpiryDate;
  final TextEditingController _addressController = TextEditingController();
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedSubdistrict;
  final TextEditingController _zipcodeController = TextEditingController();

  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_validateInput);
    _idController.addListener(_validateInput);
    _addressController.addListener(_validateInput);
    _zipcodeController.addListener(_validateInput);
  }

  void _validateInput() {
    setState(() {
      _isInputValid =
          _selectedTitle != null &&
          _nameController.text.isNotEmpty &&
          _idController.text.length >= 13 &&
          _selectedBirthDate != null &&
          _selectedExpiryDate != null &&
          _addressController.text.isNotEmpty &&
          _selectedProvince != null &&
          _selectedDistrict != null &&
          _selectedSubdistrict != null &&
          _zipcodeController.text.length == 5;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _addressController.dispose();
    _zipcodeController.dispose();
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

  Widget _buildDropdownCard(
    String? value,
    String hint,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: Text(
            hint,
            style: AppTypography.body2.copyWith(color: const Color(0xFF94A3B8)),
          ),
          isExpanded: true,
          icon: const AppIcon(AppIcons.chevronDownLine, color: Color(0xFF64748B)),
          items: items.map((String val) {
            return DropdownMenuItem<String>(
              value: val,
              child: Text(val, style: AppTypography.body2),
            );
          }).toList(),
          onChanged: onChanged,
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
                    const AuthStepIndicator(currentStep: 5),
                    const SizedBox(height: 32),
                    Text(
                      'ข้อมูลส่วนตัว',
                      style: AppTypography.heading3.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'กรุณาระบุข้อมูลตามบัตรประชาชนเพื่อใช้ในการยืนยันตัวตนและทำสัญญา',
                      style: AppTypography.body2.copyWith(
                        color: AppColors.semanticGrayNeutralFgMidOnWhite,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Card 1: Identity
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.premiumCardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppIcon(
                                AppIcons.circleUserLine,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ข้อมูลระบุตัวตน',
                                style: AppTypography.label1.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: Color(0xFFF1F5F9)),
                          _buildFieldLabel('สัญชาติ'),
                          _buildDropdownCard(
                            _selectedNationality,
                            'เลือกสัญชาติ',
                            ['Thailand', 'Other'],
                            (val) {
                              setState(() => _selectedNationality = val);
                              _validateInput();
                            },
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel('เลขประจำตัวประชาชน'),
                          TextField(
                            controller: _idController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '1-xxxx-xxxxx-xx-x',
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('คำนำหน้า'),
                                    _buildDropdownCard(
                                      _selectedTitle,
                                      'เลือก',
                                      ['นาย', 'นาง', 'นางสาว'],
                                      (val) {
                                        setState(() => _selectedTitle = val);
                                        _validateInput();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('ชื่อ-นามสกุล'),
                                    TextField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        hintText: 'สมชาย ใจดี',
                                        border: OutlineInputBorder(
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('วันเกิด (พ.ศ.)'),
                                    InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime(1990),
                                          firstDate: DateTime(1950),
                                          lastDate: DateTime.now(),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.light(
                                                  primary: AppColors.primary,
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (date != null) {
                                          setState(
                                            () => _selectedBirthDate =
                                                "${date.day}/${date.month}/${date.year + 543}",
                                          );
                                          _validateInput();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            AppIcon(
                                              AppIcons.calendarLine,
                                              size: 18,
                                              color: _selectedBirthDate != null
                                                  ? AppColors.primary
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _selectedBirthDate ?? 'วว/ดด/ปปปป',
                                              style: AppTypography.body2.copyWith(
                                                color: _selectedBirthDate != null
                                                    ? null
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('วันหมดอายุบัตร (พ.ศ.)'),
                                    InkWell(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: DateTime.now().add(const Duration(days: 365 * 5)),
                                          firstDate: DateTime.now(),
                                          lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
                                          builder: (context, child) {
                                            return Theme(
                                              data: Theme.of(context).copyWith(
                                                colorScheme: const ColorScheme.light(
                                                  primary: AppColors.primary,
                                                ),
                                              ),
                                              child: child!,
                                            );
                                          },
                                        );
                                        if (date != null) {
                                          setState(
                                            () => _selectedExpiryDate =
                                                "${date.day}/${date.month}/${date.year + 543}",
                                          );
                                          _validateInput();
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8FAFC),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: const Color(0xFFE2E8F0),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            AppIcon(
                                              AppIcons.calendarLine,
                                              size: 18,
                                              color: _selectedExpiryDate != null
                                                  ? AppColors.primary
                                                  : const Color(0xFF94A3B8),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              _selectedExpiryDate ?? 'วว/ดด/ปปปป',
                                              style: AppTypography.body2.copyWith(
                                                color: _selectedExpiryDate != null
                                                    ? null
                                                    : const Color(0xFF94A3B8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Card 2: Address
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: AppTheme.premiumCardDecoration,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const AppIcon(
                                AppIcons.houseLine,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ที่อยู่ตามทะเบียนบ้าน',
                                style: AppTypography.label1.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 32, color: Color(0xFFF1F5F9)),
                          _buildFieldLabel('ที่อยู่'),
                          TextField(
                            controller: _addressController,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'เลขที่บ้าน, หมู่ที่, ซอย, ถนน',
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel('จังหวัด'),
                          _buildDropdownCard(
                            _selectedProvince,
                            'เลือกจังหวัด',
                            ['กรุงเทพมหานคร', 'เชียงใหม่', 'ภูเก็ต'],
                            (val) {
                              setState(() => _selectedProvince = val);
                              _validateInput();
                            },
                          ),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('เขต/อำเภอ'),
                                    _buildDropdownCard(
                                      _selectedDistrict,
                                      'เลือก',
                                      ['เขตบางรัก', 'เขตปทุมวัน'],
                                      (val) {
                                        setState(() => _selectedDistrict = val);
                                        _validateInput();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildFieldLabel('แขวง/ตำบล'),
                                    _buildDropdownCard(
                                      _selectedSubdistrict,
                                      'เลือก',
                                      ['แขวงลุมพินี', 'แขวงสีลม'],
                                      (val) {
                                        setState(
                                          () => _selectedSubdistrict = val,
                                        );
                                        _validateInput();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildFieldLabel('รหัสไปรษณีย์'),
                          TextField(
                            controller: _zipcodeController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: '10xxx',
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                              ),
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
                          context.push('/register/bank_info');
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
                  child: const Text('ดำเนินการต่อ'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
