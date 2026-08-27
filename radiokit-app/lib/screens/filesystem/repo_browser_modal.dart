import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

import '../../models/fs_info.dart';
import '../../services/device_fs_service.dart';
import '../../services/repo_tree_service.dart';
import 'fs_helpers.dart';

/// Modal dialog window for browsing a remote Git repository/subfolder,
/// selecting files/directories, and batch-uploading them to the device LittleFS.
class RepoBrowserModal extends StatefulWidget {
  final String initialUrl;
  final String targetPath;
  final DeviceFsService fsService;
  final FsInfo? fsInfo;

  const RepoBrowserModal({
    super.key,
    required this.initialUrl,
    required this.targetPath,
    required this.fsService,
    this.fsInfo,
  });

  /// Helper to display the modal dialog window.
  static Future<bool?> show(
    BuildContext context, {
    required String initialUrl,
    required String targetPath,
    required DeviceFsService fsService,
    FsInfo? fsInfo,
  }) {
    final tokens = RKTheme.of(context);
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      useSafeArea: true,
      builder: (ctx) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: tokens.effectiveOutline),
        ),
        clipBehavior: Clip.antiAlias,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 800,
            maxHeight: MediaQuery.of(ctx).size.height * 0.85,
          ),
          child: RepoBrowserModal(
            initialUrl: initialUrl,
            targetPath: targetPath,
            fsService: fsService,
            fsInfo: fsInfo,
          ),
        ),
      ),
    );
  }

  @override
  State<RepoBrowserModal> createState() => _RepoBrowserModalState();
}

class _RepoBrowserModalState extends State<RepoBrowserModal> {
  late final TextEditingController _urlController;
  final RepoTreeService _repoService = RepoTreeService();

  bool _loading = false;
  String? _errorMessage;
  RepoUrlInfo? _currentInfo;
  List<RepoFileEntry> _entries = [];
  final Set<String> _selectedRelativePaths = {};
  final Set<String> _expandedDirs = {};

