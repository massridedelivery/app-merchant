import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/finance/presentation/screens/finance_screen.dart';
import 'package:merchant_app/features/home/presentation/screens/dashboard_screen.dart';
import 'package:merchant_app/features/home/providers/navigation_provider.dart';
import 'package:merchant_app/features/menu/presentation/screens/menu_screen.dart';
import 'package:merchant_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:merchant_app/features/profile/presentation/screens/profile_screen.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen> {
  final List<Widget> _pages = const [
    DashboardScreen(),
    OrdersScreen(),
    MenuScreen(),
    FinanceScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    socketService.connect(mockMode: true);
  }

  @override
  void dispose() {
    socketService.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: Stack(
        children: [
          // Content
          Positioned.fill(
            child: IndexedStack(
              index: currentIndex,
              children: _pages
                  .map(
                    (page) => Padding(
                      padding: const EdgeInsets.only(bottom: 90),
                      // Space for floating nav bar
                      child: page,
                    ),
                  )
                  .toList(),
            ),
          ),

          // Floating Nav Bar
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: _buildFloatingPill(currentIndex),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingPill(int currentIndex) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Pill Background
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.92),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
        // Nav Items
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildFloatingNavItem(
                0,
                Icons.home_outlined,
                Icons.home_rounded,
                'หน้าแรก',
                currentIndex,
              ),
              _buildFloatingNavItem(
                1,
                Icons.receipt_long_outlined,
                Icons.receipt_long_rounded,
                'คำสั่งซื้อ',
                currentIndex,
              ),
              _buildFloatingNavItem(
                2,
                Icons.restaurant_menu_outlined,
                Icons.restaurant_menu_rounded,
                'เมนู',
                currentIndex,
              ),
              _buildFloatingNavItem(
                3,
                Icons.account_balance_wallet_outlined,
                Icons.account_balance_wallet_rounded,
                'การเงิน',
                currentIndex,
              ),
              _buildFloatingNavItem(
                4,
                Icons.person_outline,
                Icons.person_rounded,
                'บัญชี',
                currentIndex,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingNavItem(
    int index,
    IconData outlineIcon,
    IconData filledIcon,
    String label,
    int currentIndex,
  ) {
    final isSelected = currentIndex == index;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => ref.read(navigationProvider.notifier).state = index,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Floating Circle for Selected Tab
            if (isSelected)
              Positioned(
                top: -10,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primaryDark, AppColors.primary],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFFCF9F8),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withValues(alpha: 0.2),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(filledIcon, color: Colors.white, size: 24),
                ),
              ),

            // Icon and Label Container
            SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isSelected) ...[
                    Icon(outlineIcon, color: const Color(0xFF64748B), size: 24),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: AppTypography.caption5.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ] else ...[
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          label,
                          style: AppTypography.caption4.copyWith(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
