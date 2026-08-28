import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:intl/intl.dart';

import '../../theme/app_theme.dart';
import '../../models/tab_index.dart';
import '../../widgets/radiokit_app_bar.dart';
import '../../providers/flasher_provider.dart';
import '../../services/firmware_marketplace_service.dart';
import '../../services/firmware_release_service.dart';
import 'qr_repo_scanner_modal.dart';

class FlasherTab extends StatefulWidget {
  const FlasherTab({super.key});

  @override
  State<FlasherTab> createState() => _FlasherTabState();
}

class _FlasherTabState extends State<FlasherTab> {
  FlasherProvider? _flasher;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _flasher = context.read<FlasherProvider>();
      _flasher!.startAutoScan();
    });
  }

  @override
  void dispose() {
    _flasher?.stopAutoScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final orientation = MediaQuery.of(context).orientation;
    final isLandscape = orientation == Orientation.landscape;

    if (isLandscape) {
      return _buildContent(context);
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        tabIndex: TabIndex.flasher,
        accentColor: context.tokens.primary,
        onScan: () => context.read<FlasherProvider>().scanPorts(),
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
                _MarketplaceSection(),
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
          const Spacer(),
          if (isScanning) ...[
            SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: context.tokens.primary.withValues(alpha: 0.7))),
            const SizedBox(width: 6),
            Text('SCANNING',
                style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.38),
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1)),
          ],
          if (!isScanning && ports.isNotEmpty)
            IconButton(
              tooltip: 'View all ports',
              icon: Icon(Icons.visibility_outlined,
                  size: 22, color: context.tokens.onSurface.withValues(alpha: 0.54)),
              onPressed: () => _showAllPortsDialog(context, flasher),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
        ]),
        if (ports.isEmpty && !isScanning) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.tokens.onSurface.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: context.tokens.onSurface.withValues(alpha: 0.08)),
            ),
            child: Text('No ports detected. Plug in a device.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.38),
                    fontSize: 11)),
          ),
        ],
        // Show only preferred ports in the main list; fall back to all
        // if none match (e.g. no port descriptions available).
        if (ports.isNotEmpty) ...[const SizedBox(height: 8),
          if (ports.any((p) => p.isPreferred))
            _PortList(ports: ports.where((p) => p.isPreferred).toList(), flasher: flasher)
          else
            _PortList(ports: ports, flasher: flasher),
        ],
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
      title: Text(port.description ?? port.name,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: context.tokens.onSurface)),
      subtitle: Text(port.id,
          style: TextStyle(
              fontSize: 10,
              color: context.tokens.onSurface
                  .withValues(alpha: 0.54),
              overflow: TextOverflow.ellipsis)),
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

// ── Firmware Marketplace Section ───────────────────────────────────────────

class _MarketplaceSection extends StatefulWidget {
  @override
  State<_MarketplaceSection> createState() => _MarketplaceSectionState();
}

class _MarketplaceSectionState extends State<_MarketplaceSection> {
  final FirmwareMarketplaceService _marketplaceService = FirmwareMarketplaceService();
  List<String> _repos = [];
  final Map<String, MarketplaceRelease?> _releases = {};
  final Map<String, bool> _loading = {};
  final Map<String, MarketplaceBinaryInfo?> _selectedBinaries = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _isDownloading = {};
  final Set<String> _expandedChangelogs = {};
  final Set<String> _expandedCards = {};

  @override
  void initState() {
    super.initState();
    _loadRepos();
  }

  Future<void> _loadRepos() async {
    final repos = await _marketplaceService.getSavedRepos();
    if (!mounted) return;
    setState(() {
      _repos = repos;
    });

    for (final repo in repos) {
      _fetchRelease(repo);
    }
  }

  Future<void> _fetchRelease(String repoUrl, {bool force = false}) async {
    setState(() => _loading[repoUrl] = true);
    final release = await _marketplaceService.fetchRelease(repoUrl, forceRefresh: force);
    if (!mounted) return;
    setState(() {
      _loading[repoUrl] = false;
      _releases[repoUrl] = release;

      // Auto-select best binary if available
      if (release != null && release.binaries.isNotEmpty) {
        final flasher = context.read<FlasherProvider>();
        final connectedChip = flasher.chipInfo?.model;
        final best = release.findBestBinary(
          connectedChip: connectedChip,
          preferFactory: true,
        );
        final nonOtaBinaries = release.binaries.where((b) => !b.isOta).toList();
        _selectedBinaries[repoUrl] = best ?? (nonOtaBinaries.isNotEmpty ? nonOtaBinaries.first : release.binaries.first);
      }
    });
  }

