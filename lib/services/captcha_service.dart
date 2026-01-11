import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CaptchaService {
  static final CaptchaService _instance = CaptchaService._internal();
  factory CaptchaService() => _instance;
  CaptchaService._internal();

  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Extract captcha image from WebView as Base64 and solve it using OCR
  Future<String?> solveCaptchaFromWebView(WebViewController controller) async {
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        // 1. Get Base64 of the captcha image via JS
        final String base64Image = await controller.runJavaScriptReturningResult('''
          (function() {
            const img = document.querySelector('img[src*="captcha"], img[src*="Captcha"], img[id*="captcha"], #imgCaptcha');
            if (!img || !img.complete || img.naturalWidth === 0) return '';
            
            const canvas = document.createElement('canvas');
            canvas.width = img.naturalWidth;
            canvas.height = img.naturalHeight;
            const ctx = canvas.getContext('2d');
            ctx.drawImage(img, 0, 0);
            return canvas.toDataURL('image/png').split(',')[1];
          })()
        ''') as String;

        final cleanBase64 = base64Image.replaceAll('"', '');
        if (cleanBase64.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }

        // 2. Decode and save to temp file
        final Uint8List bytes = base64Decode(cleanBase64);
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/captcha_temp.png');
        await file.writeAsBytes(bytes);

        // 3. Recognize text
        final InputImage inputImage = InputImage.fromFile(file);
        final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

        // 4. Cleanup and return result
        String result = recognizedText.text.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').trim();
        debugPrint('[CaptchaService] Attempt ${attempt + 1} Recognized: $result');
        
        if (result.length >= 4 && result.length <= 6) {
          return result;
        }
        
        // If result is nonsensical, retry
        await Future.delayed(const Duration(milliseconds: 200));
      } catch (e) {
        debugPrint('[CaptchaService] Attempt ${attempt + 1} Error: $e');
      }
    }
    return null;
  }

  void dispose() {
    _textRecognizer.close();
  }
}
