import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🔤 Font Provider - Quản lý font chữ động cho toàn bộ ứng dụng
class FontProvider extends ChangeNotifier {
  static const String _fontKey = 'selected_font';
  
  /// Danh sách các font có sẵn
  static const List<FontOption> availableFonts = [
    FontOption(
      id: 'utmhelvetins',
      name: 'UTM HelvetIns',
      fontFamily: 'UTMHelvetIns',
      description: 'Font chữ gọn gàng, chuyên nghiệp',
    ),
    FontOption(
      id: 'inter',
      name: 'Inter',
      fontFamily: null, // Sử dụng Google Fonts
      description: 'Hiện đại, dễ đọc số liệu',
    ),
    FontOption(
      id: 'roboto',
      name: 'Roboto',
      fontFamily: null, // Font hệ thống Android
      description: 'Nhẹ, quen thuộc',
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

  const FontOption({
    required this.id,
    required this.name,
    this.fontFamily,
    required this.description,
  });
}
