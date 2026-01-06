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
        AndroidInitializationSettings('@mipmap/ic_launcher');

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
    // Use permission_handler for Android 13+
    final status = await Permission.notification.request();
    debugPrint('Notification Permission Status: $status');
    
    if (status.isGranted) {
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

  Future<void> scheduleDailyNotification() async {
    final scheduledTime = _nextInstanceOfTime();
    debugPrint('Scheduling notification for: $scheduledTime');
    
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Nhắc nhở chấm công',
      'Đã đến giờ rồi, bạn nhớ chấm công hôm nay nhé!',
      scheduledTime,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder_channel',
          'Daily Reminder',
          channelDescription: 'Daily reminder to log overtime',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    
    debugPrint('Notification scheduled successfully!');
  }

  tz.TZDateTime _nextInstanceOfTime() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    debugPrint('Current time (Vietnam): $now');
    
    // Schedule for 17:28 daily for testing
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 20, 00);

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
      1,
      'Test Notification',
      'Nếu bạn thấy thông báo này, notification đang hoạt động!',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'test_channel',
          'Test',
          channelDescription: 'Test notifications',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
  
  Future<void> cancelAll() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}
