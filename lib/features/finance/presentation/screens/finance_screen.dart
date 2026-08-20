import 'package:flutter/material.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/finance/models/finance.dart';
import 'package:merchant_app/features/finance/providers/finance_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class FinanceScreen extends ConsumerStatefulWidget {
  const FinanceScreen({super.key});

  @override
  ConsumerState<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends ConsumerState<FinanceScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedEarningsFilter = 0;
  final _earningsFilters = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ปีนี้'];

  EarningsPeriod _periodFor(FinanceEarnings e, int i) {
    switch (i) {
      case 1:
        return e.thisWeek;
      case 2:
        return e.thisMonth;
      case 3:
        return e.thisYear;
      default:
        return e.today;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ──────────────────────────────────────
            _buildHeader(),
            // ─── Tabs ────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              child: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: const Color(0xFF94A3B8),
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: AppColors.primary.withOpacity(0.1),
                ),
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelPadding: const EdgeInsets.symmetric(horizontal: 16),
                overlayColor: WidgetStateProperty.all(Colors.transparent),
                splashFactory: NoSplash.splashFactory,
                dividerColor: Colors.transparent,
                labelStyle: AppTypography.label2.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                unselectedLabelStyle: AppTypography.label3,
                tabs: const [
                  Tab(text: 'สรุป'),
                  Tab(text: 'รายการ'),
                  Tab(text: 'ยอดเงิน'),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildSummarytab(),
                  _buildTransactionsTab(),
                  _buildEarningsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'การเงิน',
            style: AppTypography.heading4.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
              fontWeight: FontWeight.w900,
            ),
          ),
          Row(
            children: [
              _headerIconBtn(const AppIcon(AppIcons.stackPaperLine)),
              const SizedBox(width: 8),
              // No QR scanner equivalent in the SVG icon set yet.
              _headerIconBtn(const Icon(Icons.qr_code_scanner_rounded)),
              const SizedBox(width: 8),
              _headerIconBtn(const AppIcon(AppIcons.circleQuestionLine)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerIconBtn(Widget icon) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: IconTheme(
          data: const IconThemeData(size: 20, color: Color(0xFF475569)),
          child: icon,
        ),
      ),
    );
  }

  // ─── SUMMARY TAB ──────────────────────────────────────────────────────────

  Widget _buildSummarytab() {
    final summaryAsync = ref.watch(financeSummaryProvider);
    return summaryAsync.when(
      loading: () => const Center(
        child: MassLoadingM(size: 72),
      ),
      error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (summary) => RefreshIndicator(
        onRefresh: () => ref.read(financeSummaryProvider.notifier).fetch(),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            children: [
              _buildSummaryCard(summary),
              const SizedBox(height: 16),
              _summaryStatRow('รายได้สะสมทั้งหมด', summary.lifetimeEarnings),
              _summaryStatRow('ถอนออกไปแล้ว', summary.totalWithdrawn),
              if (summary.lifetimeEarnings == 0) ...[
                const SizedBox(height: 24),
                _buildEmptyFinanceIllustration(
                  title: 'ยอดขายยังไม่พร้อมแสดงผล',
                  subtitle: 'ข้อมูลสรุปจะแสดงหลังจากเริ่มรับออเดอร์',
                  icon: '🚀',
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryStatRow(String label, double value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.body2
                  .copyWith(color: AppColors.semanticGrayNeutralFgMidOnWhite)),
          Text('฿${value.toStringAsFixed(2)}',
              style: AppTypography.label1.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(FinanceSummary s) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.semanticGrayNeutralBgWhite,
            AppColors.semanticGrayNeutralBgWhite,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.semanticGrayNeutralFgHigh.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'ยอดคงเหลือในระบบ',
                style: AppTypography.label2.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  AppIcons.chevronRightLine,
                  color: AppColors.semanticGrayNeutralBgWhite,
                  size: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '฿${s.balance.toStringAsFixed(2)}',
            style: AppTypography.heading2.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  'ถอนได้',
                  '฿${s.availableBalance.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _summaryMetric(
                  'รอถอน',
                  '฿${s.pendingWithdrawal.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _summaryMetric(
                  'รายได้สะสม',
                  '฿${s.lifetimeEarnings.toStringAsFixed(0)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption4.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.label1.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
          ),
        ),
      ],
    );
  }

  // ─── TRANSACTIONS TAB ─────────────────────────────────────────────────────

  Widget _buildTransactionsTab() {
    final filters = ['วันนี้', 'บริการ', 'วิธีการชำระเงิน', 'ประเภท'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Filter chips
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: filters.map((f) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    child: Row(
                      children: [
                        Text(
                          f,
                          style: AppTypography.body3.copyWith(
                            color: AppColors.semanticGrayNeutralFgHigh,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const AppIcon(
                          AppIcons.chevronDownLine,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF1F5F9)),
        Expanded(child: _buildTransactionsList()),
      ],
    );
  }

  Widget _buildTransactionsList() {
    final txAsync = ref.watch(financeTransactionsProvider);
    return txAsync.when(
      loading: () => const Center(child: MassLoadingM(size: 72)),
      error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (page) {
        if (page.items.isEmpty) {
          return _buildEmptyFinanceIllustration(
            title: 'ไม่มีรายการชำระเงิน',
            subtitle: 'รายการจะปรากฏเมื่อลูกค้าชำระเงินสำเร็จ',
            icon: '💸',
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(financeTransactionsProvider.notifier).fetch(),
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
                  page.hasMore) {
                ref.read(financeTransactionsProvider.notifier).loadMore();
              }
              return false;
            },
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: page.items.length + (page.hasMore ? 1 : 0),
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (_, i) {
                if (i >= page.items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: MassLoadingM(size: 40)),
                  );
                }
                final t = page.items[i];
                final negative = t.amount < 0;
                return ListTile(
                  title: Text(
                    t.description.isEmpty ? t.type : t.description,
                    style: AppTypography.body2.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh),
                  ),
                  subtitle: Text(
                    [t.type, t.createdAt].where((s) => s != null && s.isNotEmpty).join(' · '),
                    style: AppTypography.caption5
                        .copyWith(color: const Color(0xFF64748B)),
                  ),
                  trailing: Text(
                    '${negative ? '-' : '+'}฿${t.amount.abs().toStringAsFixed(2)}',
                    style: AppTypography.label1.copyWith(
                      color: negative
                          ? AppColors.primary
                          : AppColors.semanticSuccessFgHigh,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ─── EARNINGS TAB ─────────────────────────────────────────────────────────

  Widget _buildEarningsTab() {
    final earningsAsync = ref.watch(financeEarningsProvider);
    return earningsAsync.when(
      loading: () => const Center(child: MassLoadingM(size: 72)),
      error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (earnings) {
        final p = _periodFor(earnings, _selectedEarningsFilter);
        return RefreshIndicator(
          onRefresh: () => ref.read(financeEarningsProvider.notifier).fetch(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _earningsFilters.asMap().entries.map((entry) {
                          final i = entry.key;
                          final selected = i == _selectedEarningsFilter;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedEarningsFilter = i),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? AppColors.primary.withOpacity(0.1)
                                      : Colors.white,
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.primary.withOpacity(0.1)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  entry.value,
                                  style: AppTypography.label2.copyWith(
                                    color: selected
                                        ? AppColors.primary
                                        : const Color(0xFF64748B),
                                    fontWeight: selected
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('รายได้สุทธิ',
                              style: AppTypography.caption5.copyWith(
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          Text('฿${p.netEarnings.toStringAsFixed(2)}',
                              style: AppTypography.heading2.copyWith(
                                  color: AppColors.semanticGrayNeutralFgHigh,
                                  fontWeight: FontWeight.w900)),
                          Text('${p.orders} ออเดอร์',
                              style: AppTypography.caption5.copyWith(
                                  color: const Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _earningsRow('ยอดขายอาหาร', p.grossFood),
                    _earningsRow('ค่าคอมมิชชั่นแพลตฟอร์ม', -p.commission),
                    _earningsRow('ภาษีหัก ณ ที่จ่าย', -p.withholdingTax),
                    const Divider(height: 24, color: Color(0xFFF1F5F9)),
                    _earningsRow('รายได้สุทธิ', p.netEarnings, bold: true),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _earningsRow(String label, double value, {bool bold = false}) {
    final negative = value < 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: AppTypography.body2.copyWith(
                  color: bold
                      ? AppColors.semanticGrayNeutralFgHigh
                      : AppColors.semanticGrayNeutralFgMidOnWhite,
                  fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '${negative ? '-' : ''}฿${value.abs().toStringAsFixed(2)}',
            style: AppTypography.label1.copyWith(
              color: negative
                  ? AppColors.primary
                  : AppColors.semanticGrayNeutralFgHigh,
              fontWeight: bold ? FontWeight.w900 : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyFinanceIllustration({
    required String title,
    required String subtitle,
    String icon = '🖥️',
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    spreadRadius: 10,
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Text(icon, style: const TextStyle(fontSize: 48)),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.heading5.copyWith(
                color: AppColors.semanticGrayNeutralFgHigh,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.body3.copyWith(
                color: const Color(0xFF64748B),
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
