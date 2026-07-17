import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/languages/json.dart' show langJson;
import 'package:re_highlight/languages/cpp.dart' show langCpp;
import 'package:re_highlight/styles/atom-one-dark.dart' show atomOneDarkTheme;
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'utils/file_download.dart';
import 'widgets/designer_widget_dialog.dart';
import '../../widgets/themed_bottom_sheet.dart';
import 'widgets/designer_inspector.dart';
import 'widgets/designer_page_bar.dart';

import '../../providers/designs_provider.dart';
import 'codegen/json_arduino_generator.dart';

class DesignerScreen extends StatefulWidget {
  final String? designId;
  final String? templateJson;
  final String? templateName;
  const DesignerScreen({super.key, this.designId, this.templateJson, this.templateName});

  @override
  State<DesignerScreen> createState() => _DesignerScreenState();
}

class _DesignerScreenState extends State<DesignerScreen> {
  final DesignerState _state = DesignerState();
  String? _currentDesignId;
  bool _hasUnsavedChanges = false;
  bool _isInitializing = false;
  bool _isFileMode = false;
  int _lastMutationCount = 0;

  bool get _isJsonMode => _isFileMode && _state.originalHeaderPath != null && _state.originalHeaderPath!.endsWith('.json');

  static const _appVersion = '1.0.0';

