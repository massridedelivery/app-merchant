import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:merchant_app/core/theme/app_typography.dart';
import 'package:merchant_app/core/assets/app_icons.dart';
import 'package:merchant_app/core/widgets/app_icon.dart';
import 'package:merchant_app/core/widgets/mass_loading_m.dart';
import 'package:merchant_app/features/restaurant/data/restaurant_repository.dart';
import 'package:merchant_app/features/restaurant/models/store_hours.dart';

class DaySchedule {
  String day;
  String dayTh;
  int dayOfWeek; // BE: 0=Sun … 6=Sat
  bool isOpen;
  bool is24hr;
  String openTime;
  String closeTime;

  DaySchedule({
    required this.day,
    required this.dayTh,
    required this.dayOfWeek,
    this.isOpen = true,
    this.is24hr = false,
    this.openTime = '10:00',
    this.closeTime = '22:00',
  });
}

class OpeningHoursScreen extends ConsumerStatefulWidget {
  const OpeningHoursScreen({super.key});

  @override
  ConsumerState<OpeningHoursScreen> createState() => _OpeningHoursScreenState();
}

class _OpeningHoursScreenState extends ConsumerState<OpeningHoursScreen> {
  final List<DaySchedule> _schedule = [
    DaySchedule(day: 'MON', dayTh: 'จันทร์', dayOfWeek: 1, openTime: '10:00', closeTime: '18:00'),
    DaySchedule(day: 'TUE', dayTh: 'อังคาร', dayOfWeek: 2, openTime: '10:00', closeTime: '18:00'),
    DaySchedule(day: 'WED', dayTh: 'พุธ', dayOfWeek: 3, openTime: '10:00', closeTime: '18:00'),
    DaySchedule(day: 'THU', dayTh: 'พฤหัส', dayOfWeek: 4, openTime: '10:00', closeTime: '18:00'),
    DaySchedule(day: 'FRI', dayTh: 'ศุกร์', dayOfWeek: 5, openTime: '10:00', closeTime: '22:00'),
    DaySchedule(day: 'SAT', dayTh: 'เสาร์', dayOfWeek: 6, openTime: '10:00', closeTime: '22:00'),
    DaySchedule(day: 'SUN', dayTh: 'อาทิตย์', dayOfWeek: 0, openTime: '10:00', closeTime: '22:00'),
  ];

  String _timezone = 'Asia/Bangkok';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHours();
  }

  Future<void> _loadHours() async {
    try {
      final hours = await ref.read(restaurantRepositoryProvider).fetchHours();
      _timezone = hours.timezone;
      for (final d in hours.days) {
        final local = _schedule.where((s) => s.dayOfWeek == d.dayOfWeek);
        if (local.isEmpty) continue;
        final s = local.first;
        s.isOpen = !d.isClosed;
        s.openTime = _snap(d.openTime);
        s.closeTime = _snap(d.closeTime);
        // BE has no 24h flag; open == close is our 24h convention.
        s.is24hr = !d.isClosed && d.openTime == d.closeTime;
      }
    } catch (_) {
      // fall back to the defaults already in _schedule
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Times must be one of the dropdown options, or DropdownButton asserts.
  String _snap(String t) => _timeOptions.contains(t) ? t : '10:00';

  static const _timeOptions = [
    '00:00', '00:30', '01:00', '01:30', '02:00', '02:30', '03:00', '03:30',
    '04:00', '04:30', '05:00', '05:30', '06:00', '06:30', '07:00', '07:30',
    '08:00', '08:30', '09:00', '09:30', '10:00', '10:30', '11:00', '11:30',
    '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30',
    '16:00', '16:30', '17:00', '17:30', '18:00', '18:30', '19:00', '19:30',
    '20:00', '20:30', '21:00', '21:30', '22:00', '22:30', '23:00', '23:30',
  ];

  bool _isSaving = false;

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
          'แก้ไขเวลาจัดส่ง',
          style: AppTypography.heading5.copyWith(
            color: const Color(0xFF111111),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: MassLoadingM(size: 72))
                : ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children:
                        _schedule.map((day) => _buildDayCard(day)).toList(),
                  ),
          ),
          // ─── Save Button ──────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE5002B),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('บันทึก',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayCard(DaySchedule day) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day.dayTh,
                style: AppTypography.body1.copyWith(
                  color: const Color(0xFF111111),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Switch(
                value: day.isOpen,
                activeColor: const Color(0xFFE5002B),
                onChanged: (val) => setState(() => day.isOpen = val),
              ),
            ],
          ),

          if (day.isOpen) ...[
            const SizedBox(height: 12),
            // 24hr toggle
            Row(
              children: [
                const AppIcon(AppIcons.clockLine, size: 16, color: Color(0xFF888888)),
                const SizedBox(width: 8),
                Text('24 ชั่วโมง',
                    style: AppTypography.body3.copyWith(color: const Color(0xFF555555))),
                const Spacer(),
                Switch(
                  value: day.is24hr,
                  activeColor: const Color(0xFFE5002B),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (val) => setState(() => day.is24hr = val),
                ),
              ],
            ),

            if (!day.is24hr) ...[
              const SizedBox(height: 10),
              // Time pickers
              Row(
                children: [
                  Expanded(
                    child: _buildTimeDropdown(
                      label: 'เปิด',
                      value: day.openTime,
                      onChanged: (v) => setState(() => day.openTime = v!),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('–', style: TextStyle(color: Color(0xFF888888), fontSize: 18)),
                  ),
                  Expanded(
                    child: _buildTimeDropdown(
                      label: 'ปิด',
                      value: day.closeTime,
                      onChanged: (v) => setState(() => day.closeTime = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Add hour slot
              GestureDetector(
                onTap: () {},
                child: Text(
                  '+ เพิ่มช่วงเวลาอื่น',
                  style: AppTypography.label3.copyWith(color: const Color(0xFF0066CC)),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTimeDropdown({
    required String label,
    required String value,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppTypography.caption5.copyWith(color: const Color(0xFF888888))),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFCCCCCC)),
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: DropdownButton<String>(
            value: value,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            icon: const AppIcon(AppIcons.chevronDownLine, size: 18, color: Color(0xFF666666)),
            style: AppTypography.body2.copyWith(color: const Color(0xFF222222)),
            items: _timeOptions.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Always send all 7 days — a partial PUT is rejected. 24h is encoded as
      // open == close (the backend reads close <= open as running overnight).
      final days = _schedule
          .map((s) => DayHours(
                dayOfWeek: s.dayOfWeek,
                openTime: s.is24hr ? '00:00' : s.openTime,
                closeTime: s.is24hr ? '00:00' : s.closeTime,
                isClosed: !s.isOpen,
              ))
          .toList()
        ..sort((a, b) => a.dayOfWeek.compareTo(b.dayOfWeek));
      await ref
          .read(restaurantRepositoryProvider)
          .updateHours(StoreHours(days: days, timezone: _timezone));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('บันทึกเวลาเปิด-ปิดเรียบร้อยแล้ว'),
          backgroundColor: Color(0xFFE5002B),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกไม่สำเร็จ: $e'),
          backgroundColor: const Color(0xFFE5002B),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
