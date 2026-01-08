import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint('Background task executed: $task');

      switch (task) {
        case BackgroundNotificationService.taskName:
          await BackgroundNotificationService.executeSmartNotifications();
          break;
        case BackgroundNotificationService.otReminderTask:
          await BackgroundNotificationService.executeOTReminder();
          break;
        case BackgroundNotificationService.debtReminderTask:
          await BackgroundNotificationService.executeDebtReminder();
          break;
        case BackgroundNotificationService.budgetReminderTask:
          await BackgroundNotificationService.executeBudgetReminder();
          break;
        case BackgroundNotificationService.oneTimeReminderTask:
          final title = inputData?['title'] ?? 'Nhắc nhở';
          final body = inputData?['body'] ?? 'Bạn có thông báo mới';
          await BackgroundNotificationService.showNotification(999, title, body);
          break;
      }

      return true;
    } catch (e) {
      debugPrint('Background task failed: $e');
      return false;
    }
  });
}

class BackgroundNotificationService {
  static const String taskName = 'smart_notifications_task';
  static const String otReminderTask = 'ot_reminder_task';
  static const String debtReminderTask = 'debt_reminder_task';
  static const String budgetReminderTask = 'budget_reminder_task';
  static const String oneTimeReminderTask = 'one_time_reminder';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize WorkManager and background tasks
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

    // Register background tasks
    await Workmanager().registerPeriodicTask(
      taskName,
      taskName,
      frequency: const Duration(hours: 1), // Check every hour
      initialDelay: const Duration(minutes: 1),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );

