import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// Variants for the knob.
enum RKKnobVariant { standard, steeringWheel }

/// A premium rotary knob widget for RadioKit.
class RKKnob extends StatefulWidget {
  const RKKnob({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.size = 100.0,
    this.divisions,
    this.onInteractionChanged,
    this.startAngle = -135.0,
    this.endAngle = 135.0,
    this.autoCenter = false,
    this.center = 0.5,
    this.springCurve = Curves.easeOutCubic,
    this.springDuration = const Duration(milliseconds: 500),
    this.variant = RKKnobVariant.standard,
    this.centerIcon,
    this.rotation = 0.0,
    this.label,
  });

  final IconData? centerIcon;
  final RKKnobVariant variant;
  final double rotation;
  final String? label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final Curve springCurve;
  final Duration springDuration;
  final double min;
  final double max;
  final double size;
  final int? divisions;

  /// Start angle in degrees (default -135)
  final double startAngle;

  /// End angle in degrees (default 135)
  final double endAngle;

  /// Whether the knob springs back to center
  final bool autoCenter;

  /// The neutral value to spring back to (normalized 0..1)
  final double center;

  @override
  State<RKKnob> createState() => _RKKnobState();
}

class _RKKnobState extends State<RKKnob> with SingleTickerProviderStateMixin {
  late AnimationController _centerController;
  late Animation<double> _centerAnimation;
  double? _lastEmittedValue;
  double? _previousTouchAngle;
  double _currentAccumulatedRotation = 0;
  bool _isInteracting = false;
  final List<double> _echoBuffer = [];

  void _addToHistory(double val) {
    _echoBuffer.add(val);
    if (_echoBuffer.length > 20) _echoBuffer.removeAt(0);
  }

  @override
  void initState() {
    super.initState();
    _centerController = AnimationController(
      vsync: this,
      duration: widget.springDuration,
    );
    _centerAnimation = CurvedAnimation(
      parent: _centerController,
      curve: Curves.elasticOut,
    );
    _centerController.addListener(() {
      final val = widget.min + _centerAnimation.value * (widget.max - widget.min);
      _emitValue(val.clamp(widget.min, widget.max));
    });
  }

  @override
  void didUpdateWidget(RKKnob oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.springDuration != oldWidget.springDuration) {
      _centerController.duration = widget.springDuration;
    }
    if (widget.value != oldWidget.value) {
      if (_isInteracting) return;
      
      final range = (widget.max - widget.min).abs();
      // Ignore stale echoes found in history
      final isEcho = _echoBuffer.any((v) => (v - widget.value).abs() < range * 0.03);
      if (isEcho) return;
      
      // If animating, ignore updates that are close to current animation position
      if (_centerController.isAnimating) {
        final currentNorm = _centerAnimation.value;
        final currentVal = widget.min + currentNorm * (widget.max - widget.min);
        final diff = (widget.value - currentVal).abs();
        if (diff < range * 0.15) return;
      }

      _lastEmittedValue = widget.value;
      if (_centerController.isAnimating) _centerController.stop();
    }

