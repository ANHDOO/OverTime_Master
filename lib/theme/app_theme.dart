import 'package:flutter/material.dart';

/// 🎨 App Color System - Light & Dark Mode
class AppColors {
  // Private constructor - use static members only
  AppColors._();

  // ═══════════════════════════════════════════════════════════════════════
  // PRIMARY COLORS - Trust Blue
  // ═══════════════════════════════════════════════════════════════════════
  static const primary = Color(0xFF3B82F6);       // Blue 500
  static const primaryLight = Color(0xFF60A5FA);  // Blue 400
  static const primaryDark = Color(0xFF2563EB);   // Blue 600
  static const primaryDeep = Color(0xFF1D4ED8);   // Blue 700

  // ═══════════════════════════════════════════════════════════════════════
  // ACCENT COLORS - Warm Orange for CTA
  // ═══════════════════════════════════════════════════════════════════════
  static const accent = Color(0xFFF97316);        // Orange 500
  static const accentLight = Color(0xFFFB923C);   // Orange 400
  static const accentDark = Color(0xFFEA580C);    // Orange 600

  // ═══════════════════════════════════════════════════════════════════════
  // SEMANTIC COLORS
  // ═══════════════════════════════════════════════════════════════════════
  // Success - Green (Income, positive)
  static const success = Color(0xFF10B981);       // Emerald 500
  static const successLight = Color(0xFF34D399);  // Emerald 400
  static const successDark = Color(0xFF059669);   // Emerald 600
  static const successBg = Color(0xFFD1FAE5);     // Emerald 100
  static const successBgDark = Color(0xFF064E3B); // Emerald 900

  // Danger - Red (Expense, negative)
  static const danger = Color(0xFFEF4444);        // Red 500
  static const dangerLight = Color(0xFFF87171);   // Red 400
  static const dangerDark = Color(0xFFDC2626);    // Red 600
  static const dangerBg = Color(0xFFFEE2E2);      // Red 100
  static const dangerBgDark = Color(0xFF7F1D1D);  // Red 900

  // Warning - Amber
  static const warning = Color(0xFFF59E0B);       // Amber 500
  static const warningLight = Color(0xFFFBBF24);  // Amber 400
  static const warningDark = Color(0xFFD97706);   // Amber 600
  static const warningBg = Color(0xFFFEF3C7);     // Amber 100
  static const warningBgDark = Color(0xFF78350F); // Amber 900

  // Info - Cyan
  static const info = Color(0xFF06B6D4);          // Cyan 500
  static const infoLight = Color(0xFF22D3EE);     // Cyan 400
  static const infoDark = Color(0xFF0891B2);      // Cyan 600
  static const infoBg = Color(0xFFCFFAFE);        // Cyan 100
  static const infoBgDark = Color(0xFF164E63);    // Cyan 900

  // ═══════════════════════════════════════════════════════════════════════
  // LIGHT THEME COLORS
  // ═══════════════════════════════════════════════════════════════════════
  static const lightBackground = Color(0xFFF8FAFC);      // Slate 50
  static const lightSurface = Color(0xFFFFFFFF);         // White
  static const lightSurfaceVariant = Color(0xFFF1F5F9);  // Slate 100
  static const lightCard = Color(0xFFFFFFFF);            // White
  static const lightTextPrimary = Color(0xFF0F172A);     // Slate 900
  static const lightTextSecondary = Color(0xFF475569);   // Slate 600
  static const lightTextMuted = Color(0xFF94A3B8);       // Slate 400
  static const lightBorder = Color(0xFFE2E8F0);          // Slate 200
  static const lightDivider = Color(0xFFF1F5F9);         // Slate 100

  // ═══════════════════════════════════════════════════════════════════════
  // DARK THEME COLORS (OLED optimized)
  // ═══════════════════════════════════════════════════════════════════════
  static const darkBackground = Color(0xFF0F172A);       // Slate 900
  static const darkSurface = Color(0xFF1E293B);          // Slate 800
  static const darkSurfaceVariant = Color(0xFF334155);   // Slate 700
  static const darkCard = Color(0xFF1E293B);             // Slate 800
  static const darkTextPrimary = Color(0xFFF8FAFC);      // Slate 50
  static const darkTextSecondary = Color(0xFFCBD5E1);    // Slate 300
  static const darkTextMuted = Color(0xFF64748B);        // Slate 500
  static const darkBorder = Color(0xFF334155);           // Slate 700
  static const darkDivider = Color(0xFF1E293B);          // Slate 800

