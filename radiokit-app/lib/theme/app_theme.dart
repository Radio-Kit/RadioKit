import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// RadioKit color palette — built from the brand logo.
class AppColors {
  AppColors._();

  // --- BRAND COLORS ---
  static const Color brandCharcoal = Color(0xFF1A1A1A); // Deeper Dark for higher contrast
  static const Color brandOrange = Color(0xFFFF8C00);   // More vibrant Orange
  static const Color brandWhite = Color(0xFFF5F5F5);    // Soft White

  // --- UI SEMANTIC COLORS ---
  static const Color brandBlue = Color(0xFF00A3FF);     // Vibrant Blue
  static const Color brandYellow = Color(0xFFFFD600);   // Warning Yellow
  static const Color brandRed = Color(0xFFFF4B4B);      // Danger Red
  static const Color brandGray = Color(0xFF8E8E93);     // iOS-style gray

  // --- STATUS INDICATORS ---
  static const Color connected = Color(0xFF34C759);    // iOS Green
  static const Color disconnected = brandRed;

  // --- LED COLORS (Hardware config based) ---
  static const Color ledOff = Color(0xFF3A3A4A);
  static const Color ledRed = Color(0xFFFF3B3B);
  static const Color ledGreen = Color(0xFF4ADE80);
  static const Color ledBlue = Color(0xFF60A5FA);
  static const Color ledYellow = Color(0xFFFBBF24);

  static Color ledColor(int value) {
    switch (value) {
      case 1: return ledRed;
      case 2: return ledGreen;
      case 3: return ledBlue;
      case 4: return ledYellow;
      default: return ledOff;
    }
  }

  // --- GLASSMORPHISM HELPERS ---
  static Color glassBackground(Brightness b) =>
      b == Brightness.dark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.3);
  static Color glassBorder(Brightness b) =>
      b == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1);

  // --- DYNAMIC HELPERS ---
  static Color dynamicSurface(Brightness b) =>
      b == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.white;

  static Color dynamicBackground(Brightness b) =>
      b == Brightness.dark ? brandCharcoal : brandWhite;

  static Color dynamicTextPrimary(Brightness b) =>
      b == Brightness.dark ? brandWhite : brandCharcoal;

  static Color dynamicTextSecondary(Brightness b) => brandGray;

  static Color dynamicBorder(Brightness b) =>
      b == Brightness.dark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.08);

  // --- SEMANTIC ALIASES ---
  static const Color primary = brandOrange;
  static const Color accent = brandOrange;
}

/// RadioKit app theme configuration.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => _build(Brightness.dark);
  static ThemeData get light => _build(Brightness.light);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    
    // Core colors based on mode
    final bg = AppColors.dynamicBackground(brightness);
    final surface = AppColors.dynamicSurface(brightness);
    final text = AppColors.dynamicTextPrimary(brightness);
    final secondaryText = AppColors.dynamicTextSecondary(brightness);
    final border = AppColors.dynamicBorder(brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandOrange,
        brightness: brightness,
        primary: AppColors.brandOrange,
        onPrimary: Colors.white,
        secondary: AppColors.brandBlue,
        error: AppColors.brandRed,
        surface: bg, // Match background for unified look
        onSurface: text,
      ),
      scaffoldBackgroundColor: bg,
      bottomSheetTheme: BottomSheetThemeData(
        constraints: const BoxConstraints(maxHeight: double.infinity),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        dragHandleSize: const Size(32, 4),
        dragHandleColor: Colors.white24,
      ),
      dividerColor: border,
      disabledColor: isDark ? const Color(0xFF444446) : const Color(0xFFD1D1D6),
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: text,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.exo2(
          color: text,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        selectedItemColor: AppColors.brandOrange,
        unselectedItemColor: secondaryText,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandOrange,
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 0.5),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          headlineLarge: TextStyle(
            color: text,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
          headlineMedium: TextStyle(
            color: text,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            color: text,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: text,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: text,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: secondaryText,
            fontSize: 14,
          ),
          labelSmall: TextStyle(
            color: secondaryText,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
