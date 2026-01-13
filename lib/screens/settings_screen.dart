import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/overtime_provider.dart';
import '../widgets/smart_money_input.dart';
import '../services/update_service.dart';
import '../services/notification_service.dart';
import '../services/google_sheets_service.dart';
import 'settings/update_screen.dart';
import 'settings/notifications_screen.dart';
import 'settings/google_sheets_screen.dart';
import 'settings/backup_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _rateController;
  late TextEditingController _totalSalaryController;
  late TextEditingController _allowanceController;
  late TextEditingController _leaveDaysController;
  bool _useMonthlySalary = true;
  
  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    _rateController = TextEditingController(text: provider.hourlyRate.toStringAsFixed(0));
    _totalSalaryController = TextEditingController(
        text: provider.monthlySalary != null && provider.monthlySalary! > 0 
            ? provider.monthlySalary!.toStringAsFixed(0) 
            : '15000000');
    _allowanceController = TextEditingController(text: provider.allowance.toStringAsFixed(0));
    _leaveDaysController = TextEditingController(text: provider.leaveDays.toString());
    _useMonthlySalary = provider.monthlySalary == null || provider.monthlySalary! >= 0;
  }

  @override
  void dispose() {
    _rateController.dispose();
    _totalSalaryController.dispose();
    _allowanceController.dispose();
    _leaveDaysController.dispose();
    super.dispose();
  }

  double _calculateHourlyRate(OvertimeProvider provider) {
    final totalSalary = double.tryParse(_totalSalaryController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    final allowance = double.tryParse(_allowanceController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    final leaveDays = int.tryParse(_leaveDaysController.text) ?? 0;
    
    final baseSalary = totalSalary - allowance;
    final workingDays = provider.getWorkingDaysInMonth();
    final actualWorkingDays = workingDays - leaveDays;
    
    if (actualWorkingDays <= 0) return 0;
    return baseSalary / actualWorkingDays / 8;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt mức lương'),
      ),
      body: Consumer<OvertimeProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Cách tính lương'),
                const SizedBox(height: 12),
                _buildMethodToggle(),
                const SizedBox(height: 24),
                
                if (_useMonthlySalary) ...[
                  // Total Salary
                  _buildSectionTitle('Lương tổng theo hợp đồng'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _totalSalaryController,
                    hint: 'Ví dụ: 18000000',
                    icon: Icons.account_balance_wallet,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  
                  // Fixed Allowance
                  _buildSectionTitle('Phụ cấp cố định (Trách nhiệm + Chuyên cần)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _allowanceController,
                    hint: 'Ví dụ: 945000',
                    icon: Icons.card_giftcard,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 16),
                  
                  // Leave Days
                  _buildSectionTitle('Số ngày nghỉ trong tháng'),
                  const SizedBox(height: 4),
                  Text(
                    'Nghỉ không lương hoặc nghỉ trừ phép năm',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _leaveDaysController,
                    hint: '0',
                    icon: Icons.event_busy,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 24),
                  
                  // Calculation Summary
                  _buildCalculationSummary(provider),
                  
                ] else ...[
                  _buildSectionTitle('Lương cơ bản theo giờ (VNĐ/h)'),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: _rateController,
                    hint: 'Ví dụ: 85000',
                    icon: Icons.timer,
                  ),
                ],
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _saveSettings(provider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    child: const Text('Lưu cài đặt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCalculationSummary(OvertimeProvider provider) {
    final totalSalary = double.tryParse(_totalSalaryController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    final allowance = double.tryParse(_allowanceController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    final leaveDays = int.tryParse(_leaveDaysController.text) ?? 0;
    final baseSalary = totalSalary - allowance;
    final workingDays = provider.getWorkingDaysInMonth();
    final actualWorkingDays = workingDays - leaveDays;
    final hourlyRate = _calculateHourlyRate(provider);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tổng kết tính lương',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(color: Colors.white24, height: 24),
          _buildSummaryRow('Lương tổng hợp đồng', currencyFormat.format(totalSalary)),
          _buildSummaryRow('Trừ phụ cấp cố định', '- ${currencyFormat.format(allowance)}'),
          _buildSummaryRow('Lương cơ bản (để tính OT)', currencyFormat.format(baseSalary)),
          const Divider(color: Colors.white24, height: 24),
          _buildSummaryRow('Số ngày công tháng này', '$workingDays ngày'),
          _buildSummaryRow('Số ngày nghỉ', '$leaveDays ngày'),
          _buildSummaryRow('Số ngày làm thực tế', '$actualWorkingDays ngày'),
          const Divider(color: Colors.white24, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('LƯƠNG/GIỜ', style: TextStyle(color: Colors.white70, fontSize: 14)),
              Text(
                currencyFormat.format(hourlyRate),
                style: const TextStyle(color: Colors.greenAccent, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Công thức: ${currencyFormat.format(baseSalary)} ÷ $actualWorkingDays ÷ 8',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 13)),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildMethodToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton('Theo tháng', _useMonthlySalary, () {
              setState(() => _useMonthlySalary = true);
            }),
          ),
          Expanded(
            child: _buildToggleButton('Nhập thủ công', !_useMonthlySalary, () {
              setState(() => _useMonthlySalary = false);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade600,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    ValueChanged<double>? onChanged,
  }) {
    return SmartMoneyInput(
      key: ValueKey(controller.hashCode),
      controller: controller,
      onChanged: onChanged,
      label: hint,
    );
  }

  void _saveSettings(OvertimeProvider provider) async {
    if (_useMonthlySalary) {
      final hourlyRate = _calculateHourlyRate(provider);
      if (hourlyRate > 0) {
        final totalSalary = double.tryParse(_totalSalaryController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
        final allowance = double.tryParse(_allowanceController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
        final leaveDays = int.tryParse(_leaveDaysController.text) ?? 0;
        
        await provider.saveSalarySettings(
          totalSalary: totalSalary,
          allowance: allowance,
          leaveDays: leaveDays,
          hourlyRate: hourlyRate,
        );
        _showSuccess('Đã cập nhật lương và tính lại tất cả thẻ OT!');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Vui lòng kiểm tra lại thông tin nhập')),
        );
      }
    } else {
      final rate = double.tryParse(_rateController.text.replaceAll(',', '').replaceAll('.', ''));
      if (rate != null && rate > 0) {
        await provider.saveSalarySettings(
          totalSalary: 0,
          allowance: 0,
          leaveDays: 0,
          hourlyRate: rate,
        );
        _showSuccess('Đã cập nhật lương/giờ và tính lại tất cả thẻ OT!');
      }
    }
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
    Navigator.pop(context);
  }
}
