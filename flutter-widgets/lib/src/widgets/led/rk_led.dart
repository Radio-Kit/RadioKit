import 'dart:math';
import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// Shapes available for the RKLed widget.
enum RKLEDShape {
  circle,
  square,
  diamond,
  star,
}

/// Operating states for the RKLed widget.
enum RKLEDState {
  off,
  on,
  blink,
  breathe,
}

/// LED indicator widget for RadioKit.
class RKLed extends StatefulWidget {
  const RKLed({
    super.key,
    this.state = RKLEDState.off,
    this.shape = RKLEDShape.circle,
    this.size = 24.0,
    this.color,
    this.timing = 500,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  /// The fixed aspect ratio (width/height) for this widget.
  static const double? aspectRatio = 1.0;

  final RKLEDState state;
  final RKLEDShape shape;
  final double size;
  final Color? color;
  final int timing;
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  State<RKLed> createState() => _RKLedState();
}

class _RKLedState extends State<RKLed> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: widget.timing),
    );
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    _updateAnimation();
  }

  @override
  void didUpdateWidget(RKLed oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state || oldWidget.timing != widget.timing) {
      _controller.duration = Duration(milliseconds: widget.timing);
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _controller.stop();
    if (widget.state == RKLEDState.blink) {
      _opacity = _controller.drive(Tween<double>(begin: 0.0, end: 1.0));
      _controller.repeat(reverse: true);
    } else if (widget.state == RKLEDState.breathe) {
      _opacity = _controller.drive(CurveTween(curve: Curves.easeInOutSine));
      _controller.repeat(reverse: true);
    } else {
      _opacity = const AlwaysStoppedAnimation(1.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final baseColor = widget.color ?? tokens.primary;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: widget.size,
      contentHeight: widget.size,
      labelColor: tokens.effectiveOutline.withValues(alpha: 0.8),
      fitContent: true,
      child: AnimatedBuilder(
        animation: _opacity,
        builder: (context, child) {
          double currentOpacity = 1.0;
          bool isActive = false;

          switch (widget.state) {
            case RKLEDState.off:
              isActive = false;
              currentOpacity = 1.0;
              break;
            case RKLEDState.on:
              isActive = true;
              currentOpacity = 1.0;
              break;
            case RKLEDState.blink:
              isActive = true;
              currentOpacity = _opacity.value > 0.5 ? 1.0 : 0.0;
              break;
            case RKLEDState.breathe:
              isActive = true;
              currentOpacity = _opacity.value;
              break;
          }

          final ledColor = isActive ? baseColor.withValues(alpha: currentOpacity) : tokens.effectiveOutline;

          return SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _LEDPainter(
                color: ledColor,
                shape: widget.shape,
                glow: isActive ? baseColor.withValues(alpha: currentOpacity * 0.4) : Colors.transparent,
                glowSize: widget.size * 0.4,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LEDPainter extends CustomPainter {
  _LEDPainter({
    required this.color,
    required this.shape,
    required this.glow,
    required this.glowSize,
  });

  final Color color;
  final RKLEDShape shape;
  final Color glow;
  final double glowSize;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    if (glow != Colors.transparent) {
      final glowPaint = Paint()
        ..color = glow
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowSize);
      _drawShape(canvas, size, glowPaint);
    }

    _drawShape(canvas, size, paint);
  }

  void _drawShape(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    switch (shape) {
      case RKLEDShape.circle:
        canvas.drawCircle(center, radius, paint);
        break;
      case RKLEDShape.square:
        canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
        break;

      case RKLEDShape.diamond:
        final path = Path()
          ..moveTo(size.width / 2, 0)
          ..lineTo(size.width, size.height / 2)
          ..lineTo(size.width / 2, size.height)
          ..lineTo(0, size.height / 2)
          ..close();
        canvas.drawPath(path, paint);
        break;
      case RKLEDShape.star:
        final path = _getStarPath(size.width, size.height);
        canvas.drawPath(path, paint);
        break;
    }
  }

  Path _getStarPath(double width, double height) {
    final path = Path();
    final centerX = width / 2;
    final centerY = height / 2;
    final outerRadius = width / 2;
    final innerRadius = width / 4;
    const points = 5;
    const angle = (2 * pi) / points;

    for (int i = 0; i < points; i++) {
      double x = centerX + outerRadius * sin(i * angle);
      double y = centerY - outerRadius * cos(i * angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }

      x = centerX + innerRadius * sin(i * angle + angle / 2);
      y = centerY - innerRadius * cos(i * angle + angle / 2);
      path.lineTo(x, y);
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant _LEDPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.shape != shape || oldDelegate.glow != glow;
  }
}
