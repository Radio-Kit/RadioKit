import 'protocol.dart';

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

  /// Human-readable label (always present as first string in wire format).
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

  /// Center icon string (present if kStrMaskExtra is set for Knob).
  final String centerIcon;

  /// Rotation as stored on the wire (int16, degrees ÷ 2).
  /// Multiply by 2 to get display degrees.
  final int rotation;

  /// Whether the label should be hidden in the UI (set via kStrMaskLabelHidden bit).
  final bool labelHidden;

  /// Whether the widget is hidden in the UI (set via kStrMaskWidgetHidden bit).
  final bool hidden;

  /// The page index this widget belongs to (0-indexed).
  final int pageIndex;

  /// The float multiplier for width (scalewidth).
  double get widthF => width / 10.0;

  /// The float multiplier for height (scaleheight).
  double get heightF => height / 10.0;

  /// Whether this widget supports independent width/height control on the device.
  bool get isResizable => typeId == kWidgetSlider || typeId == kWidgetText;

  /// Display rotation in degrees (wire stores degrees÷2 as int16).
  double get rotationDegrees => (rotation * 2).toDouble();


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
    this.centerIcon = '',
    this.labelHidden = false,
    this.hidden = false,
    this.pageIndex = 0,
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
    String? centerIcon,
    bool? labelHidden,
    bool? hidden,
    int? pageIndex,
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
      centerIcon: centerIcon ?? this.centerIcon,
      labelHidden: labelHidden ?? this.labelHidden,
      hidden: hidden ?? this.hidden,
      pageIndex: pageIndex ?? this.pageIndex,
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

  /// Converts this [WidgetConfig] to a designer-format JSON map
  /// suitable for [DesignerElement.fromJson] or [DesignerState.loadFromJson].
  ///
  /// [canvasW] / [canvasH] are the designer canvas dimensions in grid units
  /// (typically 200×100 for landscape, 100×200 for portrait).
  ///
  /// Coordinate system: The wire protocol and the designer JSON both use
  /// top-left origin (Y increases downward). The wire stores the same
  /// grid-unit values that the JSON uses directly.
  Map<String, dynamic> toDesignerJsonMap(int canvasW, int canvasH) {
    final props = _buildDesignerProps();

    // ── Size: wire stores grid units directly ──────────────────────────────
    // width=0 means aspect-ratio-driven → emit null so DesignerElement.fromJson
    // derives it from height × aspectRatio.
    final int? jsonW = width == 0 ? null : width;
    final int jsonH = height.clamp(1, canvasH);

    // ── Position: top-left origin, no Y flip needed ────────────────────────
    final posX = x.round().clamp(0, canvasW);
    final posY = y.round().clamp(0, canvasH);

    // ── Auto-center ───────────────────────────────────────────────────────
    props['autoCenter'] = _acListForCentering(variantCentering(variant));

    // ── Variant / mode ────────────────────────────────────────────────────
    final (String? topVariant, String? propVariant) = _resolveVariants();

    // ── Type string: use base type, variant is promoted separately ─────────
    final typeStr = _wireTypeToDesignerTypeName(typeId);

    // ── Label ─────────────────────────────────────────────────────────────
    final hasLabel = label.isNotEmpty;
    final displayLabel = hasLabel ? label : 'widget_$widgetId';
    final shouldShow = hasLabel && !labelHidden;

    final result = <String, dynamic>{
      'type': typeStr,
      'name': displayLabel,
      'label': <String, dynamic>{'text': displayLabel, 'show': shouldShow},
      'position': [posX, posY, rotationDegrees.round()],
      'size': [jsonW, jsonH],
      'haptic': true,
      'properties': props,
    };

    if (topVariant != null) result['variant'] = topVariant;
    if (propVariant != null) {
      result['properties']['variant'] = propVariant;
    }
    if (hidden) result['hidden'] = true;

    return result;
  }

  /// Maps wire typeId to designer JSON type string (base type, variant promoted
  /// separately by [_resolveVariants]).
  static String _wireTypeToDesignerTypeName(int typeId) {
    switch (typeId) {
      case kWidgetButton:      return 'button';
      // Wire type 0x02 is a toggle button (RK_TYPE_TOGGLE_BUTTON), not the
      // legacy 'switch' the constant name suggests — it must render as a button.
      case kWidgetSwitch:      return 'button';
      case kWidgetSlideSwitch: return 'switch';
      case kWidgetSlider:      return 'slider';
      case kWidgetKnob:        return 'knob';
      case kWidgetJoystick:    return 'joystick';
      case kWidgetLed:         return 'led';
      case kWidgetText:        return 'text';
      case kWidgetMultiple:    return 'multiple';
      case kWidgetTelemetry:   return 'telemetry';
      default:                 return 'button';
    }
  }

  /// Build the base properties map for designer JSON.
  Map<String, dynamic> _buildDesignerProps() {
    final p = <String, dynamic>{
      'widgetId': widgetId,
    };

    // Text-capable widgets (button / toggle-button / slide-switch) always
    // carry onText/offText, including empty strings — the designer's own
    // toJson emits them explicitly, and DesignerElement.fromJson seeds
    // defaults for missing keys ("ON"/"OFF"). Omitting empty text here would
    // make an icon-only button silently render default labels after load.
    final supportsText = typeId == kWidgetButton ||
        typeId == kWidgetSwitch ||
        typeId == kWidgetSlideSwitch;
    if (supportsText) {
      p['onText'] = onText;
      p['offText'] = offText;
    } else {
      if (onText.isNotEmpty) p['onText'] = onText;
      if (offText.isNotEmpty) p['offText'] = offText;
    }
    p['minAngle'] = minAngle;
    p['maxAngle'] = maxAngle;

    // The wire carries a single icon string for button/switch-style widgets;
    // map it to the designer's onIcon field (the off-state falls back to the
    // on-state icon when offIcon is unset). Knobs carry their center icon in
    // the EXTRA block instead.
    if (icon.isNotEmpty) p['onIcon'] = icon;
    if (typeId == kWidgetKnob && centerIcon.isNotEmpty) {
      p['centerIcon'] = centerIcon;
    }

    final detents = variantDetents(variant);
    if (detents > 1) p['divisions'] = detents;

    if (typeId == kWidgetMultiple) {
      final items = multipleItems;
      p['itemCount'] = items.length;
      p['items'] = items.map((m) => <String, dynamic>{
        'onLabel': m.label,
        'onIcon': m.icon.isNotEmpty ? m.icon : null,
        'offLabel': null,
        'offIcon': null,
      }).toList();
    }

    return p;
  }

  /// Resolves variant strings for wire protocol values.
  /// Returns (topLevelVariant, propertyVariant) — either may be null.
  (String?, String?) _resolveVariants() {
    switch (typeId) {
      case kWidgetButton:
        if (variant == 1) return (null, 'toggle');
        return (null, 'push');
      case kWidgetSwitch:
        // 0x02 is RK_TYPE_TOGGLE_BUTTON on the wire: always a latching toggle.
        return (null, 'toggle');
      case kWidgetSlider:
        if (variantIsAlternateShape(variant)) return ('gasPedal', null);
        return (null, null);
      case kWidgetKnob:
        if (variantIsAlternateShape(variant)) return ('steeringWheel', null);
        return (null, null);
      case kWidgetMultiple:
        return (variant == 1 ? 'multiSelect' : 'multiButton', null);
      case kWidgetSlideSwitch:
        return ('slideSwitch', null);
      default:
        return (null, null);
    }
  }

  /// Maps a protocol centering mode to the designer autoCenter list format.
  static List<dynamic> _acListForCentering(int centerMode) {
    switch (centerMode) {
      case kCenterMin:    return ['min', 'smooth', 300];
      case kCenterMid:    return ['center', 'smooth', 300];
      case kCenterMax:    return ['max', 'smooth', 300];
      case kCenterTop:    return ['top', 'smooth', 300];
      case kCenterBottom: return ['bottom', 'smooth', 300];
      default:            return [null, 'smooth', 300];
    }
  }

  @override
  String toString() =>
      'WidgetConfig(id=$widgetId, page=$pageIndex, type=$typeName, label="$label", '
      'pos=($x,$y), scale=$widthF×$heightF, '
      'style=$style, variant=$variant, rot=$rotationDegrees°)';
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
        } else if (w.typeId == kWidgetSlider || w.typeId == kWidgetKnob) {
          final center = variantCentering(w.variant);
          if (center == kCenterMin || center == kCenterTop) {
            inputs[w.widgetId] = [-100];
          } else if (center == kCenterMax || center == kCenterBottom) {
            inputs[w.widgetId] = [100];
          } else {
            inputs[w.widgetId] = [0];
          }
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

/// Converts a list of [WidgetConfig] + metadata to a full designer-format JSON map (version 2).
///
/// The output matches the schema used by [DesignerState.loadFromJson] and
/// [DesignerElement.fromJson], grouping widgets into `pages[]` arrays.
Map<String, dynamic> widgetConfigsToDesignerJson({
  required List<WidgetConfig> widgets,
  required String name,
  required String description,
  required int orientation,
  required String theme,
  List<String>? pageNames,
  int? numPages,
  Map<String, dynamic>? features,
  bool? enableControlUI,
  bool? showPageBar,
  bool? showControlPageBar,
}) {
  final isLandscape = orientation == kOrientationLandscape;
  final canvasW = isLandscape ? 200 : 100;
  final canvasH = isLandscape ? 100 : 200;

  // Split telemetry widgets out of the page widget lists. Telemetry widgets
  // are display-only (no canvas position) and are serialized as a top-level
  // `telemetry[]` array in the v2 schema.
  final telemetryWidgets = widgets
      .where((w) => WidgetConfig._wireTypeToDesignerTypeName(w.typeId) == 'telemetry')
      .toList();
  final uiWidgets = widgets
      .where((w) => WidgetConfig._wireTypeToDesignerTypeName(w.typeId) != 'telemetry')
      .toList();

  // Determine highest page index among UI widgets
  int maxPageIndex = 0;
  for (final w in uiWidgets) {
    if (w.pageIndex > maxPageIndex) {
      maxPageIndex = w.pageIndex;
    }
  }
  if (pageNames != null && pageNames.length - 1 > maxPageIndex) {
    maxPageIndex = pageNames.length - 1;
  }
  // The device may report more pages than appear in the (active-page-only)
  // CONF_DATA widget list — e.g. pageNames from PAGES_DATA or the v5 header's
  // numPages field. Prefer the highest of all sources so a multi-page device
  // never reconstructs as a flat single-page config.
  if (numPages != null && numPages - 1 > maxPageIndex) {
    maxPageIndex = numPages - 1;
  }

  final isMultiPage = maxPageIndex > 0 || (pageNames?.length ?? 1) > 1;

  final pagesJson = <Map<String, dynamic>>[];
  for (int i = 0; i <= maxPageIndex; i++) {
    final pageWidgets = uiWidgets.where((w) => w.pageIndex == i).toList();
    final pName = (pageNames != null && i < pageNames.length)
        ? pageNames[i]
        : (i == 0 ? 'Control' : 'Page ${i + 1}');
    pagesJson.add({
      'name': pName,
      'orientation': isLandscape ? 'landscape' : 'portrait',
      'widgets': pageWidgets
          .map((w) => w.toDesignerJsonMap(canvasW, canvasH))
          .toList(),
    });
  }

  final result = <String, dynamic>{
    'version': 2,
    'appdata': <String, dynamic>{
      'appVersion': '1.0.0',
    },
    'config': <String, dynamic>{
      'name': name,
      'description': description,
      'type': 'Locomotive',
      'transport': 'BLE',
      'theme': theme.isNotEmpty ? theme : 'dragon',
      'password': '',
    },
    'canvas': <String, dynamic>{
      'size': [canvasW, canvasH],
      'grid': 'none',
      'skin': theme.isNotEmpty ? theme : 'dragon',
      if (showPageBar != null) 'showPageBar': showPageBar,
      if (showControlPageBar != null) 'showControlPageBar': showControlPageBar,
    },
  };

  if (enableControlUI != null) result['enableControlUI'] = enableControlUI;
  if (features != null) result['features'] = features;

  // Telemetry widgets are reconstructed as {label, icon} entries; unit is not
  // carried on the wire.
  if (telemetryWidgets.isNotEmpty) {
    result['telemetry'] = telemetryWidgets.map((w) {
      return <String, dynamic>{
        'label': w.label.isEmpty ? 'telemetry_${w.widgetId}' : w.label,
        if (w.icon.isNotEmpty) 'icon': w.icon,
      };
    }).toList();
  }

  if (isMultiPage) {
    result['pages'] = pagesJson;
  } else {
    result['widgets'] = uiWidgets
        .map((w) => w.toDesignerJsonMap(canvasW, canvasH))
        .toList();
  }

  return result;
}

/// Extracts the designer-only metadata (features, enableControlUI, page-bar
/// flags) from a saved design JSON map.
///
/// A live device connection reconstructs the config JSON from the wire, which
/// does not carry these app/designer-only fields. When a saved design matches
/// the connected device, its metadata is merged into the reconstruction so
/// flags like `canvas.showControlPageBar` survive a BLE/serial connect.
/// Returns `null` when the source is not a map or carries none of the fields.
Map<String, dynamic>? designMetadataFromJson(Map<String, dynamic>? designJson) {
  if (designJson == null) return null;
  final canvas = designJson['canvas'];
  final canvasMap = canvas is Map<String, dynamic> ? canvas : null;
  final result = <String, dynamic>{};
  final features = designJson['features'];
  if (features is Map<String, dynamic>) result['features'] = features;
  final enableControlUI = designJson['enableControlUI'];
  if (enableControlUI is bool) result['enableControlUI'] = enableControlUI;
  if (canvasMap != null) {
    final showPageBar = canvasMap['showPageBar'];
    if (showPageBar is bool) result['showPageBar'] = showPageBar;
    final showControlPageBar = canvasMap['showControlPageBar'];
    if (showControlPageBar is bool) {
      result['showControlPageBar'] = showControlPageBar;
    }
  }
  return result.isEmpty ? null : result;
}
