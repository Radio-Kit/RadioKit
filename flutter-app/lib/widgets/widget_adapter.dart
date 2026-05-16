import 'package:flutter/material.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../utils/icon_utils.dart';

/// Central adapter that converts [WidgetConfig] + protocol values into
/// library widget instances from `radiokit_widgets`.
///
/// All integer↔double domain conversions happen here.
class WidgetAdapter {
  WidgetAdapter._();

  /// Builds the appropriate library widget for the given [config].
  static Widget build({
    required WidgetConfig config,
    required RadioWidgetState? state,
    required void Function(List<int> values) onInputChanged,
    required double scale,
  }) {
    switch (config.typeId) {
      case kWidgetButton:
        return _buildButton(config, state, onInputChanged, scale);
      case kWidgetSwitch:
        return _buildSwitch(config, state, onInputChanged, scale);
      case kWidgetSlideSwitch:
        return _buildSlideSwitch(config, state, onInputChanged, scale);
      case kWidgetSlider:
        return _buildSlider(config, state, onInputChanged, scale);
      case kWidgetKnob:
        return _buildKnob(config, state, onInputChanged, scale);
      case kWidgetJoystick:
        return _buildJoystick(config, state, onInputChanged, scale);
      case kWidgetLed:
        return _buildLed(config, state, scale);
      case kWidgetText:
        return _buildDisplay(config, state, scale);
      case kWidgetMultiple:
        return _buildMultiple(config, state, onInputChanged, scale);
      default:
        return _buildUnknown(config);
    }
  }

  // ── Button ────────────────────────────────────────────────────────────────

  static Widget _buildButton(
    WidgetConfig config,
    RadioWidgetState? state,
    void Function(List<int>) onInputChanged,
    double scale,
  ) {
    final value = state?.inputValues[config.widgetId]?.first ?? 0;
    final isToggle = config.variant == 1;
    final size = config.h * scale;

    return _ExternalStateButton(
      key: ValueKey('btn_${config.widgetId}'),
      isPressed: value != 0,
      mode: isToggle ? RKButtonMode.toggle : RKButtonMode.push,
      size: size,
      onText: config.onText.isNotEmpty ? config.onText : null,
      offText: config.offText.isNotEmpty ? config.offText : null,
      onIcon: config.icon.isNotEmpty ? parseIconFromName(config.icon) : null,
      onChanged: (pressed) {
        onInputChanged([pressed ? 1 : 0]);
      },
    );
  }

  // ── Switch (toggle via RKButton) ──────────────────────────────────────────

  static Widget _buildSwitch(
    WidgetConfig config,
    RadioWidgetState? state,
    void Function(List<int>) onInputChanged,
    double scale,
  ) {
    final value = state?.inputValues[config.widgetId]?.first ?? 0;
    final size = config.h * scale;

    return _ExternalStateButton(
      key: ValueKey('sw_${config.widgetId}'),
      isPressed: value != 0,
      mode: RKButtonMode.toggle,
      size: size,
      onText: config.onText.isNotEmpty ? config.onText : 'ON',
      offText: config.offText.isNotEmpty ? config.offText : 'OFF',
      onChanged: (pressed) {
        onInputChanged([pressed ? 1 : 0]);
      },
    );
  }

  // ── SlideSwitch ───────────────────────────────────────────────────────────

  static Widget _buildSlideSwitch(
    WidgetConfig config,
    RadioWidgetState? state,
    void Function(List<int>) onInputChanged,
    double scale,
  ) {
    final value = state?.inputValues[config.widgetId]?.first ?? 0;
    final w = config.w * scale;
    final h = config.h * scale;

    return RKSlideSwitch(
      key: ValueKey('ss_${config.widgetId}'),
      value: value != 0,
      width: w,
      height: h,
      onText: config.onText.isNotEmpty ? config.onText : 'ON',
      offText: config.offText.isNotEmpty ? config.offText : 'OFF',
      onChanged: (v) => onInputChanged([v ? 1 : 0]),
    );
  }

  // ── Slider ────────────────────────────────────────────────────────────────

