import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_theme.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../providers/flasher_provider.dart';

class FlasherTab extends StatelessWidget {
  const FlasherTab({super.key});

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildContent(context);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: 1,
        accentColor: context.tokens.primary,
      ),
      body: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Column(
      children: [
        // Scrollable content area
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PortSelector(),
                const SizedBox(height: 16),
                _ChipInfoPanel(),
                const SizedBox(height: 16),
                _FirmwareSection(),
                const SizedBox(height: 16),
                _MarketplacePlaceholder(),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        // Collapsible console log
        _ConsoleLogPanel(),
      ],
    );
  }
}

// ── Console Log Panel ──────────────────────────────────────────────────────

class _ConsoleLogPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FlasherProvider>(
      builder: (context, flasher, _) {
        final logExpanded = flasher.isLogExpanded;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          height: logExpanded
              ? MediaQuery.of(context).size.height / 3
              : 40,
          child: Column(
            children: [
              // Log header bar — single InkWell handles the toggle
              Material(
                color: context.tokens.base200,
                child: InkWell(
                  onTap: () => flasher.toggleLog(),
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: context.tokens.onSurface.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.terminal_rounded,
                          size: 14,
                          color: context.tokens.primary.withValues(alpha: 0.7),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'CONSOLE LOG',
                          style: GoogleFonts.changa(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                            color: context.tokens.primary.withValues(alpha: 0.7),
                          ),
                        ),
                        if (flasher.isOperationActive) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: context.tokens.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'ACTIVE',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                              color: context.tokens.success,
                            ),
                          ),
                        ],
                        const Spacer(),
                        // Copy and clear buttons — stop propagation so they
                        // don't also trigger the InkWell's onTap
                        GestureDetector(
                          onTap: () {
                            // copy to clipboard
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.copy_all_rounded,
                              size: 16,
                              color: context.tokens.onSurface.withValues(alpha: 0.24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => flasher.clearLog(),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              Icons.delete_sweep_rounded,
                              size: 16,
                              color: context.tokens.onSurface.withValues(alpha: 0.24),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          logExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          size: 18,
                          color: context.tokens.onSurface.withValues(alpha: 0.54),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              // Log content (only visible when expanded)
              if (logExpanded)
                Expanded(
                  child: Container(
                    color: context.tokens.base200,
                    child: _FlasherLogView(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ── Port Selector ───────────────────────────────────────────────────────────

class _PortSelector extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FlasherProvider>(
      builder: (context, flasher, _) {
        if (flasher.isConnected) {
          return _ConnectedPortBar(flasher: flasher);
        }
        return _DisconnectedState(flasher: flasher);
      },
    );
  }
}

class _DisconnectedState extends StatelessWidget {
  final FlasherProvider flasher;

  const _DisconnectedState({required this.flasher});

  @override
  Widget build(BuildContext context) {
    final isScanning = flasher.isScanning;
    final ports = flasher.availablePorts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.usb_rounded, size: 16, color: context.tokens.primary),
          const SizedBox(width: 8),
          Text('SERIAL PORT',
              style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.54),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1)),
        ]),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: context.tokens.primary,
                foregroundColor: context.tokens.onPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6)),
              ),
              onPressed: isScanning
                  ? null
                  : () => flasher.scanPorts(),
              icon: isScanning
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.tokens.onPrimary))
                  : const Icon(Icons.search_rounded, size: 20),
              label: Text(
                  isScanning ? 'SCANNING...' : 'SCAN PORTS',
                  style: GoogleFonts.changa(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      fontSize: 12)),
            ),
          ),
          if (ports.isNotEmpty) ...[const SizedBox(width: 8)],
          if (ports.isNotEmpty)
            IconButton(
              tooltip: 'View all ports',
              icon: Icon(Icons.visibility_outlined,
                  size: 22, color: context.tokens.onSurface.withValues(alpha: 0.54)),
              onPressed: () => _showAllPortsDialog(context, flasher),
            ),
        ]),
        // Show only preferred ports in the main list; fall back to all
        // if none match (e.g. no port descriptions available).
        if (ports.isNotEmpty) ...[if (ports.any((p) => p.isPreferred)) ...[
          const SizedBox(height: 8),
          _PortList(ports: ports.where((p) => p.isPreferred).toList(), flasher: flasher),
        ] else ...[
          const SizedBox(height: 8),
          _PortList(ports: ports, flasher: flasher),
        ]],
        // Manual boot mode fallback (shown when sync fails)
        if (flasher.errorMessage != null &&
            flasher.errorMessage!.contains('Sync')) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.warning.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: context.tokens.warning.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.warning_rounded,
                      size: 16, color: context.tokens.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(flasher.errorMessage!,
                        style: TextStyle(
                            color: context.tokens.warning, fontSize: 11)),
                  ),
                ]),
                const SizedBox(height: 8),
                Text('Manual boot mode:',
                    style: TextStyle(
                        color: context.tokens.warning,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('1. Hold BOOT button on the ESP32 board',
                    style: TextStyle(
                        color: context.tokens.warning.withValues(alpha: 0.7),
                        fontSize: 10)),
                Text('2. Tap RESET button (while holding BOOT)',
                    style: TextStyle(
                        color: context.tokens.warning.withValues(alpha: 0.7),
                        fontSize: 10)),
                Text('3. Release BOOT button',
                    style: TextStyle(
                        color: context.tokens.warning.withValues(alpha: 0.7),
                        fontSize: 10)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    minimumSize: Size.zero,
                    backgroundColor: context.tokens.primary.withValues(alpha: 0.15),
                  ),
                  onPressed: () => flasher.scanPorts(),
                  child: Text('RETRY',
                      style: GoogleFonts.changa(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                          fontSize: 10)),
                ),
              ],
            ),
          ),
        ],
        // General error message
        if (flasher.errorMessage != null &&
            !flasher.errorMessage!.contains('Sync')) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.tokens.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: context.tokens.error.withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.error_outline_rounded,
                  size: 16, color: context.tokens.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(flasher.errorMessage!,
                    style: TextStyle(
                        color: context.tokens.error, fontSize: 11)),
              ),
            ]),
          ),
        ],
      ],
    );
  }
}

