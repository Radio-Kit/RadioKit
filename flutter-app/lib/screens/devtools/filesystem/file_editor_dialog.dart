import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../services/device_fs_service.dart';
import 'fs_helpers.dart';

/// Result from the file editor.
class FileEditResult {
  final bool saved;
  final Uint8List? newContent;
  final String path;

  const FileEditResult({
    required this.saved,
    this.newContent,
    required this.path,
  });
}

/// Full-screen overlay dialog for editing text/code files on the device.
///
/// Features:
/// - Top bar with back button, file name, and save button
/// - Monospace text editor with basic undo support
/// - File size warning for large files (>500 KB)
/// - Save via DeviceFsService (uses REPLACE for small files, fallback to upload)
/// - Loading spinner while file is being fetched
class FileEditorDialog extends StatefulWidget {
  final DeviceFsService fs;
  final String path;
  final String fileName;
  final Uint8List? initialContent;

  const FileEditorDialog({
    super.key,
    required this.fs,
    required this.path,
    required this.fileName,
    this.initialContent,
  });

  /// Show the editor as a full-screen dialog overlay.
  /// [cachedContent] is optional — if provided, it skips the fetch.
  /// Returns a [FileEditResult] describing the outcome.
  static Future<FileEditResult?> show(
    BuildContext context, {
    required DeviceFsService fs,
    required String path,
    required String fileName,
    Uint8List? cachedContent,
  }) {
    return showDialog<FileEditResult>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black,
      useSafeArea: true,
      builder: (_) => FileEditorDialog(
        fs: fs,
        path: path,
        fileName: fileName,
        initialContent: cachedContent,
      ),
    );
  }

  @override
  State<FileEditorDialog> createState() => _FileEditorDialogState();
}

class _FileEditorDialogState extends State<FileEditorDialog> {
  late TextEditingController _controller;
  bool _loading = true;
  bool _saving = false;
  bool _contentChanged = false;
  String? _error;
  Uint8List? _originalBytes;

