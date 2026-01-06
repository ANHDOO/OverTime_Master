import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    // Set Vietnam timezone
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));

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
        // Handle notification tap
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
      // Test mode: schedule sau 10 giây từ giờ hiện tại để test nhanh
      final now = tz.TZDateTime.now(tz.local);
      scheduledTime = now.add(const Duration(seconds: 10));
      debugPrint('TEST MODE: Scheduling notification in 10 seconds');
    } else {
      // Production: schedule lúc 22:00 (10 PM)
      scheduledTime = _nextInstanceOfTime(22, 0);
    }
    
    debugPrint('Scheduling daily notification for: $scheduledTime');
    
    // Schedule notification gộp chung
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
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
    
    debugPrint('Notification scheduled successfully!');
    debugPrint('Notification ID: 0, scheduled at: $scheduledTime');
    debugPrint('Schedule mode: ${canUseExact ? "exact" : "inexact"}');
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
    await scheduleDailyNotification(testMode: true);
    debugPrint('Test notification scheduled! Check in 10 seconds.');
  }
  
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
