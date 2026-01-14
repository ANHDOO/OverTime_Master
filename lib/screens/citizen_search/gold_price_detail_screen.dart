import 'package:flutter/material.dart';
import '../../services/info_service.dart';
import '../../services/storage_service.dart';
import '../../models/gold_investment.dart';
import '../../widgets/smart_money_input.dart';
import '../../theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'dart:ui' as ui;

class GoldPriceDetailScreen extends StatefulWidget {
  const GoldPriceDetailScreen({super.key});

  @override
  State<GoldPriceDetailScreen> createState() => _GoldPriceDetailScreenState();
}

class _GoldPriceDetailScreenState extends State<GoldPriceDetailScreen> {
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

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final goldData = await _infoService.getTamNhungGoldPrices();
      final miHongGold = await _infoService.getMiHongGoldPrices();
      final investments = await _storageService.getAllGoldInvestments();
      final maoThiet = goldData['mao_thiet'] ?? [];
      
      const String nhanTronKey = 'MAIN_GOLD_NHAN_TRON_9999';
      final nhanTronHistory = await _storageService.getGoldPriceHistory(nhanTronKey);
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

      // Calculate Portfolio Analytics
      double totalInvested = 0;
      double totalCurrentValue = 0;
      double totalQuantity = 0;

      for (var inv in investments) {
        if (inv.goldType.contains('SJC')) {
          continue; // Skip SJC as requested
        }
        
        totalInvested += inv.buyPrice * inv.quantity;
        totalQuantity += inv.quantity;
        
        double currentPrice = 0;
        if (inv.goldType.contains('610')) {
          final g610 = miHongGold.firstWhere((p) => p['type']?.contains('610') ?? false, orElse: () => <String, String>{});
          if (g610.isNotEmpty) currentPrice = _parsePrice(g610['buy']);
        } else {
          final normal = maoThiet.firstWhere((p) => p['type'] == inv.goldType, orElse: () => <String, String>{});
          if (normal.isNotEmpty) currentPrice = _parsePrice(normal['buy']);
        }
        
        if (currentPrice == 0) {
          currentPrice = inv.buyPrice; // Fallback
        }
        totalCurrentValue += currentPrice * inv.quantity;
      }

      double totalProfit = totalCurrentValue - totalInvested;
      double totalProfitPercent = totalInvested > 0 ? (totalProfit / totalInvested) * 100 : 0;

      // Generate Portfolio Profit History (Simplified: use history of all types)
      final allHistories = {
        'MAIN_GOLD_NHAN_TRON_9999': await _storageService.getGoldPriceHistory('MAIN_GOLD_NHAN_TRON_9999'),
        'GOLD_610': await _storageService.getGoldPriceHistory('GOLD_610'),
      };

      List<Map<String, dynamic>> portfolioHistory = [];
      if (investments.any((inv) => !inv.goldType.contains('SJC'))) {
        // Use the longest history as base
        final baseHistory = allHistories['MAIN_GOLD_NHAN_TRON_9999'] ?? [];
        for (var i = 0; i < baseHistory.length; i++) {
          final date = baseHistory[i]['date'];
          double pointProfit = 0;
          for (var inv in investments) {
            if (inv.goldType.contains('SJC')) continue;
            
            String? typeKey;
            if (inv.goldType.contains('610')) {
              typeKey = 'GOLD_610';
            } else if (inv.goldType.contains('Nhẫn Trơn')) {
              typeKey = 'MAIN_GOLD_NHAN_TRON_9999';
            }
            
            if (typeKey != null) {
              final typeHistory = allHistories[typeKey] ?? [];
              if (i < typeHistory.length) {
                final histPrice = typeHistory[i]['buy_price'];
                pointProfit += (histPrice - inv.buyPrice) * inv.quantity;
              }
            }
          }
          portfolioHistory.add({'date': date, 'profit': pointProfit});
        }
      }

