import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../widgets/side_menu.dart';
import 'main_screen.dart';

class SalaryEstimationScreen extends StatefulWidget {
  const SalaryEstimationScreen({super.key});

  @override
  State<SalaryEstimationScreen> createState() => _SalaryEstimationScreenState();
}

class _SalaryEstimationScreenState extends State<SalaryEstimationScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OvertimeProvider>();
    final monthEntries = provider.entries.where((e) => 
      e.date.month == _selectedMonth.month && e.date.year == _selectedMonth.year
    ).toList();

    // OT Breakdown
    double hours15 = monthEntries.fold(0, (sum, e) => sum + e.hours15);
    double hours18 = monthEntries.fold(0, (sum, e) => sum + e.hours18);
    double hours20 = monthEntries.fold(0, (sum, e) => sum + e.hours20);
    
    double hourlyRate = provider.getHourlyRateForMonth(_selectedMonth.year, _selectedMonth.month);
    double pay15 = hours15 * hourlyRate * 1.5;
    double pay18 = hours18 * hourlyRate * 1.8;
    double pay20 = hours20 * hourlyRate * 2.0;
    double totalOT = pay15 + pay18 + pay20;

    // Logic: Lương chính = monthlySalary - Responsibility - Diligence
    double baseSalary = (provider.monthlySalary ?? 0) - 
                        provider.responsibilityAllowance - provider.diligenceAllowance;
    
    double businessTripPay = provider.calculateBusinessTripPayForMonth(_selectedMonth.year, _selectedMonth.month);
    bool isOnTrip = provider.isOnBusinessTripInMonth(_selectedMonth.year, _selectedMonth.month);
    double internetPay = isOnTrip ? 120000.0 : 0.0;
    
    // Logic: Xăng xe = 100k nếu không đi công tác, ngược lại = 0
    double gasolinePay = isOnTrip ? 0.0 : 100000.0;
    
    // Sub-totals
    double section1Total = baseSalary + provider.responsibilityAllowance + provider.diligenceAllowance + totalOT;
    double section2Total = gasolinePay + businessTripPay + internetPay;
    double totalGrossSalary = section1Total + section2Total; // TỔNG LƯƠNG (1+2)
    double section3Total = provider.bhxhDeduction + provider.advancePayment; // CÁC KHOẢN TRỪ

    // Final Salary = (1+2) - 3
    double finalSalary = totalGrossSalary - section3Total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('DỰ TOÁN LƯƠNG'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
              });
            },
          ),
          TextButton(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedMonth,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (date != null) {
                setState(() => _selectedMonth = date);
              }
            },
            child: Text(
              DateFormat('MM/yyyy').format(_selectedMonth),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
              });
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: SideMenu(
        onSelectTab: (index) {
          if (mounted) {
            Navigator.of(context).pop();
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => MainScreen(initialIndex: index)),
              (route) => false,
            );
          }
        },
        selectedIndex: -1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(_selectedMonth, finalSalary),
            const SizedBox(height: 24),
            _buildSectionTitle('1. LƯƠNG'),
            _buildTable([
              _buildRow('1.1 Số công làm việc (Lương chính)', baseSalary),
              _buildRow('1.3 Trách nhiệm', provider.responsibilityAllowance),
              _buildRow('1.4 Chuyên cần', provider.diligenceAllowance),
              _buildRow(
                '1.5 Tăng ca tối (x1.5)', 
                pay15, 
                subtitle: '${hours15.toStringAsFixed(1)}h × ${currencyFormat.format(hourlyRate)} × 1.5'
              ),
              _buildRow(
                '1.6 Tăng ca đêm (x1.8)', 
                pay18, 
                subtitle: '${hours18.toStringAsFixed(1)}h × ${currencyFormat.format(hourlyRate)} × 1.8'
              ),
              _buildRow(
                '1.7 Tăng ca Chủ nhật (x2.0)', 
                pay20, 
                subtitle: '${hours20.toStringAsFixed(1)}h × ${currencyFormat.format(hourlyRate)} × 2.0'
              ),
              _buildSubTotalRow('Tổng cộng', section1Total),
            ]),
            const SizedBox(height: 24),
            _buildSectionTitle('2. PHỤ CẤP'),
            _buildTable([
              _buildRow('2.1 Xăng (km)', gasolinePay),
              _buildRow('2.2 Tiền mạng', internetPay),
              _buildRow('2.3 Công tác', businessTripPay, isEditable: true, onTap: _showBusinessTripDialog),
              _buildSubTotalRow('Tổng cộng', section2Total),
            ]),
            const SizedBox(height: 24),
            _buildTotalRow('TỔNG LƯƠNG (1+2)', totalGrossSalary, isPrimary: false),
            const SizedBox(height: 24),
            _buildSectionTitle('3. CÁC KHOẢN TRỪ'),
            _buildTable([
              _buildRow('3.1 Bảo hiểm', provider.bhxhDeduction, isNegative: true),
              _buildRow('3.2 Tạm ứng', provider.advancePayment, isNegative: true, isEditable: true, onTap: _showAdvancePaymentDialog),
              _buildSubTotalRow('Tổng cộng', section3Total, isNegative: true),
            ]),
            const SizedBox(height: 32),
            _buildTotalRow('LƯƠNG THỰC HƯỞNG (1+2-3)', finalSalary, isPrimary: true),
            const SizedBox(height: 12),
            Center(
              child: Text(
                '* Đơn giá giờ đang tính: ${currencyFormat.format(hourlyRate)}/h',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DateTime month, double amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade700, Colors.blue.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Dự toán tháng ${DateFormat('MM/yyyy').format(month)}',
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            currencyFormat.format(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade900,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildTable(List<Widget> rows) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildRow(String label, double value, {String? subtitle, bool isNegative = false, bool isEditable = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                ],
              ),
            ),
            if (isEditable) const Icon(Icons.edit, size: 14, color: Colors.blue),
            const SizedBox(width: 8),
            Text(
              '${isNegative ? "-" : ""}${currencyFormat.format(value)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isNegative ? Colors.red.shade700 : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTotalRow(String label, double value, {bool isNegative = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.03),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Text(
            '${isNegative ? "-" : ""}${currencyFormat.format(value)}',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: isNegative ? Colors.red.shade700 : Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, {bool isPrimary = true}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPrimary ? Colors.green.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPrimary ? Colors.green.shade100 : Colors.blue.shade100),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isPrimary ? Colors.green.shade900 : Colors.blue.shade900,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isPrimary ? Colors.green.shade900 : Colors.blue.shade900,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancePaymentDialog() {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    final controller = TextEditingController(text: provider.advancePayment.toInt().toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nhập tiền Tạm ứng'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Số tiền (VNĐ)',
            hintText: 'Ví dụ: 2000000',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              provider.updateAdvancePayment(amount);
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _showBusinessTripDialog() {
    final provider = context.read<OvertimeProvider>();
    DateTime? start = provider.businessTripStart;
    DateTime? end = provider.businessTripEnd;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cấu hình Công tác'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Ngày bắt đầu'),
                subtitle: Text(start != null ? DateFormat('dd/MM/yyyy').format(start!) : 'Chưa chọn'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: start ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setDialogState(() => start = date);
                },
              ),
              ListTile(
                title: const Text('Ngày kết thúc'),
                subtitle: Text(end != null ? DateFormat('dd/MM/yyyy').format(end!) : 'Chưa chọn'),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: end ?? start ?? DateTime.now(),
                    firstDate: start ?? DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (date != null) setDialogState(() => end = date);
                },
              ),
              if (start != null && end != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Số ngày: ${end!.difference(start!).inDays + 1} ngày',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                  ),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                provider.updateBusinessTripDates(null, null);
                Navigator.pop(context);
              },
              child: const Text('Xoá', style: TextStyle(color: Colors.red)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Huỷ'),
            ),
            ElevatedButton(
              onPressed: () {
                provider.updateBusinessTripDates(start, end);
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
