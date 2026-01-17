import 'package:excel/excel.dart' as excel_pkg;
import 'package:syncfusion_flutter_xlsio/xlsio.dart' hide Column, Alignment, Border, Row;
import 'package:flutter/material.dart' hide Border, BorderStyle;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:convert';
import '../models/overtime_entry.dart';
import '../models/cash_transaction.dart';
import '../../core/utils/overtime_calculator.dart';

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
    final excel = excel_pkg.Excel.createExcel();
    final sheetName = 'Tăng ca T${month.toString().padLeft(2, '0')}-$year';
    excel.rename('Sheet1', sheetName);
    final sheet = excel[sheetName];
    
    // === HEADER THÔNG TIN ===
    
    // Tiêu đề
    sheet.merge(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0), 
                excel_pkg.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: 0));
    final titleCell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0));
    titleCell.value = excel_pkg.TextCellValue('BẢNG CHẤM CÔNG TĂNG CA - THÁNG $month/$year');
    titleCell.cellStyle = excel_pkg.CellStyle(
      bold: true,
      fontSize: 16,
      fontFamily: 'Times New Roman',
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
    );
    
    // Thông tin nhân viên - style with Times New Roman
    final infoStyle = excel_pkg.CellStyle(fontFamily: 'Times New Roman', fontSize: 11);
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 2))
      ..value = excel_pkg.TextCellValue('Họ và tên:')
      ..cellStyle = infoStyle;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 2))
      ..value = excel_pkg.TextCellValue(employeeName)
      ..cellStyle = infoStyle;
    
    if (employeeId != null) {
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: 2))
        ..value = excel_pkg.TextCellValue('Mã NV:')
        ..cellStyle = infoStyle;
      sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 2))
        ..value = excel_pkg.TextCellValue(employeeId)
        ..cellStyle = infoStyle;
    }
    
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 3))
      ..value = excel_pkg.TextCellValue('Ngày xuất:')
      ..cellStyle = infoStyle;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: 3))
      ..value = excel_pkg.TextCellValue(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()))
      ..cellStyle = infoStyle;
    
    // === BORDERS & STYLES ===
    final excel_pkg.Border thinBorder = excel_pkg.Border(
      borderStyle: excel_pkg.BorderStyle.Thin,
    );

    // Header Style
    final tableHeaderStyle = excel_pkg.CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: 'Times New Roman',
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#4472C4'),
      fontColorHex: excel_pkg.ExcelColor.fromHexString('#FFFFFF'),
      topBorder: thinBorder,
      bottomBorder: thinBorder,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );

    // Data Styles
    final dataStyleCenter = excel_pkg.CellStyle(
      fontFamily: 'Times New Roman', 
      fontSize: 11,
      horizontalAlign: excel_pkg.HorizontalAlign.Center,
      verticalAlign: excel_pkg.VerticalAlign.Center,
      topBorder: thinBorder,
      bottomBorder: thinBorder,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );
    
    final dataStyleRight = excel_pkg.CellStyle(
      fontFamily: 'Times New Roman', 
      fontSize: 11,
      horizontalAlign: excel_pkg.HorizontalAlign.Right,
      verticalAlign: excel_pkg.VerticalAlign.Center,
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
      final cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: headerRow));
      cell.value = excel_pkg.TextCellValue(headers[i]);
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
              excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: startRow),
              excel_pkg.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow - 1),
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
    final summaryStyle = excel_pkg.CellStyle(
      bold: true,
      fontSize: 11,
      fontFamily: 'Times New Roman',
      backgroundColorHex: excel_pkg.ExcelColor.fromHexString('#D9E2F3'),
      topBorder: thinBorder,
      bottomBorder: thinBorder,
      leftBorder: thinBorder,
      rightBorder: thinBorder,
    );
    
    sheet.merge(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow), 
                excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: summaryRow));
    final summaryLabelCell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: summaryRow));
    summaryLabelCell.value = excel_pkg.TextCellValue('TỔNG CỘNG');
    summaryLabelCell.cellStyle = summaryStyle;
    
    final total15Cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: summaryRow));
    total15Cell.value = excel_pkg.DoubleCellValue(total15);
    total15Cell.cellStyle = summaryStyle;
    
    final total18Cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: summaryRow));
    total18Cell.value = excel_pkg.DoubleCellValue(total18);
    total18Cell.cellStyle = summaryStyle;
    
    final total20Cell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: summaryRow));
    total20Cell.value = excel_pkg.DoubleCellValue(total20);
    total20Cell.cellStyle = summaryStyle;
    
    final totalAllCell = sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: summaryRow));
    totalAllCell.value = excel_pkg.DoubleCellValue(total15 + total18 + total20);
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
    required excel_pkg.Sheet sheet,
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
    required excel_pkg.CellStyle styleCenter,
    required excel_pkg.CellStyle styleRight,
  }) {
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row))
      ..value = excel_pkg.TextCellValue(stt)
      ..cellStyle = styleCenter;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row))
      ..value = excel_pkg.TextCellValue(date)
      ..cellStyle = styleCenter;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row))
      ..value = excel_pkg.TextCellValue(dayOfWeek)
      ..cellStyle = styleCenter;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row))
      ..value = excel_pkg.TextCellValue(startTime)
      ..cellStyle = styleCenter;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row))
      ..value = excel_pkg.TextCellValue(endTime)
      ..cellStyle = styleCenter;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row))
      ..value = excel_pkg.TextCellValue(otType)
      ..cellStyle = styleCenter;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: row))
      ..value = excel_pkg.DoubleCellValue(h15)
      ..cellStyle = styleRight;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: row))
      ..value = excel_pkg.DoubleCellValue(h18)
      ..cellStyle = styleRight;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: row))
      ..value = excel_pkg.DoubleCellValue(h20)
      ..cellStyle = styleRight;
    sheet.cell(excel_pkg.CellIndex.indexByColumnRow(columnIndex: 9, rowIndex: row))
      ..value = excel_pkg.DoubleCellValue(total)
      ..cellStyle = styleRight;
  }

  /// Xuất phiếu giải chi theo dự án cho kế toán (Sử dụng Syncfusion để hỗ trợ chèn ảnh)
  static Future<void> exportCashFlowForAccounting({
    required BuildContext context,
    required List<CashTransaction> transactions,
    required String project,
    required int month,
    required int year,
    String employeeName = 'Lý Anh Đô',
  }) async {
    // Lọc giao dịch theo dự án, tháng/năm và loại là Chi ra
    final filteredTransactions = transactions.where((t) => 
      t.project == project && 
      t.date.month == month && 
      t.date.year == year &&
      t.type == TransactionType.expense
    ).toList();

    // Tính tổng thu nhập (Đã nhận) cho dự án/tháng này
    final totalIncome = transactions.where((t) => 
      t.project == project && 
      t.date.month == month && 
      t.date.year == year &&
      t.type == TransactionType.income
    ).fold<double>(0, (sum, t) => sum + t.amount);
    
    if (filteredTransactions.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Không có dữ liệu chi ra cho dự án $project trong tháng $month/$year')),
        );
      }
      return;
    }
    
    // Sắp xếp theo ngày
    filteredTransactions.sort((a, b) => a.date.compareTo(b.date));
    
    // Tạo Workbook
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.name = 'GiaiChi_$project';
    
    // Tạo sheet Chứng từ
    final Worksheet imageSheet = workbook.worksheets.addWithName('Chứng từ');
    
    // === STYLES ===
    final Style titleStyle = workbook.styles.add('titleStyle');
    titleStyle.bold = true;
    titleStyle.fontSize = 16;
    titleStyle.fontName = 'Times New Roman';
    titleStyle.hAlign = HAlignType.center;

    final Style headerInfoStyle = workbook.styles.add('headerInfoStyle');
    headerInfoStyle.fontName = 'Times New Roman';
    headerInfoStyle.fontSize = 11;
    headerInfoStyle.bold = true;

    final Style tableHeaderStyle = workbook.styles.add('tableHeaderStyle');
    tableHeaderStyle.bold = true;
    tableHeaderStyle.fontSize = 11;
    tableHeaderStyle.fontName = 'Times New Roman';
    tableHeaderStyle.hAlign = HAlignType.center;
    tableHeaderStyle.vAlign = VAlignType.center;
    tableHeaderStyle.backColor = '#D9E2F3';
    tableHeaderStyle.borders.all.lineStyle = LineStyle.thin;

    final Style dataStyleCenter = workbook.styles.add('dataStyleCenter');
    dataStyleCenter.fontName = 'Times New Roman';
    dataStyleCenter.fontSize = 11;
    dataStyleCenter.hAlign = HAlignType.center;
    dataStyleCenter.vAlign = VAlignType.center;
    dataStyleCenter.borders.all.lineStyle = LineStyle.thin;

    final Style dataStyleLeft = workbook.styles.add('dataStyleLeft');
    dataStyleLeft.fontName = 'Times New Roman';
    dataStyleLeft.fontSize = 11;
    dataStyleLeft.hAlign = HAlignType.left;
    dataStyleLeft.vAlign = VAlignType.center;
    dataStyleLeft.borders.all.lineStyle = LineStyle.thin;

    final Style dataStyleRight = workbook.styles.add('dataStyleRight');
    dataStyleRight.fontName = 'Times New Roman';
    dataStyleRight.fontSize = 11;
    dataStyleRight.hAlign = HAlignType.right;
    dataStyleRight.vAlign = VAlignType.center;
    dataStyleRight.borders.all.lineStyle = LineStyle.thin;
    dataStyleRight.numberFormat = '#,###';

    final Style linkStyle = workbook.styles.add('linkStyle');
    linkStyle.fontName = 'Times New Roman';
    linkStyle.fontSize = 11;
    linkStyle.fontColor = '#0563C1';
    linkStyle.underline = true;
    linkStyle.hAlign = HAlignType.center;
    linkStyle.vAlign = VAlignType.center;
    linkStyle.borders.all.lineStyle = LineStyle.thin;

    // === HEADER ===
    sheet.getRangeByIndex(1, 1).text = 'CÔNG TY TNHH THƯƠNG MẠI DỊCH VỤ TƯ VẤN TIẾN PHÁT';
    sheet.getRangeByIndex(1, 1).cellStyle = headerInfoStyle;
    sheet.getRangeByIndex(2, 1).text = 'Địa chỉ: 17/3 Tam Bình, Kp66, P. Hiệp Bình, TP. Hồ Chí Minh';
    sheet.getRangeByIndex(2, 1).cellStyle = workbook.styles.add('normalInfoStyle')..fontName = 'Times New Roman'..fontSize = 11;

    sheet.getRangeByIndex(4, 1, 4, 10).merge();
    final Range titleRange = sheet.getRangeByIndex(4, 1);
    titleRange.text = 'PHIẾU GIẢI CHI';
    titleRange.cellStyle = titleStyle;

    sheet.getRangeByIndex(6, 1).text = 'Người đề xuất: $employeeName';
    sheet.getRangeByIndex(7, 1).text = 'Ngày đề xuất: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}';
    sheet.getRangeByIndex(8, 1).text = 'Lý do: Giải chi vật tư thi công dự án $project';
    sheet.getRangeByIndex(9, 1).text = 'Gói: $project';

    // === TABLE HEADER ===
    final headers = ['STT', 'Tên vật tư/thiết bị', 'Đơn vị tính', 'Số lượng', 'Đơn giá', 'Thuế (%)', 'Thành tiền', 'Ghi chú', 'Nhà cung cấp', 'Chứng từ'];
    for (var i = 0; i < headers.length; i++) {
      final Range cell = sheet.getRangeByIndex(11, i + 1);
      cell.text = headers[i];
      cell.cellStyle = tableHeaderStyle;
    }

    // === DATA ROWS ===
    double totalAmount = 0;
    int currentRow = 12;
    int imageRow = 1;

    // Nhóm theo nhà cung cấp
    filteredTransactions.sort((a, b) => (a.note ?? '').compareTo(b.note ?? ''));

    for (int i = 0; i < filteredTransactions.length; i++) {
      final t = filteredTransactions[i];
      final taxRate = t.taxRate;
      final total = t.amount;
      final unitPriceBeforeTax = total / (1 + taxRate / 100);
      
      sheet.getRangeByIndex(currentRow, 1).setText((i + 1).toString());
      sheet.getRangeByIndex(currentRow, 1).cellStyle = dataStyleCenter;
      
      sheet.getRangeByIndex(currentRow, 2).setText(t.description);
      sheet.getRangeByIndex(currentRow, 2).cellStyle = dataStyleLeft;
      
      sheet.getRangeByIndex(currentRow, 3).setText('Gói');
      sheet.getRangeByIndex(currentRow, 3).cellStyle = dataStyleCenter;
      
      sheet.getRangeByIndex(currentRow, 4).setNumber(1);
      sheet.getRangeByIndex(currentRow, 4).cellStyle = dataStyleCenter;
      
      sheet.getRangeByIndex(currentRow, 5).setNumber(unitPriceBeforeTax.roundToDouble());
      sheet.getRangeByIndex(currentRow, 5).cellStyle = dataStyleRight;
      
      sheet.getRangeByIndex(currentRow, 6).setText('$taxRate%');
      sheet.getRangeByIndex(currentRow, 6).cellStyle = dataStyleCenter;
      
      sheet.getRangeByIndex(currentRow, 7).setNumber(total.roundToDouble());
      sheet.getRangeByIndex(currentRow, 7).cellStyle = dataStyleRight;
      
      sheet.getRangeByIndex(currentRow, 8).setText('Đã thanh toán');
      sheet.getRangeByIndex(currentRow, 8).cellStyle = dataStyleCenter;
      
      sheet.getRangeByIndex(currentRow, 9).setText(t.note ?? '');
      sheet.getRangeByIndex(currentRow, 9).cellStyle = dataStyleCenter;

      // Xử lý ảnh và Hyperlink
      if (t.imagePath != null && File(t.imagePath!).existsSync()) {
        final String cellRef = 'Chứng từ!A$imageRow';
        sheet.hyperlinks.add(sheet.getRangeByIndex(currentRow, 10), HyperlinkType.workbook, cellRef);
        sheet.getRangeByIndex(currentRow, 10).setText('Xem ảnh');
        sheet.getRangeByIndex(currentRow, 10).cellStyle = linkStyle;

        // Ghi thông tin vào sheet Chứng từ
        imageSheet.getRangeByIndex(imageRow, 1).text = 'STT: ${i + 1}';
        imageSheet.getRangeByIndex(imageRow, 1).cellStyle = headerInfoStyle;
        imageSheet.getRangeByIndex(imageRow + 1, 1).text = 'Nội dung: ${t.description}';
        
        // Chèn ảnh
        final List<int> imageBytes = File(t.imagePath!).readAsBytesSync();
        final Picture picture = imageSheet.pictures.addStream(imageRow + 2, 1, imageBytes);
        
        // Tự động điều chỉnh kích thước (giữ nguyên chất lượng nhưng scale hiển thị)
        picture.height = 400;
        picture.width = 300;

        // Link quay lại sheet chính
        imageSheet.hyperlinks.add(imageSheet.getRangeByIndex(imageRow, 2), HyperlinkType.workbook, '${sheet.name}!A$currentRow');
        imageSheet.getRangeByIndex(imageRow, 2).text = '[Quay lại]';
        imageSheet.getRangeByIndex(imageRow, 2).cellStyle = linkStyle;

        imageRow += 25; // Khoảng cách giữa các ảnh
      } else {
        sheet.getRangeByIndex(currentRow, 10).setText('Không có');
        sheet.getRangeByIndex(currentRow, 10).cellStyle = dataStyleCenter;
      }
      
      totalAmount += total;
      currentRow++;
    }

    // === FOOTER ===
    final Style footerStyle = workbook.styles.add('footerStyle');
    footerStyle.bold = true;
    footerStyle.fontName = 'Times New Roman';
    footerStyle.fontSize = 11;
    footerStyle.borders.all.lineStyle = LineStyle.thin;

    final Style footerStyleRight = workbook.styles.add('footerStyleRight');
    footerStyleRight.bold = true;
    footerStyleRight.fontName = 'Times New Roman';
    footerStyleRight.fontSize = 11;
    footerStyleRight.hAlign = HAlignType.right;
    footerStyleRight.borders.all.lineStyle = LineStyle.thin;
    footerStyleRight.numberFormat = '#,###';

    // Tổng cộng
    sheet.getRangeByIndex(currentRow, 1, currentRow, 6).merge();
    sheet.getRangeByIndex(currentRow, 1).text = 'Tổng';
    sheet.getRangeByIndex(currentRow, 1).cellStyle = footerStyle;
    sheet.getRangeByIndex(currentRow, 7).setNumber(totalAmount.roundToDouble());
    sheet.getRangeByIndex(currentRow, 7).cellStyle = footerStyleRight;

    currentRow++;
    sheet.getRangeByIndex(currentRow, 1, currentRow, 6).merge();
    sheet.getRangeByIndex(currentRow, 1).text = 'Đã nhận';
    sheet.getRangeByIndex(currentRow, 1).cellStyle = footerStyle;
    sheet.getRangeByIndex(currentRow, 7).setNumber(totalIncome.roundToDouble());
    sheet.getRangeByIndex(currentRow, 7).cellStyle = footerStyleRight;

    currentRow++;
    sheet.getRangeByIndex(currentRow, 1, currentRow, 6).merge();
    sheet.getRangeByIndex(currentRow, 1).text = 'Còn';
    sheet.getRangeByIndex(currentRow, 1).cellStyle = footerStyle;
    sheet.getRangeByIndex(currentRow, 7).setNumber((totalIncome - totalAmount).roundToDouble());
    sheet.getRangeByIndex(currentRow, 7).cellStyle = footerStyleRight;

    // === ĐỘ RỘNG CỘT ===
    sheet.setColumnWidthInPixels(1, 40);
    sheet.setColumnWidthInPixels(2, 250);
    sheet.setColumnWidthInPixels(3, 60);
    sheet.setColumnWidthInPixels(4, 50);
    sheet.setColumnWidthInPixels(5, 100);
    sheet.setColumnWidthInPixels(6, 60);
    sheet.setColumnWidthInPixels(7, 100);
    sheet.setColumnWidthInPixels(8, 100);
    sheet.setColumnWidthInPixels(9, 150);
    sheet.setColumnWidthInPixels(10, 80);

    imageSheet.setColumnWidthInPixels(1, 400);

    // Chữ ký
    currentRow += 2;
    sheet.getRangeByIndex(currentRow, 2).text = 'Người Đề Xuất';
    sheet.getRangeByIndex(currentRow, 2).cellStyle = headerInfoStyle;
    sheet.getRangeByIndex(currentRow, 7).text = 'Thủ Quỹ';
    sheet.getRangeByIndex(currentRow, 7).cellStyle = headerInfoStyle;

    currentRow += 4;
    sheet.getRangeByIndex(currentRow, 2).text = employeeName;
    sheet.getRangeByIndex(currentRow, 7).text = 'Phan Thu Uyên';

    // === LƯU VÀ SHARE ===
    try {
      final List<int> bytes = workbook.saveAsStream();
      workbook.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'PhieuGiaiChi_${project}_T${month}_$year.xlsx';
      final filePath = '${directory.path}/$fileName';
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      if (context.mounted) {
        _showFileActionSheet(context, filePath, fileName);
      }
    } catch (e) {
      debugPrint('Error saving Excel: $e');
    }
  }
}
