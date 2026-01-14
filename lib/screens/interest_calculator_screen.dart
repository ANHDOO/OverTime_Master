import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

class InterestCalculatorScreen extends StatefulWidget {
  const InterestCalculatorScreen({super.key});

  @override
  State<InterestCalculatorScreen> createState() => _InterestCalculatorScreenState();
}

class _InterestCalculatorScreenState extends State<InterestCalculatorScreen> {
  final TextEditingController _amountController = TextEditingController();
  DateTime _selectedMonth = DateTime.now();
  
  double _baseInterest = 0;
  double _extraInterest = 0;
  double _totalInterest = 0;
  int _daysLate = 0;
  bool _hasCalculated = false;

  final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _calculateInterest() {
    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white),
              const SizedBox(width: 12),
              const Text('Vui lòng nhập số tiền nợ lương hợp lệ'),
            ],
          ),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
      );
      return;
    }

    final now = DateTime.now();
    final dueDate = DateTime(_selectedMonth.year, _selectedMonth.month, 20);
    final interestStartDate = DateTime(_selectedMonth.year, _selectedMonth.month, 5);

    setState(() {
      _baseInterest = 0;
      _extraInterest = 0;
      _daysLate = 0;

      if (now.isAfter(interestStartDate)) {
        _baseInterest = amount * 0.015;
      }

      if (now.isAfter(dueDate)) {
        _daysLate = now.difference(dueDate).inDays;
        _extraInterest = amount * 0.001 * _daysLate;
      }

      _totalInterest = _baseInterest + _extraInterest;
      _hasCalculated = true;
    });
  }

  void _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Chọn tháng lương bị nợ',
      locale: const Locale('vi', 'VN'),
    );
    if (picked != null) {
      setState(() {
        _selectedMonth = picked;
        _hasCalculated = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(title: const Text('Tính lãi nợ lương')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(isDark),
            const SizedBox(height: 24),

            _buildSectionTitle('Tháng lương bị nợ', isDark),
            const SizedBox(height: 12),
            _buildMonthSelector(isDark),
            const SizedBox(height: 24),

            _buildSectionTitle('Số tiền công ty còn nợ (VNĐ)', isDark),
            const SizedBox(height: 12),
            _buildAmountInput(isDark),
            const SizedBox(height: 28),

            _buildCalculateButton(isDark),
            const SizedBox(height: 24),

            if (_hasCalculated) _buildResults(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
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
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.2),
              borderRadius: AppRadius.borderSm,
            ),
            child: Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quy định lãi suất nợ lương',
                  style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.w600, fontSize: 14),
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

  Widget _buildMonthSelector(bool isDark) {
    return GestureDetector(
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
    );
  }

  Widget _buildAmountInput(bool isDark) {
    return TextField(
      controller: _amountController,
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      decoration: InputDecoration(
        hintText: 'Ví dụ: 5,000,000',
        hintStyle: TextStyle(color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.accent, width: 2),
        ),
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.accent.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(Icons.payments_rounded, color: AppColors.accent, size: 20),
        ),
      ),
    );
  }

  Widget _buildCalculateButton(bool isDark) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.heroOrange,
        borderRadius: AppRadius.borderMd,
        boxShadow: AppShadows.heroOrangeLight,
      ),
      child: ElevatedButton(
        onPressed: _calculateInterest,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.calculate_rounded, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            const Text(
              'Tính toán lãi suất',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.heroBlue,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroLight,
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.08)),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05)),
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
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Kết quả tính toán',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
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
                      _buildResultRow('Lãi cơ bản (1.5%)', currencyFormat.format(_baseInterest), 'Từ ngày 5 đến ngày 20'),
                      Divider(color: Colors.white.withOpacity(0.2), height: 24),
                      _buildResultRow(
                        'Lãi thêm (0.1%/ngày)',
                        currencyFormat.format(_extraInterest),
                        _daysLate > 0 ? 'Quá hạn $_daysLate ngày' : 'Chưa quá ngày 20',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Tổng tiền lãi', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text(
                      currencyFormat.format(_totalInterest),
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: AppRadius.borderMd,
                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'TỔNG CÔNG TY CẦN TRẢ',
                        style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormat.format(amount + _totalInterest),
                        style: TextStyle(color: AppColors.successLight, fontSize: 28, fontWeight: FontWeight.w700),
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

  Widget _buildResultRow(String title, String amount, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(title, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            Text(amount, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: AppRadius.borderFull,
          ),
          child: Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ),
      ],
    );
  }
}
