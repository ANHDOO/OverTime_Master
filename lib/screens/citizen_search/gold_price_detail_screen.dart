import 'package:flutter/material.dart';
import '../../services/info_service.dart';
import '../../services/storage_service.dart';
import '../../models/gold_investment.dart';
import '../../widgets/smart_money_input.dart';
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
  List<Map<String, String>> _sjcPrices = [];
  List<Map<String, String>> _miHongPrices = [];
  List<GoldInvestment> _investments = [];
  List<Map<String, dynamic>> _priceHistory = [];
  bool _isLoading = true;
  String? _lastUpdated;
  double _priceChangePercent = 0;
  String _selectedHistoryKey = 'MAIN_GOLD_NHAN_TRON_9999';
  
  final Map<String, String> _goldTypeNames = {
    'MAIN_GOLD_NHAN_TRON_9999': 'Vàng Nhẫn Trơn 9999',
    'GOLD_610': 'Vàng 610',
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
      
      // 1. Clean and Seed historical data (only 2 days: Jan 11 & 12)
      // SEED NHAN TRON 9999
      const String nhanTronKey = 'MAIN_GOLD_NHAN_TRON_9999';
      final nhanTronHistory = await _storageService.getGoldPriceHistory(nhanTronKey);
      // Force reset if has old Jan 13 seed data or incorrect data
      bool needsReset = nhanTronHistory.any((e) => 
        (e['date'].contains('2026-01-12') && e['sell_price'] == 15500000.0) ||
        (e['date'].contains('2026-01-13 08:00'))
      );
      if (needsReset || nhanTronHistory.isEmpty) {
        await _storageService.clearGoldPriceHistory(nhanTronKey);
        await _storageService.insertGoldPriceHistory({'date': '2026-01-11 08:00', 'buy_price': 14700000.0, 'sell_price': 14900000.0, 'gold_type': nhanTronKey});
        await _storageService.insertGoldPriceHistory({'date': '2026-01-12 08:00', 'buy_price': 15100000.0, 'sell_price': 15300000.0, 'gold_type': nhanTronKey});
      }

      // SEED GOLD 610
      const String gold610Key = 'GOLD_610';
      final gold610History = await _storageService.getGoldPriceHistory(gold610Key);
      // Force reset if has old Jan 13 seed data
      bool needsReset610 = gold610History.any((e) => e['date'].contains('2026-01-13 08:00'));
      if (needsReset610 || gold610History.isEmpty) {
        await _storageService.clearGoldPriceHistory(gold610Key);
        await _storageService.insertGoldPriceHistory({'date': '2026-01-11 08:00', 'buy_price': 9045000.0, 'sell_price': 9345000.0, 'gold_type': gold610Key});
        await _storageService.insertGoldPriceHistory({'date': '2026-01-12 08:00', 'buy_price': 9045000.0, 'sell_price': 9345000.0, 'gold_type': gold610Key});
      }

      // 2. Save today's scraped prices for tracked types
      final now = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      
      // Update Nhan Tron 9999 (from Mao Thiet)
      final nhanTronData = maoThiet.firstWhere((p) => p['type']?.contains('Vàng Nhẫn Trơn') ?? false, orElse: () => {});
      if (nhanTronData.isNotEmpty) {
        final currentBuy = _parsePrice(nhanTronData['buy']);
        final currentSell = _parsePrice(nhanTronData['sell']);
        final updated = await _storageService.getGoldPriceHistory(nhanTronKey);
        // Only add new point when price changes
        if (updated.isEmpty || updated.last['buy_price'] != currentBuy || updated.last['sell_price'] != currentSell) {
          await _storageService.insertGoldPriceHistory({'date': now, 'buy_price': currentBuy, 'sell_price': currentSell, 'gold_type': nhanTronKey});
        }
      }

      // Update Gold 610 (from Mi Hong)
      final gold610Data = miHongGold.firstWhere((p) => p['type']?.contains('610') ?? false, orElse: () => {});
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

      // 3. Load updated history for SELECTED type
      final history = await _storageService.getGoldPriceHistory(_selectedHistoryKey);
      
      // 4. Calculate price change percent based on SELLING price
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
        if (yesterdaySell > 0) {
          percent = ((todaySell - yesterdaySell) / yesterdaySell) * 100;
        }
      }

      if (mounted) {
        setState(() {
          _maoThietPrices = maoThiet;
          _sjcPrices = goldData['sjc'] ?? [];
          _miHongPrices = miHongGold; // Store Mi Hong prices for UI
          _investments = investments;
          _priceHistory = history;
          _priceChangePercent = percent;
          _isLoading = false;
          _lastUpdated = DateFormat('HH:mm dd/MM/yyyy').format(DateTime.now());
        });
      }
    } catch (e) {
      debugPrint('Error loading gold data: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  double _parsePrice(String? priceStr) {
    if (priceStr == null) return 0;
    double val = double.tryParse(priceStr.replaceAll('.', '').replaceAll(',', '')) ?? 0;
    // If the value is small (e.g. 8000), it's likely in thousands, so multiply by 1000
    if (val > 0 && val < 1000000) {
      val *= 1000;
    }
    return val;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: const Text('Vàng Tám Nhung'),
          backgroundColor: Colors.red[900],
          foregroundColor: Colors.white,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Giá hiện tại', icon: Icon(Icons.show_chart)),
              Tab(text: 'Sổ đầu tư', icon: Icon(Icons.account_balance_wallet)),
            ],
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadAllData,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildCurrentPricesTab(),
                  _buildInvestmentTab(),
                ],
              ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showAddInvestmentDialog,
          backgroundColor: Colors.red[900],
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildCurrentPricesTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_lastUpdated != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Cập nhật lúc: $_lastUpdated',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ),
        
        // Highlight Card for Nhan Tron 9999
        _buildHighlightCard(),
        
        const SizedBox(height: 16),
        
        // Mao Thiet Table
        _buildSectionTitle('Vàng Mão Thiệt'),
        ..._maoThietPrices.where((p) => !(p['type']?.contains('Vàng Nhẫn Trơn') ?? false)).map((item) => _buildPriceCard(item)),
        
        const SizedBox(height: 24),
        
        // SJC Table
        if (_sjcPrices.isNotEmpty) ...[
          _buildSectionTitle('Vàng SJC (giá/chỉ)'),
          ..._sjcPrices.map((item) => _buildPriceCard(item, isSjc: true)),
        ],
        
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.red[900],
        ),
      ),
    );
  }

  Widget _buildHighlightCard() {
    final selectedName = _goldTypeNames[_selectedHistoryKey] ?? '';
    
    Map<String, String> currentPriceData = {};
    if (_selectedHistoryKey == 'GOLD_610') {
      currentPriceData = _miHongPrices.firstWhere(
        (p) => p['type']?.contains('610') ?? false,
        orElse: () => {},
      );
    } else {
      currentPriceData = _maoThietPrices.firstWhere(
        (p) => p['type']?.contains(selectedName.replaceAll('Vàng ', '')) ?? false,
        orElse: () => {},
      );
    }

    double buyPrice = _parsePrice(currentPriceData['buy']);
    double sellPrice = _parsePrice(currentPriceData['sell']);
    
    // Fallback to history if scrape fails for some reason
    if (sellPrice == 0 && _priceHistory.isNotEmpty) {
      buyPrice = _priceHistory.last['buy_price'];
      sellPrice = _priceHistory.last['sell_price'];
    }

    final isUp = _priceChangePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red[900]!, Colors.red[700]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButton<String>(
                    value: _selectedHistoryKey,
                    dropdownColor: Colors.red[900],
                    underline: const SizedBox(),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() => _selectedHistoryKey = newValue);
                        _loadAllData();
                      }
                    },
                    items: _goldTypeNames.entries.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.key,
                        child: Text(e.value),
                      );
                    }).toList(),
                  ),
                  Text(
                    '${NumberFormat('#,###').format(sellPrice)} đ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isUp ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isUp ? Colors.greenAccent : Colors.orangeAccent,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_priceChangePercent.abs().toStringAsFixed(3)}%',
                      style: TextStyle(
                        color: isUp ? Colors.greenAccent : Colors.orangeAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Chart
          SizedBox(
            height: 120,
            child: _priceHistory.length < 2
                ? const Center(
                    child: Text(
                      'Đang thu thập dữ liệu biểu đồ...',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: Colors.white.withValues(alpha: 0.1),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 22,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() >= 0 && value.toInt() < _priceHistory.length) {
                                final dateStr = _priceHistory[value.toInt()]['date'];
                                try {
                                  final date = DateFormat('yyyy-MM-dd HH:mm').parse(dateStr);
                                  return Text(
                                    DateFormat('dd/MM').format(date),
                                    style: const TextStyle(color: Colors.white60, fontSize: 9),
                                  );
                                } catch (_) {
                                  return Text(
                                    dateStr.split(' ')[0].substring(5),
                                    style: const TextStyle(color: Colors.white60, fontSize: 9),
                                  );
                                }
                              }
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minY: _priceHistory.map((e) => (e['buy_price'] as num).toDouble()).reduce(min) / 10000 * 0.98,
                      maxY: _priceHistory.map((e) => (e['sell_price'] as num).toDouble()).reduce(max) / 10000 * 1.02,
                      lineBarsData: [
                        // Sell Price Line (Thick, White)
                        LineChartBarData(
                          spots: _priceHistory.asMap().entries.map((e) {
                            double val = (e.value['sell_price'] as num).toDouble();
                            return FlSpot(e.key.toDouble(), val / 10000);
                          }).toList(),
                          isCurved: false,
                          color: Colors.white,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return LabelDotPainter(
                                circlePainter: FlDotCirclePainter(
                                  radius: 3,
                                  color: Colors.white,
                                  strokeWidth: 1,
                                  strokeColor: Colors.white,
                                ),
                                text: NumberFormat('#,###').format(spot.y * 10000),
                                isAbove: true,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: Colors.white.withValues(alpha: 0.1),
                          ),
                        ),
                        // Buy Price Line (Thin, White70)
                        LineChartBarData(
                          spots: _priceHistory.asMap().entries.map((e) {
                            double val = (e.value['buy_price'] as num).toDouble();
                            return FlSpot(e.key.toDouble(), val / 10000);
                          }).toList(),
                          isCurved: false,
                          color: Colors.white70,
                          barWidth: 1,
                          dashArray: [5, 5],
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              return LabelDotPainter(
                                circlePainter: FlDotCirclePainter(
                                  radius: 2,
                                  color: Colors.white70,
                                  strokeWidth: 0,
                                  strokeColor: Colors.transparent,
                                ),
                                text: NumberFormat('#,###').format(spot.y * 10000),
                                isAbove: false,
                              );
                            },
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.red[900]!,
                          getTooltipItems: (List<LineBarSpot> touchedSpots) {
                            return touchedSpots.map((spot) {
                              final isSell = spot.barIndex == 0;
                              final record = _priceHistory[spot.x.toInt()];
                              final timeStr = record['date'].split(' ').length > 1 
                                  ? record['date'].split(' ')[1] 
                                  : '';
                              
                              return LineTooltipItem(
                                '${isSell ? 'Bán: ' : 'Mua: '}${NumberFormat('#,###').format(spot.y * 10000)}\n$timeStr',
                                const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                              );
                            }).toList();
                          },
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Bán ra', Colors.white, isDashed: false),
              const SizedBox(width: 16),
              _buildLegendItem('Mua vào', Colors.white70, isDashed: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPriceInfo('MUA VÀO', buyPrice, Colors.white),
              _buildPriceInfo('BÁN RA', sellPrice, Colors.white.withValues(alpha: 0.8)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, {required bool isDashed}) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: isDashed ? null : color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: isDashed 
            ? Row(
                children: List.generate(3, (i) => Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    color: color,
                  ),
                )),
              )
            : null,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildPriceInfo(String label, double price, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 10, letterSpacing: 1),
        ),
        const SizedBox(height: 2),
        Text(
          '${NumberFormat('#,###').format(price)} đ',
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ],
    );
  }

  Widget _buildPriceCard(Map<String, String> item, {bool isSjc = false}) {
    double buyPrice = _parsePrice(item['buy']);
    double sellPrice = _parsePrice(item['sell']);
    
    // Convert SJC from "lượng" to "chỉ" if needed
    if (isSjc) {
      buyPrice /= 10;
      sellPrice /= 10;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          // Name on left
          Expanded(
            flex: 4,
            child: Text(
              item['type'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          // Compact MUA/BÁN on right
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('MUA ', style: TextStyle(fontSize: 9, color: Colors.green[700])),
                Text(
                  NumberFormat('#,###').format(buyPrice),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[700]),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('BÁN ', style: TextStyle(fontSize: 9, color: Colors.red[700])),
                Text(
                  NumberFormat('#,###').format(sellPrice),
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvestmentTab() {
    if (_investments.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_edu, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có giao dịch nào', style: TextStyle(color: Colors.grey)),
            Text('Nhấn + để thêm giao dịch mua vàng', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _investments.length,
      itemBuilder: (context, index) {
        final inv = _investments[index];
        // Find current price at which the shop buys from user to calculate profit
        double currentShopBuyPrice = 0;
        final current = _maoThietPrices.firstWhere(
          (p) => p['type'] == inv.goldType,
          orElse: () => {},
        );
        if (current.isNotEmpty) {
          currentShopBuyPrice = _parsePrice(current['buy']);
        }

        final totalBuy = inv.buyPrice * inv.quantity;
        final totalCurrent = currentShopBuyPrice * inv.quantity;
        final profit = totalCurrent - totalBuy;
        final isProfit = profit >= 0;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      inv.goldType,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    inv.date,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Số lượng: ${inv.quantity} chỉ',
                style: const TextStyle(fontSize: 13),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GIÁ MUA', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                      Text(
                        '${NumberFormat('#,###').format(inv.buyPrice)} đ',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('LỜI / LỖ', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                      Text(
                        '${isProfit ? '+' : ''}${NumberFormat('#,###').format(profit)} đ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isProfit ? Colors.green : Colors.red,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (inv.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Ghi chú: ${inv.note}',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ],
              const SizedBox(height: 8),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showAddInvestmentDialog(investment: inv),
                    icon: const Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                    label: const Text('Sửa', style: TextStyle(color: Colors.blue, fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _deleteInvestment(inv.id!),
                    icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                    label: const Text('Xóa', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAddInvestmentDialog({GoldInvestment? investment}) {
    String? selectedType = investment?.goldType ?? (_maoThietPrices.isNotEmpty ? _maoThietPrices[0]['type'] : null);
    final quantityController = TextEditingController(text: investment?.quantity.toString() ?? '');
    final priceController = TextEditingController(
      text: investment != null ? NumberFormat('#,###').format(investment.buyPrice) : '',
    );
    final noteController = TextEditingController(text: investment?.note ?? '');

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            padding: const EdgeInsets.all(20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    investment == null ? 'Thêm giao dịch mua' : 'Sửa giao dịch mua',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Loại vàng'),
                    items: _maoThietPrices.map((p) {
                      return DropdownMenuItem(
                        value: p['type'],
                        child: Text(
                          p['type'] ?? '',
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) => setDialogState(() => selectedType = val),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(labelText: 'Số lượng (chỉ)'),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SmartMoneyInput(
                    controller: priceController,
                    label: 'Giá mua (đ/chỉ)',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(labelText: 'Ghi chú'),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Hủy'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () async {
                          if (selectedType != null && quantityController.text.isNotEmpty && priceController.text.isNotEmpty) {
                            double inputPrice = double.tryParse(priceController.text.replaceAll('.', '').replaceAll(',', '')) ?? 0;
                            // If user enters a small number like 15000, assume it's in thousands and multiply by 1000
                            if (inputPrice < 1000000) {
                              inputPrice *= 1000;
                            }

                            final inv = GoldInvestment(
                              id: investment?.id,
                              goldType: selectedType!,
                              quantity: double.tryParse(quantityController.text) ?? 0,
                              buyPrice: inputPrice,
                              date: investment?.date ?? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()),
                              note: noteController.text,
                            );
                            
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
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red[900]),
                        child: const Text('Lưu', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _deleteInvestment(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa giao dịch này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Hủy')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Xóa', style: TextStyle(color: Colors.red))),
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
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: circlePainter.color.withValues(alpha: 0.9),
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();

    final yOffset = isAbove ? -15.0 : 8.0;
    textPainter.paint(
      canvas,
      offsetInCanvas + Offset(-textPainter.width / 2, yOffset),
    );
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
