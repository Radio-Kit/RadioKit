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

  @override
  void initState() {
    super.initState();
    RKDebugOverlay.enabled = widget.debugMode;
    _designerState = DesignerState();
    // Start in play mode so elements are interactable and scaling works correctly
    if (!_designerState.isPlayMode) {
      _designerState.togglePlayMode();
    }
    _designerState.onRuntimeValueChanged = _onWidgetValueChanged;
    _syncElements();
    _syncValues();
  }

  @override
  void didUpdateWidget(DeviceDesignerBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.debugMode != widget.debugMode) {
      RKDebugOverlay.enabled = widget.debugMode;
    }
    if (oldWidget.deviceProvider.widgets != widget.deviceProvider.widgets || 
        oldWidget.deviceProvider.orientation != widget.deviceProvider.orientation) {
      _syncElements();
    }
    _syncValues();
  }

  @override
  void dispose() {
    _designerState.dispose();
    RKDebugOverlay.enabled = false;
    super.dispose();
  }

  void _syncElements() {
    _designerState.clearAll();
    
    // Set orientation correctly
    if (widget.deviceProvider.orientation == kOrientationPortrait && _designerState.isLandscape) {
      _designerState.toggleOrientation();
    } else if (widget.deviceProvider.orientation == kOrientationLandscape && !_designerState.isLandscape) {
      _designerState.toggleOrientation();
    }

    final canvasVH = _designerState.canvasHeight;

    for (final config in widget.deviceProvider.widgets) {
      final type = _mapWidgetType(config);
      if (type == null) continue; // Unknown

      // Seed with type defaults so widget-specific properties (min, max, etc.)
      // are always present. Bridge-specific values override where needed.
      final props = DesignerElement.defaultPropertiesFor(type);
      
      // Transfer generic properties
      if (config.onText.isNotEmpty) props['onText'] = config.onText;
      if (config.offText.isNotEmpty) props['offText'] = config.offText;
      props['minAngle'] = config.minAngle.toDouble();
      props['maxAngle'] = config.maxAngle.toDouble();
      // Map variant centering mode to autoCenter list [position, type, duration]
      // position: null=disabled, "min"/"center"/"max"=enabled
      // type: spring curve name
      // duration: spring duration in ms
      props['autoCenter'] = _acListForCentering(variantCentering(config.variant));

      props['divisions'] = variantDetents(config.variant);
      if (props['divisions'] == 1) props.remove('divisions');

      if (config.typeId == kWidgetMultiple) {
        props['itemCount'] = config.multipleItems.length;
      }
      if (config.typeId == kWidgetButton) {
        props['mode'] = config.variant == 1 ? 'toggle' : 'push';
      }

      // Use designer defaults as the base size, scaled by wire scale factors.
      // This ensures Control UI matches Designer Test mode at scale 1.0 while
      // preserving the device's relative sizing (2× on device = 2× on Flutter).
      final (defaultW, defaultH) = DesignerElement.defaultSize(type);
      final h = (defaultH * config.heightF).round();
      final ar = DesignerElement.aspectRatioFor(type, props);
      final int w;
      if (ar == null) {
        // Free-form: slider, text, gasPedal, multiButton, multiSelect, serialMonitor
        w = (defaultW * config.heightF * config.widthF).round();
      } else if (ar >= 0) {
        // Height is primary (button, slideSwitch, knob, joystick, led)
        w = (h * ar).round();
      } else {
        // Width is primary (rockerSwitch)
        w = (defaultW * config.heightF).round();
      }

      // Y is flipped here because App is Y-up, Designer is Y-down
      final flippedY = canvasVH - config.y;

      _designerState.addElement(
        type,
        config.x.round(),
        flippedY.round(),
        properties: props,
        width: w,
        height: h,
      );

      _designerState.updateElementRotation(
        _designerState.elements.last.id,
        config.rotationDegrees.round(),
      );
      // We map the widgetId explicitly so we can find it
      _designerState.updateElementLabel(
        _designerState.elements.last.id,
        config.widgetId.toString()
      );
    }
    
    // Clear selection since it's play mode
    _designerState.selectElement(null);
  }

  void _syncValues() {
    final state = widget.deviceProvider.widgetState;
    if (state == null) return;

    for (final el in _designerState.elements) {
      final widgetId = int.tryParse(el.label) ?? 0;
      final config = widget.deviceProvider.widgets.firstWhere((w) => w.widgetId == widgetId, orElse: () => const WidgetConfig(typeId: 0, widgetId: 0, x: 0, y: 0, width: 0, height: 0));
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
            _designerState.updateElementProperty(el.id, 'color', Color.fromARGB(a, r, g, b).toARGB32());
          }
        }
      } else if (config.typeId == kWidgetText) {
        final outValue = state.outputValues[widgetId] ?? '';
        _designerState.updateElementProperty(el.id, 'text', outValue.toString());
      } else {
        // Inputs
        final inValues = state.inputValues[widgetId] ?? [0, 0];
        if (inValues.isEmpty) continue;
        
        dynamic normalized;
        if (config.typeId == kWidgetSlider || config.typeId == kWidgetKnob) {
          normalized = (inValues[0] + 100) / 200.0;
        } else if (config.typeId == kWidgetJoystick) {
          final rawX = inValues.isNotEmpty ? inValues[0] : 0;
          final rawY = inValues.length > 1 ? inValues[1] : 0;
          normalized = RKJoystickValue(x: rawX / 100.0, y: rawY / 100.0);
        } else if (config.typeId == kWidgetButton || config.typeId == kWidgetSwitch || config.typeId == kWidgetSlideSwitch) {
          normalized = inValues[0] != 0;
        } else {
          normalized = inValues[0];
        }
        
        // Use an internal method if possible or just temporarily unset listener
        final oldCallback = _designerState.onRuntimeValueChanged;
        _designerState.onRuntimeValueChanged = null;
        _designerState.setRuntimeWidgetValue(el.id, normalized);
        _designerState.onRuntimeValueChanged = oldCallback;
      }
    }
  }

  void _onWidgetValueChanged(String id, dynamic value) {
    final el = _designerState.elements.firstWhere((e) => e.id == id);
    final widgetId = int.tryParse(el.label) ?? 0;

    final config = widget.deviceProvider.widgets.firstWhere((w) => w.widgetId == widgetId, orElse: () => const WidgetConfig(typeId: 0, widgetId: 0, x: 0, y: 0, width: 0, height: 0));
    if (config.typeId == 0) return;

    List<int> payload = [0];

    if (config.typeId == kWidgetSlider || config.typeId == kWidgetKnob) {
      final doubleVal = value as double;
      int intVal = ((doubleVal * 200) - 100).round().clamp(-100, 100);
      final detents = variantDetents(config.variant);
      if (detents > 1) {
        final step = 200.0 / (detents - 1);
        intVal = (((intVal + 100) / step).round() * step - 100).round();
      }
      payload = [intVal];
    } else if (config.typeId == kWidgetJoystick) {
      final joy = value as RKJoystickValue;
      final intX = (joy.x * 100).round().clamp(-100, 100);
      final intY = (joy.y * 100).round().clamp(-100, 100);
      payload = [intX, intY];
    } else if (config.typeId == kWidgetButton || config.typeId == kWidgetSwitch || config.typeId == kWidgetSlideSwitch) {
      payload = [(value as bool) ? 1 : 0];
    } else if (config.typeId == kWidgetMultiple) {
      payload = [value as int];
    }

    widget.deviceProvider.setInputValue(widgetId, payload);
  }

  DesignerElementType? _mapWidgetType(WidgetConfig config) {
    switch (config.typeId) {
      case kWidgetButton:
        return DesignerElementType.button;
      case kWidgetSwitch:
        return DesignerElementType.button; // Mode = toggle is set later
      case kWidgetSlideSwitch:
        return DesignerElementType.slideSwitch;
      case kWidgetSlider:
        return variantIsAlternateShape(config.variant) ? DesignerElementType.gasPedal : DesignerElementType.slider;
      case kWidgetKnob:
        return variantIsAlternateShape(config.variant) ? DesignerElementType.steeringWheel : DesignerElementType.knob;
      case kWidgetJoystick:
        return DesignerElementType.joystick;
      case kWidgetLed:
        return DesignerElementType.led;
      case kWidgetText:
        return DesignerElementType.text;
      case kWidgetMultiple:
        return config.variant == 1 ? DesignerElementType.multiSelect : DesignerElementType.multiButton;
      default:
        return null;
    }
  }

  /// Maps a protocol centering mode to the designer autoCenter list format.
  /// Returns [position, type, duration] where position is null (disabled) or
  /// "min" | "center" | "max" (enabled).
  List<dynamic> _acListForCentering(int centerMode) {
    switch (centerMode) {
      case kCenterMin:
        return ['min', 'smooth', 300];
      case kCenterMid:
        return ['center', 'smooth', 300];
      case kCenterMax:
        return ['max', 'smooth', 300];
      default:
        return [null, 'smooth', 300];
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesignerCanvas(state: _designerState);
  }
}
