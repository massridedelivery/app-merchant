import 'package:flutter/material.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/restaurant/providers/restaurant_provider.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/closing_hours_screen.dart';
import 'package:merchant_app/features/restaurant/presentation/widgets/edit_store_profile_dialog.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class StoreDetailsScreen extends ConsumerWidget {
  const StoreDetailsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(restaurantProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF333333)),
        title: Text(
          'ร้าน',
          style: AppTypography.heading5.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          if (profileAsync.hasValue)
            IconButton(
              tooltip: 'แก้ไขข้อมูลร้าน',
              onPressed: () => showDialog(
                context: context,
                builder: (_) =>
                    EditStoreProfileDialog(profile: profileAsync.value!),
              ),
              icon: const AppIcon(
                AppIcons.pencilFill,
                size: 20,
                color: Color(0xFF333333),
              ),
            ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: MassLoadingM(size: 72)),
        error: (e, _) => Center(child: Text('เกิดข้อผิดพลาด: $e')),
        data: (profile) => SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Restaurant Header ─────────────────────────
              _buildRestaurantHeader(profile),
              const SizedBox(height: 8),

              // ─── Photos Section ────────────────────────────
              _buildSection(
                children: [
                  _buildPhotoRow(
                    label: 'รูปหน้าปกร้าน',
                    imageUrl: profile.coverImageUrl,
                  ),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildPhotoRow(
                    label: 'รูปประจำร้าน (โลโก้)',
                    imageUrl: profile.logoUrl,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ─── Food Type ─────────────────────────────────
              _buildSection(
                children: [
                  _buildNavRow(context, 'ประเภทอาหารและการรับรอง', null),
                ],
              ),
              const SizedBox(height: 8),

              // ─── Hours ─────────────────────────────────────
              _buildSection(
                children: [
                  _buildNavRow(context, 'เวลาเปิด-ปิด', () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ClosingHoursScreen()));
                  }),
                ],
              ),
              const SizedBox(height: 8),

              // ─── Contact ───────────────────────────────────
              _buildSection(
                children: [
                  _buildInfoRow('เจ้าของร้าน', profile.name),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildInfoRow('ผู้จัดการ', profile.name),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildInfoRow('เบอร์ติดต่อร้าน', profile.phone ?? '-'),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildInfoRow('ที่อยู่', profile.address ?? '-'),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildInfoRow('ประเภทอาหาร', profile.cuisineType ?? '-'),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildInfoRow('คำอธิบายร้าน', profile.description ?? '-'),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildInfoRow(
                    'ยอดสั่งซื้อขั้นต่ำ',
                    profile.minOrderAmount == null
                        ? '-'
                        : '฿${profile.minOrderAmount!.toStringAsFixed(0)}',
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // ─── Dine-in image ─────────────────────────────
              _buildSection(
                children: [
                  _buildNavRow(context, 'รูปกินที่ร้าน', null, subtitle: 'เพิ่มรูป'),
                ],
              ),
              const SizedBox(height: 8),

              // ─── IDs ───────────────────────────────────────
              _buildSection(
                children: [
                  _buildCopyRow(context, 'รหัสร้านค้า', profile.restaurantCode ?? '-'),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildCopyRow(context, 'เลขประจำตัวผู้เสียภาษี', profile.taxId ?? '-'),
                  const Divider(height: 24, color: Color(0xFFF0F0F0)),
                  _buildOtpRow(context),
                ],
              ),
              const SizedBox(height: 16),

              // ─── Share Button ──────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const AppIcon(AppIcons.share, color: Color(0xFFE5002B)),
                    label: const Text('แชร์ลิงก์ร้าน Grab',
                        style: TextStyle(color: Color(0xFFE5002B), fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE5002B), width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {},
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader(RestaurantProfile profile) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: profile.logoUrl != null
                ? Image.network(profile.logoUrl!, width: 56, height: 56, fit: BoxFit.cover)
                : Container(
                    width: 56,
                    height: 56,
                    color: const Color(0xFFF0F0F0),
                    child: const AppIcon(AppIcons.storeLine, color: Color(0xFF888888)),
                  ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.name,
                style: AppTypography.heading6.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (profile.branch.isNotEmpty)
                Text(profile.branch,
                    style: AppTypography.body3.copyWith(color: const Color(0xFF888888))),
              Text(profile.platform,
                  style: AppTypography.body3
                      .copyWith(color: const Color(0xFFE5002B), fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection({required List<Widget> children}) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildPhotoRow({required String label, String? imageUrl}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body2.copyWith(color: const Color(0xFF333333))),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: imageUrl != null
                  ? Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover)
                  : Container(
                      width: 40, height: 40,
                      color: const Color(0xFFF0F0F0),
                      child: const AppIcon(AppIcons.photoLine, color: Color(0xFFBBBBBB)),
                    ),
            ),
            const SizedBox(width: 8),
            const AppIcon(AppIcons.chevronRightLine, color: Color(0xFF888888)),
          ],
        ),
      ],
    );
  }

  Widget _buildNavRow(BuildContext context, String label, VoidCallback? onTap, {String? subtitle}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.body2.copyWith(color: const Color(0xFF333333))),
          Row(
            children: [
              if (subtitle != null)
                Text(subtitle, style: AppTypography.body3.copyWith(color: const Color(0xFFE5002B))),
              const AppIcon(AppIcons.chevronRightLine, color: Color(0xFF888888)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.body3.copyWith(color: const Color(0xFF888888))),
        Flexible(
          child: Text(
            value,
            style: AppTypography.body2.copyWith(color: const Color(0xFF333333)),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildCopyRow(BuildContext context, String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.body3.copyWith(color: const Color(0xFF888888))),
            const SizedBox(height: 2),
            Text(value,
                style: AppTypography.body2.copyWith(
                  color: const Color(0xFF333333),
                  fontWeight: FontWeight.w500,
                )),
          ],
        ),
        GestureDetector(
          onTap: () {
            Clipboard.setData(ClipboardData(text: value));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('คัดลอกแล้ว'),
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Icon(Icons.copy_outlined, size: 18, color: Color(0xFFE5002B)),
        ),
      ],
    );
  }

  Widget _buildOtpRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('OTP', style: AppTypography.body3.copyWith(color: const Color(0xFF888888))),
            const SizedBox(height: 2),
            Text('••••••',
                style: AppTypography.body2.copyWith(color: const Color(0xFF333333))),
          ],
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            'สร้างรหัส OTP',
            style: AppTypography.label3.copyWith(color: const Color(0xFFE5002B)),
          ),
        ),
      ],
    );
  }
}
