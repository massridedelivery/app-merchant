import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/services/socket_service.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/finance/presentation/screens/finance_screen.dart';
import 'package:merchant_app/features/home/presentation/screens/dashboard_screen.dart';
import 'package:merchant_app/features/home/providers/navigation_provider.dart';
import 'package:merchant_app/features/menu/presentation/screens/menu_screen.dart';
import 'package:merchant_app/features/orders/presentation/screens/orders_screen.dart';
import 'package:merchant_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/store_onboarding_screen.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';

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

  // Held rather than read in dispose(): reading a provider while the widget is
  // being torn down is not guaranteed to succeed.
  late final SocketService _socket;

  @override
  void initState() {
    super.initState();
    _socket = ref.read(socketServiceProvider);
    _socket.connect(mockMode: true);
  }

  @override
  void dispose() {
    _socket.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);
    final profileAsync = ref.watch(restaurantProfileProvider);

    // A restaurant still on the row registration created has no real
    // coordinates, which means customer search cannot see it at all. Nothing
    // else in the app is worth doing until that is fixed (SCRUM-53 §2).
    final profile = profileAsync.valueOrNull;
    if (profile != null && profile.isPlaceholder) {
      return StoreOnboardingScreen(profile: profile);
    }

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: Stack(
        children: [
          // Content
          Positioned.fill(
            child: Column(
              children: [
                if (profile != null && !profile.isVerified)
                  _buildVerificationBanner(profile),
                Expanded(
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
              ],
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

  /// KYC approval is admin-side and asynchronous, so this informs rather than
  /// blocks — unlike the coordinates gate, an unverified restaurant can still
  /// use the app while paperwork is reviewed.
  Widget _buildVerificationBanner(RestaurantProfile profile) {
    final rejected = profile.verificationStatus == 'REJECTED';
    return Container(
      width: double.infinity,
      color: rejected
          ? AppColors.semanticErrorFgHigh.withValues(alpha: 0.1)
          : const Color(0xFFFEF9C3),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                AppIcons.houseLine,
                AppIcons.houseFill,
                'หน้าแรก',
                currentIndex,
              ),
              _buildFloatingNavItem(
                1,
                AppIcons.cartLine,
                AppIcons.cartFill,
                'คำสั่งซื้อ',
                currentIndex,
              ),
              // No filled variant in the icon set for these two.
              _buildFloatingNavItem(
                2,
                AppIcons.forkSpoonLine,
                AppIcons.forkSpoonLine,
                'เมนู',
                currentIndex,
              ),
              _buildFloatingNavItem(
                3,
                AppIcons.cardLine,
                AppIcons.cardLine,
                'การเงิน',
                currentIndex,
              ),
              _buildFloatingNavItem(
                4,
                AppIcons.circleUserLine,
                AppIcons.circleUserFill,
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
    String outlineIcon,
    String filledIcon,
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
                  child: Center(
                    child: AppIcon(
                      filledIcon,
                      size: 24,
                      color: Colors.white,
                      semanticLabel: label,
                    ),
                  ),
                ),
              ),

            // Icon and Label Container
            SizedBox(
              height: 64,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!isSelected) ...[
                    AppIcon(
                      outlineIcon,
                      size: 24,
                      color: const Color(0xFF64748B),
                      semanticLabel: label,
                    ),
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
