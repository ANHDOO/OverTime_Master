import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../../data/models/cash_transaction.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/google_sheets_service.dart';
import '../../data/services/backup_service.dart';

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
    await _storageService.insertCashTransaction(transaction);
    await fetchCashTransactions();
    
    // Sync to Sheets
    await _syncProjectToSheets(project);

    // Sync image to Google Drive if available and signed in
    if (imagePath != null) {
      final isSignedIn = await _backupService.isSignedIn();
      if (isSignedIn) {
        await _backupService.backupImages([imagePath], projectName: project);
      }
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
    await _syncProjectToSheets(project);
  }

  Future<void> updateCashTransaction(CashTransaction transaction) async {
    final oldProject = _cashTransactions.firstWhere((t) => t.id == transaction.id).project;
    await _storageService.updateCashTransaction(transaction);
    await fetchCashTransactions();
    
    await _syncProjectToSheets(oldProject);
    if (transaction.project != oldProject) {
      await _syncProjectToSheets(transaction.project);
    }

    // Sync image to Google Drive if updated and available
    if (transaction.imagePath != null) {
      final isSignedIn = await _backupService.isSignedIn();
      if (isSignedIn) {
        await _backupService.backupImages([transaction.imagePath!], projectName: transaction.project);
      }
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
