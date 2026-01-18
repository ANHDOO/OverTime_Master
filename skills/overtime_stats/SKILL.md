---
name: overtime_stats
description: Thống kê và phân tích dữ liệu tài chính trong ứng dụng OverTime
---

# Skill: Overtime Statistics (Thống kê Tăng ca)

Patterns phân tích và trực quan hóa dữ liệu tài chính nghề nghiệp trong OverTime_Master.

## 🎯 Domain Knowledge

| Khái niệm | Mô tả |
|-----------|-------|
| **Overtime Pay** | Tính theo giờ với hệ số nhân (1.5x, 2.0x, 3.0x) |
| **Cash Flow** | Theo dõi thu/chi theo từng dự án |
| **PIT** | Thuế TNCN theo bậc lương Việt Nam |

## 📊 Data Visualization

### Library: `fl_chart`

```dart
LineChartData(
  lineBarsData: [
    LineChartBarData(
      spots: monthlyData.map((e) => FlSpot(e.month, e.value)).toList(),
      isCurved: true,
      gradient: LinearGradient(colors: [Colors.blue, Colors.cyan]),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          colors: [Colors.blue.withOpacity(0.3), Colors.transparent],
        ),
      ),
    ),
  ],
)
```

### Premium Styling
- Đường cong mượt (isCurved: true)
- Gradient fill dưới đường
- Custom tooltips với font hệ thống
- 8px grid cho legends và axes

## 🧮 Calculation Logic

### OT Calculator (`overtime_calculator.dart`)
```dart
double calculateOTPay(double hours, double hourlyRate, OTType type) {
  final multiplier = switch(type) {
    OTType.weekday => 1.5,
    OTType.weekend => 2.0,
    OTType.holiday => 3.0,
  };
  return hours * hourlyRate * multiplier;
}
```

### PIT Calculator (`pit_calculator_screen.dart`)
- Áp dụng bậc thuế TNCN Việt Nam
- Trừ giảm trừ gia cảnh (11 triệu/người phụ thuộc)

## 🎨 UI Patterns (Pro Max)

### Summary Cards
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: isIncome 
        ? [Colors.green[400]!, Colors.green[600]!]
        : [Colors.red[400]!, Colors.red[600]!],
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [BoxShadow(blurRadius: 12, offset: Offset(0, 4))],
  ),
)
```

### Tabbed Layout
- Tab 1: OT Stats (Thống kê tăng ca)
- Tab 2: Cash Flow (Dòng tiền)

## ⚠️ Constraints

- **Privacy:** Aggregate data trước khi hiển thị
- **Performance:** Dùng `ListView.builder` cho danh sách dài
- **Precision:** Dùng 2 số thập phân cho tiền tệ

---
*OverTime_Master Agent Skills v1.4.0*
