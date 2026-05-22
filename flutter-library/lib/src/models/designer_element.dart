enum DesignerElementType {
  button,
  slideSwitch,
  rockerSwitch,
  slider,
  knob,
  steeringWheel,
  joystick,
  multiButton,
  multiSelect,
  gasPedal,
  led,
  text,
  serialMonitor,
}

class WidgetDragPayload {
  final DesignerElementType type;
  final Map<String, dynamic> properties;
  const WidgetDragPayload(this.type, this.properties);
}

class DesignerElement {
  final String id;
  final DesignerElementType type;
  int x;
  int y;
  int width;
  int height;
  Map<String, dynamic> properties;
  String label;
  bool labelHidden;
  int rotation;

  /// The aspect ratio (width/height) that this widget type enforces, or `null`
  /// if the widget has free-form sizing. When non-null the inspector shows
  /// only a single dimension field and auto-computes the other.
  double? get aspectRatio {
    switch (type) {
      case DesignerElementType.button:
      case DesignerElementType.knob:
      case DesignerElementType.steeringWheel:
      case DesignerElementType.joystick:
      case DesignerElementType.led:
        return 1.0;
      case DesignerElementType.multiButton:
      case DesignerElementType.multiSelect:
        final count = (properties['itemCount'] as num?)?.toInt() ?? 3;
        final baseAr = (count * 0.67).clamp(0.5, 10.0);
        // Positive  → horizontal (height is primary, width  = height × ar)
        // Negative  → vertical   (width  is primary, height = width  × |ar|)
        return width >= height ? baseAr : -baseAr;
      default:
        return null;
    }
  }

  /// The effective rendered size in grid units.
  (int, int) get renderedGridSize {
    final ar = aspectRatio;
    if (ar == null) return (width, height);
    if (ar >= 0) {
      // Height is primary (horizontal multi, square widgets)
      return ((height * ar).round().clamp(1, 999), height);
    } else {
      // Width is primary (vertical multi)
      return (width, (width * -ar).round().clamp(1, 999));
    }
  }

  DesignerElement({
    required this.id,
    required this.type,
    this.x = 10,
    this.y = 10,
    this.width = 20,
    this.height = 20,
    Map<String, dynamic>? properties,
    this.label = '',
    this.labelHidden = false,
    this.rotation = 0,
  }) : properties = properties ?? _defaultProperties(type);

  static Map<String, dynamic> _defaultProperties(DesignerElementType type) {
    switch (type) {
      case DesignerElementType.button:
        return {
          'onText': 'ON',
          'offText': 'OFF',
          'onIcon': null,
          'offIcon': null,
        };
      case DesignerElementType.slideSwitch:
        return {
          'onText': 'ON',
          'offText': 'OFF',
        };
      case DesignerElementType.rockerSwitch:
        return {
          'onIcon': null,
          'offIcon': null,
        };
      case DesignerElementType.multiButton:
        return {
          'itemCount': 3,
          'items': List.generate(
              3,
              (i) => <String, dynamic>{
                    'onLabel': String.fromCharCode(65 + i),
                    'onIcon': null,
                    'offLabel': null,
                    'offIcon': null,
                  }),
        };
      case DesignerElementType.multiSelect:
        return {
          'itemCount': 3,
          'items': List.generate(
              3,
              (i) => <String, dynamic>{
                    'onLabel': String.fromCharCode(65 + i),
                    'onIcon': null,
                    'offLabel': null,
                    'offIcon': null,
                  }),
        };
      case DesignerElementType.slider:
        return {
          'min': 0,
          'max': 100,
          'autoCenter': false,
          'center': 0.5,
          'springBehavior': 'smooth',
          'springDuration': 300,
          'divisions': null,
        };
      case DesignerElementType.knob:
        return {
          'min': 0,
          'max': 100,
          'minAngle': -135,
          'maxAngle': 135,
          'autoCenter': false,
          'center': 0.5,
          'centerIcon': null,
          'springBehavior': 'smooth',
          'springDuration': 500,
          'divisions': null,
        };
      case DesignerElementType.steeringWheel:
        return {
          'min': 0,
          'max': 100,
          'minAngle': -135,
          'maxAngle': 135,
          'autoCenter': false,
          'center': 0.5,
          'centerIcon': null,
          'springBehavior': 'smooth',
          'springDuration': 500,
          'divisions': null,
        };
      case DesignerElementType.joystick:
        return {
          'autoCenter': true,
          'centerX': 0.0,
          'centerY': 0.0,
          'springBehavior': 'smooth',
          'springDuration': 300,
        };
      case DesignerElementType.gasPedal:
        return {
          'min': 0,
          'max': 100,
          'autoCenter': false,
          'center': 0.0,
          'springBehavior': 'smooth',
          'springDuration': 300,
        };
      case DesignerElementType.led:
        return {
          'state': 'off',
          'shape': 'circle',
          'color': 0x00FF00,
          'timing': 500,
        };
      case DesignerElementType.text:
        return {
          'text': 'Display',
          'fontSize': 14,
          'fontFamily': 'monospace',
        };
      case DesignerElementType.serialMonitor:
        return {
          'fontSize': 12,
          'fontFamily': 'monospace',
        };
    }
  }

