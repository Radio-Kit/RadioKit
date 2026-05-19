import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// A text display output widget for RadioKit.
class RKDisplay extends StatelessWidget {
  const RKDisplay({
    super.key,
    required this.text,
    this.width = 180,
    this.height = 40,
    this.fontSize = 14,
    this.fontFamily = 'monospace',
    this.onInteractionChanged,
    this.rotation = 0.0,
    this.label,
  });

  final String text;
  final double width;
  final double height;
  final double fontSize;
  final String fontFamily;
  final ValueChanged<bool>? onInteractionChanged;
  final double rotation;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    final baseStyle = TextStyle(
      color: tokens.primary,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );

    TextStyle textStyle;
    if (['monospace', 'serif', 'sans-serif'].contains(fontFamily)) {
      textStyle = baseStyle;
    } else {
      try {
        textStyle = GoogleFonts.getFont(fontFamily, textStyle: baseStyle);
      } catch (_) {
        textStyle = baseStyle;
      }
    }
    
    Widget content = Listener(
      onPointerDown: (_) => onInteractionChanged?.call(true),
      onPointerUp: (_) => onInteractionChanged?.call(false),
      onPointerCancel: (_) => onInteractionChanged?.call(false),
      child: Container(
        width: width,
        height: height,
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(
          horizontal: width * 0.06,
          vertical: height * 0.1,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(tokens.borderRadius),
          border: Border.all(color: tokens.trackColor, width: 1.5),
        ),
        child: Text(
          text,
          style: textStyle.copyWith(fontSize: fontSize * (height / 40).clamp(0.6, 1.5)),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return RKRotatedWrapper(
      rotation: rotation,
      label: label,
      contentWidth: width,
      contentHeight: height,
      labelColor: tokens.trackColor.withValues(alpha: 0.8),
      fitContent: true,
      child: content,
    );
  }
}
