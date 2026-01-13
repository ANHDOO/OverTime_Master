import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../models/overtime_entry.dart';
import 'add_entry_screen.dart';
import 'add_debt_screen.dart';
import 'add_transaction_screen.dart';
import 'entry_detail_screen.dart';
import 'settings_screen.dart';
import 'cash_flow_tab.dart';
import 'statistics_screen.dart';
import 'pit_calculator_screen.dart';
import 'citizen_search/citizen_search_screen.dart';
import '../widgets/side_menu.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  DateTime _otSelectedMonth = DateTime.now();
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
        return 'Tính thuế TNCN 2026';
      default:
        return 'Quỹ Dự Án';
    }
  }

  Color _getFabColor() {
    switch (_currentIndex) {
      case 0:
        return Colors.teal.shade700;
      case 1:
        return Theme.of(context).colorScheme.primary;
      case 2:
        return Colors.orange.shade700;
      case 3:
        return Colors.indigo.shade700;
      default:
        return Colors.teal.shade700;
    }
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text(
          _getAppBarTitle(),
          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.0, fontSize: 15),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CitizenSearchScreen()),
              );
            },
            tooltip: 'Tra cứu công dân',
          ),
          IconButton(
            icon: const Icon(Icons.show_chart),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StatisticsScreen()),
              );
            },
          ),
          // settings button removed per request
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
      floatingActionButton: _currentIndex == 3 ? null : FloatingActionButton(
        backgroundColor: _getFabColor(),
        mini: true,
        onPressed: () {
          // New order: 0 = Quỹ Dự Án, 1 = Tăng ca, 2 = Lãi nợ
          if (_currentIndex == 1) {
            // Tăng ca
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => AddEntryScreen(selectedMonth: _otSelectedMonth)),
            );
          } else if (_currentIndex == 2) {
            // Lãi nợ
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddDebtScreen()),
            );
          } else {
            // Quỹ Dự Án
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddTransactionScreen()),
            );
          }
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: NavigationBar(
        height: 70,
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.savings_outlined, size: 20),
            selectedIcon: Icon(Icons.savings, size: 20),
            label: 'Quỹ Dự Án',
          ),
          NavigationDestination(
            icon: Icon(Icons.access_time_outlined, size: 20),
            selectedIcon: Icon(Icons.access_time_filled, size: 20),
            label: 'Tăng ca',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
            selectedIcon: Icon(Icons.account_balance_wallet, size: 20),
            label: 'Lãi nợ',
          ),
          NavigationDestination(
            icon: Icon(Icons.calculate_outlined, size: 20),
            selectedIcon: Icon(Icons.calculate, size: 20),
            label: 'Tính thuế',
          ),
        ],
      ),
    );
  }
}