  /// Returns the aspect ratio for [type] based on its current [properties],
  /// or `null` for free-form widgets.
  static double? _aspectRatioFor(
      DesignerElementType type, Map<String, dynamic> properties) {
    switch (type) {
      case DesignerElementType.button:
      case DesignerElementType.knob:
      case DesignerElementType.steeringWheel:
      case DesignerElementType.joystick:
      case DesignerElementType.led:
        return 1.0;
      default:
        return null;
    }
  }

  static (int, int) defaultSize(DesignerElementType type) {
    switch (type) {
      case DesignerElementType.button:
        return (20, 20);
      case DesignerElementType.slideSwitch:
        return (40, 15);
      case DesignerElementType.rockerSwitch:
        return (15, 30);
      case DesignerElementType.slider:
        return (40, 10);
      case DesignerElementType.knob:
        return (20, 20);
      case DesignerElementType.steeringWheel:
        return (25, 25);
      case DesignerElementType.joystick:
        return (30, 30);
      case DesignerElementType.multiButton:
        return (40, 20);
      case DesignerElementType.multiSelect:
        return (40, 20);
      case DesignerElementType.gasPedal:
        return (15, 30);
      case DesignerElementType.led:
        return (10, 10);
      case DesignerElementType.text:
        return (60, 15);
      case DesignerElementType.serialMonitor:
        return (60, 40);
    }
  }

  DesignerElement copyWith({
    String? id,
    DesignerElementType? type,
    int? x,
    int? y,
    int? width,
    int? height,
    Map<String, dynamic>? properties,
    String? label,
    bool? labelHidden,
    int? rotation,
  }) {
    return DesignerElement(
      id: id ?? this.id,
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      properties: properties ?? Map<String, dynamic>.from(this.properties),
      label: label ?? this.label,
      labelHidden: labelHidden ?? this.labelHidden,
      rotation: rotation ?? this.rotation,
    );
  }

  String get jsonTypeStr {
    switch (type) {
      case DesignerElementType.button:
        return 'button';
      case DesignerElementType.slideSwitch:
        return 'slideSwitch';
      case DesignerElementType.rockerSwitch:
        return 'switch';
      case DesignerElementType.slider:
        return 'slider';
      case DesignerElementType.gasPedal:
        return 'slider';
      case DesignerElementType.knob:
        return 'knob';
      case DesignerElementType.steeringWheel:
        return 'knob';
      case DesignerElementType.joystick:
        return 'joystick';
      case DesignerElementType.multiButton:
        return 'multiple';
      case DesignerElementType.multiSelect:
        return 'multiple';
      case DesignerElementType.led:
        return 'led';
      case DesignerElementType.text:
        return 'text';
      case DesignerElementType.serialMonitor:
        return 'serialMonitor';
    }
  }