  // Tab-specific colors for hero cards
  static const tealPrimary = Color(0xFF14B8A6);          // Teal 500
  static const tealDark = Color(0xFF0D9488);             // Teal 600
  static const tealDeep = Color(0xFF0F766E);             // Teal 700
  
  static const indigoPrimary = Color(0xFF6366F1);        // Indigo 500
  static const indigoDark = Color(0xFF4F46E5);           // Indigo 600
  static const indigoDeep = Color(0xFF4338CA);           // Indigo 700
}

/// 🌈 Gradient System
class AppGradients {
  AppGradients._();

  // Hero Cards
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

  // Success gradient
  static const success = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Glass overlay effect
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

  // Green gradient for success actions
  static const heroGreen = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669), Color(0xFF047857)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Danger gradient for delete/warning actions
  static const heroDanger = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDC2626), Color(0xFFB91C1C)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Shimmer effect for loading
  static const shimmer = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x40FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}

/// 📐 Spacing System (8-point grid)
class AppSpacing {
  AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

/// 📦 Border Radius System
class AppRadius {
  AppRadius._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0;

  // Convenient BorderRadius objects
  static final BorderRadius borderXs = BorderRadius.circular(xs);
  static final BorderRadius borderSm = BorderRadius.circular(sm);
  static final BorderRadius borderMd = BorderRadius.circular(md);
  static final BorderRadius borderLg = BorderRadius.circular(lg);
  static final BorderRadius borderXl = BorderRadius.circular(xl);
  static final BorderRadius borderXxl = BorderRadius.circular(xxl);
  static final BorderRadius borderFull = BorderRadius.circular(full);
}

/// 🌫️ Shadow System
class AppShadows {
  AppShadows._();

