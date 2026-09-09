import 'package:flutter/material.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_colors.dart';
import 'package:merchant_app/core/theme/app_theme.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/ads/presentation/screens/ads_screen.dart';
import 'package:merchant_app/core/notifications/push_notification_service.dart';
import 'package:merchant_app/features/auth/providers/auth_provider.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';
import 'package:merchant_app/features/finance/presentation/screens/bank_account_screen.dart';
import 'package:merchant_app/features/finance/presentation/screens/withdraw_screen.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/closing_hours_screen.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/kyc_documents_screen.dart';
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
        // The profile is fetched once at startup, so without this the screen
        // never picks up an edit made on another device -- or a KYC approval --
        // until the app is restarted. It is also the only way out of the error
        // state below.
        child: RefreshIndicator(
          onRefresh: () =>
              ref.read(restaurantProfileProvider.notifier).fetchProfile(),
          child: SingleChildScrollView(
            // Always scrollable, or a short page cannot be pulled to refresh.
            physics: const AlwaysScrollableScrollPhysics(),
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
                                    AppColors.primary.withValues(alpha: 0.8),
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
                                Colors.black.withValues(alpha: 0.4),
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
                              AppColors.primary.withValues(alpha: 0.8),
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
                              color: Colors.black.withValues(alpha: 0.12),
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
                      // maybeWhen(data:, orElse:) used to cover loading *and*
                      // error with the same spinner, so a failed fetch spun
                      // forever with nothing on screen to tap.
                      profileAsync.when(
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
                        loading: () => const MassLoadingM(size: 52),
                        error: (_, _) => _ProfileLoadError(
                          onRetry: () => ref
                              .read(restaurantProfileProvider.notifier)
                              .fetchProfile(),
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
                        icon: AppIcons.stackPaperLine,
                        title: 'เอกสารยืนยันตัวตน',
                        subtitle: 'ส่งเอกสาร KYC และดูสถานะการตรวจสอบ',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const KycDocumentsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        icon: AppIcons.buildingLine,
                        title: 'บัญชีธนาคาร',
                        subtitle: 'จัดการบัญชีรับเงิน',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const BankAccountScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        icon: AppIcons.cardLine,
                        title: 'แจ้งถอนเงิน',
                        subtitle: 'ถอนรายได้เข้าบัญชีธนาคาร',
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const WithdrawScreen(),
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
                      const SizedBox(height: 12),
                      _buildMenuCard(
                        icon: AppIcons.notification,
                        title: 'ทดสอบเสียงออเดอร์ใหม่',
                        subtitle: 'เล่นเสียงแจ้งเตือนออเดอร์เข้าเพื่อทดสอบ',
                        onTap: () async {
                          await PushNotificationService.instance
                              .playTestOrderAlert();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'กำลังเล่นเสียงแจ้งเตือนออเดอร์ใหม่',
                              ),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        },
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
                        onPressed: () => _confirmLogout(context, ref),
                      ),
                      const SizedBox(height: 16),

                      // ─── Delete account (App Store / Play requirement) ──
                      TextButton(
                        onPressed: () => _confirmDeleteAccount(context, ref),
                        child: Text(
                          'ลบบัญชี',
                          style: AppTypography.label3.copyWith(
                            color: AppColors.error,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// `POST /auth/logout` revokes **every** refresh token, not just this
  /// device's (SCRUM-53 2). A merchant with a till tablet and a phone would
  /// otherwise sign the counter out by tapping this on the phone, with nothing
  /// having warned them.
  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text(
          'จะออกจากระบบทุกเครื่องที่เข้าใช้บัญชีนี้อยู่ รวมถึงแท็บเล็ตหน้าร้าน '
          'ต้องเข้าสู่ระบบใหม่ทั้งหมด',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('ออกจากระบบ'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authProvider.notifier).logout();
  }

  /// Permanent account deletion — required by the App Store (5.1.1(v)) and
  /// Google Play for any app with sign-in. Deletes server-side, then the auth
  /// state flips to unauthenticated and the router returns to the welcome
  /// screen. A failed call keeps the merchant signed in (nothing was deleted).
  Future<void> _confirmDeleteAccount(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบบัญชีถาวร'),
        content: const Text(
          'การลบบัญชีจะลบข้อมูลร้าน เมนู การเงิน และเอกสารทั้งหมดอย่างถาวร '
          'กู้คืนไม่ได้ และจะออกจากระบบทุกเครื่องทันที\n\n'
          'ยืนยันลบบัญชีนี้หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('ลบบัญชีถาวร'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(authProvider.notifier).deleteAccount();
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ลบบัญชีไม่สำเร็จ กรุณาลองใหม่ หรือติดต่อฝ่ายสนับสนุน'),
          backgroundColor: AppColors.error,
        ),
      );
    }
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
                    color: AppColors.primary.withValues(alpha: 0.08),
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

/// Shown in place of the name when `GET /profile` fails. It offers a button as
/// well as pull-to-refresh, because nothing on screen would otherwise say that
/// pulling is an option.
class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'โหลดข้อมูลร้านไม่สำเร็จ',
          style: AppTypography.body2.copyWith(
            color: AppColors.semanticGrayNeutralFgHigh,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          'ตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
          style: AppTypography.caption5.copyWith(
            color: const Color(0xFF64748B),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('ลองอีกครั้ง')),
      ],
    );
  }
}
