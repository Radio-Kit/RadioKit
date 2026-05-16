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
