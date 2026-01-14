import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/overtime_provider.dart';
import '../widgets/smart_money_input.dart';
import '../theme/app_theme.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt mức lương'),
      ),
      body: Consumer<OvertimeProvider>(
        builder: (context, provider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('Cách tính lương', isDark),
                const SizedBox(height: 12),
                _buildMethodToggle(isDark),
                const SizedBox(height: 28),
                
                if (_useMonthlySalary) ...[
                  // Total Salary
                  _buildInputSection(
                    title: 'Lương tổng theo hợp đồng',
                    controller: _totalSalaryController,
                    hint: 'Ví dụ: 18,000,000',
                    icon: Icons.account_balance_wallet_rounded,
                    isDark: isDark,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  
                  // Fixed Allowance
                  _buildInputSection(
                    title: 'Phụ cấp cố định',
                    subtitle: 'Trách nhiệm + Chuyên cần',
                    controller: _allowanceController,
                    hint: 'Ví dụ: 945,000',
                    icon: Icons.card_giftcard_rounded,
                    isDark: isDark,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 20),
                  
                  // Leave Days
                  _buildInputSection(
                    title: 'Số ngày nghỉ trong tháng',
                    subtitle: 'Nghỉ không lương hoặc trừ phép năm',
                    controller: _leaveDaysController,
                    hint: '0',
                    icon: Icons.event_busy_rounded,
                    isDark: isDark,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 28),
                  
                  // Calculation Summary
                  _buildCalculationSummary(provider, isDark),
                  
                ] else ...[
                  _buildInputSection(
                    title: 'Lương cơ bản theo giờ',
                    subtitle: 'Đơn vị: VNĐ/h',
                    controller: _rateController,
                    hint: 'Ví dụ: 85,000',
                    icon: Icons.schedule_rounded,
                    isDark: isDark,
                  ),
                ],
                
                const SizedBox(height: 40),
                _buildSaveButton(provider, isDark),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildMethodToggle(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: AppRadius.borderMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton('Theo tháng', _useMonthlySalary, isDark, () {
              setState(() => _useMonthlySalary = true);
            }),
          ),
          Expanded(
            child: _buildToggleButton('Nhập thủ công', !_useMonthlySalary, isDark, () {
              setState(() => _useMonthlySalary = false);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, bool isDark, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected 
              ? (isDark ? AppGradients.heroBlueDark : AppGradients.heroBlue)
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: AppRadius.borderSm,
          boxShadow: isSelected ? [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected 
                ? Colors.white 
                : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildInputSection({
    required String title,
    String? subtitle,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    ValueChanged<double>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(isDark ? 0.2 : 0.1),
                borderRadius: AppRadius.borderSm,
              ),
              child: Icon(icon, color: AppColors.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SmartMoneyInput(
          key: ValueKey(controller.hashCode),
          controller: controller,
          onChanged: onChanged,
          label: hint,
        ),
      ],
    );
  }

  Widget _buildCalculationSummary(OvertimeProvider provider, bool isDark) {
    final totalSalary = double.tryParse(_totalSalaryController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    final allowance = double.tryParse(_allowanceController.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
    final leaveDays = int.tryParse(_leaveDaysController.text) ?? 0;
    final baseSalary = totalSalary - allowance;
    final workingDays = provider.getWorkingDaysInMonth();
    final actualWorkingDays = workingDays - leaveDays;
    final hourlyRate = _calculateHourlyRate(provider);

    return Container(
      decoration: BoxDecoration(
        gradient: isDark ? AppGradients.heroBlueDark : AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: isDark ? AppShadows.heroDark : AppShadows.heroLight,
      ),
      child: Stack(
        children: [
          // Decorative elements
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(Icons.calculate_rounded, color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Tổng kết tính lương',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Lương hợp đồng', currencyFormat.format(totalSalary)),
                      _buildSummaryRow('Phụ cấp cố định', '- ${currencyFormat.format(allowance)}'),
                      Divider(color: Colors.white.withOpacity(0.2), height: 16),
                      _buildSummaryRow('Lương cơ bản (OT)', currencyFormat.format(baseSalary), highlight: true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 12),
                
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: AppRadius.borderMd,
                  ),
                  child: Column(
                    children: [
                      _buildSummaryRow('Ngày công tháng', '$workingDays ngày'),
                      _buildSummaryRow('Ngày nghỉ', '$leaveDays ngày'),
                      Divider(color: Colors.white.withOpacity(0.2), height: 16),
                      _buildSummaryRow('Ngày làm thực tế', '$actualWorkingDays ngày', highlight: true),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'LƯƠNG THEO GIỜ',
                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        currencyFormat.format(hourlyRate),
                        style: TextStyle(
                          color: AppColors.successLight,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: AppRadius.borderFull,
                        ),
                        child: Text(
                          '${currencyFormat.format(baseSalary)} ÷ $actualWorkingDays ÷ 8',
                          style: const TextStyle(color: Colors.white54, fontSize: 10),
                        ),
                      ),
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

  Widget _buildSummaryRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: highlight ? Colors.white : Colors.white70,
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: highlight ? 15 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(OvertimeProvider provider, bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.heroBlue,
        borderRadius: AppRadius.borderMd,
        boxShadow: AppShadows.buttonLight,
      ),
      child: ElevatedButton(
        onPressed: () => _saveSettings(provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.save_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            const Text(
              'Lưu cài đặt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
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
          SnackBar(
            content: const Text('Vui lòng kiểm tra lại thông tin nhập'),
            backgroundColor: AppColors.danger,
          ),
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
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.success,
      ),
    );
    Navigator.pop(context);
  }
}
