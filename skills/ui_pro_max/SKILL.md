---
name: ui_pro_max
description: Hướng dẫn thiết kế giao diện "Pro Max" cho ứng dụng Flutter
---

# Skill: UI Pro Max (Thiết kế Giao diện Cao cấp)

Standards thiết kế giao diện chất lượng cao cho ứng dụng Flutter.

## 🎨 Design Principles

### 1. Glassmorphism
```dart
ClipRRect(
  borderRadius: BorderRadius.circular(16),
  child: BackdropFilter(
    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
    child: Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
    ),
  ),
)
```

### 2. 8px Grid System
```dart
// ✅ Đúng - Bội số của 8
const EdgeInsets.all(16)
const EdgeInsets.symmetric(horizontal: 24, vertical: 8)
SizedBox(height: 32)

// ❌ Sai
const EdgeInsets.all(15)
SizedBox(height: 25)
```

### 3. Consistent Shadows
```dart
BoxShadow(
  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
  blurRadius: 16,
  offset: const Offset(0, 8),
)
```

## 🏗️ Component Patterns

### Premium AppBar
```dart
AppBar(
  title: Text('Title'),
  titleTextStyle: TextStyle(
    fontWeight: FontWeight.w900,
    fontSize: 16,
    letterSpacing: 1.2,
    color: Colors.white,
  ),
  backgroundColor: Theme.of(context).colorScheme.primary,
  foregroundColor: Colors.white,
  elevation: 0,
)
```

### Gradient Button
```dart
Container(
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(16),
    gradient: LinearGradient(
      colors: [primaryColor, primaryColor.withOpacity(0.8)],
    ),
    boxShadow: [
      BoxShadow(
        color: primaryColor.withOpacity(0.3),
        blurRadius: 12,
        offset: Offset(0, 4),
      ),
    ],
  ),
  child: ElevatedButton(...),
)
```

### Status Card
```dart
Container(
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: statusColor.withOpacity(0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: statusColor.withOpacity(0.2)),
  ),
  child: Row(
    children: [
      Icon(statusIcon, color: statusColor),
      SizedBox(width: 16),
      Expanded(child: Text(statusMessage)),
    ],
  ),
)
```

## 🎯 Typography

### System Default Font
```dart
// Tiêu đề
TextStyle(
  fontWeight: FontWeight.w900,
  fontSize: 18,
  letterSpacing: 0.5,
)

// Body
TextStyle(
  fontWeight: FontWeight.w500,
  fontSize: 14,
  height: 1.5,
)

// Caption
TextStyle(
  fontWeight: FontWeight.w400,
  fontSize: 12,
  color: Colors.grey[600],
)
```

### Number Display (Monospace feel)
```dart
TextStyle(
  fontWeight: FontWeight.w700,
  fontSize: 24,
  letterSpacing: 1.0,
  fontFeatures: [FontFeature.tabularFigures()],
)
```

## 🌈 Color Usage

```dart
// Primary actions
Theme.of(context).colorScheme.primary

// Success/Income
Colors.green[600]

// Error/Expense
Colors.red[600]

// Neutral backgrounds
Colors.grey[100] // Light mode
Colors.grey[900] // Dark mode

// KHÔNG hardcode hex colors - dùng Theme
```

## ⚠️ Constraints

- **Font:** Chỉ dùng system default font (đã gỡ GoogleFonts)
- **Colors:** Luôn dùng Theme colors, không hardcode hex
- **Spacing:** Luôn là bội số của 8
- **Border Radius:** Thống nhất 12-16 cho cards, 8 cho buttons nhỏ

---
*OverTime_Master Agent Skills v1.4.0*
