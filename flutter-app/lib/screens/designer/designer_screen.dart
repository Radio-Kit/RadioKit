import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'utils/file_download.dart';
import 'codegen/arduino_generator.dart';
import 'widgets/designer_widget_dialog.dart';
import 'widgets/designer_inspector.dart';

import '../../providers/designs_provider.dart';

class DesignerScreen extends StatefulWidget {
  final String? designId;
  const DesignerScreen({super.key, this.designId});

  @override
  State<DesignerScreen> createState() => _DesignerScreenState();
}

class _DesignerScreenState extends State<DesignerScreen> {
  final DesignerState _state = DesignerState();
  String? _currentDesignId;
  Timer? _saveTimer;

  @override
  void initState() {
    super.initState();
    _currentDesignId = widget.designId;
    _state.addListener(_onStateChanged);
    RKDebugOverlay.enabled = !_state.isPlayMode;
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadInitialDesign();
    });
  }

  void _loadInitialDesign() {
    if (widget.designId != null) {
      final provider = context.read<DesignsProvider>();
      final designs = provider.designs;
      final existing = designs.where((d) => d.id == widget.designId).firstOrNull;
      if (existing != null) {
        try {
          final json = jsonDecode(existing.jsonContent);
          _state.loadFromJson(json);
        } catch (e) {
          debugPrint('Failed to load design: $e');
        }
      } else {
        _state.setModelName('Project-${math.Random().nextInt(10000)}');
      }
    } else {
      _state.setModelName('Project-${math.Random().nextInt(10000)}');
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _state.removeListener(_onStateChanged);
    _state.dispose();
    RKDebugOverlay.enabled = false;
    super.dispose();
  }

  void _onStateChanged() {
    RKDebugOverlay.enabled = !_state.isPlayMode;
    setState(() {});
    
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 1000), () {
      _autoSaveToApp();
    });
  }

  void _autoSaveToApp() async {
    if (!mounted) return;
    final provider = context.read<DesignsProvider>();
    final jsonContent = jsonEncode(_state.toJson());
    final name = _state.modelName.isNotEmpty ? _state.modelName : 'Untitled Design';
    
    _currentDesignId ??= DateTime.now().millisecondsSinceEpoch.toString();
    
    await provider.saveDesign(_currentDesignId!, name, jsonContent);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Scaffold(
      body: Column(
        children: [
          _buildTopBar(tokens),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      RKTheme(
                        tokens: switch (_state.activeSkin) {
                          'neon' => RKTokens.neon,
                          'minimal' => RKTokens.minimal,
                          _ => RKTokens.dragon,
                        },
                        child: DesignerCanvas(state: _state),
                      ),
                      if (!_state.isPlayMode)
                        Positioned(
                          left: 16,
                          bottom: 16,
                          child: _DesignerFabMenu(
                            state: _state,
                            tokens: tokens,
                            onAddWidget: () {
                              showDialog(
                                context: context,
                                builder: (context) => DesignerWidgetDialog(state: _state),
                              );
                            },
                            onShare: () {
                              _autoSaveToApp();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Design saved'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            onViewCode: () => _showSourceCode(context, tokens),
                            onDownloadCode: _downloadCode,
                          ),
                        ),
                      if (!_state.isPlayMode && !_state.isInspectorVisible)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton(
                            onPressed: () {
                              _state.setInspectorVisible(true);
                            },
                            backgroundColor: tokens.primary,
                            foregroundColor: Colors.black,
                            child: const Icon(LucideIcons.settings),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Top bar ──────────────────────────────────────────────────────────────

  Widget _buildTopBar(RKTokens tokens) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(bottom: BorderSide(color: Color(0xFF222222), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(LucideIcons.arrowLeft, color: tokens.primary, size: 20),
            onPressed: () => _handleBack(context),
          ),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: _state,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _state.modelName.isNotEmpty ? _state.modelName : 'Untitled Project',
                  style: TextStyle(
                    color: tokens.primary,
                    fontSize: 18,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(LucideIcons.pencil, size: 16, color: tokens.primary),
                  onPressed: () => _editProjectName(context),
                  tooltip: 'Edit Project Name',
                ),
              ],
            ),
          ),
          const Spacer(),
          _buildPlayModeButton(tokens),
          const SizedBox(width: 12),
          _buildUndoRedoButtons(tokens),
        ],
      ),
    );
  }

  Future<void> _editProjectName(BuildContext context) async {
    final controller = TextEditingController(text: _state.modelName);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        title: const Text(
          'Edit Project Name',
          style: TextStyle(color: Color(0xFFE0E0E0), fontFamily: 'monospace'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white, fontFamily: 'monospace'),
          decoration: const InputDecoration(
            hintText: 'Project Name',
            hintStyle: TextStyle(color: Color(0xFF888888)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF333333))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF90CAF9))),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL', style: TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'monospace')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('SAVE', style: TextStyle(color: Color(0xFF90CAF9), fontFamily: 'monospace', fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (newName != null && newName.trim().isNotEmpty) {
      _state.setModelName(newName.trim());
      // Explicitly trigger save for immediate UI/persistence update if needed
      _autoSaveToApp();
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
            const SizedBox(width: 4),
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
              color: isPlay ? const Color(0xFF1B5E20) : const Color(0xFF1A1A1A),
              border: Border.all(
                color: isPlay ? const Color(0xFF2E7D32) : const Color(0xFF444444),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isPlay ? LucideIcons.square : LucideIcons.play,
                  color: isPlay ? const Color(0xFFA5D6A7) : tokens.primary,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  isPlay ? 'DONE' : 'TEST',
                  style: TextStyle(
                    color: isPlay ? const Color(0xFFA5D6A7) : tokens.primary,
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

  // ── Back navigation ───────────────────────────────────────────────────────

  Future<void> _handleBack(BuildContext context) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF181818),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        title: const Text(
          'Unsaved Changes',
          style: TextStyle(
            color: Color(0xFFE0E0E0),
            fontFamily: 'monospace',
            fontWeight: FontWeight.w600,
          ),
        ),
        content: const Text(
          'Do you want to save your changes before leaving?',
          style: TextStyle(color: Color(0xFFAAAAAA), fontFamily: 'monospace'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text(
              'DISCARD',
              style: TextStyle(
                color: Color(0xFFFF5555),
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text(
              'SAVE',
              style: TextStyle(
                color: Color(0xFF90CAF9),
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
      _autoSaveToApp();
    }
    // Both 'save' and 'discard' navigate back; null means dialog was dismissed
    if (result != null) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/designs');
      }
    }
  }

  // ── .h file I/O ──────────────────────────────────────────────────────────

  void _openHeaderFile() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['h'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final bytes = result.files.first.bytes;
        if (bytes != null) {
          final content = utf8.decode(bytes);
          _state.loadFromHeaderContent(content, path: result.files.first.name);
        } else {
          // Fallback if bytes is null (e.g., some desktop platforms if withData fails)
          final path = result.files.first.path;
          if (path != null) {
            await _state.loadFromHeaderFile(path);
          } else {
            throw Exception('Could not read file data');
          }
        }
        
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: SelectableText('RadioKit_UI.h loaded')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Load failed: $e')),
      );
    }
  }

  void _saveHeaderFile() async {
    try {
      if (kIsWeb) {
        final newContent = _state.generateHeaderContent(_state.originalHeaderContent ?? '');
        final filename = _state.originalHeaderPath ?? 'RadioKit_UI.h';
        downloadFile(filename, newContent);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: SelectableText('RadioKit_UI.h downloaded')),
        );
        return;
      }

      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['h'],
        dialogTitle: 'Select an existing RadioKit_UI.h to update',
      );
      if (result != null && result.files.isNotEmpty) {
        final path = result.files.first.path;
        if (path != null) {
          await _state.saveToHeaderFile(path);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: SelectableText('RadioKit_UI.h saved')),
          );
        } else {
          throw Exception('File path is null. Saving to an existing file requires Desktop.');
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: SelectableText('Save failed: $e')),
      );
    }
  }

  // ── Code generation dialog ───────────────────────────────────────────────

  void _downloadCode() {
    final code = ArduinoGenerator.generate(_state);
    downloadFile('RadioKit_UI.ino', code);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: SelectableText('RadioKit_UI.ino downloaded')),
    );
  }

  void _showSourceCode(BuildContext context, RKTokens tokens) {
    final code = ArduinoGenerator.generate(_state);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF111111),
        insetPadding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(LucideIcons.code, color: tokens.primary, size: 20),
                  const SizedBox(width: 10),
                  const Text(
                    'ARDUINO SOURCE CODE',
                    style: TextStyle(
                      color: Color(0xFFE0E0E0),
                      fontSize: 14,
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: SelectableText('Code copied to clipboard')),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: tokens.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.copy, color: Colors.black, size: 14),
                          SizedBox(width: 6),
                          Text(
                            'COPY',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 11,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: const Icon(Icons.close, color: Color(0xFF888888), size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF222222), height: 1),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0A0A),
                  border: Border.all(color: const Color(0xFF222222)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  code,
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 12,
                    fontFamily: 'monospace',
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignerFabMenu extends StatefulWidget {
  final DesignerState state;
  final RKTokens tokens;
  final VoidCallback onAddWidget;
  final VoidCallback onShare;
  final VoidCallback onViewCode;
  final VoidCallback onDownloadCode;

  const _DesignerFabMenu({
    required this.state,
    required this.tokens,
    required this.onAddWidget,
    required this.onShare,
    required this.onViewCode,
    required this.onDownloadCode,
  });

  @override
  State<_DesignerFabMenu> createState() => _DesignerFabMenuState();
}

class _DesignerFabMenuState extends State<_DesignerFabMenu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_controller.isCompleted) {
      _controller.reverse();
    } else {
      _controller.forward();
    }
  }

  void _close() {
    if (_controller.isCompleted || _controller.isAnimating) {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizeTransition(
          sizeFactor: _expandAnimation,
          alignment: Alignment.bottomCenter,
          child: FadeTransition(
            opacity: _expandAnimation,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMenuItem(LucideIcons.plus, 'Add Widget', widget.onAddWidget),
                const SizedBox(height: 8),
                _buildMenuItem(LucideIcons.share2, 'Share', widget.onShare),
                const SizedBox(height: 8),
                _buildMenuItem(LucideIcons.code, 'View Code', widget.onViewCode),
                const SizedBox(height: 8),
                _buildMenuItem(LucideIcons.download, 'Download Code', widget.onDownloadCode),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        FloatingActionButton(
          onPressed: _toggle,
          backgroundColor: widget.tokens.primary,
          foregroundColor: Colors.black,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Icon(
              _controller.isCompleted ? Icons.close : LucideIcons.plus,
              key: ValueKey(_controller.isCompleted),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMenuItem(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: () {
        _close();
        onTap();
      },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: widget.tokens.primary, size: 16),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
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
          color: isDisabled ? const Color(0xFF111111) : const Color(0xFF1A1A1A),
          border: Border.all(
            color: isDisabled ? const Color(0xFF222222) : const Color(0xFF444444),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Icon(
          icon,
          color: isDisabled ? const Color(0xFF333333) : tokens.primary,
          size: 16,
        ),
      ),
    );
  }
}
