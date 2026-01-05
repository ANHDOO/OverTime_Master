import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/overtime_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _rateController;
  late TextEditingController _salaryController;
  bool _useMonthlySalary = true;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    _rateController = TextEditingController(text: provider.hourlyRate.toStringAsFixed(0));
    _salaryController = TextEditingController(
        text: provider.monthlySalary != null ? provider.monthlySalary!.toStringAsFixed(0) : '');
    _useMonthlySalary = provider.monthlySalary != null && provider.monthlySalary! > 0;
  }

  @override
  void dispose() {
    _rateController.dispose();
    _salaryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt lương'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Cách tính lương'),
            const SizedBox(height: 12),
            _buildMethodToggle(),
            const SizedBox(height: 24),
            if (_useMonthlySalary) ...[
              _buildSectionTitle('Lương tháng chính thức (VNĐ)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _salaryController,
                hint: 'Ví dụ: 18000000',
                icon: Icons.account_balance_wallet,
              ),
              const SizedBox(height: 8),
              const Text(
                '* Hệ thống tự động chia cho 26 ngày công và 8 giờ làm việc mỗi ngày.',
                style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ] else ...[
              _buildSectionTitle('Lương cơ bản theo giờ (VNĐ/h)'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _rateController,
                hint: 'Ví dụ: 90000',
                icon: Icons.timer,
              ),
            ],
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveSettings,
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        prefixIcon: Icon(icon, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  void _saveSettings() {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    if (_useMonthlySalary) {
      final salary = double.tryParse(_salaryController.text);
      if (salary != null && salary > 0) {
        provider.updateMonthlySalary(salary);
        _showSuccess();
      }
    } else {
      final rate = double.tryParse(_rateController.text);
      if (rate != null && rate > 0) {
        provider.updateHourlyRate(rate);
        _showSuccess();
      }
    }
  }

  void _showSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã cập nhật cài đặt lương!')),
    );
    Navigator.pop(context);
  }
}
