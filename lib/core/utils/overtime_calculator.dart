import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class OvertimeCalculator {
  /// Calculates OT hours for a single time range.
  /// Uses Time Range Intersection algorithm for maximum accuracy.
  static Map<String, double> calculateHours({
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required double hourlyRate,
  }) {
    double hours15 = 0;
    double hours18 = 0;
    double hours20 = 0;

    final bool isSunday = date.weekday == DateTime.sunday;
    
    double start = startTime.hour + startTime.minute / 60.0;
    double end = endTime.hour + endTime.minute / 60.0;

    // Handle overnight OT
    if (end < start) {
      end += 24;
    }

    if (isSunday) {
      hours20 = end - start;
    } else {
      // Intersection with 1.5x range (17:30 - 22:00)
      hours15 = _getIntersection(start, end, AppConstants.otStartHour, AppConstants.nightShiftStartHour);
      
      // Intersection with 1.8x range (22:00 - 06:00 next day)
      // Range 1: 22:00 - 24:00
      hours18 += _getIntersection(start, end, AppConstants.nightShiftStartHour, 24.0);
      // Range 2: 00:00 - 06:00
      hours18 += _getIntersection(start, end, 24.0, 24.0 + AppConstants.nightShiftEndHour);
      // Range 3: 00:00 - 06:00 (if start was already after midnight)
      hours18 += _getIntersection(start, end, 0.0, AppConstants.nightShiftEndHour);
    }

    double totalPay = (hours15 * hourlyRate * AppConstants.otRate15) +
        (hours18 * hourlyRate * AppConstants.otRate18) +
        (hours20 * hourlyRate * AppConstants.otRate20);

    return {
      'hours15': hours15,
      'hours18': hours18,
      'hours20': hours20,
      'totalPay': totalPay,
    };
  }

  /// Helper to find intersection of two ranges [s1, e1] and [s2, e2]
  static double _getIntersection(double s1, double e1, double s2, double e2) {
    double start = s1 > s2 ? s1 : s2;
    double end = e1 < e2 ? e1 : e2;
    return (end > start) ? (end - start) : 0;
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
