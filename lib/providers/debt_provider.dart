import 'package:flutter/material.dart';
import '../models/debt_entry.dart';
import '../services/storage_service.dart';

class DebtProvider with ChangeNotifier {
  final StorageService _storageService = StorageService();
  List<DebtEntry> _debtEntries = [];
  bool _isLoading = false;

  List<DebtEntry> get debtEntries => _debtEntries;
  bool get isLoading => _isLoading;

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

  Future<void> fetchDebtEntries() async {
    _isLoading = true;
    notifyListeners();
    try {
      _debtEntries = await _storageService.getAllDebtEntries();
    } catch (e) {
      debugPrint('Error fetching debt entries: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

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
    await fetchDebtEntries();
  }

  Future<void> deleteDebtEntry(int id) async {
    await _storageService.deleteDebtEntry(id);
    await fetchDebtEntries();
  }

  Future<void> toggleDebtPaid(DebtEntry entry) async {
    final isPaid = !entry.isPaid;
    final updatedEntry = entry.copyWith(
      isPaid: isPaid,
      paidAt: isPaid ? DateTime.now() : null,
    );
    await _storageService.updateDebtEntry(updatedEntry);
    await fetchDebtEntries();
  }

  Future<void> updateDebtEntry(DebtEntry entry) async {
    await _storageService.updateDebtEntry(entry);
    await fetchDebtEntries();
  }
}
