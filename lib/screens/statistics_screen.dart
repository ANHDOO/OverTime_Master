import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../models/overtime_entry.dart';
import '../models/cash_transaction.dart';
import '../services/excel_service.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '3 tháng'; // 3 tháng, 6 tháng, 1 năm
  String _selectedProject = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {}); // Trigger rebuild to show/hide project filter
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<String> get _periodOptions => ['3 tháng', '6 tháng', '1 năm'];
  List<String> _getProjectOptions(List<CashTransaction> transactions) {
    final projects = transactions.map((t) => t.project).toSet().toList()..sort();
    return ['Tất cả', ...projects];
  }

  void _showExportDialog(BuildContext context) {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    
    // Lấy danh sách các tháng có dữ liệu
    final monthsWithData = <DateTime>{};
    for (final entry in provider.entries) {
      monthsWithData.add(DateTime(entry.date.year, entry.date.month));
    }
    final sortedMonths = monthsWithData.toList()..sort((a, b) => b.compareTo(a));
    
    if (sortedMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có dữ liệu tăng ca để xuất')),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                const Text(
                  'Xuất Excel cho kế toán',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Chọn tháng cần xuất báo cáo (không tính tiền)',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: sortedMonths.length,
                itemBuilder: (context, index) {
                  final month = sortedMonths[index];
                  final entriesCount = provider.entries.where((e) => 
                    e.date.month == month.month && e.date.year == month.year
                  ).length;
                  
                  return ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.calendar_month,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    title: Text(
                      'Tháng ${month.month}/${month.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text('$entriesCount ngày làm tăng ca'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.pop(context);
                      ExcelService.exportOvertimeForAccounting(
                        context: context,
                        entries: provider.entries,
                        month: month.month,
                        year: month.year,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
        actions: [
          // Export Excel button (only show on OT tab)
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Xuất Excel cho kế toán',
            onPressed: () => _showExportDialog(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          // Ensure selected/unselected labels and icons remain visible against AppBar background
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
          tabs: const [
            Tab(text: 'Lương OT', icon: Icon(Icons.access_time)),
            Tab(text: 'Thu Chi', icon: Icon(Icons.account_balance_wallet)),
          ],
        ),
      ),
      body: Consumer<OvertimeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final projectOptions = _getProjectOptions(provider.cashTransactions);

          return Column(
            children: [
              // Filters
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.grey.shade50,
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedPeriod,
                        decoration: const InputDecoration(
                          labelText: 'Thời gian',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _periodOptions.map((period) {
                          return DropdownMenuItem(
                            value: period,
                            child: Text(period),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedPeriod = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    if (_tabController.index == 1) // Only show for cash flow tab
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: projectOptions.contains(_selectedProject) ? _selectedProject : 'Tất cả',
                          decoration: const InputDecoration(
                            labelText: 'Dự án',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          items: projectOptions.map((project) {
                            return DropdownMenuItem(
                              value: project,
                              child: Text(project),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedProject = value);
                            }
                          },
                        ),
                      ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOTStatistics(provider, currencyFormat),
                    _buildCashFlowStatistics(provider, currencyFormat),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOTStatistics(OvertimeProvider provider, NumberFormat format) {
    final months = _getMonthsForPeriod(_selectedPeriod);
    final otData = _getOTDataForPeriod(provider.entries, months);

    if (otData.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.show_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Chưa có dữ liệu tăng ca', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(otData, format, 'OT'),
          const SizedBox(height: 24),
          const Text('Biểu đồ lương tăng ca theo tháng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.only(top: 24, right: 16, left: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < otData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MM/yy').format(otData[value.toInt()]['month']),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1000000,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          '${(value / 1000000).toStringAsFixed(0)}M',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        );
                      },
                      reservedSize: 35,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: otData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value['total']);
                    }).toList(),
                    isCurved: true,
                    gradient: LinearGradient(
                      colors: [
                        Theme.of(context).colorScheme.primary,
                        Theme.of(context).colorScheme.primary.withOpacity(0.7),
                      ],
                    ),
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 4,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          Theme.of(context).colorScheme.primary.withOpacity(0.2),
                          Theme.of(context).colorScheme.primary.withOpacity(0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.shade800,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final data = otData[spot.x.toInt()];
                        return LineTooltipItem(
                          '${DateFormat('MM/yyyy').format(data['month'])}\n',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: format.format(spot.y),
                              style: const TextStyle(color: Colors.yellow, fontWeight: FontWeight.w500),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          _buildSalaryPredictionCard(provider, format),
          const SizedBox(height: 24),
          _buildWorkTrendsSection(provider),
          const SizedBox(height: 24),
          const Text('Chi tiết theo tháng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...otData.map((data) => _buildMonthDetailCard(data, format)),
        ],
      ),
    );
  }

  Widget _buildSalaryPredictionCard(OvertimeProvider provider, NumberFormat format) {
    final totalIncome = provider.getTotalIncomeSoFar();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade800, Colors.green.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng thu nhập thực tế',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Icon(Icons.account_balance_wallet, color: Colors.white.withOpacity(0.8)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '(Lương + Phụ cấp + OT thực tế)',
            style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
          ),
          const SizedBox(height: 16),
          Text(
            format.format(totalIncome),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Lương OT: ${format.format(provider.totalMonthlyPay)}',
            style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkTrendsSection(OvertimeProvider provider) {
    final trends = provider.getWorkTrends();
    final weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final maxCount = trends.values.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Xu hướng làm việc', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            children: List.generate(7, (index) {
              final weekday = index + 1;
              final data = trends[weekday]!;
              final count = data['count'] as int;
              final hours = data['totalHours'] as double;
              final barWidth = maxCount > 0 ? (count / maxCount) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  children: [
                    SizedBox(
                      width: 30,
                      child: Text(
                        weekdays[index],
                        style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          FractionallySizedBox(
                            widthFactor: barWidth.clamp(0.05, 1.0),
                            child: Container(
                              height: 24,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.orange.shade400, Colors.orange.shade700],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Text(
                                '$count buổi (${hours.toStringAsFixed(1)}h)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: barWidth > 0.5 ? Colors.white : Colors.orange.shade900,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildCashFlowStatistics(OvertimeProvider provider, NumberFormat format) {
    final months = _getMonthsForPeriod(_selectedPeriod);
    final cashData = _getCashFlowDataForPeriod(provider.cashTransactions, months, _selectedProject);

    // Calculate project breakdown
    final projectBreakdown = <String, Map<String, double>>{};
    for (final t in provider.cashTransactions) {
      final tMonth = DateTime(t.date.year, t.date.month);
      if (months.any((m) => m.year == tMonth.year && m.month == tMonth.month)) {
        projectBreakdown.putIfAbsent(t.project, () => {'income': 0, 'expense': 0});
        if (t.type == TransactionType.income) {
          projectBreakdown[t.project]!['income'] = projectBreakdown[t.project]!['income']! + t.amount;
        } else {
          projectBreakdown[t.project]!['expense'] = projectBreakdown[t.project]!['expense']! + t.amount;
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(cashData, format, 'Cash'),
          const SizedBox(height: 24),
          const Text('Xu hướng thu chi theo tháng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            height: 300,
            padding: const EdgeInsets.only(top: 24, right: 16, left: 8, bottom: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.shade100,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < cashData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              DateFormat('MM/yy').format(cashData[value.toInt()]['month']),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 5000000,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const Text('');
                        return Text(
                          '${(value / 1000000).toStringAsFixed(0)}M',
                          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                        );
                      },
                      reservedSize: 35,
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Income line
                  LineChartBarData(
                    spots: cashData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value['income']);
                    }).toList(),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Colors.green,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  // Expense line
                  LineChartBarData(
                    spots: cashData.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value['expense']);
                    }).toList(),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                        radius: 3,
                        color: Colors.white,
                        strokeWidth: 2,
                        strokeColor: Colors.red,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [Colors.red.withOpacity(0.2), Colors.red.withOpacity(0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    tooltipBgColor: Colors.blueGrey.shade800,
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        final isIncome = spot.barIndex == 0;
                        return LineTooltipItem(
                          '${isIncome ? "Thu" : "Chi"}: ',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          children: [
                            TextSpan(
                              text: format.format(spot.y),
                              style: TextStyle(
                                color: isIncome ? Colors.greenAccent : Colors.redAccent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        );
                      }).toList();
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Thu nhập', Colors.green),
              const SizedBox(width: 24),
              _buildLegendItem('Chi tiêu', Colors.red),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Chi tiết theo dự án', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          ...projectBreakdown.entries.map((entry) {
            final projectName = entry.key;
            final income = entry.value['income']!;
            final expense = entry.value['expense']!;
            final balance = income - expense;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(projectName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(
                        format.format(balance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: balance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Thu: ${format.format(income)}', style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
                      Text('Chi: ${format.format(expense)}', style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildOverviewStatistics(OvertimeProvider provider, NumberFormat format) {
    final months = _getMonthsForPeriod(_selectedPeriod);
    final otData = _getOTDataForPeriod(provider.entries, months);
    
    final totalOTPay = otData.fold<double>(0, (sum, data) => sum + data['total']);
    
    // Exclude project funds (e.g., 'Mặc định' or 'Quỹ Phòng') from overview totals
    final excludedProjects = {'Mặc định', 'Quỹ Phòng', 'Công ty'};
    double totalIncome = 0;
    double totalExpense = 0;
    for (final t in provider.cashTransactions) {
      if (excludedProjects.contains(t.project)) continue;
      final transactionMonth = DateTime(t.date.year, t.date.month);
      if (months.any((m) => m.year == transactionMonth.year && m.month == transactionMonth.month)) {
        if (t.type == TransactionType.income) totalIncome += t.amount;
        if (t.type == TransactionType.expense) totalExpense += t.amount;
      }
    }
    final totalDebtInterest = provider.totalDebtInterest;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Tổng quan tài chính', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),

          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Lương OT',
                  format.format(totalOTPay),
                  Icons.access_time,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  'Tổng thu',
                  format.format(totalIncome),
                  Icons.arrow_upward,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildOverviewCard(
                  'Tổng chi',
                  format.format(totalExpense),
                  Icons.arrow_downward,
                  Colors.red,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildOverviewCard(
                  'Lãi nợ',
                  format.format(totalDebtInterest),
                  Icons.account_balance_wallet,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 32),
          const Text('Cân đối tài chính', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
            ),
            child: Column(
              children: [
                _buildBalanceRow('Thu nhập', totalIncome + totalOTPay, format, Colors.green),
                const Divider(),
                _buildBalanceRow('Chi tiêu', totalExpense + totalDebtInterest, format, Colors.red),
                const Divider(height: 32),
                _buildBalanceRow(
                  'Cân đối',
                  (totalIncome + totalOTPay) - (totalExpense + totalDebtInterest),
                  format,
                  (totalIncome + totalOTPay) >= (totalExpense + totalDebtInterest) ? Colors.green : Colors.red,
                  isBold: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> data, NumberFormat format, String type) {
    if (data.isEmpty) return const SizedBox();

    double total = 0;
    int count = 0;

    for (final item in data) {
      if (type == 'OT') {
        total += item['total'];
        count += (item['count'] as num).toInt();
      } else {
        total += item['income'] - item['expense'];
      }
    }

    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == 'OT' ? 'Tổng lương OT' : 'Cân đối thu chi',
                  style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  format.format(total),
                  style: TextStyle(
                    color: Colors.blue.shade900,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  type == 'OT' ? 'Số buổi OT' : 'Số tháng',
                  style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  type == 'OT' ? count.toString() : data.length.toString(),
                  style: TextStyle(
                    color: Colors.green.shade900,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthDetailCard(Map<String, dynamic> data, NumberFormat format) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                DateFormat('MMMM yyyy', 'vi_VN').format(data['month']),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              Text(
                '${data['count']} buổi OT',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
          Text(
            format.format(data['total']),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  Widget _buildOverviewCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceRow(String label, double amount, NumberFormat format, Color color, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          format.format(amount),
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: color,
          ),
        ),
      ],
    );
  }

  List<DateTime> _getMonthsForPeriod(String period) {
    final now = DateTime.now();
    final months = <DateTime>[];

    int monthCount;
    switch (period) {
      case '3 tháng':
        monthCount = 3;
        break;
      case '6 tháng':
        monthCount = 6;
        break;
      case '1 năm':
        monthCount = 12;
        break;
      default:
        monthCount = 6;
    }

    for (int i = monthCount - 1; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      months.add(month);
    }

    return months;
  }

  List<Map<String, dynamic>> _getOTDataForPeriod(List<OvertimeEntry> entries, List<DateTime> months) {
    return months.map((month) {
      final monthEntries = entries.where((entry) {
        return entry.date.year == month.year && entry.date.month == month.month;
      }).toList();

      final total = monthEntries.fold<double>(0, (sum, entry) => sum + entry.totalPay);

      return {
        'month': month,
        'count': monthEntries.length,
        'total': total,
      };
    }).toList();
  }

  List<Map<String, dynamic>> _getCashFlowDataForPeriod(List<CashTransaction> transactions, List<DateTime> months, String project) {
    return months.map((month) {
      final monthTransactions = transactions.where((transaction) {
        final transactionMonth = DateTime(transaction.date.year, transaction.date.month);
        return transactionMonth.year == month.year &&
               transactionMonth.month == month.month &&
               (project == 'Tất cả' || transaction.project == project);
      }).toList();

      final income = monthTransactions
          .where((t) => t.type == TransactionType.income)
          .fold<double>(0, (sum, t) => sum + t.amount);

      final expense = monthTransactions
          .where((t) => t.type == TransactionType.expense)
          .fold<double>(0, (sum, t) => sum + t.amount);

      return {
        'month': month,
        'income': income,
        'expense': expense,
      };
    }).toList();
  }

  }

