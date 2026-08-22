import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../providers/device_provider.dart';
import '../../models/fs_entry.dart';
import '../../models/fs_info.dart';
import '../../theme/app_theme.dart';
import '../../widgets/themed_bottom_sheet.dart';
import '../../services/device_fs_service.dart';
import '../filesystem/fs_helpers.dart';
import '../filesystem/fs_breadcrumbs.dart';
import '../filesystem/fs_file_tile.dart';
import '../filesystem/fs_info_strip.dart';
import '../filesystem/fs_action_sheet.dart';
import '../filesystem/file_editor_cache.dart';
import '../filesystem/file_editor_dialog.dart';

class FsTabContent extends StatefulWidget {
  final DeviceProvider? deviceProvider;
  const FsTabContent({super.key, this.deviceProvider});

  @override
  State<FsTabContent> createState() => _FsTabContentState();
}

class _FsTabContentState extends State<FsTabContent> {
  final FileEditorCache _editorCache = FileEditorCache();
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
  bool _isMultiSelect = false;
  final Set<String> _selectedPaths = {};
  final Set<String> _loadingPaths = {};

  DeviceProvider? _dp;

  @override
  void initState() {
    super.initState();
    _dp = widget.deviceProvider;
    _dp?.addListener(_onDeviceProviderChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initFs());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dp = widget.deviceProvider ?? context.read<DeviceProvider>();
    if (_dp != dp) {
      _dp?.removeListener(_onDeviceProviderChanged);
      _dp = dp;
      _dp?.addListener(_onDeviceProviderChanged);
      _initFs();
    }
  }

  @override
  void dispose() {
    _dp?.removeListener(_onDeviceProviderChanged);
    super.dispose();
  }

  void _onDeviceProviderChanged() {
    if (!mounted) return;
    final dp = _dp ?? widget.deviceProvider ?? context.read<DeviceProvider>();
    if (dp.isConnected && !_initTriggered) {
      _initFs();
    } else if (!dp.isConnected && _initTriggered) {
      setState(() {
        _initTriggered = false;
        _fs = null;
        _entries = [];
        _fsInfo = null;
        _loading = false;
      });
    }
  }

  void _initFs() {
    if (!mounted || _initTriggered) return;
    final dp = _dp ?? widget.deviceProvider ?? context.read<DeviceProvider>();
    if (!dp.isConnected) {
      return;
    }
    _initTriggered = true;
    _fs = createDeviceFsService(dp);
    if (dp.fsCacheReady && _currentPath == '/') {
      final cached = dp.fsTreeCache!['/']!;
      setState(() {
        _entries = cached;
        _statusMessage = '${cached.length} entries (cached)';
      });
    }
    _refresh();
  }

  void _navigateToParent() {
    if (_currentPath == '/') return;
    final segs = pathSegments(_currentPath);
    if (segs.length <= 1) {
      _navigateTo('/');
    } else {
      _navigateTo('/${segs.take(segs.length - 1).join('/')}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPopLocally = _isMultiSelect || _currentPath != '/';
    return PopScope(
      canPop: !canPopLocally,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isMultiSelect) {
          setState(() {
            _selectedPaths.clear();
            _isMultiSelect = false;
          });
          return;
        }
        if (_currentPath != '/') {
          _navigateToParent();
        }
      },
      child: Column(
        children: [
          FsInfoStrip(
            info: _fsInfo,
            loading: _loading && _fsInfo == null,
            speedBytesPerSec:
                _transferStartTime != null
                    ? _currentTransferBytes /
                        (DateTime.now()
                                .difference(_transferStartTime!)
                                .inMilliseconds /
                            1000.0)
                    : null,
          ),
          FsBreadcrumbs(
            currentPath: _currentPath,
            onJumpTo: (idx) {
              final segs = ['/', ...pathSegments(_currentPath)];
              _navigateTo(idx == 0 ? '/' : segs.take(idx + 1).join('/'));
            },
          ),
          const Divider(height: 1),
          Expanded(child: _buildList()),
          if (_statusMessage != null ||
              _errorMessage != null ||
              _progress != null)
            _buildStatusBar(),
        ],
      ),
    );
  }

