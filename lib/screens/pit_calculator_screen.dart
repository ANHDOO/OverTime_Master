import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/overtime_provider.dart';

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
  final double _insuranceRate = 0.105; // 10.5% (BHXH, BHYT, BHTN)
  
  // 2026 Regulations
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
    // Capped insurance (approximate for 2026, usually based on base salary)
    // For simplicity, we'll use the rate directly or cap it if needed.
    
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

    debugPrint('--- PIT Calculation Debug ---');
    debugPrint('Gross Salary: $_grossSalary');
    debugPrint('Insurance: $insurance');
    debugPrint('Total Deduction: $totalDeduction');
    debugPrint('Taxable Income: $taxableIncome');

    for (var bracket in brackets) {
      double limit = (bracket['limit'] as num).toDouble();
      double rate = (bracket['rate'] as num).toDouble();
      
      if (taxableIncome > previousLimit) {
        double incomeInBracket = (taxableIncome > limit ? limit : taxableIncome) - previousLimit;
        double bracketTax = incomeInBracket * rate;
        tax += bracketTax;
        
        debugPrint('Bracket [${previousLimit.toStringAsFixed(0)} - ${limit.isInfinite ? "∞" : limit.toStringAsFixed(0)}]: '
            'Income: ${incomeInBracket.toStringAsFixed(0)}, Rate: $rate, Tax: ${bracketTax.toStringAsFixed(0)}');
            
        previousLimit = limit;
      } else {
        break;
      }
    }
    debugPrint('Total Tax: $tax');
    debugPrint('-----------------------------');

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

    return Consumer<OvertimeProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImportSection(provider, currencyFormat),
              const SizedBox(height: 16),
              _buildInputCard(),
              const SizedBox(height: 24),
              const Text(
                'Kết quả tính toán (Dự kiến 2026)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildResultCard(results, currencyFormat),
              const SizedBox(height: 24),
              _buildTaxBracketsInfo(currencyFormat),
            ],
          ),
        );
      },
    );
  }

  Widget _buildImportSection(OvertimeProvider provider, NumberFormat format) {
    // Generate last 12 months
    final now = DateTime.now();
    final availableMonths = List.generate(12, (i) => DateTime(now.year, now.month - i));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lấy lương từ dữ liệu thực tế',
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: DropdownButton<DateTime>(
                    value: _selectedMonth,
                    isExpanded: true,
                    underline: const SizedBox(),
                    items: availableMonths.map((m) {
                      return DropdownMenuItem(
                        value: m,
                        child: Text(DateFormat('MM/yyyy').format(m)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedMonth = val);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () {
                  final totalIncome = provider.getTotalIncomeForMonth(_selectedMonth.year, _selectedMonth.month);
                  setState(() {
                    _salaryController.text = format.format(totalIncome).replaceAll('₫', '').trim();
                    _calculate();
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Đã lấy dữ liệu tháng ${DateFormat('MM/yyyy').format(_selectedMonth)}')),
                  );
                },
                icon: const Icon(Icons.download),
                label: const Text('Lấy dữ liệu'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInputCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          TextField(
            controller: _salaryController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Lương Gross (VNĐ)',
              hintText: 'Nhập lương chưa trừ thuế',
              prefixIcon: Icon(Icons.payments),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculate(),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _dependentsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Số người phụ thuộc',
              hintText: 'Nhập số lượng',
              prefixIcon: Icon(Icons.people),
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => _calculate(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(Map<String, double> results, NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade700, Colors.indigo.shade500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          _buildResultRow('Lương Net thực nhận', format.format(results['net']), isMain: true),
          const Divider(color: Colors.white24, height: 32),
          _buildResultRow('Bảo hiểm (10.5%)', format.format(results['insurance'])),
          _buildResultRow('Giảm trừ gia cảnh', format.format(results['deduction'])),
          _buildResultRow('Thu nhập tính thuế', format.format(results['taxable'])),
          _buildResultRow('Thuế TNCN phải nộp', format.format(results['tax']), isHighlight: true),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {bool isMain = false, bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isMain ? 16 : 14,
              fontWeight: isMain ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isHighlight ? Colors.orangeAccent : Colors.white,
              fontSize: isMain ? 24 : 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaxBracketsInfo(NumberFormat format) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Biểu thuế lũy tiến 2026 (5 bậc):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          _buildBracketRow('Đến 10tr', '5%'),
          _buildBracketRow('10tr - 30tr', '10%'),
          _buildBracketRow('30tr - 60tr', '20%'),
          _buildBracketRow('60tr - 100tr', '30%'),
          _buildBracketRow('Trên 100tr', '35%'),
          const Divider(),
          Text('• Giảm trừ bản thân: ${format.format(_personalDeduction)}', style: const TextStyle(fontSize: 12)),
          Text('• Giảm trừ người phụ thuộc: ${format.format(_dependentDeduction)}/người', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBracketRow(String range, String rate) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(range, style: const TextStyle(fontSize: 12)),
          Text(rate, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
