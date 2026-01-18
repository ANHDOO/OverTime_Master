---
name: citizen_lookup
description: Tra cứu thông tin công dân qua các cổng chính phủ Việt Nam
---

# Skill: Citizen Lookup (Tra cứu Công dân)

Hướng dẫn cho AI Agent thực hiện tra cứu dữ liệu công dân trong hệ sinh thái OverTime_Master.

## 🎯 Phạm vi

Skill này bao gồm tương tác với các cổng thông tin chính phủ và tiện ích công cộng Việt Nam:

| Service | Mô tả | File chính |
|---------|-------|------------|
| **MST** | Tra cứu Mã số thuế cá nhân/doanh nghiệp | `mst_search_screen.dart` |
| **BHXH** | Tra cứu lịch sử BHXH và thẻ BHYT | `bhxh_search_screen.dart` |
| **Phạt nguội** | Tra cứu vi phạm giao thông | `traffic_fine_search_screen.dart` |

## 🔧 Patterns Kỹ thuật

### 1. WebView Strategy
```dart
// Sử dụng webview_flutter để tương tác với portal
final controller = WebViewController()
  ..setJavaScriptMode(JavaScriptMode.unrestricted)
  ..setUserAgent("Mozilla/5.0 ...");
```

### 2. CAPTCHA Extraction Flow
```dart
// 1. Chờ ảnh CAPTCHA load hoàn toàn
for (int i = 0; i < 8; i++) {
  final status = await controller.runJavaScriptReturningResult('''
    (function() {
      var img = document.querySelector('img[src*="captcha"]');
      if (!img || !img.complete) return 'LOADING';
      return 'READY';
    })()
  ''');
  if (status == 'READY') break;
  await Future.delayed(Duration(milliseconds: 500));
}

// 2. Extract via Canvas (giữ session)
final base64 = await controller.runJavaScriptReturningResult('''
  var canvas = document.createElement('canvas');
  var ctx = canvas.getContext('2d');
  ctx.drawImage(img, 0, 0);
  canvas.toDataURL('image/png').split(',')[1];
''');
```

### 3. Form Submission (Click Simulation)
```dart
// Bấm nút thay vì form.submit() để trigger đầy đủ event handlers
await controller.runJavaScript('''
  var buttons = document.querySelectorAll('input[type="button"]');
  if(buttons.length > 0) buttons[0].click();
''');
```

## 🎨 UI Standards (Pro Max)

- **Glassmorphism:** Dùng `BackdropFilter` với `sigmaX/Y: 10`
- **8px Grid:** Mọi spacing phải là bội số của 8
- **Theme Consistency:** Dùng `Theme.of(context).colorScheme.primary`

## ⚠️ Constraints

- **Privacy:** KHÔNG log dữ liệu nhạy cảm (CCCD, Tên) ra console trong production
- **Retry Logic:** Các portal VN thường không ổn định, luôn implement exponential backoff
- **Session:** Đảm bảo dùng CÙNG MỘT WebViewController cho cả captcha extraction và form submission

---
*OverTime_Master Agent Skills v1.4.0*