  Future<void> _onAddOrScanRepo() async {
    final result = await QrRepoScannerModal.show(context);
    if (result == null || !mounted) return;

    final added = await _marketplaceService.addRepo(result.repoUrl);
    if (added) {
      await _loadRepos();
      if (result.preselectedAsset != null) {
        final release = _releases[result.repoUrl];
        if (release != null) {
          for (final b in release.binaries) {
            if (b.assetName == result.preselectedAsset) {
              setState(() => _selectedBinaries[result.repoUrl] = b);
              break;
            }
          }
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Repository added: ${result.repoUrl}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _onRemoveRepo(String repoUrl) async {
    await _marketplaceService.removeRepo(repoUrl);
    await _loadRepos();
  }

  Future<void> _selectFirmware(String repoUrl, MarketplaceBinaryInfo binary) async {
    setState(() {
      _isDownloading[repoUrl] = true;
      _downloadProgress[repoUrl] = 0.0;
    });

    try {
      final releaseService = FirmwareReleaseService();
      final bytes = await releaseService.downloadAsset(
        binary.downloadUrl,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() {
              _downloadProgress[repoUrl] = received / total;
            });
          }
        },
      );

      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/${binary.assetName}');
      await tempFile.writeAsBytes(bytes);

      if (!mounted) return;
      final flasher = context.read<FlasherProvider>();
      flasher.setSelectedFirmwareDirect(
        name: binary.assetName,
        path: tempFile.path,
        bytes: bytes.length,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selected ${binary.displayName} (${binary.assetName}). Ready to flash in the FIRMWARE section above.'),
          backgroundColor: context.tokens.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: context.tokens.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading[repoUrl] = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final flasher = context.watch<FlasherProvider>();
    final connectedChip = flasher.chipInfo?.model;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(PhosphorIcons.storefront,
                    size: 18, color: tokens.primary),
                const SizedBox(width: 8),
                Text(
                  'FIRMWARE MARKETPLACE',
                  style: GoogleFonts.changa(
                    color: tokens.primary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: Icon(PhosphorIcons.arrowsClockwise,
                      size: 16, color: tokens.onSurface.withValues(alpha: 0.7)),
                  tooltip: 'Refresh releases',
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    for (final r in _repos) {
                      _fetchRelease(r, force: true);
                    }
                  },
                ),
                const SizedBox(width: 4),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    backgroundColor: tokens.primary.withValues(alpha: 0.15),
                    foregroundColor: tokens.primary,
                  ),
                  onPressed: _onAddOrScanRepo,
                  icon: const Icon(PhosphorIcons.plus, size: 14),
                  label: Text('ADD / SCAN',
                      style: GoogleFonts.changa(
                          fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 0.5)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Repositories list
        if (_repos.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: tokens.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tokens.onSurface.withValues(alpha: 0.08)),
            ),
            child: Center(
              child: Text(
                'No firmware repositories added.',
                style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.4), fontSize: 11),
              ),
            ),
          )
        else
          ..._repos.map((repoUrl) {
            final isLoading = _loading[repoUrl] ?? false;
            final release = _releases[repoUrl];
            final selectedBinary = _selectedBinaries[repoUrl];
            final isDownloading = _isDownloading[repoUrl] ?? false;
            final progress = _downloadProgress[repoUrl] ?? 0.0;
            final isDefault = FirmwareMarketplaceService.defaultRepos.contains(repoUrl);
            final isExpanded = _expandedCards.contains(repoUrl);

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: tokens.onSurface.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Repository card header
                  InkWell(
                    borderRadius: BorderRadius.vertical(
                      top: const Radius.circular(10),
                      bottom: isExpanded ? Radius.zero : const Radius.circular(10),
                    ),
                    onTap: () {
                      setState(() {
                        if (isExpanded) {
                          _expandedCards.remove(repoUrl);
                        } else {
                          _expandedCards.add(repoUrl);
                        }
                      });
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Icon(PhosphorIcons.githubLogo,
                              size: 20, color: tokens.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  repoUrl.replaceAll('https://github.com/', ''),
                                  style: GoogleFonts.martianMono(
                                    color: tokens.onSurface,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (release != null) ...[
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: tokens.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          release.tagName,
                                          style: GoogleFonts.martianMono(
                                            color: tokens.primary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                      if (release.publishedAt != null) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat.yMMMd().format(release.publishedAt!),
                                          style: TextStyle(
                                            color: tokens.onSurface.withValues(alpha: 0.4),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (isLoading)
                            SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.5,
                                color: tokens.primary,
                              ),
                            )
                          else if (!isDefault)
                            IconButton(
                              icon: Icon(PhosphorIcons.trash,
                                  size: 16, color: tokens.error.withValues(alpha: 0.7)),
                              tooltip: 'Remove repository',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _onRemoveRepo(repoUrl),
                            ),
                          Icon(
                            isExpanded
                                ? PhosphorIcons.caretUp
                                : PhosphorIcons.caretDown,
                            size: 16,
                            color: tokens.onSurface.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Expanded contents
                  if (isExpanded && release != null) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Changelog expandable viewer
                          if (release.changelog.trim().isNotEmpty) ...[
                            InkWell(
                              onTap: () {
                                setState(() {
                                  if (_expandedChangelogs.contains(repoUrl)) {
                                    _expandedChangelogs.remove(repoUrl);
                                  } else {
                                    _expandedChangelogs.add(repoUrl);
                                  }
                                });
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    _expandedChangelogs.contains(repoUrl)
                                        ? Icons.expand_less_rounded
                                        : Icons.expand_more_rounded,
                                    size: 16,
                                    color: tokens.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _expandedChangelogs.contains(repoUrl)
                                        ? 'HIDE RELEASE NOTES'
                                        : 'VIEW RELEASE NOTES',
                                    style: GoogleFonts.changa(
                                      color: tokens.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (_expandedChangelogs.contains(repoUrl)) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: tokens.onSurface.withValues(alpha: 0.04),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  release.changelog,
                                  style: TextStyle(
                                    color: tokens.onSurface.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                          ],

                          // Binaries list
                          Text(
                            'AVAILABLE FIRMWARE',
                            style: TextStyle(
                              color: tokens.onSurface.withValues(alpha: 0.54),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 8),

                          Builder(
                            builder: (context) {
                              final flashableBinaries = release.binaries.where((b) => !b.isOta).toList();

                              if (flashableBinaries.isEmpty) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  child: Text(
                                    'No flashable .bin assets found in this release.',
                                    style: TextStyle(
                                      color: tokens.onSurface.withValues(alpha: 0.4),
                                      fontSize: 11,
                                    ),
                                  ),
                                );
                              }

                              return Column(
                                children: flashableBinaries.map((binary) {
                                  final isSelected = selectedBinary?.assetName == binary.assetName;
                                  final matchesConnectedChip = binary.matchesChip(connectedChip);

                                  return InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () {
                                      setState(() => _selectedBinaries[repoUrl] = binary);
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 8),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? tokens.primary.withValues(alpha: 0.08)
                                            : tokens.onSurface.withValues(alpha: 0.03),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? tokens.primary
                                              : tokens.onSurface.withValues(alpha: 0.08),
                                          width: isSelected ? 1.5 : 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(top: 2),
                                            child: Icon(
                                              isSelected
                                                  ? Icons.radio_button_checked_rounded
                                                  : Icons.radio_button_off_rounded,
                                              size: 18,
                                              color: isSelected
                                                  ? tokens.primary
                                                  : tokens.onSurface.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                // Primary title: Board / Display Name
                                                Text(
                                                  binary.displayName,
                                                  style: GoogleFonts.martianMono(
                                                    color: tokens.onSurface,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // Metadata tags: Chip, Variant, Size, Compatibility
                                                Wrap(
                                                  spacing: 6,
                                                  runSpacing: 4,
                                                  crossAxisAlignment: WrapCrossAlignment.center,
                                                  children: [
                                                    if (binary.chip != null)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: tokens.primary.withValues(alpha: 0.12),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          'Chip: ${binary.chip!.toUpperCase()}',
                                                          style: TextStyle(
                                                            color: tokens.primary,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    if (binary.variant != null)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: Colors.purple.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          'Variant: ${binary.variant}',
                                                          style: const TextStyle(
                                                            color: Colors.purple,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    if (matchesConnectedChip)
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                        decoration: BoxDecoration(
                                                          color: tokens.success.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            Icon(Icons.check_rounded, size: 10, color: tokens.success),
                                                            const SizedBox(width: 3),
                                                            Text(
                                                              'MATCHES ${connectedChip?.toUpperCase()}',
                                                              style: TextStyle(
                                                                color: tokens.success,
                                                                fontSize: 9,
                                                                fontWeight: FontWeight.bold,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    Text(
                                                      binary.formattedSize,
                                                      style: TextStyle(
                                                        color: tokens.onSurface.withValues(alpha: 0.4),
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 4),
                                                // Subtle asset filename
                                                Text(
                                                  binary.assetName,
                                                  style: GoogleFonts.martianMono(
                                                    color: tokens.onSurface.withValues(alpha: 0.35),
                                                    fontSize: 9,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                          ),

                          const SizedBox(height: 12),

                          // Select firmware action button
                          if (selectedBinary != null) ...[
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: tokens.primary,
                                  foregroundColor: tokens.onPrimary,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                ),
                                onPressed: isDownloading
                                    ? null
                                    : () => _selectFirmware(repoUrl, selectedBinary),
                                icon: isDownloading
                                    ? SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: tokens.onPrimary,
                                        ),
                                      )
                                    : const Icon(Icons.download_done_rounded, size: 18),
                                label: Text(
                                  isDownloading
                                      ? 'DOWNLOADING ${(progress * 100).toInt()}%...'
                                      : 'SELECT FIRMWARE',
                                  style: GoogleFonts.changa(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            if (isDownloading) ...[
                              const SizedBox(height: 6),
                              LinearProgressIndicator(
                                value: progress > 0 ? progress : null,
                                backgroundColor: tokens.onSurface.withValues(alpha: 0.1),
                                valueColor: AlwaysStoppedAnimation(tokens.primary),
                                minHeight: 4,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
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
