import 'dart:async';
import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../providers/device_provider.dart';

class DeviceDesignerBridge extends StatefulWidget {
  final DeviceProvider deviceProvider;
  final bool debugMode;
  final bool overrideTheme;

  const DeviceDesignerBridge({
    super.key,
    required this.deviceProvider,
    this.debugMode = false,
    this.overrideTheme = false,
  });

  @override
  State<DeviceDesignerBridge> createState() => _DeviceDesignerBridgeState();
}

class _DeviceDesignerBridgeState extends State<DeviceDesignerBridge> {
  late DesignerState _designerState;
  Map<String, dynamic>? _lastJson;

  final Map<int, Timer> _throttleTimers = {};
  final Map<int, List<int>> _pendingPayloads = {};

  @override
  void initState() {
    super.initState();
    RKDebugOverlay.enabled = widget.debugMode;
    _designerState = DesignerState();
    _designerState.addListener(_onDesignerStateChanged);
    widget.deviceProvider.addListener(_onDeviceProviderChanged);
    if (!_designerState.isPlayMode) {
      _designerState.togglePlayMode();
    }
    _designerState.onRuntimeValueChanged = _onWidgetValueChanged;
    _syncElementsFromJson();
    final deviceActivePage = widget.deviceProvider.activePage;
    if (_designerState.activePageIndex != deviceActivePage &&
        deviceActivePage < _designerState.numPages) {
      _designerState.setActivePage(deviceActivePage);
    }
    _syncValues();
  }

  void _onDesignerStateChanged() {
    if (mounted) setState(() {});
  }

  void _onDeviceProviderChanged() {
    if (!mounted) return;
    final currentJson = widget.deviceProvider.deviceConfigJson;
    if (currentJson != _lastJson) {
      _syncElementsFromJson();
    }
    final deviceActivePage = widget.deviceProvider.activePage;
    if (_designerState.activePageIndex != deviceActivePage &&
        deviceActivePage < _designerState.numPages) {
      _designerState.setActivePage(deviceActivePage);
    }
    _syncValues();
  }

