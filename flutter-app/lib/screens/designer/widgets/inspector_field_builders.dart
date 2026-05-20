import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

  static Widget buildReadOnlyField(RKTokens tokens, String label, String value) {
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
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D0D),
                border: Border.all(color: const Color(0xFF333333)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                value,
                style: const TextStyle(
                  color: Color(0xFFE0E0E0),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
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

  static Widget buildOptionSelector(RKTokens tokens, String label, String value, List<String> options, ValueChanged<String> onChanged, {Widget? suffix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF888888),
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                ...options.map((opt) {
                  final isSelected = opt == value;
                  return GestureDetector(
                    onTap: () => onChanged(opt),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                  );
                }),
                if (suffix != null) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: suffix,
                  ),
                ],
              ],
            ),
          ),
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

  static Widget buildRotationSlider(RKTokens tokens, double rotation, ValueChanged<double> onChanged, {VoidCallback? onReset}) {
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
              if (onReset != null) ...[
                GestureDetector(
                  onTap: onReset,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(LucideIcons.rotateCcw, size: 12, color: const Color(0xFF555555)),
                  ),
                ),
              ],
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
            child: _PopupMenuSelector(
              tokens: tokens,
              value: value,
              options: options,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PopupMenuSelector extends StatefulWidget {
  final RKTokens tokens;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  const _PopupMenuSelector({
    required this.tokens,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  State<_PopupMenuSelector> createState() => _PopupMenuSelectorState();
}

class _PopupMenuSelectorState extends State<_PopupMenuSelector> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = widget.tokens;
    final hoverBorderColor = tokens.primary.withValues(alpha: 0.5);
    final activeBorderColor = _isHovered ? hoverBorderColor : const Color(0xFF333333);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: PopupMenuButton<String>(
        tooltip: '',
        onSelected: widget.onChanged,
        offset: const Offset(0, 32),
        color: const Color(0xFF141414),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
          side: const BorderSide(color: Color(0xFF2C2C2C), width: 1),
        ),
        itemBuilder: (BuildContext context) {
          return widget.options.map((opt) {
            final isSelected = opt == widget.value;
            return PopupMenuItem<String>(
              value: opt,
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      opt.toUpperCase(),
                      style: TextStyle(
                        color: isSelected ? tokens.primary : const Color(0xFFC0C0C0),
                        fontSize: 11,
                        fontFamily: 'monospace',
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 14,
                      color: tokens.primary,
                    ),
                ],
              ),
            );
          }).toList();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            border: Border.all(color: activeBorderColor),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.value.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFFE0E0E0),
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.unfold_more_rounded,
                size: 14,
                color: _isHovered ? tokens.primary : const Color(0xFF888888),
              ),
            ],
          ),
        ),
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

// ── Icon picker infrastructure ────────────────────────────────────────────

/// Builds a compact icon selector — shows current icon or "NONE", opens picker on tap.
class IconFieldBuilder {
  static Widget buildIconSelectorField(
    BuildContext context,
    String label,
    String? currentIconName,
    ValueChanged<String?> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 11,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _openIconPicker(context, currentIconName, onChanged),
            child: Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                border: Border.all(color: const Color(0xFF333333)),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (currentIconName != null && kDesignerIcons.containsKey(currentIconName))
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        kDesignerIcons[currentIconName]!,
                        color: const Color(0xFFFF8C00),
                        size: 14,
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Text(
                        '—',
                        style: TextStyle(color: Color(0xFF555555), fontSize: 11, fontFamily: 'monospace'),
                      ),
                    ),
                  const Icon(LucideIcons.chevronDown, color: Color(0xFF666666), size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _openIconPicker(
    BuildContext context,
    String? currentIconName,
    ValueChanged<String?> onChanged,
  ) {
    showDialog(
      context: context,
      builder: (_) => _DesignerIconPicker(
        currentIconName: currentIconName,
        onIconSelected: onChanged,
      ),
    );
  }
}

class _DesignerIconPicker extends StatefulWidget {
  final String? currentIconName;
  final ValueChanged<String?> onIconSelected;

  const _DesignerIconPicker({
    required this.currentIconName,
    required this.onIconSelected,
  });

  @override
  State<_DesignerIconPicker> createState() => _DesignerIconPickerState();
}

class _DesignerIconPickerState extends State<_DesignerIconPicker> {
  String _search = '';

  List<String> get _filteredKeys {
    if (_search.isEmpty) return kDesignerIcons.keys.toList();
    return kDesignerIcons.keys
        .where((k) => k.toLowerCase().contains(_search.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final keys = _filteredKeys;

    return AlertDialog(
      backgroundColor: const Color(0xFF181818),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: TextField(
        onChanged: (v) => setState(() => _search = v),
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search icons...',
          hintStyle: TextStyle(color: Color(0xFF666666)),
          prefixIcon: Icon(LucideIcons.search, size: 16, color: Color(0xFF666666)),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
      content: SizedBox(
        width: 420,
        height: 400,
        child: Column(
          children: [
            const Divider(color: Color(0xFF222222)),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: keys.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    final isActive = widget.currentIconName == null;
                    return GestureDetector(
                      onTap: () {
                        widget.onIconSelected(null);
                        Navigator.pop(context);
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: isActive ? const Color(0xFF333333) : const Color(0xFF222222),
                          borderRadius: BorderRadius.circular(6),
                          border: isActive ? Border.all(color: const Color(0xFF888888), width: 1) : null,
                        ),
                        child: const Center(
                          child: Text(
                            '—',
                            style: TextStyle(color: Color(0xFF888888), fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    );
                  }
                  final key = keys[index - 1];
                  final icon = kDesignerIcons[key]!;
                  final isActive = widget.currentIconName == key;
                  return GestureDetector(
                    onTap: () {
                      widget.onIconSelected(key);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isActive ? const Color(0xFF333333) : const Color(0xFF222222),
                        borderRadius: BorderRadius.circular(6),
                        border: isActive ? Border.all(color: const Color(0xFFFF8C00), width: 1) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon, color: Colors.white, size: 18),
                          const SizedBox(height: 2),
                          Text(
                            key,
                            style: const TextStyle(color: Color(0xFF888888), fontSize: 7),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
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
