import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// Convenience extension — [context.tokens] gives the current [RKTokens].
extension TokensContext on BuildContext {
  RKTokens get tokens => RKTheme.of(this);
}

/// RadioKit app theme configuration.
class AppTheme {
  AppTheme._();

  static ThemeData get dark => fromTokens(RKTokens.dragon, Brightness.dark);
  static ThemeData get light => fromTokens(RKTokens.dragon, Brightness.light);

  /// Build a [ThemeData] from [RKTokens] at a given [Brightness].
  ///
  /// All Material component colors flow from the token values, so updating
  /// the library's token presets automatically updates the entire app theme.
  static ThemeData fromTokens(RKTokens tokens, Brightness brightness) {
    final isDark = brightness == Brightness.dark;

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: tokens.primary,
        onPrimary: tokens.onPrimary,
        secondary: tokens.secondary,
        onSecondary: tokens.onSecondary,
        tertiary: tokens.accent,
        onTertiary: tokens.onAccent,
        error: tokens.error,
        onError: tokens.onError,
        surface: tokens.surface,
        onSurface: tokens.onSurface,
        outline: tokens.effectiveOutline,
      ),
      scaffoldBackgroundColor: tokens.surface,
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark
            ? tokens.base200
            : tokens.surface,
        constraints: const BoxConstraints(maxHeight: double.infinity),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        ),
        dragHandleSize: const Size(32, 4),
        dragHandleColor: tokens.onSurface.withValues(alpha: 0.2),
      ),
      dividerColor: tokens.effectiveOutline,
      disabledColor: tokens.onSurface.withValues(alpha: 0.3),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.base200,
        foregroundColor: tokens.onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.exo2(
          color: tokens.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.borderRadius.clamp(0, 32)),
          side: BorderSide(
            color: tokens.effectiveOutline,
            width: tokens.borderWidth,
          ),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: tokens.base200,
        selectedItemColor: tokens.primary,
        unselectedItemColor: tokens.onSurface.withValues(alpha: 0.5),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: tokens.base200,
        selectedIconTheme: IconThemeData(color: tokens.primary),
        unselectedIconTheme: IconThemeData(
            color: tokens.onSurface.withValues(alpha: 0.5)),
        selectedLabelTextStyle: TextStyle(
          color: tokens.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: tokens.onSurface.withValues(alpha: 0.5),
          fontSize: 11,
        ),
        indicatorColor: tokens.primary.withValues(alpha: 0.12),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.primary,
          foregroundColor: tokens.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusField.clamp(0, 16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.5,
          ),
        ),
      ),
      textTheme: GoogleFonts.interTextTheme(
        TextTheme(
          headlineLarge: TextStyle(
            color: tokens.onSurface,
            fontSize: 32,
            fontWeight: FontWeight.w900,
            letterSpacing: -1.0,
          ),
          headlineMedium: TextStyle(
            color: tokens.onSurface,
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
          titleLarge: TextStyle(
            color: tokens.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          titleMedium: TextStyle(
            color: tokens.onSurface,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(
            color: tokens.onSurface,
            fontSize: 16,
          ),
          bodyMedium: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.7),
            fontSize: 14,
          ),
          labelSmall: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.5,
          ),
        ),
      ),
    );
  }
}
