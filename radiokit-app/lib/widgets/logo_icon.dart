import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class LogoIcon extends StatelessWidget {
  const LogoIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(context.tokens.primary),
            _dot(context.tokens.primary),
            _dot(context.tokens.primary),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _dot(context.tokens.primary),
            _dot(context.tokens.onSurface.withValues(alpha: 0.1)),
            _dot(context.tokens.primary),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 4,
      height: 6,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
