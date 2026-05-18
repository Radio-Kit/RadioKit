import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

class InspectorFieldBuilders {
  static Widget buildSection(RKTokens tokens, String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Text(
            title,
            style: TextStyle(
              color: tokens.primary,
              fontSize: 12,
              fontFamily: 'monospace',
              letterSpacing: 1,
            ),
          ),
        ),
        ...children,
        Container(height: 1, color: const Color(0xFF222222)),
      ],
    );
  }

  static Widget buildTextField(RKTokens tokens, String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                border: Border.all(color: const Color(0xFF333333)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: TextField(
                controller: TextEditingController(text: value)
                  ..selection = TextSelection.collapsed(offset: value.length),
                style: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildNumField(RKTokens tokens, String label, int value, ValueChanged<int> onChanged, {double? min, double? max}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DragToAdjustInput(
              value: value.toDouble(),
              min: min ?? 0,
              max: max ?? double.infinity,
              sensitivity: 1.0,
              decimalPlaces: 0,
              onChanged: (v) => onChanged(v.toInt()),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildDoubleField(RKTokens tokens, String label, double value, ValueChanged<double> onChanged, {double? min, double? max, int decimalPlaces = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DragToAdjustInput(
              value: value,
              min: min ?? 0,
              max: max ?? double.infinity,
              sensitivity: decimalPlaces == 0 ? 1.0 : (0.1 / decimalPlaces),
              decimalPlaces: decimalPlaces,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildCompactNumField(RKTokens tokens, String label, int value, ValueChanged<int> onChanged, {double? min, double? max}) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: DragToAdjustInput(
            value: value.toDouble(),
            min: min ?? 0,
            max: max ?? double.infinity,
            sensitivity: 1.0,
            decimalPlaces: 0,
            onChanged: (v) => onChanged(v.toInt()),
          ),
        ),
      ],
    );
  }

  static Widget buildOptionSelector(RKTokens tokens, String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          ...options.map((opt) {
            final isSelected = opt == value;
            return Padding(
              padding: const EdgeInsets.only(right: 4),
              child: GestureDetector(
                onTap: () => onChanged(opt),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? tokens.primary : const Color(0xFF1A1A1A),
                    border: Border.all(
                      color: isSelected ? tokens.primary : const Color(0xFF444444),
                      width: 1,
                    ),
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Text(
                    opt.toUpperCase(),
                    style: TextStyle(
                      color: isSelected ? Colors.black : const Color(0xFF888888),
                      fontSize: 10,
                      fontFamily: 'monospace',
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  static Widget buildBoolToggle(RKTokens tokens, String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => onChanged(!value),
            child: Container(
              width: 28,
              height: 16,
              decoration: BoxDecoration(
                color: value ? tokens.primary : const Color(0xFF333333),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 12,
                  height: 12,
                  margin: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildRotationSlider(RKTokens tokens, double rotation, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Rotation',
                style: TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
              const Spacer(),
              Text(
                '${rotation.toInt()}°',
                style: TextStyle(
                  color: tokens.primary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text('-180', style: TextStyle(color: Color(0xFF555555), fontSize: 10, fontFamily: 'monospace')),
              Expanded(
                child: Slider(
                  value: rotation,
                  min: -180,
                  max: 180,
                  divisions: 360,
                  activeColor: tokens.primary,
                  inactiveColor: const Color(0xFF333333),
                  onChanged: onChanged,
                ),
              ),
              const Text('180', style: TextStyle(color: Color(0xFF555555), fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ],
      ),
    );
  }

  static Widget buildCenterPinnedSelector(
    RKTokens tokens,
    String label,
    String value,
    List<String> options,
    ValueChanged<String> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _CenterPinnedSelector(
              options: options,
              initialIndex: options.indexOf(value).clamp(0, options.length - 1),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterPinnedSelector extends StatefulWidget {
  const _CenterPinnedSelector({
    super.key,
    required this.options,
    this.initialIndex = 0,
    required this.onChanged,
  });

  final List<String> options;
  final int initialIndex;
  final ValueChanged<String> onChanged;

  @override
  State<_CenterPinnedSelector> createState() => _CenterPinnedSelectorState();
}

class _CenterPinnedSelectorState extends State<_CenterPinnedSelector>
    with SingleTickerProviderStateMixin {
  late int selectedIndex;
  late int incomingIndex;
  late AnimationController _controller;
  late Animation<double> _animation;

  double dragDx = 0;
  int direction = 0;

  static const double selectedFontSize = 13;
  static const double normalFontSize = 11;
  static const double itemGap = 10;

  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex;
    incomingIndex = widget.initialIndex;

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          selectedIndex = incomingIndex;
          direction = 0;
          dragDx = 0;
        });
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(int newIndex) {
    if (_controller.isAnimating || newIndex == selectedIndex) return;
    widget.onChanged(widget.options[newIndex]);

    setState(() {
      incomingIndex = newIndex;
      direction = newIndex > selectedIndex ? 1 : -1;
      if (selectedIndex == widget.options.length - 1 && newIndex == 0) {
        direction = 1;
      } else if (selectedIndex == 0 && newIndex == widget.options.length - 1) {
        direction = -1;
      }
    });

    _controller.forward(from: 0);
  }

  void _goNext() {
    final next = (selectedIndex + 1) % widget.options.length;
    _animateTo(next);
  }

  void _goPrevious() {
    final previous =
        (selectedIndex - 1 + widget.options.length) % widget.options.length;
    _animateTo(previous);
  }

  void _select(int index) {
    if (index == selectedIndex) return;
    _animateTo(index);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_controller.isAnimating) return;
    setState(() {
      dragDx += details.delta.dx;
      dragDx = dragDx.clamp(-56, 56);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_controller.isAnimating) return;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -120 || dragDx < -28) {
      _goNext();
    } else if (velocity > 120 || dragDx > 28) {
      _goPrevious();
    } else {
      setState(() => dragDx = 0);
    }
  }

  double _measureText(String text, {required bool selected}) {
    final style = TextStyle(
      fontSize: selected ? selectedFontSize : normalFontSize,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      fontFamily: 'monospace',
    );
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  List<_ItemLayout> _buildLayouts(double availableWidth) {
    final progress = _controller.isAnimating ? _animation.value : 0.0;
    final centerIndex = _controller.isAnimating ? incomingIndex : selectedIndex;
    final centerText = widget.options[centerIndex];
    final centerWidth = _measureText(centerText, selected: true);
    final layouts = <_ItemLayout>[];

    layouts.add(_ItemLayout(
      index: centerIndex,
      x: 0,
      opacity: 1,
      scale: 1,
      selected: true,
    ));

    double leftCursor = -(centerWidth / 2) - itemGap;
    for (int i = centerIndex - 1; i >= 0; i--) {
      final width = _measureText(widget.options[i], selected: false);
      final x = leftCursor - (width / 2);
      if (x + width / 2 < -availableWidth / 2) break;
      final distance = centerIndex - i;
      final opacity = distance == 1 ? 0.55 : distance == 2 ? 0.32 : 0.18;
      layouts.add(_ItemLayout(
        index: i,
        x: x - (progress * 10 * direction),
        opacity: opacity,
        scale: 0.92,
        selected: false,
      ));
      leftCursor -= width + itemGap;
    }

    double rightCursor = (centerWidth / 2) + itemGap;
    for (int i = centerIndex + 1; i < widget.options.length; i++) {
      final width = _measureText(widget.options[i], selected: false);
      final x = rightCursor + (width / 2);
      if (x - width / 2 > availableWidth / 2) break;
      final distance = i - centerIndex;
      final opacity = distance == 1 ? 0.55 : distance == 2 ? 0.32 : 0.18;
      layouts.add(_ItemLayout(
        index: i,
        x: x - (progress * 10 * direction),
        opacity: opacity,
        scale: 0.92,
        selected: false,
      ));
      rightCursor += width + itemGap;
    }

    if (!_controller.isAnimating && dragDx != 0) {
      final dragShift = dragDx * 0.35;
      return layouts
          .map((e) => e.selected
              ? e
              : e.copyWith(
                  x: e.x + dragShift,
                  opacity: (e.opacity + 0.06).clamp(0.0, 1.0),
                ))
          .toList();
    }

    return layouts;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFF333333)),
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: _goPrevious,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_left_rounded,
                      size: 18, color: tokens.primary.withValues(alpha: 0.7)),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onHorizontalDragUpdate: _onDragUpdate,
                  onHorizontalDragEnd: _onDragEnd,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final availableWidth = constraints.maxWidth - 16;
                      final layouts = _buildLayouts(availableWidth);
                       return SizedBox(
                         height: 28,
                         child: Stack(
                           clipBehavior: Clip.none,
                          alignment: Alignment.center,
                          children: [
                            for (final item in layouts)
                              Positioned.fill(
                                child: IgnorePointer(
                                  ignoring: !item.selected,
                                  child: Align(
                                    alignment: Alignment.center,
                                    child: Transform.translate(
                                      offset: Offset(item.x, 0),
                                      child: Opacity(
                                        opacity: item.opacity,
                                        child: Transform.scale(
                                          scale: item.scale,
                                          child: GestureDetector(
                                            onTap: () => _select(item.index),
                                              child: Padding(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 4, vertical: 2),
                                                child: Text(
                                                widget.options[item.index].toUpperCase(),
                                                maxLines: 1,
                                                overflow: TextOverflow.visible,
                                                style: TextStyle(
                                                  fontSize: item.selected
                                                      ? selectedFontSize
                                                      : normalFontSize,
                                                  fontWeight: item.selected
                                                      ? FontWeight.w700
                                                      : FontWeight.w500,
                                                  color: item.selected
                                                      ? tokens.primary
                                                      : const Color(0xFF666666),
                                                  fontFamily: 'monospace',
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              GestureDetector(
                onTap: _goNext,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.chevron_right_rounded,
                      size: 18, color: tokens.primary.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ItemLayout {
  const _ItemLayout({
    required this.index,
    required this.x,
    required this.opacity,
    required this.scale,
    required this.selected,
  });

  final int index;
  final double x;
  final double opacity;
  final double scale;
  final bool selected;

  _ItemLayout copyWith(
      {double? x, double? opacity, double? scale, bool? selected}) {
    return _ItemLayout(
      index: index,
      x: x ?? this.x,
      opacity: opacity ?? this.opacity,
      scale: scale ?? this.scale,
      selected: selected ?? this.selected,
    );
  }
}

class DragToAdjustInput extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double sensitivity;
  final int decimalPlaces;
  final String suffix;
  final ValueChanged<double> onChanged;

  const DragToAdjustInput({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.sensitivity = 1.0,
    this.decimalPlaces = 1,
    this.suffix = '',
  });

  @override
  State<DragToAdjustInput> createState() => _DragToAdjustInputState();
}

class _DragToAdjustInputState extends State<DragToAdjustInput> with SingleTickerProviderStateMixin {
  bool _isDragging = false;
  bool _isEditing = false;
  bool _isHovered = false;
  double _dragDirection = 1.0;

  late TextEditingController _textController;
  late FocusNode _focusNode;
  late AnimationController _animationController;

  double get _minorStep {
    switch (widget.decimalPlaces) {
      case 0: return 1.0;
      case 1: return 0.1;
      case 2: return 0.01;
      case 3: return 0.001;
      default: return 1.0;
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _submitText();
    });

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _focusNode.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _submitText() {
    setState(() => _isEditing = false);
    double? parsed = double.tryParse(_textController.text);
    if (parsed != null) {
      widget.onChanged(parsed.clamp(widget.min, widget.max));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayValue = widget.value.toStringAsFixed(widget.decimalPlaces) + widget.suffix;
    final baseBoxColor = _isDragging ? const Color(0xFF222222) : const Color(0xFF2D2D2D);
    final activeColor = _isDragging || _isHovered ? const Color(0xFFFF8C00) : const Color(0xFF555555);

    if (_isEditing) {
      return Container(
        width: 115,
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: const Color(0xFFFF8C00), width: 1),
        ),
        child: TextField(
          controller: _textController,
          focusNode: _focusNode,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 11, color: Color(0xFFE0E0E0), fontFamily: 'monospace', fontWeight: FontWeight.w600),
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 6),
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _submitText(),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _isEditing = true;
          _textController.text = widget.value.toStringAsFixed(widget.decimalPlaces);
        });
      },
      onHorizontalDragStart: (_) {
        setState(() => _isDragging = true);
        _animationController.repeat();
      },
      onHorizontalDragUpdate: (details) {
        double delta = details.primaryDelta ?? 0;
        if (delta != 0) {
          setState(() {
            _dragDirection = delta > 0 ? 1.0 : -1.0;
          });
        }
        double newValue = widget.value + (delta * widget.sensitivity);
        widget.onChanged(newValue.clamp(widget.min, widget.max));
      },
      onHorizontalDragEnd: (_) {
        setState(() => _isDragging = false);
        _animationController.stop();
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 115,
          height: 28,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: baseBoxColor,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: _isDragging ? const Color(0xFFFF8C00) : const Color(0xFF333333),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              if (_isDragging)
                Positioned.fill(
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: RulerLinesPainter(
                          progress: _animationController.value,
                          direction: _dragDirection,
                        ),
                      );
                    },
                  ),
                ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onChanged((widget.value - _minorStep).clamp(widget.min, widget.max));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.chevron_left, color: activeColor, size: 12),
                  ),
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    widget.onChanged((widget.value + _minorStep).clamp(widget.min, widget.max));
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(Icons.chevron_right, color: activeColor, size: 12),
                  ),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: baseBoxColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 11,
                        color: _isDragging ? const Color(0xFFFF8C00) : const Color(0xFFE0E0E0),
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RulerLinesPainter extends CustomPainter {
  final double progress;
  final double direction;

  RulerLinesPainter({required this.progress, required this.direction});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF8C00).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    const double spacing = 6.0;
    const double tickHeight = 8.0;

    double totalOffset = progress * spacing * direction;
    double centerY = size.height / 2;

    for (double x = -spacing * 2; x < size.width + spacing * 2; x += spacing) {
      double currentX = x + totalOffset;
      canvas.drawLine(
        Offset(currentX, centerY - (tickHeight / 2)),
        Offset(currentX, centerY + (tickHeight / 2)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant RulerLinesPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.direction != direction;
  }
}