    debugPrint('BackgroundNotificationService initialized');
  }

  // Execute smart notifications check
  static Future<void> executeSmartNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationData = prefs.getString('notification_data');

    if (notificationData == null) return;

    final data = jsonDecode(notificationData);
    final now = DateTime.now();

    // Check Daily Reminder (22:00)
    await _checkDailyReminder(now);

    // Check OT reminders
    if (data['otEnabled'] == true) {
      await executeOTReminder();
    }

    // Check debt reminders
    if (data['debtEnabled'] == true) {
      await executeDebtReminder();
    }

    // Check budget warnings
    if (data['budgetEnabled'] == true) {
      await executeBudgetReminder();
    }
  }

  // Check and show Daily Reminder (22:00)
  static Future<void> _checkDailyReminder(DateTime now) async {
    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString('last_daily_reminder_date') ?? '';
    final todayStr = "${now.year}-${now.month}-${now.day}";

    // Trigger lúc 22:00 - Hiện mỗi ngày một lần
    if (lastShown != todayStr && now.hour >= 22) {
      await showNotification(
        1001,
        'Nhắc nhở hằng ngày',
        'Cập nhật OT và chi tiêu hôm nay nha!',
      );
      await prefs.setString('last_daily_reminder_date', todayStr);
      debugPrint('Daily reminder shown and recorded for $todayStr');
    }
  }

  // Check and show OT reminder
  static Future<void> executeOTReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationData = prefs.getString('notification_data');
    if (notificationData == null) return;
    final data = jsonDecode(notificationData);
    final otEntries = data['otEntries'] ?? [];
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day);
    final todayEntries = otEntries.where((entry) {
      final entryDate = DateTime.parse(entry['date']);
      return entryDate.year == today.year &&
             entryDate.month == today.month &&
             entryDate.day == today.day;
    }).toList();

    // Trigger lúc 22:00 - Chỉ hiện nếu chưa nhập OT
    if (now.hour > 22 || (now.hour == 22 && now.minute >= 0)) {
      if (todayEntries.isEmpty) {
        await showNotification(
          100,
          'Nhắc nhở nhập OT',
          'Bạn chưa nhập OT hôm nay. Hãy cập nhật để không quên!',
        );
      } else {
        debugPrint('OT already entered for today, skipping background reminder');
      }
    }
  }

  // Check and show debt reminders
  static Future<void> executeDebtReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationData = prefs.getString('notification_data');
    if (notificationData == null) return;
    final data = jsonDecode(notificationData);
    final debtEntries = data['debtEntries'] ?? [];
    final now = DateTime.now();

    for (final debt in debtEntries) {
      if (debt['isPaid'] == true) continue; // Skip paid debts

      final debtMonth = DateTime.parse(debt['month']);
      final dueDate = DateTime(debtMonth.year, debtMonth.month, 20); // Due on 20th of month
      final daysUntilDue = dueDate.difference(now).inDays;

      if (daysUntilDue <= 3 && daysUntilDue >= 0) {
        await showNotification(
          200 + (debt['id'] as int),
          'Nợ lương sắp đến hạn',
          'Khoản nợ tháng ${debtMonth.month}/${debtMonth.year} sắp đến hạn (ngày 20).',
        );
      }
    }
  }

  // Check budget warnings
  static Future<void> executeBudgetReminder() async {
    final prefs = await SharedPreferences.getInstance();
    final notificationData = prefs.getString('notification_data');
    if (notificationData == null) return;
    final data = jsonDecode(notificationData);
    final budgetData = data['budgetData'] ?? {};
    final now = DateTime.now();

    final Map<String, dynamic> budgets = budgetData['budgets'] ?? {};
    final Map<String, dynamic> expenses = budgetData['expenses'] ?? {};

    for (final project in budgets.keys) {
      final budget = (budgets[project] as num).toDouble();
      final spent = (expenses[project] as num?)?.toDouble() ?? 0.0;

      if (budget <= 0) continue;

      final percentage = (spent / budget) * 100;
      if (percentage >= 80) {
        await showNotification(
          300 + project.hashCode,
          'Cảnh báo hạn mức chi tiêu',
          'Dự án "$project" đã sử dụng ${percentage.toStringAsFixed(0)}% hạn mức (${spent.toStringAsFixed(0)} đ / ${budget.toStringAsFixed(0)} đ)',
        );
      }
    }
  }

  // Show notification
  static Future<void> showNotification(int id, String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'smart_reminder_channel',
      'Smart Reminders',
      channelDescription: 'Intelligent reminders for OT, debts, and budgets',
      importance: Importance.high,
      priority: Priority.high,
      enableVibration: true,
      playSound: true,
      icon: '@mipmap/launcher_icon',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _notificationsPlugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: androidDetails, iOS: iosDetails),
    );
  }

  // Schedule one-time reminder (for testing)
  static Future<void> scheduleOneTimeReminder(Duration delay, String title, String body) async {
    await Workmanager().registerOneOffTask(
      'one_time_${DateTime.now().millisecondsSinceEpoch}',
      oneTimeReminderTask,
      initialDelay: delay,
      inputData: {'title': title, 'body': body},
    );
  }

  // Update notification data for background checks
  static Future<void> updateNotificationData({
    required List<Map<String, dynamic>> otEntries,
    required List<Map<String, dynamic>> debtEntries,
    required Map<String, double> budgets,
    required Map<String, double> expenses,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'otEnabled': true,
      'debtEnabled': true,
      'budgetEnabled': true,
      'otEntries': otEntries,
      'debtEntries': debtEntries,
      'budgetData': {
        'budgets': budgets,
        'expenses': expenses,
      },
    };

    await prefs.setString('notification_data', jsonEncode(data));
    debugPrint('Notification data updated for background tasks');
  }

  // Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    debugPrint('All background tasks cancelled');
  }

  // Test immediate notification
  static Future<void> testImmediateNotification() async {
    await showNotification(
      999,
      'Test Background Notification',
      'Thông báo background đang hoạt động! ${DateTime.now()}',
    );
  }

  // Force trigger background check immediately (for testing)
  static Future<void> forceBackgroundCheck() async {
    debugPrint('=== FORCE BACKGROUND CHECK ===');
    await executeSmartNotifications();
    debugPrint('Force background check completed');
  }

  // Execute individual reminder types (for one-off tasks)
  static Future<void> _executeOTReminder() async {
    await showNotification(
      100,
      'Nhắc nhở nhập OT',
      'Đến giờ nhập OT rồi! Hãy cập nhật công việc hôm nay.',
    );
  }

  static Future<void> _executeDebtReminder() async {
    await showNotification(
      200,
      'Nhắc nhở nợ lương',
      'Bạn có nợ lương chưa thanh toán. Hãy kiểm tra!',
    );
  }

  static Future<void> _executeBudgetReminder() async {
    await showNotification(
      300,
      'Cảnh báo hạn mức',
      'Dự án của bạn đã đạt hạn mức chi tiêu.',
    );
  }
}
