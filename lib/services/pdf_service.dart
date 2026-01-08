import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/overtime_entry.dart';
import '../models/debt_entry.dart';
import '../models/cash_transaction.dart';

class PdfService {
  static const String _appName = 'Note_OverTime';

  Future<void> generateOTReport({
    required BuildContext context,
    required List<OvertimeEntry> entries,
    required DateTime month,
    required double hourlyRate,
  }) async {
    // Helper function to format TimeOfDay
    String formatTimeOfDay(TimeOfDay time) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
    final pdf = pw.Document();

    // Font setup
    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    // Data preparation
    final monthEntries = entries.where((entry) {
      return entry.date.year == month.year && entry.date.month == month.month;
    }).toList();

    final totalPay = monthEntries.fold<double>(0, (sum, entry) => sum + entry.totalPay);
    final totalHours15 = monthEntries.fold<double>(0, (sum, entry) => sum + entry.hours15);
    final totalHours18 = monthEntries.fold<double>(0, (sum, entry) => sum + entry.hours18);
    final totalHours20 = monthEntries.fold<double>(0, (sum, entry) => sum + entry.hours20);

    // Currency formatter
    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_appName, style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.blue)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'BÁO CÁO LƯƠNG TĂNG CA',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                  pw.Text(
                    'Tháng ${DateFormat('MM/yyyy').format(month)}',
                    style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Ngày xuất: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                    style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary Section
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.blue50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.blue200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TỔNG KẾT', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.blue900)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Tổng lương OT', currencyFormat.format(totalPay), boldFont, font),
                      _buildSummaryItem('Số buổi', monthEntries.length.toString(), boldFont, font),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Giờ x1.5', '${totalHours15.toStringAsFixed(1)}h', boldFont, font),
                      _buildSummaryItem('Giờ x1.8', '${totalHours18.toStringAsFixed(1)}h', boldFont, font),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  _buildSummaryItem('Giờ x2.0 (CN)', '${totalHours20.toStringAsFixed(1)}h', boldFont, font),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Details Table
            pw.Text('CHI TIẾT CÁC BUỔI TĂNG CA', style: pw.TextStyle(font: boldFont, fontSize: 14)),
            pw.SizedBox(height: 12),

            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300),
              children: [
                // Header
                pw.TableRow(
                  decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                  children: [
                    _buildTableCell('Ngày', boldFont, isHeader: true),
                    _buildTableCell('Thời gian', boldFont, isHeader: true),
                    _buildTableCell('Loại', boldFont, isHeader: true),
                    _buildTableCell('Giờ x1.5', boldFont, isHeader: true),
                    _buildTableCell('Giờ x1.8', boldFont, isHeader: true),
                    _buildTableCell('Giờ x2.0', boldFont, isHeader: true),
                    _buildTableCell('Tổng tiền', boldFont, isHeader: true),
                  ],
                ),
                // Data rows
                ...monthEntries.map((entry) {
                  final timeFormat = DateFormat('HH:mm');
                  String typeText;
                  if (entry.isSunday) {
                    typeText = 'Chủ nhật';
                  } else if (entry.hours18 > 0) {
                    typeText = 'Đêm';
                  } else {
                    typeText = 'Chiều';
                  }

                  return pw.TableRow(
                    children: [
                      _buildTableCell(DateFormat('dd/MM/yyyy').format(entry.date), font),
                      _buildTableCell('${formatTimeOfDay(entry.startTime)} - ${formatTimeOfDay(entry.endTime)}', font),
                      _buildTableCell(typeText, font),
                      _buildTableCell(entry.hours15.toStringAsFixed(1), font),
                      _buildTableCell(entry.hours18.toStringAsFixed(1), font),
                      _buildTableCell(entry.hours20.toStringAsFixed(1), font),
                      _buildTableCell(currencyFormat.format(entry.totalPay), font, alignRight: true),
                    ],
                  );
                }).toList(),
              ],
            ),

            pw.SizedBox(height: 24),

            // Footer
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('THÔNG TIN THAM KHẢO', style: pw.TextStyle(font: boldFont, fontSize: 12)),
                  pw.SizedBox(height: 8),
                  pw.Text('• Lương/giờ cơ bản: ${currencyFormat.format(hourlyRate)}', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('• Hệ số tăng ca: 1.5x (17:30-22:00), 1.8x (sau 22:00), 2.0x (Chủ nhật)', style: pw.TextStyle(font: font, fontSize: 10)),
                  pw.Text('• Báo cáo được tạo tự động bởi ứng dụng $_appName', style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // Save and share
    await _saveAndSharePdf(pdf, 'BaoCao_OT_${DateFormat('MM_yyyy').format(month)}.pdf', context);
  }

  Future<void> generateDebtReport({
    required BuildContext context,
    required List<DebtEntry> debtEntries,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    final totalDebt = debtEntries.fold<double>(0, (sum, debt) => sum + debt.amount);
    final totalInterest = debtEntries.fold<double>(0, (sum, debt) => sum + debt.calculateInterest()['totalInterest']!);
    final paidDebts = debtEntries.where((debt) => debt.isPaid).toList();
    final unpaidDebts = debtEntries.where((debt) => !debt.isPaid).toList();

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_appName, style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.orange)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'BÁO CÁO LÃI NỢ LƯƠNG',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                  pw.Text(
                    'Tình hình đến ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.orange50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.orange200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TỔNG KẾT', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.orange900)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Tổng nợ gốc', currencyFormat.format(totalDebt), boldFont, font),
                      _buildSummaryItem('Tổng lãi', currencyFormat.format(totalInterest), boldFont, font),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Đã thanh toán', paidDebts.length.toString(), boldFont, font),
                      _buildSummaryItem('Chưa thanh toán', unpaidDebts.length.toString(), boldFont, font),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Unpaid Debts
            if (unpaidDebts.isNotEmpty) ...[
              pw.Text('CÁC KHOẢN NỢ CHƯA THANH TOÁN', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.red50),
                    children: [
                      _buildTableCell('Tháng nợ', boldFont, isHeader: true),
                      _buildTableCell('Gốc nợ', boldFont, isHeader: true),
                      _buildTableCell('Lãi cơ bản', boldFont, isHeader: true),
                      _buildTableCell('Lãi quá hạn', boldFont, isHeader: true),
                      _buildTableCell('Tổng phải trả', boldFont, isHeader: true),
                    ],
                  ),
                  ...unpaidDebts.map((debt) {
                    final interest = debt.calculateInterest();
                    return pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('MM/yyyy').format(debt.month), font),
                        _buildTableCell(currencyFormat.format(debt.amount), font, alignRight: true),
                        _buildTableCell(currencyFormat.format(interest['baseInterest']), font, alignRight: true),
                        _buildTableCell(currencyFormat.format(interest['extraInterest']), font, alignRight: true),
                        _buildTableCell(currencyFormat.format(debt.amount + interest['totalInterest']!), font, alignRight: true),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // Paid Debts
            if (paidDebts.isNotEmpty) ...[
              pw.Text('CÁC KHOẢN NỢ ĐÃ THANH TOÁN', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green50),
                    children: [
                      _buildTableCell('Tháng nợ', boldFont, isHeader: true),
                      _buildTableCell('Gốc nợ', boldFont, isHeader: true),
                      _buildTableCell('Ngày thanh toán', boldFont, isHeader: true),
                    ],
                  ),
                  ...paidDebts.map((debt) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('MM/yyyy').format(debt.month), font),
                        _buildTableCell(currencyFormat.format(debt.amount), font, alignRight: true),
                        _buildTableCell(debt.paidAt != null ? DateFormat('dd/MM/yyyy').format(debt.paidAt!) : '-', font),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          ];
        },
      ),
    );

    await _saveAndSharePdf(pdf, 'BaoCao_NoLuong_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf', context);
  }

  Future<void> generateCashFlowReport({
    required BuildContext context,
    required List<CashTransaction> transactions,
    required String project,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final pdf = pw.Document();

    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    final filteredTransactions = transactions.where((t) {
      return t.date.isAfter(startDate.subtract(const Duration(days: 1))) &&
             t.date.isBefore(endDate.add(const Duration(days: 1))) &&
             (project == 'Tất cả' || t.project == project);
    }).toList();

    final incomeTransactions = filteredTransactions.where((t) => t.type == TransactionType.income).toList();
    final expenseTransactions = filteredTransactions.where((t) => t.type == TransactionType.expense).toList();

    final totalIncome = incomeTransactions.fold<double>(0, (sum, t) => sum + t.amount);
    final totalExpense = expenseTransactions.fold<double>(0, (sum, t) => sum + t.amount);

    final currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Header(
              level: 0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(_appName, style: pw.TextStyle(font: boldFont, fontSize: 24, color: PdfColors.teal)),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'BÁO CÁO THU CHI',
                    style: pw.TextStyle(font: boldFont, fontSize: 18),
                  ),
                  pw.Text(
                    project == 'Tất cả' ? 'Tất cả dự án' : 'Dự án: $project',
                    style: pw.TextStyle(font: font, fontSize: 14, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Từ ${DateFormat('dd/MM/yyyy').format(startDate)} đến ${DateFormat('dd/MM/yyyy').format(endDate)}',
                    style: pw.TextStyle(font: font, fontSize: 12, color: PdfColors.grey600),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Summary
            pw.Container(
              padding: const pw.EdgeInsets.all(16),
              decoration: pw.BoxDecoration(
                color: PdfColors.teal50,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: PdfColors.teal200),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('TỔNG KẾT', style: pw.TextStyle(font: boldFont, fontSize: 14, color: PdfColors.teal900)),
                  pw.SizedBox(height: 12),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Tổng thu', currencyFormat.format(totalIncome), boldFont, font),
                      _buildSummaryItem('Tổng chi', currencyFormat.format(totalExpense), boldFont, font),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      _buildSummaryItem('Số giao dịch thu', incomeTransactions.length.toString(), boldFont, font),
                      _buildSummaryItem('Số giao dịch chi', expenseTransactions.length.toString(), boldFont, font),
                    ],
                  ),
                  pw.SizedBox(height: 8),
                  _buildSummaryItem(
                    'Cân đối',
                    currencyFormat.format(totalIncome - totalExpense),
                    boldFont,
                    font,
                    color: (totalIncome - totalExpense) >= 0 ? PdfColors.green : PdfColors.red,
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 24),

            // Income Transactions
            if (incomeTransactions.isNotEmpty) ...[
              pw.Text('DANH SÁCH THU NHẬP', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.green50),
                    children: [
                      _buildTableCell('Ngày', boldFont, isHeader: true),
                      _buildTableCell('Mô tả', boldFont, isHeader: true),
                      _buildTableCell('Số tiền', boldFont, isHeader: true),
                    ],
                  ),
                  ...incomeTransactions.map((transaction) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('dd/MM/yyyy').format(transaction.date), font),
                        _buildTableCell(transaction.description, font),
                        _buildTableCell(currencyFormat.format(transaction.amount), font, alignRight: true),
                      ],
                    );
                  }).toList(),
                ],
              ),
              pw.SizedBox(height: 24),
            ],

            // Expense Transactions
            if (expenseTransactions.isNotEmpty) ...[
              pw.Text('DANH SÁCH CHI TIÊU', style: pw.TextStyle(font: boldFont, fontSize: 14)),
              pw.SizedBox(height: 12),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.red50),
                    children: [
                      _buildTableCell('Ngày', boldFont, isHeader: true),
                      _buildTableCell('Mô tả', boldFont, isHeader: true),
                      _buildTableCell('Số tiền', boldFont, isHeader: true),
                    ],
                  ),
                  ...expenseTransactions.map((transaction) {
                    return pw.TableRow(
                      children: [
                        _buildTableCell(DateFormat('dd/MM/yyyy').format(transaction.date), font),
                        _buildTableCell(transaction.description, font),
                        _buildTableCell(currencyFormat.format(transaction.amount), font, alignRight: true),
                      ],
                    );
                  }).toList(),
                ],
              ),
            ],
          ];
        },
      ),
    );

    final projectName = project == 'Tất cả' ? 'TatCa' : project.replaceAll(' ', '_');
    final fileName = 'BaoCao_ThuChi_${projectName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
    await _saveAndSharePdf(pdf, fileName, context);
  }

  pw.Widget _buildSummaryItem(String label, String value, pw.Font boldFont, pw.Font font, {PdfColor? color}) {
    return pw.Expanded(
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, color: PdfColors.grey600)),
          pw.Text(
            value,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 14,
              color: color ?? PdfColors.black,
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildTableCell(String text, pw.Font font, {bool isHeader = false, bool alignRight = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          font: font,
          fontSize: isHeader ? 10 : 9,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
      ),
    );
  }

  Future<void> _saveAndSharePdf(pw.Document pdf, String fileName, BuildContext context) async {
    try {
      // Get temporary directory
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/$fileName');
      await file.writeAsBytes(await pdf.save());

      // Show success message and offer to share
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã tạo báo cáo: $fileName'),
            action: SnackBarAction(
              label: 'Mở',
              onPressed: () async {
                await Printing.sharePdf(bytes: await pdf.save(), filename: fileName);
              },
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi khi tạo PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