      final history = await _storageService.getGoldPriceHistory(_selectedHistoryKey);
      double percent = 0;
      if (history.length >= 2) {
        final latest = history.last;
        final latestDateStr = latest['date'].split(' ')[0];
        Map<String, dynamic>? prevDayRecord;
        for (var i = history.length - 2; i >= 0; i--) {
          if (history[i]['date'].split(' ')[0] != latestDateStr) {
            prevDayRecord = history[i];
            break;
          }
        }
        prevDayRecord ??= history[history.length - 2];
        double todaySell = latest['sell_price'];
        double yesterdaySell = prevDayRecord['sell_price'];
        if (yesterdaySell > 0) percent = ((todaySell - yesterdaySell) / yesterdaySell) * 100;
      }

      if (mounted) {
        setState(() { 
          _maoThietPrices = List<Map<String, String>>.from(maoThiet); 
          _miHongPrices = List<Map<String, String>>.from(miHongGold); 
          _sjcPrices = List<Map<String, String>>.from(goldData['sjc'] ?? []);
          _investments = investments; 
          _priceHistory = history; 
          _priceChangePercent = percent; 
          _totalInvested = totalInvested;
          _totalCurrentValue = totalCurrentValue;
          _totalProfit = totalProfit;
          _totalProfitPercent = totalProfitPercent;
          _totalQuantity = totalQuantity;
          _portfolioProfitHistory = portfolioHistory;
          _isLoading = false; 
          _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now()); 
        });
      }
    } catch (e) {
      debugPrint('Error loading gold data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _parsePrice(String? priceStr) {
    if (priceStr == null) {
      return 0;
    }
    double val = double.tryParse(priceStr.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    if (val > 0 && val < 1000000) {
      val *= 1000;
    }
    return val;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          title: const Text('Vàng Tám Nhung'),
          bottom: TabBar(
            tabs: const [Tab(text: 'Giá hiện tại', icon: Icon(Icons.show_chart_rounded)), Tab(text: 'Sổ đầu tư', icon: Icon(Icons.account_balance_wallet_rounded))],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
          actions: [IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _loadAllData)],
        ),
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: AppColors.accent))
            : TabBarView(children: [_buildCurrentPricesTab(isDark), _buildInvestmentTab(isDark)]),
        floatingActionButton: Container(
          decoration: BoxDecoration(gradient: AppGradients.heroOrange, shape: BoxShape.circle, boxShadow: AppShadows.heroOrangeLight),
          child: FloatingActionButton(onPressed: _showAddInvestmentDialog, backgroundColor: Colors.transparent, elevation: 0, child: const Icon(Icons.add_rounded, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCurrentPricesTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_lastUpdated != null) Padding(padding: const EdgeInsets.only(bottom: 12), child: Text('Cập nhật lúc: $_lastUpdated', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted), textAlign: TextAlign.center)),
        _buildHighlightCard(isDark),
        const SizedBox(height: 20),
        ..._maoThietPrices.where((p) => !(p['type']?.contains('Vàng Nhẫn Trơn') ?? false)).map((item) => _buildPriceCard(item, isDark)),
        const SizedBox(height: 20),
        _buildSectionTitle('Vàng SJC', isDark),
        const SizedBox(height: 8),
        ..._sjcPrices.map((item) => _buildPriceCard(item, isDark, isSjc: true)),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(children: [
      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm), child: Icon(Icons.monetization_on_rounded, color: AppColors.accent, size: 16)),
      const SizedBox(width: 10),
      Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.accent)),
    ]);
  }

  Widget _buildHighlightCard(bool isDark) {
    final selectedName = _goldTypeNames[_selectedHistoryKey] ?? '';
    Map<String, String> currentPriceData = {};
    if (_selectedHistoryKey == 'GOLD_610') {
      currentPriceData = _miHongPrices.firstWhere(
        (p) => p['type']?.contains('610') ?? false,
        orElse: () => <String, String>{},
      );
    } else {
      currentPriceData = _maoThietPrices.firstWhere(
        (p) => p['type']?.contains(selectedName.replaceAll('Vàng ', '')) ?? false,
        orElse: () => <String, String>{},
      );
    }

    double buyPrice = _parsePrice(currentPriceData['buy']);
    double sellPrice = _parsePrice(currentPriceData['sell']);
    if (sellPrice == 0 && _priceHistory.isNotEmpty) {
      buyPrice = _priceHistory.last['buy_price'];
      sellPrice = _priceHistory.last['sell_price'];
    }
    final isUp = _priceChangePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: AppGradients.heroOrange, borderRadius: AppRadius.borderXl, boxShadow: AppShadows.heroOrangeLight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              DropdownButton<String>(
                value: _selectedHistoryKey,
                dropdownColor: AppColors.accent,
                underline: const SizedBox(),
                icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white70),
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedHistoryKey = newValue);
                    _loadAllData();
                  }
                },
                items: _goldTypeNames.entries.map((e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
              ),
              Text('${NumberFormat('#,###').format(sellPrice)} đ', style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700)),
            ]),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: AppRadius.borderMd),
              child: Row(children: [
                Icon(isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, color: isUp ? AppColors.successLight : Colors.white, size: 16),
                const SizedBox(width: 4),
                Text('${_priceChangePercent.abs().toStringAsFixed(3)}%', style: TextStyle(color: isUp ? AppColors.successLight : Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
          ]),
          const SizedBox(height: 20),
          SizedBox(
            height: 120,
            child: _priceHistory.length < 2 ? Center(child: Text('Đang thu thập dữ liệu biểu đồ...', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)))
                : LineChart(LineChartData(
                    gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: Colors.white.withValues(alpha: 0.1), strokeWidth: 1)),
                    titlesData: FlTitlesData(show: true, rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: 1, getTitlesWidget: (value, meta) { if (value.toInt() >= 0 && value.toInt() < _priceHistory.length) { final dateStr = _priceHistory[value.toInt()]['date']; try { final date = DateFormat('yyyy-MM-dd HH:mm').parse(dateStr); return Text(DateFormat('dd/MM').format(date), style: const TextStyle(color: Colors.white60, fontSize: 9)); } catch (_) { return Text(dateStr.split(' ')[0].substring(5), style: const TextStyle(color: Colors.white60, fontSize: 9)); } } return const SizedBox(); }))),
                    borderData: FlBorderData(show: false),
                    minY: _priceHistory.map((e) => (e['buy_price'] as num).toDouble()).reduce(min) / 10000 * 0.98,
                    maxY: _priceHistory.map((e) => (e['sell_price'] as num).toDouble()).reduce(max) / 10000 * 1.02,
                    lineBarsData: [
                      LineChartBarData(spots: _priceHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['sell_price'] as num).toDouble() / 10000)).toList(), isCurved: false, color: Colors.white, barWidth: 3, isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => LabelDotPainter(circlePainter: FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 1, strokeColor: Colors.white), text: NumberFormat('#,###').format(spot.y * 10000), isAbove: true)), belowBarData: BarAreaData(show: true, color: Colors.white.withValues(alpha: 0.1))),
                      LineChartBarData(spots: _priceHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['buy_price'] as num).toDouble() / 10000)).toList(), isCurved: false, color: Colors.white70, barWidth: 1, dashArray: [5, 5], isStrokeCapRound: true, dotData: FlDotData(show: true, getDotPainter: (spot, percent, barData, index) => LabelDotPainter(circlePainter: FlDotCirclePainter(radius: 2, color: Colors.white70, strokeWidth: 0, strokeColor: Colors.transparent), text: NumberFormat('#,###').format(spot.y * 10000), isAbove: false))),
                    ],
                    lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(tooltipBgColor: AppColors.accent, getTooltipItems: (List<LineBarSpot> touchedSpots) { return touchedSpots.map((spot) { final isSell = spot.barIndex == 0; final record = _priceHistory[spot.x.toInt()]; final timeStr = record['date'].split(' ').length > 1 ? record['date'].split(' ')[1] : ''; return LineTooltipItem('${isSell ? 'Bán: ' : 'Mua: '}${NumberFormat('#,###').format(spot.y * 10000)}\n$timeStr', const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)); }).toList(); })),
                  )),
          ),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_buildLegendItem('Bán ra', Colors.white, isDashed: false), const SizedBox(width: 16), _buildLegendItem('Mua vào', Colors.white70, isDashed: true)]),
          const SizedBox(height: 16),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [_buildPriceInfo('MUA VÀO', buyPrice, Colors.white), _buildPriceInfo('BÁN RA', sellPrice, Colors.white.withValues(alpha: 0.8))]),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {required bool isDashed}) {
    return Row(children: [
      Container(width: 20, height: 3, decoration: BoxDecoration(color: isDashed ? null : color, borderRadius: BorderRadius.circular(2)), child: isDashed ? Row(children: List.generate(3, (i) => Expanded(child: Container(margin: const EdgeInsets.symmetric(horizontal: 1), color: color)))) : null),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10)),
    ]);
  }

  Widget _buildPriceInfo(String label, double price, Color color) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1)),
      const SizedBox(height: 2),
      Text('${NumberFormat('#,###').format(price)} đ', style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 15)),
    ]);
  }

  Widget _buildPriceCard(Map<String, String> item, bool isDark, {bool isSjc = false}) {
    double buyPrice = _parsePrice(item['buy']);
    double sellPrice = _parsePrice(item['sell']);
    if (isSjc) {
      buyPrice /= 10;
      sellPrice /= 10;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: AppRadius.borderMd, border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      child: Row(children: [
        Expanded(flex: 4, child: Text(item['type'] ?? '', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 12, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
        const SizedBox(width: 8),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.success.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: AppRadius.borderSm), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('MUA ', style: TextStyle(fontSize: 9, color: AppColors.success)), Text(NumberFormat('#,###').format(buyPrice), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success))])),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.danger.withValues(alpha: isDark ? 0.15 : 0.1), borderRadius: AppRadius.borderSm), child: Row(mainAxisSize: MainAxisSize.min, children: [Text('BÁN ', style: TextStyle(fontSize: 9, color: AppColors.danger)), Text(NumberFormat('#,###').format(sellPrice), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.danger))])),
      ]),
    );
  }

  Widget _buildInvestmentTab(bool isDark) {
    return Column(
      children: [
        if (_investments.isNotEmpty) ...[
          _buildPortfolioSummary(isDark),
          if (_portfolioProfitHistory.length >= 2) _buildPortfolioChart(isDark),
        ],
        Expanded(
          child: _investments.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: isDark ? 0.15 : 0.1), shape: BoxShape.circle), child: Icon(Icons.history_edu_rounded, size: 48, color: AppColors.accent.withValues(alpha: 0.5))),
                  const SizedBox(height: 16),
                  Text('Chưa có giao dịch nào', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text('Nhấn + để thêm giao dịch mua vàng', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: _investments.length,
                  itemBuilder: (context, index) {
                    final inv = _investments[index];
                    
                    double currentShopBuyPrice = 0;
                    
                    if (inv.goldType.contains('610')) {
                      final g610 = _miHongPrices.firstWhere((p) => p['type']?.contains('610') ?? false, orElse: () => <String, String>{});
                      if (g610.isNotEmpty) {
                        currentShopBuyPrice = _parsePrice(g610['buy']);
                      }
                    } else {
                      final current = _maoThietPrices.firstWhere((p) => p['type'] == inv.goldType, orElse: () => <String, String>{});
                      if (current.isNotEmpty) {
                        currentShopBuyPrice = _parsePrice(current['buy']);
                      }
                    }

                    final totalBuy = inv.buyPrice * inv.quantity;
                    final totalCurrent = currentShopBuyPrice * inv.quantity;
                    final profit = totalCurrent - totalBuy;
                    final isProfit = profit >= 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: isDark ? AppColors.darkCard : AppColors.lightCard, borderRadius: AppRadius.borderLg, border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Expanded(child: Text(inv.goldType, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), maxLines: 1, overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 8),
                          Text(inv.date, style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                        ]),
                        const SizedBox(height: 4),
                        Text('Số lượng: ${inv.quantity} chỉ', style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                        Divider(height: 24, color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('GIÁ MUA', style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, letterSpacing: 0.5)),
                            Text('${NumberFormat('#,###').format(inv.buyPrice)} đ', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                          ]),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text('LỜI / LỖ', style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, letterSpacing: 0.5)),
                            Text('${isProfit ? '+' : ''}${NumberFormat('#,###').format(profit)} đ', style: TextStyle(fontWeight: FontWeight.w700, color: isProfit ? AppColors.success : AppColors.danger, fontSize: 15)),
                          ]),
                        ]),
                        if (inv.note.isNotEmpty) ...[const SizedBox(height: 8), Text('Ghi chú: ${inv.note}', style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontStyle: FontStyle.italic))],
                        const SizedBox(height: 12),
                        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                          TextButton.icon(onPressed: () => _showAddInvestmentDialog(investment: inv), icon: Icon(Icons.edit_rounded, size: 16, color: AppColors.primary), label: Text('Sửa', style: TextStyle(color: AppColors.primary, fontSize: 12))),
                          const SizedBox(width: 8),
                          TextButton.icon(onPressed: () => _deleteInvestment(inv.id!), icon: Icon(Icons.delete_rounded, size: 16, color: AppColors.danger), label: Text('Xóa', style: TextStyle(color: AppColors.danger, fontSize: 12))),
                        ]),
                      ]),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPortfolioSummary(bool isDark) {
    final isProfit = _totalProfit >= 0;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroLight,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('TỔNG VỐN ĐẦU TƯ', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: AppRadius.borderFull),
                child: Text('${_totalQuantity.toStringAsFixed(2)} chỉ', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('${NumberFormat('#,###').format(_totalInvested)} đ', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('GIÁ TRỊ HIỆN TẠI', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Text('${NumberFormat('#,###').format(_totalCurrentValue)} đ', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
              Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('TỔNG LỜI / LỖ', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 0.5)),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Icon(isProfit ? Icons.trending_up_rounded : Icons.trending_down_rounded, color: isProfit ? const Color(0xFF4ADE80) : const Color(0xFFF87171), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${isProfit ? '+' : ''}${_totalProfitPercent.toStringAsFixed(2)}%',
                          style: TextStyle(color: isProfit ? const Color(0xFF4ADE80) : const Color(0xFFF87171), fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPortfolioChart(bool isDark) {
    if (_portfolioProfitHistory.isEmpty) return const SizedBox();
    
    final profits = _portfolioProfitHistory.map((e) => (e['profit'] as num).toDouble()).toList();
    final minProfit = profits.reduce(min);
    final maxProfit = profits.reduce(max);
    final range = maxProfit - minProfit;
    final padding = range == 0 ? 1000000.0 : range * 0.2;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      height: 180,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('XU HƯỚNG LỢI NHUẬN', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05), strokeWidth: 1)),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minY: minProfit - padding,
                maxY: maxProfit + padding,
                lineBarsData: [
                  LineChartBarData(
                    spots: _portfolioProfitHistory.asMap().entries.map((e) => FlSpot(e.key.toDouble(), (e.value['profit'] as num).toDouble())).toList(),
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [AppColors.primary.withValues(alpha: 0.2), AppColors.primary.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: AppColors.primary,
                    getTooltipItems: (List<LineBarSpot> touchedSpots) {
                      return touchedSpots.map((spot) {
                        final record = _portfolioProfitHistory[spot.x.toInt()];
                        final dateStr = record['date'].split(' ')[0];
                        return LineTooltipItem(
                          '${NumberFormat('#,###').format(spot.y)} đ\n$dateStr',
                          const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddInvestmentDialog({GoldInvestment? investment}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String? selectedType = investment?.goldType ?? (_maoThietPrices.isNotEmpty ? _maoThietPrices[0]['type'] : null);
    final quantityController = TextEditingController(text: investment?.quantity.toString() ?? '');
    final priceController = TextEditingController(text: investment != null ? NumberFormat('#,###').format(investment.buyPrice) : '');
    final noteController = TextEditingController(text: investment?.note ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(24),
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.accent.withValues(alpha: isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm), child: Icon(investment == null ? Icons.add_rounded : Icons.edit_rounded, color: AppColors.accent, size: 20)),
                  const SizedBox(width: 12),
                  Text(investment == null ? 'Thêm giao dịch mua' : 'Sửa giao dịch mua', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                ]),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant,
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: selectedType,
                      isExpanded: true,
                      dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                      items: _maoThietPrices.map((p) => DropdownMenuItem<String>(
                        value: p['type'],
                        child: Text(
                          p['type'] ?? '',
                          style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (val) {
                        setDialogState(() => selectedType = val);
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(controller: quantityController, keyboardType: TextInputType.number, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), decoration: InputDecoration(labelText: 'Số lượng (chỉ)', labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted), filled: true, fillColor: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant, border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none))),
                const SizedBox(height: 12),
                SmartMoneyInput(controller: priceController, label: 'Giá mua (đ/chỉ)'),
                const SizedBox(height: 12),
                TextField(controller: noteController, style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary), decoration: InputDecoration(labelText: 'Ghi chú', labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted), filled: true, fillColor: isDark ? AppColors.darkSurfaceVariant.withValues(alpha: 0.5) : AppColors.lightSurfaceVariant, border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none))),
                const SizedBox(height: 24),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  TextButton(onPressed: () => Navigator.pop(context), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
                  const SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(gradient: AppGradients.heroOrange, borderRadius: AppRadius.borderMd),
                    child: ElevatedButton(
                      onPressed: () async {
                        if (selectedType != null && quantityController.text.isNotEmpty && priceController.text.isNotEmpty) {
                          double inputPrice = double.tryParse(priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                          if (inputPrice < 1000000) inputPrice *= 1000;
                          final inv = GoldInvestment(id: investment?.id, goldType: selectedType!, quantity: double.tryParse(quantityController.text) ?? 0, buyPrice: inputPrice, date: investment?.date ?? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), note: noteController.text);
                          if (investment == null) {
                            await _storageService.insertGoldInvestment(inv);
                          } else {
                            await _storageService.updateGoldInvestment(inv);
                          }
                          if (context.mounted) {
                            Navigator.pop(context);
                            _loadAllData();
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.transparent, shadowColor: Colors.transparent),
                      child: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteInvestment(int id) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Text('Xác nhận xóa', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
        content: Text('Bạn có chắc chắn muốn xóa giao dịch này không?', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted))),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Xóa', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirm == true) {
      await _storageService.deleteGoldInvestment(id);
      _loadAllData();
    }
  }
}

class LabelDotPainter extends FlDotPainter {
  final FlDotCirclePainter circlePainter;
  final String text;
  final bool isAbove;

  LabelDotPainter({required this.circlePainter, required this.text, required this.isAbove});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset offsetInCanvas) {
    circlePainter.draw(canvas, spot, offsetInCanvas);
    final textPainter = TextPainter(text: TextSpan(text: text, style: TextStyle(color: circlePainter.color.withValues(alpha: 0.9), fontSize: 8, fontWeight: FontWeight.bold)), textDirection: ui.TextDirection.ltr)..layout();
    final yOffset = isAbove ? -15.0 : 8.0;
    textPainter.paint(canvas, offsetInCanvas + Offset(-textPainter.width / 2, yOffset));
  }

  @override
  Size getSize(FlSpot spot) => circlePainter.getSize(spot);
  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) => b;
  @override
  Color get mainColor => circlePainter.color;
  @override
  List<Object?> get props => [circlePainter, text, isAbove];
}
