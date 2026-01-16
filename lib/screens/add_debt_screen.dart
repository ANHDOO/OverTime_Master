import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/overtime_provider.dart';
import '../providers/debt_provider.dart';
import '../widgets/smart_money_input.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AddDebtScreen extends StatefulWidget {
  const AddDebtScreen({super.key});

  @override
  State<AddDebtScreen> createState() => _AddDebtScreenState();
}

class _AddDebtScreenState extends State<AddDebtScreen> {
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedMonth = DateTime.now();
  final _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchEstimatedSalary();
    });
  }

  void _fetchEstimatedSalary() {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    final amount = provider.calculateFinalSalaryForMonth(_selectedMonth.year, _selectedMonth.month);
    if (amount > 0) {
      setState(() {
        _amountController.text = _currencyFormat.format(amount).trim();
      });
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Chọn tháng lương bị nợ',
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = DateTime(picked.year, picked.month, 1);
      });
      _fetchEstimatedSalary();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thêm khoản nợ lương'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Month Selector
            _buildSectionTitle('Tháng lương bị nợ', isDark),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: _selectMonth,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : AppColors.lightCard,
                  borderRadius: AppRadius.borderMd,
                  border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: Icon(Icons.calendar_month_rounded, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Amount Input
            _buildSectionTitle('Số tiền công ty còn nợ (VNĐ)', isDark),
            const SizedBox(height: 12),
            SmartMoneyInput(
              controller: _amountController,
              label: 'Số tiền công ty còn nợ',
              textColor: AppColors.accent,
            ),
            const SizedBox(height: 20),

            // Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.accent.withOpacity(isDark ? 0.15 : 0.1),
                    AppColors.accentDark.withOpacity(isDark ? 0.1 : 0.05),
                  ],
                ),
                borderRadius: AppRadius.borderMd,
                border: Border.all(color: AppColors.accent.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accent.withOpacity(0.2),
                      borderRadius: AppRadius.borderSm,
                    ),
                    child: Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quy định lãi suất',
                          style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '1.5% từ ngày 5 đến 20, thêm 0.1%/ngày sau ngày 20',
                          style: TextStyle(
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // Save Button
            Container(
              decoration: BoxDecoration(
                gradient: AppGradients.heroOrange,
                borderRadius: AppRadius.borderMd,
                boxShadow: AppShadows.heroOrangeLight,
              ),
              child: ElevatedButton(
                onPressed: () async {
                  final cleanAmount = _amountController.text.replaceAll(',', '').replaceAll('.', '');
                  final amount = double.tryParse(cleanAmount);
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            const Text('Vui lòng nhập số tiền hợp lệ'),
                          ],
                        ),
                        backgroundColor: AppColors.danger,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                      ),
                    );
                    return;
                  }

                  final debtProvider = Provider.of<DebtProvider>(context, listen: false);
                  await debtProvider.addDebtEntry(
                    month: _selectedMonth,
                    amount: amount,
                  );
                  if (mounted) Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save_rounded, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    const Text(
                      'Lưu khoản nợ',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
}