  // Uploading state
  bool _uploading = false;
  int _currentUploadIndex = 0;
  int _totalUploadCount = 0;
  double _currentFileProgress = 0.0;
  String _uploadStatus = '';
  final List<String> _failedFiles = [];

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(text: widget.initialUrl);
    if (widget.initialUrl.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchTree());
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _repoService.close();
    super.dispose();
  }

  Future<void> _fetchTree() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a GitHub repository URL.';
        _entries = [];
        _selectedRelativePaths.clear();
      });
      return;
    }

    final info = RepoTreeService.parseGithubUrl(url);
    if (info == null) {
      setState(() {
        _errorMessage = 'Invalid GitHub URL. Must be in format:\nhttps://github.com/owner/repo[/tree/branch/subfolder]';
        _entries = [];
        _selectedRelativePaths.clear();
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
      _currentInfo = info;
      _entries = [];
      _selectedRelativePaths.clear();
      _expandedDirs.clear();
    });

    try {
      final entries = await _repoService.fetchTree(info);
      setState(() {
        _entries = entries;
        _loading = false;
        // Tree collapsed by default
        _expandedDirs.clear();
        // No files selected at first
        _selectedRelativePaths.clear();
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load repository tree:\n$e';
        _loading = false;
      });
    }
  }

  List<RepoFileEntry> get _visibleEntries {
    if (_entries.isEmpty) return [];
    return _entries.where((entry) {
      final parts = entry.relativePath.split('/');
      if (parts.length <= 1) return true;
      String currentParent = '';
      for (int i = 0; i < parts.length - 1; i++) {
        currentParent = currentParent.isEmpty ? parts[i] : '$currentParent/${parts[i]}';
        if (!_expandedDirs.contains(currentParent)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  void _toggleDirExpanded(String dirPath) {
    setState(() {
      if (_expandedDirs.contains(dirPath)) {
        _expandedDirs.remove(dirPath);
      } else {
        _expandedDirs.add(dirPath);
      }
    });
  }

  int get _selectedTotalBytes {
    int total = 0;
    for (final e in _entries) {
      if (!e.isDirectory && _selectedRelativePaths.contains(e.relativePath)) {
        total += e.size;
      }
    }
    return total;
  }

  int get _selectedFileCount {
    int count = 0;
    for (final e in _entries) {
      if (!e.isDirectory && _selectedRelativePaths.contains(e.relativePath)) {
        count++;
      }
    }
    return count;
  }

  void _toggleFileSelection(String relPath) {
    if (_uploading) return;
    setState(() {
      if (_selectedRelativePaths.contains(relPath)) {
        _selectedRelativePaths.remove(relPath);
      } else {
        _selectedRelativePaths.add(relPath);
      }
    });
  }

  bool? _getDirectorySelectionState(String dirRelPath) {
    final prefix = dirRelPath.isEmpty ? '' : '$dirRelPath/';
    final filesInDir = _entries
        .where((e) => !e.isDirectory && e.relativePath.startsWith(prefix))
        .map((e) => e.relativePath)
        .toList();
    if (filesInDir.isEmpty) return false;
    final selectedCount =
        filesInDir.where((p) => _selectedRelativePaths.contains(p)).length;
    if (selectedCount == 0) return false;
    if (selectedCount == filesInDir.length) return true;
    return null;
  }

  void _toggleDirectorySelection(String dirRelPath) {
    if (_uploading) return;
    final prefix = dirRelPath.isEmpty ? '' : '$dirRelPath/';
    final filesInDir = _entries
        .where((e) => !e.isDirectory && e.relativePath.startsWith(prefix))
        .map((e) => e.relativePath)
        .toList();

    final allSelected = filesInDir.isNotEmpty &&
        filesInDir.every((p) => _selectedRelativePaths.contains(p));

    setState(() {
      if (allSelected) {
        for (final p in filesInDir) {
          _selectedRelativePaths.remove(p);
        }
      } else {
        for (final p in filesInDir) {
          _selectedRelativePaths.add(p);
        }
      }
    });
  }

  void _selectAll() {
    if (_uploading) return;
    setState(() {
      for (final e in _entries) {
        if (!e.isDirectory) {
          _selectedRelativePaths.add(e.relativePath);
        }
      }
    });
  }

  void _deselectAll() {
    if (_uploading) return;
    setState(() {
      _selectedRelativePaths.clear();
    });
  }

  Future<void> _startUpload() async {
    final selectedFiles = _entries
        .where((e) => !e.isDirectory && _selectedRelativePaths.contains(e.relativePath))
        .toList();

    if (selectedFiles.isEmpty) return;

    setState(() {
      _uploading = true;
      _currentUploadIndex = 0;
      _totalUploadCount = selectedFiles.length;
      _currentFileProgress = 0.0;
      _uploadStatus = 'Starting download...';
      _failedFiles.clear();
    });

    for (int i = 0; i < selectedFiles.length; i++) {
      final file = selectedFiles[i];
      final destPath = joinPath(widget.targetPath, file.relativePath);

      setState(() {
        _currentUploadIndex = i + 1;
        _currentFileProgress = 0.0;
        _uploadStatus = 'Downloading ${file.name} (${i + 1}/${selectedFiles.length})...';
      });

      Uint8List fileBytes;
      try {
        fileBytes = await _repoService.downloadFile(file.downloadUrl);
      } catch (e) {
        _failedFiles.add('${file.relativePath} (Download failed: $e)');
        continue;
      }

      setState(() {
        _uploadStatus = 'Uploading ${file.name} to $destPath...';
      });

      // Ensure intermediate parent directories exist on device LittleFS
      final parent = parentPath(destPath);
      if (parent != '/' && parent.isNotEmpty) {
        final segments = pathSegments(parent);
        String cur = '';
        for (final seg in segments) {
          cur = joinPath(cur.isEmpty ? '/' : cur, seg);
          await widget.fsService.mkdir(cur);
        }
      }

      try {
        final result = await widget.fsService.writeFileUpload(
          destPath,
          fileBytes,
          onProgress: (written, total) {
            if (mounted && total > 0) {
              setState(() {
                _currentFileProgress = written / total;
              });
            }
          },
        );

        if (!result.success) {
          _failedFiles.add(
              '${file.relativePath} (Upload error: ${result.errorName} ${result.message})');
        }
      } catch (e) {
        _failedFiles.add('${file.relativePath} (Upload failed: $e)');
      }
    }

    if (!mounted) return;

    if (_failedFiles.isEmpty) {
      // Success! Close modal and refresh parent
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _uploading = false;
        _errorMessage = 'Finished with ${_failedFiles.length} errors:\n' +
            _failedFiles.join('\n');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalBytes = _selectedTotalBytes;
    final fileCount = _selectedFileCount;

    return Material(
      color: tokens.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            decoration: BoxDecoration(
              color: tokens.base200,
              border: Border(bottom: BorderSide(color: tokens.effectiveOutline)),
            ),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.gitFork, color: tokens.primary, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'REMOTE BROWSER',
                    style: TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: tokens.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: _uploading ? null : () => Navigator.of(context).pop(false),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          // ── URL input bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    enabled: !_uploading,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: tokens.onSurface,
                    ),
                    decoration: InputDecoration(
                      labelText: 'GitHub Repository or Subfolder URL',
                      hintText: 'https://github.com/owner/repo/tree/main/subfolder',
                      hintStyle: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: tokens.onSurface.withValues(alpha: 0.4),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: tokens.effectiveOutline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(4),
                        borderSide: BorderSide(color: tokens.primary),
                      ),
                    ),
                    onSubmitted: (_) => _fetchTree(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: _uploading || _loading ? null : _fetchTree,
                  icon: _loading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 16),
                  label: const Text('Load'),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ],
            ),
          ),

          // ── Target Path & Storage Bar ────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: tokens.base200,
            child: Row(
              children: [
                Icon(PhosphorIconsFill.folder, size: 14, color: tokens.onSurface.withValues(alpha: 0.6)),
                const SizedBox(width: 6),
                Text(
                  'Destination: ${widget.targetPath}',
                  style: TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                    color: tokens.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const Spacer(),
                if (widget.fsInfo != null) ...[
                  Text(
                    'Free: ${formatBytes(widget.fsInfo!.totalBytes - widget.fsInfo!.usedBytes)}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      color: tokens.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Error Banner ─────────────────────────────────────────
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: tokens.error.withValues(alpha: 0.15),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: tokens.error, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: tokens.error, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),

          // ── Tree View / List ─────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _entries.isEmpty
                    ? Center(
                        child: Text(
                          _errorMessage == null ? 'Enter a repository URL and tap Load.' : '',
                          style: TextStyle(
                            fontSize: 12,
                            color: tokens.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : () {
                        final visible = _visibleEntries;
                        return ListView.builder(
                          itemCount: visible.length,
                          itemBuilder: (context, index) {
                            final entry = visible[index];
                            final isDir = entry.isDirectory;
                            final isExpanded = _expandedDirs.contains(entry.relativePath);
                            final depth = entry.relativePath.split('/').length - 1;
                            final isSelected = _selectedRelativePaths.contains(entry.relativePath);
                            final dirState = isDir
                                ? _getDirectorySelectionState(entry.relativePath)
                                : null;
                            final visual = fileVisual(entry.name, isDir: isDir);

                            return InkWell(
                              onTap: _uploading
                                  ? null
                                  : () {
                                      if (isDir) {
                                        _toggleDirExpanded(entry.relativePath);
                                      } else {
                                        _toggleFileSelection(entry.relativePath);
                                      }
                                    },
                              child: Padding(
                                padding: EdgeInsets.only(
                                  left: 8.0 + depth * 18.0,
                                  right: 16.0,
                                  top: 3.0,
                                  bottom: 3.0,
                                ),
                                child: Row(
                                  children: [
                                    if (isDir)
                                      SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: IconButton(
                                          padding: EdgeInsets.zero,
                                          iconSize: 18,
                                          icon: Icon(
                                            isExpanded
                                                ? Icons.expand_more_rounded
                                                : Icons.chevron_right_rounded,
                                            color: tokens.onSurface.withValues(alpha: 0.7),
                                          ),
                                          onPressed: () =>
                                              _toggleDirExpanded(entry.relativePath),
                                        ),
                                      )
                                    else
                                      const SizedBox(width: 24),
                                    SizedBox(
                                      width: 28,
                                      height: 28,
                                      child: Checkbox(
                                        visualDensity: VisualDensity.compact,
                                        tristate: isDir,
                                        value: isDir ? dirState : isSelected,
                                        onChanged: _uploading
                                            ? null
                                            : (val) {
                                                if (isDir) {
                                                  _toggleDirectorySelection(
                                                      entry.relativePath);
                                                } else {
                                                  _toggleFileSelection(
                                                      entry.relativePath);
                                                }
                                              },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      isDir
                                          ? (isExpanded
                                              ? PhosphorIconsFill.folderOpen
                                              : PhosphorIconsFill.folder)
                                          : visual.icon,
                                      color: isDir ? tokens.primary : visual.color,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        entry.name,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontFamily: 'monospace',
                                          fontWeight: isDir
                                              ? FontWeight.bold
                                              : FontWeight.normal,
                                          color: tokens.onSurface,
                                        ),
                                      ),
                                    ),
                                    if (!isDir)
                                      Text(
                                        formatBytes(entry.size),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                          color:
                                              tokens.onSurface.withValues(alpha: 0.5),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }(),
          ),

          // ── Bottom Action Bar / Upload Progress ──────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tokens.base300,
              border: Border(top: BorderSide(color: tokens.effectiveOutline)),
            ),
            child: _uploading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _uploadStatus,
                              style: TextStyle(
                                fontSize: 11,
                                fontFamily: 'monospace',
                                color: tokens.onSurface,
                              ),
                            ),
                          ),
                          Text(
                            '$_currentUploadIndex / $_totalUploadCount',
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              color: tokens.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: _currentFileProgress > 0 ? _currentFileProgress : null,
                        minHeight: 6,
                        backgroundColor: tokens.base200,
                        valueColor: AlwaysStoppedAnimation<Color>(tokens.primary),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      TextButton(
                        onPressed: _entries.isEmpty ? null : _selectAll,
                        child: const Text('Select All', style: TextStyle(fontSize: 11)),
                      ),
                      TextButton(
                        onPressed: _entries.isEmpty ? null : _deselectAll,
                        child: const Text('Clear', style: TextStyle(fontSize: 11)),
                      ),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: fileCount == 0 ? null : _startUpload,
                        icon: const Icon(Icons.cloud_upload_outlined, size: 16),
                        label: Text(
                          'Upload Selected ($fileCount · ${formatBytes(totalBytes)})',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
