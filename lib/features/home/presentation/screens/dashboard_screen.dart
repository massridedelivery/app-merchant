import 'package:flutter/material.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/home/presentation/widgets/status_bottom_sheet.dart';
import 'package:merchant_app/features/home/providers/navigation_provider.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/core/errors/failure_snack_bar.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(restaurantProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const Center(
            child: MassLoadingM(size: 72),
          ),
          error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
          data: (profile) => RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () =>
                ref.read(restaurantProfileProvider.notifier).fetchProfile(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Header ─────────────────────────────────────
                  _buildHeader(context, profile),
                  const SizedBox(height: 16),

                  // ─── Performance Summary (Hero) ──────────────────
                  _buildPerformanceHero(context, ref, profile),
                  const SizedBox(height: 24),

                  // ─── Operational Controls & Quick Glance ────────
                  _buildOperationalSection(context, ref, profile),

                  // ─── Verification banner ─────────────────────────
                  // Moved here (from the top app shell) to sit under the
                  // store-management section.
                  if (!profile.isVerified) ...[
                    const SizedBox(height: 12),
                    _buildVerificationBanner(profile),
                  ],
                  const SizedBox(height: 32),

                  // ─── Action Hub (Quick Grid) — hidden for now ────
                  // _buildActionHub(context, ref),
                  // const SizedBox(height: 32),

                  // ─── Personalized Section ──────────────────
                  _buildPersonalizedSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── HEADER ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, RestaurantProfile profile) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const AppIcon(
              AppIcons.storeLine,
              size: 24,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${profile.name}${profile.branch.isNotEmpty ? ' ${profile.branch}' : ''}',
              style: AppTypography.heading6.copyWith(
                color: AppColors.semanticGrayNeutralFgHigh,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  shape: BoxShape.circle,
                ),
                child: const AppIcon(
                  AppIcons.notification,
                  size: 24,
                  color: Color(0xFF475569),
                ),
              ),
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Center(
                    child: Text(
                      '9',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── STATUS CARDS ────────────────────────────────────────────────────────────

  // ─── PERFORMANCE HERO ───────────────────────────────────────────────────────

  Widget _buildPerformanceHero(
    BuildContext context,
    WidgetRef ref,
    RestaurantProfile profile,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _getStatusGradient(profile.status),
          begin: Alignment.bottomRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _statusBgColor(profile.status).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showStatusSheet(context, ref, profile),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'ยอดขายวันนี้',
                  style: AppTypography.heading4.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor(profile.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _statusLabel(profile.status),
                        style: AppTypography.label2.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '฿',
                  style: AppTypography.heading4.copyWith(
                    color: Colors.white.withOpacity(0.8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  profile.todayRevenue.toStringAsFixed(0),
                  style: AppTypography.heading1.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _heroMetric(
                    'คำสั่งซื้อวันนี้',
                    '${profile.todayOrders} รายการ',
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.white.withOpacity(0.2),
                  ),
                  _heroMetric(
                    'กำลังเตรียม',
                    '${profile.preparingCount} รายการ',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption4.copyWith(color: Colors.white),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.body1.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ─── OPERATIONAL SECTION ──────────────────────────────────────────────────────

  Widget _buildOperationalSection(
    BuildContext context,
    WidgetRef ref,
    RestaurantProfile profile,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'การจัดการหน้าร้าน',
            style: AppTypography.heading4.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
            ),
          ),
          const SizedBox(height: 16),
          _buildStatusPill(context, ref, profile),
        ],
      ),
    );
  }

  Widget _buildStatusPill(
    BuildContext context,
    WidgetRef ref,
    RestaurantProfile profile,
  ) {
    final statusColor = _statusBgColor(profile.status);
    return GestureDetector(
      onTap: () => _showStatusSheet(context, ref, profile),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: IconTheme(
                data: IconThemeData(color: statusColor, size: 24),
                child: _statusIcon(profile.status),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'สถานะ: ${_statusLabel(profile.status)}',
                    style: AppTypography.body2.copyWith(
                      color: AppColors.semanticGrayNeutralFgHigh,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'คลิกเพื่อเปลี่ยนสถานะร้านของคุณ',
                    style: AppTypography.caption5.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            const AppIcon(
              AppIcons.chevronRightLine,
              size: 14,
              color: Color(0xFF94A3B8),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusIcon(RestaurantStatus s) {
    switch (s) {
      case RestaurantStatus.open:
        return const AppIcon(AppIcons.circleCheckFill);
      case RestaurantStatus.busy:
        return const AppIcon(AppIcons.clockLine);
      case RestaurantStatus.paused:
        // No pause equivalent in the SVG icon set yet.
        return const Icon(Icons.pause_circle_filled_rounded);
    }
  }

  // ─── ACTION HUB ─────────────────────────────────────────────────────────────

  Widget _buildVerificationBanner(RestaurantProfile profile) {
    final rejected = profile.verificationStatus == 'REJECTED';
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: rejected
            ? AppColors.semanticErrorFgHigh.withValues(alpha: 0.1)
            : const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          AppIcon(
            AppIcons.circleInformationLine,
            size: 16,
            color: rejected
                ? AppColors.semanticErrorFgHigh
                : const Color(0xFFA16207),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rejected
                  ? 'เอกสารยืนยันร้านไม่ผ่าน กรุณาส่งใหม่'
                  : 'อยู่ระหว่างตรวจสอบเอกสารยืนยันร้าน',
              style: AppTypography.caption5.copyWith(
                color: rejected
                    ? AppColors.semanticErrorFgHigh
                    : const Color(0xFFA16207),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Hidden for now (call commented out above); kept for easy re-enable.
  // ignore: unused_element
  Widget _buildActionHub(BuildContext context, WidgetRef ref) {
    final items = [
      _QuickItem(
        'คำสั่งซื้อ',
        const AppIcon(AppIcons.stackPaperLine),
        null,
        () => ref.read(navigationProvider.notifier).state = 1,
      ),
      _QuickItem(
        'เมนู',
        const AppIcon(AppIcons.forkSpoonLine),
        null,
        () => ref.read(navigationProvider.notifier).state = 2,
      ),
      _QuickItem(
        'ยอดขาย',
        const AppIcon(AppIcons.graphArrowUpLine),
        null,
        () => ref.read(navigationProvider.notifier).state = 3,
      ),
      // The four Material icons below have no counterpart in the SVG icon set.
      _QuickItem('ผู้ช่วย AI', const Icon(Icons.auto_awesome_rounded), 'ใหม่', () {}),
      _QuickItem('โปรโมชัน', const AppIcon(AppIcons.calloutFill), 'ยอดฮิต', () {}),
      _QuickItem('พนักงาน', const Icon(Icons.people_alt_rounded), null, () {}),
      _QuickItem('หน้าร้าน', const AppIcon(AppIcons.storeLine), null, () {}),
      _QuickItem('ประวัติ', const AppIcon(AppIcons.clockwiseArrow), null, () {}),
      _QuickItem('พรรทเนอร์', const Icon(Icons.stars_rounded), null, () {}),
      _QuickItem('เพิ่มเติม', const AppIcon(AppIcons.threeDotsHorizontal), null, () {}),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เมนูด่วน (Action Hub)',
            style: AppTypography.heading4.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              mainAxisSpacing: 20,
              crossAxisSpacing: 10,
              childAspectRatio: 0.7,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) => _buildGridItem(items[i]),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(_QuickItem item) {
    return GestureDetector(
      onTap: item.onTap,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: IconTheme(
                  data: const IconThemeData(
                    size: 24,
                    color: Color(0xFF334155),
                  ),
                  child: item.icon,
                ),
              ),
              if (item.badge != null)
                Positioned(
                  top: -6,
                  right: -6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: item.badge == 'ยอดฮิต'
                          ? AppColors.primary
                          : const Color(0xFFF59E0B),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      item.badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.label,
            style: AppTypography.caption5.copyWith(
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _statusColor(RestaurantStatus s) {
    switch (s) {
      case RestaurantStatus.open:
        return Colors.white;
      case RestaurantStatus.busy:
        return const Color(0xFFFEF08A);
      case RestaurantStatus.paused:
        return const Color(0xFFFCA5A5);
    }
  }

  Color _statusBgColor(RestaurantStatus s) {
    switch (s) {
      case RestaurantStatus.open:
        return AppColors.foundationGreen600;
      case RestaurantStatus.busy:
        return AppColors.foundationYellow400;
      case RestaurantStatus.paused:
        return AppColors.foundationRed700;
    }
  }

  List<Color> _getStatusGradient(RestaurantStatus s) {
    switch (s) {
      case RestaurantStatus.open:
        return [AppColors.foundationGreen600, AppColors.foundationGreen600];
      case RestaurantStatus.busy:
        return [AppColors.foundationYellow400, AppColors.foundationYellow400];
      case RestaurantStatus.paused:
        return [AppColors.foundationRed700, AppColors.foundationRed700];
    }
  }

  String _statusLabel(RestaurantStatus s) {
    switch (s) {
      case RestaurantStatus.open:
        return 'เปิดให้บริการ';
      case RestaurantStatus.busy:
        return 'ยุ่ง';
      case RestaurantStatus.paused:
        return 'หยุดชั่วคราว';
    }
  }

  // ─── PERSONALIZED SECTION ────────────────────────────────────────────────────

  Widget _buildPersonalizedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'สำหรับคุณโดยเฉพาะ',
                style: AppTypography.heading4.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '2/2',
                  style: AppTypography.caption5.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 110,
          child: PageView(
            controller: PageController(viewportFraction: 0.9),
            padEnds: false,
            children: [
              _buildPromoCard(
                icon: '🚀',
                title: 'เพิ่มยอดคำสั่งซื้อได้ 21% เพียงให้ส่วนลดค่าส่ง!',
                actionText: 'ดูข้อมูลเพิ่มเติม',
                color: const Color(0xFFFEF2F2),
                borderColor: const Color(0xFFFECACA),
              ),
              _buildPromoCard(
                icon: '👑',
                title: 'ร้านดีการันตีคุณภาพ – ทำเป้าหมายสำเร็จในสิ้นเดือน',
                actionText: 'ดูรายละเอียด',
                color: const Color(0xFFF8FAFC),
                borderColor: const Color(0xFFE2E8F0),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromoCard({
    required String icon,
    required String title,
    required String actionText,
    required Color color,
    required Color borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 20, right: 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(icon, style: const TextStyle(fontSize: 24)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: AppTypography.body3.copyWith(
                    color: AppColors.semanticGrayNeutralFgHigh,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      actionText,
                      style: AppTypography.label3.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const AppIcon(
                      AppIcons.chevronRightLine,
                      size: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStatusSheet(
    BuildContext context,
    WidgetRef ref,
    RestaurantProfile profile,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatusBottomSheet(
        currentStatus: profile.status,
        onStatusChanged: (s) =>
            runGuarded(
          context,
          () => ref.read(restaurantProfileProvider.notifier).setStatus(s),
        ),
      ),
    );
  }
}

class _QuickItem {
  final String label;

  /// Widget rather than an asset path — most entries are an [AppIcon] from the
  /// design set, a few still fall back to a Material icon.
  final Widget icon;
  final String? badge;
  final VoidCallback onTap;

  _QuickItem(this.label, this.icon, this.badge, this.onTap);
}