  @override
  void initState() {
    super.initState();
    _currentDesignId = widget.designId;
    _state.addListener(_onStateChanged);
    _state.setAppData(appVersion: _appVersion);
    RKDebugOverlay.enabled = !_state.isPlayMode;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialDesign();
    });
  }

  void _loadInitialDesign() {
    _isInitializing = true;

    // Template from starter section — loaded via route extra, not provider.
    if (widget.templateJson != null) {
      try {
        final json = jsonDecode(widget.templateJson!);
        _state.loadFromJson(json);
      } catch (e) {
        debugPrint('Failed to load template: $e');
      }
      _currentDesignId ??= DateTime.now().millisecondsSinceEpoch.toString();
    } else if (widget.designId != null) {
      final provider = context.read<DesignsProvider>();
      final existing = provider.designs
          .where((d) => d.id == widget.designId).firstOrNull;
      if (existing != null) {
        if (existing.filePath != null) {
          try {
            _isFileMode = true;
            if (existing.filePath!.endsWith('.json')) {
              _state.loadJsonFromPath(existing.filePath!);
            } else {
              _state.loadFromHeaderFile(existing.filePath!);
            }
          } catch (e) {
            debugPrint('Failed to load file design: $e');
            _state.setModelName('Project-${math.Random().nextInt(10000)}');
          }
        } else if (existing.jsonContent != null) {
          try {
            final json = jsonDecode(existing.jsonContent!);
            _state.loadFromJson(json);
          } catch (e) {
            debugPrint('Failed to load design: $e');
            _state.setModelName('Project-${math.Random().nextInt(10000)}');
          }
        } else {
          _state.setModelName('Project-${math.Random().nextInt(10000)}');
        }
      } else {
        _state.setModelName('Project-${math.Random().nextInt(10000)}');
      }
    } else {
      _state.setModelName('Project-${math.Random().nextInt(10000)}');
    }

    // Apply template name if provided.
    if (widget.templateName != null && widget.templateName!.isNotEmpty) {
      _state.setModelName(widget.templateName!);
    }

    _isInitializing = false;
    _hasUnsavedChanges = false;
    _lastMutationCount = _state.mutationCount;
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();
    RKDebugOverlay.enabled = false;
    super.dispose();
  }

  void _onStateChanged() {
    RKDebugOverlay.enabled = !_state.isPlayMode;
    if (!_isInitializing && !_state.isPlayMode) {
      final currentCount = _state.mutationCount;
      if (currentCount != _lastMutationCount) {
        _lastMutationCount = currentCount;
        _hasUnsavedChanges = true;
      }
    }
    setState(() {});
  }

  Future<void> _autoSaveToApp() async {
    if (!mounted) return;
    final provider = context.read<DesignsProvider>();
    final jsonContent = jsonEncode(_state.toJson());
    final name =
        _state.modelName.isNotEmpty ? _state.modelName : 'Untitled Design';

    _currentDesignId ??= DateTime.now().millisecondsSinceEpoch.toString();

    await provider.saveDesign(_currentDesignId!, name, jsonContent);
    if (mounted) setState(() => _hasUnsavedChanges = false);
  }

  String _saveContent(String filePath) {
    _state.setAppData(lastEdit: DateTime.now().millisecondsSinceEpoch);
    return filePath.endsWith('.json')
        ? _buildJsonContent()
        : _buildFullHeader();
  }

  Future<void> _autoSaveToFile() async {
    if (!mounted) return;
    final filePath = _state.originalHeaderPath;
    if (filePath == null) return;

    final content = _saveContent(filePath);
    await File(filePath).writeAsString(content);

    // Update the provider entry with fresh timestamp
    _currentDesignId ??= DateTime.now().millisecondsSinceEpoch.toString();
    final provider = context.read<DesignsProvider>();
    final name =
        _state.modelName.isNotEmpty ? _state.modelName : 'Untitled Design';
    await provider.saveDesign(
      _currentDesignId!, name, null,
      filePath: filePath,
      lastEdit: _state.lastEdit ?? DateTime.now().millisecondsSinceEpoch,
      appVersion: _state.appVersion,
    );
    if (mounted) setState(() => _hasUnsavedChanges = false);
  }

  Future<void> _saveAs() async {
    final ext = _isJsonMode ? 'json' : 'h';
    final content = _saveContent('');
    final bytes = Uint8List.fromList(utf8.encode(content));
    final path = await FilePicker.saveFile(
      fileName: 'RadioKit_UI.$ext',
      allowedExtensions: [ext],
      type: FileType.custom,
      bytes: bytes,
    );
    if (path == null || !mounted) return;

    await File(path).writeAsString(content);

    // Create a new provider entry with the new file path
    final provider = context.read<DesignsProvider>();
    final name =
        _state.modelName.isNotEmpty ? _state.modelName : 'Untitled Design';
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    await provider.saveDesign(
      id, name, null,
      filePath: path,
      lastEdit: _state.lastEdit ?? DateTime.now().millisecondsSinceEpoch,
      appVersion: _state.appVersion,
    );

    _currentDesignId = id;
    _isFileMode = true;
    if (mounted) setState(() => _hasUnsavedChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved as ${path.split('/').last}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(tokens),
          if (!_state.isPlayMode)
            DesignerPageBar(state: _state),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _buildCanvasWithSkin(),
                      // Restore page bar button (when hidden)
                      if (!_state.isPlayMode && !_state.showPageBar)
                        Positioned(
                          top: 8,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: GestureDetector(
                              onTap: () => _state.togglePageBar(),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tokens.base300,
                                  border: Border.all(
                                    color: tokens.effectiveOutline,
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  LucideIcons.panelTopClose,
                                  size: 14,
                                  color: tokens.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      if (!_state.isPlayMode)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: FloatingActionButton(
                            onPressed: () {
                              showThemedBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                showDragHandle: true,
                                backgroundColor: tokens.surface,
                                shape: const RoundedRectangleBorder(
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                ),
                                builder: (context) =>
                                    DesignerWidgetSheet(state: _state),
                              );
                            },
                            backgroundColor: tokens.primary,
                            foregroundColor: tokens.onPrimary,
                            child: Icon(LucideIcons.plus),
                          ),
                        ),
                      if (!_state.isPlayMode)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton(
                            onPressed: () => _showSourceCode(context, tokens),
                            backgroundColor: tokens.base200,
                            foregroundColor: tokens.onSurface.withValues(alpha: 0.7),
                            child: Icon(LucideIcons.code),
                          ),
                        ),
                    ],
                  ),
                ),
                if (!_state.isPlayMode && _state.isInspectorVisible)
                  ListenableBuilder(
                    listenable: _state,
                    builder: (context, _) => DesignerInspector(state: _state),
                  ),
                if (!_state.isPlayMode && !_state.isInspectorVisible)
                  _buildEdgeTabBar(tokens),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(RKTokens tokens) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.fromLTRB(24, topPad, 24, 0),
      decoration: BoxDecoration(
        color: tokens.base300,
        border: Border(bottom: BorderSide(color: tokens.effectiveOutline, width: 1)),
      ),
      child: SizedBox(
        height: 56,
        child: Row(
          children: [
            IconButton(
              icon:
                  Icon(LucideIcons.arrowLeft, color: tokens.primary, size: 20),
              onPressed: () => _handleBack(context),
            ),
            SizedBox(width: 8),
            ListenableBuilder(
              listenable: _state,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _state.modelName.isNotEmpty
                        ? _state.modelName
                        : 'Untitled Project',
                    style: TextStyle(
                      color: tokens.primary,
                      fontSize: 18,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  if (_isFileMode && _state.originalHeaderPath != null) ...[
                    SizedBox(width: 8),
                    Text(
                      '(${_state.originalHeaderPath!.split('/').last})',
                      style: TextStyle(
                        color: tokens.onSurface.withValues(alpha: 0.4),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                  SizedBox(width: 8),
                  IconButton(
                    icon: Icon(LucideIcons.pencil,
                        size: 16, color: tokens.primary),
                    onPressed: () => _editProjectName(context),
                    tooltip: 'Edit Project Name',
                  ),
                ],
              ),
            ),
            Spacer(),
            _buildPlayModeButton(tokens),
            SizedBox(width: 12),
            _buildUndoRedoButtons(tokens),
            SizedBox(width: 8),
            if (_isFileMode) _buildSaveAsButton(tokens),
            if (_isFileMode) SizedBox(width: 4),
            _buildSaveButton(tokens),
          ],
        ),
      ),
    );
  }

  Future<void> _editProjectName(BuildContext context) async {
    final tokens = RKTheme.of(context);
    final controller = TextEditingController(text: _state.modelName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.base300,
        title: Text(
          'Edit Project Name',
          style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.88), fontFamily: 'monospace'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.88), fontFamily: 'monospace'),
          decoration: InputDecoration(
            hintText: 'Project Name',
            hintStyle: TextStyle(color: tokens.onSurface.withValues(alpha: 0.53)),                enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: tokens.effectiveOutline)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: tokens.primary.withValues(alpha: 0.6))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL',
                style: TextStyle(
                    color: tokens.onSurface.withValues(alpha: 0.67), fontFamily: 'monospace')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text('SAVE',
                style: TextStyle(
                    color: tokens.primary.withValues(alpha: 0.6),
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      _state.setModelName(newName.trim());
      if (_isFileMode) {
        _autoSaveToFile();
      } else {
        _autoSaveToApp();
      }
    }
  }

  Widget _buildUndoRedoButtons(RKTokens tokens) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _IconButton(
              icon: LucideIcons.undo,
              onPressed: _state.canUndo ? () => _state.undo() : null,
              tokens: tokens,
            ),
            SizedBox(width: 4),
            _IconButton(
              icon: LucideIcons.redo,
              onPressed: _state.canRedo ? () => _state.redo() : null,
              tokens: tokens,
            ),
          ],
        );
      },
    );
  }

  Widget _buildSaveButton(RKTokens tokens) {
    if (!_hasUnsavedChanges) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () async {
        if (_isFileMode) {
          await _autoSaveToFile();
        } else {
          await _autoSaveToApp();
        }
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: SelectableText('Design saved')),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(
              color: tokens.primary.withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.save, color: tokens.primary, size: 14),
            SizedBox(width: 6),
            Text(
              'SAVE',
              style: TextStyle(
                color: tokens.primary,
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveAsButton(RKTokens tokens) {
    return GestureDetector(
      onTap: () async {
        await _saveAs();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: tokens.surface,
          border: Border.all(color: tokens.effectiveOutline, width: 1),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.save, color: tokens.onSurface.withValues(alpha: 0.54), size: 14),
            SizedBox(width: 6),
            Text(
              'SAVE AS',
              style: TextStyle(
                color: tokens.onSurface.withValues(alpha: 0.54),
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEdgeTabBar(RKTokens tokens) {
    return GestureDetector(
      onTap: () => _state.setInspectorVisible(true),
      child: Container(
        width: 32,
        decoration: BoxDecoration(
          color: tokens.base300,
          border: Border(
            left: BorderSide(color: tokens.effectiveOutline, width: 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.chevronLeft, color: tokens.primary, size: 18),
            SizedBox(height: 4),
            RotatedBox(
              quarterTurns: 3,
              child: Text(
                'INSPECTOR',
                style: TextStyle(
                  color: tokens.onSurface.withValues(alpha: 0.53),
                  fontSize: 9,
                  fontFamily: 'monospace',
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayModeButton(RKTokens tokens) {
    return ListenableBuilder(
      listenable: _state,
      builder: (context, _) {
        final isPlay = _state.isPlayMode;
        return GestureDetector(
          onTap: () => _state.togglePlayMode(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isPlay ? tokens.success.withValues(alpha: 0.15) : tokens.surface,
              border: Border.all(
                color:
                    isPlay ? tokens.success : tokens.effectiveOutline,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlay ? LucideIcons.square : LucideIcons.play,
                  color: isPlay ? tokens.success : tokens.primary,
                  size: 14,
                ),
                SizedBox(width: 6),
                Text(
                  isPlay ? 'DONE' : 'TEST',
                  style: TextStyle(
                    color: isPlay ? tokens.success : tokens.primary,
                    fontSize: 11,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Canvas with skin theming ──────────────────────────────────────────────

  Widget _buildCanvasWithSkin() {
    final skinTokens = _state.activeSkin == 'default'
        ? null
        : RKTokens.presetsByName[_state.activeSkin];
    Widget canvas = DesignerCanvas(state: _state);
    if (skinTokens != null) {
      canvas = RKTheme(tokens: skinTokens, child: canvas);
    }
    return canvas;
  }

  // ── Back navigation ───────────────────────────────────────────────────────

  Future<void> _handleBack(BuildContext context) async {
    // Capture navigator references before any async gaps for safe use later.
    final tokens = RKTheme.of(context);
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final canPop = context.canPop();

    // Navigate immediately when there is nothing unsaved.
    if (!_hasUnsavedChanges) {
      if (canPop) {
        context.pop();
      } else {
        context.go('/designs');
      }
      return;
    }

    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tokens.base300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: Text(
          'Unsaved Changes',
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.88),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          _isFileMode
              ? 'Save changes to ${_state.originalHeaderPath?.split('/').last ?? 'RadioKit_UI.h'}?'
              : 'Do you want to save your changes before leaving?',
          style: TextStyle(color: tokens.onSurface.withValues(alpha: 0.67), fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: Text(
              'DISCARD',
              style: TextStyle(
                color: tokens.error,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: Text(
              'SAVE',
              style: TextStyle(
                color: tokens.primary.withValues(alpha: 0.6),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (result == 'save') {
      if (_isFileMode) {
        await _autoSaveToFile();
      } else {
        await _autoSaveToApp();
      }
      if (!mounted) return;
    }
    // Both 'save' and 'discard' navigate back; null (dismissed) stays.
    if (result != null) {
      if (canPop) {
        navigator.pop();
      } else {
        router.go('/designs');
      }
    }
  }

  // ── Read-only code editor widget ──────────────────────────────────────

  /// Builds a read-only [CodeEditor] showing [text] highlighted with the given
  /// re_highlight [language] mode.
  Widget _buildCodeEditor(String text, String language) {
    return CodeEditor(
      controller: CodeLineEditingController.fromText(text),
      readOnly: true,
      style: CodeEditorStyle(
        fontSize: 12,
        fontHeight: 1.5,
        codeTheme: CodeHighlightTheme(
          languages: {
            language: CodeHighlightThemeMode(
              mode: language == 'json' ? langJson : langCpp,
            ),
          },
          theme: atomOneDarkTheme,
        ),
      ),
      indicatorBuilder: (context, editingController,
          chunkController, notifier) {
        final editorTokens = RKTheme.of(context);
        return Row(
          children: [
            DefaultCodeLineNumber(
              controller: editingController,
              notifier: notifier,
              textStyle: TextStyle(
                color: editorTokens.onSurface.withValues(alpha: 0.33),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
            SizedBox(width: 4),
            Container(width: 1, color: editorTokens.base200),
            SizedBox(width: 4),
          ],
        );
      },
    );
  }

  /// Collapses simple scalar arrays (no nested objects/arrays) from multi-line
  /// to single-line. E.g.
  /// ```
  ///   "position": [
  ///     93,
  ///     12,
  ///     0
  ///   ]
  /// ```
  /// becomes:
  /// ```
  ///   "position": [93, 12, 0]
  /// ```
  static String _inlineSimpleArrays(String json) {
    return json.replaceAllMapped(
      RegExp(r'\[\s*\n((?:\s*[^\[\]\{\}]+,\s*\n)+)\s*\]'),
      (m) {
        final inner = m.group(1)!;
        final parts =
            inner.split(RegExp(r',\s*\n\s*')).map((s) => s.trim()).join(', ');
        return '[$parts]';
      },
    );
  }

  /// Transforms JSON for code viewer display:
  /// - Keeps `name` as-is to show the C++ identifier name
  /// - Replaces `label` object {text, show} with a compact `show`/`hide` string
  String _transformJsonForDisplay(String rawJson) {
    final data = jsonDecode(rawJson);
    if (data is! Map<String, dynamic>) return rawJson;

    // Handle both v1 (flat widgets) and v2 (pages[].widgets) formats
    void transformWidgets(List widgets) {
      for (final w in widgets) {
        if (w is! Map<String, dynamic>) continue;
        // Replace 'label': { text, show } object with just the show/hide string
        final labelObj = w['label'];
        if (labelObj is Map) {
          final show = (labelObj['show'] as bool?) ?? true;
          w['label'] = show ? 'show' : 'hide';
        }
      }
    }

    // v1: flat widgets array
    final widgets = data['widgets'];
    if (widgets is List) {
      transformWidgets(widgets);
    }

    // v2: pages[].widgets
    final pages = data['pages'];
    if (pages is List) {
      for (final page in pages) {
        if (page is Map<String, dynamic>) {
          final pageWidgets = page['widgets'];
          if (pageWidgets is List) {
            transformWidgets(pageWidgets);
          }
        }
      }
    }

    final json = const JsonEncoder.withIndent('  ').convert(data);
    return _inlineSimpleArrays(json);
  }

  // ── Arduino .h file generator ──────────────────────────────────────────

  /// Generates the complete `RadioKit_UI.h` file content from the designer
  /// JSON config — the C++ code is always derived from the JSON schema.
  String _generateArduinoHeader() {
    final json = _state.toJson();
    return JsonArduinoGenerator.generate(json);
  }

  // ── C syntax highlighter for Arduino code ─────────────────────────────
  // (replaced by re_editor/re_highlight — see _buildCodeEditor above)

  /// Builds the complete RadioKit_UI.h content: JSON config block + Arduino code.
  String _buildFullHeader() {
    const encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(_state.toJson());
    final arduino = _generateArduinoHeader();
    return '/*__RadioKit_UI_Designer_Config__\n$json\nRadioKit_UI_Designer_Config__*/\n$arduino';
  }

  /// Builds just the JSON config content for .json files.
  String _buildJsonContent() {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_state.toJson());
  }

  // ── Code generation dialog ───────────────────────────────────────────────

  void _showSourceCode(BuildContext context, RKTokens tokens) {
    const encoder = JsonEncoder.withIndent('  ');
    final jsonString = _inlineSimpleArrays(encoder.convert(_state.toJson()));
    final displayJsonString = _transformJsonForDisplay(jsonString);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: tokens.base300,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOut,
          )),
          child: Material(
            color: tokens.base200,
            child: SafeArea(
              left: false,
              right: false,
              child: Column(
                children: [
                  // ── Header bar ────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    decoration: BoxDecoration(
                      color: tokens.base300,
                      border:
                          Border(bottom: BorderSide(color: tokens.effectiveOutline)),
                    ),
                    child: Row(
                      children: [
                        Icon(LucideIcons.code, color: tokens.primary, size: 20),
                        SizedBox(width: 10),
                        Text(
                          'CODE VIEWER',
                          style: TextStyle(
                            color: tokens.onSurface.withValues(alpha: 0.88),
                            fontSize: 14,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        Spacer(),
                        // COPY
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(
                                ClipboardData(text: _buildFullHeader()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: SelectableText(
                                      'RadioKit_UI.h copied to clipboard')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: tokens.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.copy, color: tokens.onPrimary, size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'COPY',
                                  style: TextStyle(
                                    color: tokens.onPrimary,
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // SHARE
                        GestureDetector(
                          onTap: () {
                            SharePlus.instance.share(
                                ShareParams(
                                  text: _buildFullHeader(),
                                  subject: 'RadioKit_UI.h',
                                ));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: tokens.base200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.share2,
                                    color: tokens.onSurface.withValues(alpha: 0.7), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  'SHARE',
                                  style: TextStyle(
                                    color: tokens.onSurface.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // DOWNLOAD .h
                        GestureDetector(
                          onTap: () async {
                            await downloadFile(
                                'RadioKit_UI.h', _buildFullHeader());
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: SelectableText(
                                      'RadioKit_UI.h downloaded')),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: tokens.base200,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(LucideIcons.download,
                                    color: tokens.onSurface.withValues(alpha: 0.7), size: 14),
                                SizedBox(width: 6),
                                Text(
                                  '.h',
                                  style: TextStyle(
                                    color: tokens.onSurface.withValues(alpha: 0.7),
                                    fontSize: 11,
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: 8),
                        // CLOSE
                        GestureDetector(
                          onTap: () => Navigator.of(ctx).pop(),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: tokens.effectiveOutline,
                              borderRadius: BorderRadius.circular(2),
                            ),
                            child: Icon(Icons.close,
                                color: tokens.onSurface.withValues(alpha: 0.53), size: 16),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ── Dual-pane body ───────────────────────────────────
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── JSON pane ────────────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pane header
                              _buildPaneHeader(
                                icon: LucideIcons.fileJson,
                                label: 'UI CONFIG (JSON)',
                                tokens: tokens,
                                onCopy: () {
                                  Clipboard.setData(
                                      ClipboardData(text: jsonString));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: SelectableText(
                                            'JSON config copied to clipboard')),
                                  );
                                },
                                onDownload: () async {
                                  await downloadFile(
                                      'RadioKit_UI.json', jsonString);
                                  if (!context.mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: SelectableText(
                                            'RadioKit_UI.json downloaded')),
                                  );
                                },
                              ),
                              // Code content with re_editor
                              Expanded(
                                child: Container(
                                  color: tokens.base200,
                                  child: _buildCodeEditor(displayJsonString, 'json'),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ── Vertical divider ──────────────────────────────
                        Container(
                          width: 1,
                          color: tokens.effectiveOutline,
                        ),
                        // ── Arduino pane ────────────────────────────────
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Pane header
                              _buildPaneHeader(
                                icon: LucideIcons.microchip,
                                label: 'ARDUINO CODE',
                                tokens: tokens,
                                onCopy: () {
                                  final arduinoCode = _generateArduinoHeader();
                                  Clipboard.setData(
                                      ClipboardData(text: arduinoCode));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: SelectableText(
                                            'Arduino code copied to clipboard')),
                                  );
                                },
                              ),
                              // Generated code with re_editor
                              Expanded(
                                child: Container(
                                  color: tokens.base200,
                                  child: _buildCodeEditor(_generateArduinoHeader(), 'cpp'),
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
          ),
        );
      },
    );
  }
}

/// Shared pane header builder with copy icon button and optional download.
Widget _buildPaneHeader({
  required IconData icon,
  required String label,
  required RKTokens tokens,
  required VoidCallback onCopy,
  VoidCallback? onDownload,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
    decoration: BoxDecoration(
      color: tokens.base300,
      border: Border(bottom: BorderSide(color: tokens.base200)),
    ),
    child: Row(
      children: [
        Icon(icon, color: tokens.primary, size: 14),
        SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: tokens.onSurface.withValues(alpha: 0.67),
            fontSize: 11,
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        Spacer(),
        GestureDetector(
          onTap: onCopy,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: tokens.effectiveOutline,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Icon(Icons.copy, color: tokens.primary, size: 13),
          ),
        ),
        if (onDownload != null) ...[
          SizedBox(width: 6),
          GestureDetector(
            onTap: onDownload,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: tokens.effectiveOutline,
                borderRadius: BorderRadius.circular(2),
              ),
              child:
                  Icon(LucideIcons.download, color: tokens.primary, size: 13),
            ),
          )
        ],
      ],
    ),
  );
}

class _IconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final RKTokens tokens;

  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.tokens,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isDisabled ? tokens.base300 : tokens.surface,
          border: Border.all(
            color:
                isDisabled ? tokens.effectiveOutline : tokens.effectiveOutline,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(
          icon,
          color: isDisabled ? tokens.effectiveOutline : tokens.primary,
          size: 16,
        ),
      ),
    );
  }
}
