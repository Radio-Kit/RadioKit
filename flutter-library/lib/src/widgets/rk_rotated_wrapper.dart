import 'package:flutter/material.dart';

/// A wrapper that applies rotation to a RadioKit widget without scaling.
/// The layout size remains [contentWidth] x [contentHeight]; rotation is
/// visual only, so the widget never changes its allocated layout box.
class RKRotatedWrapper extends StatelessWidget {
  final double rotation;
  final String? label;
  final Widget child;
  final double contentWidth;
  final double contentHeight;
  final Color labelColor;
  final bool fitContent;

  const RKRotatedWrapper({
    super.key,
    required this.rotation,
    required this.child,
    required this.contentWidth,
    required this.contentHeight,
    required this.labelColor,
    this.label,
    this.fitContent = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    if (fitContent) {
      content = FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: contentWidth,
          height: contentHeight,
          child: content,
        ),
      );
    }

    if (label != null && label!.isNotEmpty) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label!.toUpperCase(),
            style: TextStyle(
              color: labelColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          content,
        ],
      );
    }

    if (rotation != 0) {
      content = Transform.rotate(
        angle: rotation,
        child: content,
      );
    }

    return content;
  }
}
