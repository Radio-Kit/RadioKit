import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';

import '../../providers/device_provider.dart';
import '../../models/device_info.dart';
import '../../theme/app_theme.dart';
import '../../services/firmware_release_service.dart';

class FirmwareTabContent extends StatefulWidget {
  final DeviceInfo device;
  final DeviceProvider? deviceProvider;

  const FirmwareTabContent({super.key, required this.device, this.deviceProvider});

  @override
  State<FirmwareTabContent> createState() => _FirmwareTabContentState();
}

class _FirmwareTabContentState extends State<FirmwareTabContent> {
  final _releaseService = FirmwareReleaseService();

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

  // ── Remote Release / Update check state ───────────────────────────
  bool _checkingUpdate = false;
  FirmwareRelease? _latestRelease;
  String? _checkError;
  ReleaseAsset? _selectedReleaseAsset;
  bool _changelogExpanded = false;
  bool _hasCheckedOnMount = false;
  bool _showAllBinaries = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_hasCheckedOnMount) {
        _hasCheckedOnMount = true;
        _checkForUpdates();
      }
    });
  }

  @override
  void dispose() {
    _releaseService.close();
    super.dispose();
  }

  Future<void> _checkForUpdates({bool force = false}) async {
    final dp = widget.deviceProvider ?? context.read<DeviceProvider>();
    final otaUrl = dp.otaUrl;
    if (otaUrl.isEmpty) {
      if (mounted) {
        setState(() {
          _latestRelease = null;
          _checkError = null;
          _checkingUpdate = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _checkingUpdate = true;
        _checkError = null;
      });
    }

    try {
      final release = await _releaseService.fetchLatestRelease(otaUrl);
      if (!mounted) return;
      setState(() {
        _latestRelease = release;
        _checkingUpdate = false;
        if (release != null) {
          final targetBoardOrName = dp.board ?? dp.configName ?? widget.device.name;
          _selectedReleaseAsset = release.findBestAsset(targetBoardOrName, showAll: _showAllBinaries);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingUpdate = false;
        _checkError = '$e';
      });
    }
  }

  Future<void> _downloadAndFlash(ReleaseAsset asset) async {
    setState(() {
      _uploading = true;
      _complete = false;
      _error = false;
      _status = 'Downloading ${asset.name}...';
      _received = 0;
      _total = asset.size;
      _started = DateTime.now();
      _cancelled = false;
      _errorMessage = null;
    });

    Uint8List firmwareBytes;
    try {
      firmwareBytes = await _releaseService.downloadAsset(
        asset.downloadUrl,
        onProgress: (received, total) {
          if (!mounted || _cancelled) return;
          setState(() {
            _received = received;
            _total = total;
            _status = 'Downloading asset (${_formatBytes(received)} / ${_formatBytes(total)})...';
          });
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _uploading = false;
        _status = 'Download failed';
        _errorMessage = 'Download error: $e';
      });
      return;
    }

    if (_cancelled || !mounted) return;
    await _startUpload(firmwareBytes);
  }

  Future<void> _selectFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: false,
    );
    if (result.isEmpty) return;
    final file = result.first;
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
    final dp = widget.deviceProvider ?? context.read<DeviceProvider>();
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
    final dp = widget.deviceProvider ?? context.watch<DeviceProvider>();
    final configName = dp.configName ?? 'Unknown';
    final currentVersion = dp.firmwareVersion ?? '1.0.0';

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
                color: context.tokens.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.memory_rounded,
                  color: context.tokens.primary, size: 24),
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
                          color: context.tokens.onSurface)),
                  const SizedBox(height: 2),
                  Text('FIRMWARE UPDATE',
                      style: TextStyle(
                          color: context.tokens.primary.withValues(alpha: 0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 24),
          Divider(height: 1, color: context.tokens.onSurface.withValues(alpha: 0.12)),
          const SizedBox(height: 24),

          // ── Firmware info ────────────────────────────────────
          if (dp.board != null && dp.board!.isNotEmpty)
            _infoRow('BOARD', dp.board!),
          _infoRow('DEVICE', configName),
          _infoRow('VERSION', currentVersion),
          if (dp.otaUrl.isNotEmpty) _infoRow('OTA SOURCE', dp.otaUrl),
          const SizedBox(height: 24),

          // ── Uploading / Progress State ───────────────────────
          if (_uploading) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _total > 0 ? _received / _total : null,
                minHeight: 6,
                backgroundColor: context.tokens.onSurface.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation(context.tokens.primary),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(_status,
                      style:
                          TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.7), fontSize: 12)),
                ),
                Text('${_total > 0 ? (_received * 100 ~/ _total) : 0}%',
                    style: GoogleFonts.martianMono(
                        color: context.tokens.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: context.tokens.error,
                  foregroundColor: context.tokens.onSurface,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: _cancel,
                child: const Text('CANCEL'),
              ),
            ),
          ] else if (_complete) ...[
            // ── Complete state ─────────────────────────────────
            Row(children: [
              Icon(Icons.check_circle_rounded,
                  color: context.tokens.success, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Device is rebooting with new firmware.',
                    style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.7), fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.tokens.onSurface.withValues(alpha: 0.54),
                  side: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.24)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('CLOSE'),
              ),
            ),
          ] else if (_error) ...[
            // ── Error state ────────────────────────────────────
            Row(children: [
              Icon(Icons.error_rounded,
                  color: context.tokens.error, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(_errorMessage ?? 'Unknown error',
                    style:
                        TextStyle(color: context.tokens.error, fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: context.tokens.primary,
                  side: BorderSide(
                      color: context.tokens.primary.withValues(alpha: 0.6)),
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
          ] else ...[
            // ── Remote Update / Release Section ────────────────
            if (dp.otaUrl.isNotEmpty) ...[
              _buildRemoteUpdateSection(context, dp, currentVersion),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: Divider(color: context.tokens.onSurface.withValues(alpha: 0.12))),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR LOCAL FILE',
                      style: TextStyle(
                          color: context.tokens.onSurface.withValues(alpha: 0.38),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                ),
                Expanded(child: Divider(color: context.tokens.onSurface.withValues(alpha: 0.12))),
              ]),
              const SizedBox(height: 24),
            ],

            // ── Confirm upload phase (file selected) ───────────
            if (_selectedFileName != null &&
                _selectedFirmwareBytes != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.tokens.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: context.tokens.primary.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('SELECTED FILE',
                        style: TextStyle(
                            color: context.tokens.primary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Icon(Icons.insert_drive_file_rounded,
                          size: 18, color: context.tokens.onSurface),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_selectedFileName!,
                                style: GoogleFonts.martianMono(
                                    color: context.tokens.onSurface,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Text(_formatBytes(_selectedFirmwareBytes!.length),
                                style: TextStyle(
                                    color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close_rounded,
                            size: 18, color: context.tokens.onSurface.withValues(alpha: 0.38)),
                        onPressed: _clearSelection,
                      ),
                    ]),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _buildEraseToggle(context),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.tokens.primary,
                    foregroundColor: context.tokens.onPrimary,
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

            // ── Select file button (always visible when idle) ──
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.tokens.primary,
                  foregroundColor: context.tokens.onPrimary,
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
            Text(
              'Select a compiled firmware (.bin) file to update the device.',
              style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.38), fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRemoteUpdateSection(
    BuildContext context,
    DeviceProvider dp,
    String currentVersion,
  ) {
    if (_checkingUpdate) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.tokens.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(context.tokens.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Checking for remote updates...',
                style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_checkError != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tokens.error.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.tokens.error.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.sync_problem_rounded, color: context.tokens.error, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Could not check remote releases',
                    style: TextStyle(color: context.tokens.error, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: context.tokens.onSurface.withValues(alpha: 0.7),
                onPressed: () => _checkForUpdates(force: true),
              ),
            ]),
            Text(_checkError!,
                style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 11)),
          ],
        ),
      );
    }

    if (_latestRelease == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.tokens.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.tokens.onSurface.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline_rounded,
                size: 18, color: context.tokens.onSurface.withValues(alpha: 0.54)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No releases found on remote repository.',
                style: TextStyle(
                  color: context.tokens.onSurface.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _checkForUpdates(force: true),
              child: const Text('CHECK AGAIN'),
            ),
          ],
        ),
      );
    }

    final release = _latestRelease!;
    final isNewer = FirmwareReleaseService.isNewerVersion(release.version, currentVersion);
    final binAssets = release.getFilteredBinAssets(showAll: _showAllBinaries);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNewer
            ? context.tokens.primary.withValues(alpha: 0.06)
            : context.tokens.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isNewer
              ? context.tokens.primary.withValues(alpha: 0.3)
              : context.tokens.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card Header ──────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isNewer
                      ? context.tokens.primary.withValues(alpha: 0.15)
                      : context.tokens.success.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isNewer ? Icons.system_update_rounded : Icons.check_circle_rounded,
                  color: isNewer ? context.tokens.primary : context.tokens.success,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          isNewer ? 'UPDATE AVAILABLE' : 'FIRMWARE UP TO DATE',
                          style: TextStyle(
                            color: isNewer ? context.tokens.primary : context.tokens.success,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                        if (isNewer) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: context.tokens.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'NEW',
                              style: TextStyle(
                                color: context.tokens.onPrimary,
                                fontSize: 9,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${release.title} (${release.tagName})',
                      style: GoogleFonts.exo2(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: context.tokens.onSurface,
                      ),
                    ),
                    if (release.publishedAt != null)
                      Text(
                        'Published: ${_formatDate(release.publishedAt!)}',
                        style: TextStyle(
                          color: context.tokens.onSurface.withValues(alpha: 0.5),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                color: context.tokens.onSurface.withValues(alpha: 0.6),
                tooltip: 'Check again',
                onPressed: () => _checkForUpdates(force: true),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Asset Selection ──────────────────────────────────
          if (binAssets.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TARGET FIRMWARE BINARY',
                  style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.54),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                if (release.hasOtaBinAssets)
                  InkWell(
                    onTap: () {
                      setState(() {
                        _showAllBinaries = !_showAllBinaries;
                        final updatedBins =
                            release.getFilteredBinAssets(showAll: _showAllBinaries);
                        if (_selectedReleaseAsset == null ||
                            !updatedBins.contains(_selectedReleaseAsset)) {
                          final targetBoardOrName =
                              dp.board ?? dp.configName ?? widget.device.name;
                          _selectedReleaseAsset = release.findBestAsset(
                              targetBoardOrName,
                              showAll: _showAllBinaries);
                        }
                      });
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        _showAllBinaries
                            ? 'SHOW ONLY OTA (${release.otaBinAssets.length})'
                            : 'SHOW ALL (${release.binAssets.length})',
                        style: TextStyle(
                          color: context.tokens.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            if (binAssets.length == 1) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: context.tokens.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.tokens.onSurface.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.developer_board_rounded,
                        size: 16, color: context.tokens.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        binAssets.first.name,
                        style: GoogleFonts.martianMono(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.tokens.onSurface,
                        ),
                      ),
                    ),
                    Text(
                      _formatBytes(binAssets.first.size),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.tokens.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                decoration: BoxDecoration(
                  color: context.tokens.onSurface.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.tokens.onSurface.withValues(alpha: 0.08)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ReleaseAsset>(
                    value: _selectedReleaseAsset ?? binAssets.first,
                    isExpanded: true,
                    dropdownColor: context.tokens.surface,
                    icon: Icon(Icons.arrow_drop_down, color: context.tokens.onSurface),
                    items: binAssets.map((asset) {
                      return DropdownMenuItem<ReleaseAsset>(
                        value: asset,
                        child: Row(
                          children: [
                            Icon(Icons.developer_board_rounded,
                                size: 16, color: context.tokens.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                asset.name,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.martianMono(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: context.tokens.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              _formatBytes(asset.size),
                              style: TextStyle(
                                fontSize: 11,
                                color: context.tokens.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (asset) {
                      if (asset != null) {
                        setState(() => _selectedReleaseAsset = asset);
                      }
                    },
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],

          // ── Expandable Changelog ──────────────────────────────
          if (release.changelog.trim().isNotEmpty) ...[
            InkWell(
              onTap: () => setState(() => _changelogExpanded = !_changelogExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Icon(
                      _changelogExpanded
                          ? Icons.keyboard_arrow_down_rounded
                          : Icons.keyboard_arrow_right_rounded,
                      size: 18,
                      color: context.tokens.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Release Notes',
                      style: TextStyle(
                        color: context.tokens.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_changelogExpanded) ...[
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.tokens.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: context.tokens.onSurface.withValues(alpha: 0.06)),
                ),
                child: Text(
                  release.changelog.trim(),
                  style: TextStyle(
                    color: context.tokens.onSurface.withValues(alpha: 0.8),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],

          // ── Erase All Option ──────────────────────────────────
          _buildEraseToggle(context),
          const SizedBox(height: 16),

          // ── Download & Flash Button ───────────────────────────
          if (binAssets.isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isNewer ? context.tokens.primary : context.tokens.surface,
                  foregroundColor: isNewer ? context.tokens.onPrimary : context.tokens.onSurface,
                  side: isNewer
                      ? null
                      : BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.2)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                icon: Icon(
                  isNewer ? Icons.download_rounded : Icons.replay_rounded,
                  size: 20,
                ),
                label: Text(
                  isNewer ? 'DOWNLOAD & FLASH (v${release.version})' : 'REFLASH RELEASE (v${release.version})',
                  style: GoogleFonts.changa(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    fontSize: 12,
                  ),
                ),
                onPressed: () {
                  final target = _selectedReleaseAsset ?? binAssets.first;
                  _downloadAndFlash(target);
                },
              ),
            )
          else
            Text(
              'No .bin firmware binary assets found in this release.',
              style: TextStyle(
                color: context.tokens.error,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEraseToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: context.tokens.onSurface.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(Icons.delete_sweep_rounded,
              size: 18,
              color: _eraseAll
                  ? context.tokens.error
                  : context.tokens.onSurface.withValues(alpha: 0.38)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ERASE ALL',
                    style: TextStyle(
                        color: context.tokens.onSurface,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
                Text('Reset to factory defaults after reboot (NVS + filesystem)',
                    style: TextStyle(
                        color: context.tokens.onSurface.withValues(alpha: 0.38),
                        fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: _eraseAll,
            onChanged: (v) => setState(() => _eraseAll = v),
            activeThumbColor: context.tokens.error,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 12)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.martianMono(
                    color: context.tokens.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
