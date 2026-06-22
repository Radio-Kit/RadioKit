import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/bash.dart' show langBash;
import 'package:re_highlight/languages/cpp.dart' show langCpp;
import 'package:re_highlight/languages/css.dart' show langCss;
import 'package:re_highlight/languages/dart.dart' show langDart;
import 'package:re_highlight/languages/go.dart' show langGo;
import 'package:re_highlight/languages/ini.dart' show langIni;
import 'package:re_highlight/languages/javascript.dart' show langJavascript;
import 'package:re_highlight/languages/json.dart' show langJson;
import 'package:re_highlight/languages/markdown.dart' show langMarkdown;
import 'package:re_highlight/languages/plaintext.dart' show langPlaintext;
import 'package:re_highlight/languages/python.dart' show langPython;
import 'package:re_highlight/languages/rust.dart' show langRust;
import 'package:re_highlight/languages/xml.dart' show langXml;
import 'package:re_highlight/languages/yaml.dart' show langYaml;
import 'package:re_highlight/re_highlight.dart' show Mode;
import 'package:re_highlight/styles/atom-one-dark.dart' show atomOneDarkTheme;

import '../../../services/device_fs_service.dart';
import '../../theme/app_theme.dart';
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

/// Maps a file extension to a re_highlight language name for syntax coloring.
String _languageForFile(String fileName) {
  final ext = fileName.split('.').last.toLowerCase();
  switch (ext) {
    case 'json':
      return 'json';
    case 'c':
    case 'h':
    case 'cpp':
    case 'hpp':
    case 'cxx':
    case 'hxx':
    case 'cc':
    case 'hh':
    case 'ino':
    case 'arduino':
      return 'cpp';
    case 'py':
      return 'python';
    case 'dart':
      return 'dart';
    case 'yaml':
    case 'yml':
      return 'yaml';
    case 'xml':
    case 'html':
    case 'htm':
      return 'xml';
    case 'md':
    case 'markdown':
      return 'markdown';
    case 'sh':
    case 'bash':
    case 'zsh':
      return 'bash';
    case 'toml':
      return 'toml';
    case 'go':
      return 'go';
    case 'rs':
      return 'rust';
    case 'js':
    case 'jsx':
    case 'ts':
    case 'tsx':
      return 'javascript';
    case 'css':
    case 'scss':
    case 'less':
      return 'css';
    case 'ini':
    case 'cfg':
      return 'ini';
    case 'txt':
    default:
      return 'plaintext';
  }
}

