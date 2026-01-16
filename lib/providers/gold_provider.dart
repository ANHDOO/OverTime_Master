import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../models/gold_investment.dart';
import '../services/info_service.dart';
import '../services/storage_service.dart';

class GoldProvider with ChangeNotifier {
  final InfoService _infoService = InfoService();
  final StorageService _storageService = StorageService();

  List<Map<String, String>> _maoThietPrices = [];
  List<Map<String, String>> _miHongPrices = [];
  List<Map<String, String>> _sjcPrices = [];
  List<GoldInvestment> _investments = [];
  List<Map<String, dynamic>> _priceHistory = [];
  bool _isLoading = true;
  String? _lastUpdated;
  double _priceChangePercent = 0;
  int _recentTrend = 0; // 1: up, -1: down, 0: no change
  String _selectedHistoryKey = 'MAIN_GOLD_NHAN_TRON_9999';

  // Portfolio Analytics
  double _totalInvested = 0;
  double _totalCurrentValue = 0;
  double _totalProfit = 0;
  double _totalProfitPercent = 0;
  double _totalQuantity = 0;
  List<Map<String, dynamic>> _portfolioProfitHistory = [];

  final Map<String, String> _goldTypeNames = {
    'MAIN_GOLD_NHAN_TRON_9999': 'Vàng Nhẫn Trơn 9999',
    'GOLD_610': 'Vàng 610',
    'MAIN_GOLD_SJC': 'Vàng SJC',
  };

  // Getters
  List<Map<String, String>> get maoThietPrices => _maoThietPrices;
  List<Map<String, String>> get miHongPrices => _miHongPrices;
  List<Map<String, String>> get sjcPrices => _sjcPrices;
  List<GoldInvestment> get investments => _investments;
  List<Map<String, dynamic>> get priceHistory => _priceHistory;
  bool get isLoading => _isLoading;
  String? get lastUpdated => _lastUpdated;
  double get priceChangePercent => _priceChangePercent;
  int get recentTrend => _recentTrend;
  String get selectedHistoryKey => _selectedHistoryKey;
  double get totalInvested => _totalInvested;
  double get totalCurrentValue => _totalCurrentValue;
  double get totalProfit => _totalProfit;
  double get totalProfitPercent => _totalProfitPercent;
  double get totalQuantity => _totalQuantity;
  List<Map<String, dynamic>> get portfolioProfitHistory => _portfolioProfitHistory;
  Map<String, String> get goldTypeNames => _goldTypeNames;

  set selectedHistoryKey(String value) {
    _selectedHistoryKey = value;
    fetchGoldData();
    notifyListeners();
  }

