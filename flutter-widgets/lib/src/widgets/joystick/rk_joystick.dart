import 'package:flutter/material.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// 2-axis joystick value.
class RKJoystickValue {
  const RKJoystickValue({this.x = 0.0, this.y = 0.0, this.isActive = false});
  /// X axis: -1.0 (left) to 1.0 (right)
  final double x;
  /// Y axis: -1.0 (down) to 1.0 (up)
  final double y;
  /// True when the widget is being actively interacted with (e.g. dragged)
  final bool isActive;

  /// Returns true if the position (x, y) is nearly identical.
  /// Useful for ignoring protocol echoes that might have rounding errors.
  bool isSamePosition(RKJoystickValue? other) {
    if (other == null) return false;
    return (x - other.x).abs() < 0.03 && (y - other.y).abs() < 0.03;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RKJoystickValue &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          isActive == other.isActive;

  @override
  int get hashCode => Object.hash(x, y, isActive);
}

/// A premium 2-axis joystick widget for RadioKit.
class RKJoystick extends StatefulWidget {
  const RKJoystick({
    super.key,
    required this.onChanged,
    this.value,
    this.center = const RKJoystickValue(x: 0, y: 0),
    this.size = 140.0,
    this.autoCenter = true,
    this.label,
    this.springCurve = Curves.easeOutCubic,
    this.springDuration = const Duration(milliseconds: 300),
    this.rotation = 0.0,
    this.showDebug = true,
  });

  /// The fixed aspect ratio (width/height) for this widget.
  static const double? aspectRatio = 1.0;

  final ValueChanged<RKJoystickValue> onChanged;
  final RKJoystickValue? value;
  final RKJoystickValue center;
  final double size;
  final bool autoCenter;
  final String? label;
  final Curve springCurve;
  final Duration springDuration;
  final double rotation;
  final bool showDebug;

  @override
  State<RKJoystick> createState() => _RKJoystickState();
}

class _RKJoystickState extends State<RKJoystick> with SingleTickerProviderStateMixin {
  Offset _knobOffset = Offset.zero;
  late AnimationController _centerController;
  late Animation<Offset> _centerAnimation;
  RKJoystickValue? _lastEmittedValue;
  final List<RKJoystickValue> _echoBuffer = [];
  bool _isInteracting = false;

  void _addToHistory(RKJoystickValue val) {
    _echoBuffer.add(val);
    if (_echoBuffer.length > 20) _echoBuffer.removeAt(0);
  }

  @override
  void initState() {
    super.initState();
    if (widget.value != null) {
      _knobOffset = _offsetFromValue(widget.value!);
      _lastEmittedValue = widget.value;
    }
    _centerController = AnimationController(
      vsync: this,
      duration: widget.springDuration,
    );
    _centerAnimation = Tween<Offset>(
      begin: _knobOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _centerController,
      curve: widget.springCurve,
    ));

    _centerController.addListener(() {
      final newOffset = _centerAnimation.value;
      final radius = widget.size / 2;

      setState(() {
        if (newOffset.distance <= radius) {
          _knobOffset = newOffset;
        } else {
          _knobOffset = Offset.fromDirection(newOffset.direction, radius);
        }
      });
      _updateValue(_knobOffset);
    });
  }

  @override
  void didUpdateWidget(covariant RKJoystick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.springDuration != oldWidget.springDuration) {
      _centerController.duration = widget.springDuration;
    }
    
    // MASTER-SLAVE Logic: If the user is actively interacting with the joystick,
    // we ignore all external value updates. The local user is the "Master".
    if (_isInteracting) return;

    if (widget.value != null && widget.value != oldWidget.value) {
      // ECHO FILTER: Ignore updates that match our recent emission history.
      // This solves the lagged loopback problem in WIDGETS_DEMO.
      final isEcho = _echoBuffer.any((v) => v.isSamePosition(widget.value));
      if (isEcho) return;

      final newOffset = _offsetFromValue(widget.value!);
      final distance = (newOffset - _knobOffset).distance;
      // Since we have the echo buffer, we can use a much tighter threshold for real external updates.
      final isExternalUpdate = distance > 0.05;

      if (isExternalUpdate) {
        final centerOffset = _offsetFromValue(widget.center);
        
        // If the external update is exactly the center, treat it as a command to center (release)
        final isCenterValue = (newOffset.dx - centerOffset.dx).abs() < 0.001 && 
                             (newOffset.dy - centerOffset.dy).abs() < 0.001;

        if (widget.autoCenter && isCenterValue) {
          _lastEmittedValue = widget.value;
          _triggerCenter(target: centerOffset);
        } else {
          // Hard jump to external value
          if (_centerController.isAnimating) _centerController.stop();
          setState(() {
            _knobOffset = newOffset;
            _lastEmittedValue = widget.value;
          });
        }
      }
    }