/// Full-screen overlay dialog for editing text/code files on the device.
///
/// Features:
/// - Top bar with back button, file name, and save button
/// - re_editor [CodeEditor] with syntax highlighting based on file extension
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
      barrierColor: context.tokens.base300,
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
  CodeLineEditingController? _controller;
  bool _loading = true;
  bool _saving = false;
  bool _contentChanged = false;
  String? _error;
  Uint8List? _originalBytes;

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      _loadContent(widget.initialContent!);
    } else {
      _fetchFile();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _loadContent(Uint8List bytes) {
    _originalBytes = Uint8List.fromList(bytes);
    final text = utf8DecodeWithFallback(bytes);
    _controller?.dispose();
    _controller = CodeLineEditingController.fromText(text)
      ..addListener(_onTextChanged);
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
    final currentText = _controller?.text;
    if (currentText == null) return;
    final changed = currentText != _utf8Decode(_originalBytes);
    if (changed != _contentChanged) {
      _contentChanged = changed;
    }
    // Also rebuild for undo/redo button state changes
    setState(() {});
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
    final content = _controller?.text;
    if (content == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final bytes = Uint8List.fromList(utf8.encode(content));

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

  @override
  Widget build(BuildContext context) {
    final isLargeFile =
        _originalBytes != null && _originalBytes!.length > 500 * 1024;
    final lang = _languageForFile(widget.fileName);

    return Material(
      color: context.tokens.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── Top bar ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: context.tokens.base300,
                border: Border(
                  bottom: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.2)),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    tooltip: 'Back',
                    color: context.tokens.onSurface.withValues(alpha: 0.7),
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
                          style: GoogleFonts.martianMono(
                            color: context.tokens.onSurface,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_contentChanged)
                          Text(
                            'Unsaved changes',
                            style: TextStyle(
                              color: context.tokens.warning.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Undo / Redo buttons
                  ListenableBuilder(
                    listenable: _controller ?? ChangeNotifier(),
                    builder: (context, _) {
                      final canUndo = _controller?.canUndo ?? false;
                      final canRedo = _controller?.canRedo ?? false;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.undo_rounded,
                              size: 18,
                              color: canUndo ? context.tokens.onSurface.withValues(alpha: 0.7) : context.tokens.onSurface.withValues(alpha: 0.24),
                            ),
                            tooltip: 'Undo',
                            onPressed: canUndo
                                ? () {
                                    _controller!.undo();
                                  }
                                : null,
                            style: IconButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(6),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.redo_rounded,
                              size: 18,
                              color: canRedo ? context.tokens.onSurface.withValues(alpha: 0.7) : context.tokens.onSurface.withValues(alpha: 0.24),
                            ),
                            tooltip: 'Redo',
                            onPressed: canRedo
                                ? () {
                                    _controller!.redo();
                                  }
                                : null,
                            style: IconButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.all(6),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: _saving
                        ? SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: context.tokens.onPrimary),
                          )
                        : const Icon(Icons.save_rounded, size: 16),
                    label: Text(
                      _saving ? 'SAVING' : 'SAVE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: _contentChanged ? context.tokens.onPrimary : context.tokens.onPrimary.withValues(alpha: 0.38),
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: _contentChanged
                          ? context.tokens.primary
                          : context.tokens.onSurface.withValues(alpha: 0.12),
                      foregroundColor: context.tokens.onPrimary,
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Reading file…',
                            style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54)),
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
                                    color: context.tokens.error
                                        .withValues(alpha: 0.7)),
                                const SizedBox(height: 12),
                                Text(
                                  _error!,
                                  textAlign: TextAlign.center,
                                  style:                                  TextStyle(
                                      color: context.tokens.error, fontSize: 13),
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
                                color: context.tokens.warning
                                    .withValues(alpha: 0.1),
                                child: Row(
                                  children: [
                                    Icon(Icons.warning_amber_rounded,
                                        size: 14,
                                        color: context.tokens.warning),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Large file — editing may be slow',
                                        style: TextStyle(
                                          color: context.tokens.warning,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            Expanded(
                              child: CodeEditor(
                                controller: _controller!,
                                readOnly: false,
                                style: CodeEditorStyle(
                                  fontSize: 13,
                                  fontHeight: 1.5,
                                  codeTheme: CodeHighlightTheme(
                                    languages: {
                                      if (lang != 'plaintext')
                                        lang: CodeHighlightThemeMode(
                                          mode: _highlightModeForLang(lang),
                                        ),
                                    },
                                    theme: _codeHighlightTheme(),
                                  ),
                                ),
                                indicatorBuilder: (context, editingController,
                                    chunkController, notifier) {
                                  return Row(
                                    children: [
                                      DefaultCodeLineNumber(
                                        controller: editingController,
                                        notifier: notifier,
                                        textStyle: TextStyle(
                                          color: context.tokens.onSurface.withValues(alpha: 0.38),
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      DefaultCodeChunkIndicator(
                                        width: 20,
                                        controller: chunkController,
                                        notifier: notifier,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            // Bottom info bar
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(
                                color: context.tokens.base300,
                                border: Border(
                                  top: BorderSide(color: context.tokens.onSurface.withValues(alpha: 0.2)),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.code_rounded,
                                      size: 12, color: context.tokens.onSurface.withValues(alpha: 0.38)),
                                  const SizedBox(width: 6),
                                  Text(
                                    lang.toUpperCase(),
                                    style: TextStyle(
                                      color: context.tokens.onSurface.withValues(alpha: 0.38),
                                      fontSize: 11,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${_controller?.text.length ?? 0} chars',
                                    style: TextStyle(
                                      color: context.tokens.onSurface.withValues(alpha: 0.38),
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
                                      color: context.tokens.onSurface.withValues(alpha: 0.38),
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
          backgroundColor: context.tokens.surface,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          title: Text('Discard changes?',
              style: TextStyle(color: context.tokens.onSurface)),
          content: Text(
            'You have unsaved changes. Discard them?',
            style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('CANCEL',
                  style: TextStyle(color: context.tokens.onSurface.withValues(alpha: 0.54))),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: context.tokens.error.withValues(alpha: 0.2),
                foregroundColor: context.tokens.error,
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

// ── Re-highlight helpers ──────────────────────────────────────────────────

/// Map a language name string (from [_languageForFile]) to a [Mode] object.
Mode _highlightModeForLang(String lang) {
  switch (lang) {
    case 'json':
      return langJson;
    case 'cpp':
      return langCpp;
    case 'python':
      return langPython;
    case 'dart':
      return langDart;
    case 'yaml':
      return langYaml;
    case 'xml':
      return langXml;
    case 'markdown':
      return langMarkdown;
    case 'bash':
      return langBash;
    case 'go':
      return langGo;
    case 'rust':
      return langRust;
    case 'javascript':
      return langJavascript;
    case 'css':
      return langCss;
    case 'ini':
      return langIni;
    case 'plaintext':
    default:
      return langPlaintext;
  }
}

/// Returns the Atom One Dark theme map for re_highlight.
Map<String, TextStyle> _codeHighlightTheme() {
  return atomOneDarkTheme;
}
