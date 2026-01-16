import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import '../models/overtime_entry.dart';
import '../models/debt_entry.dart';
import '../models/cash_transaction.dart';
import '../models/citizen_profile.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/google_sheets_service.dart';
import '../utils/overtime_calculator.dart';
import '../services/update_service.dart';
import '../services/citizen_lookup_service.dart';

class OvertimeProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final SettingsService _settingsService = SettingsService();
  List<OvertimeEntry> _entries = [];
  double _hourlyRate = 85275.0;
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

  /// Close DB and reload everything from disk (used after external restore)
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
    return getWorkingDaysForMonth(now.year, now.month);
  }

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

  double getHourlyRateForMonth(int year, int month) {
    if (_monthlySalary == null || _monthlySalary! <= 0) {
      return _hourlyRate;
    }
    final baseSalary = _monthlySalary! - _responsibilityAllowance - _diligenceAllowance;
    final workingDays = getWorkingDaysForMonth(year, month) - _leaveDays;
    if (workingDays <= 0) return 0;
    return baseSalary / workingDays / 8;
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
      final List<dynamic> shiftsList = jsonDecode(shiftsJson);
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

  /// Restore a previously deleted entry (for undo functionality)
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
    if (_businessTripStart == null || _businessTripEnd == null) return false;
    
    final monthStart = DateTime(year, month, 1);
    final monthEnd = DateTime(year, month + 1, 0);

    final overlapStart = _businessTripStart!.isAfter(monthStart) ? _businessTripStart! : monthStart;
    final overlapEnd = _businessTripEnd!.isBefore(monthEnd) ? _businessTripEnd! : monthEnd;

    return !overlapStart.isAfter(overlapEnd);
  }

  double calculateBusinessTripPayForMonth(int year, int month) {
    if (_businessTripStart == null || _businessTripEnd == null) return 0;

    // Attribution Logic: Pay the entire trip amount in the month the trip ENDS
    if (_businessTripEnd!.year != year || _businessTripEnd!.month != month) {
      return 0;
    }

    final totalDays = _businessTripEnd!.difference(_businessTripStart!).inDays + 1;
    if (totalDays <= 0) return 0;

    int periods = (totalDays - 1) ~/ 14;
    double dailyRate = 100000.0 + (periods * 20000.0);
    
    return totalDays * dailyRate;
  }

  double calculateBusinessTripPay() {
    return calculateBusinessTripPayForMonth(DateTime.now().year, DateTime.now().month);
  }

  /// Tính toán tổng lương thực lĩnh cho một tháng cụ thể
  double calculateFinalSalaryForMonth(int year, int month) {
    final monthEntries = _entries.where((e) => 
      e.date.month == month && e.date.year == year
    ).toList();

    // OT Breakdown
    double hours15 = monthEntries.fold(0, (sum, e) => sum + e.hours15);
    double hours18 = monthEntries.fold(0, (sum, e) => sum + e.hours18);
    double hours20 = monthEntries.fold(0, (sum, e) => sum + e.hours20);
    
    double hourlyRate = getHourlyRateForMonth(year, month);
    double pay15 = hours15 * hourlyRate * 1.5;
    double pay18 = hours18 * hourlyRate * 1.8;
    double pay20 = hours20 * hourlyRate * 2.0;
    double totalOT = pay15 + pay18 + pay20;

    // Logic: Lương chính = monthlySalary - Responsibility - Diligence
    double baseSalary = (_monthlySalary ?? 0) - _responsibilityAllowance - _diligenceAllowance;
    
    double businessTripPay = calculateBusinessTripPayForMonth(year, month);
    bool isOnTrip = isOnBusinessTripInMonth(year, month);
    double internetPay = isOnTrip ? 120000.0 : 0.0;
    
    // Logic: Xăng xe = 100k nếu không đi công tác, ngược lại = 0
    double gasolinePay = isOnTrip ? 0.0 : 100000.0;
    
    // Sub-totals
    double section1Total = baseSalary + _responsibilityAllowance + _diligenceAllowance + totalOT;
    double section2Total = gasolinePay + businessTripPay + internetPay;
    double totalGrossSalary = section1Total + section2Total; // TỔNG LƯƠNG (1+2)
    double section3Total = _bhxhDeduction + _advancePayment; // CÁC KHOẢN TRỪ

    // Final Salary = (1+2) - 3
    return totalGrossSalary - section3Total;
  }

  double getTotalIncomeForMonth(int year, int month) {
    final monthEntries = _entries.where((e) => 
      e.date.month == month && e.date.year == year
    ).toList();

    double hours15 = monthEntries.fold(0, (sum, e) => sum + e.hours15);
    double hours18 = monthEntries.fold(0, (sum, e) => sum + e.hours18);
    double hours20 = monthEntries.fold(0, (sum, e) => sum + e.hours20);
    
    double hourlyRate = getHourlyRateForMonth(year, month);
    double pay15 = hours15 * hourlyRate * 1.5;
    double pay18 = hours18 * hourlyRate * 1.8;
    double pay20 = hours20 * hourlyRate * 2.0;
    double totalOT = pay15 + pay18 + pay20;

    double baseSalary = (_monthlySalary ?? 0) - _responsibilityAllowance - _diligenceAllowance;
    double businessTripPay = calculateBusinessTripPayForMonth(year, month);
    bool isOnTrip = isOnBusinessTripInMonth(year, month);
    double internetPay = isOnTrip ? 120000.0 : 0.0;
    double gasolinePay = isOnTrip ? 0.0 : 100000.0;
    
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
