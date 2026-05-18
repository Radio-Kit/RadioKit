import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';

/// Data model for a single toggle item in [RKMultiButton] or [RKMultiSelect].
class RKToggleItem {
  final String? onLabel;
  final String? offLabel;
  final IconData? onIcon;
  final IconData? offIcon;

  const RKToggleItem({
    this.onLabel,
    this.offLabel,
    this.onIcon,
    this.offIcon,
  });

  String labelFor(bool selected) => (selected ? onLabel : offLabel) ?? '';
  IconData? iconFor(bool selected) => (selected ? onIcon : offIcon);
}

/// Radio-style multi-button group for RadioKit.
///
/// ### Defined aspect ratio
/// The widget enforces a strict **N:1** width:height ratio where **N = number
/// of items**.  Each per-button slot is `buttonSize` × `buttonSize`; a fixed
/// `gap` separates consecutive buttons.  There are no freeform spacing
/// parameters.
class RKMultiButton extends StatelessWidget {
  const RKMultiButton({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.buttonSize = 24.0,
    this.gap = 8.0,
    this.enableHapticFeedback = true,
    this.onActiveChanged,
    this.orientation = RKAxis.horizontal,
    this.rotation = 0.0,
    this.label,
  });

  final List<RKToggleItem> items;
  final int selected;
  final ValueChanged<int> onChanged;
  final double buttonSize;
  final double gap;
  final bool enableHapticFeedback;
  final ValueChanged<bool>? onActiveChanged;
  final RKAxis orientation;
  final double rotation;
  final String? label;

  /// Content dimensions that enforce the strict N:1 aspect ratio.
  ///
  /// `buttonSize * count` × `buttonSize` → N:1 exactly.
  static Offset _contentSize(int count, double buttonSize, {required bool horizontal}) =>
      horizontal
          ? Offset(buttonSize * count, buttonSize)
          : Offset(buttonSize, buttonSize * count);

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final int count = items.length;
    final bool isHorizontal = orientation == RKAxis.horizontal;

    final double cw = _contentSize(count, buttonSize, horizontal: isHorizontal).dx;
    final double ch = _contentSize(count, buttonSize, horizontal: isHorizontal).dy;

    return RKRotatedWrapper(
      rotation: rotation,
      label: label,
      contentWidth: cw,
      contentHeight: ch,
      labelColor: tokens.primary.withValues(alpha: 0.7),
      fitContent: true,
      child: Container(
        width: cw,
        height: ch,
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.trackColor, width: 1),
          borderRadius: BorderRadius.circular(tokens.borderRadius * 2.5),
          boxShadow: tokens.shadows,
        ),
        child: Listener(
          onPointerDown: (_) => onActiveChanged?.call(true),
          onPointerUp: (_) => onActiveChanged?.call(false),
          onPointerCancel: (_) => onActiveChanged?.call(false),
          child: _buildAxis(count, tokens, isHorizontal),
        ),
      ),
    );
  }

  Widget _buildAxis(int count, RKTokens tokens, bool isHorizontal) {
    final children = <Widget>[];
    for (int i = 0; i < count; i++) {
      if (i > 0) {
        children.add(isHorizontal
            ? SizedBox(width: gap)
            : SizedBox(height: gap));
      }
      children.add(_Button(
        item: items[i],
        selected: i == selected,
        buttonSize: buttonSize,
        onTap: () {
          if (enableHapticFeedback) {
            HapticFeedback.lightImpact();
          }
          onChanged(i);
        },
        tokens: tokens,
      ));
    }
    if (isHorizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    } else {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
  }
}

class _Button extends StatelessWidget {
  final RKToggleItem item;
  final bool selected;
  final double buttonSize;
  final VoidCallback onTap;
  final RKTokens tokens;

  const _Button({
    required this.item,
    required this.selected,
    required this.buttonSize,
    required this.onTap,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final double radius = tokens.borderRadius * 2.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutQuart,
          width: buttonSize,
          height: buttonSize,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: selected
                ? tokens.primaryGradient
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      tokens.surface.withValues(alpha: 0.8),
                      tokens.surface.withValues(alpha: 0.5),
                    ],
                  ),
            border: Border.all(
              color: selected ? Colors.transparent : tokens.trackColor,
              width: 1.0,
            ),
            boxShadow: selected ? tokens.glows : null,
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.iconFor(selected),
                  size: buttonSize * 0.3,
                  color: selected ? tokens.surface : tokens.onSurface.withValues(alpha: 0.5),
                ),
                SizedBox(height: buttonSize * 0.08),
                Text(
                  item.labelFor(selected).toUpperCase(),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? tokens.surface : tokens.onSurface.withValues(alpha: 0.5),
                    fontSize: buttonSize * 0.1,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
