import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class OCRResult {
  final double? amount;
  final String? description;
  final String? vendor;
  final DateTime? date;
  final String? transactionId;

  OCRResult({this.amount, this.description, this.vendor, this.date, this.transactionId});

  @override
  String toString() {
    return 'OCRResult(amount: $amount, description: $description, vendor: $vendor, date: $date, transactionId: $transactionId)';
  }
}

class OCRService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<OCRResult> processReceipt(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    String fullText = recognizedText.text;
    return _parseTechcombank(fullText);
  }

  OCRResult _parseTechcombank(String text) {
    double? amount;
    String? description;
    String? vendor;
    DateTime? date;
    String? transactionId;

    final lines = text.split('\n');

    // 1. Extract Amount
    final amountRegex = RegExp(r'(?:VND|VND\s+)?([\d,.]+)', caseSensitive: false);
    final amountMatches = amountRegex.allMatches(text);
    for (var match in amountMatches) {
      String val = match.group(1)!.replaceAll(',', '').replaceAll('.', '');
      double? parsed = double.tryParse(val);
      if (parsed != null && parsed > 1000) {
        amount = parsed;
        break;
      }
    }

    // 2. Extract Date
    final dateRegex = RegExp(r'(\d{1,2})\s+thg\s+(\d{1,2}),\s+(\d{4})', caseSensitive: false);
    final dateMatch = dateRegex.firstMatch(text);
    if (dateMatch != null) {
      int day = int.parse(dateMatch.group(1)!);
      int month = int.parse(dateMatch.group(2)!);
      int year = int.parse(dateMatch.group(3)!);
      date = DateTime(year, month, day);
    }

    // 3. Extract Vendor & Description
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trim();
      
      // Vendor: Look for "Tới"
      if (line.startsWith('Tới') && line.length > 4) {
        vendor = line.substring(3).trim();
      } else if (line == 'Tới' && i + 1 < lines.length) {
        vendor = lines[i + 1].trim();
      }

      // Description: Look for "Lời nhắn"
      if (line.contains('Lời nhắn') && i + 1 < lines.length) {
        String rawDesc = lines[i + 1].trim();
        // Remove "Anh Do chuyen khoan" or "chuyen khoan"
        description = rawDesc
            .replaceAll(RegExp(r'^Anh\s+Do\s+chuyen\s+khoan\s*', caseSensitive: false), '')
            .replaceAll(RegExp(r'^chuyen\s+khoan\s*', caseSensitive: false), '')
            .trim();
        
        // Capitalize first letter
        if (description.isNotEmpty) {
          description = description[0].toUpperCase() + description.substring(1);
        }
      }

      // Transaction ID: Look for "Mã giao dịch"
      if (line.contains('Mã giao dịch') && i + 1 < lines.length) {
        transactionId = lines[i + 1].trim();
      }
    }

    // Fallback for Transaction ID if not found by label
    if (transactionId == null) {
      final txIdRegex = RegExp(r'FT\d{10,}', caseSensitive: false);
      final txIdMatch = txIdRegex.firstMatch(text);
      if (txIdMatch != null) {
        transactionId = txIdMatch.group(0);
      }
    }

    return OCRResult(
      amount: amount,
      description: description,
      vendor: vendor,
      date: date,
      transactionId: transactionId,
    );
  }

  void dispose() {
    _textRecognizer.close();
  }
}
