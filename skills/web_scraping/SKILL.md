---
name: web_scraping
description: Cào dữ liệu thị trường từ các website Việt Nam (giá vàng, xăng, tỷ giá)
---

# Skill: Web Scraping (Cào dữ liệu Web)

Patterns cào dữ liệu thị trường real-time từ các nguồn Việt Nam.

## 🎯 Data Sources

| Nguồn | URL | Dữ liệu |
|-------|-----|---------|
| **Giá Vàng** | giavangmaothiet.com | Vàng Mao Thiết, SJC |
| **Tỷ Giá** | Vietcombank XML API | USD, EUR, JPY... |
| **Giá Xăng** | pvoil.com.vn | RON 95, E5, DO |

## 🔧 Technical Implementation

### Service: `InfoService` (`lib/services/info_service.dart`)

### 1. HTTP Client with SSL Bypass
```dart
final _client = IOClient(
  HttpClient()..badCertificateCallback = 
    (X509Certificate cert, String host, int port) => true,
);
```

### 2. HTML Parsing với `html` package
```dart
import 'package:html/parser.dart' as parser;

final response = await _client.get(Uri.parse(url));
var document = parser.parse(response.body);
var table = document.querySelector('table.goldbox-table');
var rows = table.querySelectorAll('tbody tr');
```

### 3. XML Parsing với Regex (không dùng xml package)
```dart
// Vietcombank API trả về XML
final exrateRegex = RegExp(
  r'<Exrate\s+CurrencyCode="([^"]*)"[^>]*Buy="([^"]*)"'
);
final matches = exrateRegex.allMatches(xmlString);
```

## 📊 Data Models

### Gold Price
```dart
{
  'type': 'Vàng Nhẫn Trơn 9999',
  'buy': '8,750,000',
  'sell': '8,850,000',
}
```

### Exchange Rate
```dart
{
  'code': 'USD',
  'name': 'Đô la Mỹ',
  'buy': '24,685',
  'sell': '25,025',
  'transfer': '24,965',
}
```

## 🔔 Background Monitoring

### WorkManager Integration (`background_service.dart`)
```dart
await Workmanager().registerPeriodicTask(
  'goldPriceSync',
  'goldPriceCheckTask', 
  frequency: Duration(hours: 1),
  constraints: Constraints(networkType: NetworkType.connected),
);
```

### Notification on Price Change
- So sánh giá mới với giá cũ trong SharedPreferences
- Gửi notification nếu có thay đổi
- Skip quiet hours (00:00 - 08:00)

## ⚠️ Constraints

- **Timeout:** Set 10-15 giây cho mỗi request
- **Error Handling:** Wrap trong try-catch và return empty list on failure
- **Rate Limiting:** Không request quá 1 lần/giờ cho background tasks
- **SSL Issues:** Một số site VN có certificate không hợp lệ, cần bypass

---
*OverTime_Master Agent Skills v1.4.0*
