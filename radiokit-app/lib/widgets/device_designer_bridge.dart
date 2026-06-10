import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../providers/device_provider.dart';

class DeviceDesignerBridge extends StatefulWidget {
  final DeviceProvider deviceProvider;
  final bool debugMode;

  const DeviceDesignerBridge({
    super.key,
    required this.deviceProvider,
    this.debugMode = false,
  });

  @override
  State<DeviceDesignerBridge> createState() => _DeviceDesignerBridgeState();
}

class _DeviceDesignerBridgeState extends State<DeviceDesignerBridge> {
  late DesignerState _designerState;
  Map<String, dynamic>? _lastJson;

  @override
  void initState() {
    super.initState();
    RKDebugOverlay.enabled = widget.debugMode;
    _designerState = DesignerState();
    if (!_designerState.isPlayMode) {
      _designerState.togglePlayMode();
    }
    _designerState.onRuntimeValueChanged = _onWidgetValueChanged;
    _syncElementsFromJson();
    _syncValues();
  }

  @override
  void didUpdateWidget(DeviceDesignerBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debugMode != widget.debugMode) {
      RKDebugOverlay.enabled = widget.debugMode;
    }
    final currentJson = widget.deviceProvider.deviceConfigJson;
    if (currentJson != _lastJson) {
      _syncElementsFromJson();
    }
    _syncValues();
  }

  @override
  void dispose() {
    _designerState.dispose();
    RKDebugOverlay.enabled = false;
    super.dispose();
  }

  void _syncElementsFromJson() {
    _designerState.clearAll();
    _lastJson = null;

    final json = widget.deviceProvider.deviceConfigJson;
    if (json == null) return;

    _designerState.loadFromJson(json);

    // Override the name/label on each element to store widgetId,
    // so _syncValues and _onWidgetValueChanged can find the wire config.
    for (final el in _designerState.elements) {
      final wid = el.properties['widgetId'];
      if (wid is int) {
        _designerState.updateElementLabel(el.id, wid.toString());
      }
    }

    _designerState.selectElement(null);
    _lastJson = json;
  }

  /// Find a [WidgetConfig] by widgetId extracted from [element.properties].
  WidgetConfig _widgetConfigForElement(DesignerElement el) {
    final widgetId = el.properties['widgetId'] as int? ?? 0;
    return widget.deviceProvider.widgets.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => const WidgetConfig(
        typeId: 0, widgetId: 0, x: 0, y: 0, width: 0, height: 0),
    );
  }

  void _syncValues() {
    final state = widget.deviceProvider.widgetState;
    if (state == null) return;

    for (final el in _designerState.elements) {
      final widgetId = el.properties['widgetId'] as int? ?? 0;
      if (widgetId == 0) continue;
      final config = _widgetConfigForElement(el);
      if (config.typeId == 0) continue;

      if (config.typeId == kWidgetLed) {
        final outValues = state.outputValues[widgetId];
        if (outValues is List<int> && outValues.isNotEmpty) {
          final stateVal = outValues[0];
          final r = outValues.length > 1 ? outValues[1] : 0;
          final g = outValues.length > 2 ? outValues[2] : 0;
          final b = outValues.length > 3 ? outValues[3] : 0;
          final a = outValues.length > 4 ? outValues[4] : 255;

          String ledStateStr = 'off';
          if (stateVal == 1) {
            ledStateStr = 'on';
          } else if (stateVal == 2) {
            ledStateStr = 'blink';
          } else if (stateVal == 3) {
            ledStateStr = 'breathe';
          }

          _designerState.updateElementProperty(el.id, 'state', ledStateStr);
          if (r > 0 || g > 0 || b > 0) {
            _designerState.updateElementProperty(
                el.id, 'color', Color.fromARGB(a, r, g, b).toARGB32());
          }
        }
      } else if (config.typeId == kWidgetText) {
        final outValue = state.outputValues[widgetId] ?? '';
        _designerState.updateElementProperty(
            el.id, 'text', outValue.toString());
      } else {
        final inValues = state.inputValues[widgetId] ?? [0, 0];
        if (inValues.isEmpty) continue;

        dynamic normalized;
        if (config.typeId == kWidgetSlider || config.typeId == kWidgetKnob) {
          normalized = (inValues[0] + 100) / 200.0;
        } else if (config.typeId == kWidgetJoystick) {
          final rawX = inValues.isNotEmpty ? inValues[0] : 0;
          final rawY = inValues.length > 1 ? inValues[1] : 0;
          normalized = RKJoystickValue(x: rawX / 100.0, y: rawY / 100.0);
        } else if (config.typeId == kWidgetButton ||
            config.typeId == kWidgetSwitch ||
            config.typeId == kWidgetSlideSwitch) {
          normalized = inValues[0] != 0;
        } else {
          normalized = inValues[0];
        }

        final oldCallback = _designerState.onRuntimeValueChanged;
        _designerState.onRuntimeValueChanged = null;
        _designerState.setRuntimeWidgetValue(el.id, normalized);
        _designerState.onRuntimeValueChanged = oldCallback;
      }
    }
  }

  void _onWidgetValueChanged(String id, dynamic value) {
    final el = _designerState.elements.firstWhere((e) => e.id == id);
    final widgetId = el.properties['widgetId'] as int? ?? 0;
    final config = _widgetConfigForElement(el);
    if (config.typeId == 0) return;

    List<int> payload = [0];

    if (config.typeId == kWidgetSlider || config.typeId == kWidgetKnob) {
      final doubleVal = value as double;
      int intVal =
          ((doubleVal * 200) - 100).round().clamp(-100, 100);
      final detents = variantDetents(config.variant);
      if (detents > 1) {
        final step = 200.0 / (detents - 1);
        intVal =
            (((intVal + 100) / step).round() * step - 100).round();
      }
      payload = [intVal];
    } else if (config.typeId == kWidgetJoystick) {
      final joy = value as RKJoystickValue;
      final intX = (joy.x * 100).round().clamp(-100, 100);
      final intY = (joy.y * 100).round().clamp(-100, 100);
      payload = [intX, intY];
    } else if (config.typeId == kWidgetButton ||
        config.typeId == kWidgetSwitch ||
        config.typeId == kWidgetSlideSwitch) {
      payload = [(value as bool) ? 1 : 0];
    } else if (config.typeId == kWidgetMultiple) {
      payload = [value as int];
    }

    widget.deviceProvider.setInputValue(widgetId, payload);
  }

  @override
  Widget build(BuildContext context) {
    return DesignerCanvas(state: _designerState);
  }
}
