import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/ads/presentation/screens/ads_screen.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';
import 'package:merchant_app/features/finance/presentation/screens/bank_account_screen.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/closing_hours_screen.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/store_details_screen.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(restaurantProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.semanticGrayNeutralBgWhite,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ─── Header with cover + logo ──────────────
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  profileAsync.maybeWhen(
                    data: (p) => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        image: p.coverImageUrl != null
                            ? DecorationImage(
                                image: NetworkImage(p.coverImageUrl!),
                                fit: BoxFit.cover,
                              )
                            : null,
                        gradient: p.coverImageUrl == null
                            ? LinearGradient(
                                colors: [
                                  AppColors.primary.withOpacity(0.8),
                                  AppColors.primary,
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              )
                            : null,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.4),
                            ],
                          ),
                        ),
                      ),
                    ),
                    orElse: () => Container(
                      height: 180,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary.withOpacity(0.8),
                            AppColors.primary,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: profileAsync.maybeWhen(
                        data: (p) => p.logoUrl != null
                            ? CircleAvatar(
                                radius: 46,
                                backgroundImage: NetworkImage(p.logoUrl!),
                              )
                            : Container(
                                width: 92,
                                height: 92,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF1F5F9),
                                  shape: BoxShape.circle,
                                ),
                                child: const AppIcon(
                                  AppIcons.storeLine,
                                  size: 40,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                        orElse: () => const CircleAvatar(
                          radius: 46,
                          backgroundColor: Color(0xFFF1F5F9),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 64),

              // ─── Name & address ─────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    profileAsync.maybeWhen(
                      data: (p) => Column(
                        children: [
                          Text(
                            p.name,
                            style: AppTypography.heading4.copyWith(
                              color: AppColors.semanticGrayNeutralFgHigh,
                              fontWeight: FontWeight.w900,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          if (p.address != null)
                            Text(
                              p.address!,
                              style: AppTypography.body3.copyWith(
                                color: const Color(0xFF64748B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                      orElse: () => const CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ─── Menu Cards ──────────────────────
                    _buildMenuCard(
                      icon: AppIcons.storeLine,
                      title: 'ร้าน',
                      subtitle: 'จัดการข้อมูลร้าน, ภาพ และที่อยู่',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StoreDetailsScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: AppIcons.clockLine,
                      title: 'เวลาเปิด-ปิด',
                      subtitle: 'วันหยุดพิเศษและเวลาจัดส่ง',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ClosingHoursScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: AppIcons.buildingLine,
                      title: 'บัญชีธนาคาร',
                      subtitle: 'จัดการการรับเงินและขอถอนเงิน',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BankAccountScreen(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildMenuCard(
                      icon: AppIcons.calloutFill,
                      title: 'โปรโมทร้านค้า (Ads)',
                      subtitle: 'จัดการงบประมาณและราคาประมูลรายวัน',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AdsScreen()),
                      ),
                    ),
                    const SizedBox(height: 48),

                    // ─── Logout ──────────────────────────
                    OutlinedButton.icon(
                      icon: const AppIcon(
                        AppIcons.doorOpenLine,
                        color: AppColors.primary,
                      ),
                      label: Text(
                        'ออกจากระบบ',
                        style: AppTypography.label2.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        minimumSize: const Size.fromHeight(56),
                        elevation: 0,
                      ),
                      onPressed: () => ref.read(authProvider.notifier).logout(),
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required String icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: AppTheme.premiumCardDecoration.copyWith(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: AppIcon(icon, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTypography.label2.copyWith(
                          color: AppColors.semanticGrayNeutralFgHigh,
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
                const AppIcon(
                  AppIcons.chevronRightLine,
                  color: Color(0xFF94A3B8),
                  size: 16,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
