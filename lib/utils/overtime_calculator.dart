import 'package:flutter/material.dart';

class OvertimeCalculator {
  static const double baseHourlyRate = 85275.0;

  static Map<String, double> calculateHours({
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double hourlyRate,
  }) {
    double hours15 = 0;
    double hours18 = 0;
    double hours20 = 0;

    bool isSunday = date.weekday == DateTime.sunday;

    double start = startTime.hour + startTime.minute / 60.0;
    double end = endTime.hour + endTime.minute / 60.0;

    // Handle overnight OT (e.g., 22:00 to 02:00)
    if (end < start) {
      end += 24;
    }

    if (isSunday) {
      hours20 = end - start;
    } else {
      // Weekday logic
      // 17:30 to 22:00 is 1.5x
      // After 22:00 is 1.8x
      
      double current = start;
      while (current < end) {
        double next = current + 0.25; // Check every 15 mins
        if (next > end) next = end;

        double hourOfDay = current % 24;
        
        if (hourOfDay >= 17.5 && hourOfDay < 22.0) {
          hours15 += (next - current);
        } else if (hourOfDay >= 22.0 || hourOfDay < 6.0) {
          hours18 += (next - current);
        } else {
          // Normal working hours or before 17:30
          // User said OT starts from 17:30, so we count anything before as 1.0 or ignore?
          // Usually OT is only what's extra. I'll assume anything before 17:30 is not OT unless Sunday.
        }
        current = next;
      }
    }

    double totalPay = (hours15 * hourlyRate * 1.5) +
        (hours18 * hourlyRate * 1.8) +
        (hours20 * hourlyRate * 2.0);

    return {
      'hours15': hours15,
      'hours18': hours18,
      'hours20': hours20,
      'totalPay': totalPay,
    };
  }

  static Map<String, double> calculateMultiShiftHours({
    required DateTime date,
    required List<Map<String, dynamic>> shifts,
    required double hourlyRate,
  }) {
    double totalHours15 = 0;
    double totalHours18 = 0;
    double totalHours20 = 0;
    double totalPay = 0;

    for (var shift in shifts) {
      final startTime = TimeOfDay(hour: shift['start_hour'], minute: shift['start_minute']);
      final endTime = TimeOfDay(hour: shift['end_hour'], minute: shift['end_minute']);
      
      final result = calculateHours(
        date: date,
        startTime: startTime,
        endTime: endTime,
        hourlyRate: hourlyRate,
      );

      totalHours15 += result['hours15']!;
      totalHours18 += result['hours18']!;
      totalHours20 += result['hours20']!;
      totalPay += result['totalPay']!;
    }

    return {
      'hours15': totalHours15,
      'hours18': totalHours18,
      'hours20': totalHours20,
      'totalPay': totalPay,
    };
  }
}
