import 'protocol.dart';

// These are the baseline dimensions of each widget at scale=1.0.
// Resizable widgets (Slider, Text) use both maps. 
// Non-resizable widgets ignore kWidgetBaseWidth and derive width from height * aspect.
const Map<int, double> kWidgetBaseHeight = {
  kWidgetButton:      15.0,
  kWidgetSlideSwitch:  12.0,
  kWidgetSlider:      10.0,
  kWidgetJoystick:    20.0,
  kWidgetLed:          15.0,
  kWidgetText:         10.0,
  kWidgetMultiple:    10.0,
  kWidgetKnob:        20.0,
};

const Map<int, double> kWidgetDefaultAspect = {
  kWidgetButton:      1.0, // Visual Square
  // kWidgetSwitch:      5.0, // Wide Pill
  kWidgetSlideSwitch: 2.5,
  kWidgetSlider:      1.0, 
  kWidgetJoystick:    1.0, // Visual Square
  kWidgetLed:         1.0, // Visual Square
  kWidgetMultiple:    1.0,
  kWidgetKnob:        1.0, // Visual Square
  kWidgetText:         5.0,
};

/// Represents a single item in a Multiple widget.
class MultipleItem {
  final String label;
  final String icon;
  const MultipleItem(this.label, this.icon);
}

/// Configuration for a single UI widget, parsed from a v3 CONF_DATA payload.
///
/// Coordinate system:
///   - Origin (0,0) is the bottom-left corner of the virtual canvas.
///   - X increases rightward; Y increases upward.
///   - [x] and [y] are the CENTER point of the widget.
class WidgetConfig {
  final int typeId;
  final int widgetId;

  /// Center X in virtual canvas coordinates (uint8).
  final double x;

  /// Center Y in virtual canvas coordinates, bottom-left origin (uint8).
  final double y;

  /// Scale Width factor × 10 (uint8). 
  /// From the user/firmware perspective, this is "scalewidth".
  /// e.g. 20 = 2.0× multiplier.
  final int width;

  /// Scale Height factor × 10 (uint8). 
  /// From the user/firmware perspective, this is "scaleheight".
  /// e.g. 10 = 1.0× multiplier.
  final int height;

  /// Style / color variant (uint8, v3). See kStyle* constants.
  final int style;

  /// Widget-specific variant byte (uint8, v3).
  /// Button: 0 = push/momentary, 1 = toggle
  /// Multiple: number of items (1–8)
  /// Slider/Knob: bit 7 is Alt Shape (GasPedal/Steering), bits 1:0 are centering.
  final int variant;

  /// String presence bitmask (uint8, v3). See kStrMask* constants.
  final int strMask;

  /// Human-readable label (present if kStrMaskLabel bit is set).
  final String label;

  /// Icon identifier string (present if kStrMaskIcon bit is set).
  final String icon;

  /// ON state label (present if kStrMaskOnText bit is set).
  final String onText;

  /// OFF state label (present if kStrMaskOffText bit is set).
  final String offText;

  /// Content string — pipe-delimited items for Multiple widget
  /// (present if kStrMaskContent bit is set).
  final String content;
  
  /// Minimum sweep angle (present if kStrMaskExtra is set for Knob).
  final double minAngle;

  /// Maximum sweep angle (present if kStrMaskExtra is set for Knob).
  final double maxAngle;

  /// Rotation as stored on the wire (int16, degrees ÷ 2).
  /// Multiply by 2 to get display degrees.
  final int rotation;

  /// The float multiplier for width (scalewidth).
  double get widthF => width / 10.0;

  /// The float multiplier for height (scaleheight).
  double get heightF => height / 10.0;

  /// Whether this widget supports independent width/height control.
  bool get isResizable => typeId == kWidgetSlider || typeId == kWidgetText;

  /// Returns true if this slider is a Gas Pedal variant.
  bool get isGasPedal => typeId == kWidgetSlider && variantIsAlternateShape(variant);

  /// Returns true if this knob is a Steering Wheel variant.
  bool get isSteeringWheel => typeId == kWidgetKnob && variantIsAlternateShape(variant);

  /// Returns a full descriptive label for debug mode (e.g. "Knob:Steering").
  String get debugLabel {
    final typeName = widgetTypeName(typeId);
    final variantName = widgetVariantName(typeId, variant);
    if (variantName.isEmpty) return typeName;
    return '$typeName:$variantName';
  }

  /// The intrinsic aspect ratio of this widget.
  /// For Multiple widgets, this is derived from the number of menu items.
  double get dynamicAspect {
    if (typeId == kWidgetMultiple) {
      final itemsCount = multipleItems.length;
      return itemsCount > 0 ? itemsCount.toDouble() : 1.0;
    }
    return kWidgetDefaultAspect[typeId] ?? 1.0;
  }

  /// Base height for this widget type in canvas units at scale 1.0.
  double get baseH => kWidgetBaseHeight[typeId] ?? 10.0;

  /// Base width derived from height and aspect ratio.
  double get baseW => baseH * dynamicAspect;