  // Light theme shadows
  static List<BoxShadow> cardLight = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.03),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.08),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> cardLightHover = [
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.04),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: const Color(0xFF0F172A).withOpacity(0.12),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  static List<BoxShadow> heroLight = [
    BoxShadow(
      color: const Color(0xFF1D4ED8).withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> heroTealLight = [
    BoxShadow(
      color: const Color(0xFF0F766E).withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> heroOrangeLight = [
    BoxShadow(
      color: const Color(0xFFC2410C).withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> heroIndigoLight = [
    BoxShadow(
      color: const Color(0xFF4338CA).withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> heroGreenLight = [
    BoxShadow(
      color: const Color(0xFF047857).withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> heroDangerLight = [
    BoxShadow(
      color: const Color(0xFFB91C1C).withOpacity(0.25),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> buttonLight = [
    BoxShadow(
      color: const Color(0xFF3B82F6).withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // Dark theme shadows (more subtle)
  static List<BoxShadow> cardDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  static List<BoxShadow> heroDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
  ];

  static List<BoxShadow> buttonDark = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
  ];

  // No shadow
  static List<BoxShadow> none = [];
}

/// ⏱️ Animation Durations
class AppDurations {
  AppDurations._();

  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 300);
  static const Duration slower = Duration(milliseconds: 400);
  static const Duration splash = Duration(milliseconds: 1200);
}

/// 🎨 Theme Data Builder
class AppTheme {
  AppTheme._();

  // ═══════════════════════════════════════════════════════════════════════
  // LIGHT THEME
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    
    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryLight.withOpacity(0.2),
      secondary: AppColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.accentLight.withOpacity(0.2),
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightTextPrimary,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      error: AppColors.danger,
      onError: Colors.white,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.lightBackground,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 56,
      titleTextStyle: const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: Colors.white,
      ),
      iconTheme: const IconThemeData(color: Colors.white, size: 22),
    ),

    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primary.withOpacity(0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          );
        }
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.lightTextMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 22);
        }
        return IconThemeData(color: AppColors.lightTextMuted, size: 22);
      }),
    ),

    // Cards
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.lightCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(color: AppColors.lightBorder.withOpacity(0.5)),
      ),
      margin: EdgeInsets.zero,
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.lightSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: BorderSide(color: AppColors.lightBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      hintStyle: TextStyle(color: AppColors.lightTextMuted, fontSize: 14),
      labelStyle: TextStyle(color: AppColors.lightTextSecondary, fontSize: 14),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: AppColors.lightDivider,
      thickness: 1,
      space: 1,
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSurface,
      contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      behavior: SnackBarBehavior.floating,
    ),

    // Bottom Sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.lightSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
    ),

    // Checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return Colors.transparent;
      }),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.white;
        }
        return AppColors.lightTextMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.lightBorder;
      }),
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      tileColor: Colors.transparent,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.lightSurfaceVariant,
      selectedColor: AppColors.primary.withOpacity(0.15),
      labelStyle: TextStyle(color: AppColors.lightTextPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
      side: BorderSide.none,
    ),
  );

  // ═══════════════════════════════════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    
    // Color Scheme
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      onPrimary: AppColors.darkBackground,
      primaryContainer: AppColors.primaryDark.withOpacity(0.3),
      secondary: AppColors.accentLight,
      onSecondary: AppColors.darkBackground,
      secondaryContainer: AppColors.accentDark.withOpacity(0.3),
      surface: AppColors.darkSurface,
      onSurface: AppColors.darkTextPrimary,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      error: AppColors.dangerLight,
      onError: AppColors.darkBackground,
    ),

    // Scaffold
    scaffoldBackgroundColor: AppColors.darkBackground,

    // AppBar
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkTextPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      toolbarHeight: 56,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
        color: AppColors.darkTextPrimary,
      ),
      iconTheme: IconThemeData(color: AppColors.darkTextPrimary, size: 22),
    ),

    // Navigation Bar
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      elevation: 0,
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.primaryLight.withOpacity(0.15),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primaryLight,
          );
        }
        return TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.darkTextMuted,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primaryLight, size: 22);
        }
        return IconThemeData(color: AppColors.darkTextMuted, size: 22);
      }),
    ),

    // Cards
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.darkCard,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.borderLg,
        side: BorderSide(color: AppColors.darkBorder.withOpacity(0.5)),
      ),
      margin: EdgeInsets.zero,
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryLight,
        foregroundColor: AppColors.darkBackground,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
        side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryLight,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.borderSm),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),

    // FAB
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primaryLight,
      foregroundColor: AppColors.darkBackground,
      elevation: 4,
      shape: CircleBorder(),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.darkSurfaceVariant.withOpacity(0.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: BorderSide(color: AppColors.darkBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: const BorderSide(color: AppColors.primaryLight, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppRadius.borderMd,
        borderSide: const BorderSide(color: AppColors.dangerLight),
      ),
      hintStyle: TextStyle(color: AppColors.darkTextMuted, fontSize: 14),
      labelStyle: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
    ),

    // Divider
    dividerTheme: DividerThemeData(
      color: AppColors.darkDivider,
      thickness: 1,
      space: 1,
    ),

    // Snackbar
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.darkSurfaceVariant,
      contentTextStyle: TextStyle(color: AppColors.darkTextPrimary, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      behavior: SnackBarBehavior.floating,
    ),

    // Bottom Sheet
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    // Dialog
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.darkSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderXl),
    ),

    // Checkbox
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(AppColors.darkBackground),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    ),

    // Switch
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.darkBackground;
        }
        return AppColors.darkTextMuted;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primaryLight;
        }
        return AppColors.darkBorder;
      }),
    ),

    // ListTile
    listTileTheme: ListTileThemeData(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderMd),
      tileColor: Colors.transparent,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.darkSurfaceVariant,
      selectedColor: AppColors.primaryLight.withOpacity(0.2),
      labelStyle: TextStyle(color: AppColors.darkTextPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderFull),
      side: BorderSide.none,
    ),
  );
}

/// Extension for easy theme-aware color access
extension ThemeContextExtension on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  Color get backgroundColor => isDarkMode 
      ? AppColors.darkBackground 
      : AppColors.lightBackground;
      
  Color get surfaceColor => isDarkMode 
      ? AppColors.darkSurface 
      : AppColors.lightSurface;
      
  Color get cardColor => isDarkMode 
      ? AppColors.darkCard 
      : AppColors.lightCard;
      
  Color get textPrimary => isDarkMode 
      ? AppColors.darkTextPrimary 
      : AppColors.lightTextPrimary;
      
  Color get textSecondary => isDarkMode 
      ? AppColors.darkTextSecondary 
      : AppColors.lightTextSecondary;
      
  Color get textMuted => isDarkMode 
      ? AppColors.darkTextMuted 
      : AppColors.lightTextMuted;
      
  Color get borderColor => isDarkMode 
      ? AppColors.darkBorder 
      : AppColors.lightBorder;
      
  List<BoxShadow> get cardShadow => isDarkMode 
      ? AppShadows.cardDark 
      : AppShadows.cardLight;
      
  List<BoxShadow> get heroShadow => isDarkMode 
      ? AppShadows.heroDark 
      : AppShadows.heroLight;
}