  @override
  void didUpdateWidget(DeviceDesignerBridge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceProvider != widget.deviceProvider) {
      oldWidget.deviceProvider.removeListener(_onDeviceProviderChanged);
      widget.deviceProvider.addListener(_onDeviceProviderChanged);
    }
    if (oldWidget.debugMode != widget.debugMode) {
      RKDebugOverlay.enabled = widget.debugMode;
    }
    _onDeviceProviderChanged();
  }

  @override
  void dispose() {
    for (final timer in _throttleTimers.values) {
      timer.cancel();
    }
    _throttleTimers.clear();
    _pendingPayloads.clear();
    widget.deviceProvider.removeListener(_onDeviceProviderChanged);
    _designerState.removeListener(_onDesignerStateChanged);
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

    final deviceActivePage = widget.deviceProvider.activePage;
    if (deviceActivePage < _designerState.numPages) {
      _designerState.setActivePage(deviceActivePage);
    }

    // Override the name/label on each element to store widgetId across all pages,
    // so _syncValues and _onWidgetValueChanged can find the wire config.
    for (final page in _designerState.pages) {
      for (final el in page.elements) {
        final wid = el.properties['widgetId'];
        if (wid is int) {
          el.label = wid.toString();
        }
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

    // Suppress undo snapshots during runtime sync — BLE notifications
    // trigger this on every frame; creating deep copies blocks the event loop.
    _designerState.beginRuntimeSync();
    bool changed = false;
    try {
    for (final el in _designerState.elements) {
      final widgetId = el.properties['widgetId'] as int? ?? 0;
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
          // Map protocol [-100..100] → widget [min..max]
          final rawVal = inValues[0].toSigned(8);
          final protocolT = ((rawVal + 100) / 200.0).clamp(0.0, 1.0); // 0..1
          final wMin = (el.properties['min'] as num?)?.toDouble() ?? 0;
          final wMax = (el.properties['max'] as num?)?.toDouble() ?? 100;
          normalized = wMin + protocolT * (wMax - wMin);
        } else if (config.typeId == kWidgetJoystick) {
          final rawX = inValues.isNotEmpty ? inValues[0].toSigned(8) : 0;
          final rawY = inValues.length > 1 ? inValues[1].toSigned(8) : 0;
          normalized = RKJoystickValue(x: rawX / 100.0, y: rawY / 100.0);
        } else if (config.typeId == kWidgetButton ||
            config.typeId == kWidgetSwitch ||
            config.typeId == kWidgetSlideSwitch) {
          normalized = inValues[0] != 0;
        } else {
          normalized = inValues[0];
        }

        final currentVal = _designerState.getRuntimeWidgetValue(el.id, null);
        if (currentVal != normalized) {
          changed = true;
          final oldCallback = _designerState.onRuntimeValueChanged;
          _designerState.onRuntimeValueChanged = null;
          _designerState.setRuntimeWidgetValue(el.id, normalized);
          _designerState.onRuntimeValueChanged = oldCallback;
        }
      }
    }

    // Sync hidden state from WidgetConfig → DesignerElement
    for (final el in _designerState.elements) {
      final config = _widgetConfigForElement(el);
      if (config.typeId == 0) continue;
      if (config.hidden != el.hidden) {
        changed = true;
        _designerState.setElementHidden(el.id, config.hidden);
      }
    }
    } finally {
      _designerState.endRuntimeSync();
    }
    // Only rebuild if something actually changed — eliminates ~15 unnecessary rebuilds/sec
    if (changed) {
      _designerState.notifyListeners();
    }
  }

  void _onWidgetValueChanged(String id, dynamic value) {
    final el = _designerState.elements.firstWhere((e) => e.id == id);
    final widgetId = el.properties['widgetId'] as int? ?? 0;
    final config = _widgetConfigForElement(el);
    if (config.typeId == 0) return;

    List<int> payload = [0];

    final isContinuous = config.typeId == kWidgetSlider ||
        config.typeId == kWidgetKnob ||
        config.typeId == kWidgetJoystick;

    if (config.typeId == kWidgetSlider || config.typeId == kWidgetKnob) {
      // Map widget [min..max] → protocol [-100..100]
      final doubleVal = (value is num) ? value.toDouble() : 0.0;
      final wMin = (el.properties['min'] as num?)?.toDouble() ?? 0;
      final wMax = (el.properties['max'] as num?)?.toDouble() ?? 100;
      final wRange = wMax - wMin;
      final t = wRange > 0 ? ((doubleVal - wMin) / wRange).clamp(0.0, 1.0) : 0.5;
      int intVal = (-100 + (t * 200)).round().clamp(-100, 100);
      final detents = variantDetents(config.variant);
      if (detents > 1) {
        final step = 200.0 / (detents - 1);
        intVal =
            (((intVal + 100) / step).round() * step - 100).round();
      }
      payload = [intVal];
    } else if (config.typeId == kWidgetJoystick) {
      final joy = value is RKJoystickValue ? value : const RKJoystickValue(x: 0, y: 0);
      final intX = (joy.x * 100).round().clamp(-100, 100);
      final intY = (joy.y * 100).round().clamp(-100, 100);
      payload = [intX, intY];
    } else if (config.typeId == kWidgetButton ||
        config.typeId == kWidgetSwitch ||
        config.typeId == kWidgetSlideSwitch) {
      payload = [(value == true) ? 1 : 0];
    } else if (config.typeId == kWidgetMultiple) {
      payload = [(value is num) ? value.toInt() : 0];
    }

    // NOTE: Do NOT skip based on runtime widget value here — it was already
    // updated by setRuntimeWidgetValue() before this callback fires, so it
    // always matches. The skip logic is handled by setInputValue() which
    // compares against the device's input state.
    if (!isContinuous) {
      _throttleTimers[widgetId]?.cancel();
      _throttleTimers.remove(widgetId);
      _pendingPayloads.remove(widgetId);
      widget.deviceProvider.setInputValue(widgetId, payload);
      return;
    }

    _pendingPayloads[widgetId] = payload;
    if (_throttleTimers[widgetId]?.isActive ?? false) {
      return;
    }

    // Send immediately if no throttle timer is running, then throttle subsequent samples
    widget.deviceProvider.setInputValue(widgetId, payload);
    _pendingPayloads.remove(widgetId);

    _throttleTimers[widgetId] = Timer(const Duration(milliseconds: 10), () {
      final latest = _pendingPayloads.remove(widgetId);
      if (latest != null && mounted) {
        widget.deviceProvider.setInputValue(widgetId, latest);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final skin = _designerState.activeSkin;
    final useDeviceSkin = !widget.overrideTheme && skin != 'default';
    final skinTokens = useDeviceSkin ? RKTokens.presetsByName[skin] : null;
    Widget canvas = DesignerCanvas(state: _designerState);
    if (skinTokens != null) {
      canvas = RKTheme(tokens: skinTokens, child: canvas);
    }
    return canvas;
  }
}
