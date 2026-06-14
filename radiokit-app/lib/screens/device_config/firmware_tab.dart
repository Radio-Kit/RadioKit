import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/device_provider.dart';
import '../../models/device_info.dart';
import '../../theme/app_theme.dart';

class FirmwareTabContent extends StatefulWidget {
  final DeviceInfo device;

  const FirmwareTabContent({required this.device});

  @override
  State<FirmwareTabContent> createState() => _FirmwareTabContentState();
}

class _FirmwareTabContentState extends State<FirmwareTabContent> {
  int _received = 0;
  int _total = 0;
  String _status = 'Ready';
  bool _uploading = false;
  bool _complete = false;
  bool _error = false;
  String? _errorMessage;
  DateTime? _started;
  bool _cancelled = false;

  // ── Confirm upload state ──────────────────────────────────────────
  String? _selectedFileName;
  Uint8List? _selectedFirmwareBytes;
  bool _eraseAll = false;

  Future<void> _selectFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access the selected file.')),
        );
      }
      return;
    }

    Uint8List firmware;
    try {
      firmware = await File(file.path!).readAsBytes();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = true;
          _status = 'Failed to read file';
          _errorMessage = '$e';
        });
      }
      return;
    }

    // Store file for confirm step instead of starting upload immediately
    setState(() {
      _selectedFileName = file.name;
      _selectedFirmwareBytes = firmware;
      _error = false;
      _errorMessage = null;
      _status = 'Ready';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedFileName = null;
      _selectedFirmwareBytes = null;
      _eraseAll = false;
    });
  }

  Future<void> _confirmAndUpload() async {
    final firmware = _selectedFirmwareBytes;
    if (firmware == null) return;
    _startUpload(firmware);
  }

  Future<void> _startUpload(Uint8List firmware) async {
    final dp = context.read<DeviceProvider>();
    final eraseAll = _eraseAll;
    setState(() {
      _uploading = true;
      _complete = false;
      _error = false;
      _status = 'Initializing...';
      _received = 0;
      _total = firmware.length;
      _started = DateTime.now();
      _cancelled = false;
      _errorMessage = null;
      _selectedFileName = null;
      _selectedFirmwareBytes = null;
    });

    try {
      await dp.uploadFirmware(firmware, eraseAll: eraseAll,
          onProgress: (received, total) {
        if (!mounted || _cancelled) return;
        setState(() {
          _received = received;
          _total = total;
          _status = _formatSpeed(received, total);
        });
      });
      if (!mounted) return;
      setState(() {
        _status = 'Verifying...';
      });
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      setState(() {
        _complete = true;
        _uploading = false;
        _status = 'Update complete — device rebooting...';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _uploading = false;
        _status = 'Update failed';
        _errorMessage = 'Error: $e';
      });
    }
  }

  String _formatSpeed(int received, int total) {
    final elapsed = DateTime.now().difference(_started ?? DateTime.now());
    final ms = elapsed.inMilliseconds;
    final speed =
        ms > 0 ? (received / ms * 1000 / 1024).toStringAsFixed(1) : '0';
    final pct = total > 0 ? (received * 100 / total).toStringAsFixed(0) : '0';
    return 'Uploading... $pct% ($speed KB/s)';
  }

  String _formatBytes(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '$bytes B';
  }

  Future<void> _cancel() async {
    _cancelled = true;
    try {
      await context.read<DeviceProvider>().abortOta();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _uploading = false;
        _status = 'Cancelled';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dp = context.watch<DeviceProvider>();
    final configName = dp.configName ?? 'Unknown';

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Device info header ───────────────────────────────
          Row(children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brandOrange.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.memory_rounded,
                  color: AppColors.brandOrange, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(configName.toUpperCase(),
                      style: GoogleFonts.exo2(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('FIRMWARE UPDATE',
                      style: TextStyle(
                          color: AppColors.brandOrange.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          const Divider(height: 1, color: Colors.white12),
          const SizedBox(height: 24),

          // ── Firmware info ────────────────────────────────────
          _infoRow('DEVICE', configName),
          _infoRow('VERSION', dp.connectedDevice?.id ?? '--'),
          const SizedBox(height: 24),

          if (!_uploading && !_complete && !_error) ...[
            // ── Confirm upload phase (file selected) ────────────
            if (_selectedFileName != null &&
                _selectedFirmwareBytes != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.brandOrange.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppColors.brandOrange.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECTED FILE',
                        style: TextStyle(
                            color: AppColors.brandOrange,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      const Icon(Icons.insert_drive_file_rounded,
                          size: 18, color: Colors.white),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedFileName!,
                                style: GoogleFonts.jetBrainsMono(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(_formatBytes(_selectedFirmwareBytes!.length),
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded,
                            size: 18, color: Colors.white38),
                        onPressed: _clearSelection,
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Erase all toggle ──────────────────────────────
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_rounded,
                        size: 18,
                        color: _eraseAll ? Colors.redAccent : Colors.white38),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ERASE ALL',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                          Text(
                              'Reset to factory defaults after reboot (NVS + filesystem)',
                              style: TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                    ),
                    Switch(
                      value: _eraseAll,
                      onChanged: (v) => setState(() => _eraseAll = v),
                      activeThumbColor: Colors.redAccent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Confirm upload button ─────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brandOrange,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6)),
                  ),
                  icon: const Icon(Icons.cloud_upload_rounded, size: 20),
                  label: Text('CONFIRM UPLOAD',
                      style: GoogleFonts.changa(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                          fontSize: 12)),
                  onPressed: _confirmAndUpload,
                ),
              ),
              const SizedBox(height: 12),
            ],
            // ── Select file button (always visible when idle) ───
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brandOrange,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                icon: const Icon(Icons.file_open_rounded, size: 20),
                label: Text('SELECT FIRMWARE FILE',
                    style: GoogleFonts.changa(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                        fontSize: 12)),
                onPressed: _selectFile,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select a compiled firmware (.bin) file to update the device.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],

          // ── Upload progress ──────────────────────────────────
          if (_uploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total > 0 ? _received / _total : null,
                minHeight: 6,
                backgroundColor: Colors.white12,
                valueColor: const AlwaysStoppedAnimation(AppColors.brandOrange),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_status,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
                Text('${(_received * 100 ~/ _total)}%',
                    style: GoogleFonts.jetBrainsMono(
                        color: AppColors.brandOrange,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _cancel,
                child: const Text('CANCEL'),
              ),
            ),
          ],

          // ── Error state ──────────────────────────────────────
          if (_error) ...[
            Row(children: [
              const Icon(Icons.error_rounded,
                  color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_errorMessage ?? 'Unknown error',
                    style:
                        const TextStyle(color: Colors.redAccent, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.brandOrange,
                  side: BorderSide(
                      color: AppColors.brandOrange.withValues(alpha: 0.6)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => setState(() {
                  _error = false;
                  _status = 'Ready';
                  _errorMessage = null;
                }),
                child: const Text('RETRY'),
              ),
            ),
          ],

          // ── Complete state ───────────────────────────────────
          if (_complete) ...[
            Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Colors.greenAccent, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Device is rebooting with new firmware.',
                    style: TextStyle(color: Colors.white70, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white54,
                  side: const BorderSide(color: Colors.white24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('CLOSE'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Text(value,
              style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Transport Badge Widget ──────────────────────────────────────────────────

/// Compact transport status pill shown in the Info tab.
/// Shows an icon, label, green dot if connected, gray if available, dimmed if not.
