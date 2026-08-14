import 'package:flutter/material.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/finance/data/finance_repository.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class BankAccountScreen extends ConsumerStatefulWidget {
  const BankAccountScreen({super.key});

  @override
  ConsumerState<BankAccountScreen> createState() => _BankAccountScreenState();
}

class _BankAccountScreenState extends ConsumerState<BankAccountScreen> {
  final double _currentBalance = 15420.50;
  bool _isLoading = false;

  void _showWithdrawDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.semanticGrayNeutralBgWhite,
          title: Text('ระบุจำนวนเงินที่ต้องการถอน', style: AppTypography.heading6.copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            style: AppTypography.body1.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
            decoration: const InputDecoration(
              labelText: 'จำนวนเงิน (บาท)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ยกเลิก', style: AppTypography.label2.copyWith(color: AppColors.semanticErrorFgHigh)),
            ),
            ElevatedButton(
              onPressed: () {
                final amount = double.tryParse(controller.text);
                if (amount != null && amount > 0 && amount <= _currentBalance) {
                  Navigator.pop(context);
                  _processWithdrawal(amount);
                } else if (amount != null && amount > _currentBalance) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('ยอดเงินไม่เพียงพอ'), backgroundColor: AppColors.error),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.semanticSuccessBgHigh),
              child: Text('ยืนยัน', style: AppTypography.label2.copyWith(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _processWithdrawal(double amount) async {
    setState(() => _isLoading = true);

    try {
      await ref.read(financeRepositoryProvider).requestWithdrawal(amount);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.semanticGrayNeutralBgWhite,
          title: const AppIcon(AppIcons.circleCheckFill, color: AppColors.success, size: 64),
          content: Text(
            'ส่งคำขอถอนเงินจำนวน ฿${amount.toStringAsFixed(2)} สำเร็จ\n\nระบบจะโอนเข้าบัญชีของคุณภายใน 1-2 วันทำการ',
            textAlign: TextAlign.center,
            style: AppTypography.body2.copyWith(color: AppColors.semanticGrayNeutralFgHigh),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to profile
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.semanticSuccessBgHigh),
                child: Text('ตกลง', style: AppTypography.label1.copyWith(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('บัญชีธนาคาร', style: AppTypography.heading5.copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
        iconTheme: const IconThemeData(color: AppColors.semanticGrayNeutralFgHigh),
      ),
      body: _isLoading
          ? const Center(child: MassLoadingM(size: 72))
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ยอดเงินที่ถอนได้', style: AppTypography.body1.copyWith(color: Colors.white.withOpacity(0.7))),
                        const SizedBox(height: 8),
                        Text(
                          '฿${_currentBalance.toStringAsFixed(2)}',
                          style: AppTypography.heading1.copyWith(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text('บัญชีรับเงินของคุณ', style: AppTypography.heading6.copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
                  const SizedBox(height: 16),
                  Card(
                    color: AppColors.semanticGrayNeutralBgWhite,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: AppColors.semanticGrayNeutralBorderLightGray),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: AppColors.semanticGrayNeutralBgLightGray, borderRadius: BorderRadius.circular(8)),
                        child: const AppIcon(AppIcons.buildingLine, color: AppColors.primary),
                      ),
                      title: Text('ธนาคารไทยพาณิชย์ (SCB)', style: AppTypography.body2.copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
                      subtitle: Text('***-***-1234\nนาย สมชาย เข็มกลัด', style: AppTypography.body3.copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite)),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _isLoading ? null : _showWithdrawDialog,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.semanticSuccessBgHigh,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('ถอนเงินเลย', style: AppTypography.label1.copyWith(color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
