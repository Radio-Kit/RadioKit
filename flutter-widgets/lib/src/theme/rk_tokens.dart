import 'package:flutter/material.dart';

/// Design tokens shared across all RadioKit widgets.
///
/// Follows the DaisyUI semantic color model with 20 color fields,
/// 3 border-radius tokens, 3 sizing tokens, and 2 effect tokens.
class RKTokens {
  const RKTokens({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.accent,
    required this.onAccent,
    required this.neutral,
    required this.onNeutral,
    required this.surface,
    required this.onSurface,
    required this.base200,
    required this.base300,
    required this.info,
    required this.onInfo,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.error,
    required this.onError,
    this.outlineColor,
    this.borderRadius = 16.0,
    this.radiusSelector = 16.0,
    this.radiusField = 8.0,
    this.sizeSelector = 4.0,
    this.sizeField = 4.0,
    this.borderWidth = 1.0,
    this.depth = 1,
    this.noise = 0,
  });

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color accent;
  final Color onAccent;
  final Color neutral;
  final Color onNeutral;
  final Color surface;
  final Color onSurface;
  final Color base200;
  final Color base300;
  final Color info;
  final Color onInfo;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color error;
  final Color onError;
  final Color? outlineColor;
  final double borderRadius;
  final double radiusSelector;
  final double radiusField;
  final double sizeSelector;
  final double sizeField;
  final double borderWidth;
  final int depth;
  final int noise;

  Color get effectiveOutline => outlineColor ?? onSurface.withValues(alpha: 0.2);

