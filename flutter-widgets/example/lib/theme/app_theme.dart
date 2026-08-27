import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// Global notifier for the current RadioKit theme tokens.
final themeNotifier = ValueNotifier<RKTokens>(RKTokens.dragon);

/// Wraps the app with the selected RadioKit theme.
class AppTheme extends StatelessWidget {
  const AppTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<RKTokens>(
      valueListenable: themeNotifier,
      builder: (context, tokens, _) {
        return RKTheme(
          tokens: tokens,
          child: child,
        );
      },
    );
  }
}