// ── Port list widget (shared between main and fallback) ───────

class _PortList extends StatelessWidget {
  final List<PortInfo> ports;
  final FlasherProvider flasher;

  const _PortList({required this.ports, required this.flasher});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
            color: context.tokens.onSurface.withValues(alpha: 0.12)),
      ),
      child: Column(
        children: ports.map((port) => _PortTile(flasher: flasher, port: port)).toList(),
      ),
    );
  }
}

// ── Port tile widget (shared between main list and dialog) ────

class _PortTile extends StatelessWidget {
  final FlasherProvider flasher;
  final PortInfo port;

  const _PortTile({required this.flasher, required this.port});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(Icons.usb_rounded,
          size: 18, color: context.tokens.primary),
      title: Text(port.name,
          style: GoogleFonts.martianMono(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: context.tokens.onSurface)),
      subtitle: port.description != null
          ? Text(port.description!,
              style: TextStyle(
                  fontSize: 10,
                  color: context.tokens.onSurface
                      .withValues(alpha: 0.54),
                  overflow: TextOverflow.ellipsis))
          : Text(port.id,
              style: TextStyle(
                  fontSize: 10,
                  color: context.tokens.onSurface
                      .withValues(alpha: 0.54))),
      trailing: FilledButton(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          backgroundColor: context.tokens.primary,
        ),
        onPressed: () => flasher.connect(port.id),
        child: Text('CONNECT',
            style: GoogleFonts.changa(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                fontSize: 10)),
      ),
      onTap: () => flasher.connect(port.id),
    );
  }
}

// ── All-ports dialog ─────────────────────────────────────────────