  // Undo stack
  final List<String> _undoStack = [];
  int _undoIndex = -1;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    if (widget.initialContent != null) {
      _loadContent(widget.initialContent!);
    } else {
      _fetchFile();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _loadContent(Uint8List bytes) {
    _originalBytes = Uint8List.fromList(bytes);
    final text = utf8DecodeWithFallback(bytes);
    _controller.text = text;
    _controller.selection = TextSelection.collapsed(offset: text.length);
    _controller.addListener(_onTextChanged);
    setState(() {
      _loading = false;
      _contentChanged = false;
    });
  }

  Future<void> _fetchFile() async {
    setState(() => _loading = true);
    try {
      final bytes = await widget.fs.readFile(widget.path);
      if (!mounted) return;
      if (bytes == null) {
        setState(() {
          _loading = false;
          _error = 'Failed to read file from device';
        });
        return;
      }
      _loadContent(bytes);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Error reading file: $e';
      });
    }
  }

  void _onTextChanged() {
    final changed = _controller.text != _utf8Decode(_originalBytes);
    if (changed != _contentChanged) {
      setState(() => _contentChanged = changed);
    }
  }

  String _utf8Decode(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return '';
    try {
      return utf8DecodeWithFallback(bytes);
    } catch (_) {
      return String.fromCharCodes(bytes);
    }
  }

  Future<void> _save() async {
    if (_saving || !_contentChanged) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final text = _controller.text;
      final bytes = Uint8List.fromList(utf8.encode(text));

      final result = await widget.fs.replaceFile(widget.path, bytes);
      if (!mounted) return;

      if (result.success) {
        _originalBytes = Uint8List.fromList(bytes);
        setState(() {
          _saving = false;
          _contentChanged = false;
        });
        Navigator.of(context).pop(FileEditResult(
          saved: true,
          newContent: bytes,
          path: widget.path,
        ));
      } else {
        setState(() {
          _saving = false;
          _error = 'Save failed: ${result.errorName}';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Save error: $e';
      });
    }
  }

  void _saveUndoPoint() {
    if (_undoIndex < 0 || _controller.text != _undoStack[_undoIndex]) {
      // Truncate redo history
      _undoStack.removeRange(_undoIndex + 1, _undoStack.length);
      _undoStack.add(_controller.text);
      _undoIndex = _undoStack.length - 1;
    }
  }

  // Uses utf8DecodeWithFallback from fs_helpers.dart

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isLargeFile = _originalBytes != null && _originalBytes!.length > 500 * 1024;

    return Material(
      color: const Color(0xFF121212),
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: const BoxDecoration(
                color: Color(0xFF1E1E1E),
                border: Border(
                  bottom: BorderSide(color: Color(0xFF333333)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    color: Colors.white70,
                    onPressed: () => _onBack(context),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jetBrainsMono(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_contentChanged)
                          Text(
                            'Unsaved changes',
                            style: TextStyle(
                              color: Colors.orangeAccent.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (_contentChanged)
                    TextButton.icon(
                      icon: const Icon(Icons.undo_rounded, size: 16),
                      label: const Text('Undo'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white54,
                        textStyle: const TextStyle(fontSize: 11),
                      ),
                      onPressed: _undoIndex > 0
                          ? () {
                              _undoIndex--;
                              _controller.text = _undoStack[_undoIndex];
                              _controller.selection = TextSelection.fromPosition(
                                TextPosition(offset: _controller.text.length),
                              );
                            }
                          : null,
                    ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: _saving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(
                      _saving ? 'SAVING' : 'SAVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _contentChanged ? Colors.black : Colors.black38,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _contentChanged
                          ? scheme.primary
                          : Colors.white12,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                    ),
                    onPressed: _contentChanged && !_saving ? _save : null,
                  ),
                ],
              ),
            ),

            // ── Editor body ───────────────────────────────────────
            Expanded(
              child: _loading
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Reading file…',
                            style: TextStyle(color: Colors.white54),
                          ),
                        ],
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.error_outline_rounded,
                                    size: 48,
                                    color: Colors.redAccent.withValues(alpha: 0.7)),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.redAccent, fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                FilledButton.tonal(
                                  onPressed: _fetchFile,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          children: [
                            if (isLargeFile)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 6),
                                color: Colors.orangeAccent.withValues(alpha: 0.1),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 14,
                                        color: Colors.orangeAccent),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Large file — editing may be slow',
                                        style: TextStyle(
                                          color: Colors.orangeAccent,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                maxLines: null,
                                expands: true,
                                textAlignVertical: TextAlignVertical.top,
                                style: GoogleFonts.jetBrainsMono(
                                  color: const Color(0xFFD4D4D4),
                                  fontSize: 13,
                                  height: 1.5,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.all(16),
                                  isDense: true,
                                ),
                                keyboardType: TextInputType.multiline,
                                onTap: _saveUndoPoint,
                                onEditingComplete: _saveUndoPoint,
                              ),
                            ),
                            // Bottom info bar
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF1E1E1E),
                                border: Border(
                                  top: BorderSide(color: Color(0xFF333333)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.code_rounded,
                                      size: 12, color: Colors.white38),
                                  const SizedBox(width: 6),
                                  Text(
                                    'UTF-8',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_controller.text.length} chars',
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures()
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Text(
                                    formatBytes(_originalBytes?.length ?? 0),
                                    style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
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

  void _onBack(BuildContext context) {
    if (_contentChanged) {
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: const Text('Discard changes?',
              style: TextStyle(color: Colors.white)),
          content: const Text(
            'You have unsaved changes. Discard them?',
            style: TextStyle(color: Colors.white54),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCEL',
                  style: TextStyle(color: Colors.white54)),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent.withValues(alpha: 0.2),
                foregroundColor: Colors.redAccent,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('DISCARD'),
            ),
          ],
        ),
      ).then((discard) {
        if (discard == true) {
          Navigator.of(context).pop(FileEditResult(
            saved: false,
            path: widget.path,
          ));
        }
      });
    } else {
      Navigator.of(context).pop(FileEditResult(
        saved: false,
        path: widget.path,
      ));
    }
  }
}
