import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/api_log_entry.dart';
import '../providers/remote_access_provider.dart';
import '../theme/app_theme.dart';

class ApiLogView extends StatefulWidget {
  final double height;

  const ApiLogView({super.key, this.height = 240});

  @override
  State<ApiLogView> createState() => _ApiLogViewState();
}

class _ApiLogViewState extends State<ApiLogView> {
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

  Color _methodColor(String method) {
    switch (method) {
      case 'GET':
        return AppColors.connected;
      case 'POST':
        return AppColors.brandOrange;
      case 'PUT':
      case 'PATCH':
        return Colors.amberAccent;
      case 'DELETE':
        return Colors.redAccent;
      case 'SRV':
        return Colors.white38;
      default:
        return Colors.white54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RemoteAccessProvider>(
      builder: (context, ra, _) {
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
                      Icon(Icons.api_rounded,
                          size: 14,
                          color: AppColors.brandOrange.withValues(alpha: 0.7)),
                      const SizedBox(width: 8),
                      Text(
                        'API_LOG',
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              letterSpacing: 1.2,
                              color: AppColors.brandOrange
                                  .withValues(alpha: 0.7),
                            ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_all_rounded, size: 16),
                        onPressed: () {
                          final logText = ra.logs
                              .map((e) =>
                                  '[${e.timeLabel}] ${e.method} ${e.path} → ${e.statusCode} (${e.durationMs}ms)')
                              .join('\n');
                          Clipboard.setData(ClipboardData(text: logText));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Log copied to clipboard'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: Colors.white24,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon:
                            const Icon(Icons.delete_sweep_rounded, size: 16),
                        onPressed: () => ra.clearLog(),
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
                child: _buildLogList(ra),
              )
            else
              SizedBox(
                height: widget.height,
                child: _buildLogList(ra),
              ),
          ],
        );
      },
    );
  }

  Widget _buildLogList(RemoteAccessProvider ra) {
    return Container(
      margin: EdgeInsets.symmetric(
          horizontal: widget.height == double.infinity ? 0 : 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: ra.logs.isEmpty
            ? Center(
                child: Text(
                  'No requests yet',
                  style: TextStyle(color: Colors.white24, fontSize: 12),
                ),
              )
            : ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: ra.logs.length,
                itemBuilder: (context, index) {
                  final entry = ra.logs[index];
                  return _buildLogLine(entry);
                },
              ),
      ),
    );
  }

  Widget _buildLogLine(ApiLogEntry entry) {
    final methodColor = _methodColor(entry.method);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 10,
            height: 1.4,
          ),
          children: [
            TextSpan(
              text: ' [${entry.timeLabel}] ',
              style: const TextStyle(color: Colors.white24),
            ),
            TextSpan(
              text: '${entry.method} ',
              style: TextStyle(
                color: methodColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: entry.path,
              style: const TextStyle(color: Colors.white70),
            ),
            if (entry.statusCode > 0) ...[
              TextSpan(
                text: ' → ${entry.statusCode}',
                style: TextStyle(
                  color: entry.statusCode >= 400
                      ? Colors.redAccent
                      : entry.statusCode >= 300
                          ? AppColors.brandOrange
                          : AppColors.connected,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextSpan(
                text: ' (${entry.durationMs}ms)',
                style: const TextStyle(color: Colors.white24),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
