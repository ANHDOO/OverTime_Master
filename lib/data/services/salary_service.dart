import '../../core/constants/app_constants.dart';

class SalaryService {
  /// Calculates working days in a specific month (excluding Sundays)
  int getWorkingDaysForMonth(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0);
    int workingDays = 0;
    for (int day = 1; day <= lastDay.day; day++) {
      final date = DateTime(year, month, day);
      if (date.weekday != DateTime.sunday) {
        workingDays++;
      }
    }
    return workingDays;
  }

  /// Calculates dynamic hourly rate based on monthly salary and actual working days
  double calculateHourlyRate({
    required double monthlySalary,
    required double responsibilityAllowance,
    required double diligenceAllowance,
    required int workingDaysInMonth,
    required int leaveDays,
  }) {
    final baseSalary = monthlySalary - responsibilityAllowance - diligenceAllowance;
    final actualWorkingDays = workingDaysInMonth - leaveDays;
    
    if (actualWorkingDays <= 0) return 0;
    
    // Standard 8 hours per day
    return baseSalary / actualWorkingDays / 8;
  }

  /// Calculates business trip pay based on trip duration and periods
  double calculateBusinessTripPay({
    required DateTime? start,
    required DateTime? end,
    required int targetYear,
    required int targetMonth,
  }) {
    if (start == null || end == null) return 0;

    // Attribution Logic: Pay the entire trip amount in the month the trip ENDS
    if (end.year != targetYear || end.month != targetMonth) {
      return 0;
    }

    final totalDays = end.difference(start).inDays + 1;
    if (totalDays <= 0) return 0;

    int periods = (totalDays - 1) ~/ AppConstants.businessTripPeriodDays;
    double dailyRate = AppConstants.defaultDailyBusinessTripPay + (periods * AppConstants.businessTripBonusPerPeriod);
    
    return totalDays * dailyRate;
  }

  /// Checks if a business trip overlaps with a specific month
  bool isOnBusinessTripInMonth({
    required DateTime? start,
    required DateTime? end,
    required int year,
    required int month,
  }) {
    if (start == null || end == null) return false;
    
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);

    final overlapStart = start.isAfter(monthStart) ? start : monthStart;
    final overlapEnd = end.isBefore(monthEnd) ? end : monthEnd;

    return !overlapStart.isAfter(overlapEnd);
  }

  /// Calculates final net salary for a month
  double calculateFinalSalary({
    required double monthlySalary,
    required double responsibilityAllowance,
    required double diligenceAllowance,
    required double totalOTPay,
    required double businessTripPay,
    required bool isOnTrip,
    required double bhxhDeduction,
    required double advancePayment,
  }) {
    double internetPay = isOnTrip ? AppConstants.defaultInternetPay : 0.0;
    double gasolinePay = isOnTrip ? 0.0 : AppConstants.defaultGasolinePay;
    
    double totalGross = monthlySalary + totalOTPay + gasolinePay + businessTripPay + internetPay;
    double totalDeductions = bhxhDeduction + advancePayment;

    return totalGross - totalDeductions;
  }
}
