import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      // Test mode: schedule 10 seconds from now
      debugPrint('TEST MODE: Scheduling notification in 10 seconds');
      scheduledTime = tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10));
    } else {
      // Lấy giờ từ SharedPreferences, mặc định là 22:00
      final prefs = await SharedPreferences.getInstance();
      final hour = prefs.getInt('notification_hour') ?? 22;
      final minute = prefs.getInt('notification_minute') ?? 0;
      final isEnabled = prefs.getBool('notification_enabled') ?? true;
      
      if (!isEnabled) {
        debugPrint('Notifications are disabled in settings. Skipping schedule.');
        await cancelAll();
        return;
      }
      
      scheduledTime = _nextInstanceOfTime(hour, minute);
    }
    
    debugPrint('Scheduling daily notification for: $scheduledTime');
    debugPrint('Android Schedule Mode: $scheduleMode');
    debugPrint('Match DateTime Components: ${testMode ? "None" : "Time"}');
    
    // Schedule notification using AlarmManager (zonedSchedule)
    await flutterLocalNotificationsPlugin.zonedSchedule(
      1001, // Sử dụng ID khác 0
      'Anh Đô ơi! 💼',
      'Hôm nay làm OT không? Nhớ ghi lại công việc và chi tiêu nha! 📝✨',
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
  
  Future<bool> _canScheduleExactAlarms() async {
    try {
      final status = await Permission.scheduleExactAlarm.status;
      return status.isGranted;
    } catch (e) {
      debugPrint('Error checking exact alarm permission: $e');
      return false;
    }
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
    await BackgroundNotificationService.cancelAll();
  }

}