    if (widget.autoCenter) {
      final centerOffset = _offsetFromValue(widget.center);
      final wasToggledOn = !oldWidget.autoCenter;
      final centerChanged = widget.center != oldWidget.center;

      if ((wasToggledOn || centerChanged) && (_knobOffset - centerOffset).distance > 0.001) {
        _triggerCenter(target: centerOffset);
      }
    }
  }

  void _triggerCenter({Offset? target}) {
    final endTarget = target ?? _offsetFromValue(widget.center);
    _centerController.stop();
    _centerAnimation = Tween<Offset>(
      begin: _knobOffset,
      end: endTarget,
    ).animate(CurvedAnimation(
      parent: _centerController,
      curve: widget.springCurve,
    ));
    _centerController.forward(from: 0);
  }

  Offset _offsetFromValue(RKJoystickValue value) {
    final radius = widget.size / 2;
    return Offset(
      value.x * radius,
      -value.y * radius,
    );
  }

  @override
  void dispose() {
    _centerController.dispose();
    super.dispose();
  }

  void _updateValue(Offset offset) {
    final radius = widget.size / 2;
    double dx = offset.dx / radius;
    double dy = -offset.dy / radius;
    if (dx.abs() < 0.001) dx = 0.0;
    if (dy.abs() < 0.001) dy = 0.0;

    final newValue = RKJoystickValue(
      x: dx.clamp(-1.0, 1.0),
      y: dy.clamp(-1.0, 1.0),
      isActive: _isInteracting,
    );

    if (newValue != _lastEmittedValue) {
      _lastEmittedValue = newValue;
      
      // Add to echo buffer to ignore lagged loopback updates
      _addToHistory(newValue);

      // We use a microtask only if we are currently in a build phase (e.g. from listener during build)
      // otherwise we emit synchronously to satisfy the "synchronous data flow" requirement.
      Future.microtask(() => widget.onChanged(newValue));
    }
  }

  void _onPanStart(DragStartDetails details) {
    _isInteracting = true;
    _centerController.stop();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final box = context.findRenderObject() as RenderBox;
    final center = box.size.center(Offset.zero);
    final localPos = box.globalToLocal(details.globalPosition);
    final delta = localPos - center;
    final radius = widget.size / 2;
    final newOffset = delta;
    if (newOffset.distance <= radius) {
      setState(() => _knobOffset = newOffset);
    } else {
      setState(() => _knobOffset = Offset.fromDirection(newOffset.direction, radius));
    }
    _updateValue(_knobOffset);
  }

  void _onPanEnd(DragEndDetails details) {
    _isInteracting = false;
    if (widget.autoCenter) {
      _triggerCenter(target: _offsetFromValue(widget.center));
    } else {
      _updateValue(_knobOffset);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final radius = widget.size / 2;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: widget.size,
      contentHeight: widget.size,
      labelColor: tokens.effectiveOutline.withValues(alpha: 0.8),
      fitContent: true,
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: CustomPaint(
            painter: _JoystickPainter(
              knobOffset: _knobOffset,
              tokens: tokens,
              radius: radius,
            ),
          ),
        ),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  _JoystickPainter({
    required this.knobOffset,
    required this.tokens,
    required this.radius,
  });

  final Offset knobOffset;
  final RKTokens tokens;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final trackPaint = Paint()
      ..shader = LinearGradient(colors: [tokens.surface, tokens.base200]).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, trackPaint);

    if (tokens.depth > 0) {
      canvas.drawCircle(center, radius, Paint()
        ..color = tokens.base300.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    }

    final bevelPaint = Paint()
      ..color = tokens.onSurface.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawCircle(center, radius - 2, bevelPaint);

    final guidePaint = Paint()
      ..color = tokens.effectiveOutline.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), guidePaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), guidePaint);

    final knobCenter = center + knobOffset;
    final knobRadius = radius * 0.35;

    final knobPaint = Paint()
      ..shader = LinearGradient(colors: [tokens.primary, tokens.primary.withValues(alpha: 0.8)]).createShader(Rect.fromCircle(center: knobCenter, radius: knobRadius))
      ..style = PaintingStyle.fill;

    if (tokens.depth > 0) {
      canvas.drawCircle(knobCenter, knobRadius, Paint()
        ..color = tokens.base300.withValues(alpha: 0.30)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1));
    }

    canvas.drawCircle(knobCenter, knobRadius, knobPaint);

    canvas.drawCircle(knobCenter - Offset(knobRadius * 0.3, knobRadius * 0.3), knobRadius * 0.2, Paint()
      ..color = tokens.onSurface.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.knobOffset != knobOffset;
}
