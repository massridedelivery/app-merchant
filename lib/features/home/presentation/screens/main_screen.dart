import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/constants/layout.dart';
import 'package:merchant_app/core/router/app_router_holder.dart';
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
    _socket.connect();
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
    // System nav inset (3-button bar / gesture pill). extendBody isn't used, but
    // viewPadding still reports the real inset even when padding is consumed.
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    // How high the floating bar sits. Android's inset is an opaque button/gesture
    // bar the pill must clear, so add it. iOS's inset is only the thin, see-through
    // home indicator (or 0 on Home-button devices) — safe to sit under, so the bar
    // hugs the bottom instead of floating too high. Uses the real inset, never a
    // hardcoded value, so gesture vs 3-button is handled automatically.
    final navBottom =
        Platform.isAndroid ? kFloatingNavGap + bottomInset : kFloatingNavGap;

    // A tapped new-order push routes to '/' and asks for the Orders tab; honour
    // it once, after this frame, then clear so it doesn't fire again.
    if (pendingTabIndex != null) {
      final target = pendingTabIndex!;
      pendingTabIndex = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ref.read(navigationProvider.notifier).state = target;
      });
    }

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
                Expanded(
                  child: IndexedStack(
                    index: currentIndex,
                    children: _pages
                        .map(
                          (page) => Padding(
                            // Reserve just the floating-nav footprint. Each tab
                            // already wraps its body in a SafeArea, so the
                            // system-nav inset is added there — adding it here
                            // too would leave a big empty gap above the bar.
                            padding: const EdgeInsets.only(
                                bottom: kFloatingNavReserve),
                            child: page,
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ),
          ),

          // Floating Nav Bar — clears the opaque system nav on Android; hugs the
          // bottom on iOS (see navBottom above).
          Positioned(
            left: 20,
            right: 20,
            bottom: navBottom,
            child: _buildFloatingPill(currentIndex),
          ),
        ],
      ),
    );
  }

  /// KYC approval is admin-side and asynchronous, so this informs rather than
  /// blocks — unlike the coordinates gate, an unverified restaurant can still
  /// use the app while paperwork is reviewed.
  Widget _buildFloatingPill(int currentIndex) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // Pill Background — solid frosted off-white (no BackdropFilter blur,
        // for smoothness on low-end devices).
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: const Color(0xFFFCF9F8).withValues(alpha: 0.94),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
        ),
        // Nav Items
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
        ),
      ),
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
                top: -8,
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
                        color: AppColors.primary.withValues(alpha: 0.4),
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
                            color: const Color(0xFF00236F),
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
