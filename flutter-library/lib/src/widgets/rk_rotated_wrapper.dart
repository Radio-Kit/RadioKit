import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'rk_debug_overlay.dart';

/// A wrapper that applies rotation to a RadioKit widget without scaling.
///
/// The widget is laid out in a fixed box whose dimensions are determined by
/// [contentWidth] and (optionally) [contentHeight].  Rotation is **visual
/// only** — the layout box never changes size, so neighbouring widgets are
/// never disturbed.
///
/// ## Rotation pivot
/// The pivot is always the geometric centre of the core box
/// (the fixed [contentWidth] × [contentHeight] area).  The debug border
/// (`RKDebugOverlay`), the [label], and the optional [indicator] all orbit
/// that same centre.
///
/// ## Layout inside the core box
/// * [label] sits just **outside** the debug border (above the core).
/// * [indicator] sits just **outside** the debug border (below the core).
/// * Both the label and indicator rotate together with the core.
class RKRotatedWrapper extends StatelessWidget {
  /// Clockwise rotation in **radians**.
  ///
  /// The pivot is the centre of the core widget, not the centre of the
  /// label or indicator.
  final double rotation;

  /// Optional text drawn immediately above the core widget.
  ///
  /// Sits outside the debug border.  Rotates around the core's centre.
  final String? label;

  /// The underlying control to display.
  final Widget child;

  /// Width of the core layout box in logical pixels.
  final double contentWidth;

  /// Height of the core layout box in logical pixels.
  ///
  /// If `null`, defaults to [contentWidth] for a square aspect ratio.
  final double? contentHeight;

  /// Text colour for [label].
  final Color labelColor;

  /// When `true`, the child is scaled to fit the fixed box while
  /// preserving its aspect ratio.
  final bool fitContent;

  /// Whether to show the debug overlay for this widget instance.
  /// Ignored when [RKDebugOverlay.enabled] is `false`.
  final bool showDebug;

  /// Optional status indicator drawn immediately below the core widget.
  ///
  /// Sits outside the debug border.  Rotates around the core's centre.
  final Widget? indicator;

  /// Vertical gap between [label] and the core, and between the core and
  /// [indicator], in logical pixels.
  static const double _spacing = 4.0;

  /// Scale factor for sizing label offsets and typography relative to the core widget size.
  final double? scale;

  const RKRotatedWrapper({
    super.key,
    required this.rotation,
    required this.child,
    required this.contentWidth,
    this.contentHeight,
    required this.labelColor,
    this.label,
    this.fitContent = false,
    this.showDebug = true,
    this.indicator,
    this.scale,
  });

  @override
  Widget build(BuildContext context) {
    // Resolve final dimensions.  Square aspect is kept when only one dim
    // is supplied.
    final double width = contentWidth;
    final double height = contentHeight ?? contentWidth;

    // Calculate a dynamic scale based on the smaller dimension if scale is not provided.
    // 100.0 is the reference base size.
    final double resolvedScale = scale ?? (math.min(width, height) / 100.0);

    // ── Core widget ──────────────────────────────────────────────────────
    Widget inner = child;
    if (fitContent) {
      inner = FittedBox(fit: BoxFit.contain, child: inner);
    }

    Widget core = SizedBox(
      width: width,
      height: height,
      child: inner,
    );

    // The debug overlay wraps only the core.  The dashed border therefore
    // matches the core's rectangle exactly, and its centre is the rotation
    // pivot.
    if (RKDebugOverlay.enabled) {
      core = RKDebugOverlay(show: showDebug, child: core);
    }

    // ── Assemble in a Stack ──────────────────────────────────────────────
    // A Stack keeps the measured size locked to the core widget only
    // (the non‑positioned child).  The label and indicator are
    // Positioned relative to that same origin so their painted positions
    // are always known, and they participate in the parent Transform.
    final stackChildren = <Widget>[
      // non‑positioned child → defines Stack's measured size = core size
      core,
    ];

    if (label != null && label!.isNotEmpty) {
      stackChildren.add(
        Positioned(
          left: 0,
          right: 0,
          bottom: height + (_spacing * resolvedScale),
          child: Text(
            label!.toUpperCase(),
            style: TextStyle(
              color: labelColor,
              fontSize: 10 * resolvedScale,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2 * resolvedScale,
              fontFamily: 'monospace',
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    if (indicator != null) {
      stackChildren.add(
        Positioned(
          left: 0,
          right: 0,
          top: height + (_spacing * resolvedScale * 2.0),
          child: indicator!,
        ),
      );
    }

    // The Stack's measured size = core size (120×120, for example), which
    // is always exactly the core widget's rectangle.  The rotation pivot
    // (Stack centre = core centre) therefore never moves even when a label
    // or an indicator is present.
    Widget unit = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: stackChildren,
    );

    // Rotate the entire unit around its centre, which is the same as the
    // core's centre (and the debug overlay's centre when enabled).
    if (rotation != 0) {
      unit = Transform.rotate(
        angle: rotation,
        child: unit,
      );
    }

    return unit;
  }
}

