import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/designer_element.dart';
import '../models/designer_state.dart';
import 'canvas_element.dart';

/// Interactive design surface for arranging RadioKit widgets.
class DesignerCanvas extends StatefulWidget {
  /// Mutable designer state containing elements, canvas orientation, and mode.
  final DesignerState state;

  /// Creates a canvas bound to [state].
  const DesignerCanvas({super.key, required this.state});

  @override
  State<DesignerCanvas> createState() => _DesignerCanvasState();
}

class _DesignerCanvasState extends State<DesignerCanvas> {
  final GlobalKey _canvasKey = GlobalKey();
  final GlobalKey _outerStackKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final cw = state.canvasWidth;
    final ch = state.canvasHeight;
    const canvasPixelW = 600.0;
    final canvasPixelH = 600.0 * ch / cw;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableW = constraints.maxWidth.clamp(1, double.infinity);
        final availableH = constraints.maxHeight.clamp(1, double.infinity);
        final scaleX = availableW / canvasPixelW;
        final scaleY = availableH / canvasPixelH;
        final scale = math.min(scaleX, scaleY);
        final displayW = canvasPixelW * scale;
        final displayH = canvasPixelH * scale;
        final canvasLeft = (constraints.maxWidth - displayW) / 2;
        final canvasTop = (constraints.maxHeight - displayH) / 2;

