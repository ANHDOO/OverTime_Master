import 'package:flutter/material.dart';
import '../models/overtime_entry.dart';
import '../models/debt_entry.dart';
import '../models/cash_transaction.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../utils/overtime_calculator.dart';

class OvertimeProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final SettingsService _settingsService = SettingsService();
  List<OvertimeEntry> _entries = [];
  List<DebtEntry> _debtEntries = [];
  List<CashTransaction> _cashTransactions = [];
  double _hourlyRate = 85275.0;
  double? _monthlySalary = 15000000.0;
  double _allowance = 945000.0;
  int _leaveDays = 0;
  bool _isLoading = false;

  List<OvertimeEntry> get entries => _entries;
  List<DebtEntry> get debtEntries => _debtEntries;
  List<CashTransaction> get cashTransactions => _cashTransactions;
  double get hourlyRate => _hourlyRate;
  double? get monthlySalary => _monthlySalary;
  double get allowance => _allowance;
  int get leaveDays => _leaveDays;
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

  double get totalDebtInterest {
    double total = 0;
    for (var debt in _debtEntries) {
      final interest = debt.calculateInterest();
      total += interest['totalInterest']!;
    }
    return total;
  }

  double get totalDebtAmount {
    double total = 0;
    for (var debt in _debtEntries) {
      total += debt.amount;
    }
    return total;
  }

  // Cash Flow getters
  double get totalCashIncome {
    return _cashTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get totalCashExpense {
    return _cashTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
  }

  double get cashBalance => totalCashIncome - totalCashExpense;

  Future<void> fetchEntries() async {
    _isLoading = true;
    notifyListeners();
    _hourlyRate = await _settingsService.getHourlyRate();
    _monthlySalary = await _settingsService.getMonthlySalary();
    _allowance = await _settingsService.getAllowance();
    _leaveDays = await _settingsService.getLeaveDays();
    _entries = await _storageService.getAllEntries();
    _debtEntries = await _storageService.getAllDebtEntries();
    _cashTransactions = await _storageService.getAllCashTransactions();
    _isLoading = false;
    notifyListeners();
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
    final baseSalary = _monthlySalary! - _allowance;
    final workingDays = getWorkingDaysForMonth(year, month) - _leaveDays;
    if (workingDays <= 0) return 0;
    return baseSalary / workingDays / 8;
  }

  Future<void> updateMonthlySalary(double salary) async {
    await _settingsService.setMonthlySalary(salary);
    _monthlySalary = salary;
    notifyListeners();
  }

  Future<void> saveSalarySettings({
    required double totalSalary,
    required double allowance,
    required int leaveDays,
    required double hourlyRate,
  }) async {
    await _settingsService.setMonthlySalary(totalSalary);
    await _settingsService.setAllowance(allowance);
    await _settingsService.setLeaveDays(leaveDays);
    await _settingsService.setHourlyRate(hourlyRate);
    
    _monthlySalary = totalSalary;
    _allowance = allowance;
    _leaveDays = leaveDays;
    _hourlyRate = hourlyRate;

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

  // Debt Entry methods
  Future<void> addDebtEntry({
    required DateTime month,
    required double amount,
  }) async {
    final entry = DebtEntry(
      month: month,
      amount: amount,
      createdAt: DateTime.now(),
    );
    await _storageService.insertDebtEntry(entry);
    await fetchEntries();
  }

  Future<void> deleteDebtEntry(int id) async {
    await _storageService.deleteDebtEntry(id);
    await fetchEntries();
  }

  Future<void> toggleDebtPaid(DebtEntry entry) async {
    final isPaid = !entry.isPaid;
    final updatedEntry = entry.copyWith(
      isPaid: isPaid,
      paidAt: isPaid ? DateTime.now() : null,
    );
    await _storageService.updateDebtEntry(updatedEntry);
    await fetchEntries();
  }

  Future<void> updateDebtEntry(DebtEntry entry) async {
    await _storageService.updateDebtEntry(entry);
    await fetchEntries();
  }

  // Cash Transaction methods
  Future<void> addCashTransaction({
    required TransactionType type,
    required double amount,
    required String description,
    required DateTime date,
    String? imagePath,
    String? note,
    String project = 'Mặc định',
  }) async {
    final transaction = CashTransaction(
      type: type,
      amount: amount,
      description: description,
      date: date,
      imagePath: imagePath,
      note: note,
      project: project,
    );
    await _storageService.insertCashTransaction(transaction);
    await fetchEntries();
  }

  Future<void> deleteCashTransaction(int id) async {
    await _storageService.deleteCashTransaction(id);
    await fetchEntries();
  }

  Future<void> updateCashTransaction(CashTransaction transaction) async {
    await _storageService.updateCashTransaction(transaction);
    await fetchEntries();
  }
}
