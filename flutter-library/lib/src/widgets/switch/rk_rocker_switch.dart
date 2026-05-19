import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// A premium rocker switch widget for RadioKit.
class RKRockerSwitch extends StatefulWidget {
  const RKRockerSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 72,
    this.height = 110,
    this.onIcon,
    this.offIcon,
    this.activeColor,
    this.enableHapticFeedback = true,
    this.onInteractionChanged,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final double width;
  final double height;
  final IconData? onIcon;
  final IconData? offIcon;
  final Color? activeColor;
  final bool enableHapticFeedback;
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  State<RKRockerSwitch> createState() => _RKRockerSwitchState();
}

class _RKRockerSwitchState extends State<RKRockerSwitch>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _rockProgress;
  late Animation<double> _tiltAnimation;
  late Animation<double> _shadowAnimation;

  static const double _tiltAngle = 0.42;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: widget.value ? 1.0 : 0.0,
    );

    _rockProgress = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeOutBack,
    );

    _tiltAnimation = Tween<double>(
      begin: _tiltAngle,
      end: -_tiltAngle,
    ).animate(_rockProgress);

    _shadowAnimation = Tween<double>(
      begin: -10.0,
      end: 10.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void didUpdateWidget(covariant RKRockerSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details) {
    if (_isDragging) return;

    if (widget.enableHapticFeedback) {
      HapticFeedback.mediumImpact();
    }

    final midY = widget.height / 2;
    final tappedTop = details.localPosition.dy < midY;
    if (tappedTop) {
      if (!widget.value) widget.onChanged(true);
    } else {
      if (widget.value) widget.onChanged(false);
    }
  }

  void _handleDragUpdate(double delta) {
    final dragRange = widget.height * 0.45;
    _controller.value = (_controller.value - delta / dragRange).clamp(0.0, 1.0);
  }

  void _handleDragEnd() {
    _isDragging = false;
    widget.onInteractionChanged?.call(false);

    final newValue = _controller.value > 0.5;
    if (newValue != widget.value) {
      if (widget.enableHapticFeedback) {
        HapticFeedback.mediumImpact();
      }
      widget.onChanged(newValue);
    } else {
      if (widget.value) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final activeColor = widget.activeColor ?? tokens.primary;
    
    // The widget actually renders with some extra padding/shadow space.
    final totalWidth = widget.width + 22;
    final totalHeight = widget.height + 22;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: totalWidth,
      contentHeight: totalHeight,
      labelColor: tokens.trackColor.withValues(alpha: 0.8),
      fitContent: true,
      child: GestureDetector(
        onTapDown: (_) => widget.onInteractionChanged?.call(true),
        onTapUp: (details) {
          widget.onInteractionChanged?.call(false);
          _handleTap(details);
        },
        onTapCancel: () => widget.onInteractionChanged?.call(false),
        onVerticalDragStart: (_) {
          _isDragging = true;
          widget.onInteractionChanged?.call(true);
        },
        onVerticalDragUpdate: (details) {
          _handleDragUpdate(details.primaryDelta!);
        },
        onVerticalDragEnd: (_) => _handleDragEnd(),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            final tilt = _tiltAnimation.value;
            final shadowOffset = _shadowAnimation.value;

            return SizedBox(
              width: totalWidth,
              height: totalHeight,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _buildBezel(tokens, widget.width, widget.height),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0022)
                      ..multiply(Matrix4.rotationX(tilt)),
                    child: _buildRocker(tokens, activeColor, shadowOffset, widget.width, widget.height),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBezel(RKTokens tokens, double actualWidth, double actualHeight) {
    return Container(
      width: actualWidth,
      height: actualHeight,
      decoration: BoxDecoration(
        color: const Color(0xFF131313),
        borderRadius: BorderRadius.circular(tokens.borderRadius * 1.35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.85),
            blurRadius: 4,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: const Color(0xFF050505),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(tokens.borderRadius * 1.1),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.03),
              width: 0.8,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRocker(RKTokens tokens, Color activeColor, double shadowOffset, double actualWidth, double actualHeight) {
    final glowIntensity = _rockProgress.value;
    final isTopPressed = shadowOffset < 0;
    final rockerW = actualWidth * 0.88;
    final rockerH = actualHeight * 0.92;
    final rockerRadius = actualWidth * 0.18;

    final topLight = Color.lerp(
      const Color(0xFF404040),
      activeColor.withValues(alpha: 0.55),
      glowIntensity,
    )!;
    final topDark = Color.lerp(
      const Color(0xFF1F1F1F),
      activeColor.withValues(alpha: 0.20),
      glowIntensity,
    )!;

    final faceTop = isTopPressed ? topDark : topLight;
    final faceBottom = isTopPressed ? topLight : topDark;

    return SizedBox(
      width: rockerW,
      height: rockerH,
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(rockerRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.78),
                  blurRadius: 12,
                  spreadRadius: 1,
                  offset: Offset(0, shadowOffset),
                ),
              ],
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(rockerRadius),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(rockerRadius),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [faceTop, faceBottom],
                ),
                boxShadow: [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.28 * glowIntensity),
                    blurRadius: 18 * glowIntensity,
                    spreadRadius: -1,
                  ),
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.18 * glowIntensity),
                    blurRadius: 8 * glowIntensity,
                    spreadRadius: -2,
                  ),
                ],
                border: Border.all(
                  color: Color.lerp(
                    Colors.white.withValues(alpha: 0.08),
                    activeColor.withValues(alpha: 0.55),
                    glowIntensity,
                  )!,
                  width: 0.8,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _DiagonalGridPainter(
                        glowColor: activeColor,
                        glowIntensity: glowIntensity,
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          stops: const [0.0, 0.10, 0.48, 0.52, 1.0],
                          colors: [
                            Colors.white.withValues(alpha: 0.16),
                            Colors.white.withValues(alpha: 0.04),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.10),
                            Colors.black.withValues(alpha: 0.22),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 4,
                    right: 4,
                    top: 4,
                    bottom: 4,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(rockerRadius - 4),
                        border: Border.all(
                          color: Color.lerp(
                            Colors.white.withValues(alpha: 0.05),
                            activeColor.withValues(alpha: 0.22),
                            glowIntensity,
                          )!,
                          width: 0.6,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 6,
                    right: 6,
                    top: 6,
                    height: rockerH * 0.22,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(rockerRadius - 6),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white.withValues(alpha: 0.12),
                              Colors.white.withValues(alpha: 0.01),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: rockerH / 2 - 0.5,
                    left: 8,
                    right: 8,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.white.withValues(alpha: 0.05),
                            Colors.black.withValues(alpha: 0.30),
                            Colors.white.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: rockerH * 0.16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Opacity(
                        opacity: (0.35 + 0.65 * glowIntensity).clamp(0.0, 1.0),
                        child: widget.onIcon != null
                            ? _surfaceGlowIcon(
                                child: Icon(widget.onIcon, size: rockerH * 0.18, color: activeColor),
                                color: activeColor,
                                intensity: glowIntensity,
                              )
                            : _surfaceGlowIcon(
                                child: _defaultOnIcon(),
                                color: activeColor,
                                intensity: glowIntensity,
                              ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: rockerH * 0.15,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Opacity(
                        opacity: (1.0 - 0.72 * glowIntensity).clamp(0.0, 1.0),
                        child: widget.offIcon != null
                            ? Icon(widget.offIcon, size: rockerH * 0.15, color: Colors.white.withValues(alpha: 0.5))
                            : _defaultOffIcon(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _surfaceGlowIcon({
    required Widget child,
    required Color color,
    required double intensity,
  }) {
    if (intensity <= 0.05) return child;

    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25 * intensity),
            blurRadius: 10 * intensity,
            spreadRadius: 0.5,
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _defaultOnIcon() {
    return Container(
      width: 4,
      height: 20,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _defaultOffIcon() {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.78),
          width: 3,
        ),
      ),
    );
  }
}

class _DiagonalGridPainter extends CustomPainter {
  const _DiagonalGridPainter({
    required this.glowColor,
    required this.glowIntensity,
  });

  final Color glowColor;
  final double glowIntensity;

  @override
  void paint(Canvas canvas, Size size) {
    final clipRect = Offset.zero & size;

    final darkStroke = Paint()
      ..color = Colors.black.withValues(alpha: 0.16)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final lightStroke = Paint()
      ..color = Color.lerp(
        Colors.white.withValues(alpha: 0.06),
        glowColor.withValues(alpha: 0.18),
        glowIntensity,
      )!
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    const spacing = 11.0;

    canvas.save();
    canvas.clipRect(clipRect);

    for (double x = -size.height; x < size.width + size.height; x += spacing) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        darkStroke,
      );
      canvas.drawLine(
        Offset(x + 2.2, 0),
        Offset(x + size.height + 2.2, size.height),
        lightStroke,
      );
    }

    for (double x = size.width + size.height; x > -size.height; x -= spacing * 2.2) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.025)
          ..strokeWidth = 0.7,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalGridPainter oldDelegate) {
    return oldDelegate.glowColor != glowColor ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}