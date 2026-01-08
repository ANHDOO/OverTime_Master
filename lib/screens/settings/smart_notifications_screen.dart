import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/overtime_provider.dart';
import '../../services/notification_service.dart';

class SmartNotificationsScreen extends StatefulWidget {
  const SmartNotificationsScreen({super.key});

  @override
  State<SmartNotificationsScreen> createState() => _SmartNotificationsScreenState();
}

class _SmartNotificationsScreenState extends State<SmartNotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  Map<String, double> _budgetSettings = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadBudgetSettings();
  }

  Future<void> _loadBudgetSettings() async {
    setState(() => _isLoading = true);
    try {
      _budgetSettings = await _notificationService.loadBudgetSettings();
      setState(() {});
    } catch (e) {
      _showError('Lỗi tải cài đặt: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveBudgetSettings() async {
    setState(() => _isLoading = true);
    try {
      await _notificationService.saveBudgetSettings(_budgetSettings);
      _showSuccess('Đã lưu cài đặt hạn mức');
    } catch (e) {
      _showError('Lỗi lưu cài đặt: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleSmartReminders() async {
    final provider = Provider.of<OvertimeProvider>(context, listen: false);
    setState(() => _isLoading = true);

    try {
      await _notificationService.scheduleSmartReminders(
        overtimeEntries: provider.entries,
        debtEntries: provider.debtEntries,
        cashTransactions: provider.cashTransactions,
      );
      _showSuccess('Đã lên lịch nhắc nhở thông minh');
    } catch (e) {
      _showError('Lỗi lên lịch nhắc nhở: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _testSmartReminder(String type) async {
    String title;
    String body;

    switch (type) {
      case 'ot':
        title = 'Nhắc nhở nhập OT';
        body = 'Đến giờ nhập OT rồi! Hãy cập nhật công việc hôm nay.';
        break;
      case 'debt':
        title = 'Nợ lương quá hạn';
        body = 'Bạn có nợ lương chưa thanh toán. Hãy kiểm tra!';
        break;
      case 'budget':
        title = 'Cảnh báo hạn mức chi tiêu';
        body = 'Dự án của bạn đã đạt 80% hạn mức chi tiêu.';
        break;
      case 'background':
        await _testBackgroundNotification();
        return;
      default:
        return;
    }

    try {
      await _notificationService.showSmartReminderTest(title: title, body: body);
      _showSuccess('Đã gửi thông báo test');
    } catch (e) {
      _showError('Lỗi gửi thông báo: $e');
    }
  }

  Future<void> _testBackgroundNotification() async {
    try {
      await _notificationService.testBackgroundNotification();
      _showSuccess('Đã test Background Notification Service');
    } catch (e) {
      _showError('Lỗi test background notification: $e');
    }
  }

  Future<void> _forceBackgroundCheck() async {
    try {
      await _notificationService.forceBackgroundCheck();
      _showSuccess('Đã force check Background Service');
    } catch (e) {
      _showError('Lỗi force background check: $e');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showSuccess(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _addBudgetProject() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thêm dự án'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tên dự án',
            hintText: 'Ví dụ: Dự án ABC',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final projectName = controller.text.trim();
              if (projectName.isNotEmpty && !_budgetSettings.containsKey(projectName)) {
                setState(() {
                  _budgetSettings[projectName] = 0;
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
  }

  void _editBudget(String projectName, double currentBudget) {
    final controller = TextEditingController(text: currentBudget.toStringAsFixed(0));
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cài đặt hạn mức - $projectName'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Hạn mức (VNĐ)',
            hintText: 'Ví dụ: 50000000',
          ),
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              final budget = double.tryParse(controller.text.replaceAll(',', '').replaceAll('.', '')) ?? 0;
              setState(() {
                _budgetSettings[projectName] = budget;
              });
              Navigator.pop(context);
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _removeBudgetProject(String projectName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: Text('Bạn có chắc chắn muốn xóa cài đặt hạn mức cho dự án "$projectName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _budgetSettings.remove(projectName);
              });
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhắc nhở thông minh'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Lên lịch lại',
            onPressed: () async {
              setState(() => _isLoading = true);
              try {
                await _notificationService.testScheduledNotifications();
                _showSuccess('Đã schedule test notification (10s)');
              } catch (e) {
                _showError('Lỗi khi schedule test: $e');
              } finally {
                setState(() => _isLoading = false);
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Introduction
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.smart_toy, color: Colors.blue.shade600, size: 24),
                            const SizedBox(width: 12),
                            Text(
                              'Nhắc nhở thông minh',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Hệ thống sử dụng Background Service để tự động kiểm tra và nhắc nhở bạn về các việc quan trọng như nhập OT, thanh toán nợ, và quản lý chi tiêu dự án.',
                          style: TextStyle(color: Color(0xFF1976D2)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // OT Reminders
                  _buildReminderSection(
                    icon: Icons.access_time,
                    color: Colors.blue,
                    title: 'Nhắc nhở nhập OT',
                    description: 'Nhắc nhở nhập OT lúc 22:00 nếu chưa cập nhật',
                    testType: 'ot',
                  ),

                  const SizedBox(height: 16),

                  // Debt Reminders
                  _buildReminderSection(
                    icon: Icons.account_balance_wallet,
                    color: Colors.orange,
                    title: 'Nhắc nhở nợ lương',
                    description: 'Cảnh báo nợ quá hạn hoặc sắp đến hạn',
                    testType: 'debt',
                  ),

                  const SizedBox(height: 16),

                  // Background Service Test
                  _buildBackgroundServiceSection(),

                  const SizedBox(height: 16),

                  // Budget Settings
                  _buildBudgetSection(),

                  const SizedBox(height: 24),

                  // Schedule Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        setState(() => _isLoading = true);
                        try {
                          // Schedule test notifications to fire shortly for manual testing
                          await _notificationService.testScheduledNotifications();
                          _showSuccess('Đã lên lịch test nhắc nhở (10s). Kiểm tra sau 10s.');
                        } catch (e) {
                          _showError('Lỗi lên lịch test: $e');
                        } finally {
                          setState(() => _isLoading = false);
                        }
                      },
                      icon: const Icon(Icons.schedule),
                      label: const Text('Lên lịch nhắc nhở (Test 10s)'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Info
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💡 Mẹo:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 8),
                        Text('• Background Service kiểm tra mỗi giờ một lần'),
                        Text('• Nhắc nhở hoạt động ngay cả khi app đóng'),
                        Text('• Có thể test từng loại và Background Service'),
                        Text('• Hạn mức chi tiêu được tính theo tháng hiện tại'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildReminderSection({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required String testType,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: color.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _testSmartReminder(testType),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: const Text('Test'),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundServiceSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.work, color: Colors.purple.shade600, size: 24),
              const SizedBox(width: 12),
              Text(
                'Background Service',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Test Background Notification Service - hoạt động ngay cả khi app đóng.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF7B1FA2),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _testSmartReminder('background'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: const Text('Test Background Service'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.savings, color: Colors.teal.shade600, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Hạn mức chi tiêu dự án',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _addBudgetProject,
                icon: const Icon(Icons.add),
                label: const Text('Thêm'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Cài đặt hạn mức chi tiêu theo tháng cho từng dự án',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF00796B),
            ),
          ),
          const SizedBox(height: 16),

          if (_budgetSettings.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text(
                  'Chưa có dự án nào được cài đặt hạn mức',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ..._budgetSettings.entries.map((entry) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.teal.shade200),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              entry.key,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                        Text(
                          'Hạn mức: ${entry.value.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')} ₫',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editBudget(entry.key, entry.value),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _removeBudgetProject(entry.key),
                          ),
                          ElevatedButton(
                            onPressed: () => _testSmartReminder('budget'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                            ),
                            child: const Text('Test'),
                          ),
                        ],
                      ),
                    ],
                  ),
                )),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _forceBackgroundCheck,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Force Check'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _testBackgroundNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Test Background'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_budgetSettings.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveBudgetSettings,
                style: const ButtonStyle(
                  backgroundColor: MaterialStatePropertyAll(Color(0xFF00796B)),
                  foregroundColor: MaterialStatePropertyAll(Colors.white),
                ),
                child: const Text('Lưu cài đặt hạn mức'),
              ),
            ),
        ],
      ),
    );
  }
}
