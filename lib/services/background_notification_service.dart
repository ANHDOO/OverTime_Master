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
  static const String oneTimeReminderTask = 'one_time_reminder';

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize WorkManager and background tasks
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
    debugPrint('BackgroundNotificationService initialized');
  }

  // Show notification
  static Future<void> showNotification(int id, String title, String body) async {
    const androidDetails = AndroidNotificationDetails(
      'daily_reminder_channel',
      'Daily Reminder',
      channelDescription: 'Daily reminder to log overtime and expenses',
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

  // Cancel all background tasks
  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
    debugPrint('All background tasks cancelled');
  }
}