  Future<void> fetchGoldData() async {
    _isLoading = true;
    notifyListeners();

    try {
      final goldData = await _infoService.getTamNhungGoldPrices();
      final miHongGold = await _infoService.getMiHongGoldPrices();
      final investments = await _storageService.getAllGoldInvestments();
      final maoThiet = goldData['mao_thiet'] ?? [];

      const String nhanTronKey = 'MAIN_GOLD_NHAN_TRON_9999';
      final nhanTronHistory = await _storageService.getGoldPriceHistory(nhanTronKey);
      
      // Data correction logic
      bool needsReset = nhanTronHistory.any((e) => (e['date'].contains('2026-01-12') && e['sell_price'] == 15500000.0) || (e['date'].contains('2026-01-13 08:00')));
      if (needsReset || nhanTronHistory.isEmpty) {
        await _storageService.clearGoldPriceHistory(nhanTronKey);
        await _storageService.insertGoldPriceHistory({'date': '2026-01-11 08:00', 'buy_price': 14700000.0, 'sell_price': 14900000.0, 'gold_type': nhanTronKey});
        await _storageService.insertGoldPriceHistory({'date': '2026-01-12 08:00', 'buy_price': 15100000.0, 'sell_price': 15300000.0, 'gold_type': nhanTronKey});
        await _storageService.insertGoldPriceHistory({'date': '2026-01-13 08:00', 'buy_price': 15150000.0, 'sell_price': 15400000.0, 'gold_type': nhanTronKey});
      }

      const String gold610Key = 'GOLD_610';
      final gold610History = await _storageService.getGoldPriceHistory(gold610Key);
      bool needsReset610 = gold610History.any((e) => e['date'].contains('2026-01-13 08:00'));
      if (needsReset610 || gold610History.isEmpty) {
        await _storageService.clearGoldPriceHistory(gold610Key);
        await _storageService.insertGoldPriceHistory({'date': '2026-01-11 08:00', 'buy_price': 9045000.0, 'sell_price': 9345000.0, 'gold_type': gold610Key});
        await _storageService.insertGoldPriceHistory({'date': '2026-01-12 08:00', 'buy_price': 9045000.0, 'sell_price': 9345000.0, 'gold_type': gold610Key});
        await _storageService.insertGoldPriceHistory({'date': '2026-01-13 08:00', 'buy_price': 9045000.0, 'sell_price': 9345000.0, 'gold_type': gold610Key});
      }

      final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      final nhanTronData = maoThiet.firstWhere((p) => p['type']?.contains('Vàng Nhẫn Trơn') ?? false, orElse: () => <String, String>{});
      if (nhanTronData.isNotEmpty) {
        final currentBuy = _parsePrice(nhanTronData['buy']);
        final currentSell = _parsePrice(nhanTronData['sell']);
        final updated = await _storageService.getGoldPriceHistory(nhanTronKey);
        if (updated.isEmpty || updated.last['buy_price'] != currentBuy || updated.last['sell_price'] != currentSell) {
          await _storageService.insertGoldPriceHistory({'date': now, 'buy_price': currentBuy, 'sell_price': currentSell, 'gold_type': nhanTronKey});
        }
      }

      final gold610Data = miHongGold.firstWhere((p) => p['type']?.contains('610') ?? false, orElse: () => <String, String>{});
      if (gold610Data.isNotEmpty) {
        final currentBuy = _parsePrice(gold610Data['buy']);
        final currentSell = _parsePrice(gold610Data['sell']);
        if (currentBuy > 0 && currentSell > 0) {
          final updated = await _storageService.getGoldPriceHistory(gold610Key);
          if (updated.isEmpty || updated.last['buy_price'] != currentBuy || updated.last['sell_price'] != currentSell) {
            await _storageService.insertGoldPriceHistory({'date': now, 'buy_price': currentBuy, 'sell_price': currentSell, 'gold_type': gold610Key});
          }
        }
      }

      // Global Data Cleanup
      for (var typeKey in _goldTypeNames.keys) {
        final typeHistory = await _storageService.getGoldPriceHistory(typeKey);
        for (var entry in typeHistory) {
          double buy = (entry['buy_price'] as num).toDouble();
          double sell = (entry['sell_price'] as num).toDouble();
          
          if ((buy > 0 && buy < 1000000) || (sell > 0 && sell < 1000000)) {
            final cleanedEntry = Map<String, dynamic>.from(entry);
            if (buy > 0 && buy < 1000000) cleanedEntry['buy_price'] = buy * 1000;
            if (sell > 0 && sell < 1000000) cleanedEntry['sell_price'] = sell * 1000;
            await _storageService.insertGoldPriceHistory(cleanedEntry);
          }
        }
      }

      // Portfolio Analytics
      _totalInvested = 0;
      _totalCurrentValue = 0;
      _totalQuantity = 0;

      for (var inv in investments) {
        if (inv.goldType.contains('SJC')) continue;
        
        _totalInvested += inv.buyPrice * inv.quantity;
        _totalQuantity += inv.quantity;
        
        double currentPrice = 0;
        if (inv.goldType.contains('610')) {
          final g610 = miHongGold.firstWhere((p) => p['type']?.contains('610') ?? false, orElse: () => <String, String>{});
          if (g610.isNotEmpty) currentPrice = _parsePrice(g610['buy']);
        } else {
          final normal = maoThiet.firstWhere((p) => p['type'] == inv.goldType, orElse: () => <String, String>{});
          if (normal.isNotEmpty) currentPrice = _parsePrice(normal['buy']);
        }
        
        if (currentPrice == 0) currentPrice = inv.buyPrice;
        _totalCurrentValue += currentPrice * inv.quantity;
      }

      _totalProfit = _totalCurrentValue - _totalInvested;
      _totalProfitPercent = _totalInvested > 0 ? (_totalProfit / _totalInvested) * 100 : 0;

      // Portfolio History
      final allHistories = {
        'MAIN_GOLD_NHAN_TRON_9999': await _storageService.getGoldPriceHistory('MAIN_GOLD_NHAN_TRON_9999'),
        'GOLD_610': await _storageService.getGoldPriceHistory('GOLD_610'),
      };

      _portfolioProfitHistory = [];
      if (investments.any((inv) => !inv.goldType.contains('SJC'))) {
        final baseHistory = allHistories['MAIN_GOLD_NHAN_TRON_9999'] ?? [];
        for (var i = 0; i < baseHistory.length; i++) {
          final date = baseHistory[i]['date'];
          double pointProfit = 0;
          for (var inv in investments) {
            if (inv.goldType.contains('SJC')) continue;
            
            String? typeKey;
            if (inv.goldType.contains('610')) typeKey = 'GOLD_610';
            else if (inv.goldType.contains('Nhẫn Trơn')) typeKey = 'MAIN_GOLD_NHAN_TRON_9999';
            
            if (typeKey != null) {
              final typeHistory = allHistories[typeKey] ?? [];
              if (i < typeHistory.length) {
                final histPrice = typeHistory[i]['buy_price'];
                pointProfit += (histPrice - inv.buyPrice) * inv.quantity;
              }
            }
          }
          _portfolioProfitHistory.add({'date': date, 'profit': pointProfit});
        }
      }

      _priceHistory = await _storageService.getGoldPriceHistory(_selectedHistoryKey);
      _calculateTrendAndPercent();

      _maoThietPrices = List<Map<String, String>>.from(maoThiet);
      _miHongPrices = List<Map<String, String>>.from(miHongGold);
      _sjcPrices = List<Map<String, String>>.from(goldData['sjc'] ?? []);
      _investments = investments;
      _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now());
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching gold data: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  void _calculateTrendAndPercent() {
    if (_priceHistory.length >= 2) {
      final latest = _priceHistory.last;
      final previous = _priceHistory[_priceHistory.length - 2];
      
      if (latest['sell_price'] > previous['sell_price']) _recentTrend = 1;
      else if (latest['sell_price'] < previous['sell_price']) _recentTrend = -1;
      else _recentTrend = 0;
      
      final latestDateStr = latest['date'].split(' ')[0];
      Map<String, dynamic>? prevDayRecord;
      for (var i = _priceHistory.length - 2; i >= 0; i--) {
        if (_priceHistory[i]['date'].split(' ')[0] != latestDateStr) {
          prevDayRecord = _priceHistory[i];
          break;
        }
      }
      prevDayRecord ??= _priceHistory.first;
      
      double todaySell = latest['sell_price'];
      double baselineSell = prevDayRecord['sell_price'];
      if (baselineSell > 0) _priceChangePercent = ((todaySell - baselineSell) / baselineSell) * 100;
      else _priceChangePercent = 0;
    }
  }

  double _parsePrice(String? priceStr) {
    if (priceStr == null) return 0;
    final digitsOnly = priceStr.replaceAll(RegExp(r'[^0-9]'), '');
    double val = double.tryParse(digitsOnly) ?? 0;
    if (val > 0 && val < 1000000) val *= 1000;
    return val;
  }

  Future<void> addInvestment(GoldInvestment investment) async {
    await _storageService.insertGoldInvestment(investment);
    await fetchGoldData();
  }

  Future<void> updateInvestment(GoldInvestment investment) async {
    await _storageService.updateGoldInvestment(investment);
    await fetchGoldData();
  }

  Future<void> deleteInvestment(int id) async {
    await _storageService.deleteGoldInvestment(id);
    await fetchGoldData();
  }
}
