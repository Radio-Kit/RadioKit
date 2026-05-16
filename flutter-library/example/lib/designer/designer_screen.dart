import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'models/designer_state.dart';
import 'codegen/arduino_generator.dart';
import 'widgets/designer_sidebar.dart';
import 'widgets/designer_canvas.dart';
import 'widgets/designer_inspector.dart';

class DesignerScreen extends StatefulWidget {
  const DesignerScreen({super.key});

  @override
  State<DesignerScreen> createState() => _DesignerScreenState();
}

class _DesignerScreenState extends State<DesignerScreen> {
  final DesignerState _state = DesignerState();

  @override
  void initState() {
    super.initState();
    _state.addListener(_onStateChanged);
    RKDebugOverlay.enabled = true;
  }

  @override
  void dispose() {
    _state.removeListener(_onStateChanged);
    _state.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DesignerSidebar(),
          Expanded(
            child: Column(
              children: [
                _buildTopBar(tokens),
                Expanded(child: DesignerCanvas(state: _state)),
              ],
            ),
          ),
          ListenableBuilder(
            listenable: _state,
            builder: (context, _) => DesignerInspector(state: _state),
          ),
        ],
      ),
    );
  }

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
          Text(
            'UI DESIGNER',
            style: TextStyle(
              color: tokens.primary,
              fontSize: 18,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          _buildPlayModeButton(tokens),
          const SizedBox(width: 12),
          _buildUndoRedoButtons(tokens),
          const SizedBox(width: 12),
          _buildGetSourceButton(tokens),
        ],
      ),
    );
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

  Widget _buildGetSourceButton(RKTokens tokens) {
    return GestureDetector(
      onTap: () => _showSourceCode(context, tokens),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1B5E20),
          borderRadius: BorderRadius.circular(2),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.code, color: tokens.primary, size: 14),
            const SizedBox(width: 6),
            const Text(
              'CODE',
              style: TextStyle(
                color: Color(0xFFA5D6A7),
                fontSize: 11,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
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
                        const SnackBar(content: Text('Code copied to clipboard')),
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
