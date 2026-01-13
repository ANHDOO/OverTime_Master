import 'package:flutter/material.dart';

class OvertimeEntry {
  final int? id;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final bool isSunday;
  final double hours15; // 17:30 - 22:00 (1.5x)
  final double hours18; // After 22:00 (1.8x)
  final double hours20; // Sunday (2.0x)
  final double hourlyRate;
  final double totalPay;

  OvertimeEntry({
    this.id,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.isSunday,
    required this.hours15,
    required this.hours18,
    required this.hours20,
    required this.hourlyRate,
    required this.totalPay,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'start_hour': startTime.hour,
      'start_minute': startTime.minute,
      'end_hour': endTime.hour,
      'end_minute': endTime.minute,
      'is_sunday': isSunday ? 1 : 0,
      'hours_15': hours15,
      'hours_18': hours18,
      'hours_20': hours20,
      'hourly_rate': hourlyRate,
      'total_pay': totalPay,
    };
  }

  factory OvertimeEntry.fromMap(Map<String, dynamic> map) {
    return OvertimeEntry(
      id: map['id'],
      date: DateTime.parse(map['date']),
      startTime: TimeOfDay(hour: map['start_hour'], minute: map['start_minute']),
      endTime: TimeOfDay(hour: map['end_hour'], minute: map['end_minute']),
      isSunday: map['is_sunday'] == 1,
      hours15: map['hours_15'],
      hours18: map['hours_18'],
      hours20: map['hours_20'],
      hourlyRate: map['hourly_rate'] ?? 85275.0, // Default for old entries
      totalPay: map['total_pay'],
    );
  }
}
