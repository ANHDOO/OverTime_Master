---
name: notifications
description: Lập lịch và quản lý thông báo trong ứng dụng
---

# Skill: Notifications (Thông báo)

Patterns lập lịch và gửi thông báo đến người dùng.

## 🎯 Notification Types

| Loại | Mô tả | Trigger |
|------|-------|---------|
| **Daily Reminder** | Nhắc nhở hàng ngày | 22:00 hàng ngày |
| **Gold Price Alert** | Giá vàng thay đổi | Background task mỗi giờ |
| **Debt Reminder** | Khoản vay sắp đến hạn | Trước 3 ngày |

## 🔧 Technical Implementation

### Service: `NotificationService` (`lib/services/notification_service.dart`)

### Dependencies
```yaml
dependencies:
  flutter_local_notifications: ^17.2.3
  timezone: ^0.9.4
  workmanager: ^0.9.0
```

### 1. Initialization
```dart
await flutterLocalNotificationsPlugin.initialize(
  InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  ),
  onDidReceiveNotificationResponse: _onNotificationTap,
);
```

### 2. Schedule Daily Notification (Vietnam Time)
```dart
await flutterLocalNotificationsPlugin.zonedSchedule(
  notificationId,
  'Sổ Tay Công Việc',
  'Đừng quên ghi chép công việc hôm nay!',
  _nextInstanceOfTime(22, 0), // 22:00 Vietnam
  notificationDetails,
  androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  matchDateTimeComponents: DateTimeComponents.time,
  uiLocalNotificationDateInterpretation: 
    UILocalNotificationDateInterpretation.absoluteTime,
);
```

### 3. Timezone Configuration
```dart
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

tz.initializeTimeZones();
tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
```

### 4. Background Gold Price Check
```dart
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName == 'goldPriceCheckTask') {
      await _checkGoldPriceAndNotify();
    }
    return true;
  });
}
```

## 🔔 Notification Channels (Android)

```dart
const androidDetails = AndroidNotificationDetails(
  'daily_reminder_channel',
  'Nhắc nhở hàng ngày',
  channelDescription: 'Thông báo nhắc nhở ghi chép công việc',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@mipmap/ic_launcher',
);
```

## ⚠️ Constraints

- **Permissions:** Request notification permission trước khi schedule
- **Quiet Hours:** Skip notifications từ 00:00 - 08:00
- **Battery:** Dùng `inexactAllowWhileIdle` để tiết kiệm pin
- **Deep Links:** Handle notification tap để navigate đến screen phù hợp

---
*OverTime_Master Agent Skills v1.4.0*