  static Widget _buildSlider(
    WidgetConfig config,
    RadioWidgetState? state,
    void Function(List<int>) onInputChanged,
    double scale,
  ) {
    final rawValue = state?.inputValues[config.widgetId]?.first ?? 0;

    // Protocol range: -100..100 → normalized 0.0..1.0
    final normalized = (rawValue + 100) / 200.0;

    // Centering from variant bits
    final centerMode = variantCentering(config.variant);
    final detents = variantDetents(config.variant);
    final autoCenter = centerMode != kCenterNone;

    // Determine center position (normalized)
    double centerPos = 0.5;
    if (centerMode == kCenterMin) centerPos = 0.0;
    else if (centerMode == kCenterMid) centerPos = 0.5;
    else if (centerMode == kCenterMax) centerPos = 1.0;

    // Determine orientation from aspect ratio
    final orientation = config.w > config.h ? RKAxis.horizontal : RKAxis.vertical;

    // Determine length from the longer dimension
    final length = (orientation == RKAxis.horizontal ? config.w : config.h) * scale;

    final isGasPedal = variantIsAlternateShape(config.variant);

    if (isGasPedal) {
      return RKGasPedal(
        key: ValueKey('sl_${config.widgetId}'),
        value: normalized,
        min: 0.0,
        max: 1.0,
        orientation: orientation,
        length: length,
        autoCenter: autoCenter,
        center: centerPos,
        divisions: detents > 1 ? detents : null,
        onChanged: (v) {
          int intVal = ((v * 200) - 100).round().clamp(-100, 100);
          if (detents > 1) intVal = snapToDetents(intVal, detents);
          onInputChanged([intVal]);
        },
      );
    }

    return RKSlider(
      key: ValueKey('sl_${config.widgetId}'),
      value: normalized,
      min: 0.0,
      max: 1.0,
      orientation: orientation,
      length: length,
      autoCenter: autoCenter,
      center: centerPos,
      divisions: detents > 1 ? detents : null,
      onChanged: (v) {
        int intVal = ((v * 200) - 100).round().clamp(-100, 100);
        if (detents > 1) intVal = snapToDetents(intVal, detents);
        onInputChanged([intVal]);
      },
    );
  }

  // ── Knob ──────────────────────────────────────────────────────────────────

  static Widget _buildKnob(
    WidgetConfig config,
    RadioWidgetState? state,
    void Function(List<int>) onInputChanged,
    double scale,
  ) {
    final rawValue = state?.inputValues[config.widgetId]?.first ?? 0;

    // Protocol range: -100..100 → normalized 0.0..1.0
    final normalized = (rawValue + 100) / 200.0;

    final centerMode = variantCentering(config.variant);
    final detents = variantDetents(config.variant);
    final autoCenter = centerMode != kCenterNone;

    double centerPos = 0.5;
    if (centerMode == kCenterMin) centerPos = 0.0;
    else if (centerMode == kCenterMid) centerPos = 0.5;
    else if (centerMode == kCenterMax) centerPos = 1.0;

    final size = config.h * scale;
    final knobVariant = variantIsAlternateShape(config.variant)
        ? RKKnobVariant.steeringWheel
        : RKKnobVariant.standard;

    return RKKnob(
      key: ValueKey('kn_${config.widgetId}'),
      value: normalized,
      min: 0.0,
      max: 1.0,
      size: size,
      variant: knobVariant,
      autoCenter: autoCenter,
      center: centerPos,
      minAngle: config.minAngle,
      maxAngle: config.maxAngle,
      divisions: detents > 1 ? detents : null,
      onChanged: (v) {
        int intVal = ((v * 200) - 100).round().clamp(-100, 100);
        if (detents > 1) intVal = snapToDetents(intVal, detents);
        onInputChanged([intVal]);
      },
    );
  }

  // ── Joystick ──────────────────────────────────────────────────────────────

  static Widget _buildJoystick(
    WidgetConfig config,
    RadioWidgetState? state,
    void Function(List<int>) onInputChanged,
    double scale,
  ) {
    final values = state?.inputValues[config.widgetId] ?? [0, 0];
    final rawX = values.isNotEmpty ? values[0] : 0;
    final rawY = values.length > 1 ? values[1] : 0;

    // Protocol range: -100..100 → normalized -1.0..1.0
    final size = config.h * scale;

    return RKJoystick(
      key: ValueKey('js_${config.widgetId}'),
      value: RKJoystickValue(x: rawX / 100.0, y: rawY / 100.0),
      size: size,
      autoCenter: variantCentering(config.variant) != kCenterNone,
      label: null,
      onChanged: (v) {
        // Normalized -1.0..1.0 → protocol -100..100
        final intX = (v.x * 100).round().clamp(-100, 100);
        final intY = (v.y * 100).round().clamp(-100, 100);
        onInputChanged([intX, intY]);
      },
    );
  }

  // ── LED ───────────────────────────────────────────────────────────────────

