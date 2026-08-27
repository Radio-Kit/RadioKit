import 'package:flutter/material.dart';
import 'rk_tokens.dart';
export 'rk_tokens.dart';

/// Provides RadioKit theme data to the widget tree.
class RKTheme extends InheritedWidget {
  const RKTheme({
    super.key,
    required this.tokens,
    required super.child,
  });

  final RKTokens tokens;

  static RKTokens of(BuildContext context) {
    final result = context.dependOnInheritedWidgetOfExactType<RKTheme>();
    assert(result != null, 'No RKTheme found in context');
    return result!.tokens;
  }

  @override
  bool updateShouldNotify(RKTheme oldWidget) => tokens != oldWidget.tokens;
}

/// Standard axis orientation for RadioKit widgets.
enum RKAxis { horizontal, vertical }