    if ((widget.autoCenter && !oldWidget.autoCenter) || 
        (widget.autoCenter && widget.center != oldWidget.center)) {
      _triggerCenter();
    }
  }

  @override
  void dispose() {
    _centerController.dispose();
    super.dispose();
  }

  void _emitValue(double val) {
    if (val != _lastEmittedValue) {
      _lastEmittedValue = val;
      _addToHistory(val);
      // Use a microtask to avoid "setState() or markNeedsBuild() called during build" 
      // if this is triggered during a widget update cycle.
      Future.microtask(() => widget.onChanged(val));
    }
  }

  void _triggerCenter() {
    final startNorm = (widget.value - widget.min) / (widget.max - widget.min);
    if ((startNorm - widget.center).abs() < 0.001) return;

    _centerAnimation = Tween<double>(
      begin: startNorm,
      end: widget.center,
    ).animate(CurvedAnimation(
      parent: _centerController,
      curve: widget.springCurve,
    ));
    _centerController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final normalized = (widget.value - widget.min) / (widget.max - widget.min);
    final zeroPos = ((0.0 - widget.min) / (widget.max - widget.min)).clamp(0.0, 1.0);
    
    final sweepRad = (widget.endAngle - widget.startAngle) * math.pi / 180;
    final startRad = (-math.pi / 2) + (widget.startAngle * math.pi / 180);
    final currentAngle = startRad + normalized * sweepRad;

    final double indicatorH = (widget.variant == RKKnobVariant.steeringWheel) ? widget.size * 0.2 : 0.0;
    final double contentH = widget.size + indicatorH;
    final double contentW = widget.size;

    return RKRotatedWrapper(
      rotation: widget.rotation * math.pi / 180,
      label: widget.label,
      contentWidth: contentW,
      contentHeight: contentH,
      labelColor: tokens.primary.withValues(alpha: 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onPanStart: (details) {
              _centerController.stop();
              setState(() => _isInteracting = true);
              widget.onInteractionChanged?.call(true);
              final RenderBox box = context.findRenderObject() as RenderBox;
              final center = box.size.center(Offset.zero);
              final localPos = box.globalToLocal(details.globalPosition);
              _previousTouchAngle = math.atan2(localPos.dy - center.dy, localPos.dx - center.dx) * 180 / math.pi;
              _currentAccumulatedRotation = (normalized - widget.center) * (widget.endAngle - widget.startAngle);
            },
            onPanUpdate: (details) {
              if (_previousTouchAngle == null) return;
              final RenderBox box = context.findRenderObject() as RenderBox;
              final center = box.size.center(Offset.zero);
              final localPos = box.globalToLocal(details.globalPosition);
              final currentTouchAngle = math.atan2(localPos.dy - center.dy, localPos.dx - center.dx) * 180 / math.pi;
              double delta = currentTouchAngle - _previousTouchAngle!;
              if (delta > 180) delta -= 360;
              if (delta < -180) delta += 360;
              _currentAccumulatedRotation += delta;
              _previousTouchAngle = currentTouchAngle;
              final minRot = (0.0 - widget.center) * (widget.endAngle - widget.startAngle);
              final maxRot = (1.0 - widget.center) * (widget.endAngle - widget.startAngle);
              final targetRotation = _currentAccumulatedRotation.clamp(minRot, maxRot);
              final norm = (targetRotation - minRot) / (maxRot - minRot);
              double newVal = widget.min + norm * (widget.max - widget.min);
              if (widget.divisions != null && widget.divisions! > 0) {
                final step = (widget.max - widget.min) / widget.divisions!;
                newVal = ((newVal - widget.min) / step).round() * step + widget.min;
              }
              _emitValue(newVal);
            },
            onPanEnd: (_) {
              setState(() => _isInteracting = false);
              widget.onInteractionChanged?.call(false);
              if (widget.autoCenter) _triggerCenter();
            },
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: Size(widget.size, widget.size),
                    painter: widget.variant == RKKnobVariant.steeringWheel
                        ? _SteeringWheelPainter(
                            angle: currentAngle,
                            tokens: tokens,
                            normalized: normalized,
                            startAngle: startRad,
                            sweepAngle: sweepRad,
                            centerPos: widget.center,
                          )
                        : _KnobPainter(
                            angle: currentAngle,
                            tokens: tokens,
                            normalized: normalized,
                            startAngle: startRad,
                            sweepAngle: sweepRad,
                            centerPos: widget.center,
                          ),
                  ),
                  if (widget.variant == RKKnobVariant.steeringWheel)
                    _SteeringWheelHub(angle: currentAngle, tokens: tokens, centerIcon: widget.centerIcon, knobSize: widget.size),
                  if (widget.variant == RKKnobVariant.standard && widget.centerIcon != null)
                    Transform.rotate(
                      angle: currentAngle + math.pi / 2,
                      child: Icon(widget.centerIcon, color: tokens.primary.withValues(alpha: 0.5), size: widget.size * 0.25),
                    ),
                ],
              ),
            ),
          ),
          if (widget.variant == RKKnobVariant.steeringWheel) ...[
            SizedBox(height: widget.size * 0.14),
            _RKKnobIndicator(normalized: normalized, tokens: tokens, knobSize: widget.size),
          ],
        ],
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({
    required this.angle,
    required this.tokens,
    required this.normalized,
    required this.centerPos,
    required this.startAngle,
    required this.sweepAngle,
  });

  final double angle;
  final RKTokens tokens;
  final double normalized;
  final double centerPos;
  final double startAngle;
  final double sweepAngle;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final knobRadius = radius * 0.8;

    final trackPaint = Paint()
      ..color = tokens.trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    final activePaint = Paint()
      ..color = tokens.primary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final arcStart = startAngle + centerPos * sweepAngle;
    final arcSweep = (normalized - centerPos) * sweepAngle;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 4),
      arcStart,
      arcSweep,
      false,
      activePaint,
    );

    final knobPaint = Paint()
      ..color = tokens.surface
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, knobRadius, Paint()
      ..color = tokens.shadowColor.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    
    canvas.drawCircle(center, knobRadius, knobPaint);

    canvas.drawCircle(center, knobRadius, Paint()
      ..color = tokens.primary.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    final pointerPaint = Paint()
      ..color = tokens.primary
      ..style = PaintingStyle.fill;

    final pointerCenter = Offset(
      center.dx + (knobRadius - 12) * math.cos(angle),
      center.dy + (knobRadius - 12) * math.sin(angle),
    );

    canvas.drawCircle(pointerCenter, 4, pointerPaint);
  }

  @override
  bool shouldRepaint(_KnobPainter old) => old.angle != angle;
}