  static Widget _buildLed(
    WidgetConfig config,
    RadioWidgetState? state,
    double scale,
  ) {
    final value = state?.outputValues[config.widgetId];
    final ledBytes = (value is List<int>) ? value : [0, 0, 0, 0, 0];

    // LED v3: [STATE, R, G, B, OPACITY]
    final stateVal = ledBytes.isNotEmpty ? ledBytes[0] : 0;
    final r = ledBytes.length > 1 ? ledBytes[1] : 0;
    final g = ledBytes.length > 2 ? ledBytes[2] : 0;
    final b = ledBytes.length > 3 ? ledBytes[3] : 0;
    final opacity = ledBytes.length > 4 ? ledBytes[4] : 255;

    // Map state byte to RKLEDState
    RKLEDState ledState;
    switch (stateVal) {
      case 0: ledState = RKLEDState.off; break;
      case 1: ledState = RKLEDState.on; break;
      case 2: ledState = RKLEDState.blink; break;
      case 3: ledState = RKLEDState.breathe; break;
      default: ledState = RKLEDState.off;
    }

    final size = config.h * scale;
    final color = (r == 0 && g == 0 && b == 0)
        ? null // Use theme primary
        : Color.fromARGB(opacity, r, g, b);

    return RKLed(
      key: ValueKey('led_${config.widgetId}'),
      state: ledState,
      size: size,
      color: color,
    );
  }

  // ── Display (Text) ────────────────────────────────────────────────────────

  static Widget _buildDisplay(
    WidgetConfig config,
    RadioWidgetState? state,
    double scale,
  ) {
    final value = state?.outputValues[config.widgetId] ?? '';
    final text = value.toString();

    return RKDisplay(
      key: ValueKey('txt_${config.widgetId}'),
      text: text.isEmpty ? '—' : text,
    );
  }

  // ── Multiple (Radio / Bitmask) ────────────────────────────────────────────

  static Widget _buildMultiple(
    WidgetConfig config,
    RadioWidgetState? state,
    void Function(List<int>) onInputChanged,
    double scale,
  ) {
    final value = state?.inputValues[config.widgetId]?.first ?? 0;
    final items = config.multipleItems;
    final isBitmask = config.variant == 1;

    // Convert MultipleItem → RKToggleItem
    final rkItems = items.map((mi) {
      final icon = mi.icon.isNotEmpty ? parseIconFromName(mi.icon) : null;
      return RKToggleItem(
        onLabel: mi.label,
        offLabel: mi.label,
        onIcon: icon,
        offIcon: icon,
      );
    }).toList();

    if (rkItems.isEmpty) return _buildUnknown(config);

    final buttonSize = config.h * scale * 0.8;

    if (isBitmask) {
      return RKMultiSelect(
        key: ValueKey('ms_${config.widgetId}'),
        items: rkItems,
        bitmask: value,
        buttonSize: buttonSize,
        onChanged: (mask) => onInputChanged([mask]),
      );
    }

    return RKMultiButton(
      key: ValueKey('mb_${config.widgetId}'),
      items: rkItems,
      selected: value.clamp(0, rkItems.length - 1),
      buttonSize: buttonSize,
      onChanged: (idx) => onInputChanged([idx]),
    );
  }

  // ── Unknown ───────────────────────────────────────────────────────────────

  static Widget _buildUnknown(WidgetConfig config) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF444446)),
      ),
      child: Center(
        child: Text(
          'Unknown\n${config.widgetId}',
          style: const TextStyle(color: Colors.white38, fontSize: 10),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

// ── External-State Button Wrapper ─────────────────────────────────────────
//
// RKButton manages its own internal pressed/latched state, but the app's
// DeviceProvider is the source of truth (integer values from the protocol).
// This wrapper bridges the two by driving RKButton from external state.

class _ExternalStateButton extends StatefulWidget {
  final bool isPressed;
  final RKButtonMode mode;
  final double size;
  final String? onText;
  final String? offText;
  final IconData? onIcon;
  final ValueChanged<bool> onChanged;

  const _ExternalStateButton({
    super.key,
    required this.isPressed,
    required this.mode,
    required this.size,
    required this.onChanged,
    this.onText,
    this.offText,
    this.onIcon,
  });

  @override
  State<_ExternalStateButton> createState() => _ExternalStateButtonState();
}

class _ExternalStateButtonState extends State<_ExternalStateButton> {
  @override
  Widget build(BuildContext context) {
    // Use the library button directly — it manages its own visual state,
    // but we relay the onChanged callback to the DeviceProvider.
    return RKButton(
      mode: widget.mode,
      size: widget.size,
      onText: widget.onText,
      offText: widget.offText,
      onIcon: widget.onIcon,
      onChanged: widget.onChanged,
    );
  }
}
