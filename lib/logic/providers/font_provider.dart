import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔤 Font Provider - Quản lý font chữ động cho toàn bộ ứng dụng
class FontProvider extends ChangeNotifier {
  static const String _fontKey = 'selected_font';
  
  /// Danh sách các font có sẵn
  static const List<FontOption> availableFonts = [
    FontOption(
      id: 'system',
      name: 'Mặc định hệ thống',
      fontFamily: null,
      description: 'Sử dụng font chữ mặc định của điện thoại (Xiaomi MiSans, SamsungOne...)',
      isGoogleFont: false,
    ),
    FontOption(
      id: 'utmhelvetins',
      name: 'UTM HelvetIns',
      fontFamily: 'UTMHelvetIns',
      description: 'Font chữ gọn gàng, chuyên nghiệp',
      isGoogleFont: false,
    ),
    FontOption(
      id: 'inter',
      name: 'Inter',
      fontFamily: 'Inter', // Tên font trong Google Fonts
      description: 'Hiện đại, dễ đọc số liệu',
      isGoogleFont: true,
    ),
    FontOption(
      id: 'roboto',
      name: 'Roboto',
      fontFamily: 'Roboto', // Tên font trong Google Fonts
      description: 'Nhẹ, quen thuộc',
      isGoogleFont: true,
    ),
    FontOption(
      id: 'be_vietnam_pro',
      name: 'Be Vietnam Pro',
      fontFamily: 'Be Vietnam Pro',
      description: 'Thiết kế riêng cho tiếng Việt, cực kỳ chuyên nghiệp (Khuyên dùng)',
      isGoogleFont: true,
    ),
    FontOption(
      id: 'montserrat',
      name: 'Montserrat',
      fontFamily: 'Montserrat',
      description: 'Hiện đại, mạnh mẽ cho tiêu đề',
      isGoogleFont: true,
    ),
    FontOption(
      id: 'poppins',
      name: 'Poppins',
      fontFamily: 'Poppins',
      description: 'Thân thiện, dễ đọc trên mobile',
      isGoogleFont: true,
    ),
    FontOption(
      id: 'jetbrains_mono',
      name: 'JetBrains Mono',
      fontFamily: 'JetBrains Mono',
      description: 'Chuyên dụng cho số liệu kỹ thuật',
      isGoogleFont: true,
    ),
  ];

  String _selectedFontId = 'utmhelvetins';
  bool _isLoaded = false;

  String get selectedFontId => _selectedFontId;
  bool get isLoaded => _isLoaded;

  FontOption get selectedFont => availableFonts.firstWhere(
    (f) => f.id == _selectedFontId,
    orElse: () => availableFonts.first,
  );

  String? get currentFontFamily => selectedFont.fontFamily;

  /// Tải font đã lưu từ SharedPreferences
  Future<void> loadFont() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedFontId = prefs.getString(_fontKey) ?? 'utmhelvetins';
    _isLoaded = true;
    notifyListeners();
  }

  /// Thay đổi font và lưu vào SharedPreferences
  Future<void> setFont(String fontId) async {
    if (_selectedFontId == fontId) return;
    
    _selectedFontId = fontId;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontKey, fontId);
  }
}

/// Model cho một font option
class FontOption {
  final String id;
  final String name;
  final String? fontFamily;
  final String description;
  final bool isGoogleFont;

  const FontOption({
    required this.id,
    required this.name,
    this.fontFamily,
    required this.description,
    this.isGoogleFont = false,
  });
}
