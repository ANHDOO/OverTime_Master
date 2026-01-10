import 'package:flutter/material.dart';

/// Template cho các khung giờ OT thường dùng
class OTTemplate {
  final String id;
  final String name;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final IconData icon;
  final Color color;
  
  const OTTemplate({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.icon = Icons.access_time,
    this.color = Colors.blue,
  });
  
  /// Các template mặc định
  static const List<OTTemplate> defaults = [
    OTTemplate(
      id: 'afternoon',
      name: 'Chiều thường',
      startTime: TimeOfDay(hour: 17, minute: 30),
      endTime: TimeOfDay(hour: 21, minute: 0),
      icon: Icons.wb_twilight,
      color: Colors.orange,
    ),
    OTTemplate(
      id: 'night',
      name: 'Làm đêm',
      startTime: TimeOfDay(hour: 17, minute: 30),
      endTime: TimeOfDay(hour: 23, minute: 0),
      icon: Icons.nightlight_round,
      color: Colors.indigo,
    ),
    OTTemplate(
      id: 'fullday',
      name: 'Cuối tuần',
      startTime: TimeOfDay(hour: 7, minute: 0),
      endTime: TimeOfDay(hour: 17, minute: 0),
      icon: Icons.wb_sunny,
      color: Colors.amber,
    ),
    OTTemplate(
      id: 'morning',
      name: 'Buổi sáng',
      startTime: TimeOfDay(hour: 7, minute: 0),
      endTime: TimeOfDay(hour: 12, minute: 0),
      icon: Icons.coffee,
      color: Colors.teal,
    ),
    OTTemplate(
      id: 'early_night',
      name: 'Đêm sớm',
      startTime: TimeOfDay(hour: 19, minute: 0),
      endTime: TimeOfDay(hour: 22, minute: 30),
      icon: Icons.dark_mode,
      color: Colors.purple,
    ),
  ];
  
  /// Format time range for display
  String get timeRangeString {
    String formatTime(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }
  
  /// Calculate hours
  double get hours {
    int startMinutes = startTime.hour * 60 + startTime.minute;
    int endMinutes = endTime.hour * 60 + endTime.minute;
    if (endMinutes <= startMinutes) endMinutes += 24 * 60;
    return (endMinutes - startMinutes) / 60;
  }
}
