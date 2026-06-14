import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

class DemoCard extends StatelessWidget {
  const DemoCard({
    super.key,
    required this.index,
    required this.title,
    required this.liveWidget,
    required this.inputLabel,
    this.inputValue,
    this.telemetry,
    this.inputWidget,
    this.outputWidget,
  });

  final int index;
  final String title;
  final Widget liveWidget;
  final String inputLabel;
  final String? inputValue;
  final String? telemetry;
  final Widget? inputWidget;
  final Widget? outputWidget;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: tokens.effectiveOutline,
          width: 1,
        ),
      ),
      color: tokens.surface,
      clipBehavior: Clip.antiAlias,
      elevation: 4,
      child: Column(
        children: [
          // ─── Card header ───
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: tokens.surface,
              border: Border(
                bottom: BorderSide(color: tokens.effectiveOutline, width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.onSurface,
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const Spacer(),
                Icon(
                  LucideIcons.ellipsisVertical,
                  color: tokens.onSurface.withValues(alpha: 0.3),
                  size: 16,
                ),
              ],
            ),
          ),
          // ─── Main body: widget canvas ───
          Container(
            height: 220,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.2,
                colors: [
                  tokens.surface,
                  tokens.base200,
                ],
              ),
            ),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: liveWidget,
              ),
            ),
          ),
          // ─── Bottom panel: INPUT + TELEMETRY ───
          Container(
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: tokens.effectiveOutline, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: INPUT SIGNAL
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          inputLabel.toUpperCase(),
                          style: TextStyle(
                            color: tokens.onSurface.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (inputWidget != null)
                          inputWidget!
                        else ...[
                          Row(
                            children: [
                              Text(
                                '> SET VAL: ',
                                style: TextStyle(
                                  color: tokens.onSurface.withValues(alpha: 0.6),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: tokens.surface,
                                  border: Border.all(
                                    color: tokens.effectiveOutline,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Text(
                                  inputValue ?? '--',
                                  style: TextStyle(
                                    color: tokens.primary,
                                    fontSize: 12,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Divider
                Container(
                  width: 1,
                  height: 120,
                  color: tokens.effectiveOutline,
                ),
                // Right: TELEMETRY
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TELEMETRY',
                          style: TextStyle(
                            color: tokens.onSurface.withValues(alpha: 0.5),
                            fontSize: 10,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (outputWidget != null)
                          outputWidget!
                        else ...[
                          TelemetryRow(
                            label: 'STATE',
                            value: telemetry ?? 'IDLE',
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class TelemetryRow extends StatelessWidget {
  const TelemetryRow({
    super.key,
    required this.label,
    required this.value,
    this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.onSurface.withValues(alpha: 0.35),
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color ?? tokens.onSurface.withValues(alpha: 0.8),
              fontSize: 9,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