void _showAllPortsDialog(BuildContext context, FlasherProvider flasher) {
  final ports = flasher.availablePorts;
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: context.tokens.base200,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 12, 0),
      title: Row(children: [
        Expanded(
          child: Text('ALL PORTS (${ports.length})',
              style: GoogleFonts.changa(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: context.tokens.onSurface)),
        ),
        IconButton(
          icon: Icon(Icons.close_rounded, size: 18,
              color: context.tokens.onSurface.withValues(alpha: 0.54)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ]),
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: ListView(
          shrinkWrap: true,
          children: ports.map((port) => _PortTile(flasher: flasher, port: port)).toList(),
        ),
      ),
      actionsPadding: EdgeInsets.zero,
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('CLOSE',
              style: GoogleFonts.changa(
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                  letterSpacing: 0.5)),
        ),
      ],
    ),
  );
}

class _ConnectedPortBar extends StatelessWidget {
  final FlasherProvider flasher;

  const _ConnectedPortBar({required this.flasher});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.tokens.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: context.tokens.success.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: context.tokens.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(flasher.portName ?? 'Connected',
                  style: GoogleFonts.martianMono(
                      color: context.tokens.onSurface,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Text('SYNCED @ ${flasher.baudRate} BAUD',
                  style: TextStyle(
                      color: context.tokens.success.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ],
          ),
        ),
        FilledButton.tonal(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: Size.zero,
            backgroundColor: context.tokens.error.withValues(alpha: 0.15),
            foregroundColor: context.tokens.error,
          ),
          onPressed: () => flasher.disconnect(),
          child: Text('DISCONNECT',
              style: GoogleFonts.changa(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  fontSize: 10)),
        ),
      ]),
    );
  }
}

// ── Chip Info Panel ─────────────────────────────────────────────────────────

