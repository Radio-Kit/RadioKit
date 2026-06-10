import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../widgets/radiokit_app_bar.dart';
import '../providers/debug_provider.dart';
import '../models/debug_log_entry.dart';
import '../theme/app_theme.dart';

/// Transport-agnostic debug monitor.
///
/// Two tabs:
///   1. Packet Log  — real-time hex + decoded packet stream (MCU + APP)
///   2. Send        — manual packet builder + quick-send buttons
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final ScrollController _scroll = ScrollController();
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _cmdCtrl = TextEditingController();
  final TextEditingController _payloadCtrl = TextEditingController();
  String? _sendError;

  // cmd byte input: either 0-255 decimal or 0x00 hex
  int? get _parsedCmd {
    final raw = _cmdCtrl.text.trim();
    if (raw.isEmpty) return null;
    try {
      if (raw.startsWith('0x') || raw.startsWith('0X')) {
        return int.parse(raw.substring(2), radix: 16);
      }
      return int.parse(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    _searchCtrl.dispose();
    _cmdCtrl.dispose();
    _payloadCtrl.dispose();
    super.dispose();
  }

  void _maybeAutoScroll() {
    final dp = context.read<DebugProvider>();
    if (dp.autoScroll && _scroll.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: RadioKitAppBar(
        title: 'DEBUG_MONITOR',
        actions: [
          _buildDebugModeToggle(context),
          const SizedBox(width: 8),
          _buildTransportChip(),
          const SizedBox(width: 16),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(icon: Icon(Icons.list_alt_rounded), text: 'Packet Log'),
            Tab(icon: Icon(Icons.send_rounded), text: 'Send'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _buildLogTab(),
          _buildSendTab(),
        ],
      ),
    );
  }

  /// Small chip showing which transport is active.
  Widget _buildTransportChip() {
    return Consumer<DebugProvider>(
      builder: (context, dp, _) {
        final t = dp.transport;
        final label = t == null
            ? 'No transport'
            : t.isConnected
                ? 'Connected'
                : 'Disconnected';
        final color = (t?.isConnected ?? false)
            ? AppColors.connected
            : Theme.of(context).disabledColor;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 7, height: 7,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDebugModeToggle(BuildContext context) {
    return Consumer<DebugProvider>(
      builder: (context, dp, _) {
        return TextButton.icon(
          onPressed: dp.toggleDebugMode,
          icon: Icon(
            dp.debugMode ? Icons.bug_report_rounded : Icons.bug_report_outlined,
            size: 18,
            color: dp.debugMode ? AppColors.brandOrange : Theme.of(context).disabledColor,
          ),
          label: Text(
            dp.debugMode ? 'DISABLE DEBUG MODE' : 'ENABLE DEBUG MODE',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: dp.debugMode ? AppColors.brandOrange : Theme.of(context).disabledColor,
            ),
          ),
        );
      },
    );
  }

  // ===========================================================================
  // LOG TAB
  // ===========================================================================

  Widget _buildLogTab() {
    return Consumer<DebugProvider>(
      builder: (context, dp, _) {
        _maybeAutoScroll();
        final entries = dp.entries;

        return Column(
          children: [
            _buildLogToolbar(dp),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? _buildEmptyLog(dp)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.only(bottom: 8),
                      itemCount: entries.length,
                      itemBuilder: (ctx, i) =>
                          _LogRow(entry: entries[i]),
                    ),
            ),
            _buildLogFooter(dp),
          ],
        );
      },
    );
  }

  Widget _buildLogToolbar(DebugProvider dp) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
      child: Row(
        children: [
          // Search
          Expanded(
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Filter (cmd / hex…)',
                  hintStyle: const TextStyle(fontSize: 12),
                  prefixIcon: const Icon(Icons.search_rounded, size: 16),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 14),
                          onPressed: () {
                            _searchCtrl.clear();
                            dp.setSearchTerm('');
                          },
                        )
                      : null,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: dp.setSearchTerm,
              ),
            ),
          ),
          const SizedBox(width: 6),
          // Direction filter
          _DirFilterButton(dp: dp),
          const SizedBox(width: 4),
          // Pause
          _ToolbarIconButton(
            icon: dp.paused
                ? Icons.play_arrow_rounded
                : Icons.pause_rounded,
            tooltip: dp.paused ? 'Resume' : 'Pause',
            onTap: dp.togglePause,
            active: dp.paused,
          ),
          // Auto-scroll
          _ToolbarIconButton(
            icon: Icons.vertical_align_bottom_rounded,
            tooltip: 'Auto-scroll',
            onTap: dp.toggleAutoScroll,
            active: dp.autoScroll,
          ),
          // Clear
          _ToolbarIconButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Clear',
            onTap: dp.clearLog,
          ),
          // Copy CSV
          _ToolbarIconButton(
            icon: Icons.copy_rounded,
            tooltip: 'Copy as CSV',
            onTap: () {
              Clipboard.setData(ClipboardData(text: dp.exportCsv()));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied CSV to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogFooter(DebugProvider dp) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          Text(
            'Showing ${dp.entries.length} / Buffer: ${dp.totalCount} / Total: ${dp.totalTransferred}'
            '${dp.paused ? '  ⏸ PAUSED' : ''}',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyLog(DebugProvider dp) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_rounded, size: 56,
                color: Theme.of(context).disabledColor),
            const SizedBox(height: 16),
            Text(
              dp.paused ? 'Log paused' : 'Waiting for packets…',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // SEND TAB
  // ===========================================================================

  Widget _buildSendTab() {
    return Consumer<DebugProvider>(
      builder: (context, dp, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quick-send buttons
              Text('Quick Send',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickSendChip(label: 'PING',     dp: dp),
                  _QuickSendChip(label: 'GET_CONF', dp: dp),
                  _QuickSendChip(label: 'GET_VARS', dp: dp),
                  _QuickSendChip(label: 'GET_META', dp: dp),
                  _QuickSendChip(label: 'GET_TELE', dp: dp),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Manual packet builder
              Text('Manual Packet',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(
                'Header (START + LENGTH) and CRC are added automatically.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),

              // CMD byte
              TextField(
                controller: _cmdCtrl,
                decoration: InputDecoration(
                  labelText: 'CMD byte (dec or 0x hex)',
                  hintText: 'e.g. 0x01 or 1',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                keyboardType: TextInputType.text,
                style: const TextStyle(fontFamily: 'monospace'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),

              // Payload hex
              TextField(
                controller: _payloadCtrl,
                decoration: InputDecoration(
                  labelText: 'Payload (hex, space-separated, optional)',
                  hintText: 'e.g. 01 FF A3',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
                keyboardType: TextInputType.text,
                style: const TextStyle(fontFamily: 'monospace'),
                maxLines: 3,
              ),
              const SizedBox(height: 8),

              // Error display
              if (_sendError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _sendError!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 12),
                  ),
                ),

              // Send button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_rounded),
                  label: const Text('Send Packet'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _parsedCmd == null
                      ? null
                      : () async {
                          setState(() => _sendError = null);
                          final err = await dp.sendManual(
                            _parsedCmd!,
                            _payloadCtrl.text,
                          );
                          setState(() => _sendError = err);
                          if (err == null) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Packet sent'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ===========================================================================
// Sub-widgets
// ===========================================================================

class _LogRow extends StatelessWidget {
  final DebugLogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isMcu = entry.direction == PacketDirection.mcu;
    final dirColor = isMcu ? AppColors.brandBlue : AppColors.brandOrange;
    final crcColor = entry.crcOk == false
        ? Theme.of(context).colorScheme.error
        : AppColors.connected;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: dirColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: dirColor.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: ExpansionTile(
          dense: true,
          tilePadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
          leading: Container(
            width: 36,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: dirColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              entry.dirLabel,
              textAlign: TextAlign.center,
              softWrap: false,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: dirColor,
                  fontFamily: 'monospace'),
            ),
          ),
          title: Row(
            children: [
              Text(
                entry.cmdName,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  entry.hexDump,
                  style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      fontFamily: 'monospace'),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Row(
            children: [
              Text(
                entry.timeLabel,
                style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).disabledColor,
                    fontFamily: 'monospace'),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.bytes.length} B',
                style: TextStyle(
                    fontSize: 9,
                    color: Theme.of(context).disabledColor),
              ),
              if (entry.crcOk != null) ...[
                const SizedBox(width: 8),
                Text(
                  entry.crcOk! ? 'CRC ✓' : 'CRC ✗',
                  style: TextStyle(
                      fontSize: 9,
                      color: crcColor,
                      fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailRow(label: 'HEX', value: entry.hexDump),
                  _DetailRow(label: 'ASCII', value: entry.asciiDump),
                  if (entry.payloadHex.isNotEmpty)
                    _DetailRow(label: 'PAYLOAD', value: entry.payloadHex),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 14),
                      label:
                          const Text('Copy', style: TextStyle(fontSize: 11)),
                      onPressed: () {
                        final summary = [
                          'Time: ${entry.timeLabel}',
                          'Dir:  ${entry.dirLabel}',
                          'Cmd:  ${entry.cmdName}',
                          'Size: ${entry.bytes.length} B',
                          if (entry.crcOk != null) 'CRC:  ${entry.crcOk! ? 'OK' : 'INVALID'}',
                          'Hex:  ${entry.hexDump}',
                          if (entry.payloadHex.isNotEmpty) 'Data: ${entry.payloadHex}',
                          'Text: ${entry.asciiDump}',
                        ].join('\n');
                        
                        Clipboard.setData(ClipboardData(text: summary));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Packet details copied'),
                            duration: Duration(seconds: 1),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 56,
            child: Text(
              label,
              style: TextStyle(
                  fontSize: 9,
                  color: Theme.of(context).disabledColor,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirFilterButton extends StatelessWidget {
  final DebugProvider dp;
  const _DirFilterButton({required this.dp});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Filter direction',
      icon: Icon(
        Icons.filter_list_rounded,
        size: 20,
        color: dp.dirFilter != null
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      onSelected: (value) {
        switch (value) {
          case 'mcu':  dp.setDirFilter(PacketDirection.mcu); break;
          case 'app':  dp.setDirFilter(PacketDirection.app); break;
          default:    dp.setDirFilter(null);               break;
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'all', child: Text('All')),
        const PopupMenuItem(value: 'mcu', child: Text('MCU only')),
        const PopupMenuItem(value: 'app', child: Text('APP only')),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool active;

  const _ToolbarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.active = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).iconTheme.color;
    return IconButton(
      icon: Icon(icon, size: 18, color: color),
      tooltip: tooltip,
      onPressed: onTap,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      padding: EdgeInsets.zero,
    );
  }
}

class _QuickSendChip extends StatefulWidget {
  final String label;
  final DebugProvider dp;
  const _QuickSendChip({required this.label, required this.dp});

  @override
  State<_QuickSendChip> createState() => _QuickSendChipState();
}

class _QuickSendChipState extends State<_QuickSendChip> {
  String? _err;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionChip(
          label: Text(widget.label,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          avatar: const Icon(Icons.send_rounded, size: 14),
          onPressed: () async {
            final err = await widget.dp.sendQuick(widget.label);
            setState(() => _err = err);
          },
        ),
        if (_err != null)
          Text(_err!,
              style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.error)),
      ],
    );
  }
}
