import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:simple_icons/simple_icons.dart';
import 'inspector_field_builders.dart';

class InspectorPanel extends StatelessWidget {
  const InspectorPanel({
    super.key,
    required this.selectedIndex,
    this.selfCentering,
    this.centerPosition,
    this.amplitude,
    this.resolution,
    this.minAngle,
    this.maxAngle,
    this.minValue,
    this.maxValue,
    this.springBehavior,
    this.springDuration,
    this.onSelfCenteringChanged,
    this.onCenterPositionChanged,
    this.onAmplitudeChanged,
    this.onResolutionChanged,
    this.onMinAngleChanged,
    this.onMaxAngleChanged,
    this.onMinValueChanged,
    this.onMaxValueChanged,
    this.onSpringBehaviorChanged,
    this.onSpringDurationChanged,
    this.onTextOnChanged,
    this.onTextOffChanged,
    this.onIconOnChanged,
    this.onIconOffChanged,
    this.hapticsEnabled = true,
    this.onHapticsChanged,
    this.textOn,
    this.textOff,
    this.iconOn,
    this.iconOff,
    this.orientation,
    this.onOrientationChanged,
    this.fontFamily,
    this.onFontFamilyChanged,
    this.multiItems,
    this.onMultiItemChanged,
    this.multiItemCount,
    this.onMultiItemCountChanged,
    this.ledState,
    this.onLEDStateChanged,
    this.ledShape,
    this.onLEDShapeChanged,
    this.ledTiming,
    this.onLEDTimingChanged,
    this.ledColor,
    this.onLEDColorChanged,
    this.rotation,
    this.onRotationChanged,
    this.label,
    this.onLabelChanged,
  });

  final int selectedIndex;
  final bool? selfCentering;
  final String? centerPosition;
  final String? springBehavior;
  final double? springDuration;
  final double? amplitude;
  final double? resolution;
  final double? minAngle;
  final double? maxAngle;
  final double? minValue;
  final double? maxValue;
  final ValueChanged<bool>? onSelfCenteringChanged;
  final ValueChanged<String>? onCenterPositionChanged;
  final ValueChanged<String>? onSpringBehaviorChanged;
  final ValueChanged<double>? onSpringDurationChanged;
  final ValueChanged<double>? onAmplitudeChanged;
  final ValueChanged<double>? onResolutionChanged;
  final ValueChanged<double>? onMinAngleChanged;
  final ValueChanged<double>? onMaxAngleChanged;
  final ValueChanged<double>? onMinValueChanged;
  final ValueChanged<double>? onMaxValueChanged;
  final String? textOn;
  final String? textOff;
  final IconData? iconOn;
  final IconData? iconOff;
  final bool hapticsEnabled;
  final ValueChanged<bool>? onHapticsChanged;
  final ValueChanged<String>? onTextOnChanged;
  final ValueChanged<String>? onTextOffChanged;
  final ValueChanged<IconData?>? onIconOnChanged;
  final ValueChanged<IconData?>? onIconOffChanged;
  final String? orientation;
  final ValueChanged<String>? onOrientationChanged;
  final String? fontFamily;
  final ValueChanged<String>? onFontFamilyChanged;
  final List<RKToggleItem>? multiItems;
  final void Function(int, RKToggleItem)? onMultiItemChanged;
  final int? multiItemCount;
  final ValueChanged<int>? onMultiItemCountChanged;
  final RKLEDState? ledState;
  final ValueChanged<RKLEDState>? onLEDStateChanged;
  final RKLEDShape? ledShape;
  final ValueChanged<RKLEDShape>? onLEDShapeChanged;
  final int? ledTiming;
  final ValueChanged<int>? onLEDTimingChanged;
  final Color? ledColor;
  final ValueChanged<Color>? onLEDColorChanged;
  final double? rotation;
  final ValueChanged<double>? onRotationChanged;
  final String? label;
  final ValueChanged<String>? onLabelChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    final isJoystick = selectedIndex == 5;
    final isSlider = selectedIndex == 3;
    final isKnob = selectedIndex == 4;
    final isSwitch = selectedIndex == 2;
    final isMultiple = selectedIndex == 1;
    final isLED = selectedIndex == 7;
    final isDisplay = selectedIndex == 6;
    final hasSelfCentering = isJoystick || isKnob || isSlider;

