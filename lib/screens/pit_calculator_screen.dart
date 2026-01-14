import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/overtime_provider.dart';
import '../theme/app_theme.dart';

class PITCalculatorTab extends StatefulWidget {
  const PITCalculatorTab({super.key});

  @override
  State<PITCalculatorTab> createState() => _PITCalculatorTabState();
}

class _PITCalculatorTabState extends State<PITCalculatorTab> {
  final TextEditingController _salaryController = TextEditingController();
  final TextEditingController _dependentsController = TextEditingController(text: '0');
  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  
  double _grossSalary = 0;
  int _dependents = 0;
  final double _insuranceRate = 0.105;
  
  final double _personalDeduction = 15500000;
  final double _dependentDeduction = 6200000;

  void _calculate() {
    setState(() {
      _grossSalary = double.tryParse(_salaryController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      _dependents = int.tryParse(_dependentsController.text) ?? 0;
    });
  }

  Map<String, double> _calculateTax() {
    double insurance = _grossSalary * _insuranceRate;
    double totalDeduction = _personalDeduction + (_dependents * _dependentDeduction);
    double taxableIncome = _grossSalary - insurance - totalDeduction;
    if (taxableIncome < 0) taxableIncome = 0;

    double tax = 0;
    List<Map<String, dynamic>> brackets = [
      {'limit': 10000000.0, 'rate': 0.05},
      {'limit': 30000000.0, 'rate': 0.10},
      {'limit': 60000000.0, 'rate': 0.20},
      {'limit': 100000000.0, 'rate': 0.30},
      {'limit': double.infinity, 'rate': 0.35},
    ];

    double previousLimit = 0.0;

    for (var bracket in brackets) {
      double limit = (bracket['limit'] as num).toDouble();
      double rate = (bracket['rate'] as num).toDouble();
      
      if (taxableIncome > previousLimit) {
        double incomeInBracket = (taxableIncome > limit ? limit : taxableIncome) - previousLimit;
        double bracketTax = incomeInBracket * rate;
        tax += bracketTax;
        previousLimit = limit;
      } else {
        break;
      }
    }

    return {
      'insurance': insurance,
      'deduction': totalDeduction,
      'taxable': taxableIncome,
      'tax': tax,
      'net': _grossSalary - insurance - tax,
    };
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);
    final results = _calculateTax();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImportSection(provider, currencyFormat, isDark),
              const SizedBox(height: 20),
              _buildInputCard(isDark),
              const SizedBox(height: 24),
              _buildSectionTitle('Kết quả tính toán (2026)', isDark),
              const SizedBox(height: 16),
              _buildResultCard(results, currencyFormat, isDark),
              const SizedBox(height: 24),
              _buildTaxBracketsInfo(currencyFormat, isDark),
              const SizedBox(height: 80),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
      ),
    );
  }

  Widget _buildImportSection(OvertimeProvider provider, NumberFormat format, bool isDark) {
    final now = DateTime.now();
    final availableMonths = List.generate(12, (i) => DateTime(now.year, now.month - i));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: isDark 
            ? LinearGradient(colors: [AppColors.indigoPrimary.withOpacity(0.15), AppColors.indigoDark.withOpacity(0.1)])
            : LinearGradient(colors: [AppColors.indigoPrimary.withOpacity(0.08), AppColors.indigoDark.withOpacity(0.05)]),
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: AppColors.indigoPrimary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AppGradients.heroIndigo,
                  borderRadius: AppRadius.borderSm,
                ),
                child: const Icon(Icons.cloud_download_rounded, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                'Lấy lương từ dữ liệu thực tế',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.indigoPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.lightCard,
                    borderRadius: AppRadius.borderSm,
                    border: Border.all(color: AppColors.indigoPrimary.withOpacity(0.3)),
                  ),
                  child: DropdownButton<DateTime>(
                    value: _selectedMonth,
                    isExpanded: true,
                    underline: const SizedBox(),
                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.indigoPrimary),
                    items: availableMonths.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(
                          DateFormat('MM/yyyy').format(m),
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedMonth = val);
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: AppGradients.heroIndigo,
                  borderRadius: AppRadius.borderSm,
                  boxShadow: AppShadows.heroIndigoLight,
                ),
                child: ElevatedButton.icon(
                  onPressed: () {
                    final totalIncome = provider.getTotalIncomeForMonth(_selectedMonth.year, _selectedMonth.month);
                    setState(() {
                      _salaryController.text = format.format(totalIncome).replaceAll('₫', '').trim();
                      _calculate();
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle_rounded, color: Colors.white),
                            const SizedBox(width: 12),
                            Text('Đã lấy dữ liệu tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}'),
                          ],
                        ),
                        backgroundColor: AppColors.success,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
                      ),
                    );
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Lấy dữ liệu'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderXl,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        boxShadow: isDark ? AppShadows.cardDark : AppShadows.cardLight,
      ),
      child: Column(
        children: [
          _buildInputField(
            controller: _salaryController,
            label: 'Lương Gross (VNĐ)',
            hint: 'Nhập lương chưa trừ thuế',
            icon: Icons.payments_rounded,
            isDark: isDark,
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _dependentsController,
            label: 'Số người phụ thuộc',
            hint: 'Nhập số lượng',
            icon: Icons.people_rounded,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      style: TextStyle(
        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Container(
          margin: const EdgeInsets.all(8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.indigoPrimary.withOpacity(isDark ? 0.2 : 0.1),
            borderRadius: AppRadius.borderSm,
          ),
          child: Icon(icon, color: AppColors.indigoPrimary, size: 20),
        ),
        filled: true,
        fillColor: isDark ? AppColors.darkSurfaceVariant.withOpacity(0.5) : AppColors.lightSurfaceVariant,
        border: OutlineInputBorder(borderRadius: AppRadius.borderMd, borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.borderMd,
          borderSide: BorderSide(color: AppColors.indigoPrimary, width: 2),
        ),
      ),
      onChanged: (_) => _calculate(),
    );
  }

  Widget _buildResultCard(Map<String, double> results, NumberFormat format, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.heroIndigo,
        borderRadius: AppRadius.borderXl,
        boxShadow: AppShadows.heroIndigoLight,
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: AppRadius.borderSm,
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'LƯƠNG NET THỰC NHẬN',
                          style: TextStyle(color: Colors.white60, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
                        ),
                        Text(
                          format.format(results['net']),
                          style: TextStyle(
                            color: AppColors.successLight,
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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
                      _buildResultRow('Bảo hiểm (10.5%)', format.format(results['insurance'])),
                      const SizedBox(height: 8),
                      _buildResultRow('Giảm trừ gia cảnh', format.format(results['deduction'])),
                      const SizedBox(height: 8),
                      _buildResultRow('Thu nhập tính thuế', format.format(results['taxable'])),
                      Divider(color: Colors.white.withOpacity(0.2), height: 20),
                      _buildResultRow('Thuế TNCN phải nộp', format.format(results['tax']), isHighlight: true),
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

  Widget _buildResultRow(String label, String value, {bool isHighlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        Text(
          value,
          style: TextStyle(
            color: isHighlight ? AppColors.accent : Colors.white,
            fontSize: isHighlight ? 16 : 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildTaxBracketsInfo(NumberFormat format, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.lightCard,
        borderRadius: AppRadius.borderLg,
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted),
              const SizedBox(width: 8),
              Text(
                'Biểu thuế lũy tiến 2026 (5 bậc)',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildBracketRow('Đến 10tr', '5%', isDark),
          _buildBracketRow('10tr - 30tr', '10%', isDark),
          _buildBracketRow('30tr - 60tr', '20%', isDark),
          _buildBracketRow('60tr - 100tr', '30%', isDark),
          _buildBracketRow('Trên 100tr', '35%', isDark),
          Divider(color: isDark ? AppColors.darkBorder : AppColors.lightBorder, height: 20),
          Row(
            children: [
              Icon(Icons.person_rounded, size: 14, color: AppColors.indigoPrimary),
              const SizedBox(width: 6),
              Text(
                'Giảm trừ bản thân: ${format.format(_personalDeduction)}',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(Icons.people_rounded, size: 14, color: AppColors.indigoPrimary),
              const SizedBox(width: 6),
              Text(
                'Giảm trừ NPT: ${format.format(_dependentDeduction)}/người',
                style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBracketRow(String range, String rate, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(range, style: TextStyle(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.indigoPrimary.withOpacity(isDark ? 0.2 : 0.1),
              borderRadius: AppRadius.borderFull,
            ),
            child: Text(rate, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.indigoPrimary)),
          ),
        ],
      ),
    );
  }
}
