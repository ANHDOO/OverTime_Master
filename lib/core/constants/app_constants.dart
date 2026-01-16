class AppConstants {
  // OT Constants
  static const double otRate15 = 1.5;
  static const double otRate18 = 1.8;
  static const double otRate20 = 2.0;

  static const double otStartHour = 17.5; // 17:30
  static const double nightShiftStartHour = 22.0; // 22:00
  static const double nightShiftEndHour = 6.0; // 06:00

  // Salary Constants
  static const double baseHourlyRate = 85000.0;
  static const double defaultInternetPay = 120000.0;
  static const double defaultGasolinePay = 100000.0;
  static const double defaultDailyBusinessTripPay = 100000.0;
  static const double businessTripBonusPerPeriod = 20000.0;
  static const int businessTripPeriodDays = 14;

  // PIT Constants (2026)
  static const double personalDeduction = 15500000.0;
  static const double dependentDeduction = 6200000.0;
  static const double insuranceRate = 0.105;

  // Debt Constants
  static const double debtBaseInterestRate = 0.015; // 1.5%
  static const double debtDailyInterestRate = 0.001; // 0.1% per day
  static const int debtInterestStartDay = 5;
  static const int debtDueDateDay = 20;
}
