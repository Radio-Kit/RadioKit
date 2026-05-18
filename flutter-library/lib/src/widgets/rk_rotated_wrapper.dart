import 'package:flutter/material.dart';

/// A wrapper that applies rotation to a RadioKit widget without scaling.
/// The layout size remains [contentWidth] x [contentHeight]; rotation is
/// visual only, so the widget never changes its allocated layout box.
class RKRotatedWrapper extends StatelessWidget {
  final double rotation;
  final String? label;
  final Widget child;
  final double contentWidth;
  final double contentHeight;
  final Color labelColor;
  final bool fitContent;
  final Widget? indicator;

  const RKRotatedWrapper({
    super.key,
    required this.rotation,
    required this.child,
    required this.contentWidth,
    required this.contentHeight,
    required this.labelColor,
    this.label,
    this.fitContent = false,
    this.indicator,
  });

  @override
  Widget build(BuildContext context) {
    Widget cyanBox = SizedBox(
      width: contentWidth,
      height: contentHeight,
      child: child,
    );

    if (fitContent) {
      cyanBox = FittedBox(
        fit: BoxFit.contain,
        child: cyanBox,
      );
    }

    if (rotation != 0) {
      cyanBox = Transform.rotate(
        angle: rotation,
        child: cyanBox,
      );
    }

    final columnChildren = <Widget>[];

    if (label != null && label!.isNotEmpty) {
      columnChildren.add(Text(
        label!.toUpperCase(),
        style: TextStyle(
          color: labelColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          fontFamily: 'monospace',
        ),
        textAlign: TextAlign.center,
      ));
      columnChildren.add(const SizedBox(height: 8));
    }

    columnChildren.add(cyanBox);

    if (indicator != null) {
      columnChildren.add(const SizedBox(height: 8));
      columnChildren.add(indicator!);
    }

    if (columnChildren.length == 1) {
      return columnChildren.first;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: columnChildren,
    );
  }
}