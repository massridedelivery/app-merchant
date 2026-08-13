import 'package:flutter/material.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/features/restaurant/presentation/screens/opening_hours_screen.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';

class ClosingHoursScreen extends StatelessWidget {
  const ClosingHoursScreen({super.key});

  static const _specialClosures = [
    {
      'id': 'CAS-100020539816',
      'reason': 'ปิดร้านยกเลิกสัญญา',
      'status': 'PAUSED',
      'date': '26/04/2025 - 26/04/2099',
    }
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: const BackButton(color: Color(0xFF333333)),
        title: Text(
          'เวลาเปิด-ปิดร้าน',
          style: AppTypography.heading5.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // ─── Special Closures ──────────────────────────
            _buildSectionHeader('วันและเวลาพิเศษ'),
            Container(
              color: Colors.white,
              child: Column(
                children: _specialClosures.map((c) {
                  return ListTile(
                    contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                    title: Text(c['id']!,
                        style: AppTypography.body2.copyWith(
                          color: const Color(0xFF111111),
                          fontWeight: FontWeight.w500,
                        )),
                    subtitle: Text(c['reason']!,
                        style: AppTypography.body3.copyWith(color: const Color(0xFF888888))),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEDEB),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'หยุดชั่วคราว',
                        style: AppTypography.caption5.copyWith(
                          color: const Color(0xFFCC0000),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),

            // ─── Delivery Hours ────────────────────────────
            _buildSectionHeader('เวลาจัดส่ง'),
            Container(
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                title: Text('จันทร์ – พฤหัส: 10:00 – 18:00',
                    style: AppTypography.body2.copyWith(color: const Color(0xFF333333))),
                subtitle: Text('ศุกร์ – อาทิตย์: ปิด',
                    style: AppTypography.body3.copyWith(color: const Color(0xFF888888))),
                trailing: GestureDetector(
                  onTap: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const OpeningHoursScreen()));
                  },
                  child: Text(
                    'แก้ไข',
                    style: AppTypography.label3.copyWith(color: const Color(0xFF0066CC)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ─── Dine-in ───────────────────────────────────
            Container(
              color: Colors.white,
              child: ListTile(
                contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                title: Text('กำหนดเวลาสำหรับกินที่ร้าน',
                    style: AppTypography.body2.copyWith(color: const Color(0xFF333333))),
                trailing: const AppIcon(AppIcons.chevronRightLine, color: Color(0xFF888888)),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: AppTypography.body3.copyWith(
          color: const Color(0xFF888888),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
