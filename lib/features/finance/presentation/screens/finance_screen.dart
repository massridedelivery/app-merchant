import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
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
  final _earningsFilters = ['วันนี้', 'เมื่อวาน', 'สัปดาห์นี้', 'เดือนนี้'];

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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
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
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
      error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
      data: (summary) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
        child: Column(
          children: [
            _buildSummaryCard(summary),
            const SizedBox(height: 24),
            _buildEmptyFinanceIllustration(
              title: 'ยอดขายยังไม่พร้อมแสดงผล',
              subtitle: 'ข้อมูลสรุปจะแสดงหลังจากเริ่มรับออเดอร์',
              icon: '🚀',
            ),
          ],
        ),
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
                'รายได้รวมทั้งหมด',
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
            '฿${s.totalRevenue.toStringAsFixed(2)}',
            style: AppTypography.heading2.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _summaryMetric('คำสั่งซื้อ', '${s.totalOrders}')),
              Expanded(
                child: _summaryMetric(
                  'เฉลี่ยต่อบิล',
                  '฿${s.avgOrderValue.toStringAsFixed(0)}',
                ),
              ),
              Expanded(
                child: _summaryMetric(
                  'รอรับเงิน',
                  '฿${s.pendingPayout.toStringAsFixed(0)}',
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
        Expanded(
          child: _buildEmptyFinanceIllustration(
            title: 'ไม่มีรายการชำระเงิน',
            subtitle: 'รายการจะปรากฏเมื่อลูกค้าชำระเงินสำเร็จ',
            icon: '💸',
          ),
        ),
      ],
    );
  }

  // ─── EARNINGS TAB ─────────────────────────────────────────────────────────

  Widget _buildEarningsTab() {
    return SingleChildScrollView(
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              children: [
                // Top row: calendar + filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          shape: BoxShape.circle,
                        ),
                        child: const AppIcon(
                          AppIcons.calendarLine,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ..._earningsFilters.asMap().entries.map((entry) {
                        final i = entry.key;
                        final label = entry.value;
                        final selected = i == _selectedEarningsFilter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedEarningsFilter = i),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
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
                                label,
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
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Amounts
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ยอดเงินสุทธิ',
                              style: AppTypography.caption5.copyWith(
                                color: const Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '฿0.00',
                              style: AppTypography.heading3.copyWith(
                                color: AppColors.semanticGrayNeutralFgHigh,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFEE2E2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'รอโอนเข้าบัญชี',
                              style: AppTypography.caption5.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '฿0.00',
                              style: AppTypography.heading3.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),
          SizedBox(
            height: 360,
            child: _buildEmptyFinanceIllustration(
              title: 'ยอดเงินยังเป็นศูนย์',
              subtitle:
                  'รายได้จะโอนเข้าบัญชีธนาคารที่คุณผูกไว้เมื่อครบกำหนดเวลา',
              icon: '🏦',
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
