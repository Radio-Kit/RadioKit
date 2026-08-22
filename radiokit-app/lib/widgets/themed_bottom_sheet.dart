import 'package:flutter/material.dart';

/// Shows a modal bottom sheet with a theme-aware scrim behind it.
///
/// In dark mode the scrim is semi-transparent white (lightens),
/// in light mode it is semi-transparent black (darkens).
Future<T?> showThemedBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = true,
  bool useSafeArea = false,
  bool showDragHandle = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  ShapeBorder? shape,
}) {
  final brightness = Theme.of(context).brightness;
  final scrimColor = brightness == Brightness.dark
      ? Colors.white.withValues(alpha: 0.06)
      : Colors.black.withValues(alpha: 0.38);

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    useSafeArea: useSafeArea,
    showDragHandle: showDragHandle,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    barrierColor: scrimColor,
    backgroundColor: backgroundColor,
    shape: shape,
    builder: builder,
  );
}
