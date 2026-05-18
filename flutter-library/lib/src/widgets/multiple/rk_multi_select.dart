import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/rk_theme.dart';
import '../rk_rotated_wrapper.dart';
import 'rk_multi_button.dart';

/// Bitmask multi-select group for RadioKit.
///
/// ### Defined aspect ratio
/// Same as [RKMultiButton]: strict **N:1** width:height ratio where **N =
/// number of items**.
class RKMultiSelect extends StatelessWidget {
  const RKMultiSelect({
    super.key,
    required this.items,
    required this.bitmask,
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
  final int bitmask;
  final ValueChanged<int> onChanged;
  final double buttonSize;
  final double gap;
  final bool enableHapticFeedback;
  final ValueChanged<bool>? onActiveChanged;
  final RKAxis orientation;
  final double rotation;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final int count = items.length;
    final bool isHorizontal = orientation == RKAxis.horizontal;

    final double cw = isHorizontal
        ? buttonSize * count
        : buttonSize;
    final double ch = isHorizontal
        ? buttonSize
        : buttonSize * count;

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
      final isSelected = ((bitmask >> i) & 1) == 1;
      children.add(_SelectButton(
        item: items[i],
        selected: isSelected,
        buttonSize: buttonSize,
        onTap: () {
          if (enableHapticFeedback) {
            HapticFeedback.selectionClick();
          }
          onChanged(bitmask ^ (1 << i));
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

class _SelectButton extends StatelessWidget {
  final RKToggleItem item;
  final bool selected;
  final double buttonSize;
  final VoidCallback onTap;
  final RKTokens tokens;

  const _SelectButton({
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
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
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