class _ChipInfoPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FlasherProvider>(
      builder: (context, flasher, _) {
        if (!flasher.isConnected) return const SizedBox.shrink();

        if (flasher.isLoadingChipInfo) {
          return Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.tokens.onSurface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(children: [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: context.tokens.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Synchronizing with ESP32 bootloader...',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: context.tokens.onSurface.withValues(alpha: 0.7),
                      fontSize: 12),
                ),
              ),
            ]),
          );
        }

        final info = flasher.chipInfo;
        if (info == null) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.tokens.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: context.tokens.onSurface.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.memory_rounded,
                    size: 16, color: context.tokens.primary),
                const SizedBox(width: 8),
                Text('CHIP INFO',
                    style: TextStyle(
                        color: context.tokens.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1)),
              ]),
              const SizedBox(height: 12),
              _infoRow(context, 'Model', info.model),
              _infoRow(context, 'Revision', info.revision),
              _infoRow(context, 'MAC', info.mac),
              _infoRow(context, 'Flash', info.flashSize),
              _infoRow(context, 'PSRAM', info.psramSize),
              _infoRow(context, 'Cores', info.cores),
            ],
          ),
        );
      },
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.54),
                  fontSize: 11)),
          Text(value,
              style: GoogleFonts.martianMono(
                  color: context.tokens.onSurface,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Firmware Section ────────────────────────────────────────────────────────

class _FirmwareSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<FlasherProvider>(
      builder: (context, flasher, _) {
        if (!flasher.isConnected) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.file_open_rounded,
                  size: 16, color: context.tokens.primary),
              const SizedBox(width: 8),
              Text('FIRMWARE',
                  style: TextStyle(
                      color: context.tokens.primary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ]),
            const SizedBox(height: 12),
            // Select file button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.tokens.onSurface,
                  side: BorderSide(
                      color: context.tokens.onSurface.withValues(alpha: 0.24)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: flasher.isFlashing
                    ? null
                    : () => flasher.selectFirmwareFile(),
                icon: Icon(Icons.file_open_rounded,
                    size: 18,
                    color: context.tokens.onSurface.withValues(alpha: 0.54)),
                label: Text('SELECT FIRMWARE FILE',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 12)),
              ),
            ),
            // Selected file info
            if (flasher.selectedFirmware != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.tokens.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                      color: context.tokens.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Icon(Icons.insert_drive_file_rounded,
                          size: 16, color: context.tokens.onSurface),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(flasher.selectedFirmware!.name,
                            style: GoogleFonts.martianMono(
                                color: context.tokens.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ),
                      GestureDetector(
                        onTap: flasher.isFlashing
                            ? null
                            : () => flasher.clearFirmwareSelection(),
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Icon(Icons.close_rounded,
                              size: 16,
                              color: context.tokens.onSurface
                                  .withValues(alpha: 0.38)),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 4),
                    Text(flasher.selectedFirmware!.size,
                        style: TextStyle(
                            color: context.tokens.onSurface
                                .withValues(alpha: 0.54),
                            fontSize: 10)),
                    // Erase all toggle
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.delete_sweep_rounded,
                          size: 16,
                          color: flasher.eraseAll
                              ? context.tokens.error
                              : context.tokens.onSurface
                                  .withValues(alpha: 0.38)),
                      const SizedBox(width: 8),
                      Text('ERASE ALL',
                          style: TextStyle(
                              color: context.tokens.onSurface,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Switch(
                        value: flasher.eraseAll,
                        onChanged: flasher.isFlashing
                            ? null
                            : (v) => flasher.setEraseAll(v),
                        activeThumbColor: context.tokens.error,
                      ),
                    ]),
                    // Flash button
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: context.tokens.primary,
                          foregroundColor: context.tokens.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6)),
                        ),
                        onPressed: flasher.isFlashing
                            ? null
                            : () => flasher.startFlashing(),
                        icon: flasher.isFlashing
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: context.tokens.onPrimary))
                            : const Icon(Icons.cloud_upload_rounded, size: 20),
                        label: Text(
                            flasher.isFlashing
                                ? 'FLASHING...'
                                : 'FLASH FIRMWARE',
                            style: GoogleFonts.changa(
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1,
                                fontSize: 12)),
                      ),
                    ),
                    // Progress bar during flashing
                    if (flasher.isFlashing) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: flasher.flashProgress,
                          minHeight: 6,
                          backgroundColor: context.tokens.onSurface
                              .withValues(alpha: 0.12),
                          valueColor: AlwaysStoppedAnimation(
                              context.tokens.primary),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(flasher.flashStatus,
                              style: TextStyle(
                                  color: context.tokens.onSurface
                                      .withValues(alpha: 0.7),
                                  fontSize: 10)),
                          Text(
                              '${(flasher.flashProgress * 100).toInt()}%',
                              style: GoogleFonts.martianMono(
                                  color: context.tokens.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Marketplace Placeholder ─────────────────────────────────────────────────

class _MarketplacePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: context.tokens.onSurface.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Icon(Icons.store_outlined,
              size: 32,
              color: context.tokens.onSurface.withValues(alpha: 0.24)),
          const SizedBox(height: 12),
          Text('FIRMWARE MARKETPLACE',
              style: GoogleFonts.changa(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                  fontSize: 11,
                  color: context.tokens.onSurface.withValues(alpha: 0.38))),
          const SizedBox(height: 6),
          Text('Coming soon — browse and download curated firmwares.',
              style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.3),
                  fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Flasher Log View ────────────────────────────────────────────────────────

class _FlasherLogView extends StatefulWidget {
  @override
  State<_FlasherLogView> createState() => _FlasherLogViewState();
}

class _FlasherLogViewState extends State<_FlasherLogView> {
  final ScrollController _scrollController = ScrollController();
  int _prevEntryCount = 0;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _autoScroll(int entryCount) {
    if (entryCount > _prevEntryCount && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOut,
          );
        }
      });
    }
    _prevEntryCount = entryCount;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<FlasherProvider>(
      builder: (context, flasher, _) {
        final entries = flasher.logEntries;
        _autoScroll(entries.length);

        if (entries.isEmpty) {
          return Center(
            child: Text('No log entries yet.',
                style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.24),
                    fontSize: 11)),
          );
        }
        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(12),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            final isError = entry.contains('[ERROR]');
            final isOk = entry.contains('[OK]');
            final isWarn = entry.contains('[WARN]');
            Color textColor = context.tokens.onSurface.withValues(alpha: 0.7);
            if (isError) textColor = context.tokens.error;
            if (isOk) textColor = context.tokens.success;
            if (isWarn) textColor = context.tokens.warning;

            return Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                entry,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11,
                  height: 1.4,
                  color: textColor,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
