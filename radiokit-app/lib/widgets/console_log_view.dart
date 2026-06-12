import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/console_provider.dart';
import '../models/console_entry.dart';
import '../theme/app_theme.dart';

class ConsoleLogView extends StatefulWidget {
  final double height;
  const ConsoleLogView({super.key, this.height = 200});

  @override
  State<ConsoleLogView> createState() => _ConsoleLogViewState();
}

class _ConsoleLogViewState extends State<ConsoleLogView> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConsoleProvider>(
      builder: (context, console, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

        final isExpanded = widget.height == double.infinity;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.terminal_rounded, size: 14, color: AppColors.brandOrange.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Text(
                        'CONSOLE_LOG',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              letterSpacing: 1.2,
                              color: AppColors.brandOrange.withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        onPressed: () {
                          console.copyToClipboard().then((_) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Log copied to clipboard'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.delete_sweep_rounded, size: 16),
                        onPressed: () => console.clear(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.white24,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (isExpanded)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: console.entries.length,
                      itemBuilder: (context, index) {
                        final entry = console.entries[index];
                        return _buildLogLine(entry);
                      },
                    ),
                  ),
                ),
              )
            else
              Container(
                height: widget.height,
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: console.entries.length,
                    itemBuilder: (context, index) {
                      final entry = console.entries[index];
                      return _buildLogLine(entry);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLogLine(ConsoleEntry entry) {
    Color textColor = Colors.white70;
    String prefix = '';

    switch (entry.level) {
      case ConsoleLogLevel.info:
        textColor = Colors.white70;
        break;
      case ConsoleLogLevel.success:
        textColor = AppColors.connected;
        prefix = '[SUCCESS] ';
        break;
      case ConsoleLogLevel.warning:
        textColor = AppColors.brandOrange;
        prefix = '[WARN] ';
        break;
      case ConsoleLogLevel.error:
        textColor = Colors.redAccent;
        prefix = '[ERROR] ';
        break;
      case ConsoleLogLevel.raw:
        textColor = Colors.white38;
        break;
      case ConsoleLogLevel.print:
        textColor = Colors.cyanAccent;
        prefix = '[PRINT] ';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 11,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: ' [${entry.timeLabel}] ',
              style: const TextStyle(color: Colors.white24),
            ),
            if (prefix.isNotEmpty)
              TextSpan(
                text: prefix,
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
              ),
            TextSpan(
              text: entry.message,
              style: TextStyle(color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
