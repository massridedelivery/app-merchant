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

  Future<void> _submit(FinanceSummary summary) async {
    final amount = _amount;
    if (amount < _min) {
      _snack('ถอนขั้นต่ำ ฿${_min.toStringAsFixed(0)}', AppColors.semanticErrorFgHigh);
      return;
    }
    if (amount > summary.availableBalance) {
      _snack('ยอดเงินคงเหลือไม่พอ', AppColors.semanticErrorFgHigh);
      return;
    }
    final ok = await _confirmSheet(WithdrawalQuote.from(amount, summary));
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

  /// Grab/LINEMAN-style confirmation: a bottom sheet showing the amount, the
  /// fee/net breakdown, and the destination account before committing.
  Future<bool?> _confirmSheet(WithdrawalQuote quote) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20,
              20 + MediaQuery.of(sheetContext).viewPadding.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('ยืนยันการถอนเงิน',
                  style: AppTypography.heading6
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _breakdown(quote),
              const SizedBox(height: 16),
              _sheetBankRow(),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.schedule,
                      size: 16, color: AppColors.semanticGrayNeutralFgMidOnWhite),
                  const SizedBox(width: 6),
                  Text('โอนเข้าบัญชีภายใน 1–2 วันทำการ',
                      style: AppTypography.caption5.copyWith(
                          color: AppColors.semanticGrayNeutralFgMidOnWhite)),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(sheetContext, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('ยกเลิก',
                          style: AppTypography.label2.copyWith(
                              color: AppColors.semanticGrayNeutralFgHigh)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(sheetContext, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text('ยืนยันถอน ฿${quote.net.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _breakdown(WithdrawalQuote q) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _breakdownRow('ยอดที่ขอถอน', '฿${q.amount.toStringAsFixed(2)}'),
          const SizedBox(height: 10),
          _breakdownRow(
            'ค่าธรรมเนียม',
            q.isFree ? 'ฟรี' : '-฿${q.fee.toStringAsFixed(2)}',
            valueColor: q.isFree ? AppColors.success : null,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFE2E8F0)),
          ),
          _breakdownRow(
            'ยอดที่จะได้รับ',
            '฿${q.net.toStringAsFixed(2)}',
            emphasize: true,
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value,
      {bool emphasize = false, Color? valueColor}) {
    final labelStyle = emphasize
        ? AppTypography.label2.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
            fontWeight: FontWeight.bold)
        : AppTypography.body2.copyWith(
            color: AppColors.semanticGrayNeutralFgMidOnWhite);
    final valueStyle = emphasize
        ? AppTypography.heading6.copyWith(
            color: AppColors.primary, fontWeight: FontWeight.w900)
        : AppTypography.label3.copyWith(
            color: valueColor ?? AppColors.semanticGrayNeutralFgHigh,
            fontWeight: FontWeight.bold);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: labelStyle),
        Text(value, style: valueStyle),
      ],
    );
  }

  Widget _sheetBankRow() {
    final acc = ref.read(bankAccountProvider).valueOrNull;
    final display = (acc != null && acc.isLinked)
        ? '${acc.bankName} ${acc.accountNumberMasked}'
        : 'บัญชีธนาคารที่ลงทะเบียนไว้';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('เข้าบัญชี',
                    style: AppTypography.caption5.copyWith(
                        color: AppColors.semanticGrayNeutralFgMidOnWhite)),
                const SizedBox(height: 2),
                Text(display,
                    style: AppTypography.label3.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
        if (_amount >= _min) _netHint(s),
        const SizedBox(height: 12),
        _presets(available),
        const SizedBox(height: 20),
        _bankRow(),
        const SizedBox(height: 12),
        _autoPayoutCard(),
        const SizedBox(height: 20),
        _infoRow('ถอนขั้นต่ำ ฿100 ต่อครั้ง'),
        _infoRow('โอนเข้าบัญชีภายใน 1–2 วันทำการ'),
        _infoRow(_hasFee(s)
            ? 'มีค่าธรรมเนียม/ภาษีหัก ณ ที่จ่ายตอนถอน'
            : 'ไม่มีค่าธรรมเนียมการถอน'),
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

  bool _hasFee(FinanceSummary s) =>
      s.withdrawalFeeFlat > 0 ||
      s.withdrawalFeeRate > 0 ||
      s.withholdingTaxRate > 0;

  Widget _netHint(FinanceSummary s) {
    final q = WithdrawalQuote.from(_amount, s);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        'ยอดที่จะได้รับ ฿${q.net.toStringAsFixed(2)}'
        '${q.isFree ? ' · ไม่มีค่าธรรมเนียม' : ' · ค่าธรรมเนียม ฿${q.fee.toStringAsFixed(2)}'}',
        style: AppTypography.caption5.copyWith(color: AppColors.success),
      ),
    );
  }

  static const _weekdaysTh = [
    'อาทิตย์', 'จันทร์', 'อังคาร', 'พุธ', 'พฤหัสบดี', 'ศุกร์', 'เสาร์',
  ];
  String _dayName(int d) => (d >= 0 && d < 7) ? _weekdaysTh[d] : 'จันทร์';

  Future<void> _setAutoPayout(bool enabled) async {
    try {
      await ref.read(autoPayoutProvider.notifier).update(enabled: enabled);
    } on AppFailure catch (f) {
      if (mounted) _snack(f.message, AppColors.semanticErrorFgHigh);
    }
  }

  Widget _autoPayoutCard() {
    final async = ref.watch(autoPayoutProvider);
    final settings = async.valueOrNull ?? const AutoPayoutSettings();
    final busy = async.isLoading;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Icon(Icons.autorenew, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: settings.enabled ? () => _editSchedule(settings) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('โอนเงินอัตโนมัติทุกสัปดาห์',
                        style: AppTypography.label3.copyWith(
                            color: AppColors.semanticGrayNeutralFgHigh,
                            fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(
                      settings.enabled
                          ? 'โอนทุกวัน${_dayName(settings.dayOfWeek)} · ขั้นต่ำ ฿${settings.minAmount.toStringAsFixed(0)} · แตะเพื่อตั้งค่า'
                          : 'ให้ระบบโอนยอดคงเหลือเข้าบัญชีให้อัตโนมัติ',
                      style: AppTypography.caption5.copyWith(
                          color: AppColors.semanticGrayNeutralFgMidOnWhite),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Switch(
            value: settings.enabled,
            activeColor: AppColors.primary,
            onChanged: busy ? null : _setAutoPayout,
          ),
        ],
      ),
    );
  }

  /// Bottom sheet to pick the weekly payout day + minimum amount (SCRUM-77).
  Future<void> _editSchedule(AutoPayoutSettings current) async {
    int day = current.dayOfWeek;
    final minController =
        TextEditingController(text: current.minAmount.toStringAsFixed(0));
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20,
            20 + MediaQuery.of(sheetContext).viewInsets.bottom),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ตั้งค่าโอนอัตโนมัติ',
                  style: AppTypography.heading6
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                initialValue: day,
                decoration: const InputDecoration(
                    labelText: 'โอนทุกวัน', border: OutlineInputBorder()),
                items: [
                  for (var i = 0; i < 7; i++)
                    DropdownMenuItem(value: i, child: Text(_weekdaysTh[i])),
                ],
                onChanged: (v) => setSheet(() => day = v ?? day),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: minController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                    labelText: 'ยอดขั้นต่ำ (บาท)',
                    helperText: 'อย่างน้อย ฿100',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(sheetContext, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('บันทึก',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final minText = minController.text.trim();
    minController.dispose();
    if (result != true) return;
    final minAmount = double.tryParse(minText) ?? current.minAmount;
    if (minAmount < 100) {
      _snack('ยอดขั้นต่ำต้องไม่ต่ำกว่า ฿100', AppColors.semanticErrorFgHigh);
      return;
    }
    try {
      await ref
          .read(autoPayoutProvider.notifier)
          .update(dayOfWeek: day, minAmount: minAmount);
      if (mounted) _snack('บันทึกการตั้งค่าแล้ว', AppColors.success);
    } on AppFailure catch (f) {
      if (mounted) _snack(f.message, AppColors.semanticErrorFgHigh);
    }
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
                if (w.fee > 0)
                  Text('รับจริง ฿${w.netAmount.toStringAsFixed(2)}',
                      style: AppTypography.caption5
                          .copyWith(color: AppColors.success)),
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
            onPressed: (!valid || _submitting) ? null : () => _submit(s),
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
