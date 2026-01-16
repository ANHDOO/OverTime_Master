import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../logic/providers/overtime_provider.dart';
import '../widgets/side_menu.dart';
import '../../core/theme/app_theme.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
    double finalSalary = provider.calculateFinalSalaryForMonth(_selectedMonth.year, _selectedMonth.month);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('DỰ TOÁN LƯƠNG', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.5, color: Colors.white)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left, color: Colors.white),
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
                builder: (context, child) => Theme(
                  data: Theme.of(context).copyWith(
                    colorScheme: isDark ? const ColorScheme.dark(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.darkSurface, onSurface: Colors.white) : const ColorScheme.light(primary: AppColors.primary),
                  ),
                  child: child!,
                ),
              );
              if (date != null) {
                setState(() => _selectedMonth = date);
              }
            },
            child: Text(
              DateFormat('MM/yyyy').format(_selectedMonth),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right, color: Colors.white),
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
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(_selectedMonth, finalSalary, isDark),
            const SizedBox(height: 32),
            _buildSectionTitle('1. LƯƠNG CƠ BẢN & TĂNG CA', isDark),
            _buildTable([
              _buildRow('1.1 Số công làm việc (Lương chính)', baseSalary, isDark),
              _buildRow('1.3 Trách nhiệm', provider.responsibilityAllowance, isDark),
              _buildRow('1.4 Chuyên cần', provider.diligenceAllowance, isDark),
              _buildRow(
                '1.5 Tăng ca tối (x1.5)', 
                pay15, 
                isDark,
                subtitle: '${hours15.toStringAsFixed(1)}h × ${currencyFormat.format(hourlyRate)} × 1.5'
              ),
              _buildRow(
                '1.6 Tăng ca đêm (x1.8)', 
                pay18, 
                isDark,
                subtitle: '${hours18.toStringAsFixed(1)}h × ${currencyFormat.format(hourlyRate)} × 1.8'
              ),
              _buildRow(
                '1.7 Tăng ca Chủ nhật (x2.0)', 
                pay20, 
                isDark,
                subtitle: '${hours20.toStringAsFixed(1)}h × ${currencyFormat.format(hourlyRate)} × 2.0'
              ),
              _buildSubTotalRow('Tổng cộng (1)', section1Total, isDark),
            ], isDark),
            const SizedBox(height: 28),
            _buildSectionTitle('2. PHỤ CẤP', isDark),
            _buildTable([
              _buildRow('2.1 Xăng (km)', gasolinePay, isDark),
              _buildRow('2.2 Tiền mạng', internetPay, isDark),
              _buildRow('2.3 Công tác', businessTripPay, isDark, isEditable: true, onTap: _showBusinessTripDialog),
              _buildSubTotalRow('Tổng cộng (2)', section2Total, isDark),
            ], isDark),
            const SizedBox(height: 28),
            _buildTotalRow('TỔNG LƯƠNG (1+2)', totalGrossSalary, isDark, isPrimary: false),
            const SizedBox(height: 28),
            _buildSectionTitle('3. CÁC KHOẢN TRỪ', isDark),
            _buildTable([
              _buildRow('3.1 Bảo hiểm', provider.bhxhDeduction, isDark, isNegative: true),
              _buildRow('3.2 Tạm ứng', provider.advancePayment, isDark, isNegative: true, isEditable: true, onTap: _showAdvancePaymentDialog),
              _buildSubTotalRow('Tổng cộng (3)', section3Total, isDark, isNegative: true),
            ], isDark),
            const SizedBox(height: 36),
            _buildTotalRow('LƯƠNG THỰC HƯỞNG (1+2-3)', finalSalary, isDark, isPrimary: true),
            const SizedBox(height: 16),
            Center(
              child: Text(
                '* Đơn giá giờ đang tính: ${currencyFormat.format(hourlyRate)}/h',
                style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontStyle: FontStyle.italic),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(DateTime month, double amount, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        gradient: AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'Dự toán tháng ${DateFormat('MM/yyyy').format(month)}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 15, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          Text(
            currencyFormat.format(amount),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14, left: 4),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: AppRadius.borderFull),
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<Widget> rows, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? null : AppShadows.cardLight,
      ),
      child: Column(children: rows),
    );
  }

  Widget _buildRow(String label, double value, bool isDark, {String? subtitle, bool isNegative = false, bool isEditable = false, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.borderLg,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder.withValues(alpha: 0.5))),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary, fontWeight: FontWeight.w600, fontSize: 13.5),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        subtitle,
                        style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
            if (isEditable) Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
            ),
            Text(
              '${isNegative ? "-" : ""}${currencyFormat.format(value)}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: isNegative ? AppColors.danger : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTotalRow(String label, double value, bool isDark, {bool isNegative = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.primary.withValues(alpha: 0.1) : AppColors.primary.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.primary, fontWeight: FontWeight.w800, fontSize: 14),
            ),
          ),
          Text(
            '${isNegative ? "-" : ""}${currencyFormat.format(value)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isNegative ? AppColors.danger : (isDark ? AppColors.darkTextPrimary : AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double value, bool isDark, {bool isPrimary = true}) {
    final Color color = isPrimary ? AppColors.success : AppColors.primary;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.darkTextPrimary : color,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            currencyFormat.format(value),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : color,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdvancePaymentDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    final controller = TextEditingController(text: provider.advancePayment.toInt().toString());
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        title: Text('Nhập tiền Tạm ứng', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          decoration: InputDecoration(
            labelText: 'Số tiền (VNĐ)',
            labelStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
            hintText: 'Ví dụ: 2000000',
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primary)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Hủy', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text) ?? 0.0;
              provider.updateAdvancePayment(amount);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBusinessTripDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<OvertimeProvider>();
    DateTime? start = provider.businessTripStart;
    DateTime? end = provider.businessTripEnd;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          title: Text('Cấu hình Công tác', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontWeight: FontWeight.w800)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Ngày bắt đầu', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(start != null ? DateFormat('dd/MM/yyyy').format(start!) : 'Chưa chọn', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                trailing: Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: start ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: isDark ? const ColorScheme.dark(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.darkSurface, onSurface: Colors.white) : const ColorScheme.light(primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) setDialogState(() => start = date);
                },
              ),
              ListTile(
                title: Text('Ngày kết thúc', style: TextStyle(color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: Text(end != null ? DateFormat('dd/MM/yyyy').format(end!) : 'Chưa chọn', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
                trailing: Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: end ?? start ?? DateTime.now(),
                    firstDate: start ?? DateTime(2020),
                    lastDate: DateTime(2030),
                    builder: (context, child) => Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: isDark ? const ColorScheme.dark(primary: AppColors.primary, onPrimary: Colors.white, surface: AppColors.darkSurface, onSurface: Colors.white) : const ColorScheme.light(primary: AppColors.primary),
                      ),
                      child: child!,
                    ),
                  );
                  if (date != null) setDialogState(() => end = date);
                },
              ),
              if (start != null && end != null)
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: AppRadius.borderFull),
                    child: Text(
                      'Số ngày: ${end!.difference(start!).inDays + 1} ngày',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13),
                    ),
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
              child: const Text('Xoá', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Huỷ', style: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                provider.updateBusinessTripDates(start, end);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
              child: const Text('Lưu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
