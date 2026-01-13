import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/io_client.dart';
import 'dart:io';
import 'package:html/parser.dart' as parser;
import 'package:shared_preferences/shared_preferences.dart';

// Task name constants
const String goldPriceCheckTask = 'goldPriceCheckTask';
const String goldPriceUniqueTaskName = 'com.anhdo.goldprice.sync';

/// Initialize WorkManager for background gold price monitoring
Future<void> initializeBackgroundService() async {
  await Workmanager().initialize(
    callbackDispatcher,
    isInDebugMode: kDebugMode,
  );
  
  // Register periodic task - runs every 1 hour
  await Workmanager().registerPeriodicTask(
    goldPriceUniqueTaskName,
    goldPriceCheckTask,
    frequency: const Duration(hours: 1),
    constraints: Constraints(
      networkType: NetworkType.connected,
    ),
  );
  
  debugPrint('[BackgroundService] Initialized periodic gold price check (every 1 hour)');
}

/// Callback dispatcher - must be a top-level function
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[BackgroundService] Executing task: $taskName');
    
    if (taskName == goldPriceCheckTask) {
      try {
        await _checkGoldPriceAndNotify();
        return true;
      } catch (e) {
        debugPrint('[BackgroundService] Error: $e');
        return false;
      }
    }
    
    return true;
  });
}

/// Fetch gold price and send notification if changed
Future<void> _checkGoldPriceAndNotify() async {
  // Skip during quiet hours (00:00 - 08:00) to save battery
  final now = DateTime.now();
  if (now.hour >= 0 && now.hour < 8) {
    debugPrint('[BackgroundService] Quiet hours (00:00-08:00), skipping...');
    return;
  }

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
                
                // Save new price
                await prefs.setDouble('last_gold_sell_price', sellPrice);
                debugPrint('[BackgroundService] Saved new price: $sellPrice');
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
  if (price >= 1000000) {
    return '${(price / 1000000).toStringAsFixed(2)}tr';
  } else if (price >= 1000) {
    return '${(price / 1000).toStringAsFixed(0)}k';
  }
  return price.toStringAsFixed(0);
}