class _SteeringWheelPainter extends CustomPainter {
  final double angle;
  final RKTokens tokens;
  final double normalized;
  final double centerPos;
  final double startAngle;
  final double sweepAngle;

  const _SteeringWheelPainter({
    required this.angle,
    required this.tokens,
    required this.normalized,
    required this.centerPos,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);
    final rect = Offset.zero & size;

    final rimDark = Color.lerp(Colors.black, tokens.surface, 0.4)!;
    final rimMid = tokens.surface;
    final rimLight = tokens.primary;
    final spokeDark = Color.lerp(Colors.black, tokens.surface, 0.2)!;
    final spoke = tokens.surface;
    final hubDark = Color.lerp(Colors.black, tokens.surface, 0.5)!;
    final hubMid = tokens.surface;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle + math.pi / 2);
    canvas.translate(-center.dx, -center.dy);

    final fillPaint = Paint()..isAntiAlias = true;
    final strokePaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke;

    fillPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [rimMid, rimDark],
    ).createShader(rect);

    final outerRim = Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * 0.37, h, w * 0.24, h * 0.95, w * 0.15, h * 0.85)
      ..cubicTo(w * 0.05, h * 0.76, 0, h * 0.63, 0, h / 2)
      ..cubicTo(0, h * 0.37, w * 0.05, h * 0.24, w * 0.15, h * 0.15)
      ..cubicTo(w * 0.24, h * 0.05, w * 0.37, 0, w / 2, 0)
      ..cubicTo(w * 0.63, 0, w * 0.76, h * 0.05, w * 0.85, h * 0.15)
      ..cubicTo(w * 0.95, h * 0.24, w, h * 0.37, w, h / 2)
      ..cubicTo(w, h * 0.63, w * 0.95, h * 0.76, w * 0.85, h * 0.85)
      ..cubicTo(w * 0.76, h * 0.95, w * 0.63, h, w / 2, h)
      ..lineTo(w / 2, h * 0.1)
      ..cubicTo(w * 0.28, h * 0.1, w * 0.1, h * 0.28, w * 0.1, h / 2)
      ..cubicTo(w * 0.1, h * 0.72, w * 0.28, h * 0.9, w / 2, h * 0.9)
      ..cubicTo(w * 0.72, h * 0.9, w * 0.9, h * 0.72, w * 0.9, h / 2)
      ..cubicTo(w * 0.9, h * 0.28, w * 0.72, h * 0.1, w / 2, h * 0.1)
      ..close();
    canvas.drawPath(outerRim, fillPaint);

    strokePaint
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          rimLight.withValues(alpha: 0.9),
          Colors.black.withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: w * 0.5))
      ..strokeWidth = 1.5
      ..maskFilter = null;
    canvas.drawCircle(center, w * 0.495, strokePaint);

    strokePaint
      ..shader = null
      ..color = Colors.black.withValues(alpha: 0.85)
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, w * 0.45, strokePaint);

    strokePaint
      ..color = Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    for (int i = 0; i < 360; i += 15) {
      final rad = i * math.pi / 180;
      final p1 = center + Offset(math.cos(rad) * w * 0.45, math.sin(rad) * w * 0.45);
      final p2 = center + Offset(math.cos(rad) * w * 0.49, math.sin(rad) * w * 0.49);
      canvas.drawLine(p1, p2, strokePaint);
    }

    strokePaint
      ..shader = null
      ..maskFilter = null
      ..color = Colors.black.withValues(alpha: 0.28)
      ..strokeWidth = w * 0.02;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: w * 0.445),
      0.55, 2.0, false,
      strokePaint,
    );

    fillPaint.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [spoke, spokeDark],
    ).createShader(rect);
    Path path = Path()
      ..moveTo(w / 5, h * 0.39)
      ..cubicTo(w / 5, h * 0.39, w * 0.17, h * 0.45, w * 0.18, h * 0.54)
      ..cubicTo(w / 5, h * 0.56, w * 0.24, h * 0.59, w / 4, h * 0.64)
      ..cubicTo(w * 0.26, h * 0.66, w * 0.26, h * 0.69, w * 0.26, h * 0.71)
      ..cubicTo(w * 0.31, h * 0.71, w * 0.38, h * 0.78, w * 0.38, h * 0.78)
      ..cubicTo(w * 0.42, h * 0.79, w * 0.46, h * 0.79, w / 2, h * 0.79)
      ..cubicTo(w * 0.54, h * 0.79, w * 0.58, h * 0.79, w * 0.62, h * 0.78)
      ..cubicTo(w * 0.69, h * 0.71, w * 0.74, h * 0.71, w * 0.74, h * 0.71)
      ..cubicTo(w * 0.74, h * 0.69, w * 0.74, h * 0.66, w * 0.75, h * 0.64)
      ..cubicTo(w * 0.76, h * 0.59, w * 0.79, h * 0.56, w * 0.82, h * 0.54)
      ..cubicTo(w * 0.83, h * 0.45, w * 0.8, h * 0.39, w * 0.8, h * 0.39)
      ..cubicTo(w * 0.72, h * 0.36, w * 0.61, h * 0.35, w / 2, h * 0.35)
      ..cubicTo(w * 0.39, h * 0.35, w * 0.28, h * 0.36, w / 5, h * 0.39)
      ..close();
    canvas.drawPath(path, fillPaint);

    fillPaint.shader = null;
    fillPaint.color = spokeDark;
    path = Path()
      ..moveTo(w / 4, h * 0.45)
      ..cubicTo(w / 4, h * 0.45, w / 5, h * 0.39, w / 5, h * 0.39)
      ..cubicTo(w * 0.16, h * 0.39, w * 0.13, h * 0.4, w * 0.1, h * 0.42)
      ..cubicTo(w * 0.1, h * 0.42, w * 0.05, h * 0.46, w * 0.05, h * 0.46)
      ..cubicTo(w * 0.05, h * 0.46, w * 0.1, h * 0.52, w * 0.1, h * 0.52)
      ..cubicTo(w * 0.13, h * 0.51, w * 0.16, h * 0.52, w * 0.18, h * 0.54)
      ..cubicTo(w * 0.18, h * 0.54, w / 4, h * 0.45, w / 4, h * 0.45)
      ..close();
    canvas.drawPath(path, fillPaint);

    path = Path()
      ..moveTo(w * 0.75, h * 0.45)
      ..cubicTo(w * 0.75, h * 0.45, w * 0.8, h * 0.39, w * 0.8, h * 0.39)
      ..cubicTo(w * 0.84, h * 0.39, w * 0.87, h * 0.4, w * 0.9, h * 0.42)
      ..cubicTo(w * 0.9, h * 0.42, w * 0.95, h * 0.46, w * 0.95, h * 0.46)
      ..cubicTo(w * 0.95, h * 0.46, w * 0.9, h * 0.52, w * 0.9, h * 0.52)
      ..cubicTo(w * 0.87, h * 0.51, w * 0.84, h * 0.52, w * 0.82, h * 0.54)
      ..cubicTo(w * 0.82, h * 0.54, w * 0.75, h * 0.45, w * 0.75, h * 0.45)
      ..close();
    canvas.drawPath(path, fillPaint);

    path = Path()
      ..moveTo(w * 0.36, h * 0.7)
      ..cubicTo(w * 0.36, h * 0.7, w * 0.26, h * 0.71, w * 0.26, h * 0.71)
      ..cubicTo(w / 4, h * 0.74, w * 0.24, h * 0.77, w * 0.22, h * 0.79)
      ..cubicTo(w * 0.22, h * 0.79, w * 0.23, h * 0.87, w * 0.23, h * 0.87)
      ..cubicTo(w * 0.23, h * 0.87, w * 0.31, h * 0.86, w * 0.31, h * 0.86)
      ..cubicTo(w * 0.31, h * 0.86, w * 0.32, h * 0.81, w * 0.38, h * 0.78)
      ..cubicTo(w * 0.38, h * 0.78, w * 0.36, h * 0.7, w * 0.36, h * 0.7)
      ..close();
    canvas.drawPath(path, fillPaint);

    path = Path()
      ..moveTo(w * 0.64, h * 0.7)
      ..cubicTo(w * 0.64, h * 0.7, w * 0.74, h * 0.71, w * 0.74, h * 0.71)
      ..cubicTo(w * 0.75, h * 0.74, w * 0.76, h * 0.77, w * 0.78, h * 0.79)
      ..cubicTo(w * 0.78, h * 0.79, w * 0.77, h * 0.87, w * 0.77, h * 0.87)
      ..cubicTo(w * 0.77, h * 0.87, w * 0.69, h * 0.86, w * 0.69, h * 0.86)
      ..cubicTo(w * 0.69, h * 0.86, w * 0.68, h * 0.81, w * 0.62, h * 0.78)
      ..cubicTo(w * 0.62, h * 0.78, w * 0.64, h * 0.7, w * 0.64, h * 0.7)
      ..close();
    canvas.drawPath(path, fillPaint);

    final hubRect = Rect.fromCircle(center: center, radius: w * 0.14);
    fillPaint.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [hubMid, hubDark],
    ).createShader(hubRect);
    canvas.drawCircle(center, w * 0.135, fillPaint);

    strokePaint
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [rimLight, Colors.black],
      ).createShader(hubRect)
      ..maskFilter = null
      ..strokeWidth = w * 0.015;
    canvas.drawCircle(center, w * 0.145, strokePaint);

    strokePaint
      ..shader = null
      ..color = rimLight.withValues(alpha: 0.4)
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, w * 0.108, strokePaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SteeringWheelPainter old) =>
      old.angle != angle ||
      old.centerPos != centerPos ||
      old.normalized != normalized;
}

