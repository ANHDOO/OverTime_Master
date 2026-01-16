import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../data/models/overtime_entry.dart';
import '../../data/models/ot_template.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/settings_service.dart';
import '../../data/services/excel_service.dart';
import '../../core/utils/overtime_calculator.dart';
import '../../data/services/update_service.dart';
import '../../data/services/salary_service.dart';
import '../../core/constants/app_constants.dart';

class OvertimeProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final SettingsService _settingsService = SettingsService();
  final SalaryService _salaryService = SalaryService();
  
  List<OvertimeEntry> _entries = [];
  double _hourlyRate = AppConstants.baseHourlyRate;
  double? _monthlySalary = 18000000.0;
  double _allowance = 945000.0;
  int _leaveDays = 0;
  double _bhxhDeduction = 557550.0;
  bool _isLoading = false;
  bool _hasUpdate = false;
  UpdateInfo? _updateInfo;
  
  // Salary Estimation state
  double _responsibilityAllowance = 745000.0;
  double _diligenceAllowance = 200000.0;
  DateTime? _businessTripStart;
  DateTime? _businessTripEnd;
  double _advancePayment = 0.0;

  List<OvertimeEntry> get entries => _entries;
  double get hourlyRate => _hourlyRate;
  double? get monthlySalary => _monthlySalary;
  double get allowance => _allowance;
  int get leaveDays => _leaveDays;
  double get bhxhDeduction => _bhxhDeduction;
  bool get isLoading => _isLoading;
  bool get hasUpdate => _hasUpdate;
  UpdateInfo? get updateInfo => _updateInfo;
  
  double get responsibilityAllowance => _responsibilityAllowance;
  double get diligenceAllowance => _diligenceAllowance;
  DateTime? get businessTripStart => _businessTripStart;
  DateTime? get businessTripEnd => _businessTripEnd;
  double get advancePayment => _advancePayment;

  Future<void> fetchEntries() async {
    _isLoading = true;
    notifyListeners();
    try {
      _hourlyRate = await _settingsService.getHourlyRate();
      _monthlySalary = await _settingsService.getMonthlySalary();
      _allowance = await _settingsService.getAllowance();
      _leaveDays = await _settingsService.getLeaveDays();
      _bhxhDeduction = await _settingsService.getBhxhDeduction();
      _responsibilityAllowance = await _settingsService.getResponsibilityAllowance();
      _diligenceAllowance = await _settingsService.getDiligenceAllowance();
      _businessTripStart = await _settingsService.getBusinessTripStart();
      _businessTripEnd = await _settingsService.getBusinessTripEnd();
      _advancePayment = await _settingsService.getAdvancePayment();
      _entries = await _storageService.getAllEntries();
    } catch (e) {
      debugPrint('Error fetching entries: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    
    // Silent update check
    checkUpdateSilently();
  }

  Future<void> checkUpdateSilently() async {
    try {
      final updateService = UpdateService();
      final result = await updateService.checkForUpdate();
      _hasUpdate = result.hasUpdate;
      _updateInfo = result.updateInfo;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking update silently: $e');
    }
  }

  Future<void> reloadFromDisk() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _storageService.closeDatabase();
      await fetchEntries();
    } catch (e) {
      debugPrint('Error reloading from disk: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateHourlyRate(double rate) async {
    await _settingsService.setHourlyRate(rate);
    _hourlyRate = rate;
    notifyListeners();
  }

  int getWorkingDaysInMonth() {
    final now = DateTime.now();
    return _salaryService.getWorkingDaysForMonth(now.year, now.month);
  }

  int getWorkingDaysForMonth(int year, int month) {
    return _salaryService.getWorkingDaysForMonth(year, month);
  }

  double getHourlyRateForMonth(int year, int month) {
    if (_monthlySalary == null || _monthlySalary! <= 0) {
      return _hourlyRate;
    }
    return _salaryService.calculateHourlyRate(
      monthlySalary: _monthlySalary!,
      responsibilityAllowance: _responsibilityAllowance,
      diligenceAllowance: _diligenceAllowance,
      workingDaysInMonth: _salaryService.getWorkingDaysForMonth(year, month),
      leaveDays: _leaveDays,
    );
  }

  Future<void> updateMonthlySalary(double salary) async {
    await _settingsService.setMonthlySalary(salary);
    _monthlySalary = salary;
    notifyListeners();
  }

  Future<void> updateAdvancePayment(double amount) async {
    await _settingsService.setAdvancePayment(amount);
    _advancePayment = amount;
    notifyListeners();
  }

  Future<void> updateBhxhDeduction(double amount) async {
    await _settingsService.setBhxhDeduction(amount);
    _bhxhDeduction = amount;
    notifyListeners();
  }

  Future<void> saveSalarySettings({
    required double totalSalary,
    required double allowance,
    required int leaveDays,
    required double bhxhDeduction,
    required double hourlyRate,
    double? responsibilityAllowance,
    double? diligenceAllowance,
  }) async {
    await _settingsService.setMonthlySalary(totalSalary);
    await _settingsService.setAllowance(allowance);
    await _settingsService.setLeaveDays(leaveDays);
    await _settingsService.setBhxhDeduction(bhxhDeduction);
    await _settingsService.setHourlyRate(hourlyRate);
    if (responsibilityAllowance != null) await _settingsService.setResponsibilityAllowance(responsibilityAllowance);
    if (diligenceAllowance != null) await _settingsService.setDiligenceAllowance(diligenceAllowance);
    
    _monthlySalary = totalSalary;
    _allowance = allowance;
    _leaveDays = leaveDays;
    _bhxhDeduction = bhxhDeduction;
    _hourlyRate = hourlyRate;
    if (responsibilityAllowance != null) _responsibilityAllowance = responsibilityAllowance;
    if (diligenceAllowance != null) _diligenceAllowance = diligenceAllowance;

    await _recalculateAllEntries();
    notifyListeners();
  }

  Future<void> _recalculateAllEntries() async {
    for (var entry in _entries) {
      final calculations = OvertimeCalculator.calculateHours(
        date: entry.date,
        startTime: entry.startTime,
        endTime: entry.endTime,
        hourlyRate: _hourlyRate,
      );

      final updatedEntry = OvertimeEntry(
        id: entry.id,
        date: entry.date,
        startTime: entry.startTime,
        endTime: entry.endTime,
        isSunday: entry.isSunday,
        hours15: calculations['hours15']!,
        hours18: calculations['hours18']!,
        hours20: calculations['hours20']!,
        hourlyRate: _hourlyRate,
        totalPay: calculations['totalPay']!,
      );

      await _storageService.updateEntry(updatedEntry);
    }
    _entries = await _storageService.getAllEntries();
  }

  Future<void> addEntry({
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    String? shiftsJson,
    int? id,
  }) async {
    Map<String, double> calculations;
    
    if (shiftsJson != null) {
      final List<dynamic> shiftsList = json.decode(shiftsJson);
      calculations = OvertimeCalculator.calculateMultiShiftHours(
        date: date,
        shifts: shiftsList.cast<Map<String, dynamic>>(),
        hourlyRate: _hourlyRate,
      );
    } else {
      calculations = OvertimeCalculator.calculateHours(
        date: date,
        startTime: startTime,
        endTime: endTime,
        hourlyRate: _hourlyRate,
      );
    }

    final entry = OvertimeEntry(
      id: id,
      date: date,
      startTime: startTime,
      endTime: endTime,
      isSunday: date.weekday == DateTime.sunday,
      hours15: calculations['hours15']!,
      hours18: calculations['hours18']!,
      hours20: calculations['hours20']!,
      hourlyRate: _hourlyRate,
      totalPay: calculations['totalPay']!,
      shiftsJson: shiftsJson,
    );

    if (id != null) {
      await _storageService.updateEntry(entry);
    } else {
      await _storageService.insertEntry(entry);
    }
    await fetchEntries();
  }

  Future<void> deleteEntry(int id) async {
    await _storageService.deleteEntry(id);
    await fetchEntries();
  }

  Future<void> restoreEntry(OvertimeEntry entry) async {
    await _storageService.insertEntry(entry);
    await fetchEntries();
  }

  Future<void> updateResponsibilityAllowance(double amount) async {
    await _settingsService.setResponsibilityAllowance(amount);
    _responsibilityAllowance = amount;
    notifyListeners();
  }

  Future<void> updateDiligenceAllowance(double amount) async {
    await _settingsService.setDiligenceAllowance(amount);
    _diligenceAllowance = amount;
    notifyListeners();
  }

  Future<void> updateBusinessTripDates(DateTime? start, DateTime? end) async {
    await _settingsService.setBusinessTripStart(start);
    await _settingsService.setBusinessTripEnd(end);
    _businessTripStart = start;
    _businessTripEnd = end;
    notifyListeners();
  }

  bool isOnBusinessTripInMonth(int year, int month) {
    return _salaryService.getBusinessTripDaysInMonth(
      start: _businessTripStart,
      end: _businessTripEnd,
      year: year,
      month: month,
    ) > 0;
  }

  int calculateBusinessTripDaysInMonth(int year, int month) {
    return _salaryService.getBusinessTripDaysInMonth(
      start: _businessTripStart,
      end: _businessTripEnd,
      year: year,
      month: month,
    );
  }

  double calculateBusinessTripPayForMonth(int year, int month) {
    return _salaryService.calculateBusinessTripPay(
      start: _businessTripStart,
      end: _businessTripEnd,
      targetYear: year,
      targetMonth: month,
    );
  }

  double calculateBusinessTripPay() {
    return calculateBusinessTripPayForMonth(DateTime.now().year, DateTime.now().month);
  }

  double calculateFinalSalaryForMonth(int year, int month) {
    final monthEntries = _entries.where((e) => 
      e.date.month == month && e.date.year == year
    ).toList();

    double hours15 = monthEntries.fold(0, (sum, e) => sum + e.hours15);
    double hours18 = monthEntries.fold(0, (sum, e) => sum + e.hours18);
    double hours20 = monthEntries.fold(0, (sum, e) => sum + e.hours20);
    
    double hourlyRate = getHourlyRateForMonth(year, month);
    double pay15 = hours15 * hourlyRate * AppConstants.otRate15;
    double pay18 = hours18 * hourlyRate * AppConstants.otRate18;
    double pay20 = hours20 * hourlyRate * AppConstants.otRate20;
    double totalOT = pay15 + pay18 + pay20;

    return _salaryService.calculateFinalSalary(
      monthlySalary: _monthlySalary ?? 0,
      responsibilityAllowance: _responsibilityAllowance,
      diligenceAllowance: _diligenceAllowance,
      totalOTPay: totalOT,
      businessTripPay: calculateBusinessTripPayForMonth(year, month),
      tripDays: calculateBusinessTripDaysInMonth(year, month),
      bhxhDeduction: _bhxhDeduction,
      advancePayment: _advancePayment,
    );
  }

  double getTotalIncomeForMonth(int year, int month) {
    final monthEntries = _entries.where((e) => 
      e.date.month == month && e.date.year == year
    ).toList();

    double hours15 = monthEntries.fold(0, (sum, e) => sum + e.hours15);
    double hours18 = monthEntries.fold(0, (sum, e) => sum + e.hours18);
    double hours20 = monthEntries.fold(0, (sum, e) => sum + e.hours20);
    
    double hourlyRate = getHourlyRateForMonth(year, month);
    double pay15 = hours15 * hourlyRate * AppConstants.otRate15;
    double pay18 = hours18 * hourlyRate * AppConstants.otRate18;
    double pay20 = hours20 * hourlyRate * AppConstants.otRate20;
    double totalOT = pay15 + pay18 + pay20;

    double baseSalary = (_monthlySalary ?? 0) - _responsibilityAllowance - _diligenceAllowance;
    double businessTripPay = calculateBusinessTripPayForMonth(year, month);
    int tripDays = calculateBusinessTripDaysInMonth(year, month);
    double internetPay = tripDays >= 14 ? AppConstants.defaultInternetPay : 0.0;
    double gasolinePay = tripDays > 0 ? 0.0 : AppConstants.defaultGasolinePay;
    
    return baseSalary + _responsibilityAllowance + _diligenceAllowance + totalOT + gasolinePay + businessTripPay + internetPay;
  }

  Map<int, Map<String, dynamic>> getWorkTrends() {
    final trends = <int, Map<String, dynamic>>{};
    for (int i = 1; i <= 7; i++) {
      trends[i] = {'count': 0, 'totalHours': 0.0};
    }

    for (var entry in _entries) {
      final weekday = entry.date.weekday;
      final hours = entry.hours15 + entry.hours18 + entry.hours20;
      trends[weekday]!['count'] = (trends[weekday]!['count'] as int) + 1;
      trends[weekday]!['totalHours'] = (trends[weekday]!['totalHours'] as double) + hours;
    }
    return trends;
  }
}
