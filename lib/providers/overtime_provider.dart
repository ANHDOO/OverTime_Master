import 'package:flutter/material.dart';
import '../models/overtime_entry.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../utils/overtime_calculator.dart';

class OvertimeProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final SettingsService _settingsService = SettingsService();
  List<OvertimeEntry> _entries = [];
  double _hourlyRate = 85275.0;
  double? _monthlySalary;
  bool _isLoading = false;

  List<OvertimeEntry> get entries => _entries;
  double get hourlyRate => _hourlyRate;
  double? get monthlySalary => _monthlySalary;
  bool get isLoading => _isLoading;

  double get totalMonthlyPay {
    double total = 0;
    for (var entry in _entries) {
      if (entry.date.month == DateTime.now().month && entry.date.year == DateTime.now().year) {
        total += entry.totalPay;
      }
    }
    return total;
  }

  Future<void> fetchEntries() async {
    _isLoading = true;
    notifyListeners();
    _hourlyRate = await _settingsService.getHourlyRate();
    _monthlySalary = await _settingsService.getMonthlySalary();
    _entries = await _storageService.getAllEntries();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> updateHourlyRate(double rate) async {
    await _settingsService.setHourlyRate(rate);
    _hourlyRate = rate;
    _monthlySalary = null; // Clear monthly salary if hourly rate is set manually
    await _settingsService.setMonthlySalary(0); // Reset
    notifyListeners();
  }

  Future<void> updateMonthlySalary(double salary) async {
    await _settingsService.setMonthlySalary(salary);
    _monthlySalary = salary;
    // Calculation: Salary / 26 days / 8 hours
    _hourlyRate = salary / 26 / 8;
    await _settingsService.setHourlyRate(_hourlyRate);
    notifyListeners();
  }

  Future<void> addEntry({
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
  }) async {
    final calculations = OvertimeCalculator.calculateHours(
      date: date,
      startTime: startTime,
      endTime: endTime,
      hourlyRate: _hourlyRate,
    );

    final entry = OvertimeEntry(
      date: date,
      startTime: startTime,
      endTime: endTime,
      isSunday: date.weekday == DateTime.sunday,
      hours15: calculations['hours15']!,
      hours18: calculations['hours18']!,
      hours20: calculations['hours20']!,
      hourlyRate: _hourlyRate,
      totalPay: calculations['totalPay']!,
    );

    await _storageService.insertEntry(entry);
    await fetchEntries();
  }

  Future<void> deleteEntry(int id) async {
    await _storageService.deleteEntry(id);
    await fetchEntries();
  }
}
