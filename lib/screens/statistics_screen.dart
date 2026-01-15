import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../models/overtime_entry.dart';
import '../models/cash_transaction.dart';
import '../services/excel_service.dart';
import '../theme/app_theme.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _selectedPeriod = '3 tháng';
  String _selectedProject = 'Tất cả';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final monthsWithData = <DateTime>{};
    for (final entry in provider.entries) {
      monthsWithData.add(DateTime(entry.date.year, entry.date.month));
    }
    final sortedMonths = monthsWithData.toList()..sort((a, b) => b.compareTo(a));
    
    if (sortedMonths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [const Icon(Icons.info_outline_rounded, color: Colors.white), const SizedBox(width: 12), const Text('Chưa có dữ liệu tăng ca')]),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, borderRadius: AppRadius.borderFull),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF217346).withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderMd),
                  child: const Icon(Icons.table_view_rounded, color: Color(0xFF217346)),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Xuất Excel cho kế toán', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    Text('Chọn tháng cần xuất báo cáo', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 13)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 200,
              child: ListView.builder(
                itemCount: sortedMonths.length,
                itemBuilder: (context, index) {
                  final month = sortedMonths[index];
                  final entriesCount = provider.entries.where((e) => e.date.month == month.month && e.date.year == month.year).length;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : AppColors.lightCard,
                      borderRadius: AppRadius.borderMd,
                      border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                    ),
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.indigoPrimary.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm),
                        child: Icon(Icons.calendar_month_rounded, color: AppColors.indigoPrimary, size: 20),
                      ),
                      title: Text('Tháng ${month.month}/${month.year}', style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                      subtitle: Text('$entriesCount ngày làm tăng ca', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                      trailing: Icon(Icons.arrow_forward_ios_rounded, size: 16, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                      onTap: () {
                        Navigator.pop(context);
                        ExcelService.exportOvertimeForAccounting(context: context, entries: provider.entries, month: month.month, year: month.year);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCashFlowExportDialog(BuildContext context) {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final projects = provider.cashTransactions.map((t) => t.project).toSet().toList()..sort();
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Chưa có dữ liệu thu chi')),
      );
      return;
    }

    final now = DateTime.now();
    final months = <DateTime>[];
    for (int i = 0; i < 6; i++) {
      months.add(DateTime(now.year, now.month - i, 1));
    }

    String selectedProject = projects.first;
    DateTime selectedMonth = months.first;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Xuất phiếu giải chi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              const SizedBox(height: 20),
              
              Text('Chọn dự án', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: DropdownButton<String>(
                  value: selectedProject,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: projects.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) => setModalState(() => selectedProject = v!),
                ),
              ),
              const SizedBox(height: 16),

              Text('Chọn tháng', style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: DropdownButton<DateTime>(
                  value: selectedMonth,
                  isExpanded: true,
                  underline: const SizedBox(),
                  items: months.map((m) => DropdownMenuItem(value: m, child: Text(DateFormat('MM/yyyy').format(m)))).toList(),
                  onChanged: (v) => setModalState(() => selectedMonth = v!),
                ),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    ExcelService.exportCashFlowForAccounting(
                      context: context,
                      transactions: provider.cashTransactions,
                      project: selectedProject,
                      month: selectedMonth.month,
                      year: selectedMonth.year,
                    );
                  },
                  icon: const Icon(Icons.table_view_rounded),
                  label: const Text('Xuất Excel'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF217346),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Thống kê'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded, color: Color(0xFF217346)),
            tooltip: 'Xuất Excel cho kế toán',
            onPressed: () {
              if (_tabController.index == 0) {
                _showExportDialog(context);
              } else {
                _showCashFlowExportDialog(context);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Lương OT', icon: Icon(Icons.access_time_rounded, size: 20)),
            Tab(text: 'Thu Chi', icon: Icon(Icons.account_balance_wallet_rounded, size: 20)),
          ],
        ),
      ),
      body: Consumer<OvertimeProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final projectOptions = _getProjectOptions(provider.cashTransactions);

          return Column(
            children: [
              _buildFilters(projectOptions, isDark),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildOTStatistics(provider, currencyFormat, isDark),
                    _buildCashFlowStatistics(provider, currencyFormat, isDark),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilters(List<String> projectOptions, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurfaceVariant,
        border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : AppColors.lightCard,
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: DropdownButton<String>(
                value: _selectedPeriod,
                isExpanded: true,
                underline: const SizedBox(),
                icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                items: _periodOptions.map((period) => DropdownMenuItem(
                  value: period,
                  child: Text(period, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                )).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _selectedPeriod = value);
                },
              ),
            ),
          ),
          if (_tabController.index == 1) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: DropdownButton<String>(
                  value: projectOptions.contains(_selectedProject) ? _selectedProject : 'Tất cả',
                  isExpanded: true,
                  underline: const SizedBox(),
                  icon: Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  dropdownColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                  items: projectOptions.map((project) => DropdownMenuItem(
                    value: project,
                    child: Text(project, style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  )).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedProject = value);
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOTStatistics(OvertimeProvider provider, NumberFormat format, bool isDark) {
    final months = _getMonthsForPeriod(_selectedPeriod);
    final otData = _getOTDataForPeriod(provider.entries, months);

    if (otData.isEmpty || otData.every((d) => d['total'] == 0)) {
      return _buildEmptyState('Chưa có dữ liệu tăng ca', Icons.access_time_rounded, isDark);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCards(otData, format, 'OT', isDark),
          const SizedBox(height: 24),
          _buildSectionHeader('Biểu đồ lương tăng ca', Icons.show_chart_rounded, isDark),
          const SizedBox(height: 16),
          _buildOTLineChart(otData, format, isDark),
          const SizedBox(height: 24),
          _buildWorkTrendsSection(provider, isDark),
          const SizedBox(height: 24),
          _buildSectionHeader('Chi tiết theo tháng', Icons.calendar_view_month_rounded, isDark),
          const SizedBox(height: 16),
          ...otData.where((d) => d['total'] > 0).map((data) => _buildMonthDetailCard(data, format, isDark)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 48, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
          ),
          const SizedBox(height: 20),
          Text(message, style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm),
          child: Icon(icon, color: AppColors.primary, size: 18),
        ),
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
      ],
    );
  }

  Widget _buildOTLineChart(List<Map<String, dynamic>> otData, NumberFormat format, bool isDark) {
    return Container(
      height: 280,
      padding: const EdgeInsets.only(top: 20, right: 16, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < otData.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        DateFormat('MM/yy').format(otData[value.toInt()]['month']),
                        style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w600),
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
                  return Text('${(value / 1000000).toStringAsFixed(0)}M', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted));
                },
                reservedSize: 35,
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: otData.asMap().entries.map((entry) => FlSpot(entry.key.toDouble(), entry.value['total'])).toList(),
              isCurved: true,
              gradient: AppGradients.heroBlue,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: AppColors.primary),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(colors: [AppColors.primary.withOpacity(0.2), AppColors.primary.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: AppColors.darkSurface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final data = otData[spot.x.toInt()];
                  return LineTooltipItem(
                    '${DateFormat('MM/yyyy').format(data['month'])}\n',
                    const TextStyle(color: Colors.white70, fontSize: 11),
                    children: [TextSpan(text: format.format(spot.y), style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w700, fontSize: 14))],
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWorkTrendsSection(OvertimeProvider provider, bool isDark) {
    final trends = provider.getWorkTrends();
    final weekdays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final maxCount = trends.values.map((e) => e['count'] as int).reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Xu hướng làm việc', Icons.trending_up_rounded, isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.lightCard,
            borderRadius: AppRadius.borderLg,
            border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
          ),
          child: Column(
            children: List.generate(7, (index) {
              final weekday = index + 1;
              final data = trends[weekday]!;
              final count = data['count'] as int;
              final hours = data['totalHours'] as double;
              final barWidth = maxCount > 0 ? (count / maxCount) : 0.0;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(weekdays[index], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(height: 26, decoration: BoxDecoration(color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant, borderRadius: AppRadius.borderFull)),
                          FractionallySizedBox(
                            widthFactor: barWidth.clamp(0.05, 1.0),
                            child: Container(height: 26, decoration: BoxDecoration(gradient: AppGradients.heroOrange, borderRadius: AppRadius.borderFull)),
                          ),
                          Positioned.fill(
                            child: Center(
                              child: Text(
                                '$count buổi (${hours.toStringAsFixed(1)}h)',
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: barWidth > 0.4 ? Colors.white : AppColors.accent),
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

  Widget _buildCashFlowStatistics(OvertimeProvider provider, NumberFormat format, bool isDark) {
    final months = _getMonthsForPeriod(_selectedPeriod);
    final cashData = _getCashFlowDataForPeriod(provider.cashTransactions, months, _selectedProject);

    final projectBreakdown = <String, Map<String, double>>{};
    for (final t in provider.cashTransactions) {
      final tMonth = DateTime(t.date.year, t.date.month);
      if (months.any((m) => m.year == tMonth.year && m.month == tMonth.month) && (_selectedProject == 'Tất cả' || t.project == _selectedProject)) {
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
          _buildSummaryCards(cashData, format, 'Cash', isDark),
          const SizedBox(height: 24),
          _buildSectionHeader('Xu hướng thu chi', Icons.swap_vert_rounded, isDark),
          const SizedBox(height: 16),
          _buildCashFlowChart(cashData, format, isDark),
          const SizedBox(height: 16),
          _buildChartLegend(isDark),
          const SizedBox(height: 32),
          _buildSectionHeader('Chi tiết theo dự án', Icons.folder_rounded, isDark),
          const SizedBox(height: 16),
          ...projectBreakdown.entries.map((entry) => _buildProjectCard(entry.key, entry.value['income']!, entry.value['expense']!, format, isDark)),
        ],
      ),
    );
  }

  Widget _buildCashFlowChart(List<Map<String, dynamic>> cashData, NumberFormat format, bool isDark) {
    return Container(
      height: 280,
      padding: const EdgeInsets.only(top: 20, right: 16, left: 8, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (value) => FlLine(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, strokeWidth: 1)),
          titlesData: FlTitlesData(
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true, reservedSize: 28, interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() < cashData.length) {
                    return Padding(padding: const EdgeInsets.only(top: 8), child: Text(DateFormat('MM/yy').format(cashData[value.toInt()]['month']), style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontWeight: FontWeight.w600)));
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 5000000, getTitlesWidget: (value, meta) { if (value == 0) return const Text(''); return Text('${(value / 1000000).toStringAsFixed(0)}M', style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)); }, reservedSize: 35)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(spots: cashData.asMap().entries.map((entry) => FlSpot(entry.key.toDouble(), entry.value['income'])).toList(), isCurved: true, color: AppColors.success, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: AppColors.success)), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppColors.success.withOpacity(0.15), AppColors.success.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
            LineChartBarData(spots: cashData.asMap().entries.map((entry) => FlSpot(entry.key.toDouble(), entry.value['expense'])).toList(), isCurved: true, color: AppColors.danger, barWidth: 3, dotData: FlDotData(show: true, getDotPainter: (s, p, b, i) => FlDotCirclePainter(radius: 3, color: Colors.white, strokeWidth: 2, strokeColor: AppColors.danger)), belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [AppColors.danger.withOpacity(0.15), AppColors.danger.withOpacity(0)], begin: Alignment.topCenter, end: Alignment.bottomCenter))),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendItem('Thu nhập', AppColors.success, isDark),
        const SizedBox(width: 24),
        _buildLegendItem('Chi tiêu', AppColors.danger, isDark),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isDark) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildProjectCard(String name, double income, double expense, NumberFormat format, bool isDark) {
    final balance = income - expense;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.tealPrimary.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm), child: Icon(Icons.folder_rounded, color: AppColors.tealPrimary, size: 18)),
                const SizedBox(width: 12),
                Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              ]),
              Text(format.format(balance), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: balance >= 0 ? AppColors.success : AppColors.danger)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [Icon(Icons.south_rounded, color: AppColors.success, size: 14), const SizedBox(width: 4), Text('Thu: ${format.format(income)}', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600))]),
              Row(children: [Icon(Icons.north_rounded, color: AppColors.danger, size: 14), const SizedBox(width: 4), Text('Chi: ${format.format(expense)}', style: TextStyle(color: AppColors.danger, fontSize: 12, fontWeight: FontWeight.w600))]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<Map<String, dynamic>> data, NumberFormat format, String type, bool isDark) {
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
              gradient: LinearGradient(colors: [AppColors.primary.withOpacity(isDark ? 0.2 : 0.1), AppColors.primaryDark.withOpacity(isDark ? 0.15 : 0.05)]),
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(type == 'OT' ? Icons.payments_rounded : Icons.account_balance_rounded, color: AppColors.primary, size: 18), const SizedBox(width: 8), Text(type == 'OT' ? 'Tổng lương OT' : 'Cân đối thu chi', style: TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 10),
                Text(format.format(total), style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppColors.success.withOpacity(isDark ? 0.2 : 0.1), AppColors.successDark.withOpacity(isDark ? 0.15 : 0.05)]),
              borderRadius: AppRadius.borderLg,
              border: Border.all(color: AppColors.success.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [Icon(type == 'OT' ? Icons.event_available_rounded : Icons.date_range_rounded, color: AppColors.success, size: 18), const SizedBox(width: 8), Text(type == 'OT' ? 'Số buổi OT' : 'Số tháng', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.w600))]),
                const SizedBox(height: 10),
                Text(type == 'OT' ? count.toString() : data.length.toString(), style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMonthDetailCard(Map<String, dynamic> data, NumberFormat format, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: AppColors.indigoPrimary.withOpacity(isDark ? 0.2 : 0.1), borderRadius: AppRadius.borderSm), child: Icon(Icons.calendar_today_rounded, color: AppColors.indigoPrimary, size: 18)),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(DateFormat('MMMM yyyy', 'vi_VN').format(data['month']), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
              Text('${data['count']} buổi OT', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
            ]),
          ]),
          Text(format.format(data['total']), style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.success)),
        ],
      ),
    );
  }

  List<DateTime> _getMonthsForPeriod(String period) {
    final now = DateTime.now();
    final months = <DateTime>[];
    int monthCount = period == '3 tháng' ? 3 : period == '6 tháng' ? 6 : 12;
    for (int i = monthCount - 1; i >= 0; i--) {
      months.add(DateTime(now.year, now.month - i, 1));
    }
    return months;
  }

  List<Map<String, dynamic>> _getOTDataForPeriod(List<OvertimeEntry> entries, List<DateTime> months) {
    return months.map((month) {
      final monthEntries = entries.where((entry) => entry.date.year == month.year && entry.date.month == month.month).toList();
      return {'month': month, 'count': monthEntries.length, 'total': monthEntries.fold<double>(0, (sum, e) => sum + e.totalPay)};
    }).toList();
  }

  List<Map<String, dynamic>> _getCashFlowDataForPeriod(List<CashTransaction> transactions, List<DateTime> months, String project) {
    return months.map((month) {
      final monthTransactions = transactions.where((t) {
        final tm = DateTime(t.date.year, t.date.month);
        return tm.year == month.year && tm.month == month.month && (project == 'Tất cả' || t.project == project);
      }).toList();
      return {
        'month': month,
        'income': monthTransactions.where((t) => t.type == TransactionType.income).fold<double>(0, (sum, t) => sum + t.amount),
        'expense': monthTransactions.where((t) => t.type == TransactionType.expense).fold<double>(0, (sum, t) => sum + t.amount),
      };
    }).toList();
  }
}
