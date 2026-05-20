import 'package:flutter/material.dart';
import 'dart:math' as math;
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
            clipBehavior: Clip.none,
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
                  child: ListenableBuilder(
                    listenable: state,
                    builder: (context, _) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Background grid clipped to rounded rect
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: GestureDetector(
                              onTap: () => state.selectElement(null),
                              child: CustomPaint(
                                size: Size(canvasPixelW, canvasPixelH),
                                painter: _GridPainter(
                                  cw: cw, ch: ch,
                                  style: state.gridStyle,
                                ),
                              ),
                            ),
                          ),
                          // Elements + handles as direct Stack children
                          ...state.elements.expand((el) {
                            // The element's stored position is its grid centre.
                            // The Positioned widget covers the full grid area so
                            // _MovableElement can intercept taps anywhere.
                            final halfW = el.width / 2;
                            final halfH = el.height / 2;
                            final left = (el.x - halfW) / cw * canvasPixelW;
                            final top  = (el.y - halfH) / ch * canvasPixelH;
                            final w = el.width  / cw * canvasPixelW;
                            final h = el.height / ch * canvasPixelH;
                            final isSelected = el.id == state.selectedElementId;

                            final widgets = <Widget>[
                              Positioned(
                                left: left, top: top, width: w, height: h,
                                child: _MovableElement(
                                  element: el,
                                  isSelected: isSelected,
                                  isPlayMode: state.isPlayMode,
                                  designerState: state,
                                  canvasKey: _canvasKey,
                                  cw: cw, ch: ch,
                                  canvasPixelW: canvasPixelW,
                                  canvasPixelH: canvasPixelH,
                                  onTap: () => state.selectElement(
                                    isSelected ? null : el.id,
                                  ),
                                  onSelect: () => state.selectElement(el.id),
                                  onMoved: (newX, newY) {
                                    el.x = newX;
                                    el.y = newY;
                                    state.notifyChanged();
                                  },
                                ),
                              ),
                            ];

                            if (isSelected && !state.isPlayMode) {
                              // Use the rendered size for handle positions so they
                              // sit at the corners of the debug overlay box.
                              final (rw, rh) = el.renderedGridSize;
                              final rWpx = rw / cw * canvasPixelW;
                              final rHpx = rh / ch * canvasPixelH;

                              // Centre of the rendered (debug overlay) box.
                              // For free-aspect widgets this equals the element
                              // centre; for square widgets it is the same centre
                              // because the widget is drawn centred in its area.
                              final cx = left + w / 2;
                              final cy = top  + h / 2;

                              // Compute rotated corner positions so handles
                              // follow the widget's visual rotation.
                              final angle = el.rotation * math.pi / 180;
                              final sinR  = math.sin(angle);
                              final cosR  = math.cos(angle);

                              // Rotated top-left of the rendered box
                              final rtlX = cx + (-rWpx/2 * cosR - (-rHpx/2) * sinR);
                              final rtlY = cy + (-rWpx/2 * sinR + (-rHpx/2) * cosR);
                              // Rotated bottom-right of the rendered box
                              final rbrX = cx + ( rWpx/2 * cosR -  rHpx/2  * sinR);
                              final rbrY = cy + ( rWpx/2 * sinR +  rHpx/2  * cosR);

                              widgets.add(Positioned(
                                left: rtlX - 12,
                                top:  rtlY - 12,
                                child: _DragHandle(
                                  icon: Icons.rotate_right,
                                  element: el,
                                  designerState: state,
                                  canvasKey: _canvasKey,
                                  cw: cw, ch: ch,
                                  canvasPixelW: canvasPixelW,
                                  canvasPixelH: canvasPixelH,
                                  isRotateHandle: true,
                                ),
                              ));
                              widgets.add(Positioned(
                                left: rbrX - 12,
                                top:  rbrY - 12,
                                child: _DragHandle(
                                  icon: Icons.crop_square,
                                  element: el,
                                  designerState: state,
                                  canvasKey: _canvasKey,
                                  cw: cw, ch: ch,
                                  canvasPixelW: canvasPixelW,
                                  canvasPixelH: canvasPixelH,
                                  isRotateHandle: false,
                                ),
                              ));
                            }

                            return widgets;
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

  void _onTap() {
    widget.onTap();
  }

  void _onPanStart(DragStartDetails details) {
    final renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    _dragStartGridX = widget.element.x;
    _dragStartGridY = widget.element.y;
    _dragStartCanvas = renderBox.globalToLocal(details.globalPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_dragStartCanvas == null) return;

    final renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final canvasPos = renderBox.globalToLocal(details.globalPosition);
    final dx = canvasPos.dx - _dragStartCanvas!.dx;
    final dy = canvasPos.dy - _dragStartCanvas!.dy;

    final newX = (_dragStartGridX! + (dx / widget.canvasPixelW * widget.cw).round())
        .clamp(widget.element.width ~/ 2, widget.cw - widget.element.width ~/ 2);
    final newY = (_dragStartGridY! + (dy / widget.canvasPixelH * widget.ch).round())
        .clamp(widget.element.height ~/ 2, widget.ch - widget.element.height ~/ 2);

    widget.onMoved(newX, newY);
  }

  void _onPanEnd(DragEndDetails details) {
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: FittedBox(
        fit: BoxFit.contain,
        clipBehavior: Clip.hardEdge,
        child: canvasChild,
      ),
    );
  }
}

