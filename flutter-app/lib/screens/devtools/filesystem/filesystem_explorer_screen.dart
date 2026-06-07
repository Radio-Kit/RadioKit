import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../models/fs_entry.dart';
import '../../../models/fs_info.dart';
import '../../../providers/device_provider.dart';
import '../../../services/device_fs_service.dart';
import '../../../widgets/radiokit_app_bar.dart';
import 'fs_action_sheet.dart';
import 'fs_breadcrumbs.dart';
import 'fs_drawer.dart';
import 'fs_file_tile.dart';
import 'fs_helpers.dart';
import 'fs_info_strip.dart';

/// Material 3 file explorer for the connected device's LittleFS partition.
///
/// Reachable from the DevTools tab. Drives [DeviceFsService] over the
/// main BLE/Serial transport (0xAA bulk-FS protocol).
class FilesystemExplorerScreen extends StatefulWidget {
  const FilesystemExplorerScreen({super.key});

  @override
  State<FilesystemExplorerScreen> createState() =>
      _FilesystemExplorerScreenState();
}

class _FilesystemExplorerScreenState
    extends State<FilesystemExplorerScreen> {
  DeviceFsService? _fs;

  List<FsEntry> _entries = [];
  FsInfo? _fsInfo;

  String _currentPath = '/';
  bool _loading = false;
  bool _initTriggered = false;
  String? _statusMessage;
  String? _errorMessage;
  double? _progress;
  DateTime? _transferStartTime;
  int _currentTransferBytes = 0;

  bool get _isTransferring => _transferStartTime != null;

  bool _isMultiSelect = false;
  final Set<String> _selectedPaths = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialRefresh());
  }

  /// Kick off a listing once the FS service is ready, but only once.
  void _initialRefresh() {
    if (!mounted || _initTriggered) return;
    final dp = context.read<DeviceProvider>();
    if (!dp.isConnected) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _initialRefresh());
      return;
    }
    // Defer if an FS frame exchange (e.g. HTTP API write/read) is in
    // progress. Retry after a short delay to avoid transport contention.
    if (dp.isFsBusy) {
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) _initialRefresh();
      });
      return;
    }
    _initTriggered = true;
    if (_fs == null) {
      _fs = createDeviceFsService(dp);
    }
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final deviceProvider = context.watch<DeviceProvider>();
    final isConnected = deviceProvider.isConnected;

    if (isConnected && _fs == null) {
      _fs = createDeviceFsService(deviceProvider);
    } else if (!isConnected) {
      _fs = null;
    }

    return Scaffold(
      appBar: RadioKitAppBar(
        title: _isMultiSelect
            ? '${_selectedPaths.length} selected'
            : 'Filesystem',
        automaticallyImplyLeading: false,
        leading: _isMultiSelect
            ? IconButton(
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel selection',
                onPressed: _exitMultiSelect,
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/models');
                  }
                },
              ),
        actions: _isMultiSelect
            ? [
                IconButton(
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Select all',
                  onPressed: _selectedPaths.length == _entries.length
                      ? _deselectAll
                      : _selectAll,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  tooltip: 'Delete selected',
                  onPressed: _selectedPaths.isEmpty ? null : _deleteSelected,
                ),
              ]              : [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded),
                  tooltip: 'Refresh',
                  onPressed: _loading ? null : _refresh,
                ),
              ],
      ),
      drawer: _fs == null
          ? null
          : FsDrawer(
              info: _fsInfo,
              currentPath: _currentPath,
              onJumpTo: _navigateTo,
              onFormatPartition: _formatPartition,
            ),
      body: _buildBody(isConnected),
      floatingActionButton: _isMultiSelect
          ? null
          : (isConnected && _fs != null) ? _buildFab() : null,
    );
  }

  // ─── Body ──────────────────────────────────────────────────────────────

  Widget _buildBody(bool isConnected) {
    if (!isConnected || _fs == null) {
      return _buildDisconnected();
    }
    if (_loading && _entries.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Listing files…'),
          ],
        ),
      );
    }

    return Column(
      children: [
        FsInfoStrip(
          info: _fsInfo,
          loading: _loading && _fsInfo == null,
          speedBytesPerSec: _isTransferring && _transferStartTime != null
              ? _currentTransferBytes /
                  (DateTime.now().difference(_transferStartTime!).inMilliseconds / 1000.0)
              : null,
        ),
        FsBreadcrumbs(
          currentPath: _currentPath,
          onJumpTo: (idx) {
            final segs = ['/', ...pathSegments(_currentPath)];
            if (idx == 0) {
              _navigateTo('/');
            } else {
              _navigateTo(segs.take(idx + 1).join('/'));
            }
          },
        ),
        const Divider(height: 1),
        Expanded(child: _buildList()),
        if (_statusMessage != null || _errorMessage != null || _progress != null)
          _buildStatusBar(),
      ],
    );
  }

  Widget _buildDisconnected() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Not connected',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a device to browse its filesystem.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList() {
    if (_entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Icon(
              Icons.folder_open_rounded,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                'Empty directory',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 4),
            Center(
              child: Text(
                'Tap + to upload a file or create a folder',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    final sorted = List<FsEntry>.from(_entries);
    sorted.sort((a, b) {
      if (a.isDirectory != b.isDirectory) {
        return a.isDirectory ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
        itemCount: sorted.length,
        separatorBuilder: (_, __) => const SizedBox(height: 2),
        itemBuilder: (context, i) {
          final entry = sorted[i];
          final path = joinPath(_currentPath, entry.name);
          return FsFileTile(
            entry: entry,
            fullPath: path,
            isSelected: _selectedPaths.contains(path),
            isMultiSelect: _isMultiSelect,
            onTap: () => _onTileTap(entry, path),
            onLongPress: () => _onTileLongPress(entry, path),
            onSecondaryAction: () => _openActionSheet(entry, path),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar() {
    final scheme = Theme.of(context).colorScheme;
    final hasError = _errorMessage != null;
    final color = hasError
        ? scheme.error
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return Material(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_progress != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  minHeight: 4,
                  backgroundColor: scheme.surfaceContainerHigh,
                ),
              ),
              const SizedBox(height: 4),
            ],
            Row(
              children: [
                Icon(
                  hasError
                      ? Icons.error_outline_rounded
                      : Icons.info_outline_rounded,
                  size: 14,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage ?? _statusMessage ?? '',
                    style: TextStyle(color: color, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasError)
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 16),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _errorMessage = null),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Speed chip in AppBar ──────────────────────────────────────────────

  Widget _buildSpeedChip() {
    final elapsed = DateTime.now().difference(_transferStartTime!).inMilliseconds / 1000.0;
    final speed = (elapsed > 0 && _currentTransferBytes > 0) ? _currentTransferBytes / elapsed : 0.0;
    final speedText = _formatSpeed(speed);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.3), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 10, height: 10,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: scheme.primary,
              ),
            ),
            const SizedBox(width: 5),
            Text(
              speedText,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.primary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── FAB ───────────────────────────────────────────────────────────────

  Widget _buildFab() {
    return FloatingActionButton.extended(
      onPressed: _showUploadMenu,
      icon: const Icon(Icons.add_rounded),
      label: const Text('New'),
    );
  }

  Future<void> _showUploadMenu() async {
    final choice = await showModalBottomSheet<_NewChoice>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.upload_file_rounded),
              title: const Text('Upload file'),
              subtitle: const Text('Pick a file from this device'),
              onTap: () => Navigator.of(ctx).pop(_NewChoice.upload),
            ),
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: const Text('New folder'),
              subtitle: const Text('Create a directory here'),
              onTap: () => Navigator.of(ctx).pop(_NewChoice.mkdir),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    switch (choice) {
      case _NewChoice.upload:
        await _uploadFile();
        break;
      case _NewChoice.mkdir:
        await _createFolder();
        break;
      case null:
        break;
    }
  }

  // ─── Tile interactions ────────────────────────────────────────────────

  void _onTileTap(FsEntry entry, String path) {
    HapticFeedback.selectionClick();
    if (_isMultiSelect) {
      setState(() {
        if (_selectedPaths.contains(path)) {
          _selectedPaths.remove(path);
        } else {
          _selectedPaths.add(path);
        }
      });
      return;
    }
    if (entry.isDirectory) {
      _navigateTo(path);
    } else {
      _openActionSheet(entry, path);
    }
  }

  void _onTileLongPress(FsEntry entry, String path) {
    HapticFeedback.mediumImpact();
    if (_isMultiSelect) {
      _onTileTap(entry, path);
    } else {
      setState(() {
        _isMultiSelect = true;
        _selectedPaths.add(path);
      });
    }
  }

  Future<void> _openActionSheet(FsEntry entry, String path) async {
    if (_isMultiSelect) {
      _onTileTap(entry, path);
      return;
    }
    final action = await FsActionSheet.show(context,
        entry: entry, fullPath: path);
    if (!mounted || action == null) return;
    switch (action) {
      case FsAction.download:
        await _downloadFile(entry, path);
        break;
      case FsAction.rename:
        await _renameEntry(path);
        break;
      case FsAction.copyPath:
        await Clipboard.setData(ClipboardData(text: path));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied: $path')),
        );
        break;
      case FsAction.info:
        _showInfoDialog(entry, path);
        break;
      case FsAction.delete:
        await _deleteEntry(entry, path);
        break;
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path == '' ? '/' : path;
      _entries = [];
      _selectedPaths.clear();
    });
    _refresh();
  }

  // ─── Refresh ──────────────────────────────────────────────────────────

  /// Show a SnackBar with [message] and (optionally) a friendly prefix
  /// indicating the operation that failed. Also sets the in-page
  /// [_errorMessage] for the persistent status strip.
  void _showError(String message) {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.errorContainer,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ],
          ),
        ),
      );
  }

  Future<void> _refresh() async {
    if (_fs == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = 'Listing $_currentPath…';
      _progress = null;
    });
    try {
      final entries = await _fs!.listDir(_currentPath);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _statusMessage = '${entries.length} entries';
        _progress = null;
      });
      // Get FS info lazily (no await on UI thread)
      unawaited(_fetchInfo());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'List error: $e';
        _statusMessage = null;
      });
      _showError('List error: $e');
    }
  }

  Future<void> _fetchInfo() async {
    if (_fs == null) return;
    try {
      final info = await _fs!.getInfo();
      if (!mounted) return;
      setState(() => _fsInfo = info);
    } catch (_) {
      // info is optional; ignore
    }
  }

  // ─── File operations ──────────────────────────────────────────────────

  /// Format a transfer speed as a human-readable string.
  String _formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    } else if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(0)} KB/s';
    } else {
      return '${bytesPerSec.toStringAsFixed(0)} B/s';
    }
  }

  Future<void> _uploadFile() async {
    if (_fs == null) return;
    try {
      final picked = await pickUploadFile(context);
      if (picked == null || !mounted) return;
      final remotePath = joinPath(_currentPath, picked.name);
      _transferStartTime = DateTime.now();
      setState(() {
        _statusMessage = 'Uploading ${picked.name}…';
        _progress = 0;
      });
      final res = await _fs!.writeFile(
        remotePath,
        picked.bytes,
        onProgress: (w, t) {
          if (!mounted) return;
          setState(() {
            _currentTransferBytes = w;
            _progress = t == 0 ? null : w / t;
            _statusMessage =
                'Uploading ${picked.name}  ${formatBytes(w)} / ${formatBytes(t)}';
          });
        },
      );
      if (!mounted) return;
      if (res.success) {
        _transferStartTime = null;
        _currentTransferBytes = 0;
        setState(() {
          _statusMessage = 'Uploaded ${picked.name}';
          _progress = null;
        });
      } else {
        _transferStartTime = null;
        _currentTransferBytes = 0;
        setState(() {
          _errorMessage = 'Upload failed: ${res.errorName}';
          _statusMessage = null;
          _progress = null;
        });
        _showError('Upload failed: ${res.errorName}');
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      setState(() {
        _errorMessage = 'Upload error: $e';
        _progress = null;
      });
      _showError('Upload error: $e');
    }
  }

  Future<void> _downloadFile(FsEntry entry, String path) async {
    if (_fs == null) return;
    _transferStartTime = DateTime.now();
    setState(() {
      _statusMessage = 'Reading ${entry.name}…';
      _progress = 0;
    });
    try {
      final bytes = await _fs!.readFile(
        path,
        onProgress: (r, t) {
          if (!mounted) return;
          setState(() {
            _currentTransferBytes = r;
            _progress = t == 0 ? null : r / t;
            _statusMessage =
                'Reading ${entry.name}  ${formatBytes(r)} / ${formatBytes(t)}';
          });
        },
      );
      if (!mounted) return;
      if (bytes == null) {
        _transferStartTime = null;
        _currentTransferBytes = 0;
        setState(() {
          _errorMessage = 'Download failed';
          _progress = null;
        });
        _showError('Download failed');
        return;
      }
      _transferStartTime = null;
      final savePath = await promptSaveFile(context,
          fileName: entry.name, bytes: bytes);
      if (!mounted) return;
      setState(() {
        _statusMessage = savePath != null
            ? 'Saved ${entry.name} → $savePath'
            : 'Cancelled save';
        _progress = null;
      });
    } catch (e) {
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      setState(() {
        _errorMessage = 'Download error: $e';
        _progress = null;
      });
      _showError('Download error: $e');
    }
  }

  Future<void> _deleteEntry(FsEntry entry, String path) async {
    if (_fs == null) return;
    final ok = await confirmDelete(context, entry);
    if (!ok || !mounted) return;
    setState(() {
      _statusMessage = 'Deleting ${entry.name}…';
      _progress = 0;
    });
    try {
      final res = await _fs!.delete(path, recursive: entry.isDirectory);
      if (!mounted) return;
      if (res.success) {
        setState(() {
          _statusMessage = 'Deleted ${entry.name}';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Delete failed: ${res.errorName}';
          _statusMessage = null;
          _progress = null;
        });
        _showError('Delete failed: ${res.errorName}');
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Delete error: $e';
        _progress = null;
      });
      _showError('Delete error: $e');
    }
  }

  Future<void> _deleteSelected() async {
    if (_fs == null || _selectedPaths.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedPaths.length} items?'),
        content: const Text(
          'This will permanently delete the selected files and folders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final paths = _selectedPaths.toList();
    int okCount = 0;
    int failCount = 0;
    setState(() {
      _statusMessage = 'Deleting ${paths.length} items…';
      _progress = 0;
    });
    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];
      final isDir =
          _entries.any((e) => joinPath(_currentPath, e.name) == p && e.isDirectory);
      try {
        final res = await _fs!.delete(p, recursive: isDir);
        if (res.success) {
          okCount++;
        } else {
          failCount++;
        }
      } catch (_) {
        failCount++;
      }
      if (!mounted) return;
      setState(() => _progress = (i + 1) / paths.length);
    }
    if (!mounted) return;
    _exitMultiSelect();
    setState(() {
      _statusMessage = failCount == 0
          ? 'Deleted $okCount items'
          : 'Deleted $okCount, $failCount failed';
      _progress = null;
    });
    await _refresh();
  }

  Future<void> _renameEntry(String oldPath) async {
    if (_fs == null) return;
    final newPath = await promptRename(context, oldPath);
    if (newPath == null || !mounted) return;
    setState(() {
      _statusMessage = 'Renaming…';
      _progress = 0;
    });
    try {
      final res = await _fs!.rename(oldPath, newPath);
      if (!mounted) return;
      if (res.success) {
        setState(() {
          _statusMessage = 'Renamed';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Rename failed: ${res.errorName}';
          _progress = null;
        });
        _showError('Rename failed: ${res.errorName}');
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Rename error: $e';
        _progress = null;
      });
      _showError('Rename error: $e');
    }
  }

  Future<void> _createFolder() async {
    if (_fs == null) return;
    final newPath = await promptNewFolder(context, _currentPath);
    if (newPath == null || !mounted) return;
    setState(() {
      _statusMessage = 'Creating folder…';
      _progress = 0;
    });
    try {
      final res = await _fs!.mkdir(newPath);
      if (!mounted) return;
      if (res.success) {
        setState(() {
          _statusMessage = 'Created folder';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Create failed: ${res.errorName}';
          _progress = null;
        });
        _showError('Create failed: ${res.errorName}');
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Create error: $e';
        _progress = null;
      });
      _showError('Create error: $e');
    }
  }

  Future<bool> _formatPartition() async {
    if (_fs == null) return false;
    setState(() {
      _statusMessage = 'Formatting partition…';
      _progress = null;
    });
    final res = await _fs!.format();
    if (!mounted) return res.success;
    setState(() {
      _statusMessage = res.success
          ? 'Format complete'
          : 'Format failed: ${res.errorName}';
      _progress = null;
    });
    if (!res.success) _showError('Format failed: ${res.errorName}');
    return res.success;
  }

  // ─── Multi-select helpers ─────────────────────────────────────────────

  void _selectAll() {
    setState(() {
      for (final e in _entries) {
        _selectedPaths.add(joinPath(_currentPath, e.name));
      }
    });
  }

  void _deselectAll() {
    setState(() => _selectedPaths.clear());
  }

  void _exitMultiSelect() {
    setState(() {
      _isMultiSelect = false;
      _selectedPaths.clear();
    });
  }

  // ─── Info dialog ──────────────────────────────────────────────────────

  void _showInfoDialog(FsEntry entry, String path) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(entry.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _kv('Type', entry.isDirectory ? 'Folder' : 'File'),
            _kv('Path', path),
            if (!entry.isDirectory) _kv('Size', formatBytes(entry.size)),
            if (!entry.isDirectory) _kv('Bytes', entry.size.toString()),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              k,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              v,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _NewChoice { upload, mkdir }
