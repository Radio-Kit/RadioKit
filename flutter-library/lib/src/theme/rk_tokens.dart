import 'package:flutter/material.dart';

/// Design tokens shared across all RadioKit widgets.
class RKTokens {
  const RKTokens({
    this.primary = const Color(0xFF00E5FF),
    this.surface = const Color(0xFF1E1E2E),
    this.onSurface = const Color(0xFFCDD6F4),
    this.trackColor = const Color(0xFF313244),
    this.glowColor = const Color(0x6600E5FF),
    this.shadowColor = const Color(0x99000000),
    this.onPrimary = const Color(0xFFFFFFFF),
    this.borderRadius = 12.0,
    this.elevation = 4.0,
    // Gradients for premium styling
    this.primaryGradient = const LinearGradient(
      colors: [Color(0xFF00E5FF), Color(0xFF00B8D4)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    this.surfaceGradient = const LinearGradient(
      colors: [Color(0xFF2D2D3F), Color(0xFF1E1E2E)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    // Additional design tokens
    this.shadows = const [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 6,
        offset: Offset(0, 2),
      ),
    ],
    this.glows = const [
      BoxShadow(
        color: Color(0x66FF00FF),
        blurRadius: 12,
        spreadRadius: 2,
      ),
    ],
    // Typography tokens
    this.displayTextStyle = const TextStyle(
      color: Color(0xFF00E5FF),
      fontSize: 24,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
      letterSpacing: 2,
      shadows: [
        Shadow(
          color: Color(0x6600E5FF),
          blurRadius: 8,
        ),
      ],
    ),
    this.bodyTextStyle = const TextStyle(
      color: Color(0xFFD0D0D0),
      fontSize: 14,
      fontWeight: FontWeight.normal,
    ),
    this.headlineTextStyle = const TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 28,
      fontWeight: FontWeight.w600,
    ),
  });

  final Color primary;
  final Color onPrimary;
  final Color surface;
  final Color onSurface;
  final Color trackColor;
  final Color glowColor;
  final Color shadowColor;
  final double borderRadius;
  final double elevation;
  final Gradient primaryGradient;
  final Gradient surfaceGradient;
  final TextStyle displayTextStyle;
  final List<BoxShadow> shadows;
  final List<BoxShadow> glows;
  final TextStyle bodyTextStyle;
  final TextStyle headlineTextStyle;
  /// Default neon dark theme tokens.
  static const RKTokens neon = RKTokens();

  /// Dragon industrial theme tokens (matches the reference design).
  static const RKTokens dragon = RKTokens(
    primary: Color(0xFFFF8C00),
    onPrimary: Color(0xFF000000),
    surface: Color(0xFF1A1A1A),
    onSurface: Color(0xFFE0E0E0),
    trackColor: Color(0xFF2A2A2A),
    glowColor: Color(0x66FF8C00),
    shadowColor: Color(0x99000000),
    borderRadius: 4.0,
    elevation: 2.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFFFF8C00), Color(0xFFFFA040)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFF222222), Color(0xFF1A1A1A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    shadows: [
      BoxShadow(
        color: Color(0x66000000),
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
    ],
    glows: [
      BoxShadow(
        color: Color(0x66FF8C00),
        blurRadius: 12,
        spreadRadius: 1,
      ),
    ],
    displayTextStyle: TextStyle(
      color: Color(0xFFFF8C00),
      fontSize: 24,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
      letterSpacing: 2,
      shadows: [
        Shadow(
          color: Color(0x66FF8C00),
          blurRadius: 8,
        ),
      ],
    ),
    bodyTextStyle: TextStyle(
      color: Color(0xFFB0B0B0),
      fontSize: 13,
      fontWeight: FontWeight.normal,
      fontFamily: 'monospace',
    ),
    headlineTextStyle: TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 36,
      fontWeight: FontWeight.w700,
      letterSpacing: 1,
    ),
  );

  /// Minimal monochrome theme tokens.
  static const RKTokens minimal = RKTokens(
    primary: Color(0xFFFFFFFF),
    onPrimary: Color(0xFF000000),
    surface: Color(0xFF050505),
    onSurface: Color(0xFFEEEEEE),
    trackColor: Color(0xFF1A1A1A),
    glowColor: Colors.transparent,
    shadowColor: Colors.transparent,
    borderRadius: 0.0,
    elevation: 0.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFFFFFFFF), Color(0xFFDDDDDD)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFF111111), Color(0xFF050505)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    shadows: [],
    glows: [],
    displayTextStyle: TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 24,
      fontWeight: FontWeight.w300,
      fontFamily: 'monospace',
      letterSpacing: 4,
    ),
    bodyTextStyle: TextStyle(
      color: Color(0xFFAAAAAA),
      fontSize: 12,
      fontWeight: FontWeight.w300,
    ),
    headlineTextStyle: TextStyle(
      color: Color(0xFFFFFFFF),
      fontSize: 32,
      fontWeight: FontWeight.w200,
      letterSpacing: 2,
    ),
  );

  /// High-visibility debug theme tokens for development.
  static const RKTokens debug = RKTokens(
    primary: Color(0xFF00FF00),
    onPrimary: Color(0xFF000000),
    surface: Color(0xFF0A0A0A),
    onSurface: Color(0xFF00FF00),
    trackColor: Color(0xFF1A3A1A),
    glowColor: Color(0x6600FF00),
    shadowColor: Colors.transparent,
    borderRadius: 2.0,
    elevation: 0.0,
    primaryGradient: LinearGradient(
      colors: [Color(0xFF00FF00), Color(0xFF00CC00)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    surfaceGradient: LinearGradient(
      colors: [Color(0xFF0A1A0A), Color(0xFF0A0A0A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    shadows: [],
    glows: [
      BoxShadow(
        color: Color(0x6600FF00),
        blurRadius: 8,
        spreadRadius: 1,
      ),
    ],
    displayTextStyle: TextStyle(
      color: Color(0xFF00FF00),
      fontSize: 24,
      fontWeight: FontWeight.bold,
      fontFamily: 'monospace',
      letterSpacing: 4,
    ),
    bodyTextStyle: TextStyle(
      color: Color(0xFF00CC00),
      fontSize: 12,
      fontWeight: FontWeight.w400,
      fontFamily: 'monospace',
    ),
    headlineTextStyle: TextStyle(
      color: Color(0xFF00FF00),
      fontSize: 28,
      fontWeight: FontWeight.w700,
      letterSpacing: 2,
    ),
  );

  RKTokens copyWith({
    Color? primary,
    Color? onPrimary,
    Color? surface,
    Color? onSurface,
    Color? trackColor,
    Color? glowColor,
    Color? shadowColor,
    double? borderRadius,
    double? elevation,
    Gradient? primaryGradient,
    Gradient? surfaceGradient,
    TextStyle? displayTextStyle,
    List<BoxShadow>? shadows,
    List<BoxShadow>? glows,
    TextStyle? bodyTextStyle,
    TextStyle? headlineTextStyle,
  }) {
    return RKTokens(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      trackColor: trackColor ?? this.trackColor,
      glowColor: glowColor ?? this.glowColor,
      shadowColor: shadowColor ?? this.shadowColor,
      borderRadius: borderRadius ?? this.borderRadius,
      elevation: elevation ?? this.elevation,
      primaryGradient: primaryGradient ?? this.primaryGradient,
      surfaceGradient: surfaceGradient ?? this.surfaceGradient,
      displayTextStyle: displayTextStyle ?? this.displayTextStyle,
      shadows: shadows ?? this.shadows,
      glows: glows ?? this.glows,
      bodyTextStyle: bodyTextStyle ?? this.bodyTextStyle,
      headlineTextStyle: headlineTextStyle ?? this.headlineTextStyle,
    );
  }
}
