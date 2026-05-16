import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../theme/app_theme.dart';

import '../widgets/demo_card.dart';
import '../widgets/inspector_panel.dart';
import '../widgets/left_sidebar.dart';

class DemoScreen extends StatefulWidget {
  const DemoScreen({Key? key, required this.selectedIndex}) : super(key: key);

  final int selectedIndex;

  @override
  State<DemoScreen> createState() => _DemoScreenState();
}

class _DemoScreenState extends State<DemoScreen> {
  // ─── State persistence ───
  final _pushState = ValueNotifier<bool>(false);
  final _pushActive = ValueNotifier<bool>(false);
  final _toggleState = ValueNotifier<bool>(false);
  final _toggleActive = ValueNotifier<bool>(false);
  final _slideState = ValueNotifier<bool>(false);
  final _rockerState = ValueNotifier<bool>(false);
  final _sliderState = ValueNotifier<double>(0.5);
  final _knobState = ValueNotifier<double>(0.42);
  final _ledState = ValueNotifier<bool>(false);
  final _sliderActive = ValueNotifier<bool>(false);
  final _knobActive = ValueNotifier<bool>(false);
  final _wheelState = ValueNotifier<double>(0.5);
  final _wheelActive = ValueNotifier<bool>(false);
  final _slideActive = ValueNotifier<bool>(false);
  final _rockerActive = ValueNotifier<bool>(false);
  final _pedalState = ValueNotifier<double>(0.0);
  final _pedalActive = ValueNotifier<bool>(false);
  final _displayActive = ValueNotifier<bool>(false);
  final _serialActive = ValueNotifier<bool>(false);
  String _widgetLabel = '';

  double _rotation = 0.0;

  // ─── Slider live state ───
  bool _sliderAutoCenter = true;
  String _sliderCenterPos = 'min';
  String _sliderSpringBehavior = 'smooth';
  double _sliderSpringDuration = 300;
  double _sliderMin = 0.0;
  double _sliderMax = 100.0;
  double _sliderResolution = 1.0;
  String _sliderOrientation = 'vertical';
  String _multiOrientation = 'horizontal';

  // ─── Switch live state ───
  String _switchOnText = 'ON';
  String _switchOffText = 'OFF';
  IconData? _switchOnIcon = LucideIcons.sun;
  IconData? _switchOffIcon = LucideIcons.moon;

  // ─── Knob live state ───
  bool _knobAutoCenter = false;
  String _knobCenterPos = 'center';
  String _knobSpringBehavior = 'smooth';
  double _knobSpringDuration = 500;
  double _knobMinAngle = -135.0;
  double _knobMaxAngle = 135.0;
  double _knobMin = -100.0;
  double _knobMax = 100.0;
  double _knobResolution = 1.0;

  String _knobOrientation = 'vertical';


  // ─── Display live state ───
  String _displayFont = 'monospace';
  final List<String> _serialMessages = ['> SYS: Booting...', '> SYS: Online'];
  final _displayText = ValueNotifier<String>('RADIOKIT');
  final _serialInput = ValueNotifier<String>('');

  bool _hapticsEnabled = true;

  int _multiButtonValue = 0;
  int _multiSelectBitmask = 0;
   int _lastMultiSelectIndex = -1;
  bool _multiButtonActive = false;
  bool _multiSelectActive = false;

  List<RKToggleItem> _multiItems = [
    const RKToggleItem(onLabel: 'OFF', onIcon: Icons.power_settings_new_rounded),
    const RKToggleItem(onLabel: 'LOW', onIcon: Icons.battery_1_bar_rounded),
    const RKToggleItem(onLabel: 'MID', onIcon: Icons.battery_3_bar_rounded),
    const RKToggleItem(onLabel: 'HIGH', onIcon: Icons.battery_5_bar_rounded),
    const RKToggleItem(onLabel: 'MAX', onIcon: Icons.bolt_rounded),
  ];

  // ─── Joystick live state ───
  final _joyState = ValueNotifier<RKJoystickValue>(const RKJoystickValue());
  bool _joySelfCentering = true;
  String _joyCenterPosition = 'center';
  String _joySpringBehavior = 'smooth';
  double _joySpringDuration = 100;
  double _joyAmplitude = 100;
  double _joyResolution = 1;

  // ─── LED live state ───
  RKLEDState _ledOpState = RKLEDState.off;
  RKLEDShape _ledShape = RKLEDShape.circle;
  int _ledTiming = 500;
  Color? _ledColor;

  Timer? _serialTimer;

