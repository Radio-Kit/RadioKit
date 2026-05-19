import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// A stealth neon industrial slide switch for RadioKit.
class RKSlideSwitch extends StatefulWidget {
  const RKSlideSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.width = 190.0,
    this.height = 82.0,
    this.activeColor,
    this.enableHapticFeedback = true,
    this.onInteractionChanged,
    this.rotation = 0.0,
    this.onText = 'ON',
    this.offText = 'OFF',
    this.label,
    this.icon,
    this.showDebug = true,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final ValueChanged<bool>? onInteractionChanged;
  final double width;
  final double height;
  final Color? activeColor;
  final bool enableHapticFeedback;
  final double rotation;
  final String onText;
  final String offText;
  final String? label;
  final Widget? icon;
  final bool showDebug;

  @override
  State<RKSlideSwitch> createState() => _RKSlideSwitchState();
}

class _RKSlideSwitchState extends State<RKSlideSwitch> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: widget.value ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void didUpdateWidget(RKSlideSwitch oldWidget) {
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

  void _handleToggle() {
    if (_isDragging) return;
    if (widget.enableHapticFeedback) HapticFeedback.mediumImpact();
    widget.onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final outerWidth = widget.width;
    final outerHeight = widget.height;
    
    const double trackPadding = 8.0;
    final trackWidth = outerWidth - (trackPadding * 2);
    final trackHeight = outerHeight - (trackPadding * 2);
    
    const double thumbPadding = 4.0;
    final thumbWidth = (64.0 / 190.0) * outerWidth;
    final thumbHeight = trackHeight - (thumbPadding * 2);

    final tokens = RKTheme.of(context);
    final baseActiveColor = widget.activeColor ?? tokens.primary;
    final activeHSL = HSLColor.fromColor(baseActiveColor);
    
    final lightActive = activeHSL.withLightness((activeHSL.lightness + 0.15).clamp(0, 1)).toColor();
    final borderActive = activeHSL.withLightness((activeHSL.lightness + 0.2).clamp(0, 1)).toColor();
    final mutedActive = activeHSL.withSaturation(activeHSL.saturation * 0.4).withLightness((activeHSL.lightness * 0.5).clamp(0, 1)).toColor();
    final darkerMuted = activeHSL.withSaturation(activeHSL.saturation * 0.3).withLightness((activeHSL.lightness * 0.3).clamp(0, 1)).toColor();
    final borderMuted = activeHSL.withSaturation(activeHSL.saturation * 0.4).withLightness((activeHSL.lightness * 0.4).clamp(0, 1)).toColor();

    final thumbChild = widget.icon != null
        ? Center(
            child: IconTheme(
              data: IconThemeData(
                color: widget.value
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.5),
                size: thumbHeight * 0.4,
              ),
              child: widget.icon!,
            ),
          )
        : _ThumbGripTexture(isActive: widget.value);

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: outerWidth,
      contentHeight: outerHeight,
      labelColor: tokens.trackColor.withValues(alpha: 0.8),
      fitContent: true,
      child: GestureDetector(
        onTapDown: (_) => widget.onInteractionChanged?.call(true),
        onTapUp: (_) => widget.onInteractionChanged?.call(false),
        onTapCancel: () => widget.onInteractionChanged?.call(false),
        onTap: _handleToggle,
        onHorizontalDragStart: (_) {
          _isDragging = true;
          widget.onInteractionChanged?.call(true);
        },
        onHorizontalDragUpdate: (details) {
          final dragRange = trackWidth - thumbWidth - (thumbPadding * 2);
          if (dragRange <= 0) return;
          _controller.value = (_controller.value + details.primaryDelta! / dragRange).clamp(0.0, 1.0);
        },
        onHorizontalDragEnd: (details) {
          _isDragging = false;
          widget.onInteractionChanged?.call(false);
          
          final velocity = details.primaryVelocity ?? 0.0;
          bool newValue = widget.value;
          
          if (velocity.abs() > 300) {
            newValue = velocity > 0;
          } else {
            newValue = _controller.value >= 0.5;
          }

          if (newValue != widget.value) {
            if (widget.enableHapticFeedback) HapticFeedback.mediumImpact();
            widget.onChanged(newValue);
          } else {
            if (widget.value) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          }
        },
        child: Container(
          width: outerWidth,
          height: outerHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(outerHeight * 0.5),
            color: tokens.surface,
            border: Border.all(
              color: tokens.trackColor.withValues(alpha: 0.5),
              width: 2.0,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black87,
                blurRadius: 15.0,
                offset: Offset(0, 8),
              ),
              BoxShadow(
                color: Color(0xFF28282A),
                blurRadius: 2.0,
                offset: Offset(0, 1),
                blurStyle: BlurStyle.inner,
              ),
            ],
          ),
          child: Center(
            child: Container(
              width: trackWidth,
              height: trackHeight,
              decoration: BoxDecoration(
                color: Color.alphaBlend(Colors.black.withValues(alpha: 0.3), tokens.surface),
                borderRadius: BorderRadius.circular(trackHeight * 0.5),
                border: Border.all(color: tokens.trackColor.withValues(alpha: 0.3), width: 1.0),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black,
                    blurRadius: 6.0,
                    offset: Offset(0, 3),
                    blurStyle: BlurStyle.inner,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: trackWidth * 0.15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildLabel(widget.offText, false, baseActiveColor),
                        _buildLabel(widget.onText, true, baseActiveColor),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final pos = _animation.value;
                      final dragRange = trackWidth - thumbWidth - (thumbPadding * 2);
                      
                      return Positioned(
                        left: thumbPadding + (pos * dragRange),
                        child: Container(
                          width: thumbWidth,
                          height: thumbHeight,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(thumbHeight * 0.5),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: widget.value
                                  ? [lightActive, baseActiveColor]
                                  : [mutedActive, darkerMuted],
                            ),
                            border: Border.all(
                              color: widget.value ? borderActive : borderMuted,
                              width: 1.5,
                            ),
                            boxShadow: [
                              const BoxShadow(
                                color: Colors.black54,
                                blurRadius: 4.0,
                                offset: Offset(0, 3),
                              ),
                              if (widget.value)
                                BoxShadow(
                                  color: baseActiveColor.withValues(alpha: 0.5),
                                  blurRadius: 12.0,
                                  spreadRadius: 2.0,
                                ),
                            ],
                          ),
                          child: thumbChild,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text, bool isOnSide, Color activeColor) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final isLit = isOnSide ? _controller.value >= 0.5 : _controller.value < 0.5;
        return AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 300),
          style: TextStyle(
            fontFamily: 'sans-serif',
            fontSize: 16.0,
            fontWeight: FontWeight.w800,
            color: isLit ? activeColor : RKTheme.of(context).onSurface.withValues(alpha: 0.3),
            shadows: isLit
                ? [
                    Shadow(
                      color: activeColor.withValues(alpha: 0.38),
                      blurRadius: 8.0,
                    ),
                  ]
                : [],
          ),
          child: Text(text),
        );
      },
    );
  }
}

class _ThumbGripTexture extends StatelessWidget {
  final bool isActive;
  const _ThumbGripTexture({required this.isActive});

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final baseColor = tokens.primary;
    final activeHSL = HSLColor.fromColor(baseColor);
    
    final darkGrip = activeHSL.withLightness((activeHSL.lightness - 0.2).clamp(0, 1)).toColor();
    final lightGrip = activeHSL.withLightness((activeHSL.lightness + 0.2).clamp(0, 1)).toColor();
    final mutedGrip = activeHSL.withSaturation(activeHSL.saturation * 0.4).withLightness((activeHSL.lightness * 0.4).clamp(0, 1)).toColor();
    final mutedHighlight = activeHSL.withSaturation(activeHSL.saturation * 0.4).withLightness((activeHSL.lightness * 0.5).clamp(0, 1)).toColor();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (index) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 4.0,
          margin: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: BoxDecoration(
            color: isActive ? darkGrip : mutedGrip,
            borderRadius: BorderRadius.circular(2.0),
            boxShadow: [
              BoxShadow(
                color: isActive ? lightGrip : mutedHighlight,
                offset: const Offset(1, 0),
                blurRadius: 0.0,
              ),
            ],
          ),
        );
      }),
    );
  }
}
