import 'package:flutter/material.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/home/presentation/widgets/status_bottom_sheet.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';
import 'package:merchant_app/features/orders/models/order.dart';
import 'package:merchant_app/features/orders/presentation/widgets/order_ops_sheet.dart';
import 'package:merchant_app/features/orders/providers/order_provider.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/core/errors/failure_snack_bar.dart';

class OrdersScreen extends ConsumerStatefulWidget {
  const OrdersScreen({super.key});

  @override
  ConsumerState<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends ConsumerState<OrdersScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    Future.microtask(() => ref.read(orderProvider.notifier).fetchOrders());
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orderState = ref.watch(orderProvider);
    final profileAsync = ref.watch(restaurantProfileProvider);

    final statusLabel = profileAsync.maybeWhen(
      data: (p) => _statusLabel(p.status),
      orElse: () => 'ปิด',
    );
    final isOpen = profileAsync.maybeWhen(
      data: (p) => p.status == RestaurantStatus.open,
      orElse: () => false,
    );

    // Show incoming order notification
    if (orderState.hasNewOrder && orderState.newestIncomingOrder != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showNewOrderSnackbar(context, ref, orderState.newestIncomingOrder!);
        ref.read(orderProvider.notifier).dismissNewOrderNotification();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ─────────────────────────────────────────
            _buildHeader(context, ref, statusLabel, isOpen, profileAsync),
            // ─── Tabs ───────────────────────────────────────────
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
                  Tab(text: 'กำลังเตรียม'),
                  Tab(text: 'พร้อมจัดส่ง'),
                  Tab(text: 'กำลังจัดส่ง'),
                  Tab(text: 'ประวัติ'),
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
              child: orderState.isLoading
                  ? const Center(
                      child: MassLoadingM(size: 72),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOrderList(orderState.preparing, tab: 0),
                        _buildOrderList(orderState.ready, tab: 1),
                        _buildOrderList(orderState.delivering, tab: 2),
                        _buildOrderList(orderState.history, tab: 3),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    WidgetRef ref,
    String statusLabel,
    bool isOpen,
    AsyncValue<RestaurantProfile> profileAsync,
  ) {
    // Status colour: open = green, busy = amber, paused/closed = red.
    final status = profileAsync.valueOrNull?.status ?? RestaurantStatus.paused;
    final statusColor = switch (status) {
      RestaurantStatus.open => AppColors.success,
      RestaurantStatus.busy => AppColors.warning,
      RestaurantStatus.paused => AppColors.semanticErrorFgHigh,
    };
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'คำสั่งซื้อ',
            style: AppTypography.heading4.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
              fontWeight: FontWeight.w900,
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  final profile = profileAsync.valueOrNull;
                  if (profile == null) return;
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (_) => StatusBottomSheet(
                      currentStatus: profile.status,
                      onStatusChanged: (s) => runGuarded(
                        context,
                        () => ref
                            .read(restaurantProfileProvider.notifier)
                            .setStatus(s),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.08),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.5),
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusLabel,
                        style: AppTypography.label3.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: const AppIcon(
                  AppIcons.threeDotsHorizontal,
                  size: 20,
                  color: Color(0xFF475569),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderList(List<Order> orders, {required int tab}) {
    if (orders.isEmpty) {
      return tab == 0 ? _buildEmptyPreparingState() : _buildEmptyState(tab);
    }

    final isHistory = tab == 3;
    final hasMore = isHistory && ref.watch(orderProvider).historyHasMore;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => isHistory
          ? ref.read(orderProvider.notifier).fetchHistory()
          : ref.read(orderProvider.notifier).fetchOrders(),
      child: NotificationListener<ScrollNotification>(
        onNotification: (n) {
          if (isHistory &&
              hasMore &&
              n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
            ref.read(orderProvider.notifier).loadMoreHistory();
          }
          return false;
        },
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          itemCount: orders.length + (hasMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i >= orders.length) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: MassLoadingM(size: 40)),
              );
            }
            return _buildOrderCard(orders[i]);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyPreparingState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 10,
                ),
              ],
            ),
            child: const AppIcon(
              AppIcons.stackPaperLine,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ยังไม่มีคำสั่งซื้อใหม่ในตอนนี้',
            style: AppTypography.heading6.copyWith(
              color: AppColors.semanticGrayNeutralFgHigh,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เตรียมวัตถุดิบไว้ให้พร้อมสำหรับออเดอร์ถัดไป',
            style: AppTypography.body3.copyWith(color: const Color(0xFF64748B)),
          ),
          const SizedBox(height: 32),
          // Tips card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: AppTheme.premiumCardDecoration,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ระหว่างรอคำสั่งซื้อ...',
                  style: AppTypography.heading6.copyWith(
                    color: AppColors.semanticGrayNeutralFgHigh,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTipRow(
                  '🔄',
                  'ตรวจสอบความพร้อมจำหน่ายสินค้า',
                  'เพื่อป้องกันการยกเลิก',
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildTipRow(
                  '⏱️',
                  'เตรียมให้เสร็จก่อนหมดเวลา',
                  'เพื่อไม่ให้การจัดส่งคำสั่งซื้อล่าช้า',
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildTipRow(
                  '⭐',
                  'อ่านฟีดแบกลูกค้า',
                  'เพื่อนำมาปรับปรุงให้ลูกค้าพอใจมากขึ้น',
                ),
                const Divider(height: 24, color: Color(0xFFF1F5F9)),
                _buildTipRow(
                  '✨',
                  'แชทกับผู้ช่วย AI',
                  'เพื่อหาแนวทางพัฒนาธุรกิจ',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(String emoji, String title, String subtitle) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            shape: BoxShape.circle,
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.body2.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: AppTypography.caption5.copyWith(
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
        const AppIcon(AppIcons.chevronRightLine, size: 12, color: Color(0xFF94A3B8)),
      ],
    );
  }

  Widget _buildEmptyState(int tab) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tab == 1
                ? 'ยังไม่มีออเดอร์พร้อมจัดส่ง'
                : tab == 2
                ? 'ไม่มีออเดอร์กำลังจัดส่ง'
                : 'ยังไม่มีประวัติคำสั่งซื้อ',
            style: AppTypography.body1.copyWith(
              color: const Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Order order) {
    final isPending = order.status == OrderStatus.placed;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPending
              ? AppColors.primary.withOpacity(0.5)
              : const Color(0xFFE2E8F0),
          width: isPending ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isPending
                ? AppColors.primary.withOpacity(0.1)
                : Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ─── Card Header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            decoration: BoxDecoration(
              color: isPending
                  ? AppColors.primary.withOpacity(0.02)
                  : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const AppIcon(AppIcons.hashtag, size: 18, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      order.shortId,
                      style: AppTypography.heading6.copyWith(
                        color: AppColors.semanticGrayNeutralFgHigh,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                _buildStatusChip(order.status),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── Items ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: order.items
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Text(
                                '${item.quantity}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: AppTypography.body2.copyWith(
                                    color: AppColors.semanticGrayNeutralFgHigh,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (item.selectedModifiers.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    item.selectedModifiers.map((m) => m.name).join(', '),
                                    style: AppTypography.caption5.copyWith(
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Text(
                            '฿${item.subtotal.toStringAsFixed(0)}',
                            style: AppTypography.body2.copyWith(
                              color: AppColors.semanticGrayNeutralFgHigh,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // ─── Totals & Payment ─────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _paymentIcon(order.paymentMethod),
                    style: AppTypography.label3.copyWith(
                      color: const Color(0xFF475569),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'ยอดรวม',
                      style: AppTypography.caption5.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    Text(
                      '฿${order.totalAmount.toStringAsFixed(0)}',
                      style: AppTypography.heading5.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ─── Kitchen adjustments ───────────────────────────
          if (_canAdjustOps(order.status))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: _buildOpsRow(order),
            ),

          // ─── Action Buttons ────────────────────────────────
          if (_shouldShowActions(order.status))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: _buildActionButtons(order),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final info = _statusInfo(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: info['bg'] as Color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        info['label'] as String,
        style: TextStyle(
          color: info['text'] as Color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Map<String, dynamic> _statusInfo(String status) {
    switch (status) {
      case OrderStatus.placed:
        return {
          'label': 'ได้รับออเดอร์',
          'bg': AppColors.primary.withOpacity(0.1),
          'text': AppColors.primary,
        };
      case OrderStatus.restaurantAccepted:
        return {
          'label': 'รับแล้ว',
          'bg': const Color(0xFFE0F2FE),
          'text': const Color(0xFF0284C7),
        };
      case OrderStatus.preparing:
        return {
          'label': 'กำลังเตรียม',
          'bg': const Color(0xFFF3E8FF),
          'text': const Color(0xFF7E22CE),
        };
      case OrderStatus.readyForPickup:
        return {
          'label': 'พร้อมส่ง',
          'bg': const Color(0xFFDCFCE7),
          'text': const Color(0xFF166534),
        };
      case OrderStatus.driverAssigned:
        return {
          'label': 'รอไรเดอร์รับ',
          'bg': const Color(0xFFFEF9C3),
          'text': const Color(0xFFA16207),
        };
      case OrderStatus.driverPickedUp:
        return {
          'label': 'กำลังส่ง',
          'bg': const Color(0xFFFEF9C3),
          'text': const Color(0xFFA16207),
        };
      case OrderStatus.delivered:
        return {
          'label': 'ส่งเรียบร้อย',
          'bg': const Color(0xFFF1F5F9),
          'text': const Color(0xFF475569),
        };
      case OrderStatus.restaurantRejected:
        return {
          'label': 'ปฏิเสธแล้ว',
          'bg': const Color(0xFFF1F5F9),
          'text': const Color(0xFF475569),
        };
      case OrderStatus.cancelled:
        return {
          'label': 'ยกเลิกแล้ว',
          'bg': const Color(0xFFF1F5F9),
          'text': const Color(0xFF475569),
        };
      default:
        return {
          'label': status,
          'bg': const Color(0xFFF1F5F9),
          'text': const Color(0xFF64748B),
        };
    }
  }

  /// Prep time and out-of-stock only mean something while the kitchen still
  /// owns the order — not once a rider has it.
  bool _canAdjustOps(String status) =>
      status == OrderStatus.restaurantAccepted ||
      status == OrderStatus.preparing;

  Widget _buildOpsRow(Order order) {
    final adjusted = order.prepTimeAdjustmentMin != 0;
    final oosCount = order.oosItemIds.length;

    return Row(
      children: [
        if (adjusted || oosCount > 0)
          Expanded(
            child: Text(
              [
                if (adjusted)
                  '${order.prepTimeAdjustmentMin > 0 ? '+' : ''}'
                      '${order.prepTimeAdjustmentMin} นาที',
                if (oosCount > 0) 'ของหมด $oosCount รายการ',
              ].join(' · '),
              style: AppTypography.caption5.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          const Spacer(),
        TextButton.icon(
          onPressed: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (_) => OrderOpsSheet(order: order),
          ),
          icon: const AppIcon(
            AppIcons.clockLine,
            size: 16,
            color: Color(0xFF64748B),
          ),
          label: Text(
            'ปรับเวลา / ของหมด',
            style: AppTypography.label3.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ),
      ],
    );
  }

  bool _shouldShowActions(String status) =>
      OrderStatus.inKitchen.contains(status);

  Widget _buildActionButtons(Order order) {
    final notifier = ref.read(orderProvider.notifier);

    if (order.status == OrderStatus.placed) {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => runGuarded(
                  context, () => notifier.rejectOrder(order.id)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF64748B),
                side: const BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'ปฏิเสธ',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: () => runGuarded(
                  context, () => notifier.acceptOrder(order.id)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
              ),
              child: const Text(
                'รับออเดอร์',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else if (order.status == OrderStatus.restaurantAccepted) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => runGuarded(
                  context, () => notifier.markPreparing(order.id)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
          child: const Text(
            'เริ่มเตรียมอาหาร',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    } else if (order.status == OrderStatus.preparing) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => runGuarded(
                  context, () => notifier.markReady(order.id)),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF22C55E),
            // Keep green for 'ready' as it's a success state
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            elevation: 0,
          ),
          child: const Text(
            'เสร็จแล้ว / พร้อมส่ง',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  String _paymentIcon(String method) {
    switch (method) {
      case 'credit_card':
        return '💳 บัตรเครดิต';
      case 'grab_pay':
        return '📱 จ่ายออนไลน์';
      case 'cash':
        return '💵 เงินสด';
      default:
        return '💵 $method';
    }
  }

  String _statusLabel(RestaurantStatus s) {
    switch (s) {
      case RestaurantStatus.open:
        return 'เปิด';
      case RestaurantStatus.busy:
        return 'ยุ่ง';
      case RestaurantStatus.paused:
        return 'ปิด';
    }
  }

  void _showNewOrderSnackbar(BuildContext context, WidgetRef ref, Order order) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.foundationGreen600,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.all(20),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Text('🛵', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'ออเดอร์มาแล้ว ฝากพี่ๆช่วยด้วยนะครับ',
                    style: AppTypography.label2.copyWith(
                      color: AppColors.semanticGrayNeutralBgWhite,
                    ),
                  ),
                  Text(
                    '${order.items.length} รายการ • ฿${order.totalAmount.toStringAsFixed(0)}',
                    style: AppTypography.caption4.copyWith(
                      color: AppColors.semanticGrayNeutralBgWhite,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () =>
                  ScaffoldMessenger.of(context).hideCurrentSnackBar(),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              child: Text(
                'ดู',
                style: AppTypography.caption4.copyWith(
                  color: AppColors.semanticGrayNeutralFgHigh,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