  Map<String, dynamic> toJson() {
    // Build the base properties map: widget-specific values only.
    // Common fields (rotation, label, labelHidden, haptic, variant) are promoted
    // to top-level keys and stripped from the properties sub-object.
    final baseProps = <String, dynamic>{
      ...properties,
    }
      ..remove('rotation')
      ..remove('label')
      ..remove('labelHidden')
      ..remove('haptic')
      ..remove('variant');

    // Add variant marker for special widget types
    if (type == DesignerElementType.gasPedal) baseProps['variant'] = 'gasPedal';
    if (type == DesignerElementType.steeringWheel)
      baseProps['variant'] = 'steeringWheel';
    if (type == DesignerElementType.multiSelect)
      baseProps['variant'] = 'multiSelect';
    if (type == DesignerElementType.multiButton)
      baseProps['variant'] = 'multiButton';
    if (type == DesignerElementType.rockerSwitch)
      baseProps['variant'] = 'rockerSwitch';

    final ar = aspectRatio;
    final result = <String, dynamic>{
      'type': jsonTypeStr,
      'x': x,
      'y': y,
      'rotation': rotation,
      'label': label,
      'labelHidden': labelHidden,
      'haptic': (properties['haptic'] as bool?) ?? true,
      'properties': baseProps,
    };

    if (ar == null || ar >= 0) {
      // Free-form or horizontal fixed-AR: height is the primary dimension.
      result['height'] = height;
    }
    if (ar == null || ar < 0) {
      // Free-form or vertical fixed-AR: width is the primary dimension.
      result['width'] = width;
    }
    // For horizontal fixed-AR (ar > 0): width is omitted (= height × ar).
    // For vertical   fixed-AR (ar < 0): height is omitted (= width × |ar|).
    // For square (ar == 1.0):           width is omitted (= height).

    return result;
  }