class _SteeringWheelHub extends StatelessWidget {
  final double angle;
  final RKTokens tokens;
  final IconData? centerIcon;
  final double knobSize;
  
  const _SteeringWheelHub({
    required this.angle, 
    required this.tokens,
    this.centerIcon,
    required this.knobSize,
  });

  @override
  Widget build(BuildContext context) {
    final hubSize = knobSize * 0.4;
    final iconSize = knobSize * 0.18;
    return Transform.rotate(
      angle: angle + math.pi / 2,
      child: Container(
        width: hubSize,
        height: hubSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tokens.surface,
              Color.lerp(Colors.black, tokens.surface, 0.5)!,
            ],
          ),
          border: Border.all(
            color: tokens.primary.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: hubSize * 0.16,
              offset: Offset(0, hubSize * 0.065),
            ),
          ],
        ),
        child: Center(
          child: centerIcon != null ? Icon(
            centerIcon,
            color: tokens.primary,
            size: iconSize,
          ) : null,
        ),
      ),
    );
  }
}

class _RKKnobIndicator extends StatelessWidget {
  final double normalized;
  final RKTokens tokens;
  final int dotCount;
  final double knobSize;

  const _RKKnobIndicator({
    required this.normalized,
    required this.tokens,
    this.dotCount = 11,
    required this.knobSize,
  });

