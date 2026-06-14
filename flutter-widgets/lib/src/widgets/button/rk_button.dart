import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// Button mode — momentary (push) or latching (toggle).
enum RKButtonMode { push, toggle }

/// A hardware-style button widget for RadioKit.
class RKButton extends StatefulWidget {
  const RKButton({
    super.key,
    this.value = false,
    required this.onChanged,
    this.mode = RKButtonMode.push,
    this.onText,
    this.offText,
    this.onIcon,
    this.offIcon,
    this.size = 100.0,
    this.enableHapticFeedback = true,
    this.onInteractionChanged,
    this.rotation = 0.0,
    this.label,
    this.showDebug = true,
  });

  /// The fixed aspect ratio (width/height) for this widget.
  static const double? aspectRatio = 1.0;

  final bool value;
  final ValueChanged<bool> onChanged;
  final RKButtonMode mode;
  final String? onText;
  final String? offText;
  final IconData? onIcon;
  final IconData? offIcon;
  final double size;
  final bool enableHapticFeedback;
  final ValueChanged<bool>? onInteractionChanged;
  final double rotation;
  final String? label;
  final bool showDebug;

  @override
  State<RKButton> createState() => _RKButtonState();
}

class _RKButtonState extends State<RKButton> with SingleTickerProviderStateMixin {
  bool _pressed = false;
  bool _isLatched = false;
  bool _pendingAutoReverse = false;
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      reverseDuration: const Duration(milliseconds: 300),
    );
    _glowController.addStatusListener(_onGlowStatusChanged);
    if (widget.mode == RKButtonMode.toggle && widget.value) {
      _isLatched = true;
      _glowController.value = 1.0;
    }
  }

  void _onGlowStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _pendingAutoReverse) {
      _pendingAutoReverse = false;
      widget.onChanged(false);
      setState(() => _pressed = false);
      _glowController.reverse();
    }
  }

  @override
  void didUpdateWidget(RKButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      if (widget.mode == RKButtonMode.toggle) {
        _isLatched = widget.value;
        if (_isLatched) {
          _glowController.forward();
        } else {
          _glowController.reverse();
        }
      } else {
        if (_glowController.isAnimating) return;
        if (widget.value) {
          setState(() => _pressed = true);
          _pendingAutoReverse = true;
          _glowController.forward();
        } else {
          _pendingAutoReverse = false;
          setState(() => _pressed = false);
          _glowController.reverse();
        }
      }
    }
  }

  @override
  void dispose() {
    _glowController.removeStatusListener(_onGlowStatusChanged);
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final activeColor = tokens.primary;

    return RKRotatedWrapper(
      rotation: widget.rotation,
      label: widget.label,
      showDebug: widget.showDebug,
      contentWidth: widget.size,
      contentHeight: widget.size,
      labelColor: tokens.effectiveOutline.withValues(alpha: 0.8),
      fitContent: true,
      child: Listener(
        onPointerDown: (_) => _handleDown(),
        onPointerUp: (_) => _handleUp(),
        onPointerCancel: (_) => _handleCancel(),
        child: AnimatedBuilder(
          animation: _glowController,
          builder: (context, _) {
            final t = Curves.easeOutCubic.transform(_glowController.value);

            return Transform.scale(
              scale: _pressed ? 0.98 : 1.0,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(tokens.radiusSelector),
                  boxShadow: tokens.depth > 0
                      ? [
                          BoxShadow(
                            color: tokens.base300.withValues(alpha: 0.30),
                            blurRadius: 1,
                            offset: Offset.zero,
                          ),
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.5 * t),
                            blurRadius: 1,
                            offset: Offset.zero,
                          ),
                        ]
                      : [],
                ),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(tokens.radiusSelector),
                    color: tokens.surface,
                    border: Border.all(
                      color: tokens.effectiveOutline,
                      width: widget.size * 0.02,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(widget.size * 0.04),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(tokens.radiusSelector),
                        gradient: SweepGradient(
                          colors: [
                            Color.lerp(
                              tokens.surface,
                              activeColor,
                              t,
                            )!,
                            Color.lerp(
                              tokens.base200,
                              Color.lerp(activeColor, tokens.onSurface, 0.3)!,
                              t,
                            )!,
                            Color.lerp(
                              tokens.surface,
                              activeColor,
                              t,
                            )!,
                          ],
                          stops: const [0.0, 0.5, 1.0],
                        ),
                        boxShadow: tokens.depth > 0
                            ? [
                                BoxShadow(
                                  color: activeColor.withValues(alpha: 0.5 * t),
                                  blurRadius: 1,
                                  offset: Offset.zero,
                                ),
                              ]
                            : [],
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(widget.size * 0.08),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(tokens.radiusSelector),
                            color: tokens.surface,
                            border: Border.all(
                              color: tokens.effectiveOutline,
                              width: widget.size * 0.015,
                            ),
                            boxShadow: tokens.depth > 0
                                ? [
                                    BoxShadow(
                                      color: tokens.base300.withValues(alpha: 0.30),
                                      blurRadius: 1,
                                      offset: Offset.zero,
                                    ),
                                  ]
                                : [],
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: _buildContent(t, activeColor, tokens),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(double t, Color activeColor, RKTokens tokens) {
    final currentIcon = (t > 0.5 ? widget.onIcon : widget.offIcon) ?? Icons.power_settings_new_rounded;
    final currentText = (t > 0.5 ? widget.onText : widget.offText);
    final hasText = (widget.onText ?? widget.offText) != null;

    return [
      Icon(
        currentIcon,
        size: widget.size * (hasText ? 0.25 : 0.35),
        color: Color.lerp(
          tokens.onSurface.withValues(alpha: 0.4),
          activeColor,
          t,
        ),
      ),
      if (hasText) ...[
        SizedBox(height: widget.size * 0.05),
        Text(
          (currentText ?? '').toUpperCase(),
          style: TextStyle(
            color: Color.lerp(
              tokens.onSurface.withValues(alpha: 0.4),
              activeColor,
              t,
            ),
            fontSize: widget.size * 0.08,
            letterSpacing: 1.2,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ];
  }

  void _handleDown() {
    _pendingAutoReverse = false;
    if (widget.enableHapticFeedback) HapticFeedback.lightImpact();
    setState(() => _pressed = true);
    widget.onInteractionChanged?.call(true);

    if (widget.mode == RKButtonMode.toggle) {
      _isLatched = !_isLatched;
      if (_isLatched) {
        _glowController.forward();
      } else {
        _glowController.reverse();
      }
      widget.onChanged(_isLatched);
    } else {
      _glowController.forward();
      widget.onChanged(true);
    }
  }

  void _handleUp() {
    setState(() => _pressed = false);
    widget.onInteractionChanged?.call(false);
    if (widget.mode == RKButtonMode.push) {
      _glowController.reverse();
      widget.onChanged(false);
    }
  }

  void _handleCancel() {
    setState(() => _pressed = false);
    widget.onInteractionChanged?.call(false);
    if (widget.mode == RKButtonMode.push) {
      _glowController.reverse();
      widget.onChanged(false);
    }
  }
}