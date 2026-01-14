import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/io_client.dart';
import 'dart:io';
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'storage_service.dart';

// Task name constants
const String goldPriceCheckTask = 'goldPriceCheckTask';
const String goldPriceUniqueTaskName = 'com.anhdo.goldprice.sync';
const String oneTimeReminderTask = 'one_time_reminder';
const String dailyReminderTask = 'daily_reminder';

/// Initialize WorkManager for background gold price monitoring
Future<void> initializeBackgroundService() async {
  await Workmanager().initialize(
    callbackDispatcher,
  );
  
  // Register periodic task - runs every 15 minutes (Android minimum)
  await Workmanager().registerPeriodicTask(
    goldPriceUniqueTaskName,
    goldPriceCheckTask,
    frequency: const Duration(minutes: 15),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
  );
  
  debugPrint('[BackgroundService] Initialized periodic gold price check (every 15 minutes)');
}

/// Callback dispatcher - must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BackgroundService] Executing task: $taskName');
    
    try {
      switch (taskName) {
        case goldPriceCheckTask:
          await _checkGoldPriceAndNotify();
          break;
          
        case oneTimeReminderTask:
          final title = inputData?['title'] ?? 'Nhắc nhở';
          final body = inputData?['body'] ?? 'Bạn có thông báo mới';
          await _showSimpleNotification(998, title, body);
          break;
          
        case dailyReminderTask:
          final title = inputData?['title'] ?? 'Nhắc nhở hằng ngày';
          final body = inputData?['body'] ?? 'Cập nhật OT và chi tiêu hôm nay nha!';
          await _showSimpleNotification(1001, title, body);
          
          // Reschedule for tomorrow
          await scheduleDailyReminder(
            const Duration(hours: 24),
            title,
            body,
          );
          break;
      }
      return true;
    } catch (e) {
      debugPrint('[BackgroundService] Error: $e');
      return false;
    }
  });
}

/// Fetch gold price and send notification if changed
Future<void> _checkGoldPriceAndNotify() async {
  final prefs = await SharedPreferences.getInstance();
  
  // Create HTTP client that bypasses SSL issues
  final client = IOClient(
    HttpClient()..badCertificateCallback = (X509Certificate cert, String host, int port) => true,
  );
  
  try {
    // Fetch gold prices from Tám Nhung
    final response = await client.get(
      Uri.parse('https://giavangmaothiet.com/'),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode == 200) {
      var document = parser.parse(response.body);
      var tables = document.querySelectorAll('table.goldbox-table');
      
      if (tables.isNotEmpty) {
        var rows = tables[0].querySelectorAll('tbody tr');
        for (var row in rows) {
          var cols = row.querySelectorAll('td');
          if (cols.length >= 3) {
            final type = cols[0].text.trim();
            if (type.contains('Vàng Nhẫn Trơn')) {
              final sellPriceStr = cols[2].text.trim();
              final sellPrice = _parsePrice(sellPriceStr);
              
              // Get last saved price
              final lastPrice = prefs.getDouble('last_gold_sell_price') ?? 0;
              
              debugPrint('[BackgroundService] Current: $sellPrice, Last: $lastPrice');
              
              if (sellPrice > 0 && sellPrice != lastPrice) {
                // Price changed! Send notification
                await _sendGoldPriceNotification(sellPrice, lastPrice);
                
                // Save new price to prefs
                await prefs.setDouble('last_gold_sell_price', sellPrice);
                
                // Also save to database history
                try {
                  final storage = StorageService();
                  final buyPrice = _parsePrice(cols[1].text.trim());
                  final now = DateTime.now();
                  final dateStr = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
                  
                  await storage.insertGoldPriceHistory({
                    'date': dateStr,
                    'buy_price': buyPrice,
                    'sell_price': sellPrice,
                    'gold_type': 'MAIN_GOLD_NHAN_TRON_9999',
                  });
                  debugPrint('[BackgroundService] Saved to DB: $sellPrice at $dateStr');
                } catch (dbError) {
                  debugPrint('[BackgroundService] DB Error: $dbError');
                }
                
                debugPrint('[BackgroundService] Saved new price to prefs: $sellPrice');
              }
              
              break;
            }
          }
        }
      }
    }
  } finally {
    client.close();
  }
}

/// Parse price string to double
double _parsePrice(String? priceStr) {
  if (priceStr == null || priceStr.isEmpty) return 0;
  final cleaned = priceStr.replaceAll(RegExp(r'[^\d]'), '');
  return double.tryParse(cleaned) ?? 0;
}

/// Send notification about gold price change
Future<void> _sendGoldPriceNotification(double newPrice, double oldPrice) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  // Initialize notifications
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  
  // Determine if price went up or down
  final isUp = newPrice > oldPrice;
  final diff = newPrice - oldPrice;
  final diffStr = _formatPrice(diff.abs());
  
  // Format prices
  final newPriceStr = _formatPrice(newPrice);
  final arrow = isUp ? '📈 +' : '📉 -';
  
  // Create notification
  const androidDetails = AndroidNotificationDetails(
    'gold_price_channel',
    'Giá Vàng',
    channelDescription: 'Thông báo khi giá vàng thay đổi',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/ic_launcher',
  );
  
  const notificationDetails = NotificationDetails(android: androidDetails);
  
  await flutterLocalNotificationsPlugin.show(
    999, // notification ID
    'Vàng Nhẫn Trơn 9999 $arrow$diffStr',
    'Giá bán: $newPriceStr đ',
    notificationDetails,
  );
  
  debugPrint('[BackgroundService] Notification sent: $newPriceStr ($arrow$diffStr)');
}

/// Format price to readable string
String _formatPrice(double price) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return formatter.format(price);
}

/// Show a simple notification (for reminders)
Future<void> _showSimpleNotification(int id, String title, String body) async {
  final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
  const initSettings = InitializationSettings(android: androidSettings);
  await flutterLocalNotificationsPlugin.initialize(initSettings);
  
  const androidDetails = AndroidNotificationDetails(
    'daily_reminder_channel',
    'Nhắc nhở',
    channelDescription: 'Thông báo nhắc nhở hằng ngày',
    importance: Importance.high,
    priority: Priority.high,
    icon: '@mipmap/launcher_icon',
  );
  
  const notificationDetails = NotificationDetails(android: androidDetails);
  await flutterLocalNotificationsPlugin.show(id, title, body, notificationDetails);
}

/// Schedule one-time reminder
Future<void> scheduleOneTimeReminder(Duration delay, String title, String body) async {
  await Workmanager().registerOneOffTask(
    'one_time_${DateTime.now().millisecondsSinceEpoch}',
    oneTimeReminderTask,
    initialDelay: delay,
    inputData: {'title': title, 'body': body},
    existingWorkPolicy: ExistingWorkPolicy.append,
  );
}

/// Schedule daily reminder
Future<void> scheduleDailyReminder(Duration delay, String title, String body) async {
  await Workmanager().registerOneOffTask(
    'daily_reminder_task',
    dailyReminderTask,
    initialDelay: delay,
    inputData: {'title': title, 'body': body},
    existingWorkPolicy: ExistingWorkPolicy.replace,
  );
  debugPrint('[BackgroundService] Daily reminder scheduled with delay: $delay');
}

/// Cancel all background tasks
Future<void> cancelAllBackgroundTasks() async {
  await Workmanager().cancelAll();
  debugPrint('[BackgroundService] All background tasks cancelled');
}
