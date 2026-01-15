import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../models/overtime_entry.dart';
import '../theme/app_theme.dart';
import 'add_entry_screen.dart';
import 'add_debt_screen.dart';
import 'add_transaction_screen.dart';
import 'entry_detail_screen.dart';
import 'cash_flow_tab.dart';
import 'statistics_screen.dart';
import 'pit_calculator_screen.dart';
import 'citizen_search/citizen_search_screen.dart';
import '../widgets/side_menu.dart';

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({super.key, this.initialIndex = 0});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;
  DateTime _otSelectedMonth = DateTime.now();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onOTMonthChanged(DateTime month) {
    setState(() {
      _otSelectedMonth = month;
    });
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Quỹ Dự Án';
      case 1:
        return 'OT Master';
      case 2:
        return 'Lãi nợ lương';
      case 3:
        return 'Tính thuế TNCN';
      default:
        return 'Quỹ Dự Án';
    }
  }

  LinearGradient _getFabGradient() {
    switch (_currentIndex) {
      case 0:
        return AppGradients.heroTeal;
      case 1:
        return AppGradients.heroBlue;
      case 2:
        return AppGradients.heroOrange;
      case 3:
        return AppGradients.heroIndigo;
      default:
        return AppGradients.heroTeal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      key: _scaffoldKey,
      drawer: SideMenu(
        onSelectTab: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        onClose: () {
          _scaffoldKey.currentState?.openEndDrawer();
        },
        selectedIndex: _currentIndex,
      ),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CitizenSearchScreen()),
              );
            },
            tooltip: 'Tra cứu công dân',
          ),
          IconButton(
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsScreen()),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const CashFlowTab(),
          OTTab(
            selectedMonth: _otSelectedMonth,
            onMonthChanged: _onOTMonthChanged,
          ),
          const DebtTab(),
          const PITCalculatorTab(),
        ],
      ),
      floatingActionButton: _currentIndex == 3 ? null : _buildGradientFab(context),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: NavigationBar(
              height: 64,
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              destinations: [
                _buildNavDestination(
                  icon: Icons.savings_outlined,
                  selectedIcon: Icons.savings_rounded,
                  label: 'Quỹ',
                  index: 0,
                ),
                _buildNavDestination(
                  icon: Icons.schedule_outlined,
                  selectedIcon: Icons.schedule_rounded,
                  label: 'Tăng ca',
                  index: 1,
                ),
                _buildNavDestination(
                  icon: Icons.account_balance_wallet_outlined,
                  selectedIcon: Icons.account_balance_wallet_rounded,
                  label: 'Lãi nợ',
                  index: 2,
                ),
                _buildNavDestination(
                  icon: Icons.calculate_outlined,
                  selectedIcon: Icons.calculate_rounded,
                  label: 'Thuế',
                  index: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  NavigationDestination _buildNavDestination({
    required IconData icon,
    required IconData selectedIcon,
    required String label,
    required int index,
  }) {
    return NavigationDestination(
      icon: Icon(icon, size: 24),
      selectedIcon: Icon(selectedIcon, size: 24),
      label: label,
    );
  }

  Widget _buildGradientFab(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: _getFabGradient(),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _getFabGradient().colors.first.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton(
        elevation: 0,
        backgroundColor: Colors.transparent,
        onPressed: () {
          if (_currentIndex == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddEntryScreen(selectedMonth: _otSelectedMonth)),
            );
          } else if (_currentIndex == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddDebtScreen()),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
            );
          }
        },
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// OT TAB
// ═══════════════════════════════════════════════════════════════════════════
class OTTab extends StatefulWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onMonthChanged;
  
  const OTTab({
    super.key,
    required this.selectedMonth,
    required this.onMonthChanged,
  });

  @override
  State<OTTab> createState() => _OTTabState();
}