  Widget _buildList() {
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

    if (_entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 80),
            Icon(Icons.folder_open_rounded,
                size: 64, color: context.tokens.onSurface.withValues(alpha: 0.38)),
            const SizedBox(height: 16),
            const Center(
                child: Text('Empty directory',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
            const SizedBox(height: 4),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Upload or create'),
                onPressed: _showUploadMenu,
              ),
            ),
          ],
        ),
      );
    }

    final sorted = List<FsEntry>.from(_entries);
    sorted.sort((a, b) {
      if (a.isDirectory != b.isDirectory) return a.isDirectory ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return Stack(
      children: [
        Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
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
                      onEdit: isEditableFile(entry.name)
                          ? () => _editFile(entry, path)
                          : null,
                      isLoading: _loadingPaths.contains(path),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        // Floating action buttons
        if (_isMultiSelect)
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _floatingActionButton(
                  icon: Icons.select_all_rounded,
                  tooltip: 'Select all',
                  onPressed: _selectedPaths.length == _entries.length
                      ? _deselectAll
                      : _selectAll,
                ),
                const SizedBox(width: 8),
                _floatingActionButton(
                  icon: Icons.delete_outline_rounded,
                  tooltip: 'Delete selected',
                  onPressed: _selectedPaths.isEmpty ? null : _deleteSelected,
                ),
                const SizedBox(width: 8),
                _floatingActionButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Cancel',
                  onPressed: () {
                    setState(() {
                      _selectedPaths.clear();
                      _isMultiSelect = false;
                    });
                  },
                ),
              ],
            ),
          )
        else
          Positioned(
            right: 16,
            bottom: 16,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _floatingActionButton(
                  icon: Icons.create_new_folder_outlined,
                  tooltip: 'New folder',
                  onPressed: _createFolder,
                ),
                const SizedBox(width: 8),
                _floatingActionButton(
                  icon: Icons.upload_file_rounded,
                  tooltip: 'Upload file',
                  onPressed: () => _uploadFile(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _floatingActionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 44,
        height: 44,
        child: FloatingActionButton(
          backgroundColor: context.tokens.primary.withValues(alpha: 0.9),
          foregroundColor: context.tokens.onPrimary,
          onPressed: onPressed,
          child: Icon(icon, size: 20),
        ),
      ),
    );
  }

  Widget _buildStatusBar() {
    final hasError = _errorMessage != null;
    final color = hasError ? context.tokens.error : context.tokens.onSurface.withValues(alpha: 0.54);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      color: context.tokens.base200,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 4,
                backgroundColor: context.tokens.onSurface.withValues(alpha: 0.12),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(children: [
            Icon(
                hasError
                    ? Icons.error_outline_rounded
                    : Icons.info_outline_rounded,
                size: 14,
                color: color),
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
          ]),
        ],
      ),
    );
  }

  // ── FS Operations ────────────────────────────────────────────────────

  void _showUploadMenu() {
    showThemedBottomSheet<_NewChoice>(
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
    ).then((choice) {
      switch (choice) {
        case _NewChoice.upload:
          _uploadFile();
          break;
        case _NewChoice.mkdir:
          _createFolder();
          break;
        default:
          break;
      }
    });
  }

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
    final action =
        await FsActionSheet.show(context, entry: entry, fullPath: path);
    if (!mounted || action == null) return;
    switch (action) {
      case FsAction.edit:
        await _editFile(entry, path);
        break;
      case FsAction.download:
        await _downloadFile(entry, path);
        break;
      case FsAction.rename:
        await _renameEntry(path);
        break;
      case FsAction.copyPath:
        await Clipboard.setData(ClipboardData(text: path));
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Copied: $path')));
        }
        break;
      case FsAction.info:
        _showInfoDialog(entry, path);
        break;
      case FsAction.delete:
        await _deleteEntry(entry, path);
        break;
    }
  }

  void _navigateTo(String path) {
    setState(() {
      _currentPath = path == '' ? '/' : path;
      _entries = [];
      _selectedPaths.clear();
    });
    _refresh();
  }

  Future<void> _refresh() async {
    if (_fs == null) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _statusMessage = 'Listing $_currentPath…';
    });
    try {
      final entries = await _fs!.listDir(_currentPath);
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _statusMessage = '${entries.length} entries';
      });
      unawaited(_fetchInfo());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = 'List error: $e';
        _statusMessage = null;
      });
    }
  }

  Future<void> _fetchInfo() async {
    if (_fs == null) return;
    try {
      final info = await _fs!.getInfo();
      if (mounted) setState(() => _fsInfo = info);
    } catch (_) {}
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
      final res =
          await _fs!.writeFile(remotePath, picked.bytes, onProgress: (w, t) {
        if (!mounted) return;
        setState(() {
          _currentTransferBytes = w;
          _progress = t == 0 ? null : w / t;
          _statusMessage =
              'Uploading ${picked.name}  ${formatBytes(w)} / ${formatBytes(t)}';
        });
      });
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      if (res.success) {
        setState(() {
          _statusMessage = 'Uploaded ${picked.name}';
          _progress = null;
        });
      } else {
        setState(() {
          _errorMessage = 'Upload failed: ${res.errorName}';
          _statusMessage = null;
          _progress = null;
        });
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
      final bytes = await _fs!.readFile(path, onProgress: (r, t) {
        if (!mounted) return;
        setState(() {
          _currentTransferBytes = r;
          _progress = t == 0 ? null : r / t;
          _statusMessage =
              'Reading ${entry.name}  ${formatBytes(r)} / ${formatBytes(t)}';
        });
      });
      if (!mounted) return;
      _transferStartTime = null;
      _currentTransferBytes = 0;
      if (bytes == null) {
        setState(() {
          _errorMessage = 'Download failed';
          _progress = null;
        });
        return;
      }
      final savePath =
          await promptSaveFile(context, fileName: entry.name, bytes: bytes);
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
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Delete error: $e';
        _progress = null;
      });
    }
  }

  Future<void> _editFile(FsEntry entry, String path) async {
    if (_fs == null || !mounted) return;
    setState(() {
      _loadingPaths.add(path);
      _statusMessage = 'Opening ${entry.name}…';
      _progress = 0;
    });
    try {
      // Check cache first
      Uint8List? content = _editorCache.get(path);
      if (content != null) {
        final crc = await _fs!.getFileCrc32(path);
        if (crc != null && crc.found) {
          final valid = _editorCache.isValid(
            path,
            crc32: crc.crc32,
            size: crc.size,
          );
          if (valid != true) {
            content = null;
          }
        } else {
          content = null;
        }
      }

      setState(() {
        _loadingPaths.remove(path);
        _progress = null;
        _statusMessage = null;
      });

      final result = await FileEditorDialog.show(
        context,
        fs: _fs!,
        path: path,
        fileName: entry.name,
        cachedContent: content,
      );
      if (!mounted) return;
      if (result != null && result.saved && result.newContent != null) {
        final crc = await _fs!.getFileCrc32(path);
        if (crc != null && crc.found) {
          _editorCache.put(path, result.newContent!,
              crc32: crc.crc32, size: crc.size);
        } else {
          _editorCache.put(path, result.newContent!);
        }
        setState(() {
          _statusMessage = 'Saved ${entry.name}';
          _progress = null;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingPaths.remove(path);
        _errorMessage = 'Edit error: $e';
        _progress = null;
      });
    }
  }

  Future<void> _deleteSelected() async {
    if (_fs == null || _selectedPaths.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${_selectedPaths.length} items?'),
        content: const Text(
            'This will permanently delete the selected files and folders.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel')),
          FilledButton.tonal(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final paths = _selectedPaths.toList();
    int okCount = 0, failCount = 0;
    setState(() {
      _statusMessage = 'Deleting ${paths.length} items…';
      _progress = 0;
    });
    for (int i = 0; i < paths.length; i++) {
      final p = paths[i];
      try {
        final res = await _fs!.delete(p, recursive: true);
        if (res.success) {
          okCount++;
        } else {
          failCount++;
        }
      } catch (_) {
        failCount++;
      }
      if (mounted) setState(() => _progress = (i + 1) / paths.length);
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
          _statusMessage = null;
          _progress = null;
        });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Rename error: $e';
        _progress = null;
      });
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
          _statusMessage = null;
          _progress = null;
        });
      }
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Create error: $e';
        _progress = null;
      });
    }
  }

  void _selectAll() {
    setState(() {
      for (final e in _entries) {
        _selectedPaths.add(joinPath(_currentPath, e.name));
      }
    });
  }

  void _deselectAll() => setState(() => _selectedPaths.clear());
  void _exitMultiSelect() => setState(() {
        _isMultiSelect = false;
        _selectedPaths.clear();
      });

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
            ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'))
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 60,
              child: Text(k,
                  style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54), fontSize: 12))),
          Expanded(
              child: SelectableText(v,
                  style:
                      const TextStyle(fontFamily: 'monospace', fontSize: 12))),
        ]),
      );
}

enum _NewChoice { upload, mkdir }

// ── Firmware Tab Content ─────────────────────────────────────────────────────

