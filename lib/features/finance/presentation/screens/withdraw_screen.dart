import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/errors/app_failure.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:merchant_app/features/finance/data/finance_repository.dart';
import 'package:merchant_app/features/finance/models/finance.dart';
import 'package:merchant_app/features/finance/presentation/screens/bank_account_screen.dart';
import 'package:merchant_app/features/finance/providers/finance_provider.dart';

/// Grab/LINEMAN-style withdrawal: available balance up top, amount with quick
/// presets, a single confirm CTA, and a recent-requests list. The backend
/// enforces a 100 THB minimum and one pending request at a time (SCRUM-60).
class WithdrawScreen extends ConsumerStatefulWidget {
  const WithdrawScreen({super.key});

  @override
  ConsumerState<WithdrawScreen> createState() => _WithdrawScreenState();
}

class _WithdrawScreenState extends ConsumerState<WithdrawScreen> {
  static const double _min = 100;
  final _amountController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _amount => double.tryParse(_amountController.text.trim()) ?? 0;

  Future<void> _submit(double available) async {
    final amount = _amount;
    if (amount < _min) {
      _snack('ถอนขั้นต่ำ ฿${_min.toStringAsFixed(0)}', AppColors.semanticErrorFgHigh);
      return;
    }
    if (amount > available) {
      _snack('ยอดเงินคงเหลือไม่พอ', AppColors.semanticErrorFgHigh);
      return;
    }
    final ok = await _confirmDialog(amount);
    if (ok != true) return;

    setState(() => _submitting = true);
    try {
      await ref.read(financeRepositoryProvider).requestWithdrawal(amount);
      ref.invalidate(financeSummaryProvider);
      ref.invalidate(withdrawalsProvider);
      if (!mounted) return;
      _amountController.clear();
      await _successDialog(amount);
    } on AppFailure catch (f) {
      if (mounted) _snack(f.message, AppColors.semanticErrorFgHigh);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color),
    );
  }

  Future<bool?> _confirmDialog(double amount) => showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('ยืนยันการถอนเงิน'),
          content: Text(
            'ถอนเงินจำนวน ฿${amount.toStringAsFixed(2)} '
            'เข้าบัญชีธนาคารที่ลงทะเบียนไว้\n\n'
            'ระบบจะโอนภายใน 1–2 วันทำการ',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก')),
            ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ยืนยัน')),
          ],
        ),
      );

  Future<void> _successDialog(double amount) => showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle,
                  color: AppColors.success, size: 56),
              const SizedBox(height: 12),
              Text('ส่งคำขอถอนเงินแล้ว',
                  style: AppTypography.heading6
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                '฿${amount.toStringAsFixed(2)} · โอนเข้าบัญชีภายใน 1–2 วันทำการ',
                textAlign: TextAlign.center,
                style: AppTypography.body2.copyWith(
                    color: AppColors.semanticGrayNeutralFgMidOnWhite),
              ),
            ],
          ),
          actions: [
            Center(
              child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ตกลง')),
            ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(financeSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      appBar: AppBar(
        title: Text('แจ้งถอนเงิน',
            style: AppTypography.heading5
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme:
            const IconThemeData(color: AppColors.semanticGrayNeutralFgHigh),
      ),
      body: summaryAsync.when(
        loading: () => const Center(child: MassLoadingM(size: 72)),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (summary) => _body(summary),
      ),
      bottomNavigationBar: summaryAsync.maybeWhen(
        data: (s) => _confirmBar(s),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _body(FinanceSummary s) {
    final available = s.availableBalance;
    return ListView(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewPadding.bottom),
      children: [
        _balanceCard(available, s),
        if (s.pendingWithdrawal > 0) ...[
          const SizedBox(height: 12),
          _pendingBanner(s.pendingWithdrawal),
        ],
        const SizedBox(height: 20),
        Text('จำนวนที่ต้องการถอน',
            style: AppTypography.label2
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
        const SizedBox(height: 8),
        _amountField(),
        const SizedBox(height: 12),
        _presets(available),
        const SizedBox(height: 20),
        _bankRow(),
        const SizedBox(height: 20),
        _infoRow('ถอนขั้นต่ำ ฿100 ต่อครั้ง'),
        _infoRow('โอนเข้าบัญชีภายใน 1–2 วันทำการ'),
        _infoRow('ทำรายการถอนได้ครั้งละ 1 คำขอ'),
        const SizedBox(height: 24),
        _historySection(),
      ],
    );
  }

  Widget _balanceCard(double available, FinanceSummary s) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.success, Color(0xFF0E9F6E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ยอดเงินที่ถอนได้',
              style: AppTypography.label3.copyWith(color: Colors.white)),
          const SizedBox(height: 6),
          Text('฿${available.toStringAsFixed(2)}',
              style: AppTypography.heading2.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _pendingBanner(double pending) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, color: AppColors.warning, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'มีคำขอถอนเงินค้างอยู่ ฿${pending.toStringAsFixed(2)} '
              '— รอดำเนินการก่อนถอนรายการใหม่',
              style: AppTypography.caption5
                  .copyWith(color: const Color(0xFF92400E)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _amountField() {
    return TextField(
      controller: _amountController,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
      ],
      onChanged: (_) => setState(() {}),
      style: AppTypography.heading4.copyWith(fontWeight: FontWeight.bold),
      decoration: const InputDecoration(
        prefixText: '฿ ',
        hintText: '0',
      ),
    );
  }

  Widget _presets(double available) {
    final options = <double>[500, 1000, 2000];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in options)
          if (v <= available) _presetChip('฿${v.toStringAsFixed(0)}', v),
        if (available >= _min) _presetChip('ถอนทั้งหมด', available),
      ],
    );
  }

  Widget _presetChip(String label, double value) {
    return GestureDetector(
      onTap: () => setState(
          () => _amountController.text = value.toStringAsFixed(0)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: AppTypography.label3.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _bankRow() {
    return InkWell(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const BankAccountScreen())),
      borderRadius: BorderRadius.circular(12),
      child: Container(
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
                  Text('บัญชีธนาคารที่รับเงิน',
                      style: AppTypography.label3.copyWith(
                          color: AppColors.semanticGrayNeutralFgHigh,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text('แตะเพื่อจัดการบัญชีรับเงิน',
                      style: AppTypography.caption5.copyWith(
                          color: AppColors.semanticGrayNeutralFgMidOnWhite)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF94A3B8)),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 16, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
                style: AppTypography.caption5.copyWith(
                    color: AppColors.semanticGrayNeutralFgMidOnWhite)),
          ),
        ],
      ),
    );
  }

  Widget _historySection() {
    final async = ref.watch(withdrawalsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ประวัติการถอนเงิน',
            style: AppTypography.label2
                .copyWith(color: AppColors.semanticGrayNeutralFgHigh)),
        const SizedBox(height: 12),
        async.when(
          loading: () => const Center(child: MassLoadingM(size: 44)),
          error: (e, _) => Text('โหลดประวัติไม่สำเร็จ',
              style: AppTypography.caption5.copyWith(
                  color: AppColors.semanticGrayNeutralFgMidOnWhite)),
          data: (list) => list.isEmpty
              ? Text('ยังไม่มีประวัติการถอนเงิน',
                  style: AppTypography.caption5.copyWith(
                      color: AppColors.semanticGrayNeutralFgMidOnWhite))
              : Column(children: list.map(_historyTile).toList()),
        ),
      ],
    );
  }

  Widget _historyTile(WithdrawalRequest w) {
    final (label, color) = _statusStyle(w.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('฿${w.amount.toStringAsFixed(2)}',
                    style: AppTypography.label2.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.bold)),
                if (w.createdAt != null)
                  Text(w.createdAt!.split('T').first,
                      style: AppTypography.caption5.copyWith(
                          color: AppColors.semanticGrayNeutralFgMidOnWhite)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(label,
                style: AppTypography.caption5
                    .copyWith(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  (String, Color) _statusStyle(String status) {
    switch (status.toUpperCase()) {
      case 'COMPLETED':
      case 'PAID':
      case 'SUCCESS':
        return ('สำเร็จ', AppColors.success);
      case 'FAILED':
      case 'REJECTED':
        return ('ไม่สำเร็จ', AppColors.semanticErrorFgHigh);
      default:
        return ('รอดำเนินการ', AppColors.warning);
    }
  }

  Widget _confirmBar(FinanceSummary s) {
    final available = s.availableBalance;
    final valid = _amount >= _min && _amount <= available && s.canWithdraw;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: (!valid || _submitting) ? null : () => _submit(available),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    s.canWithdraw
                        ? 'ยืนยันการถอนเงิน'
                        : 'ยังถอนเงินไม่ได้ในขณะนี้',
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}
