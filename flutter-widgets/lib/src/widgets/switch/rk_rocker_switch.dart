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

  /// The fixed aspect ratio (width/height) for this widget.
  static const double? aspectRatio = 0.5;

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

    // Use the real widget dimensions — shadows overflow via Clip.none.
    final totalWidth = widget.width;
    final totalHeight = widget.height;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: totalWidth,
      contentHeight: totalHeight,
      labelColor: tokens.effectiveOutline.withValues(alpha: 0.8),
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
                clipBehavior: Clip.none,
                children: [
                  _buildBezel(tokens, widget.width, widget.height),
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.0022)
                      ..multiply(Matrix4.rotationX(tilt)),
                    child: _buildRocker(tokens, activeColor, shadowOffset,
                        widget.width, widget.height),
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
    final double bezelPadding = (actualWidth * 0.07).clamp(2.0, 12.0);
    final double outerBorderWidth = (actualWidth * 0.028).clamp(1.0, 4.0);
    final double innerBorderWidth = (actualWidth * 0.011).clamp(0.5, 2.0);

    return Container(
      width: actualWidth,
      height: actualHeight,
      decoration: BoxDecoration(
        color: tokens.base200,
        borderRadius:
            BorderRadius.circular((tokens.borderRadius * 1.35).clamp(4, 24)),
        boxShadow: tokens.depth > 0
            ? [
                BoxShadow(
                  color: tokens.base300.withValues(alpha: 0.3),
                  blurRadius: 1,
                ),
              ]
            : [],
        border: Border.all(
          color: tokens.base300,
          width: outerBorderWidth,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(bezelPadding),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius:
                BorderRadius.circular((tokens.borderRadius * 1.1).clamp(2, 20)),
            border: Border.all(
              color: tokens.onSurface.withValues(alpha: 0.03),
              width: innerBorderWidth,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRocker(RKTokens tokens, Color activeColor, double shadowOffset,
      double actualWidth, double actualHeight) {
    final glowIntensity = _rockProgress.value;
    final isTopPressed = shadowOffset < 0;
    final rockerW = actualWidth * 0.88;
    final rockerH = actualHeight * 0.92;
    final rockerRadius = tokens.radiusSelector;

    final topLight = Color.lerp(
      tokens.surface,
      activeColor.withValues(alpha: 0.55),
      glowIntensity,
    )!;
    final topDark = Color.lerp(
      tokens.base300,
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
              boxShadow: tokens.depth > 0
                  ? [
                      BoxShadow(
                        color: tokens.base300.withValues(alpha: 0.3),
                        blurRadius: 1,
                      ),
                    ]
                  : [],
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
boxShadow: tokens.depth > 0 && glowIntensity > 0.1
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.15 * glowIntensity),
                          blurRadius: 0.5,
                        ),
                      ]
                    : [],
                border: Border.all(
                  color: Color.lerp(
                    tokens.onSurface.withValues(alpha: 0.08),
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
                        tokens: tokens,
                        glowColor: activeColor,
                        glowIntensity: glowIntensity,
                        spacing: rockerH * 0.109,
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
                            tokens.onSurface.withValues(alpha: 0.16),
                            tokens.onSurface.withValues(alpha: 0.04),
                            Colors.transparent,
                            tokens.onSurface.withValues(alpha: 0.10),
                            tokens.onSurface.withValues(alpha: 0.22),
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
                            tokens.onSurface.withValues(alpha: 0.05),
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
                              tokens.onSurface.withValues(alpha: 0.12),
                              tokens.onSurface.withValues(alpha: 0.01),
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
                            tokens.onSurface.withValues(alpha: 0.05),
                            tokens.onSurface.withValues(alpha: 0.30),
                            tokens.onSurface.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: rockerH * 0.15,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Opacity(
                        opacity: (0.35 + 0.65 * glowIntensity).clamp(0.0, 1.0),
child: widget.onIcon != null
                             ? _surfaceGlowIcon(
                                 child: Icon(widget.onIcon,
                                     size: rockerH * 0.26, color: activeColor),
                                 color: activeColor,
                                 intensity: glowIntensity,
                                 tokens: tokens,
                               )
                             : _surfaceGlowIcon(
                                 child: _defaultOnIcon(tokens, rockerH),
                                 color: activeColor,
                                 intensity: glowIntensity,
                                 tokens: tokens,
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
                            ? Icon(widget.offIcon,
                                size: rockerH * 0.26,
        color: tokens.onSurface.withValues(alpha: 0.5))
                        : _defaultOffIcon(tokens, rockerH),
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
    required RKTokens tokens,
  }) {
    if (intensity <= 0.05) return child;

    return tokens.depth > 0 && intensity > 0.05
        ? Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.15 * intensity),
                  blurRadius: 0.5,
                ),
              ],
            ),
            child: child,
          )
        : child;
  }

  Widget _defaultOnIcon(RKTokens tokens, double rockerH) {
    return Container(
      width: rockerH * 0.04,
      height: rockerH * 0.198,
      decoration: BoxDecoration(
        color: tokens.onSurface,        borderRadius: BorderRadius.circular(tokens.radiusSelector),
      ),
    );
  }

  Widget _defaultOffIcon(RKTokens tokens, double rockerH) {
    final size = rockerH * 0.198;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(tokens.radiusSelector),
        border: Border.all(
          color: tokens.onSurface.withValues(alpha: 0.78),
          width: size * 0.15,
        ),
      ),
    );
  }
}

class _DiagonalGridPainter extends CustomPainter {
  const _DiagonalGridPainter({
    required this.tokens,
    required this.glowColor,
    required this.glowIntensity,
    required this.spacing,
  });

  final RKTokens tokens;
  final Color glowColor;
  final double glowIntensity;
  final double spacing;

  @override
  void paint(Canvas canvas, Size size) {
    final clipRect = Offset.zero & size;

    final darkStroke = Paint()
      ..color = tokens.onSurface.withValues(alpha: 0.16)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    final lightStroke = Paint()
      ..color = Color.lerp(
        tokens.onSurface.withValues(alpha: 0.06),
        glowColor.withValues(alpha: 0.18),
        glowIntensity,
      )!
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final spacing = this.spacing;

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

    for (double x = size.width + size.height;
        x > -size.height;
        x -= spacing * 2.2) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x - size.height, size.height),
        Paint()
          ..color = tokens.onSurface.withValues(alpha: 0.025)
          ..strokeWidth = 0.7,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _DiagonalGridPainter oldDelegate) {
    return oldDelegate.tokens != tokens ||
        oldDelegate.glowColor != glowColor ||
        oldDelegate.glowIntensity != glowIntensity;
  }
}