  @override
  void initState() {
    super.initState();
    _serialTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && widget.selectedIndex == 6) {
        setState(() {
          _serialMessages.add('> MSG: ${DateTime.now().toIso8601String().substring(11, 23)}');
        });
      }
    });
  }

  @override
  void didUpdateWidget(DemoScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset logic here if needed
  }

  @override
  void dispose() {
    _pushState.dispose();
    _pushActive.dispose();
    _toggleState.dispose();
    _toggleActive.dispose();
    _slideState.dispose();
    _rockerState.dispose();
    _sliderState.dispose();
    _knobState.dispose();
    _ledState.dispose();
    _joyState.dispose();
    _sliderActive.dispose();
    _knobActive.dispose();
    _wheelState.dispose();
    _wheelActive.dispose();
    _slideActive.dispose();
    _rockerActive.dispose();
    _displayText.dispose();
    _serialInput.dispose();
    _displayActive.dispose();
    _serialActive.dispose();
    _serialTimer?.cancel();
    super.dispose();
  }

  Curve _getCurve(String behavior) {
    switch (behavior) {
      case 'linear': return Curves.linear;
      case 'smooth': return Curves.easeOutCubic;
      case 'elastic': return Curves.elasticOut;
      default: return Curves.linear;
    }
  }

  /// Scale raw [-1,1] joystick value by amplitude and snap to resolution.
  double _scaleJoystick(double raw) {
    final scaled = raw * _joyAmplitude;
    if (_joyResolution <= 0) return scaled;
    return (scaled / _joyResolution).round() * _joyResolution;
  }

  /// Compute decimal places needed to display a given resolution faithfully.
  static int _decimalPlaces(double value) {
    String s = value.toStringAsFixed(10);
    s = s.replaceAll(RegExp(r'0+$'), '');
    final dot = s.indexOf('.');
    if (dot == -1) return 0;
    return s.length - dot - 1;
  }

  Widget _buildBooleanInput(bool value, ValueChanged<bool> onChanged) {
    final tokens = RKTheme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSimpleToggleBtn('0', !value, () => onChanged(false), tokens),
        const SizedBox(width: 8),
        _buildSimpleToggleBtn('1', value, () => onChanged(true), tokens),
      ],
    );
  }

  Widget _buildSimpleToggleBtn(String label, bool active, VoidCallback onTap, RKTokens tokens) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: active ? tokens.primary : const Color(0xFF222222),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.black : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Left sidebar ───
          LeftSidebar(selectedIndex: widget.selectedIndex),

          // ─── Main area ───
          Expanded(
            child: Column(
              children: [
                // Top nav bar (title + deploy)
                const _TopBar(title: 'RADIOKIT // WIDGET PLAYGROUND'),

                // Aesthetic core tabs
                _AestheticCoreBar(),

                // Scrollable card grid
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1000),
                      child: Column(
                        children: _buildDemoCards(context),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ─── Right inspector ───
          InspectorPanel(
            selectedIndex: widget.selectedIndex,
            // Centering behavior (shared props)
            selfCentering: widget.selectedIndex == 5 
              ? _joySelfCentering 
              : widget.selectedIndex == 4
                ? _knobAutoCenter
                : _sliderAutoCenter,
            centerPosition: widget.selectedIndex == 5 
              ? _joyCenterPosition 
              : widget.selectedIndex == 4
                ? _knobCenterPos
                : _sliderCenterPos,
            
            // Values
            amplitude: _joyAmplitude,
            resolution: widget.selectedIndex == 5 
              ? _joyResolution 
              : widget.selectedIndex == 4
                ? _knobResolution
                : _sliderResolution,
            minAngle: _knobMinAngle,
            maxAngle: _knobMaxAngle,
            minValue: widget.selectedIndex == 4 ? _knobMin : _sliderMin,
            maxValue: widget.selectedIndex == 4 ? _knobMax : _sliderMax,
            
            onSelfCenteringChanged: (v) => setState(() {
              if (widget.selectedIndex == 5) _joySelfCentering = v;
              else if (widget.selectedIndex == 4) _knobAutoCenter = v;
              else _sliderAutoCenter = v;
            }),
            onCenterPositionChanged: (v) => setState(() {
              if (widget.selectedIndex == 5) _joyCenterPosition = v;
              else if (widget.selectedIndex == 4) _knobCenterPos = v;
              else _sliderCenterPos = v;
            }),
            onAmplitudeChanged: (v) => setState(() => _joyAmplitude = v),
            onResolutionChanged: (v) => setState(() {
              if (widget.selectedIndex == 5) _joyResolution = v;
              else if (widget.selectedIndex == 4) _knobResolution = v;
              else _sliderResolution = v;
            }),
            onMinAngleChanged: (v) => setState(() => _knobMinAngle = v),
            onMaxAngleChanged: (v) => setState(() => _knobMaxAngle = v),
            onMinValueChanged: (v) => setState(() {
              if (widget.selectedIndex == 4) _knobMin = v;
              else _sliderMin = v;
            }),
            onMaxValueChanged: (v) => setState(() {
              if (widget.selectedIndex == 4) _knobMax = v;
              else _sliderMax = v;
            }),
            springBehavior: widget.selectedIndex == 5 ? _joySpringBehavior : widget.selectedIndex == 4 ? _knobSpringBehavior : _sliderSpringBehavior,
            springDuration: widget.selectedIndex == 5 ? _joySpringDuration : widget.selectedIndex == 4 ? _knobSpringDuration : _sliderSpringDuration,
            onSpringBehaviorChanged: (v) => setState(() {
              if (widget.selectedIndex == 5) _joySpringBehavior = v;
              else if (widget.selectedIndex == 4) _knobSpringBehavior = v;
              else _sliderSpringBehavior = v;
            }),
            onSpringDurationChanged: (v) => setState(() {
              if (widget.selectedIndex == 5) _joySpringDuration = v;
              else if (widget.selectedIndex == 4) _knobSpringDuration = v;
              else _sliderSpringDuration = v;
            }),

            orientation: widget.selectedIndex == 3 ? _sliderOrientation :
                        widget.selectedIndex == 1 ? _multiOrientation : null,
            onOrientationChanged: (v) => setState(() {
              if (widget.selectedIndex == 3) _sliderOrientation = v;
              else if (widget.selectedIndex == 1) _multiOrientation = v;
            }),

            // Switch Content
            textOn: _switchOnText,
            textOff: _switchOffText,
            iconOn: _switchOnIcon,
            iconOff: _switchOffIcon,
            onTextOnChanged: (v) => setState(() => _switchOnText = v),
            onTextOffChanged: (v) => setState(() => _switchOffText = v),
            onIconOnChanged: (v) => setState(() => _switchOnIcon = v),
            onIconOffChanged: (v) => setState(() => _switchOffIcon = v),
            hapticsEnabled: _hapticsEnabled,
            onHapticsChanged: (v) => setState(() => _hapticsEnabled = v),
            fontFamily: _displayFont,
            onFontFamilyChanged: (v) => setState(() => _displayFont = v),

            
            // Multiple config
            multiItemCount: _multiItems.length,
            onMultiItemCountChanged: (count) => setState(() {
              if (count > _multiItems.length) {
                _multiItems.addAll(List.generate(count - _multiItems.length, (i) => const RKToggleItem(onLabel: 'NEW', onIcon: Icons.add_rounded)));
              } else if (count < _multiItems.length) {
                _multiItems.removeRange(count, _multiItems.length);
              }
            }),
            multiItems: _multiItems,
            onMultiItemChanged: (index, item) => setState(() {
              _multiItems[index] = item;
            }),

            // LED Config
            ledState: _ledOpState,
            onLEDStateChanged: (v) => setState(() => _ledOpState = v),
            ledShape: _ledShape,
            onLEDShapeChanged: (v) => setState(() => _ledShape = v),
            ledTiming: _ledTiming,
            onLEDTimingChanged: (v) => setState(() => _ledTiming = v),
            ledColor: _ledColor,
            onLEDColorChanged: (v) => setState(() => _ledColor = v),
            rotation: _rotation,
            onRotationChanged: (v) => setState(() => _rotation = v),
            label: _widgetLabel,
            onLabelChanged: (v) => setState(() => _widgetLabel = v),
          ),

        ],
      ),
    );
  }

  double _getKnobCenter(String pos) {
    switch (pos) {
      case 'min':   return 0.0;
      case 'max':   return 1.0;
      default:      return 0.5;
    }
  }

  List<Widget> _buildDemoCards(BuildContext context) {
    switch (widget.selectedIndex) {
      case 0:
        return _buttonCards(context);
      case 1:
        return _multipleCards();
      case 2:
        return _switchCards();
      case 3:
        return _sliderCards();
      case 4:
        return _knobCards();
      case 5:
        return _joystickCards();
      case 6:
        return _displayCards();
      case 7:
        return _ledCards();
      default:
        return [];
    }
  }

  List<Widget> _buttonCards(BuildContext context) {
    final tokens = RKTheme.of(context);
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<bool>(
              valueListenable: _pushState,
              builder: (context, value, _) {
                return DemoCard(
                  index: 1,
                  title: 'PUSH BUTTON',
                  liveWidget: RKButton(
                    onText: _switchOnText,
                    offText: _switchOffText,
                    onIcon: _switchOnIcon,
                    offIcon: _switchOffIcon,
                    mode: RKButtonMode.push,
                    size: 120,
                    onChanged: (v) => _pushState.value = v,
                    onInteractionChanged: (v) => _pushActive.value = v,
                    enableHapticFeedback: _hapticsEnabled,
                    label: _widgetLabel,
                    rotation: _rotation * math.pi / 180,
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: _buildBooleanInput(value, (v) => _pushState.value = v),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _pushActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(label: 'VALUE', value: value.toString().toUpperCase()),
                      const TelemetryRow(label: 'MODE', value: 'PUSH'),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<bool>(
              valueListenable: _toggleState,
              builder: (context, value, _) {
                return DemoCard(
                  index: 2,
                  title: 'TOGGLE BUTTON',
                  liveWidget: RKButton(
                    onText: _switchOnText,
                    offText: _switchOffText,
                    onIcon: _switchOnIcon,
                    offIcon: _switchOffIcon,
                    mode: RKButtonMode.toggle,
                    size: 120,
                    onChanged: (v) => _toggleState.value = v,
                    onInteractionChanged: (v) => _toggleActive.value = v,
                    enableHapticFeedback: _hapticsEnabled,
                    rotation: _rotation * math.pi / 180,
                    label: _widgetLabel,
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: _buildBooleanInput(value, (v) => _toggleState.value = v),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _toggleActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(label: 'VALUE', value: value.toString().toUpperCase()),
                      const TelemetryRow(label: 'MODE', value: 'TOGGLE'),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _multipleCards() {
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: DemoCard(
              index: 1,
              title: 'MULTI BUTTON GROUP',
              liveWidget: FittedBox(
                fit: BoxFit.scaleDown,
                child: RKMultiButton(
                  buttonSize: 80,
                  spacing: 10,
                  items: _multiItems,
                  selected: _multiButtonValue % (_multiItems.isEmpty ? 1 : _multiItems.length),
                  orientation: _multiOrientation == 'vertical' ? RKAxis.vertical : RKAxis.horizontal,
                  onChanged: (i) => setState(() => _multiButtonValue = i),
                  onActiveChanged: (active) => setState(() => _multiButtonActive = active),
                  rotation: _rotation * math.pi / 180,
                  label: _widgetLabel,
                ),
              ),
              inputLabel: 'INTERACTION',
              inputWidget: const Text('TAP TO SELECT', style: TextStyle(color: Colors.white24, fontSize: 10)),
              outputWidget: Column(
                children: [
                  TelemetryRow(label: 'ACTIVE', value: _multiButtonActive ? 'YES' : 'NO'),
                  TelemetryRow(label: 'VALUE', value: _multiButtonValue.toString()),
                  TelemetryRow(label: 'BITMASK', value: '0b' + (1 << _multiButtonValue).toRadixString(2).padLeft(_multiItems.length, '0')),
                  TelemetryRow(label: 'MODE', value: 'BUTTON'),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 480,
            child: DemoCard(
              index: 2,
              title: 'MULTI SELECT BITMASK',
              liveWidget: FittedBox(
                fit: BoxFit.scaleDown,
                child: RKMultiSelect(
                  buttonSize: 80,
                  spacing: 10,
                  items: _multiItems,
                  bitmask: _multiSelectBitmask,
                  orientation: _multiOrientation == 'vertical' ? RKAxis.vertical : RKAxis.horizontal,
                  onChanged: (v) => setState(() {
                    int changedBit = _multiSelectBitmask ^ v;
                    for (int i = 0; i < _multiItems.length; i++) {
                      if ((changedBit >> i) & 1 == 1) {
                        _lastMultiSelectIndex = i;
                        break;
                      }
                    }
                    _multiSelectBitmask = v;
                  }),
                  onActiveChanged: (active) => setState(() => _multiSelectActive = active),
                  rotation: _rotation * math.pi / 180,
                  label: _widgetLabel,
                ),
              ),
              inputLabel: 'BITMASK VALUE',
              inputWidget: Text(_multiSelectBitmask.toRadixString(2).padLeft(_multiItems.length, '0'), 
                style: const TextStyle(color: Colors.white, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.bold)),
              outputWidget: Column(
                children: [
                  TelemetryRow(label: 'ACTIVE', value: _multiSelectActive ? 'YES' : 'NO'),
                  TelemetryRow(label: 'VALUE', value: _lastMultiSelectIndex == -1 ? '--' : _lastMultiSelectIndex.toString()),
                  TelemetryRow(label: 'BITMASK', value: '0b' + _multiSelectBitmask.toRadixString(2).padLeft(_multiItems.length, '0')),
                  TelemetryRow(label: 'MODE', value: 'SELECT'),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _switchCards() {
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<bool>(
              valueListenable: _slideState,
              builder: (context, value, _) {
                return DemoCard(
                  index: 1,
                  title: 'SLIDE SWITCH',
                  liveWidget: RKSlideSwitch(
                    value: value,
                    onChanged: (v) => _slideState.value = v,
                    onInteractionChanged: (active) => _slideActive.value = active,
                    enableHapticFeedback: _hapticsEnabled,
                    rotation: _rotation * math.pi / 180,
                    label: _widgetLabel,
                    onText: _switchOnText.isNotEmpty ? _switchOnText : 'ON',
                    offText: _switchOffText.isNotEmpty ? _switchOffText : 'OFF',
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: _buildBooleanInput(value, (v) => _slideState.value = v),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _slideActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(label: 'VALUE', value: value.toString().toUpperCase()),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<bool>(
              valueListenable: _rockerState,
              builder: (context, value, _) {
                return DemoCard(
                  index: 2,
                  title: 'ROCKER SWITCH',
                  liveWidget: RKRockerSwitch(
                    value: value,
                    onChanged: (v) => _rockerState.value = v,
                    onInteractionChanged: (active) => _rockerActive.value = active,
                    width: 72,
                    height: 120,
                    onIcon: _switchOnIcon,
                    offIcon: _switchOffIcon,
                    enableHapticFeedback: _hapticsEnabled,
                    label: _widgetLabel,
                    rotation: _rotation * math.pi / 180,
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: _buildBooleanInput(value, (v) => _rockerState.value = v),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _rockerActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(label: 'VALUE', value: value.toString().toUpperCase()),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _sliderCards() {
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<double>(
              valueListenable: _sliderState,
              builder: (context, value, _) {
                final decimals = _decimalPlaces(_sliderResolution);
                final isVertical = _sliderOrientation == 'vertical';
                
                return DemoCard(
                  index: 1,
                  title: 'LINEAR SLIDER',
                  liveWidget: RKSlider(
                    value: value,
                    min: _sliderMin,
                    max: _sliderMax,
                    autoCenter: _sliderAutoCenter,
                    center: _getKnobCenter(_sliderCenterPos),
                    springCurve: _getCurve(_sliderSpringBehavior),
                    springDuration: Duration(milliseconds: _sliderSpringDuration.toInt()),
                    divisions: ((_sliderMax - _sliderMin) / (_sliderResolution <= 0 ? 1 : _sliderResolution)).round(),
                    onChanged: (v) => _sliderState.value = v,
                    onInteractionChanged: (active) => _sliderActive.value = active,
                    orientation: isVertical ? RKAxis.vertical : RKAxis.horizontal,
                    length: isVertical ? 240 : 280,
                    rotation: _rotation * math.pi / 180,
                    label: _widgetLabel,
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: InputSlider(
                    label: 'Target Value',
                    value: value,
                    onChanged: (v) => _sliderState.value = v,
                    onChangeEnd: (v) {
                      if (_sliderAutoCenter) {
                        _sliderState.value = _getKnobCenter(_sliderCenterPos) * (_sliderMax - _sliderMin) + _sliderMin;
                      }
                    },
                    min: _sliderMin,
                    max: _sliderMax,
                  ),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _sliderActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(
                        label: 'VALUE', 
                        value: value.toStringAsFixed(decimals)
                      ),
                      TelemetryRow(
                        label: 'RAW', 
                        value: ((value - _sliderMin) / (_sliderMax - _sliderMin) * 2 - 1).toStringAsFixed(3)
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<double>(
              valueListenable: _pedalState,
              builder: (context, value, _) {
                final decimals = _decimalPlaces(_sliderResolution);
                final isVertical = _sliderOrientation == 'vertical';
                
                return DemoCard(
                  index: 2,
                  title: 'GAS PEDAL',
                  liveWidget: RKGasPedal(
                    value: value,
                    min: _sliderMin,
                    max: _sliderMax,
                    autoCenter: _sliderAutoCenter,
                    center: _getKnobCenter(_sliderCenterPos),
                    springCurve: _getCurve(_sliderSpringBehavior),
                    springDuration: Duration(milliseconds: _sliderSpringDuration.toInt()),
                    divisions: ((_sliderMax - _sliderMin) / (_sliderResolution <= 0 ? 1 : _sliderResolution)).round(),
                    onChanged: (v) => _pedalState.value = v,
                    onInteractionChanged: (active) => _pedalActive.value = active,
                    orientation: isVertical ? RKAxis.vertical : RKAxis.horizontal,
                    length: isVertical ? 240 : 280,
                    rotation: _rotation * math.pi / 180,
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: InputSlider(
                    label: 'Target Value',
                    value: value,
                    onChanged: (v) => _pedalState.value = v,
                    onChangeEnd: (v) {
                      if (_sliderAutoCenter) {
                        _pedalState.value = _getKnobCenter(_sliderCenterPos) * (_sliderMax - _sliderMin) + _sliderMin;
                      }
                    },
                    min: _sliderMin,
                    max: _sliderMax,
                  ),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _pedalActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(
                        label: 'VALUE', 
                        value: value.toStringAsFixed(decimals)
                      ),
                      TelemetryRow(
                        label: 'RAW', 
                        value: ((value - _sliderMin) / (_sliderMax - _sliderMin) * 2 - 1).toStringAsFixed(3)
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _knobCards() {
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<double>(
              valueListenable: _knobState,
              builder: (context, value, _) {
                final divisions = (_knobMax - _knobMin) / (_knobResolution <= 0 ? 1 : _knobResolution);
                return DemoCard(
                  index: 1,
                  title: 'ROTARY ENCODER',
                  liveWidget: RKKnob(
                    value: value,
                    min: _knobMin,
                    max: _knobMax,
                    minAngle: _knobMinAngle,
                    maxAngle: _knobMaxAngle,
                    autoCenter: _knobAutoCenter,
                    center: _getKnobCenter(_knobCenterPos),
                    springCurve: _getCurve(_knobSpringBehavior),
                    springDuration: Duration(milliseconds: _knobSpringDuration.toInt()),
                    divisions: divisions.round(),
                    onChanged: (v) => _knobState.value = v,
                    onInteractionChanged: (active) => _knobActive.value = active,
                    size: 120,
                    variant: RKKnobVariant.standard,
                    label: _widgetLabel,

                    centerIcon: _switchOnIcon,
                    rotation: _rotation * math.pi / 180,
                  ),

                  inputLabel: 'INPUT CONTROL',
                  inputWidget: InputSlider(
                    label: 'Value',
                    value: value,
                    onChanged: (v) => _knobState.value = v,
                    onChangeEnd: (v) {
                      if (_knobAutoCenter) {
                        _knobState.value = _knobMin + _getKnobCenter(_knobCenterPos) * (_knobMax - _knobMin);
                      }
                    },
                    min: _knobMin,
                    max: _knobMax,
                  ),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _knobActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(
                        label: 'VALUE', 
                        value: value.toStringAsFixed(_decimalPlaces(_knobResolution))
                      ),
                      TelemetryRow(
                        label: 'RAW', 
                        value: (value / (_knobMax - _knobMin) * 2).toStringAsFixed(3)
                      ),
                      TelemetryRow(
                        label: 'ANGLE', 
                        value: (value / (_knobMax - _knobMin) * (_knobMaxAngle - _knobMinAngle)).toStringAsFixed(1) + '°'
                      ),
                      const TelemetryRow(label: 'MODE', value: 'ABSOLUTE'),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<double>(
              valueListenable: _wheelState,
              builder: (context, value, _) {
                final divisions = (_knobMax - _knobMin) / (_knobResolution <= 0 ? 1 : _knobResolution);
                return DemoCard(
                  index: 2,
                  title: 'STEERING WHEEL',
                  liveWidget: RKKnob(
                    value: value,
                    min: _knobMin,
                    max: _knobMax,
                    minAngle: _knobMinAngle,
                    maxAngle: _knobMaxAngle,
                    autoCenter: _knobAutoCenter,
                    center: _getKnobCenter(_knobCenterPos),
                    springCurve: _getCurve(_knobSpringBehavior),
                    springDuration: Duration(milliseconds: _knobSpringDuration.toInt()),
                    divisions: divisions.round(),
                    onChanged: (v) => _wheelState.value = v,
                    onInteractionChanged: (active) => _wheelActive.value = active,
                    size: 140,
                    variant: RKKnobVariant.steeringWheel,
                    centerIcon: _switchOnIcon,
                    label: _widgetLabel,
                    rotation: _rotation * math.pi / 180,
                  ),

                  inputLabel: 'INPUT CONTROL',
                  inputWidget: InputSlider(
                    label: 'Value',
                    value: value,
                    onChanged: (v) => _wheelState.value = v,
                    onChangeEnd: (v) {
                      if (_knobAutoCenter) {
                        _wheelState.value = _knobMin + _getKnobCenter(_knobCenterPos) * (_knobMax - _knobMin);
                      }
                    },
                    min: _knobMin,
                    max: _knobMax,
                  ),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _wheelActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE',
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(
                        label: 'VALUE', 
                        value: value.toStringAsFixed(_decimalPlaces(_knobResolution))
                      ),
                      TelemetryRow(
                        label: 'RAW', 
                        value: (value / (_knobMax - _knobMin) * 2).toStringAsFixed(3)
                      ),
                      TelemetryRow(
                        label: 'ANGLE', 
                        value: (value / (_knobMax - _knobMin) * (_knobMaxAngle - _knobMinAngle)).toStringAsFixed(1) + '°'
                      ),
                      const TelemetryRow(label: 'MODE', value: 'ABSOLUTE'),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _joystickCards() {
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<RKJoystickValue>(
              valueListenable: _joyState,
              builder: (context, value, _) {
                final sx = _scaleJoystick(value.x);
                final sy = _scaleJoystick(value.y);
                final decimals = _decimalPlaces(_joyResolution);
                return DemoCard(
                  index: 1,
                  title: '2-AXIS JOYSTICK',
                  liveWidget: RKJoystick(
                    size: 160,
                    value: value,
                    center: _getJoystickCenter(_joyCenterPosition),
                    autoCenter: _joySelfCentering,
                    springCurve: _getCurve(_joySpringBehavior),
                    springDuration: Duration(milliseconds: _joySpringDuration.toInt()),
                    onChanged: (v) => _joyState.value = v,
                    rotation: _rotation * math.pi / 180,
                    label: _widgetLabel,
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: Column(
                    children: [
                      InputSlider(
                        label: 'X-Axis (Yaw)',
                        value: value.x,
                        onChanged: (v) => _joyState.value = RKJoystickValue(x: v, y: value.y, isActive: true),
                        onChangeEnd: (v) {
                          if (_joySelfCentering) {
                            final center = _getJoystickCenter(_joyCenterPosition);
                            _joyState.value = center;
                          }
                        },
                        min: -1.0,
                        max: 1.0,
                      ),
                      const SizedBox(height: 12),
                      InputSlider(
                        label: 'Y-Axis (Pitch)',
                        value: value.y,
                        onChanged: (v) => _joyState.value = RKJoystickValue(x: value.x, y: v, isActive: true),
                        onChangeEnd: (v) {
                          if (_joySelfCentering) {
                            final center = _getJoystickCenter(_joyCenterPosition);
                            _joyState.value = center;
                          }
                        },
                        min: -1.0,
                        max: 1.0,
                      ),
                    ],
                  ),
                  outputWidget: Column(
                    children: [
                      TelemetryRow(label: 'ACTIVE', value: value.isActive.toString().toUpperCase()),
                      TelemetryRow(label: 'X', value: sx.toStringAsFixed(decimals)),
                      TelemetryRow(label: 'Y', value: sy.toStringAsFixed(decimals)),
                      TelemetryRow(label: 'RAW_X', value: value.x.toStringAsFixed(3)),
                      TelemetryRow(label: 'RAW_Y', value: value.y.toStringAsFixed(3)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ];
  }

  RKJoystickValue _getJoystickCenter(String pos) {
    switch (pos) {
      case 'left':
        return const RKJoystickValue(x: -1, y: 0);
      case 'right':
        return const RKJoystickValue(x: 1, y: 0);
      case 'top':
        return const RKJoystickValue(x: 0, y: 1);
      case 'bottom':
        return const RKJoystickValue(x: 0, y: -1);
      default:
        return const RKJoystickValue(x: 0, y: 0);
    }
  }

  List<Widget> _displayCards() {
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: ValueListenableBuilder<String>(
              valueListenable: _displayText,
              builder: (context, text, _) {
                return DemoCard(
                  index: 1,
                  title: 'TEXT DISPLAY',
                  liveWidget: RKDisplay(
                    text: text,
                    fontFamily: _displayFont,
                    onInteractionChanged: (active) => _displayActive.value = active,
                    rotation: _rotation * math.pi / 180,
                    label: _widgetLabel,
                  ),
                  inputLabel: 'INPUT CONTROL',
                  inputWidget: TextInput(
                    label: 'TEXT',
                    initialValue: text,
                    onSubmitted: (v) => _displayText.value = v,
                  ),
                  outputWidget: Column(
                    children: [
                      ValueListenableBuilder<bool>(
                        valueListenable: _displayActive,
                        builder: (context, active, _) => TelemetryRow(
                          label: 'ACTIVE', 
                          value: active.toString().toUpperCase(),
                        ),
                      ),
                      TelemetryRow(label: 'TEXT', value: text),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: 480,
            child: DemoCard(
              index: 2,
              title: 'SERIAL MONITOR',
              liveWidget: RKSerialMonitor(
                messages: _serialMessages,
                fontFamily: _displayFont,
                onInteractionChanged: (active) => _serialActive.value = active,
                rotation: _rotation * math.pi / 180,
                label: _widgetLabel,
              ),
              inputLabel: 'INPUT CONTROL',
              inputWidget: ValueListenableBuilder<String>(
                valueListenable: _serialInput,
                builder: (context, input, _) {
                  return TextInput(
                    label: 'TEXT',
                    initialValue: input,
                    onSubmitted: (v) {
                      setState(() {
                        _serialMessages.add('> USER: $v');
                      });
                      _serialInput.value = '';
                    },
                  );
                },
              ),
              outputWidget: Column(
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: _serialActive,
                    builder: (context, active, _) => TelemetryRow(
                      label: 'ACTIVE', 
                      value: active.toString().toUpperCase(),
                    ),
                  ),
                  TelemetryRow(label: 'TEXT', value: _serialMessages.isNotEmpty ? (_serialMessages.last.length > 15 ? '${_serialMessages.last.substring(0, 15)}...' : _serialMessages.last) : 'NONE'),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _ledCards() {
    final tokens = RKTheme.of(context);
    return [
      Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: 480,
            child: DemoCard(
              index: 1,
              title: 'STATUS LED',
              liveWidget: RKLed(
                state: _ledOpState,
                shape: _ledShape,
                size: 64,
                color: _ledColor,
                timing: _ledTiming,
                rotation: _rotation * math.pi / 180,
                label: _widgetLabel,
              ),
              inputLabel: 'INPUT CONTROL',
              inputWidget: Column(
                children: [
                  _buildLEDStateSelection(tokens),
                ],
              ),
              outputWidget: Column(
                children: [
                  TelemetryRow(label: 'STATE', value: _ledOpState.name.toUpperCase()),
                  TelemetryRow(label: 'SHAPE', value: _ledShape.name.toUpperCase()),
                  TelemetryRow(label: 'TIMING', value: '${_ledTiming}MS'),
                  TelemetryRow(label: 'COLOR', value: '#${(_ledColor ?? tokens.primary).toARGB32().toRadixString(16).toUpperCase().substring(2)}'),
                ],
              ),
            ),
          ),
        ],
      ),
    ];
  }

  Widget _buildLEDStateSelection(RKTokens tokens) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('STATE SELECTION', style: TextStyle(color: Color(0xFF888888), fontSize: 10, fontFamily: 'monospace')),
        const SizedBox(height: 8),
        Row(
          children: RKLEDState.values.map((state) {
            final isSelected = _ledOpState == state;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _ledOpState = state),
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: isSelected ? tokens.primary : const Color(0xFF222222),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text(
                        state.name.toUpperCase(),
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white54,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }


}

// ─── Telemetry Row ───
class TelemetryRow extends StatelessWidget {
  final String label;
  final String value;

  const TelemetryRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF888888),
              fontSize: 10,
              fontFamily: 'monospace',
              letterSpacing: 0.5,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFD0D0D0),
              fontSize: 10,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Text Input ───
class TextInput extends StatefulWidget {
  final String label;
  final String initialValue;
  final ValueChanged<String> onSubmitted;

  const TextInput({
    super.key,
    required this.label,
    required this.initialValue,
    required this.onSubmitted,
  });

  @override
  State<TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<TextInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void didUpdateWidget(TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialValue != widget.initialValue && _controller.text != widget.initialValue) {
      _controller.text = widget.initialValue;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label.toUpperCase(),
          style: const TextStyle(
            color: Color(0xFF666666),
            fontSize: 10,
            fontFamily: 'monospace',
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(color: const Color(0xFF222222), width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: TextField(
              controller: _controller,
              onSubmitted: (v) {
                widget.onSubmitted(v);
                if (widget.label == 'SERIAL') {
                  _controller.clear();
                }
              },
              style: TextStyle(
                color: tokens.primary,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
              cursorColor: tokens.primary,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'ENTER VALUE...',
                hintStyle: TextStyle(color: Color(0xFF333333), fontSize: 10),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Input Slider ───
class InputSlider extends StatelessWidget {
  const InputSlider({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = 0.0,
    this.max = 1.0,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF888888),
                fontSize: 10,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              (value >= 0 ? '+' : '') + value.toStringAsFixed(2),
              style: TextStyle(
                color: tokens.primary,
                fontSize: 10,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 24,
          child: SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              activeTrackColor: tokens.primary.withValues(alpha: 0.4),
              inactiveTrackColor: const Color(0xFF222222),
              thumbColor: const Color(0xFFD0D0D0),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
              activeTickMarkColor: Colors.transparent,
              inactiveTickMarkColor: Colors.transparent,
            ),
            child: Slider(
              value: value.clamp(min, max),
              min: min,
              max: max,
              onChanged: onChanged,
              onChangeEnd: onChangeEnd,
            ),
          ),
        ),
      ],
    );
  }
}


// ─── Top system bar ───
class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final tokens = RKTheme.of(context);

    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        border: Border(
          bottom: BorderSide(color: Color(0xFF222222), width: 1),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              color: tokens.primary,
              fontSize: 18,
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: tokens.primary,
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text(
              'FLUTTER',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontSize: 12,
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Aesthetic core bar ───
class _AestheticCoreBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final styles = {
      'RAMBROS': RKTokens.rambros,
      'NEON': RKTokens.neon,
      'MINIMAL': RKTokens.minimal,
    };

    return ValueListenableBuilder<RKTokens>(
      valueListenable: themeNotifier,
      builder: (context, currentTokens, _) {
        return Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: Color(0xFF141414),
            border: Border(
              bottom: BorderSide(color: Color(0xFF222222), width: 1),
            ),
          ),
          child: Row(
            children: [
              const Text(
                'STYLE:',
                style: TextStyle(
                  color: Color(0xFFB0B0B0),
                  fontSize: 12,
                  fontFamily: 'monospace',
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(width: 12),
              ...styles.entries.map((entry) {
                final isSelected = currentTokens == entry.value;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => themeNotifier.value = entry.value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      decoration: BoxDecoration(
                        color: isSelected ? entry.value.primary : const Color(0xFF1A1A1A),
                        border: Border.all(
                          color: isSelected ? entry.value.primary : const Color(0xFF444444),
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: isSelected ? Colors.black : const Color(0xFF888888),
                          fontSize: 11,
                          fontFamily: 'monospace',
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }
}
