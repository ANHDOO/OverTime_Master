import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _hourlyRateKey = 'hourly_rate';
  static const String _monthlySalaryKey = 'monthly_salary';
  static const String _allowanceKey = 'fixed_allowance';
  static const String _leaveDaysKey = 'leave_days';
  static const double _defaultRate = 85275.0;
  static const double _defaultAllowance = 945000.0;
  static const double _defaultMonthlySalary = 18000000.0;

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
}
