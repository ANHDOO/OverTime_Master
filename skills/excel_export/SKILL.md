---
name: excel_export
description: Xuất báo cáo kế toán ra file Excel
---

# Skill: Excel Export (Xuất Excel)

Patterns tạo và chia sẻ file Excel cho báo cáo kế toán.

## 🎯 Use Cases

1. **Tổng hợp OT theo tháng** - Báo cáo tăng ca đã tính lương
2. **Báo cáo thu chi** - Dòng tiền theo dự án
3. **Sao lưu dữ liệu** - Export toàn bộ entries

## 🔧 Technical Implementation

### Service: `ExcelService` (`lib/services/excel_service.dart`)

### Dependencies
```yaml
dependencies:
  excel: ^4.0.6
  path_provider: ^2.1.4
  share_plus: ^10.1.4
  open_file: ^3.3.2
```

### 1. Create Excel File
```dart
import 'package:excel/excel.dart';

final excel = Excel.createExcel();
final sheet = excel['Sheet1'];

// Header
sheet.appendRow(['STT', 'Ngày', 'Số giờ', 'Loại', 'Lương']);

// Data
for (var entry in entries) {
  sheet.appendRow([
    entry.index,
    DateFormat('dd/MM/yyyy').format(entry.date),
    entry.hours,
    entry.type,
    NumberFormat('#,###').format(entry.pay),
  ]);
}
```

### 2. Save to Device
```dart
final tempDir = await getTemporaryDirectory();
final filePath = '${tempDir.path}/report_${DateTime.now().millisecondsSinceEpoch}.xlsx';
final file = File(filePath);
await file.writeAsBytes(excel.encode()!);
```

### 3. Share File
```dart
await Share.shareXFiles(
  [XFile(filePath)],
  text: 'Báo cáo tăng ca tháng ${DateFormat('MM/yyyy').format(date)}',
);
```

### 4. Open Directly
```dart
await OpenFile.open(filePath, type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");
```

## 🎨 Formatting Tips

### Column Width
```dart
sheet.setColWidth(0, 10);  // STT
sheet.setColWidth(1, 15);  // Ngày
sheet.setColWidth(4, 20);  // Lương
```

### Cell Styling
```dart
final headerStyle = CellStyle(
  fontFamily: getFontFamily(FontFamily.Calibri),
  bold: true,
  horizontalAlign: HorizontalAlign.Center,
);
```

## ⚠️ Constraints

- **File Size:** Nên giới hạn ~1000 rows để tránh memory issues
- **Encoding:** Đảm bảo UTF-8 cho tiếng Việt
- **Cleanup:** Xóa file tạm sau khi share xong

---
*OverTime_Master Agent Skills v1.4.0*