    return Container(
      width: 320,
      decoration: const BoxDecoration(
        color: Color(0xFF181818),
        border: Border(
          left: BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(tokens),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InspectorFieldBuilders.buildSection(tokens, 'VALUES', [
                    InspectorFieldBuilders.buildTextField(tokens, 'Widget Label', label ?? '', onLabelChanged ?? (_) {}),
                    const SizedBox(height: 12),
                    if (isJoystick) ...[
                      InspectorFieldBuilders.buildDoubleField(tokens, 'Amplitude', amplitude ?? 100, onAmplitudeChanged ?? (_) {}, min: 0, max: 500, decimalPlaces: 0),
                    ] else if (isLED) ...[
                      _buildShapeSelector(tokens, ledShape ?? RKLEDShape.circle, onLEDShapeChanged ?? (_) {}),
                      const SizedBox(height: 12),
                      InspectorFieldBuilders.buildNumField(tokens, 'Timing (ms)', ledTiming ?? 500, (v) => onLEDTimingChanged?.call(v), min: 0, max: 5000),
                      const SizedBox(height: 12),
                      _buildColorSelector(context, tokens, 'LED Color', ledColor ?? tokens.primary, onLEDColorChanged ?? (_) {}),
                    ] else if (isSlider || isKnob) ...[
                      Row(
                        children: [
                          Expanded(child: InspectorFieldBuilders.buildDoubleField(tokens, 'Min', minValue ?? 0, onMinValueChanged ?? (_) {}, decimalPlaces: 0)),
                          const SizedBox(width: 8),
                          Expanded(child: InspectorFieldBuilders.buildDoubleField(tokens, 'Max', maxValue ?? 100, onMaxValueChanged ?? (_) {}, decimalPlaces: 0)),
                        ],
                      ),
                      if (isKnob) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: InspectorFieldBuilders.buildDoubleField(tokens, 'Min Angle', minAngle ?? -135, onMinAngleChanged ?? (_) {}, min: -360, max: 0, decimalPlaces: 0)),
                            const SizedBox(width: 8),
                            Expanded(child: InspectorFieldBuilders.buildDoubleField(tokens, 'Max Angle', maxAngle ?? 135, onMaxAngleChanged ?? (_) {}, min: 0, max: 360, decimalPlaces: 0)),
                          ],
                        ),
                      ],
                    ],
                    if (isJoystick || isKnob || isSlider) ...[
                      const SizedBox(height: 12),
                      InspectorFieldBuilders.buildDoubleField(tokens, 'Resolution', resolution ?? 1, (v) => onResolutionChanged?.call(v < 0.1 ? 0.1 : v), min: 0.1, max: 100, decimalPlaces: 1),
                    ],
                    if (isSlider) ...[
                      const SizedBox(height: 12),
                      InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Orientation', orientation ?? 'vertical', ['horizontal', 'vertical'], (v) => onOrientationChanged?.call(v)),
                    ],
                  ]),
                  if (isSwitch || selectedIndex == 0 || isMultiple || selectedIndex == 6 || isKnob) ...[
                    InspectorFieldBuilders.buildSection(tokens, 'CONTENT', [
                      if (isMultiple) ...[
                        InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Count', (multiItemCount ?? 4).toString(), ['1', '2', '3', '4', '5', '6', '7', '8'], (v) => onMultiItemCountChanged?.call(int.parse(v))),
                        const SizedBox(height: 8),
                        InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Orientation', orientation ?? 'horizontal', ['horizontal', 'vertical'], (v) => onOrientationChanged?.call(v)),
                        const SizedBox(height: 12),
                        _buildMultiItemEditor(context, tokens),
                      ] else if (isSwitch || selectedIndex == 0) ...[
                        Row(
                          children: [
                            Expanded(child: InspectorFieldBuilders.buildTextField(tokens, 'ON Text', textOn ?? 'ON', onTextOnChanged ?? (_) {})),
                            const SizedBox(width: 8),
                            Expanded(child: _buildIconSelector(context, tokens, 'ON Icon', iconOn, onIconOnChanged ?? (_) {})),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(child: InspectorFieldBuilders.buildTextField(tokens, 'OFF Text', textOff ?? 'OFF', onTextOffChanged ?? (_) {})),
                            const SizedBox(width: 8),
                            Expanded(child: _buildIconSelector(context, tokens, 'OFF Icon', iconOff, onIconOffChanged ?? (_) {})),
                          ],
                        ),
                      ] else if (selectedIndex == 6) ...[
                        _buildFontDropdown(tokens, 'Font Family', ['monospace', 'serif', 'sans-serif', 'Inter', 'Roboto', 'Outfit', 'Lexend'], fontFamily ?? 'monospace', onFontFamilyChanged ?? (_) {}),
                      ] else if (isKnob) ...[
                        _buildIconSelector(context, tokens, 'Center Icon', iconOn, onIconOnChanged ?? (_) {}),
                      ],
                      if (selectedIndex != 6 && !isMultiple && !isLED) ...[
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 20),
                          child: Text('Leave empty for minimal look', style: TextStyle(color: Color(0xFF555555), fontSize: 9, fontStyle: FontStyle.italic)),
                        ),
                      ],
                    ]),
                  ],
                  InspectorFieldBuilders.buildSection(tokens, 'BEHAVIOR', [
                    if (hasSelfCentering) ...[
                      InspectorFieldBuilders.buildBoolToggle(tokens, 'AutoCenter', selfCentering ?? true, onSelfCenteringChanged ?? (_) {}),
                      if (selfCentering ?? true) ...[
                        const SizedBox(height: 8),
                        InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Center Pos', centerPosition ?? 'center', isSlider ? ['min', 'max', 'center'] : isKnob ? ['min', 'max', 'center'] : ['left', 'right', 'top', 'bottom', 'center'], onCenterPositionChanged ?? (_) {}),
                        const SizedBox(height: 8),
                        InspectorFieldBuilders.buildCenterPinnedSelector(tokens, 'Spring', springBehavior ?? 'elastic', ['elastic', 'smooth', 'linear'], onSpringBehaviorChanged ?? (_) {}),
                        const SizedBox(height: 8),
                        InspectorFieldBuilders.buildNumField(tokens, 'Dur. (ms)', (springDuration ?? 300).toInt(), (v) => onSpringDurationChanged?.call(v.toDouble()), min: 0, max: 2000),
                      ],
                    ] else if (!isDisplay && !isLED) ...[
                      InspectorFieldBuilders.buildBoolToggle(tokens, 'Haptics', hapticsEnabled, onHapticsChanged ?? (_) {}),
                    ],
                  ]),
                  InspectorFieldBuilders.buildSection(tokens, 'TRANSFORM', [
                    InspectorFieldBuilders.buildRotationSlider(tokens, rotation ?? 0.0, onRotationChanged ?? (_) {}),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(RKTokens tokens) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Icon(LucideIcons.list, color: tokens.primary, size: 20),
          const SizedBox(width: 10),
          const Text(
            'CONFIGURATION',
            style: TextStyle(
              color: Color(0xFFE0E0E0),
              fontSize: 14,
              fontFamily: 'monospace',
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMultiItemEditor(BuildContext context, RKTokens tokens) {
    return _MultiItemEditor(
      items: multiItems ?? [],
      onItemChanged: onMultiItemChanged ?? (i, item) {},
      tokens: tokens,
    );
  }

  Widget _buildIconSelector(BuildContext context, RKTokens tokens, String label, IconData? currentIcon, ValueChanged<IconData?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF666666), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => _IconPicker(onIconSelected: onChanged),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                if (currentIcon != null) ...[
                  Icon(currentIcon, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                ] else
                  const Text('NONE', style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
                const Icon(LucideIcons.chevronDown, color: Color(0xFF666666), size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelector(BuildContext context, RKTokens tokens, String label, Color currentColor, ValueChanged<Color> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF666666), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            showDialog(
              context: context,
              builder: (context) => _ColorPicker(initialColor: currentColor, onColorSelected: onChanged),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF222222),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: currentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '#${currentColor.toARGB32().toRadixString(16).toUpperCase().substring(2)}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontFamily: 'monospace'),
                ),
                const Icon(LucideIcons.chevronDown, color: Color(0xFF666666), size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShapeSelector(RKTokens tokens, RKLEDShape current, ValueChanged<RKLEDShape> onChanged) {
    final shapes = {
      RKLEDShape.circle: Icons.circle,
      RKLEDShape.square: Icons.square,
      RKLEDShape.diamond: Icons.diamond,
      RKLEDShape.star: Icons.star,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('SHAPE', style: TextStyle(color: Color(0xFF888888), fontSize: 10, fontFamily: 'monospace', letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: shapes.entries.map((entry) {
            final isSelected = current == entry.key;
            return GestureDetector(
              onTap: () => onChanged(entry.key),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected ? tokens.primary : const Color(0xFF1A1A1A),
                  border: Border.all(
                    color: isSelected ? tokens.primary : const Color(0xFF444444),
                    width: 1,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  entry.value,
                  size: 20,
                  color: isSelected ? Colors.black : const Color(0xFF888888),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFontDropdown(RKTokens tokens, String label, List<String> options, String current, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF888888), fontSize: 10, fontFamily: 'monospace', letterSpacing: 0.5)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: const Color(0xFF444444), width: 1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: current,
                dropdownColor: const Color(0xFF1A1A1A),
                icon: const Icon(LucideIcons.chevronDown, color: Color(0xFF666666), size: 14),
                isExpanded: true,
                style: const TextStyle(color: Color(0xFFD0D0D0), fontSize: 12, fontFamily: 'monospace'),
                onChanged: (String? newValue) {
                  if (newValue != null) onChanged(newValue);
                },
                items: options.map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(value: value, child: Text(value));
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IconPicker extends StatefulWidget {
  const _IconPicker({required this.onIconSelected});
  final ValueChanged<IconData?> onIconSelected;

  @override
  State<_IconPicker> createState() => _IconPickerState();
}

class _IconPickerState extends State<_IconPicker> {
  String _search = '';

  static const Map<String, IconData> _allIcons = {
    'sun': LucideIcons.sun, 'moon': LucideIcons.moon, 'zap': LucideIcons.zap,
    'zap-off': LucideIcons.zapOff, 'power': LucideIcons.power, 'radio': LucideIcons.radio,
    'cpu': LucideIcons.cpu, 'battery': LucideIcons.battery, 'battery-charging': LucideIcons.batteryCharging,
    'thermometer': LucideIcons.thermometer, 'gauge': LucideIcons.gauge, 'activity': LucideIcons.activity,
    'check': LucideIcons.check, 'x': LucideIcons.x, 'lock': LucideIcons.lock,
    'unlock': LucideIcons.lockOpen, 'lightbulb': LucideIcons.lightbulb, 'fan': LucideIcons.fan,
    'mic': LucideIcons.mic, 'speaker': LucideIcons.speaker, 'volume-2': LucideIcons.volume2,
    'wifi': LucideIcons.wifi, 'bluetooth': LucideIcons.bluetooth, 'usb': LucideIcons.usb,
    'settings': LucideIcons.settings, 'settings-2': LucideIcons.settings2, 'cog': LucideIcons.cog,
    'wrench': LucideIcons.wrench, 'hammer': LucideIcons.hammer, 'drill': LucideIcons.drill,
    'save': LucideIcons.save, 'upload': LucideIcons.upload, 'download': LucideIcons.download,
    'acura': SimpleIcons.acura, 'amg': SimpleIcons.amg, 'astonmartin': SimpleIcons.astonmartin,
    'audi': SimpleIcons.audi, 'bentley': SimpleIcons.bentley, 'bmw': SimpleIcons.bmw,
    'bugatti': SimpleIcons.bugatti, 'cadillac': SimpleIcons.cadillac, 'chevrolet': SimpleIcons.chevrolet,
    'chrysler': SimpleIcons.chrysler, 'citroen': SimpleIcons.citroen, 'dacia': SimpleIcons.dacia,
    'dsautomobiles': SimpleIcons.dsautomobiles, 'ducati': SimpleIcons.ducati, 'ferrari': SimpleIcons.ferrari,
    'fiat': SimpleIcons.fiat, 'ford': SimpleIcons.ford, 'honda': SimpleIcons.honda,
    'hyundai': SimpleIcons.hyundai, 'infiniti': SimpleIcons.infiniti, 'jeep': SimpleIcons.jeep,
    'kia': SimpleIcons.kia, 'koenigsegg': SimpleIcons.koenigsegg, 'ktm': SimpleIcons.ktm,
    'lada': SimpleIcons.lada, 'lamborghini': SimpleIcons.lamborghini, 'mahindra': SimpleIcons.mahindra,
    'maserati': SimpleIcons.maserati, 'mazda': SimpleIcons.mazda, 'mclaren': SimpleIcons.mclaren,
    'mg': SimpleIcons.mg, 'mini': SimpleIcons.mini, 'mitsubishi': SimpleIcons.mitsubishi,
    'nissan': SimpleIcons.nissan, 'opel': SimpleIcons.opel, 'peugeot': SimpleIcons.peugeot,
    'polestar': SimpleIcons.polestar, 'porsche': SimpleIcons.porsche, 'ram': SimpleIcons.ram,
    'renault': SimpleIcons.renault, 'rimacautomobili': SimpleIcons.rimacautomobili,
    'rollsroyce': SimpleIcons.rollsroyce, 'scania': SimpleIcons.scania, 'seat': SimpleIcons.seat,
    'skoda': SimpleIcons.skoda, 'smart': SimpleIcons.smart, 'subaru': SimpleIcons.subaru,
    'suzuki': SimpleIcons.suzuki, 'tata': SimpleIcons.tata, 'tesla': SimpleIcons.tesla,
    'toyota': SimpleIcons.toyota, 'vauxhall': SimpleIcons.vauxhall, 'volkswagen': SimpleIcons.volkswagen,
    'volvo': SimpleIcons.volvo, 'aral': SimpleIcons.aral, 'autozone': SimpleIcons.autozone,
    'bosch': SimpleIcons.bosch, 'carthrottle': SimpleIcons.carthrottle, 'caterpillar': SimpleIcons.caterpillar,
    'daf': SimpleIcons.daf, 'generalmotors': SimpleIcons.generalmotors, 'iveco': SimpleIcons.iveco,
    'johndeere': SimpleIcons.johndeere, 'man': SimpleIcons.man, 'onstar': SimpleIcons.onstar,
    'oshkosh': SimpleIcons.oshkosh,
  };

  @override
  Widget build(BuildContext context) {
    final filteredKeys = _allIcons.keys.where((k) => k.toLowerCase().contains(_search.toLowerCase())).toList();

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Material(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 400,
          height: 500,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Search icons...',
                  hintStyle: TextStyle(color: Color(0xFF666666)),
                  prefixIcon: Icon(LucideIcons.search, size: 16, color: Color(0xFF666666)),
                  border: InputBorder.none,
                ),
              ),
              const Divider(color: Color(0xFF222222)),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                  ),
                  itemCount: filteredKeys.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return GestureDetector(
                        onTap: () { widget.onIconSelected(null); Navigator.pop(context); },
                        child: Container(
                          decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(8)),
                          child: const Center(child: Text('NONE', style: TextStyle(color: Color(0xFF666666), fontSize: 10))),
                        ),
                      );
                    }
                    final key = filteredKeys[index - 1];
                    final icon = _allIcons[key]!;
                    return GestureDetector(
                      onTap: () { widget.onIconSelected(icon); Navigator.pop(context); },
                      child: Container(
                        decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(8)),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(icon, color: Colors.white, size: 20),
                            const SizedBox(height: 4),
                            Text(key, style: const TextStyle(color: Color(0xFF888888), fontSize: 8), overflow: TextOverflow.ellipsis),
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
      ),
    );
  }
}

class _ColorPicker extends StatefulWidget {
  const _ColorPicker({required this.initialColor, required this.onColorSelected});
  final Color initialColor;
  final ValueChanged<Color> onColorSelected;

  @override
  State<_ColorPicker> createState() => _ColorPickerState();
}

class _ColorPickerState extends State<_ColorPicker> {
  late Color _currentColor;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialColor;
  }

  void _updateColor(Color color) {
    setState(() => _currentColor = color);
    widget.onColorSelected(color);
  }

  static const List<Color> _brandColors = [
    Color(0xFFFF8C00), Color(0xFF00D1FF), Color(0xFF00FF94),
    Color(0xFFFF005C), Color(0xFF8B5CF6), Color(0xFFFACC15),
    Color(0xFFFFFFFF), Color(0xFF888888), Color(0xFF444444), Color(0xFF111111),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Material(
        color: const Color(0xFF181818),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 300,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('COLOR PICKER', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _currentColor,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('HEX VALUE', style: TextStyle(color: Color(0xFF666666), fontSize: 9, fontWeight: FontWeight.bold)),
                      Text('#${_currentColor.toARGB32().toRadixString(16).toUpperCase().substring(2)}', style: const TextStyle(color: Colors.white, fontSize: 16, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildRGBSlider('RED', (_currentColor.r * 255).round(), (v) {
                _updateColor(Color.fromARGB((_currentColor.a * 255).round(), v, (_currentColor.g * 255).round(), (_currentColor.b * 255).round()));
              }),
              const SizedBox(height: 12),
              _buildRGBSlider('GREEN', (_currentColor.g * 255).round(), (v) {
                _updateColor(Color.fromARGB((_currentColor.a * 255).round(), (_currentColor.r * 255).round(), v, (_currentColor.b * 255).round()));
              }),
              const SizedBox(height: 12),
              _buildRGBSlider('BLUE', (_currentColor.b * 255).round(), (v) {
                _updateColor(Color.fromARGB((_currentColor.a * 255).round(), (_currentColor.r * 255).round(), (_currentColor.g * 255).round(), v));
              }),
              const SizedBox(height: 24),
              const Text('PRESETS', style: TextStyle(color: Color(0xFF666666), fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _brandColors.map((color) {
                  return GestureDetector(
                    onTap: () => _updateColor(color),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: color == _currentColor ? Colors.white : Colors.transparent, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF222222),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                  ),
                  child: const Text('DONE'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRGBSlider(String label, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Color(0xFF888888), fontSize: 9, fontFamily: 'monospace')),
            Text(value.toString(), style: const TextStyle(color: Colors.white, fontSize: 9, fontFamily: 'monospace')),
          ],
        ),
        SliderTheme(
          data: const SliderThemeData(
            trackHeight: 2,
            activeTrackColor: Colors.white24,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(value: value.toDouble(), min: 0, max: 255, onChanged: (v) => onChanged(v.toInt())),
        ),
      ],
    );
  }
}

class _MultiItemEditor extends StatefulWidget {
  const _MultiItemEditor({required this.items, required this.onItemChanged, required this.tokens});
  final List<RKToggleItem> items;
  final void Function(int, RKToggleItem) onItemChanged;
  final RKTokens tokens;

  @override
  State<_MultiItemEditor> createState() => _MultiItemEditorState();
}

class _MultiItemEditorState extends State<_MultiItemEditor> {
  int _editingIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) return const SizedBox.shrink();
    if (_editingIndex >= widget.items.length) _editingIndex = 0;

    final item = widget.items[_editingIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_rounded, color: widget.tokens.primary, size: 14),
            const SizedBox(width: 8),
            const Text('EDIT BUTTON', style: TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: List.generate(widget.items.length, (i) {
              final active = _editingIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _editingIndex = i),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: active ? widget.tokens.primary : const Color(0xFF222222),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Center(
                    child: Text('${i + 1}', style: TextStyle(color: active ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
        _buildItemFieldRow(context, 'ON State', item.onLabel ?? '', item.onIcon,
            (val) => widget.onItemChanged(_editingIndex, RKToggleItem(onLabel: val, offLabel: item.offLabel, onIcon: item.onIcon, offIcon: item.offIcon)),
            (icon) => widget.onItemChanged(_editingIndex, RKToggleItem(onLabel: item.onLabel, offLabel: item.offLabel, onIcon: icon, offIcon: item.offIcon))),
        const SizedBox(height: 16),
        _buildItemFieldRow(context, 'OFF State', item.offLabel ?? '', item.offIcon,
            (val) => widget.onItemChanged(_editingIndex, RKToggleItem(onLabel: item.onLabel, offLabel: val, onIcon: item.onIcon, offIcon: item.offIcon)),
            (icon) => widget.onItemChanged(_editingIndex, RKToggleItem(onLabel: item.onLabel, offLabel: item.offLabel, onIcon: item.onIcon, offIcon: icon))),
      ],
    );
  }

  Widget _buildItemFieldRow(BuildContext context, String label, String text, IconData? icon, ValueChanged<String> onTextChanged, ValueChanged<IconData?> onIconChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF666666), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _InspectorTextField(label: 'Text', value: text, onChanged: onTextChanged)),
            const SizedBox(width: 12),
            Expanded(child: _InspectorIconSelector(context: context, label: 'Icon', currentIcon: icon, onChanged: onIconChanged)),
          ],
        ),
      ],
    );
  }
}

class _InspectorIconSelector extends StatelessWidget {
  const _InspectorIconSelector({required this.context, required this.label, required this.currentIcon, required this.onChanged});
  final BuildContext context;
  final String label;
  final IconData? currentIcon;
  final ValueChanged<IconData?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: const TextStyle(color: Color(0xFF555555), fontSize: 9, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () {
            showDialog(context: context, builder: (context) => _IconPicker(onIconSelected: onChanged));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(color: const Color(0xFF222222), borderRadius: BorderRadius.circular(4)),
            child: Row(
              children: [
                if (currentIcon != null) ...[Icon(currentIcon, color: Colors.white, size: 16)] else const Text('NONE', style: TextStyle(color: Color(0xFF666666), fontSize: 10)),
                const Icon(LucideIcons.chevronDown, color: Color(0xFF666666), size: 14),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InspectorTextField extends StatefulWidget {
  const _InspectorTextField({required this.label, required this.value, required this.onChanged});
  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  State<_InspectorTextField> createState() => _InspectorTextFieldState();
}

class _InspectorTextFieldState extends State<_InspectorTextField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(_InspectorTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.fromPosition(TextPosition(offset: _controller.text.length));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.label, style: const TextStyle(color: Color(0xFF666666), fontSize: 10, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 12),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: const Color(0xFF222222),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}