  @override
  Widget build(BuildContext context) {
    final spacing = knobSize * 0.04;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(dotCount, (index) {
        final progress = normalized * (dotCount - 1);
        final intensity = _getIntensity(progress, index);
        
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing),
          child: _GlowDot(
            intensity: intensity,
            color: tokens.primary,
            knobSize: knobSize,
          ),
        );
      }),
    );
  }

  double _getIntensity(double progress, int index) {
    double diff = (progress - index).abs();
    if (diff < 1.0) return 1.0 - diff;
    if (diff < 2.0) return (2.0 - diff) * 0.3;
    return 0.0;
  }
}

class _GlowDot extends StatelessWidget {
  final double intensity;
  final Color color;
  final double knobSize;

  const _GlowDot({required this.intensity, required this.color, required this.knobSize});

  @override
  Widget build(BuildContext context) {
    final dimColor = Colors.white.withValues(alpha: 0.08);
    final baseSize = knobSize * 0.036;
    final scale = 1.0 + (1.5 * intensity);
    final size = baseSize * scale;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(dimColor, Colors.white, intensity),
        boxShadow: [
          if (intensity > 0.1)
            BoxShadow(
              color: color.withValues(alpha: intensity * 0.3),
              blurRadius: knobSize * 0.04 * intensity,
              spreadRadius: knobSize * 0.005 * intensity,
            ),
          if (intensity > 0.6)
            BoxShadow(
              color: color.withValues(alpha: (intensity - 0.6) * 0.6),
              blurRadius: knobSize * 0.08 * intensity,
              spreadRadius: knobSize * 0.012 * intensity,
            ),
        ],
      ),
    );
  }
}
