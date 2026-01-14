import 'package:excel/excel.dart';
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import '../models/overtime_entry.dart';
import '../utils/overtime_calculator.dart';

class ExcelService {
  /// Xuất báo cáo tăng ca theo tháng cho kế toán (không tính tiền)
  static Future<void> exportOvertimeForAccounting({
    required BuildContext context,
    required List<OvertimeEntry> entries,
    required int month,
    required int year,
    String employeeName = 'Anh Đô',
    String? employeeId,
  }) async {
    // Lọc entries theo tháng/năm
    final monthEntries = entries.where((e) => 
      e.date.month == month && e.date.year == year
    ).toList();
    
    if (monthEntries.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không có dữ liệu tăng ca trong tháng này')),
        );
      }
      return;
    }
    
    // Sắp xếp theo ngày
    monthEntries.sort((a, b) => a.date.compareTo(b.date));
    
    // Tạo Excel workbook
    final excel = Excel.createExcel();
    final sheetName = 'Tăng ca T${month.toString().padLeft(2, '0')}-$year';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    
    // === HEADER THÔNG TIN ===
    
    // Tiêu đề
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0));
    final titleCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = TextCellValue('BẢNG CHẤM CÔNG TĂNG CA - THÁNG $month/$year');
    titleCell.cellStyle = CellStyle(
      bold: true,
      fontSize: 16,
      fontFamily: 'Times New Roman',
      horizontalAlign: HorizontalAlign.Center,
    );
    
    // Thông tin nhân viên - style with Times New Roman
    final infoStyle = CellStyle(fontFamily: 'Times New Roman', fontSize: 11);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      ..value = TextCellValue('Họ và tên:')
      ..cellStyle = infoStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2))
      ..value = TextCellValue(employeeName)
      ..cellStyle = infoStyle;
    
    if (employeeId != null) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2))
        ..value = TextCellValue('Mã NV:')
        ..cellStyle = infoStyle;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2))
        ..value = TextCellValue(employeeId)
        ..cellStyle = infoStyle;
    }
    
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
      ..value = TextCellValue('Ngày xuất:')
      ..cellStyle = infoStyle;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3))
      ..value = TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))
      ..cellStyle = infoStyle;
    
    // === BORDERS & STYLES ===
    final Border thinBorder = Border(
      borderStyle: BorderStyle.Thin,
    );

    // Header Style
    final tableHeaderStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: 'Times New Roman',
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      backgroundColorHex: ExcelColor.fromHexString('#4472C4'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
      topBorder: thinBorder,
      bottomBorder: thinBorder,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );

    // Data Styles
    final dataStyleCenter = CellStyle(
      fontFamily: 'Times New Roman', 
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );
    
    final dataStyleRight = CellStyle(
      fontFamily: 'Times New Roman', 
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );
    
    final headers = [
      'STT',
      'Ngày',
      'Thứ',
      'Giờ vào',
      'Giờ ra',
      'Loại OT',
      'Số giờ 1.5x',
      'Số giờ 1.8x', 
      'Số giờ 2.0x',
      'Tổng giờ',
    ];
    
    const headerRow = 5;
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow));
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = tableHeaderStyle;
    }
    
    // === DATA ROWS ===
    final weekDays = ['', 'Thứ 2', 'Thứ 3', 'Thứ 4', 'Thứ 5', 'Thứ 6', 'Thứ 7', 'CN'];
    
    double total15 = 0, total18 = 0, total20 = 0;
    int currentRow = headerRow + 1;
    int sttCounter = 1;
    
    for (var entry in monthEntries) {
      List<dynamic> shifts = [];
      if (entry.shiftsJson != null) {
        try {
          shifts = jsonDecode(entry.shiftsJson!);
        } catch (_) {}
      }

      if (shifts.isEmpty) {
        // --- Single Shift Case ---
        String otType = entry.isSunday ? 'Chủ nhật' : (entry.hours18 > 0 ? 'Đêm' : 'Chiều');
        final totalHours = entry.hours15 + entry.hours18 + entry.hours20;

        _writeExcelRow(
          sheet: sheet,
          row: currentRow,
          stt: sttCounter.toString(),
          date: DateFormat('dd/MM/yyyy').format(entry.date),
          dayOfWeek: weekDays[entry.date.weekday],
          startTime: '${entry.startTime.hour.toString().padLeft(2, '0')}:${entry.startTime.minute.toString().padLeft(2, '0')}',
          endTime: '${entry.endTime.hour.toString().padLeft(2, '0')}:${entry.endTime.minute.toString().padLeft(2, '0')}',
          otType: otType,
          h15: entry.hours15,
          h18: entry.hours18,
          h20: entry.hours20,
          total: totalHours,
          styleCenter: dataStyleCenter,
          styleRight: dataStyleRight,
        );
        
        currentRow++;
      } else {
        // --- Multi Shift Case ---
        final int startRow = currentRow;
        for (int i = 0; i < shifts.length; i++) {
          final shiftData = shifts[i];
          final startTime = TimeOfDay(hour: shiftData['start_hour'], minute: shiftData['start_minute']);
          final endTime = TimeOfDay(hour: shiftData['end_hour'], minute: shiftData['end_minute']);
          
          final calc = OvertimeCalculator.calculateHours(
            date: entry.date,
            startTime: startTime,
            endTime: endTime,
            hourlyRate: entry.hourlyRate,
          );

          String otType = entry.isSunday ? 'Chủ nhật' : (calc['hours18']! > 0 ? 'Đêm' : 'Chiều');
          final totalHours = calc['hours15']! + calc['hours18']! + calc['hours20']!;

          _writeExcelRow(
            sheet: sheet,
            row: currentRow,
            stt: i == 0 ? sttCounter.toString() : '',
            date: i == 0 ? DateFormat('dd/MM/yyyy').format(entry.date) : '',
            dayOfWeek: i == 0 ? weekDays[entry.date.weekday] : '',
            startTime: '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
            endTime: '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
            otType: otType,
            h15: calc['hours15']!,
            h18: calc['hours18']!,
            h20: calc['hours20']!,
            total: totalHours,
            styleCenter: dataStyleCenter,
            styleRight: dataStyleRight,
          );
          
          currentRow++;
        }
        
        // Merge STT, Ngày, Thứ for multi-shift entry
        if (shifts.length > 1) {
          for (int col = 0; col <= 2; col++) {
            sheet.merge(
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: startRow),
              CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow - 1),
            );
          }
        }
      }
      
      total15 += entry.hours15;
      total18 += entry.hours18;
      total20 += entry.hours20;
      sttCounter++;
    }
    
    // === TỔNG CỘNG ===
    final summaryRow = currentRow + 1;
    final summaryStyle = CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: 'Times New Roman',
      backgroundColorHex: ExcelColor.fromHexString('#D9E2F3'),
      topBorder: thinBorder,
      bottomBorder: thinBorder,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );
    
    sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow), 
                CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: summaryRow));
    final summaryLabelCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow));
    summaryLabelCell.value = TextCellValue('TỔNG CỘNG');
    summaryLabelCell.cellStyle = summaryStyle;
    
    final total15Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: summaryRow));
    total15Cell.value = DoubleCellValue(total15);
    total15Cell.cellStyle = summaryStyle;
    
    final total18Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: summaryRow));
    total18Cell.value = DoubleCellValue(total18);
    total18Cell.cellStyle = summaryStyle;
    
    final total20Cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: summaryRow));
    total20Cell.value = DoubleCellValue(total20);
    total20Cell.cellStyle = summaryStyle;
    
    final totalAllCell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: summaryRow));
    totalAllCell.value = DoubleCellValue(total15 + total18 + total20);
    totalAllCell.cellStyle = summaryStyle;
    
    // === THIẾT LẬP ĐỘ RỘNG CỘT ===
    sheet.setColumnWidth(0, 6);   // STT
    sheet.setColumnWidth(1, 12);  // Ngày
    sheet.setColumnWidth(2, 10);  // Thứ
    sheet.setColumnWidth(3, 10);  // Giờ vào
    sheet.setColumnWidth(4, 10);  // Giờ ra
    sheet.setColumnWidth(5, 12);  // Loại OT
    sheet.setColumnWidth(6, 12);  // 1.5x
    sheet.setColumnWidth(7, 12);  // 1.8x
    sheet.setColumnWidth(8, 12);  // 2.0x
    sheet.setColumnWidth(9, 12);  // Tổng
    
    // === LƯU VÀ SHARE FILE ===
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'TangCa_T${month.toString().padLeft(2, '0')}_$year.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      
      final fileBytes = excel.save();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        
        // Hiển thị bottom sheet với options
        if (context.mounted) {
          _showFileActionSheet(context, filePath, fileName);
        }
      }
    } catch (e) {
      debugPrint('Error saving Excel: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi xuất file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Hiển thị bottom sheet cho phép share hoặc mở file
  static void _showFileActionSheet(BuildContext context, String filePath, String fileName) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xuất file thành công!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        fileName,
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Share button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await _shareFile(context, filePath, fileName);
                },
                icon: const Icon(Icons.share),
                label: const Text('Chia sẻ qua Zalo, Email...'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Open button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await OpenFile.open(filePath);
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Mở file'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
  
  /// Share file bằng share_plus
  static Future<void> _shareFile(BuildContext context, String filePath, String fileName) async {
    try {
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        subject: 'Báo cáo tăng ca - $fileName',
        text: 'Đính kèm file báo cáo tăng ca: $fileName',
      );
      
      if (context.mounted && result.status == ShareResultStatus.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chia sẻ file thành công!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error sharing file: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi chia sẻ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Helper to write a data row to Excel
  static void _writeExcelRow({
    required Sheet sheet,
    required int row,
    required String stt,
    required String date,
    required String dayOfWeek,
    required String startTime,
    required String endTime,
    required String otType,
    required double h15,
    required double h18,
    required double h20,
    required double total,
    required CellStyle styleCenter,
    required CellStyle styleRight,
  }) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = TextCellValue(stt)
      ..cellStyle = styleCenter;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = TextCellValue(date)
      ..cellStyle = styleCenter;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
      ..value = TextCellValue(dayOfWeek)
      ..cellStyle = styleCenter;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
      ..value = TextCellValue(startTime)
      ..cellStyle = styleCenter;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
      ..value = TextCellValue(endTime)
      ..cellStyle = styleCenter;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
      ..value = TextCellValue(otType)
      ..cellStyle = styleCenter;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
      ..value = DoubleCellValue(h15)
      ..cellStyle = styleRight;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
      ..value = DoubleCellValue(h18)
      ..cellStyle = styleRight;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
      ..value = DoubleCellValue(h20)
      ..cellStyle = styleRight;
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
      ..value = DoubleCellValue(total)
      ..cellStyle = styleRight;
  }
}
