import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:merchant_app/features/finance/data/finance_repository.dart';
import 'package:merchant_app/features/finance/models/bank_account.dart';
import 'package:merchant_app/features/finance/providers/finance_provider.dart';

/// Manage the payout bank account (SCRUM-60). The full account number is never
/// returned, so editing means re-typing it; a PUT always sends all three
/// fields, and only the bank code is sent (the server resolves the name).
class BankAccountScreen extends ConsumerStatefulWidget {
  const BankAccountScreen({super.key});

  @override
  ConsumerState<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends ConsumerState<BankAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountNumberController = TextEditingController();
  final _accountNameController = TextEditingController();
  String? _bankCode;
  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _accountNumberController.dispose();
    _accountNameController.dispose();
    super.dispose();
  }

  /// Seed the form from the current account once (bank + name only — the number
  /// can't be read back).
  void _prefill(BankAccount acc) {
    if (_prefilled) return;
    _prefilled = true;
    if (acc.bankCode.isNotEmpty &&
        kThaiBanks.any((b) => b.code == acc.bankCode)) {
      _bankCode = acc.bankCode;
    }
    _accountNameController.text = acc.accountName;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(financeRepositoryProvider).updateBankAccount(
            bankCode: _bankCode!,
            accountNumber: _accountNumberController.text.trim(),
            accountName: _accountNameController.text.trim(),
          );
      ref.invalidate(bankAccountProvider);
      if (!mounted) return;
      _snack('บันทึกบัญชีธนาคารแล้ว', AppColors.success);
      Navigator.pop(context, true);
    } on AppFailure catch (f) {
      if (mounted) _snack(f.message, AppColors.error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accountAsync = ref.watch(bankAccountProvider);
    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      appBar: AppBar(
        title: Text('บัญชีธนาคาร',
            style: AppTypography.heading5
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
        iconTheme:
            const IconThemeData(color: AppColors.semanticGrayNeutralFgHigh),
      ),
      body: accountAsync.when(
        loading: () => const Center(child: MassLoadingM(size: 72)),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (acc) {
          _prefill(acc);
          return _form(acc);
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _saving ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Text('บันทึกบัญชี',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  Widget _form(BankAccount acc) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (acc.isLinked) _currentCard(acc),
          const SizedBox(height: 20),
          Text('บัญชีรับเงิน',
              style: AppTypography.label2
                  .copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
          const SizedBox(height: 12),
          _bankDropdown(),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: 'เลขที่บัญชี',
              hintText: acc.isLinked ? 'กรอกเลขบัญชีใหม่ทั้งหมด' : null,
              border: const OutlineInputBorder(),
            ),
            validator: (v) {
              final s = v?.trim() ?? '';
              if (s.isEmpty) return 'กรุณากรอกเลขที่บัญชี';
              if (s.length < 10 || s.length > 15) {
                return 'เลขบัญชีต้องมี 10–15 หลัก';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _accountNameController,
            decoration: const InputDecoration(
              labelText: 'ชื่อบัญชี',
              border: OutlineInputBorder(),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'กรุณากรอกชื่อบัญชี' : null,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.lock_outline,
                  size: 16, color: AppColors.semanticGrayNeutralFgMidOnWhite),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'เพื่อความปลอดภัย ระบบไม่แสดงเลขบัญชีเต็ม '
                  'การแก้ไขต้องกรอกเลขบัญชีใหม่ทั้งหมด',
                  style: AppTypography.caption5.copyWith(
                      color: AppColors.semanticGrayNeutralFgMidOnWhite),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _currentCard(BankAccount acc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(acc.bankName.isNotEmpty ? acc.bankName : 'บัญชีที่ผูกไว้',
                    style: AppTypography.label3.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text('${acc.accountNumberMasked}  ·  ${acc.accountName}',
                    style: AppTypography.caption5.copyWith(
                        color: AppColors.semanticGrayNeutralFgMidOnWhite)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bankDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _bankCode,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'ธนาคาร',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final b in kThaiBanks)
          DropdownMenuItem(value: b.code, child: Text(b.name)),
      ],
      onChanged: _saving ? null : (v) => setState(() => _bankCode = v),
      validator: (v) => (v == null || v.isEmpty) ? 'กรุณาเลือกธนาคาร' : null,
    );
  }
}