  // -- Presets --
  static const RKTokens debug = RKTokens(
    surface: Color(0xFFFFF248),
    onSurface: Color(0xFF000000),
    base200: Color(0xFFF7E83A),
    base300: Color(0xFFE3D40E),
    primary: Color(0xFFFF6596),
    onPrimary: Color(0xFF180408),
    secondary: Color(0xFF00E8FF),
    onSecondary: Color(0xFF001316),
    accent: Color(0xFFCE74FF),
    onAccent: Color(0xFF0F0517),
    neutral: Color(0xFF111A3B),
    onNeutral: Color(0xFFFFF248),
    info: Color(0xFF00B5FF),
    onInfo: Color(0xFF000000),
    success: Color(0xFF00A96E),
    onSuccess: Color(0xFF000000),
    warning: Color(0xFFFFBE00),
    onWarning: Color(0xFF000000),
    error: Color(0xFFFF5861),
    onError: Color(0xFF000000),
    borderRadius: 0.0,
    radiusSelector: 0.0,
    radiusField: 0.0,
    sizeSelector: 4.0,
    sizeField: 4.0,
    borderWidth: 1.0,
    depth: 0,
    noise: 0,
  );
  static const RKTokens dragon = RKTokens(
    surface: Color(0xFF1B1816),
    onSurface: Color(0xFFCDCDCD),
    base200: Color(0xFF0B0908),
    base300: Color(0xFF000000),
    primary: Color(0xFFFCB700),
    onPrimary: Color(0xFF131616),
    secondary: Color(0xFF7A00C2),
    onSecondary: Color(0xFFE3D4F6),
    accent: Color(0xFF42AA00),
    onAccent: Color(0xFF000000),
    neutral: Color(0xFF2F1B05),
    onNeutral: Color(0xFFD2CCC7),
    info: Color(0xFF2563EB),
    onInfo: Color(0xFFD2E2FF),
    success: Color(0xFF18A34A),
    onSuccess: Color(0xFF000A02),
    warning: Color(0xFFD97708),
    onWarning: Color(0xFF110500),
    error: Color(0xFFF35248),
    onError: Color(0xFF140202),
    borderRadius: 16.0,
    radiusSelector: 16.0,
    radiusField: 8.0,
    sizeSelector: 4.0,
    sizeField: 4.0,
    borderWidth: 1.0,
    depth: 1,
    noise: 0,
  );
  static const RKTokens minimal = RKTokens(
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF161616),
    base200: Color(0xFFF5F5F5),
    base300: Color(0xFFEBEBEB),
    primary: Color(0xFFD4D4D4),
    onPrimary: Color(0xFF242424),
    secondary: Color(0xFFD4D4D4),
    onSecondary: Color(0xFF242424),
    accent: Color(0xFFD4D4D4),
    onAccent: Color(0xFF242424),
    neutral: Color(0xFFD4D4D4),
    onNeutral: Color(0xFF242424),
    info: Color(0xFF005889),
    onInfo: Color(0xFFB8E6FE),
    success: Color(0xFF006044),
    onSuccess: Color(0xFFA3F2CE),
    warning: Color(0xFF963B00),
    onWarning: Color(0xFFFDE484),
    error: Color(0xFF9D0410),
    onError: Color(0xFFFEC8C8),
    borderRadius: 0.0,
    radiusSelector: 0.0,
    radiusField: 0.0,
    sizeSelector: 4.0,
    sizeField: 4.0,
    borderWidth: 1.0,
    depth: 1,
    noise: 0,
  );
  static const RKTokens retro = RKTokens(
    surface: Color(0xFFECE3CA),
    onSurface: Color(0xFF793205),
    base200: Color(0xFFE4D8B4),
    base300: Color(0xFFDBCA9B),
    primary: Color(0xFFFF9FA0),
    onPrimary: Color(0xFF801518),
    secondary: Color(0xFFB7F6CD),
    onSecondary: Color(0xFF00642E),
    accent: Color(0xFFD08700),
    onAccent: Color(0xFF793205),
    neutral: Color(0xFF56524C),
    onNeutral: Color(0xFFD4D0CE),
    info: Color(0xFF0082CE),
    onInfo: Color(0xFFFEF2C6),
    success: Color(0xFF00776F),
    onSuccess: Color(0xFFFEF2C6),
    warning: Color(0xFFF34700),
    onWarning: Color(0xFFFEF2C6),
    error: Color(0xFFFF6266),
    onError: Color(0xFF7C2808),
    borderRadius: 32.0,
    radiusSelector: 0.0,
    radiusField: 0.0,
    sizeSelector: 4.0,
    sizeField: 4.0,
    borderWidth: 1.0,
    depth: 0,
    noise: 0,
  );
  static const RKTokens rose = RKTokens(
    surface: Color(0xFFFCF2F8),
    onSurface: Color(0xFFC5005A),
    base200: Color(0xFFF9E4F0),
    base300: Color(0xFFF9CBE5),
    primary: Color(0xFFF43098),
    onPrimary: Color(0xFFFFFFFF),
    secondary: Color(0xFFAB44FF),
    onSecondary: Color(0xFFF8F3FD),
    accent: Color(0xFF71D1FE),
    onAccent: Color(0xFF014A70),
    neutral: Color(0xFF830C41),
    onNeutral: Color(0xFFF9CBE5),
    info: Color(0xFF51E8FB),
    onInfo: Color(0xFF005889),
    success: Color(0xFF5CE8B3),
    onSuccess: Color(0xFF006044),
    warning: Color(0xFFFF8904),
    onWarning: Color(0xFF421104),
    error: Color(0xFFF82834),
    onError: Color(0xFFFEF2F2),
    borderRadius: 16.0,
    radiusSelector: 16.0,
    radiusField: 32.0,
    sizeSelector: 4.0,
    sizeField: 4.0,
    borderWidth: 1.0,
    depth: 0,
    noise: 0,
  );

  RKTokens copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? accent,
    Color? onAccent,
    Color? neutral,
    Color? onNeutral,
    Color? surface,
    Color? onSurface,
    Color? base200,
    Color? base300,
    Color? info,
    Color? onInfo,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? error,
    Color? onError,
    Color? outlineColor,
    double? borderRadius,
    double? radiusSelector,
    double? radiusField,
    double? sizeSelector,
    double? sizeField,
    double? borderWidth,
    int? depth,
    int? noise,
  }) {
    return RKTokens(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      base200: base200 ?? this.base200,
      base300: base300 ?? this.base300,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      outlineColor: outlineColor ?? this.outlineColor,
      borderRadius: borderRadius ?? this.borderRadius,
      radiusSelector: radiusSelector ?? this.radiusSelector,
      radiusField: radiusField ?? this.radiusField,
      sizeSelector: sizeSelector ?? this.sizeSelector,
      sizeField: sizeField ?? this.sizeField,
      borderWidth: borderWidth ?? this.borderWidth,
      depth: depth ?? this.depth,
      noise: noise ?? this.noise,
    );
  }
}
