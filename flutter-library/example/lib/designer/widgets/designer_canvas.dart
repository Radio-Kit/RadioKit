import 'package:flutter/material.dart';
import '../models/designer_element.dart';
import '../models/designer_state.dart';
import 'canvas_element.dart';

class DesignerCanvas extends StatefulWidget {
  final DesignerState state;
  const DesignerCanvas({super.key, required this.state});

  @override
  State<DesignerCanvas> createState() => _DesignerCanvasState();
}

class _DesignerCanvasState extends State<DesignerCanvas> {
  final GlobalKey _canvasKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cw = state.canvasWidth;
    final ch = state.canvasHeight;
    const canvasPixelW = 600.0;
    final canvasPixelH = 600.0 * ch / cw;

    return Container(
        color: const Color(0xFF0D0D0D),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            clipBehavior: Clip.hardEdge,
            child: DragTarget<WidgetDragPayload>(
              onAcceptWithDetails: (details) {
                final renderBox =
                    _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                if (renderBox == null) return;
                final localPos = renderBox.globalToLocal(details.offset);
                final gx = (localPos.dx / canvasPixelW * cw).round();
                final gy = (localPos.dy / canvasPixelH * ch).round();
                state.addElement(details.data.type, gx, gy, properties: details.data.properties);
              },
              builder: (context, candidates, rejected) {
                return Container(
                  key: _canvasKey,
                  width: canvasPixelW,
                  height: canvasPixelH,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: candidates.isNotEmpty
                          ? Colors.cyanAccent
                          : const Color(0xFF333333),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: ListenableBuilder(
                      listenable: state,
                      builder: (context, _) {
                        return Stack(
                          children: [
                            GestureDetector(
                              onTap: () => state.selectElement(null),
                              child: CustomPaint(
                                size: Size(canvasPixelW, canvasPixelH),
                                painter: _GridPainter(
                                  cw: cw, ch: ch,
                                  style: state.gridStyle,
                                ),
                              ),
                            ),
                              ...state.elements.map((el) {
                                final halfW = el.width / 2;
                                final halfH = el.height / 2;
                                return Positioned(
                                  left: (el.x - halfW) / cw * canvasPixelW,
                                  top: (el.y - halfH) / ch * canvasPixelH,
                                  width: el.width / cw * canvasPixelW,
                                  height: el.height / ch * canvasPixelH,
                                  child: _MovableElement(
                                    element: el,
                                    isSelected: el.id == state.selectedElementId,
                                    isPlayMode: state.isPlayMode,
                                    designerState: state,
                                    canvasKey: _canvasKey,
                                    cw: cw,
                                    ch: ch,
                                    canvasPixelW: canvasPixelW,
                                    canvasPixelH: canvasPixelH,
                                    onTap: () => state.selectElement(
                                      el.id == state.selectedElementId ? null : el.id,
                                    ),
                                    onSelect: () => state.selectElement(el.id),
                                    onMoved: (newX, newY) {
                                      el.x = newX;
                                      el.y = newY;
                                      state.notifyChanged();
                                    },
                                  ),
                                );
                              }),
                              if (candidates.isNotEmpty)
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.cyanAccent.withValues(alpha: 0.05),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
  }
}

class _MovableElement extends StatefulWidget {
  final DesignerElement element;
  final bool isSelected;
  final bool isPlayMode;
  final DesignerState designerState;
  final GlobalKey canvasKey;
  final int cw;
  final int ch;
  final double canvasPixelW;
  final double canvasPixelH;
  final VoidCallback onTap;
  final VoidCallback onSelect;
  final void Function(int x, int y) onMoved;

  const _MovableElement({
    required this.element,
    required this.isSelected,
    required this.isPlayMode,
    required this.designerState,
    required this.canvasKey,
    required this.cw,
    required this.ch,
    required this.canvasPixelW,
    required this.canvasPixelH,
    required this.onTap,
    required this.onSelect,
    required this.onMoved,
  });

  @override
  State<_MovableElement> createState() => _MovableElementState();
}

class _MovableElementState extends State<_MovableElement> {
  int? _dragStartGridX;
  int? _dragStartGridY;
  Offset? _dragStartCanvas;
  Offset? _pointerDownScreen;

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownScreen = event.position;
    _dragStartCanvas = null;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_pointerDownScreen == null) return;

    if (_dragStartCanvas == null) {
      final dist = (event.position - _pointerDownScreen!).distance;
      if (dist < 5) return;
      final renderBox =
          widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      _dragStartGridX = widget.element.x;
      _dragStartGridY = widget.element.y;
      _dragStartCanvas = renderBox.globalToLocal(event.position);
      return;
    }

    final renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final canvasPos = renderBox.globalToLocal(event.position);
    final dx = canvasPos.dx - _dragStartCanvas!.dx;
    final dy = canvasPos.dy - _dragStartCanvas!.dy;

    final newX = (_dragStartGridX! + (dx / widget.canvasPixelW * widget.cw).round())
        .clamp(widget.element.width ~/ 2, widget.cw - widget.element.width ~/ 2);
    final newY = (_dragStartGridY! + (dy / widget.canvasPixelH * widget.ch).round())
        .clamp(widget.element.height ~/ 2, widget.ch - widget.element.height ~/ 2);

    widget.onMoved(newX, newY);
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_pointerDownScreen != null && _dragStartCanvas == null) {
      widget.onTap();
    }
    _pointerDownScreen = null;
    _dragStartGridX = null;
    _dragStartGridY = null;
    _dragStartCanvas = null;
  }

  @override
  Widget build(BuildContext context) {
    final canvasChild = CanvasElement(
      element: widget.element,
      isSelected: widget.isSelected,
      isPlayMode: widget.isPlayMode,
      designerState: widget.designerState,
    );

    if (widget.isPlayMode) {
      return FittedBox(
        fit: BoxFit.contain,
        clipBehavior: Clip.hardEdge,
        child: canvasChild,
      );
    }

    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      child: FittedBox(
        fit: BoxFit.contain,
        clipBehavior: Clip.hardEdge,
        child: canvasChild,
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  final int cw;
  final int ch;
  final GridStyle style;

  _GridPainter({required this.cw, required this.ch, this.style = GridStyle.lines});

  @override
  void paint(Canvas canvas, Size size) {
    if (style == GridStyle.none) return;

    final stepX = size.width / cw;
    final stepY = size.height / ch;

    if (style == GridStyle.dots) {
      final finePaint = Paint()
        ..color = const Color(0xFF252525)
        ..style = PaintingStyle.fill;
      final coarsePaint = Paint()
        ..color = const Color(0xFF444444)
        ..style = PaintingStyle.fill;

      for (int i = 0; i <= cw; i += 5) {
        for (int j = 0; j <= ch; j += 5) {
          canvas.drawCircle(Offset(i * stepX, j * stepY), 1.0, finePaint);
        }
      }
      for (int i = 0; i <= cw; i += 10) {
        for (int j = 0; j <= ch; j += 10) {
          canvas.drawCircle(Offset(i * stepX, j * stepY), 1.5, coarsePaint);
        }
      }
      return;
    }

    // Lines
    final finePaint = Paint()
      ..color = const Color(0xFF252525)
      ..strokeWidth = 0.5;

    for (int i = 0; i <= cw; i += 5) {
      final x = i * stepX;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), finePaint);
    }
    for (int i = 0; i <= ch; i += 5) {
      final y = i * stepY;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), finePaint);
    }

    final coarsePaint = Paint()
      ..color = const Color(0xFF333333)
      ..strokeWidth = 1;

    for (int i = 0; i <= cw; i += 10) {
      final x = i * stepX;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), coarsePaint);
    }
    for (int i = 0; i <= ch; i += 10) {
      final y = i * stepY;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), coarsePaint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter oldDelegate) =>
      oldDelegate.cw != cw || oldDelegate.ch != ch || oldDelegate.style != style;
}