  /// Computed height in absolute virtual units for the canvas.
  double get h => baseH * heightF;

  /// Computed width in absolute virtual units for the canvas.
  /// For all widgets, width scales with height scale [heightF]. 
  /// For resizable widgets, the [widthF] acts as an additional multiplier.
  double get w => baseW * heightF * (isResizable ? widthF : 1.0);

  /// Display rotation in degrees.
  double get rotationDegrees => rotation.toDouble();

  const WidgetConfig({
    required this.typeId,
    required this.widgetId,
    required this.x,
    required this.y,
    this.width = 10,
    required this.height,
    this.style   = 0,
    this.variant = 0,
    this.strMask = 0,
    this.label   = '',
    this.icon    = '',
    this.onText  = '',
    this.offText = '',
    this.content = '',
    this.rotation = 0,
    this.minAngle = -135,
    this.maxAngle = 135,
  });

  WidgetConfig copyWith({
    int? typeId,
    int? widgetId,
    double? x,
    double? y,
    int? width,
    int? height,
    int? style,
    int? variant,
    int? strMask,
    String? label,
    String? icon,
    String? onText,
    String? offText,
    String? content,
    int? rotation,
    double? minAngle,
    double? maxAngle,
  }) {
    return WidgetConfig(
      typeId:   typeId   ?? this.typeId,
      widgetId: widgetId ?? this.widgetId,
      x:        x        ?? this.x,
      y:        y        ?? this.y,
      width:    width    ?? this.width,
      height:   height   ?? this.height,
      style:    style    ?? this.style,
      variant:  variant  ?? this.variant,
      strMask:  strMask  ?? this.strMask,
      label:    label    ?? this.label,
      icon:     icon     ?? this.icon,
      onText:   onText   ?? this.onText,
      offText:  offText  ?? this.offText,
      content:  content  ?? this.content,
      rotation: rotation ?? this.rotation,
      minAngle: minAngle ?? this.minAngle,
      maxAngle: maxAngle ?? this.maxAngle,
    );
  }

  int get inputSize  => kWidgetInputSize[typeId]  ?? 0;
  int get outputSize => kWidgetOutputSize[typeId] ?? 0;
  bool get hasInput  => inputSize > 0;
  bool get hasOutput => outputSize > 0;
  String get typeName => widgetTypeName(typeId);

  /// For Multiple widget: parse pipe-delimited items from [content].
  /// Format is "label:icon|label:icon|..."
  List<MultipleItem> get multipleItems {
    if (typeId != kWidgetMultiple || content.isEmpty) return [];
    return content.split('|').map((s) {
      final parts = s.split(':');
      if (parts.length >= 2) {
        return MultipleItem(parts[0].trim(), parts[1].trim());
      } else {
        return MultipleItem(s.trim(), '');
      }
    }).toList();
  }

  @override
  String toString() =>
      'WidgetConfig(id=$widgetId, type=$typeName, label="$label", '
      'pos=($x,$y), w=$widthF× h=$heightF× → '
      '${w.toStringAsFixed(1)}×${h.toStringAsFixed(1)}, '
      'style=$style, variant=$variant, rot=${rotationDegrees}°)';
}

/// Holds the current state (values) for all widgets.
class RadioWidgetState {
  /// Input variable values keyed by widgetId.
  /// Button/Switch/Slider/Multiple: [value]
  /// Joystick: [x, y]
  final Map<int, List<int>> inputValues;

  /// Output variable values keyed by widgetId.
  /// LED: [state, r, g, b, opacity]  (v3 – 5 bytes)
  /// Text: String
  final Map<int, dynamic> outputValues;

  const RadioWidgetState({
    required this.inputValues,
    required this.outputValues,
  });

  factory RadioWidgetState.initial(List<WidgetConfig> widgets) {
    final inputs  = <int, List<int>>{};
    final outputs = <int, dynamic>{};

    for (final w in widgets) {
      if (w.hasInput) {
        if (w.typeId == kWidgetJoystick) {
          inputs[w.widgetId] = [0, 0];
        } else {
          inputs[w.widgetId] = [0];
        }
      }
      if (w.hasOutput) {
        if (w.typeId == kWidgetText) {
          outputs[w.widgetId] = '';
        } else if (w.typeId == kWidgetLed) {
          outputs[w.widgetId] = [0, 0, 0, 0, 0]; // STATE R G B OPACITY
        } else {
          outputs[w.widgetId] = 0;
        }
      }
    }

    return RadioWidgetState(inputValues: inputs, outputValues: outputs);
  }

  RadioWidgetState copyWithInput(int widgetId, List<int> values) {
    final newInputs = Map<int, List<int>>.from(inputValues);
    newInputs[widgetId] = values;
    return RadioWidgetState(inputValues: newInputs, outputValues: outputValues);
  }

  RadioWidgetState copyWithOutput(int widgetId, dynamic value) {
    final newOutputs = Map<int, dynamic>.from(outputValues);
    newOutputs[widgetId] = value;
    return RadioWidgetState(inputValues: inputValues, outputValues: newOutputs);
  }
}
