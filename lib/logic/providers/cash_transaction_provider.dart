import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../data/models/cash_transaction.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/google_sheets_service.dart';
import '../../data/services/backup_service.dart';
import '../../data/services/notification_service.dart';

class CashTransactionProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  final BackupService _backupService = BackupService();
  List<CashTransaction> _cashTransactions = [];
  bool _isLoading = false;
  String? _pendingSharedImagePath;

  List<CashTransaction> get cashTransactions => _cashTransactions;
  bool get isLoading => _isLoading;
  String? get pendingSharedImagePath => _pendingSharedImagePath;

  void setPendingSharedImagePath(String? path) {
    _pendingSharedImagePath = path;
    notifyListeners();
  }

  Future<void> fetchCashTransactions() async {
    _isLoading = true;
    notifyListeners();
    try {
      _cashTransactions = await _storageService.getAllCashTransactions();
    } catch (e) {
      debugPrint('Error fetching cash transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get all unique image paths from transactions
  List<String> getAllImagePaths() {
    return _cashTransactions
        .where((t) => t.imagePath != null)
        .map((t) => t.imagePath!)
        .toSet()
        .toList();
  }

  /// Get image paths mapped by project
  Map<String, List<String>> getProjectImagePaths() {
    final map = <String, List<String>>{};
    for (final t in _cashTransactions) {
      if (t.imagePath != null) {
        final project = t.project;
        if (!map.containsKey(project)) {
          map[project] = [];
        }
        if (!map[project]!.contains(t.imagePath!)) {
          map[project]!.add(t.imagePath!);
        }
      }
    }
    return map;
  }

  Future<void> addCashTransaction({
    required TransactionType type,
    required double amount,
    required String description,
    required DateTime date,
    String? imagePath,
    String? note,
    String project = 'Mặc định',
    String paymentType = 'Hoá đơn giấy',
    int taxRate = 0,
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
      taxRate: taxRate,
    );
    final id = await _storageService.insertCashTransaction(transaction);
    await fetchCashTransactions();
    
    // Lên lịch nhắc VAT ngay lập tức nếu là khoản chi có thuế
    if (type == TransactionType.expense && taxRate > 0) {
      final amountStr = '${amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (Match m) => '${m[1]}.',
      )}đ';
      
      NotificationService().scheduleVatReminder(
        transactionId: id,
        description: description,
        amount: amountStr,
      );
    }
    
    // Sync to Sheets (Background)
    _syncProjectToSheets(project);

    // Sync image to Google Drive if available and signed in (Background)
    if (imagePath != null) {
      _backupService.isSignedIn().then((isSignedIn) {
        if (isSignedIn) {
          _backupService.backupImages([imagePath], projectName: project);
        }
      });
    }
  }

  Future<void> deleteCashTransaction(int id) async {
    final transaction = _cashTransactions.firstWhere((t) => t.id == id);
    final project = transaction.project;
    final imagePath = transaction.imagePath;
    
    await _storageService.deleteCashTransaction(id);
    
    if (imagePath != null) {
      try {
        final file = File(imagePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint('Error deleting image file: $e');
      }
    }

    await fetchCashTransactions();
    _syncProjectToSheets(project);
  }

  Future<void> updateCashTransaction(CashTransaction transaction) async {
    final oldProject = _cashTransactions.firstWhere((t) => t.id == transaction.id).project;
    await _storageService.updateCashTransaction(transaction);
    await fetchCashTransactions();
    
    _syncProjectToSheets(oldProject);
    if (transaction.project != oldProject) {
      _syncProjectToSheets(transaction.project);
    }

    // Sync image to Google Drive if updated and available (Background)
    if (transaction.imagePath != null) {
      _backupService.isSignedIn().then((isSignedIn) {
        if (isSignedIn) {
          _backupService.backupImages([transaction.imagePath!], projectName: transaction.project);
        }
      });
    }
  }

  /// Cập nhật đường dẫn ảnh mới vào database (dùng sau khi khôi phục từ Drive)
  Future<void> updateTransactionImagePath(int id, String newPath) async {
    try {
      final index = _cashTransactions.indexWhere((t) => t.id == id);
      if (index != -1) {
        final updatedTransaction = _cashTransactions[index].copyWith(imagePath: newPath);
        await _storageService.updateCashTransaction(updatedTransaction);
        _cashTransactions[index] = updatedTransaction;
        notifyListeners();
        debugPrint('Updated transaction $id with new image path: $newPath');
      }
    } catch (e) {
      debugPrint('Error updating transaction image path: $e');
    }
  }

  /// Lấy giao dịch theo ID
  CashTransaction? getTransactionById(int id) {
    try {
      return _cashTransactions.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Đánh dấu đã lấy hóa đơn VAT cho giao dịch
  Future<void> markVatCollected(int transactionId, {bool collected = true}) async {
    try {
      final index = _cashTransactions.indexWhere((t) => t.id == transactionId);
      if (index != -1) {
        final updatedTransaction = _cashTransactions[index].copyWith(isVatCollected: collected);
        await _storageService.updateCashTransaction(updatedTransaction);
        _cashTransactions[index] = updatedTransaction;
        notifyListeners();
        debugPrint('Marked transaction $transactionId VAT collected: $collected');
      }
    } catch (e) {
      debugPrint('Error marking VAT collected: $e');
    }
  }

  /// Lấy danh sách giao dịch cần lấy VAT (chưa lấy + trong 30 ngày)
  List<CashTransaction> getPendingVatTransactions() {
    return _cashTransactions.where((t) => t.needsVatReminder).toList();
  }

  /// Lên lịch tất cả nhắc nhở VAT cho các giao dịch chưa lấy
  Future<void> scheduleAllVatReminders() async {
    try {
      // Import NotificationService
      final pendingTransactions = getPendingVatTransactions();
      debugPrint('Found ${pendingTransactions.length} transactions needing VAT reminder');
      
      // Notification sẽ được lên lịch từ splash_screen
    } catch (e) {
      debugPrint('Error scheduling VAT reminders: $e');
    }
  }

  /// Tự động quét và khôi phục ảnh bị thiếu từ Drive
  Future<void> autoRestoreMissingImages() async {
    try {
      final missingImagesByProject = <String, List<String>>{};
      int missingCount = 0;

      for (final t in _cashTransactions) {
        if (t.imagePath != null) {
          final file = File(t.imagePath!);
          if (!await file.exists()) {
            final fileName = path.basename(t.imagePath!);
            missingImagesByProject.putIfAbsent(t.project, () => []);
            if (!missingImagesByProject[t.project]!.contains(fileName)) {
              missingImagesByProject[t.project]!.add(fileName);
              missingCount++;
            }
          }
        }
      }

      if (missingCount == 0) {
        debugPrint('✅ No missing images found.');
        return;
      }

      debugPrint('🔍 Found $missingCount missing images. Starting auto-restore...');

      for (final entry in missingImagesByProject.entries) {
        final project = entry.key;
        final fileNames = entry.value;
        
        final restoredMap = await _backupService.downloadMultipleImages(fileNames, projectName: project);
        
        // Cập nhật lại đường dẫn trong DB cho các giao dịch tương ứng
        for (final fileName in restoredMap.keys) {
          final newPath = restoredMap[fileName]!;
          
          // Tìm tất cả giao dịch dùng ảnh này để cập nhật
          final transactionsToUpdate = _cashTransactions.where((t) => t.imagePath != null && path.basename(t.imagePath!) == fileName).toList();
          
          for (final t in transactionsToUpdate) {
            await updateTransactionImagePath(t.id!, newPath);
          }
        }
      }
      
      debugPrint('✅ Auto-restore completed.');
      notifyListeners();
    } catch (e) {
      debugPrint('Error in autoRestoreMissingImages: $e');
    }
  }

  Future<void> _syncProjectToSheets(String project) async {
    if (project == 'Mặc định') return;
    
    try {
      final sheetsService = GoogleSheetsService();
      final token = await sheetsService.getAccessToken();
      if (token == null || token.isEmpty) return;
      
      final projectTransactions = _cashTransactions.where((t) => t.project == project).toList();
      final totalIncome = projectTransactions
          .where((t) => t.type == TransactionType.income)
          .fold(0.0, (sum, t) => sum + t.amount);
          
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
      
      await sheetsService.syncProjectDetails(
        projectName: project,
        totalIncome: totalIncome,
        expenses: expenses,
      );
    } catch (e) {
      debugPrint('Error syncing to sheets: $e');
    }
  }

  Future<void> syncAllProjectsToSheets() async {
    final projects = _cashTransactions.map((t) => t.project).toSet();
    for (final project in projects) {
      if (project != 'Mặc định') {
        await _syncProjectToSheets(project);
      }
    }
  }

  Future<double> getImagesSize() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      double totalSize = 0;
      for (var file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.startsWith('receipt_') || fileName.startsWith('shared_receipt_')) {
            totalSize += await file.length();
          }
        }
      }
      return totalSize / (1024 * 1024);
    } catch (e) {
      return 0;
    }
  }

  Future<void> cleanupOrphanedImages() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final files = directory.listSync();
      final dbImages = _cashTransactions
          .where((t) => t.imagePath != null)
          .map((t) => t.imagePath!)
          .toSet();

      for (var file in files) {
        if (file is File) {
          final fileName = path.basename(file.path);
          if (fileName.startsWith('receipt_') || fileName.startsWith('shared_receipt_')) {
            if (!dbImages.contains(file.path)) {
              await file.delete();
            }
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error cleaning up images: $e');
    }
  }
}
