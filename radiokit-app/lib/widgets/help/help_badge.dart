import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'help_bottom_sheet.dart';
import 'help_content.dart';

/// An interactive (?) badge that triggers a contextual [HelpBottomSheet].
class HelpBadge extends StatelessWidget {
  final HelpTopic topic;
  final double size;
  final EdgeInsets padding;

  const HelpBadge({
    super.key,
    required this.topic,
    this.size = 18.0,
    this.padding = const EdgeInsets.all(4.0),
  });

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Semantics(
      button: true,
      label: 'Help: ${topic.title}',
      child: InkWell(
        borderRadius: BorderRadius.circular(size),
        onTap: () => HelpBottomSheet.show(context, topic),
        child: Padding(
          padding: padding,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.primary.withValues(alpha: 0.12),
              border: Border.all(
                color: tokens.primary.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              '?',
              style: TextStyle(
                color: tokens.primary,
                fontSize: size * 0.65,
                fontWeight: FontWeight.bold,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
