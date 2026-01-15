import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _hourlyRateKey = 'hourly_rate';
  static const String _monthlySalaryKey = 'monthly_salary';
  static const String _allowanceKey = 'fixed_allowance';
  static const String _leaveDaysKey = 'leave_days';
  static const String _bhxhDeductionKey = 'bhxh_deduction';
  static const String _responsibilityAllowanceKey = 'responsibility_allowance';
  static const String _diligenceAllowanceKey = 'diligence_allowance';
  static const String _businessTripStartKey = 'business_trip_start';
  static const String _businessTripEndKey = 'business_trip_end';
  static const String _advancePaymentKey = 'advance_payment';
  
  static const double _defaultRate = 85275.0;
  static const double _defaultAllowance = 945000.0;
  static const double _defaultMonthlySalary = 18000000.0;
  static const double _defaultBhxhDeduction = 557550.0;
  static const double _defaultResponsibilityAllowance = 745000.0;
  static const double _defaultDiligenceAllowance = 200000.0;

  Future<double> getHourlyRate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_hourlyRateKey) ?? _defaultRate;
  }

  Future<void> setHourlyRate(double rate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_hourlyRateKey, rate);
  }

  Future<double?> getMonthlySalary() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_monthlySalaryKey) ?? _defaultMonthlySalary;
  }

  Future<void> setMonthlySalary(double salary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_monthlySalaryKey, salary);
  }

  Future<double> getAllowance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_allowanceKey) ?? _defaultAllowance;
  }

  Future<void> setAllowance(double allowance) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_allowanceKey, allowance);
  }

  Future<int> getLeaveDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_leaveDaysKey) ?? 0;
  }

  Future<void> setLeaveDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leaveDaysKey, days);
  }

  Future<double> getBhxhDeduction() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_bhxhDeductionKey) ?? _defaultBhxhDeduction;
  }

  Future<void> setBhxhDeduction(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_bhxhDeductionKey, amount);
  }

  Future<double> getResponsibilityAllowance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_responsibilityAllowanceKey) ?? _defaultResponsibilityAllowance;
  }

  Future<void> setResponsibilityAllowance(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_responsibilityAllowanceKey, amount);
  }

  Future<double> getDiligenceAllowance() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_diligenceAllowanceKey) ?? _defaultDiligenceAllowance;
  }

  Future<void> setDiligenceAllowance(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_diligenceAllowanceKey, amount);
  }

  Future<DateTime?> getBusinessTripStart() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_businessTripStartKey);
    return str != null ? DateTime.parse(str) : null;
  }

  Future<void> setBusinessTripStart(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(_businessTripStartKey);
    } else {
      await prefs.setString(_businessTripStartKey, date.toIso8601String());
    }
  }

  Future<DateTime?> getBusinessTripEnd() async {
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(_businessTripEndKey);
    return str != null ? DateTime.parse(str) : null;
  }

  Future<void> setBusinessTripEnd(DateTime? date) async {
    final prefs = await SharedPreferences.getInstance();
    if (date == null) {
      await prefs.remove(_businessTripEndKey);
    } else {
      await prefs.setString(_businessTripEndKey, date.toIso8601String());
    }
  }

  Future<double> getAdvancePayment() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_advancePaymentKey) ?? 0.0;
  }

  Future<void> setAdvancePayment(double amount) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_advancePaymentKey, amount);
  }
}
