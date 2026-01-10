import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/material.dart';
import '../models/overtime_entry.dart';
import '../models/debt_entry.dart';
import '../models/cash_transaction.dart';
import '../services/storage_service.dart';
import '../services/settings_service.dart';
import '../services/google_sheets_service.dart';
import '../services/notification_service.dart';
import '../utils/overtime_calculator.dart';
import '../services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OvertimeProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final SettingsService _settingsService = SettingsService();
  List<OvertimeEntry> _entries = [];
  List<DebtEntry> _debtEntries = [];
  List<CashTransaction> _cashTransactions = [];
  double _hourlyRate = 85275.0;
  double? _monthlySalary = 18000000.0;
  double _allowance = 945000.0;
  int _leaveDays = 0;
  bool _isLoading = false;
  bool _hasUpdate = false;
  UpdateInfo? _updateInfo;

  List<OvertimeEntry> get entries => _entries;
  List<DebtEntry> get debtEntries => _debtEntries;
  List<CashTransaction> get cashTransactions => _cashTransactions;
  double get hourlyRate => _hourlyRate;
  double? get monthlySalary => _monthlySalary;
  double get allowance => _allowance;
  int get leaveDays => _leaveDays;
  bool get isLoading => _isLoading;
  bool get hasUpdate => _hasUpdate;
  UpdateInfo? get updateInfo => _updateInfo;

  double get totalMonthlyPay {
    double total = 0;
    for (var entry in _entries) {
      if (entry.date.month == DateTime.now().month && entry.date.year == DateTime.now().year) {
        total += entry.totalPay;
      }
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

  double get totalDebtInterest {
    double total = 0;
    for (var debt in _debtEntries) {
      final interest = debt.calculateInterest();
      total += interest['totalInterest']!;
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
    
    // Silent update check
    checkUpdateSilently();

    // One-time migration sync for Payment Type (v1.0.5)
    _checkMigrationSync();
  }

  Future<void> _checkMigrationSync() async {
    final prefs = await SharedPreferences.getInstance();
    final isSynced = prefs.getBool('payment_type_migration_synced_v8') ?? false;
    if (!isSynced) {
      debugPrint('🚀 Starting one-time migration sync for Payment Type...');
      await syncAllProjectsToSheets();
      await prefs.setBool('payment_type_migration_synced_v8', true);
      debugPrint('✅ Migration sync completed');
    }
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
    String paymentType = 'Hoá đơn giấy',
  }) async {
    final transaction = CashTransaction(
      type: type,
      amount: amount,
      description: description,
      date: date,
      imagePath: imagePath,
      note: note,
      project: project,
      paymentType: paymentType,
    );
    await _storageService.insertCashTransaction(transaction);
    await fetchEntries();
    
    // Tự động sync lên Google Sheets
    await _syncProjectToSheets(project);
  }

  Future<void> deleteCashTransaction(int id) async {
    // Lấy transaction trước khi xóa để lấy imagePath và project
    final transaction = _cashTransactions.firstWhere((t) => t.id == id);
    final project = transaction.project;
    final imagePath = transaction.imagePath;
    
    await _storageService.deleteCashTransaction(id);
    
    // Xoá file ảnh vật lý nếu có
    if (imagePath != null) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('🗑️ Deleted image: $imagePath');
        }
      } catch (e) {
        debugPrint('⚠️ Error deleting image file: $e');
      }
    }

    await fetchEntries();
    
    // Sync lại sau khi xóa
    await _syncProjectToSheets(project);
  }

  /// Tính dung lượng ảnh chứng từ (trong documents)
  Future<double> getImagesSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      double totalSize = 0;
      for (var file in files) {
        if (file is File && path.basename(file.path).startsWith('receipt_')) {
          totalSize += await file.length();
        }
      }
      return totalSize / (1024 * 1024); // MB
    } catch (e) {
      return 0;
    }
  }

  /// Dọn dẹp ảnh mồ côi (không có trong DB)
  Future<void> cleanupOrphanedImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      final dbImages = _cashTransactions
          .where((t) => t.imagePath != null)
          .map((t) => t.imagePath!)
          .toSet();

      for (var file in files) {
        if (file is File && path.basename(file.path).startsWith('receipt_')) {
          if (!dbImages.contains(file.path)) {
            await file.delete();
            debugPrint('🗑️ Cleaned up orphaned image: ${file.path}');
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error cleaning up images: $e');
    }
  }

  Future<void> updateCashTransaction(CashTransaction transaction) async {
    final oldProject = _cashTransactions.firstWhere((t) => t.id == transaction.id).project;
    
    await _storageService.updateCashTransaction(transaction);
    await fetchEntries();
    
    // Sync cả project cũ và mới (nếu đổi project)
    await _syncProjectToSheets(oldProject);
    if (transaction.project != oldProject) {
      await _syncProjectToSheets(transaction.project);
    }
  }
  
  /// Tính tổng income và expense theo project
  Map<String, double> _getProjectTotals(String project) {
    final projectTransactions = _cashTransactions.where((t) => t.project == project).toList();
    final income = projectTransactions
        .where((t) => t.type == TransactionType.income)
        .fold(0.0, (sum, t) => sum + t.amount);
    final expense = projectTransactions
        .where((t) => t.type == TransactionType.expense)
        .fold(0.0, (sum, t) => sum + t.amount);
    return {'income': income, 'expense': expense};
  }
  
  /// Đồng bộ project lên Google Sheets
  Future<void> _syncProjectToSheets(String project) async {
    if (project == 'Mặc định') return; // Không sync project mặc định
    
    try {
      final sheetsService = GoogleSheetsService();
      
      // Kiểm tra xem có access token chưa
      final token = await sheetsService.getAccessToken();
      if (token == null || token.isEmpty) {
        debugPrint('⚠️ Google Sheets access token chưa được cấu hình. Bỏ qua sync.');
        return;
      }
      
      // Lấy tất cả transaction của project
      final projectTransactions = _cashTransactions.where((t) => t.project == project).toList();
      
      // Tính tổng thu
      final totalIncome = projectTransactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);
          
      // Lấy danh sách chi tiêu để sync chi tiết
      final expenses = projectTransactions
          .where((t) => t.type == TransactionType.expense)
          .map((t) {
            final combinedNote = t.note != null && t.note!.isNotEmpty 
                ? '${t.paymentType} (${t.note})' 
                : t.paymentType;
            return {
              'name': t.description,
              'amount': t.amount,
              'date': t.date,
              'note': combinedNote,
            };
          })
          .toList();
      
      final success = await sheetsService.syncProjectDetails(
        projectName: project,
        totalIncome: totalIncome,
        expenses: expenses,
      );
      
      if (success) {
        debugPrint('✅ Đã đồng bộ project $project lên Google Sheets');
      } else {
        debugPrint('❌ Lỗi khi đồng bộ project $project');
      }
    } catch (e) {
      debugPrint('Error syncing to sheets: $e');
    }
  }
  
  /// Đồng bộ tất cả projects lên Google Sheets (manual sync)
  Future<void> syncAllProjectsToSheets() async {
    final projects = _cashTransactions.map((t) => t.project).toSet();
    for (final project in projects) {
      if (project != 'Mặc định') {
        await _syncProjectToSheets(project);
      }
    }
  }

  /// Tính tổng thu nhập thực tế tháng này (Lương chính + Phụ cấp + OT thực tế)
  double getTotalIncomeSoFar() {
    final now = DateTime.now();
    return getTotalIncomeForMonth(now.year, now.month);
  }

  /// Tính tổng thu nhập thực tế cho một tháng cụ thể
  double getTotalIncomeForMonth(int year, int month) {
    double totalOT = 0;
    for (var entry in _entries) {
      if (entry.date.month == month && entry.date.year == year) {
        totalOT += entry.totalPay;
      }
    }
    final baseIncome = (monthlySalary ?? 0);
    return baseIncome + totalOT;
  }

  /// Phân tích xu hướng làm việc theo thứ trong tuần
  Map<int, Map<String, dynamic>> getWorkTrends() {
    // 1: Thứ 2, ..., 7: Chủ nhật
    final trends = <int, Map<String, dynamic>>{};
    for (int i = 1; i <= 7; i++) {
      trends[i] = {'count': 0, 'totalHours': 0.0};
    }

    for (var entry in _entries) {
      final weekday = entry.date.weekday;
      trends[weekday]!['count'] = (trends[weekday]!['count'] as int) + 1;
      final totalHours = entry.hours15 + entry.hours18 + entry.hours20;
      trends[weekday]!['totalHours'] = (trends[weekday]!['totalHours'] as double) + totalHours;
    }

    return trends;
  }
}