// OT Tab Content
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
    
    // Generate last 12 months
    for (int i = 0; i < 12; i++) {
      final month = DateTime(now.year, now.month - i, 1);
      months.add(month);
    }
    
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final availableMonths = _getAvailableMonths(provider.entries);
        
        // Ensure selected month is in available months
        final normalizedSelectedMonth = DateTime(widget.selectedMonth.year, widget.selectedMonth.month);
        DateTime effectiveSelectedMonth = normalizedSelectedMonth;
        if (!availableMonths.any((m) => m.year == normalizedSelectedMonth.year && m.month == normalizedSelectedMonth.month)) {
          effectiveSelectedMonth = availableMonths.first;
          // Update state after build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              widget.onMonthChanged(effectiveSelectedMonth);
            }
          });
        } else {
          effectiveSelectedMonth = availableMonths.firstWhere(
            (m) => m.year == normalizedSelectedMonth.year && m.month == normalizedSelectedMonth.month
          );
        }
        
        // Filter entries by selected month
        final filteredEntries = provider.entries.where((entry) {
          return entry.date.year == effectiveSelectedMonth.year && 
                 entry.date.month == effectiveSelectedMonth.month;
        }).toList();

        // Calculate total for selected month
        final monthlyTotal = filteredEntries.fold<double>(0, (sum, entry) => sum + entry.totalPay);

        return Column(
          children: [
            _buildSummaryCard(context, provider, currencyFormat, monthlyTotal, filteredEntries.length, effectiveSelectedMonth),
            
            // Month Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Lịch sử tăng ca',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: DropdownButton<DateTime>(
                      value: effectiveSelectedMonth,
                      underline: const SizedBox(),
                      isDense: true,
                      icon: const Icon(Icons.arrow_drop_down, size: 20),
                      items: availableMonths.map((month) {
                        return DropdownMenuItem(
                          value: month,
                          child: Text(
                            DateFormat('MM/yyyy').format(month),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          widget.onMonthChanged(value);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: filteredEntries.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_busy, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Không có dữ liệu tăng ca\ntháng ${DateFormat('MM/yyyy').format(effectiveSelectedMonth)}',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: filteredEntries.length,
                      itemBuilder: (context, index) {
                        final entry = filteredEntries[index];
                        return Dismissible(
                          key: Key('entry_${entry.id}'),
                          // Swipe right to edit (primary direction)
                          background: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade400,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 24),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, color: Colors.white, size: 28),
                                SizedBox(width: 8),
                                Text('Sửa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          // Swipe left to delete
                          secondaryBackground: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade400,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Text('Xóa', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                Icon(Icons.delete, color: Colors.white, size: 28),
                              ],
                            ),
                          ),
                          confirmDismiss: (direction) async {
                            if (direction == DismissDirection.endToStart) {
                              // Swipe left = Delete -> confirm
                              return await _showDeleteConfirmDialog(context);
                            } else {
                              // Swipe right = Edit
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => AddEntryScreen(editEntry: entry),
                                ),
                              );
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
                                    onPressed: () {
                                      provider.restoreEntry(deletedEntry);
                                    },
                                  ),
                                  duration: const Duration(seconds: 4),
                                ),
                              );
                            }
                          },
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Text(
                                    DateFormat('dd').format(entry.date),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                              ),
                              title: Text(
                                DateFormat('EEEE, dd/MM/yyyy', 'vi_VN').format(entry.date),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time, size: 14, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${entry.startTime.format(context)} - ${entry.endTime.format(context)}',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    currencyFormat.format(entry.totalPay),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                      fontSize: 16,
                                    ),
                                  ),
                                  if (entry.isSunday)
                                    const Text(
                                      'Chủ nhật (x2.0)',
                                      style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.bold),
                                    )
                                  else if (entry.hours18 > 0)
                                    const Text(
                                      'Có làm đêm (x1.8)',
                                      style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold),
                                    )
                                  else
                                    const Text(
                                      'Tăng ca (x1.5)',
                                      style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                                    ),
                                ],
                              ),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EntryDetailScreen(entry: entry),
                                  ),
                                );
                              },
                              onLongPress: () {
                                _showEntryActionsSheet(context, provider, entry);
                              },
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, OvertimeProvider provider, NumberFormat format, double monthlyTotal, int entryCount, DateTime selectedMonth) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E88E5),
            const Color(0xFF1565C0),
            const Color(0xFF0D47A1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D47A1).withOpacity(0.4),
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
              const Text(
                'Tổng thu nhập tăng ca',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  DateFormat('MM/yyyy').format(selectedMonth),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            format.format(monthlyTotal),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMiniStat('Số buổi', entryCount.toString(), Icons.event_note),
              const SizedBox(width: 24),
              _buildMiniStat('Ngày công', provider.getWorkingDaysForMonth(selectedMonth.year, selectedMonth.month).toString(), Icons.calendar_today),
              const SizedBox(width: 24),
              _buildMiniStat('Lương/h', format.format(provider.getHourlyRateForMonth(selectedMonth.year, selectedMonth.month)), Icons.payments),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  Future<bool> _showDeleteConfirmDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa bản ghi?'),
        content: const Text('Bạn có chắc chắn muốn xóa bản ghi này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showEntryActionsSheet(BuildContext context, OvertimeProvider provider, OvertimeEntry entry) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.copy, color: Colors.blue),
              title: const Text('Sao chép sang ngày khác'),
              subtitle: Text('${entry.startTime.format(context)} - ${entry.endTime.format(context)}'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEntryScreen(copyFrom: entry),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: Colors.orange),
              title: const Text('Chỉnh sửa'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddEntryScreen(editEntry: entry),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
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
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// Debt Tab Content
class DebtTab extends StatelessWidget {
  const DebtTab({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            _buildSummaryCard(context, provider, currencyFormat),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Text(
                    'Danh sách nợ lương',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: provider.debtEntries.isEmpty
                  ? const Center(child: Text('Chưa có khoản nợ lương nào'))
                  : ListView.builder(
                      itemCount: provider.debtEntries.length,
                      itemBuilder: (context, index) {
                        final debt = provider.debtEntries[index];
                        final interest = debt.calculateInterest();
                        final monthFormat = DateFormat('MM/yyyy');

                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: debt.isPaid ? Colors.grey.shade100 : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
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
                                          // Paid checkbox
                                          SizedBox(
                                            width: 40,
                                            height: 40,
                                            child: Checkbox(
                                              value: debt.isPaid,
                                              onChanged: (value) => provider.toggleDebtPaid(debt),
                                              activeColor: Colors.green,
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                          ),
                                          Flexible(
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: debt.isPaid ? Colors.green.shade100 : Colors.orange.shade100,
                                                borderRadius: BorderRadius.circular(20),
                                              ),
                                              child: Text(
                                                debt.isPaid ? 'Đã thanh toán' : 'Tháng ${monthFormat.format(debt.month)}',
                                                style: TextStyle(
                                                  color: debt.isPaid ? Colors.green.shade800 : Colors.orange.shade800,
                                                  fontWeight: FontWeight.bold,
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
                                                color: Colors.red.shade100,
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                'Quá ${interest['daysLate']!.toInt()} ngày',
                                                style: TextStyle(color: Colors.red.shade800, fontSize: 10, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_outline, color: Colors.grey.shade400),
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
                                        Text('Gốc nợ', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          currencyFormat.format(debt.amount), 
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16,
                                            decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                                            color: debt.isPaid ? Colors.grey.shade600 : Colors.black,
                                          )
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Tiền lãi', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        const SizedBox(height: 4),
                                        Text(
                                          currencyFormat.format(interest['totalInterest']),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold, 
                                            fontSize: 16, 
                                            color: debt.isPaid ? Colors.grey.shade600 : Colors.red,
                                            decoration: debt.isPaid ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      debt.isPaid ? 'Tổng đã trả:' : 'Tổng phải trả:', 
                                      style: TextStyle(color: Colors.grey.shade600)
                                    ),
                                    Text(
                                      currencyFormat.format(debt.amount + interest['totalInterest']!),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 18, 
                                        color: debt.isPaid ? Colors.blue.shade700 : Colors.green
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(BuildContext context, OvertimeProvider provider, NumberFormat format) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange.shade600,
            Colors.deepOrange.shade700,
            Colors.red.shade800,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.deepOrange.withOpacity(0.4),
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
              const Text(
                'Tổng tiền lãi tích lũy',
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Realtime',
                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            format.format(provider.totalDebtInterest),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _buildMiniStat('Số khoản nợ', provider.debtEntries.length.toString(), Icons.receipt_long),
              const SizedBox(width: 32),
              _buildMiniStat('Tổng gốc', format.format(provider.totalDebtAmount), Icons.account_balance_wallet),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
          ],
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, OvertimeProvider provider, int id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa khoản nợ?'),
        content: const Text('Bạn có chắc chắn muốn xóa khoản nợ này không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          TextButton(
            onPressed: () {
              provider.deleteDebtEntry(id);
              Navigator.pop(context);
            },
            child: const Text('Xóa', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
