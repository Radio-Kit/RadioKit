import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// A serial monitor widget for RadioKit.
class RKSerialMonitor extends StatefulWidget {
  const RKSerialMonitor({
    super.key,
    required this.messages,
    this.width = 300,
    this.height = 200,
    this.fontSize = 12,
    this.fontFamily = 'monospace',
    this.onInteractionChanged,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  final List<String> messages;
  final double width;
  final double height;
  final double fontSize;
  final String fontFamily;
  final ValueChanged<bool>? onInteractionChanged;
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  State<RKSerialMonitor> createState() => _RKSerialMonitorState();
}

class _RKSerialMonitorState extends State<RKSerialMonitor> {
  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    final baseStyle = TextStyle(
      color: tokens.primary,
      fontSize: widget.fontSize,
      fontFamily: widget.fontFamily,
      height: 1.2,
    );

    TextStyle textStyle;
    if (['monospace', 'serif', 'sans-serif'].contains(widget.fontFamily)) {
      textStyle = baseStyle;
    } else {
      try {
        textStyle = GoogleFonts.getFont(widget.fontFamily, textStyle: baseStyle);
      } catch (_) {
        textStyle = baseStyle;
      }
    }
    
    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: widget.width,
      contentHeight: widget.height,
      labelColor: tokens.outlineColor.withValues(alpha: 0.8),
      fitContent: true,
      child: Listener(
        onPointerDown: (_) => widget.onInteractionChanged?.call(true),
        onPointerUp: (_) => widget.onInteractionChanged?.call(false),
        onPointerCancel: (_) => widget.onInteractionChanged?.call(false),
        child: Container(
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: tokens.surface,
            borderRadius: BorderRadius.circular(tokens.borderRadius),
            border: Border.all(color: tokens.outlineColor, width: 1.5),
          ),
          child: ListView.builder(
            reverse: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: widget.messages.length,
            itemBuilder: (context, index) {
              final messageIndex = widget.messages.length - 1 - index;
              if (messageIndex < 0) return const SizedBox.shrink();
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  widget.messages[messageIndex],
                  style: textStyle,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
