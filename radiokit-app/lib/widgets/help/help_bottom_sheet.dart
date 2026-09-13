import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';
import '../themed_bottom_sheet.dart';
import 'help_content.dart';

/// Modal bottom sheet presenting detailed contextual help for a topic.
class HelpBottomSheet extends StatelessWidget {
  final HelpTopic topic;

  const HelpBottomSheet({super.key, required this.topic});

  static Future<void> show(BuildContext context, HelpTopic topic) {
    return showThemedBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.tokens.base200,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => HelpBottomSheet(topic: topic),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokens.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(topic.icon, color: tokens.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      topic.title.toUpperCase(),
                      style: GoogleFonts.changa(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 1.2,
                        color: tokens.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topic.summary,
                      style: TextStyle(
                        fontSize: 12,
                        color: tokens.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.base300,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tokens.onSurface.withValues(alpha: 0.08)),
            ),
            child: Text(
              topic.explanation,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: tokens.onSurface.withValues(alpha: 0.9),
              ),
            ),
          ),
          if (topic.hardwareTip != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tokens.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.primary.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded,
                      color: tokens.primary, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      topic.hardwareTip!,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                        color: tokens.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tokens.primary,
                foregroundColor: tokens.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'GOT IT',
                style: GoogleFonts.changa(
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
