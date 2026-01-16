import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 🎨 App Color System - Light & Dark Mode
class AppColors {
  AppColors._();

  static const primary = Color(0xFF3B82F6);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF2563EB);
  static const primaryDeep = Color(0xFF1D4ED8);

  static const accent = Color(0xFFF97316);
  static const accentLight = Color(0xFFFB923C);
  static const accentDark = Color(0xFFEA580C);

  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFF34D399);
  static const successDark = Color(0xFF059669);
  static const successBg = Color(0xFFD1FAE5);
  static const successBgDark = Color(0xFF064E3B);

  static const danger = Color(0xFFEF4444);
  static const dangerLight = Color(0xFFF87171);
  static const dangerDark = Color(0xFFDC2626);
  static const dangerBg = Color(0xFFFEE2E2);
  static const dangerBgDark = Color(0xFF7F1D1D);

  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFBBF24);
  static const warningDark = Color(0xFFD97706);
  static const warningBg = Color(0xFFFEF3C7);
  static const warningBgDark = Color(0xFF78350F);

  static const info = Color(0xFF06B6D4);
  static const infoLight = Color(0xFF22D3EE);
  static const infoDark = Color(0xFF0891B2);
  static const infoBg = Color(0xFFCFFAFE);
  static const infoBgDark = Color(0xFF164E63);

  static const lightBackground = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightSurfaceVariant = Color(0xFFF1F5F9);
  static const lightCard = Color(0xFFFFFFFF);
  static const lightTextPrimary = Color(0xFF0F172A);
  static const lightTextSecondary = Color(0xFF334155); // Slate 700 (đậm hơn 600)
  static const lightTextMuted = Color(0xFF64748B);     // Slate 500 (đậm hơn 400)
  static const lightBorder = Color(0xFFE2E8F0);
  static const lightDivider = Color(0xFFF1F5F9);

  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceVariant = Color(0xFF334155);
  static const darkCard = Color(0xFF1E293B);
  static const darkTextPrimary = Color(0xFFF8FAFC);
  static const darkTextSecondary = Color(0xFFCBD5E1);
  static const darkTextMuted = Color(0xFF64748B);
  static const darkBorder = Color(0xFF334155);
  static const darkDivider = Color(0xFF1E293B);

  static const tealPrimary = Color(0xFF14B8A6);
  static const tealDark = Color(0xFF0D9488);
  static const tealDeep = Color(0xFF0F766E);
  
  static const indigoPrimary = Color(0xFF6366F1);
  static const indigoDark = Color(0xFF4F46E5);
  static const indigoDeep = Color(0xFF4338CA);

  // Legacy compatibility
  static const lightBg = lightBackground;
  static const darkBg = darkBackground;
  static const lightText = lightTextPrimary;
  static const darkText = darkTextPrimary;
}

class AppGradients {
  AppGradients._();

  static const heroBlue = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroBlueDark = LinearGradient(
    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF1E40AF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroTeal = LinearGradient(
    colors: [Color(0xFF14B8A6), Color(0xFF0D9488), Color(0xFF0F766E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroOrange = LinearGradient(
    colors: [Color(0xFFF97316), Color(0xFFEA580C), Color(0xFFC2410C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroIndigo = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5), Color(0xFF4338CA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroPurple = LinearGradient(
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED), Color(0xFF6D28D9)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const success = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const glassLight = LinearGradient(
    colors: [Color(0x30FFFFFF), Color(0x10FFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const glassDark = LinearGradient(
    colors: [Color(0x20FFFFFF), Color(0x05FFFFFF)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const heroGreen = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const heroDanger = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const shimmer = LinearGradient(
    colors: [Color(0x00FFFFFF), Color(0x40FFFFFF), Color(0x00FFFFFF)],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );

  // Legacy compatibility
  static const primary = heroBlue;
  static const glass = glassLight;
}

class AppSpacing {
  AppSpacing._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
}

class AppRadius {
  AppRadius._();
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double full = 999.0;

  static final BorderRadius borderXs = BorderRadius.circular(xs);
  static final BorderRadius borderSm = BorderRadius.circular(sm);
  static final BorderRadius borderMd = BorderRadius.circular(md);
  static final BorderRadius borderLg = BorderRadius.circular(lg);
  static final BorderRadius borderXl = BorderRadius.circular(xl);
  static final BorderRadius borderFull = BorderRadius.circular(full);
}

class AppShadows {
  AppShadows._();

  static List<BoxShadow> cardLight = [
    BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 1)),
    BoxShadow(color: const Color(0xFF0F172A).withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 8)),
  ];

  static List<BoxShadow> heroLight = [
    BoxShadow(color: const Color(0xFF1D4ED8).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> heroTealLight = [
    BoxShadow(color: const Color(0xFF0F766E).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> heroOrangeLight = [
    BoxShadow(color: const Color(0xFFC2410C).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> heroIndigoLight = [
    BoxShadow(color: const Color(0xFF4338CA).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> heroGreenLight = [
    BoxShadow(color: const Color(0xFF047857).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> heroDangerLight = [
    BoxShadow(color: const Color(0xFFB91C1C).withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> cardDark = [
    BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4)),
  ];

  static List<BoxShadow> heroDark = [
    BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 10)),
  ];

  static List<BoxShadow> buttonLight = [
    BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6)),
  ];
}

class AppDurations {
  AppDurations._();
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slower = Duration(milliseconds: 400);
  static const Duration splash = Duration(milliseconds: 1200);
}

class AppTheme {
  AppTheme._();

  /// Tạo light theme với font tùy chọn
  static ThemeData lightWithFont(String? fontFamily) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
          surface: AppColors.lightSurface,
        ),
        fontFamily: fontFamily ?? 'UTMHelvetIns',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );

  /// Tạo dark theme với font tùy chọn
  static ThemeData darkWithFont(String? fontFamily) => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.dark,
          primary: AppColors.primaryLight,
          surface: AppColors.darkSurface,
        ),
        fontFamily: fontFamily ?? 'UTMHelvetIns',
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
      );

  // Legacy getters for backwards compatibility
  static ThemeData get light => lightWithFont(null);
  static ThemeData get dark => darkWithFont(null);
}