class _OTTabState extends State<OTTab> {
  List<DateTime> _getAvailableMonths(List<dynamic> entries) {
    final months = <DateTime>[];
    final now = DateTime.now();
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      months.add(month);
    }
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final availableMonths = _getAvailableMonths(provider.entries);
        final normalizedSelectedMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month);
        DateTime effectiveSelectedMonth = normalizedSelectedMonth;
        
        if (!availableMonths.any((m) => m.year == normalizedSelectedMonth.year && m.month == normalizedSelectedMonth.month)) {
          effectiveSelectedMonth = availableMonths.first;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) widget.onMonthChanged(effectiveSelectedMonth);
          });
        } else {
          effectiveSelectedMonth = availableMonths.firstWhere(
            (m) => m.year == normalizedSelectedMonth.year && m.month == normalizedSelectedMonth.month
          );
        }
        
        final filteredEntries = provider.entries.where((entry) {
          return entry.date.year == effectiveSelectedMonth.year && 
                 entry.date.month == effectiveSelectedMonth.month;
        }).toList();

        final monthlyTotal = filteredEntries.fold<double>(0, (sum, entry) => sum + entry.totalPay);

        return Column(
          children: [
            _buildHeroCard(context, provider, currencyFormat, monthlyTotal, filteredEntries.length, effectiveSelectedMonth),
            
            // Section Header with Filter
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Lịch sử tăng ca',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.1),
                      borderRadius: AppRadius.borderFull,
                      border: Border.all(
                        color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.2),
                      ),
                    ),
                    child: DropdownButton<DateTime>(
                      value: effectiveSelectedMonth,
                      underline: const SizedBox(),
                      isDense: true,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: isDark ? AppColors.primaryLight : AppColors.primary,
                      ),
                      items: availableMonths.map((month) {
                        return DropdownMenuItem(
                          value: month,
                          child: Text(
                            DateFormat('MM/yyyy').format(month),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) widget.onMonthChanged(value);
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            // Entry List
            Expanded(
              child: filteredEntries.isEmpty
                  ? _buildEmptyState(effectiveSelectedMonth, isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        return _buildEntryCard(context, entry, currencyFormat, provider, isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context, OvertimeProvider provider, NumberFormat format, double monthlyTotal, int entryCount, DateTime selectedMonth) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark ? AppGradients.heroBlueDark : AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: isDark ? AppShadows.heroDark : AppShadows.heroLight,
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.05),
              ),
            ),
          ),
          
          // Content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: const Icon(Icons.trending_up_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Thu nhập tăng ca',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: AppRadius.borderFull,
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: Text(
                        DateFormat('MM/yyyy').format(selectedMonth),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  format.format(monthlyTotal),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeroStat('Số buổi', entryCount.toString(), Icons.event_note_rounded),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _buildHeroStat('Ngày công', provider.getWorkingDaysForMonth(selectedMonth.year, selectedMonth.month).toString(), Icons.calendar_today_rounded),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _buildHeroStat('Lương/h', format.format(provider.getHourlyRateForMonth(selectedMonth.year, selectedMonth.month)), Icons.payments_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildEntryCard(BuildContext context, OvertimeEntry entry, NumberFormat currencyFormat, OvertimeProvider provider, bool isDark) {
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;
    
    Color typeColor;
    String typeLabel;
    if (entry.isSunday) {
      typeColor = AppColors.danger;
      typeLabel = 'CN x2.0';
    } else if (entry.hours18 > 0) {
      typeColor = AppColors.warning;
      typeLabel = 'Đêm x1.8';
    } else {
      typeColor = AppColors.primary;
      typeLabel = 'OT x1.5';
    }

    return Dismissible(
      key: Key('entry_${entry.id}'),
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
          borderRadius: AppRadius.borderLg,
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        child: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text('Sửa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.danger, AppColors.dangerDark],
          ),
          borderRadius: AppRadius.borderLg,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            SizedBox(width: 8),
            Icon(Icons.delete_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.endToStart) {
          return await _showDeleteConfirmDialog(context);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (context) => AddEntryScreen(editEntry: entry)));
          return false;
        }
      },
      onDismissed: (direction) {
        if (direction == DismissDirection.endToStart) {
          final deletedEntry = entry;
          provider.deleteEntry(entry.id!);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Đã xóa OT ngày ${DateFormat('dd/MM').format(deletedEntry.date)}'),
              action: SnackBarAction(
                label: 'Hoàn tác',
                onPressed: () => provider.restoreEntry(deletedEntry),
              ),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: AppRadius.borderLg,
          border: Border.all(color: borderColor.withOpacity(0.5)),
          boxShadow: isDark ? AppShadows.cardDark : AppShadows.cardLight,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: AppRadius.borderLg,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => EntryDetailScreen(entry: entry)));
            },
            onLongPress: () => _showEntryActionsSheet(context, provider, entry),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Date badge
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary.withOpacity(isDark ? 0.3 : 0.1),
                          AppColors.primaryLight.withOpacity(isDark ? 0.2 : 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppRadius.borderMd,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('dd').format(entry.date),
                          style: TextStyle(
                            color: isDark ? AppColors.primaryLight : AppColors.primary,
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          DateFormat('EEE', 'vi_VN').format(entry.date).toUpperCase(),
                          style: TextStyle(
                            color: (isDark ? AppColors.primaryLight : AppColors.primary).withOpacity(0.7),
                            fontWeight: FontWeight.w600,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                DateFormat('dd/MM/yyyy').format(entry.date),
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: typeColor.withOpacity(0.15),
                                borderRadius: AppRadius.borderFull,
                              ),
                              child: Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: typeColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.schedule_rounded, size: 14, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                            const SizedBox(width: 4),
                            Text(
                              '${entry.startTime.format(context)} - ${entry.endTime.format(context)}',
                              style: TextStyle(
                                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Amount
                  Text(
                    currencyFormat.format(entry.totalPay),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.success,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(DateTime month, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.event_busy_rounded,
              size: 40,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có dữ liệu tăng ca',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tháng ${DateFormat('MM/yyyy').format(month)}',
            style: TextStyle(
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showDeleteConfirmDialog(BuildContext context) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Xóa bản ghi?'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn xóa bản ghi này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showEntryActionsSheet(BuildContext context, OvertimeProvider provider, OvertimeEntry entry) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  borderRadius: AppRadius.borderFull,
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Icon(Icons.copy_rounded, color: AppColors.primary, size: 20),
                ),
                title: const Text('Sao chép sang ngày khác'),
                subtitle: Text('${entry.startTime.format(context)} - ${entry.endTime.format(context)}'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddEntryScreen(copyFrom: entry)));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Icon(Icons.edit_rounded, color: AppColors.warning, size: 20),
                ),
                title: const Text('Chỉnh sửa'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddEntryScreen(editEntry: entry)));
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Icon(Icons.delete_rounded, color: AppColors.danger, size: 20),
                ),
                title: const Text('Xóa'),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await _showDeleteConfirmDialog(context);
                  if (confirm) {
                    provider.deleteEntry(entry.id!);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Đã xóa OT ngày ${DateFormat('dd/MM').format(entry.date)}'),
                          action: SnackBarAction(
                            label: 'Hoàn tác',
                            onPressed: () => provider.restoreEntry(entry),
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// DEBT TAB
// ═══════════════════════════════════════════════════════════════════════════
class DebtTab extends StatelessWidget {
  const DebtTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        return Column(
          children: [
            _buildHeroCard(context, provider, currencyFormat),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    'Danh sách nợ lương',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.debtEntries.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: provider.debtEntries.length,
                      itemBuilder: (context, index) {
                        final debt = provider.debtEntries[index];
                        return _buildDebtCard(context, debt, currencyFormat, provider, isDark);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context, OvertimeProvider provider, NumberFormat format) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppGradients.heroOrange,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroOrangeLight,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: AppRadius.borderSm,
                          ),
                          child: const Icon(Icons.account_balance_rounded, color: Colors.white, size: 18),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Tổng tiền lãi tích lũy',
                          style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: AppRadius.borderFull,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Realtime',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  format.format(provider.totalDebtInterest),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildHeroStat('Số khoản nợ', provider.debtEntries.length.toString(), Icons.receipt_long_rounded),
                      Container(width: 1, height: 40, color: Colors.white24),
                      _buildHeroStat('Tổng gốc', format.format(provider.totalDebtAmount), Icons.account_balance_wallet_rounded),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(height: 6),
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ],
    );
  }

  Widget _buildDebtCard(BuildContext context, dynamic debt, NumberFormat currencyFormat, OvertimeProvider provider, bool isDark) {
    final interest = debt.calculateInterest();
    final monthFormat = DateFormat('MM/yyyy');
    final cardColor = isDark ? AppColors.darkCard : AppColors.lightCard;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: debt.isPaid ? (isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant) : cardColor,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: borderColor.withOpacity(0.5)),
        boxShadow: isDark ? AppShadows.cardDark : AppShadows.cardLight,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Transform.scale(
                        scale: 1.1,
                        child: Checkbox(
                          value: debt.isPaid,
                          onChanged: (value) => provider.toggleDebtPaid(debt),
                          activeColor: AppColors.success,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        ),
                      ),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: debt.isPaid 
                                ? AppColors.success.withOpacity(0.15)
                                : AppColors.warning.withOpacity(0.15),
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Text(
                            debt.isPaid ? 'Đã thanh toán' : 'Tháng ${monthFormat.format(debt.month)}',
                            style: TextStyle(
                              color: debt.isPaid ? AppColors.success : AppColors.warning,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                              decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ),
                      if (!debt.isPaid && interest['daysLate']! > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.15),
                            borderRadius: AppRadius.borderFull,
                          ),
                          child: Text(
                            'Quá ${interest['daysLate']!.toInt()} ngày',
                            style: TextStyle(color: AppColors.danger, fontSize: 10, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  onPressed: () => _showDeleteDialog(context, provider, debt.id!),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Gốc nợ', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(debt.amount),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('Tiền lãi', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text(
                      currencyFormat.format(interest['totalInterest']),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: debt.isPaid ? (isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted) : AppColors.danger,
                        decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            Divider(height: 24, color: borderColor),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  debt.isPaid ? 'Tổng đã trả:' : 'Tổng phải trả:',
                  style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                ),
                Text(
                  currencyFormat.format(debt.amount + interest['totalInterest']!),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: debt.isPaid ? AppColors.primary : AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.account_balance_wallet_outlined,
              size: 40,
              color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Chưa có khoản nợ lương nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, OvertimeProvider provider, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withOpacity(0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Xóa khoản nợ?'),
          ],
        ),
        content: const Text('Bạn có chắc chắn muốn xóa khoản nợ này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () {
              provider.deleteDebtEntry(id);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