        return Stack(
          key: _outerStackKey,
          clipBehavior: Clip.none,
          children: [
            // ── Background (fills entire area for deselection) ──
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => state.selectElement(null),
              child: Container(color: const Color(0xFF0D0D0D)),
            ),
            // ── Canvas content (scaled to fit available editor area) ──
            Positioned(
              left: canvasLeft,
              top: canvasTop,
              width: displayW,
              height: displayH,
              child: ClipRect(
                clipBehavior: Clip.hardEdge,
                child: FittedBox(
                  fit: BoxFit.fill,
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: canvasPixelW,
                    height: canvasPixelH,
                    child: DragTarget<WidgetDragPayload>(
                      onAcceptWithDetails: (details) {
                        final renderBox = _canvasKey.currentContext
                            ?.findRenderObject() as RenderBox?;
                        if (renderBox == null) return;
                        final localPos = renderBox.globalToLocal(
                          details.offset,
                        );
                        final gx = (localPos.dx / canvasPixelW * cw).round();
                        final gy = (localPos.dy / canvasPixelH * ch).round();
                        state.addElement(
                          details.data.type,
                          gx,
                          gy,
                          properties: details.data.properties,
                        );
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
                              final widgets = <Widget>[];

                              // Grid background
                              widgets.add(
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  width: canvasPixelW,
                                  height: canvasPixelH,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(3),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => state.selectElement(null),
                                      child: CustomPaint(
                                        size: Size(canvasPixelW, canvasPixelH),
                                        painter: _GridPainter(
                                          cw: cw,
                                          ch: ch,
                                          style: state.gridStyle,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );

                              // Elements only (no handles)
                              for (final el in state.elements) {
                                // Use renderedGridSize so the Positioned
                                // container matches the SizedBox inside
                                // CanvasElement exactly — keeps FittedBox
                                // scale at 1 and handle corners pixel-perfect.
                                final (rw, rh) = el.renderedGridSize;
                                final halfW = rw / 2;
                                final halfH = rh / 2;
                                final left = (el.x - halfW) / cw * canvasPixelW;
                                final top = (el.y - halfH) / ch * canvasPixelH;
                                final w = rw / cw * canvasPixelW;
                                final h = rh / ch * canvasPixelH;
                                final isSelected =
                                    el.id == state.selectedElementId;

                                widgets.add(
                                  Positioned(
                                    left: left,
                                    top: top,
                                    width: w,
                                    height: h,
                                    child: _MovableElement(
                                      element: el,
                                      isSelected: isSelected,
                                      isPlayMode: state.isPlayMode,
                                      designerState: state,
                                      canvasKey: _canvasKey,
                                      cw: cw,
                                      ch: ch,
                                      canvasPixelW: canvasPixelW,
                                      canvasPixelH: canvasPixelH,
                                      onTap: () => state.selectElement(
                                        isSelected ? null : el.id,
                                      ),
                                      onSelect: () =>
                                          state.selectElement(el.id),
                                      onMoved: (newX, newY) {
                                        el.x = newX;
                                        el.y = newY;
                                        state.notifyChanged();
                                      },
                                    ),
                                  ),
                                );
                              }

                              // Drop-target highlight
                              if (candidates.isNotEmpty) {
                                widgets.add(
                                  const Positioned.fill(
                                    child: IgnorePointer(
                                      child: ColoredBox(
                                        color: Color(0x0D00FFFF),
                                      ),
                                    ),
                                  ),
                                );
                              }

                              return Stack(
                                clipBehavior: Clip.none,
                                children: widgets,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),

            // ── Resize / rotate handles (in outer Stack for proper hit testing) ──
            // Uses LayoutBuilder so handles reposition on every layout pass
            if (!state.isPlayMode)
              LayoutBuilder(
                builder: (context, constraints) {
                  final handleWidgets = <Widget>[];

                  for (final el in state.elements) {
                    if (el.id != state.selectedElementId) continue;

                    // Use renderedGridSize consistently so the handle bounding
                    // box matches the debug box exactly (especially for widgets
                    // with a fixed aspect ratio like multiButton/multiSelect).
                    final (rw, rh) = el.renderedGridSize;
                    final halfW = rw / 2;
                    final halfH = rh / 2;
                    final left = (el.x - halfW) / cw * canvasPixelW;
                    final top = (el.y - halfH) / ch * canvasPixelH;
                    final w = rw / cw * canvasPixelW;
                    final h = rh / ch * canvasPixelH;

                    final cx = left + w / 2;
                    final cy = top + h / 2;

                    final angle = el.rotation * math.pi / 180;
                    final sinR = math.sin(angle);
                    final cosR = math.cos(angle);

                    // Corner positions in canvas-pixel space
                    final rtlX = cx + (-w / 2 * cosR - (-h / 2) * sinR);
                    final rtlY = cy + (-w / 2 * sinR + (-h / 2) * cosR);
                    final rbrX = cx + (w / 2 * cosR - h / 2 * sinR);
                    final rbrY = cy + (w / 2 * sinR + h / 2 * cosR);

                    // Convert to outer Stack coordinates using Flutter's
                    // render-object coordinate transforms for pixel-perfect
                    // alignment with the visual debug box corners.
                    final canvasRenderBox = _canvasKey.currentContext
                        ?.findRenderObject() as RenderBox?;
                    final outerRenderBox = _outerStackKey.currentContext
                        ?.findRenderObject() as RenderBox?;

                    final Offset? rtlInStack;
                    final Offset? rbrInStack;
                    if (canvasRenderBox != null && outerRenderBox != null) {
                      rtlInStack = outerRenderBox.globalToLocal(
                        canvasRenderBox.localToGlobal(Offset(rtlX, rtlY)),
                      );
                      rbrInStack = outerRenderBox.globalToLocal(
                        canvasRenderBox.localToGlobal(Offset(rbrX, rbrY)),
                      );
                    } else {
                      // Fallback: compute from LayoutBuilder-derived values
                      rtlInStack = Offset(
                        canvasLeft + rtlX * scale,
                        canvasTop + rtlY * scale,
                      );
                      rbrInStack = Offset(
                        canvasLeft + rbrX * scale,
                        canvasTop + rbrY * scale,
                      );
                    }

                    // 12px offset centers the 24×24 handle icon over the corner
                    const handleSize = 24.0;
                    const hOff = handleSize / 2;
                    final rtlSX = rtlInStack.dx - hOff;
                    final rtlSY = rtlInStack.dy - hOff;
                    final rbrSX = rbrInStack.dx - hOff;
                    final rbrSY = rbrInStack.dy - hOff;

                    handleWidgets.add(
                      Positioned(
                        left: rtlSX,
                        top: rtlSY,
                        child: _DragHandle(
                          icon: Icons.rotate_right,
                          element: el,
                          designerState: state,
                          canvasKey: _canvasKey,
                          cw: cw,
                          ch: ch,
                          canvasPixelW: canvasPixelW,
                          canvasPixelH: canvasPixelH,
                          isRotateHandle: true,
                        ),
                      ),
                    );
                    handleWidgets.add(
                      Positioned(
                        left: rbrSX,
                        top: rbrSY,
                        child: _DragHandle(
                          icon: Icons.zoom_out_map,
                          element: el,
                          designerState: state,
                          canvasKey: _canvasKey,
                          cw: cw,
                          ch: ch,
                          canvasPixelW: canvasPixelW,
                          canvasPixelH: canvasPixelH,
                          isRotateHandle: false,
                        ),
                      ),
                    );
                  }

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [const SizedBox.expand(), ...handleWidgets],
                  );
                },
              ),
          ],
        );
      },
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

    final (rw, rh) = widget.element.renderedGridSize;
    final newX =
        (_dragStartGridX! + (dx / widget.canvasPixelW * widget.cw).round())
            .clamp(
      rw ~/ 2,
      widget.cw - rw ~/ 2,
    );
    final newY =
        (_dragStartGridY! + (dy / widget.canvasPixelH * widget.ch).round())
            .clamp(
      rh ~/ 2,
      widget.ch - rh ~/ 2,
    );

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

    final renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
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
    final renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || _startCanvasPos == null) return;

    final pos = renderBox.globalToLocal(details.globalPosition);
    final dx = pos.dx - _startCanvasPos!.dx;
    final dy = pos.dy - _startCanvasPos!.dy;

    final widthDelta = (dx / widget.canvasPixelW * widget.cw).round();
    final heightDelta = (dy / widget.canvasPixelH * widget.ch).round();

    final (minW, minH) = DesignerElement.minSize(widget.element.type,
        currentWidth: widget.element.width, currentHeight: widget.element.height);
    final ar = widget.element.aspectRatio;
    if (ar != null) {
      if (ar == 1.0) {
        // Square widget: use the dominant axis delta, keep equal width/height
        final delta =
            widthDelta.abs() > heightDelta.abs() ? widthDelta : heightDelta;
        final minSize = minW > minH ? minW : minH;
        final size = (_startWidth! + delta).clamp(minSize, widget.cw - minSize);
        widget.designerState.updateElementSize(
          widget.element.id,
          width: size,
          height: size,
        );
      } else if (ar < 0) {
        // Vertical fixed-AR (multi): width is primary, derive height
        final newWidth = (_startWidth! + widthDelta).clamp(minW, widget.cw - minW);
        final autoH = (newWidth * -ar).round().clamp(1, 999);
        widget.designerState.updateElementSize(
          widget.element.id,
          width: newWidth,
          height: autoH,
        );
      } else {
        // Horizontal fixed-AR: height is primary, derive width
        final newHeight = (_startHeight! + heightDelta).clamp(minH, widget.ch - minH);
        final autoW = (newHeight * ar).round().clamp(1, 999);
        widget.designerState.updateElementSize(
          widget.element.id,
          width: autoW,
          height: newHeight,
        );
      }
    } else {
      final newWidth = (_startWidth! + widthDelta).clamp(minW, widget.cw - minW);
      final newHeight = (_startHeight! + heightDelta).clamp(minH, widget.ch - minH);
      widget.designerState.updateElementSize(
        widget.element.id,
        width: newWidth,
        height: newHeight,
      );
    }
  }

  void _handleRotate(DragUpdateDetails details) {
    final renderBox =
        widget.canvasKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null ||
        _startCanvasPos == null ||
        _startRotation == null) {
      return;
    }

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
    var newRotation =
        (_startRotation! + (deltaRadians * 180 / math.pi).round()) % 360;
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
      behavior: HitTestBehavior.opaque,
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

  _GridPainter({
    required this.cw,
    required this.ch,
    this.style = GridStyle.lines,
  });

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
      oldDelegate.cw != cw ||
      oldDelegate.ch != ch ||
      oldDelegate.style != style;
}
