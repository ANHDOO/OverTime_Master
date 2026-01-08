import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/overtime_entry.dart';
import '../models/debt_entry.dart';
import '../models/cash_transaction.dart';
import 'background_notification_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  GlobalKey<NavigatorState>? _navigatorKey;

  void setNavigatorKey(GlobalKey<NavigatorState> key) {
    _navigatorKey = key;
  }

  Future<void> init() async {
    tz_data.initializeTimeZones();
    // Set Vietnam timezone
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

    // Initialize background notification service
    await BackgroundNotificationService.initialize();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/launcher_icon');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        debugPrint('Notification tapped: ${response.payload}');
        try {
          // Bring user to main screen
          if (_navigatorKey != null && _navigatorKey!.currentState != null) {
            _navigatorKey!.currentState!.pushNamedAndRemoveUntil('/', (route) => false);
          }
        } catch (e) {
          debugPrint('Error handling notification tap: $e');
        }
      },
    );
  }

  Future<bool?> requestPermissions() async {
    // Request notification permission for Android 13+
    final notificationStatus = await Permission.notification.request();
    debugPrint('Notification Permission Status: $notificationStatus');
    
    // Request exact alarm permission for Android 12+ (API 31+)
    final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
    debugPrint('Exact Alarm Permission Status: $exactAlarmStatus');
    
    if (notificationStatus.isGranted) {
      debugPrint('Notification Permission Granted via permission_handler');
      return true;
    }
    
    // Fallback/iOS
    final iosGranted = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    debugPrint('iOS Notification Permission Granted: $iosGranted');
    return iosGranted;
  }
  
  Future<bool> _canScheduleExactAlarms() async {
    try {
      final status = await Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return false;
    }
  }

  Future<void> scheduleDailyNotification({bool testMode = false}) async {
    // Hủy tất cả notification cũ trước khi schedule mới
    await flutterLocalNotificationsPlugin.cancelAll();
    
    // Kiểm tra quyền exact alarm
    final canUseExact = await _canScheduleExactAlarms();
    final scheduleMode = canUseExact 
        ? AndroidScheduleMode.exactAllowWhileIdle 
        : AndroidScheduleMode.inexactAllowWhileIdle;
    
    if (!canUseExact) {
      debugPrint('⚠️ Exact alarm permission not granted, using inexact mode');
    }
    
    tz.TZDateTime scheduledTime;
    
    if (testMode) {
      // Sử dụng Workmanager cho test mode vì nó ổn định hơn trên MIUI
      debugPrint('TEST MODE: Scheduling notification via Workmanager in 10 seconds');
      await BackgroundNotificationService.scheduleOneTimeReminder(
        const Duration(seconds: 10),
        'Nhắc nhở hằng ngày (Test)',
        'Cập nhật OT và chi tiêu hôm nay nha!',
      );
      return;
    } else {
      // Production: schedule lúc 22:00 (10 PM)
      scheduledTime = _nextInstanceOfTime(22, 0);
    }
    
    debugPrint('Scheduling daily notification for: $scheduledTime');
    debugPrint('Android Schedule Mode: $scheduleMode');
    debugPrint('Match DateTime Components: ${testMode ? "None" : "Time"}');
    
    // Schedule notification gộp chung
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1001, // Sử dụng ID khác 0
      'Nhắc nhở hằng ngày',
      'Cập nhật OT và chi tiêu hôm nay nha!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminder',
          channelDescription: 'Daily reminder to log overtime and expenses',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: testMode ? null : DateTimeComponents.time,
    );
    
    debugPrint('✅ Notification scheduled successfully!');
    debugPrint('Notification ID: 1001, scheduled at: $scheduledTime');
  }

  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    debugPrint('Current time (Vietnam): $now');
    
    // Schedule for specified time daily
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    // If time has passed, schedule for tomorrow
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    
    debugPrint('Scheduled date: $scheduledDate');
    return scheduledDate;
  }
  
  // Test immediate notification
  Future<void> showTestNotification() async {
    await flutterLocalNotificationsPlugin.show(
      999,
      'Test Notification',
      'Nếu bạn thấy thông báo này, notification đang hoạt động!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test',
          channelDescription: 'Test notifications',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
  
  // Test scheduled notifications (sau 10 giây)
  Future<void> testScheduledNotifications() async {
    debugPrint('=== TESTING SCHEDULED NOTIFICATIONS ===');

    // Test immediate notification
    await showTestNotification();

    // Test background service one-time reminder
    await BackgroundNotificationService.scheduleOneTimeReminder(
      const Duration(seconds: 10),
      'Test Background Reminder',
      'Thông báo từ Background Service sau 10 giây!',
    );

    debugPrint('Test notifications scheduled! Check immediately and in 10 seconds.');
  }
  
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }

  // Smart Reminders - Nhắc nhở thông minh (sử dụng Background Service)
  Future<void> scheduleSmartReminders({
    required List<OvertimeEntry> overtimeEntries,
    required List<DebtEntry> debtEntries,
    required List<CashTransaction> cashTransactions,
  }) async {
    debugPrint('Scheduling smart reminders using Background Service...');

    // Convert data for background service
    final otEntries = overtimeEntries.map((e) => {
      'id': e.id,
      'date': e.date.toIso8601String(),
      'totalHours': e.hours15 + e.hours18 + e.hours20,
      'totalPay': e.totalPay,
    }).toList();

    final debtEntriesData = debtEntries.map((e) => {
      'id': e.id,
      'month': e.month.toIso8601String(),
      'amount': e.amount,
      'isPaid': e.isPaid,
    }).toList();

    // Calculate budgets and expenses by project
    final budgets = <String, double>{};
    final expenses = <String, double>{};

    // Group cash transactions by project
    for (final transaction in cashTransactions) {
      if (transaction.type == TransactionType.expense && transaction.project.isNotEmpty) {
        final project = transaction.project;
        expenses[project] = (expenses[project] ?? 0) + transaction.amount;
      }
    }

    // Update background service with current data
    await BackgroundNotificationService.updateNotificationData(
      otEntries: otEntries,
      debtEntries: debtEntriesData,
      budgets: budgets,
      expenses: expenses,
    );

    debugPrint('Smart reminders scheduled via Background Service');
  }

  // Nhắc nhở nhập OT cuối ngày (22:00)
  Future<void> _scheduleOTReminder(DateTime today, List<OvertimeEntry> entries) async {
    // Kiểm tra xem hôm nay đã nhập OT chưa
    final todayEntries = entries.where((entry) =>
      entry.date.year == today.year &&
      entry.date.month == today.month &&
      entry.date.day == today.day
    ).toList();

    // Bắt buộc nhắc nhở lúc 22:00
    final reminderTime = tz.TZDateTime(tz.local, today.year, today.month, today.day, 22, 0);

    // Nếu đã qua 22:00 thì schedule cho ngày mai
    if (reminderTime.isBefore(tz.TZDateTime.now(tz.local))) {
      final tomorrow = today.add(const Duration(days: 1));
      final reminderTime = tz.TZDateTime(tz.local, tomorrow.year, tomorrow.month, tomorrow.day, 22, 0);

        await _scheduleNotification(
          id: 100, // OT reminder
          title: 'Nhắc nhở nhập OT',
          body: 'Bạn chưa nhập OT hôm nay. Hãy cập nhật để không quên!',
          scheduledTime: reminderTime,
        );
      } else {
        await _scheduleNotification(
          id: 100,
          title: 'Nhắc nhở nhập OT',
          body: 'Đến giờ nhập OT rồi! Hãy cập nhật công việc hôm nay.',
          scheduledTime: reminderTime,
        );
      }
    }

  // Nhắc nhở thanh toán nợ lương
  Future<void> _scheduleDebtReminders(List<DebtEntry> debtEntries) async {
    final unpaidDebts = debtEntries.where((debt) => !debt.isPaid).toList();

    for (final debt in unpaidDebts) {
      final interest = debt.calculateInterest();
      final daysLate = interest['daysLate'] as double;

      // Nhắc nhở nếu nợ quá hạn hoặc sắp đến hạn
      if (daysLate > 0) {
        // Nợ quá hạn - nhắc ngay lập tức (sau 1 phút)
        final reminderTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));

        await _scheduleNotification(
          id: 200 + debt.id!, // Unique ID for each debt
          title: 'Nợ lương quá hạn',
          body: 'Nợ tháng ${debt.month.month}/${debt.month.year} đã quá hạn ${daysLate.toInt()} ngày. Lãi: ${interest['totalInterest']}₫',
          scheduledTime: reminderTime,
        );
      } else if (daysLate > -3) {
        // Sắp đến hạn (3 ngày) - nhắc lúc 9:00 sáng
        final dueDate = DateTime(debt.month.year, debt.month.month, 20);
        final reminderTime = tz.TZDateTime(tz.local, dueDate.year, dueDate.month, dueDate.day - 3, 9, 0);

        if (reminderTime.isAfter(tz.TZDateTime.now(tz.local))) {
          await _scheduleNotification(
            id: 200 + debt.id!,
            title: 'Nhắc nhở thanh toán nợ',
            body: 'Nợ tháng ${debt.month.month}/${debt.month.year} sẽ đến hạn trong ${3 + daysLate.toInt()} ngày nữa.',
            scheduledTime: reminderTime,
          );
        }
      }
    }
  }

  // Nhắc nhở hạn mức chi tiêu dự án
  Future<void> _scheduleBudgetReminders(List<CashTransaction> transactions) async {
    final prefs = await SharedPreferences.getInstance();

    // Lấy cài đặt hạn mức từ SharedPreferences (nếu có)
    final budgetSettings = prefs.getString('budget_settings');
    if (budgetSettings == null) return;

    final budgets = Map<String, double>.from(
      budgetSettings.split(',').fold<Map<String, double>>({}, (map, item) {
        final parts = item.split(':');
        if (parts.length == 2) {
          map[parts[0]] = double.tryParse(parts[1]) ?? 0;
        }
        return map;
      })
    );

    final now = DateTime.now();
    final currentMonth = DateTime(now.year, now.month);

    // Tính tổng chi tiêu theo dự án trong tháng hiện tại
    final projectExpenses = <String, double>{};
    for (final transaction in transactions) {
      if (transaction.type == TransactionType.expense) {
        final transactionMonth = DateTime(transaction.date.year, transaction.date.month);
        if (transactionMonth.year == currentMonth.year && transactionMonth.month == currentMonth.month) {
          projectExpenses[transaction.project] = (projectExpenses[transaction.project] ?? 0) + transaction.amount;
        }
      }
    }

    // Kiểm tra và tạo nhắc nhở cho các dự án vượt hạn mức
    for (final project in budgets.keys) {
      final budget = budgets[project] ?? 0;
      final expense = projectExpenses[project] ?? 0;
      final percentage = budget > 0 ? (expense / budget) * 100 : 0;

      if (percentage >= 80 && percentage < 100) {
        // Vượt 80% hạn mức - nhắc lúc 10:00 sáng mai
        final tomorrow = now.add(const Duration(days: 1));
        final reminderTime = tz.TZDateTime(tz.local, tomorrow.year, tomorrow.month, tomorrow.day, 10, 0);

        await _scheduleNotification(
          id: 300 + project.hashCode, // Unique ID for each project
          title: 'Cảnh báo hạn mức chi tiêu',
          body: 'Dự án "$project" đã chi ${percentage.toStringAsFixed(1)}% hạn mức (${expense.toStringAsFixed(0)}₫/${budget.toStringAsFixed(0)}₫)',
          scheduledTime: reminderTime,
        );
      } else if (percentage >= 100) {
        // Vượt hạn mức - nhắc ngay lập tức
        final reminderTime = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 2));

        await _scheduleNotification(
          id: 300 + project.hashCode,
          title: 'Vượt hạn mức chi tiêu!',
          body: 'Dự án "$project" đã vượt hạn mức! Đã chi ${expense.toStringAsFixed(0)}₫/${budget.toStringAsFixed(0)}₫',
          scheduledTime: reminderTime,
        );
      }
    }
  }

  // Helper method to schedule notification
  Future<void> _scheduleNotification({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledTime,
  }) async {
    final canUseExact = await _canScheduleExactAlarms();
    final scheduleMode = canUseExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_reminder_channel',
          'Smart Reminders',
          channelDescription: 'Intelligent reminders for OT, debts, and budgets',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: scheduleMode,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('Smart notification scheduled: $title at $scheduledTime (ID: $id)');
  }

  // Save budget settings
  Future<void> saveBudgetSettings(Map<String, double> budgets) async {
    final prefs = await SharedPreferences.getInstance();
    final budgetString = budgets.entries.map((e) => '${e.key}:${e.value}').join(',');
    await prefs.setString('budget_settings', budgetString);
  }

  // Load budget settings
  Future<Map<String, double>> loadBudgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final budgetString = prefs.getString('budget_settings');
    if (budgetString == null) return {};

    return budgetString.split(',').fold<Map<String, double>>({}, (map, item) {
      final parts = item.split(':');
      if (parts.length == 2) {
        map[parts[0]] = double.tryParse(parts[1]) ?? 0;
      }
      return map;
    });
  }

  // Test background notification service immediately
  Future<void> testBackgroundNotification() async {
    debugPrint('=== TESTING BACKGROUND NOTIFICATION SERVICE ===');
    await BackgroundNotificationService.testImmediateNotification();
    debugPrint('Background notification test completed');
  }

  // Force trigger background check immediately (bypass scheduling)
  Future<void> forceBackgroundCheck() async {
    debugPrint('=== FORCE BACKGROUND CHECK ===');
    await BackgroundNotificationService.forceBackgroundCheck();
    debugPrint('Force background check completed');
  }

  // Show immediate notification (for testing smart features)
  Future<void> showSmartReminderTest({
    required String title,
    required String body,
  }) async {
    await flutterLocalNotificationsPlugin.show(
      9999,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'smart_reminder_channel',
          'Smart Reminders',
          channelDescription: 'Intelligent reminders for OT, debts, and budgets',
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          playSound: true,
          icon: '@mipmap/launcher_icon',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }
}
