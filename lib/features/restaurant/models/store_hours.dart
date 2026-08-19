// Store opening hours (SCRUM-63). Verified against staging:
//   GET/PUT /api/food/restaurant/hours
//   { days: [ {day_of_week, open_time "HH:MM", close_time "HH:MM", is_closed} x7 ],
//     timezone }
// day_of_week: 0=Sunday … 6=Saturday. PUT must send all 7 days. A close_time
// less than or equal to open_time means the slot runs overnight.

class DayHours {
  final int dayOfWeek; // 0=Sun … 6=Sat
  final String openTime; // "HH:MM"
  final String closeTime; // "HH:MM"
  final bool isClosed;

  const DayHours({
    required this.dayOfWeek,
    required this.openTime,
    required this.closeTime,
    required this.isClosed,
  });

  factory DayHours.fromJson(Map<String, dynamic> json) => DayHours(
        dayOfWeek: (json['day_of_week'] as num?)?.toInt() ?? 0,
        openTime: json['open_time']?.toString() ?? '10:00',
        closeTime: json['close_time']?.toString() ?? '22:00',
        isClosed: json['is_closed'] == true,
      );

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'open_time': openTime,
        'close_time': closeTime,
        'is_closed': isClosed,
      };
}

class StoreHours {
  final List<DayHours> days;
  final String timezone;

  const StoreHours({required this.days, required this.timezone});

  factory StoreHours.fromJson(Map<String, dynamic> json) => StoreHours(
        days: (json['days'] as List? ?? [])
            .map((e) => DayHours.fromJson(e as Map<String, dynamic>))
            .toList(),
        timezone: json['timezone']?.toString() ?? 'Asia/Bangkok',
      );

  Map<String, dynamic> toJson() => {
        'days': days.map((d) => d.toJson()).toList(),
        'timezone': timezone,
      };
}
