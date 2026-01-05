import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _hourlyRateKey = 'hourly_rate';
  static const String _monthlySalaryKey = 'monthly_salary';
  static const double _defaultRate = 85275.0;

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
    return prefs.getDouble(_monthlySalaryKey);
  }

  Future<void> setMonthlySalary(double salary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_monthlySalaryKey, salary);
  }
}