class _DragHandle extends StatefulWidget {
  final IconData icon;
  final DesignerElement element;
  final DesignerState designerState;
  final GlobalKey canvasKey;
  final int cw;
  final int ch;
  final double canvasPixelW;
  final double canvasPixelH;
  final bool isRotateHandle;

  const _DragHandle({
    required this.icon,
    required this.element,
    required this.designerState,
    required this.canvasKey,
    required this.cw,
    required this.ch,
    required this.canvasPixelW,
    required this.canvasPixelH,
    required this.isRotateHandle,
  });

  @override
  State<_DragHandle> createState() => _DragHandleState();
}

class _DragHandleState extends State<_DragHandle> {
  static const double _size = 24.0;

  Offset? _startCanvasPos;
  int? _startWidth;
  int? _startHeight;
  int? _startRotation;

  void _onPanStart(DragStartDetails details) {
    _startWidth = widget.element.width;
    _startHeight = widget.element.height;
    _startRotation = widget.element.rotation;

    final renderBox = widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      _startCanvasPos = renderBox.globalToLocal(details.globalPosition);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_startCanvasPos == null) return;

    if (widget.isRotateHandle) {
      _handleRotate(details);
    } else {
      _handleResize(details);
    }
  }

  void _handleResize(DragUpdateDetails details) {
    final renderBox = widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _startCanvasPos == null) return;

    final pos = renderBox.globalToLocal(details.globalPosition);
    final dx = pos.dx - _startCanvasPos!.dx;
    final dy = pos.dy - _startCanvasPos!.dy;

    final widthDelta  = (dx / widget.canvasPixelW * widget.cw).round();
    final heightDelta = (dy / widget.canvasPixelH * widget.ch).round();

    if (widget.element.hasFixedAspectRatio) {
      // Lock to 1:1 — use the larger delta so dragging in any direction grows
      // the widget uniformly. The element stores equal width and height.
      final delta = widthDelta.abs() > heightDelta.abs() ? widthDelta : heightDelta;
      final size = (_startWidth! + delta).clamp(8, widget.cw - 8);
      widget.designerState.updateElementSize(
        widget.element.id,
        width: size,
        height: size,
      );
    } else {
      final newWidth  = (_startWidth!  + widthDelta ).clamp(8, widget.cw - 8);
      final newHeight = (_startHeight! + heightDelta).clamp(8, widget.ch - 8);
      widget.designerState.updateElementSize(
        widget.element.id,
        width: newWidth,
        height: newHeight,
      );
    }
  }

  void _handleRotate(DragUpdateDetails details) {
    final renderBox = widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _startCanvasPos == null || _startRotation == null) return;

    final el = widget.element;
    final elCenterX = (el.x / widget.cw * widget.canvasPixelW);
    final elCenterY = (el.y / widget.ch * widget.canvasPixelH);

    final pos = renderBox.globalToLocal(details.globalPosition);
    final currentDx = pos.dx - elCenterX;
    final currentDy = pos.dy - elCenterY;

    final startDx = _startCanvasPos!.dx - elCenterX;
    final startDy = _startCanvasPos!.dy - elCenterY;

    final startAngle = math.atan2(startDy, startDx);
    final currentAngle = math.atan2(currentDy, currentDx);
    final deltaRadians = currentAngle - startAngle;
    // Always compute from the fixed start position, not frame-by-frame,
    // to avoid cumulative rounding drift.
    // Normalize to -180..180 instead of 0..360.
    var newRotation = (_startRotation! + (deltaRadians * 180 / math.pi).round()) % 360;
    if (newRotation > 180) newRotation -= 360;
    widget.designerState.updateElementRotation(widget.element.id, newRotation);
  }

  void _onPanEnd(DragEndDetails details) {
    _startCanvasPos = null;
    _startRotation = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: MouseRegion(
        cursor: widget.isRotateHandle
            ? SystemMouseCursors.grab
            : SystemMouseCursors.resizeDownRight,
        child: Container(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF555555), width: 1),
          ),
          child: Icon(
            widget.icon,
            color: const Color(0xFF00D4FF),
            size: _size * 0.75,
          ),
        ),
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