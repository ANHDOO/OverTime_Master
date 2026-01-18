import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path/path.dart' as path;

/// Service để tạo PDF chứng từ với layout 9 ảnh/trang A4
class ReceiptPdfService {
  
  /// Tạo PDF từ danh sách đường dẫn ảnh
  /// Layout: 3 cột x 3 hàng = 9 ảnh/trang
  /// Nếu ảnh ít hơn 9, sẽ sắp xếp cân đối
  static Future<Uint8List> generateReceiptPdf(List<String> imagePaths) async {
    debugPrint('🚀 PDF Service Version 2.0 - Khởi tạo với ${imagePaths.length} đường dẫn');
    try {
      final pdf = pw.Document();
      
      // 1. Load tất cả ảnh hợp lệ trước
      final loadedImages = <pw.MemoryImage>[];
      for (final path in imagePaths) {
        try {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              loadedImages.add(pw.MemoryImage(bytes));
            }
          } else {
            debugPrint('⚠️ PDF: File không tồn tại: $path');
          }
        } catch (e) {
          debugPrint('❌ PDF: Lỗi load ảnh $path: $e');
        }
      }

      if (loadedImages.isEmpty) {
        throw Exception('Không có ảnh hợp lệ để tạo PDF');
      }

      // 2. Chia ảnh thành các trang (tối đa 9 ảnh/trang)
      const int imagesPerPage = 9;
      debugPrint('📦 PDF: Tổng số ảnh đã load: ${loadedImages.length}');
      
      for (var i = 0; i < loadedImages.length; i += imagesPerPage) {
        final pageImages = loadedImages.sublist(
          i,
          i + imagesPerPage > loadedImages.length ? loadedImages.length : i + imagesPerPage,
        );

        final pageNum = (i / imagesPerPage).toInt() + 1;
        debugPrint('📄 PDF: Đang tạo trang $pageNum với ${pageImages.length} ảnh');

        // 3. Tính layout tối ưu cho số ảnh thực tế trên trang này
        final layout = _calculateOptimalLayout(pageImages.length);
        final cols = layout['cols']!;
        final rows = layout['rows']!;
        
        debugPrint('📐 PDF: Layout trang $pageNum: $cols cột x $rows hàng');

        const pageFormat = PdfPageFormat.a4;
        const margin = 10.0; // Tăng margin một chút
        const spacing = 8.0; // Tăng spacing một chút
        final printWidth = pageFormat.width - (margin * 2);
        final printHeight = pageFormat.height - (margin * 2);
        
        final slotWidth = (printWidth - (spacing * (cols - 1))) / cols;
        final slotHeight = (printHeight - (spacing * (rows - 1))) / rows;
        
        debugPrint('📏 PDF: Kích thước slot: ${slotWidth.toStringAsFixed(1)} x ${slotHeight.toStringAsFixed(1)}');

        // 4. Tạo các widget ảnh cho trang này
        final imageWidgets = pageImages.map((img) => pw.Container(
          width: slotWidth,
          height: slotHeight,
          // Thêm border nhẹ để dễ debug nếu cần
          // decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
          child: pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Image(img),
            ),
          ),
        )).toList();

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.all(margin),
            build: (context) {
              return _buildImageGrid(imageWidgets, cols, rows, slotWidth, slotHeight, spacing);
            },
          ),
        );
      }
      
      return pdf.save();
    } catch (e, stack) {
      debugPrint('❌ PDF Generation Error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }
  
  /// Tính layout tối ưu dựa trên số ảnh
  static Map<String, int> _calculateOptimalLayout(int imageCount) {
    // Nếu có từ 7-9 ảnh, dùng layout 3x3
    if (imageCount > 6) {
      return {'cols': 3, 'rows': 3};
    } 
    // Nếu có 5-6 ảnh, dùng layout 3x2 (đảm bảo 6 slots)
    else if (imageCount > 4) {
      return {'cols': 3, 'rows': 2};
    } 
    // Nếu có 4 ảnh, dùng layout 2x2
    else if (imageCount == 4) {
      return {'cols': 2, 'rows': 2};
    } 
    // Nếu có 3 ảnh, dùng layout 3x1 hoặc 2x2 tùy chọn, ở đây chọn 3x1
    else if (imageCount == 3) {
      return {'cols': 3, 'rows': 1};
    } 
    // Nếu có 2 ảnh, dùng layout 2x1
    else if (imageCount == 2) {
      return {'cols': 2, 'rows': 1};
    } 
    // 1 ảnh
    else {
      return {'cols': 1, 'rows': 1};
    }
  }
  
  /// Build grid ảnh
  static pw.Widget _buildImageGrid(
    List<pw.Widget> images,
    int cols,
    int rows,
    double slotWidth,
    double slotHeight,
    double spacing,
  ) {
    final rowWidgets = <pw.Widget>[];
    
    for (var row = 0; row < rows; row++) {
      final colWidgets = <pw.Widget>[];
      for (var col = 0; col < cols; col++) {
        final index = row * cols + col;
        if (index < images.length) {
          colWidgets.add(images[index]);
        } else {
          // Slot trống
          colWidgets.add(pw.SizedBox(width: slotWidth, height: slotHeight));
        }
        if (col < cols - 1) {
          colWidgets.add(pw.SizedBox(width: spacing));
        }
      }
      rowWidgets.add(pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: colWidgets,
      ));
      if (row < rows - 1) {
        rowWidgets.add(pw.SizedBox(height: spacing));
      }
    }
    
    return pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: rowWidgets,
    );
  }
  
  /// Hiển thị preview và cho phép in PDF
  static Future<void> previewAndPrint(
    BuildContext context,
    List<String> imagePaths, {
    String? title,
  }) async {
    // Lọc chỉ lấy các file tồn tại
    final validPaths = <String>[];
    for (final p in imagePaths) {
      if (await File(p).exists()) {
        validPaths.add(p);
      } else {
        debugPrint('⚠️ PDF Preview: File không tồn tại: $p');
      }
    }
    
    if (validPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có ảnh nào để in')),
      );
      return;
    }
    
    await Printing.layoutPdf(
      onLayout: (format) => generateReceiptPdf(validPaths),
      name: title ?? 'ChungTu_${DateTime.now().millisecondsSinceEpoch}',
    );
  }
  
  /// Lưu PDF và chia sẻ
  static Future<void> saveAndShare(
    BuildContext context,
    List<String> imagePaths, {
    String? fileName,
  }) async {
    // Lọc chỉ lấy các file tồn tại
    final validPaths = <String>[];
    for (final p in imagePaths) {
      if (await File(p).exists()) {
        validPaths.add(p);
      } else {
        debugPrint('⚠️ PDF Share: File không tồn tại: $p');
      }
    }
    
    if (validPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không có ảnh nào để in')),
      );
      return;
    }
    
    final pdfBytes = await generateReceiptPdf(validPaths);
    
    // Lưu file
    final directory = await getApplicationDocumentsDirectory();
    final name = fileName ?? 'ChungTu_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final filePath = path.join(directory.path, name);
    final file = File(filePath);
    await file.writeAsBytes(pdfBytes);
    
    // Chia sẻ file
    await Share.shareXFiles([XFile(filePath)], text: 'Chứng từ');
  }
}
