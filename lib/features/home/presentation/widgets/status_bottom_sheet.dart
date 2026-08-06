import 'package:flutter/material.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/restaurant/models/restaurant_profile.dart';
import 'package:merchant_app/features/profile/presentation/screens/opening_hours_screen.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class StatusBottomSheet extends StatefulWidget {
  final RestaurantStatus currentStatus;
  final ValueChanged<RestaurantStatus> onStatusChanged;

  const StatusBottomSheet({
    super.key,
    required this.currentStatus,
    required this.onStatusChanged,
  });

  @override
  State<StatusBottomSheet> createState() => _StatusBottomSheetState();
}

class _StatusBottomSheetState extends State<StatusBottomSheet> {
  late RestaurantStatus _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFDDDDDD),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'ตั้งสถานะร้าน',
            style: AppTypography.heading5.copyWith(
              color: const Color(0xFF111111),
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Options
          _buildOption(
            status: RestaurantStatus.open,
            color: const Color(0xFF2ECC71),
            icon: const AppIcon(AppIcons.circleCheckFill),
            label: 'เปิดให้บริการ',
            subtitle: 'พร้อมรับคำสั่งซื้อใหม่เข้าร้าน',
          ),
          const SizedBox(height: 12),
          _buildOption(
            status: RestaurantStatus.busy,
            color: const Color(0xFFF39C12),
            icon: const AppIcon(AppIcons.clockLine),
            label: 'ยุ่ง (Busy)',
            subtitle: 'ปรับเวลาเตรียมคำสั่งซื้อเพิ่มขึ้น',
          ),
          const SizedBox(height: 12),
          _buildOption(
            status: RestaurantStatus.paused,
            color: const Color(0xFFE74C3C),
            // No pause equivalent in the SVG icon set yet.
            icon: const Icon(Icons.pause_circle_outline_rounded),
            label: 'หยุดชั่วคราว',
            subtitle: 'ไม่รับคำสั่งซื้อเพิ่ม เพื่อจัดการหน้าร้าน',
          ),

          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text(
                  'ร้านเปลี่ยนแปลงเวลาทำการ?',
                  style: AppTypography.body3.copyWith(
                    color: const Color(0xFF888888),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const OpeningHoursScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'อัปเดตเวลาทำการ',
                    style: AppTypography.label3.copyWith(
                      color: const Color(0xFF0066CC),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected != widget.currentStatus
                  ? () {
                      widget.onStatusChanged(_selected);
                      Navigator.pop(context);

                      // Show confirmation dialog when turning back to open from paused
                      if (_selected == RestaurantStatus.open &&
                          widget.currentStatus == RestaurantStatus.paused) {
                        Future.delayed(const Duration(milliseconds: 300), () {
                          if (context.mounted) {
                            _showConfirmResumeDialog(context);
                          }
                        });
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5002B),
                disabledBackgroundColor: const Color(0xFFCCCCCC),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ยืนยัน',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required RestaurantStatus status,
    required Color color,
    // Widget so the paused option can keep its Material fallback icon.
    required Widget icon,
    required String label,
    required String subtitle,
  }) {
    final isSelected = _selected == status;
    return GestureDetector(
      onTap: () => setState(() => _selected = status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE2E8F0),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? color : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: IconTheme(
                data: IconThemeData(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  size: 24,
                ),
                child: icon,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppTypography.label1.copyWith(
                      color: const Color(0xFF111111),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTypography.caption5.copyWith(
                      color: const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              AppIcon(AppIcons.circleCheckFill, color: color, size: 24),
          ],
        ),
      ),
    );
  }

  void _showConfirmResumeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'พร้อมกลับมารับคำสั่งซื้อ?',
          style: AppTypography.heading5.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'โปรดตรวจสอบและยืนยันเวลาทำการร้าน\nเพื่อเตรียมรับคำสั่งซื้อที่จะเข้ามา',
          style: AppTypography.body2.copyWith(color: const Color(0xFF555555)),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE5002B),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'ยืนยันเวลาทำการร้าน',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'ยกเลิก',
                style: AppTypography.label2.copyWith(
                  color: const Color(0xFF888888),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
