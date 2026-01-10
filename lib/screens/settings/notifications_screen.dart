import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/notification_service.dart';
import '../../widgets/custom_time_picker.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isEnabled = true;
  int _selectedHour = 22;
  int _selectedMinute = 0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isEnabled = prefs.getBool('notification_enabled') ?? true;
      _selectedHour = prefs.getInt('notification_hour') ?? 22;
      _selectedMinute = prefs.getInt('notification_minute') ?? 0;
    });
  }

  Future<void> _toggleNotification(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notification_enabled', value);
    setState(() => _isEnabled = value);
    
    if (value) {
      final service = NotificationService();
      await service.scheduleDailyNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã bật nhắc nhở lúc $_selectedHour:${_selectedMinute.toString().padLeft(2, '0')} mỗi ngày 💪')),
        );
      }
    } else {
      await NotificationService().cancelAll();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tắt nhắc nhở hằng ngày')),
        );
      }
    }
  }

  Future<void> _pickTime() async {
    final picked = await CustomTimePicker.show(
      context,
      initialTime: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
      title: 'Giờ nhắc nhở',
      secondaryButtonText: 'Hủy',
    );
    if (picked != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('notification_hour', picked.hour);
      await prefs.setInt('notification_minute', picked.minute);
      setState(() {
        _selectedHour = picked.hour;
        _selectedMinute = picked.minute;
      });
      
      if (_isEnabled) {
        final service = NotificationService();
        await service.scheduleDailyNotification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã cập nhật giờ nhắc nhở: ${picked.hour}:${picked.minute.toString().padLeft(2, '0')} 🕐')),
          );
        }
      }
    }
  }

  Future<void> _scheduleTestNotification() async {
    final service = NotificationService();
    await service.scheduleDailyNotification(testMode: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã đặt lịch nhắc nhở sau 10 giây để kiểm tra 🚀'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getTimeUntilNext() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, _selectedHour, _selectedMinute);
    if (next.isBefore(now)) {
      next = next.add(const Duration(days: 1));
    }
    final diff = next.difference(now);
    final hours = diff.inHours;
    final minutes = diff.inMinutes % 60;
    if (hours > 0) {
      return 'Còn $hours giờ $minutes phút nữa';
    }
    return 'Còn $minutes phút nữa';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nhắc nhở'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Main toggle
          Card(
            child: SwitchListTile(
              title: const Text(
                'Nhắc nhở hằng ngày',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(_isEnabled ? 'Đang bật' : 'Đã tắt'),
              secondary: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _isEnabled ? theme.colorScheme.primary.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.notifications_active,
                  color: _isEnabled ? theme.colorScheme.primary : Colors.grey,
                ),
              ),
              value: _isEnabled,
              onChanged: _toggleNotification,
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Time picker
          if (_isEnabled) ...[
            Card(
              child: ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('Giờ nhắc nhở'),
                subtitle: Text(_getTimeUntilNext()),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$_selectedHour:${_selectedMinute.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                onTap: _pickTime,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.preview, color: theme.colorScheme.primary, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Xem trước thông báo',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.work, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Anh Đô ơi! 💼',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Hôm nay làm OT không? Nhớ ghi lại chi tiêu nha! 📝',
                                style: TextStyle(fontSize: 13, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Test button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scheduleTestNotification,
                icon: const Icon(Icons.timer_outlined),
                label: const Text('Thử nghiệm nhắc nhở (sau 10s)'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: BorderSide(color: theme.colorScheme.primary),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Xiaomi warning
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Lưu ý cho Xiaomi/MIUI',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Để thông báo hoạt động đúng, vui lòng:\n'
                    '• Vào Cài đặt > Ứng dụng > OverTime\n'
                    '• Tắt "Tiết kiệm pin" cho app\n'
                    '• Bật "Tự khởi động"',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
