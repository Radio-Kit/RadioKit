import 'package:flutter/material.dart';

/// A hideable debug overlay that paints a dull dashed border around a widget's
/// layout bounds. Useful for visually verifying widget bounding boxes during
/// development.
///
/// Toggle [enabled] globally; set [show] on individual instances to override.
class RKDebugOverlay extends StatelessWidget {
  /// Global toggle — when `false` the overlay is invisible regardless of [show].
  static bool enabled = false;

  /// Whether this instance renders. Ignored when [enabled] is `false`.
  final bool show;

  /// Rotation in radians applied visually to the border.
  final double rotation;

  /// Border color (dull by default).
  final Color color;

  /// Dash pattern: stroke length.
  final double dashLength;

  /// Dash pattern: gap length.
  final double gapLength;

  final double strokeWidth;
  final double borderRadius;
  final Widget child;

  const RKDebugOverlay({
    super.key,
    this.show = true,
    this.rotation = 0,
    this.color = const Color(0x55AAFFFF),
    this.dashLength = 4,
    this.gapLength = 3,
    this.strokeWidth = 1.5,
    this.borderRadius = 2,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled || !show) return child;

     Widget border = IgnorePointer(
      child: CustomPaint(
        painter: _DashedBorderPainter(
          color: color,
          strokeWidth: strokeWidth,
          dashLength: dashLength,
          gapLength: gapLength,
          borderRadius: borderRadius,
        ),
      ),
    );

    if (rotation != 0) {
      border = Transform.rotate(
        angle: rotation,
        child: border,
      );
    }

    return Stack(
      children: [
        child,
        Positioned.fill(child: border),
      ],
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashLength;
  final double gapLength;
  final double borderRadius;

  _DashedBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashLength,
    required this.gapLength,
    required this.borderRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        strokeWidth / 2,
        strokeWidth / 2,
        size.width - strokeWidth,
        size.height - strokeWidth,
      ),
      Radius.circular(borderRadius),
    );

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashLength).clamp(0, metric.length).toDouble();
        final segment = metric.extractPath(distance, end);
        canvas.drawPath(segment, paint);
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.dashLength != dashLength ||
      oldDelegate.gapLength != gapLength ||
      oldDelegate.borderRadius != borderRadius;
}