  factory DesignerElement.fromJson(Map<String, dynamic> json) {
    String typeStr = json['type'] as String;

    // Read properties — from nested 'properties' key (old format) or
    // from unknown top-level keys (new flattened format)
    Map<String, dynamic> props;
    if (json.containsKey('properties')) {
      props = Map<String, dynamic>.from(json['properties'] as Map? ?? {});
    } else {
      props = {};
      const knownKeys = {
        'type',
        'x',
        'y',
        'width',
        'height',
        'rotation',
        'label',
        'labelHidden',
        'variant',
        'haptic',
        'properties',
        'behavior',
      };
      for (final key in json.keys) {
        if (key == 'behavior' && json[key] is Map) {
          // Un-nest behavior values back into flat properties
          final behavior = json[key] as Map<String, dynamic>;
          props.addAll(Map<String, dynamic>.from(behavior));
        } else if (!knownKeys.contains(key)) {
          props[key] = json[key];
        }
      }
    }
    DesignerElementType parsedType;

    switch (typeStr) {
      case 'button':
        parsedType = DesignerElementType.button;
        break;
      case 'switch':
        parsedType = DesignerElementType.rockerSwitch;
        break;
      case 'slideSwitch':
        parsedType = DesignerElementType.slideSwitch;
        break;
      case 'slider':
        {
          // variant lives inside properties in the current format
          final v = (json['variant'] is String)
              ? json['variant'] as String
              : (props['variant'] is String
                  ? props['variant'] as String
                  : null);
          parsedType = (v == 'gasPedal')
              ? DesignerElementType.gasPedal
              : DesignerElementType.slider;
          break;
        }
      case 'knob':
        {
          // variant lives inside properties in the current format
          final v = (json['variant'] is String)
              ? json['variant'] as String
              : (props['variant'] is String
                  ? props['variant'] as String
                  : null);
          parsedType = (v == 'steeringWheel')
              ? DesignerElementType.steeringWheel
              : DesignerElementType.knob;
          break;
        }
      case 'joystick':
        parsedType = DesignerElementType.joystick;
        break;
      case 'multiple':
        {
          final v = (json['variant'] is String)
              ? json['variant'] as String
              : ((props['variant'] is String)
                  ? props['variant'] as String
                  : null);
          parsedType = (v == 'multiSelect')
              ? DesignerElementType.multiSelect
              : DesignerElementType.multiButton;
          break;
        }
      case 'led':
        parsedType = DesignerElementType.led;
        break;
      case 'text':
        parsedType = DesignerElementType.text;
        break;
      case 'display':
        parsedType = DesignerElementType.text;
        break;
      default:
        try {
          parsedType = DesignerElementType.values.byName(typeStr);
        } catch (_) {
          parsedType = DesignerElementType.button;
        }
    }

    // Backward compat: map old keys to new names
    if (props.containsKey('mode') && !props.containsKey('variant')) {
      props['variant'] = props.remove('mode');
    }
    if (props.containsKey('enableHapticFeedback') &&
        !props.containsKey('haptic')) {
      props['haptic'] = props.remove('enableHapticFeedback');
    }

    // Seed with all default property keys so missing values are filled in
    final seeded = _defaultProperties(parsedType);
    seeded.addAll(props);

    // Extract rotation/label/labelHidden/variant/haptic — promoted to top-level
    // in the new JSON format, with fallback to properties for backward compat.
    // Keep a copy back in `seeded` (properties) so template code and other
    // consumers can still access them via `element.properties[...]`.
    final rotationVal =
        (seeded.remove('rotation') as int?) ?? (json['rotation'] as int? ?? 0);
    final labelVal =
        (seeded.remove('label') as String?) ?? (json['label'] as String? ?? '');
    final labelHiddenVal = (seeded.remove('labelHidden') as bool?) ??
        (json['labelHidden'] as bool? ?? false);
    final String? variantVal =
        (seeded.remove('variant') as String?) ?? (json['variant'] as String?);
    if (variantVal != null) seeded['variant'] = variantVal;
    final bool hapticVal =
        (seeded.remove('haptic') as bool?) ?? (json['haptic'] as bool?) ?? true;
    seeded['haptic'] = hapticVal;

    // Resolve width and height, handling the orientation-aware format where
    // only one dimension is stored for multi-widgets.
    final rawWidth = json['width'] as int?;
    final rawHeight = json['height'] as int?;
    int effectiveWidth;
    int effectiveHeight;

    if (parsedType == DesignerElementType.multiButton ||
        parsedType == DesignerElementType.multiSelect) {
      final count = (seeded['itemCount'] as num?)?.toInt() ?? 3;
      final ratio = (count * 0.67).clamp(0.5, 10.0);
      if (rawWidth != null && rawHeight == null) {
        // Vertical format: only width saved — derive height.
        effectiveWidth = rawWidth;
        effectiveHeight = (rawWidth * ratio).round().clamp(1, 999);
      } else if (rawHeight != null && rawWidth == null) {
        // Horizontal format (current and legacy): only height saved — derive width.
        effectiveHeight = rawHeight;
        effectiveWidth = (rawHeight * ratio).round().clamp(1, 999);
      } else if (rawWidth != null && rawHeight != null) {
        // Both present (transitioned from free-form phase) — use as-is.
        effectiveWidth = rawWidth;
        effectiveHeight = rawHeight;
      } else {
        // Fallback: default horizontal proportions.
        effectiveHeight = 20;
        effectiveWidth = (20 * ratio).round().clamp(1, 999);
      }
    } else {
      // All other widgets: height is always present in JSON.
      effectiveHeight = rawHeight ?? 20;
      if (rawWidth != null) {
        effectiveWidth = rawWidth;
      } else {
        final ar = _aspectRatioFor(parsedType, seeded);
        if (ar != null) {
          effectiveWidth = (effectiveHeight * ar).round().clamp(1, 999);
        } else {
          effectiveWidth = effectiveHeight.clamp(1, 200);
        }
      }
    }

    return DesignerElement(
      id: labelVal,
      type: parsedType,
      x: json['x'] as int,
      y: json['y'] as int,
      width: effectiveWidth,
      height: effectiveHeight,
      properties: seeded,
      label: labelVal,
      labelHidden: labelHiddenVal,
      rotation: rotationVal,
    );
  }
}
