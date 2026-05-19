import 'package:flutter/material.dart';
import 'rk_debug_overlay.dart';

/// A wrapper that applies rotation to a RadioKit widget without scaling.
/// The layout size remains [contentWidth] x [contentHeight]; rotation is
/// visual only, so the widget never changes its allocated layout box.
class RKRotatedWrapper extends StatelessWidget {
  final double rotation;
  final String? label;
  final Widget child;
  final double contentWidth;
  // For square‑aspect widgets only one dimension is required; if
  // contentHeight is supplied it must equal contentWidth. The wrapper
  // computes a unified size to avoid contradictory constraints.
  final double? contentHeight;
  final Color labelColor;
  final bool fitContent;
  final Widget? indicator;

  const RKRotatedWrapper({
    super.key,
    required this.rotation,
    required this.child,
    required this.contentWidth,
    this.contentHeight,
    required this.labelColor,
    this.label,
    this.fitContent = false,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the actual size. If height is omitted, use width to keep a square box.
    final double width = contentWidth;
    final double height = contentHeight ?? contentWidth;

    // Optional scaling to fit content.
    Widget inner = child;
    if (fitContent) {
      inner = FittedBox(
        fit: BoxFit.contain,
        child: inner,
      );
    }

    // Fixed‑size container for the interactive widget. The debug overlay
    // wraps only this core box, so the dashed border appears around the
    // control itself; the label and indicator are not inside the border.
    Widget core = SizedBox(
      width: width,
      height: height,
      child: inner,
    );
    if (RKDebugOverlay.enabled) {
      core = RKDebugOverlay(show: true, child: core);
    }

    // Assemble the full unit (label / core / indicator).
    final unitChildren = <Widget>[];
    if (label != null && label!.isNotEmpty) {
      unitChildren.add(Text(
        label!.toUpperCase(),
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
      ));
      unitChildren.add(const SizedBox(height: 8));
    }
    unitChildren.add(core);
    if (indicator != null) {
      unitChildren.add(const SizedBox(height: 8));
      unitChildren.add(indicator!);
    }

    Widget unit = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: unitChildren,
    );

    // Rotate the whole assembly so label and indicator turn together with
    // the core widget (and its debug overlay).
    if (rotation != 0) {
      unit = Transform.rotate(
        angle: rotation,
        child: unit,
      );
    }

    return unit;
  }
}
