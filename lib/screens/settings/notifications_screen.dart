import 'package:flutter/material.dart';
import '../../services/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _status = '';

  Future<void> _requestAndTest() async {
    setState(() => _status = 'Đang yêu cầu quyền...');
    final service = NotificationService();
    await service.init();
    final granted = await service.requestPermissions();
    if (granted == true) {
      setState(() => _status = 'Đã cấp quyền. Gửi thông báo thử...');
      await service.showTestNotification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi thông báo thử ngay lập tức!')));
      }
      setState(() => _status = 'Đã gửi thông báo thử ngay lập tức');
    } else {
      setState(() => _status = 'Quyền thông báo bị từ chối');
    }
  }

  Future<void> _testImmediate() async {
    final service = NotificationService();
    await service.showTestNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi thông báo thử ngay lập tức!')));
    }
  }

  Future<void> _testDailyReminder() async {
    setState(() => _status = 'Đang lên lịch nhắc nhở hằng ngày (10s)...');
    final service = NotificationService();
    await service.scheduleDailyNotification(testMode: true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lên lịch nhắc nhở hằng ngày (10s)!')));
    }
    setState(() => _status = 'Đã lên lịch nhắc nhở hằng ngày (10s)');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Thiết lập và kiểm tra thông báo'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _requestAndTest,
              icon: const Icon(Icons.notifications_active),
              label: const Text('Yêu cầu quyền & Test Ngay'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _testImmediate,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Test Thông báo ngay lập tức'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _testDailyReminder,
              icon: const Icon(Icons.alarm),
              label: const Text('Test Nhắc nhở hằng ngày (10s)'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              '⚠️ Lưu ý cho máy Xiaomi/MIUI:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            const SizedBox(height: 8),
            const Text('1. Vào Cài đặt ứng dụng -> Tự khởi chạy (Auto-start): Bật'),
            const Text('2. Tiết kiệm pin: Chọn "Không hạn chế" (No restrictions)'),
            const Text('3. Quyền khác: Bật "Hiển thị trên màn hình khóa" và "Hiển thị cửa sổ pop-up khi chạy trong nền"'),
          ],
        ),
      ),
    );
  }
}


