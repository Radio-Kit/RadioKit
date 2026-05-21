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
        return (count * 0.67).clamp(0.5, 10.0);
      default:
        return null;
    }
  }

  /// The effective rendered size in grid units.
  /// For fixed-aspect-ratio widgets the width is derived from the height
  /// and the [aspectRatio]; for free-aspect widgets it is `width` × `height`.
  (int, int) get renderedGridSize {
    final ar = aspectRatio;
    if (ar != null) {
      return ((height * ar).round().clamp(1, 999), height);
    }
    return (width, height);
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
          'variant': 'push',
          'onText': 'ON',
          'offText': 'OFF',
          'onIcon': null,
          'offIcon': null,
          'haptic': true,
        };
      case DesignerElementType.slideSwitch:
        return {
          'onText': 'ON',
          'offText': 'OFF',
          'haptic': true,
        };
      case DesignerElementType.rockerSwitch:
        return {
          'onIcon': null,
          'offIcon': null,
          'haptic': true,
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
      case DesignerElementType.multiButton:
        return {
          'haptic': true,
          'itemCount': 3,
        };
      case DesignerElementType.multiSelect:
        return {
          'haptic': true,
          'itemCount': 3,
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
      case DesignerElementType.button: return 'button';
      case DesignerElementType.slideSwitch: return 'slideSwitch';
      case DesignerElementType.rockerSwitch: return 'switch';
      case DesignerElementType.slider: return 'slider';
      case DesignerElementType.gasPedal: return 'slider';
      case DesignerElementType.knob: return 'knob';
      case DesignerElementType.steeringWheel: return 'knob';
      case DesignerElementType.joystick: return 'joystick';
      case DesignerElementType.multiButton: return 'multiple';
      case DesignerElementType.multiSelect: return 'multiple';
      case DesignerElementType.led: return 'led';
      case DesignerElementType.text: return 'text';
      case DesignerElementType.serialMonitor: return 'serialMonitor';
    }
  }

  Map<String, dynamic> toJson() {
    final result = <String, dynamic>{
      'id': id,
      'type': jsonTypeStr,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'rotation': rotation,
      'label': label,
      'labelHidden': labelHidden,
    };

    // Behavior-related values are nested under a 'behavior' key
    const behaviorKeys = {
      'autoCenter', 'center', 'centerX', 'centerY',
      'springBehavior', 'springDuration',
    };
    final behavior = <String, dynamic>{};

    // Split properties: behavior keys go into nested map, rest stay flat
    for (final entry in properties.entries) {
      if (behaviorKeys.contains(entry.key)) {
        behavior[entry.key] = entry.value;
      } else {
        result[entry.key] = entry.value;
      }
    }

    if (behavior.isNotEmpty) {
      result['behavior'] = behavior;
    }

    // Add variant markers for special widget types
    if (type == DesignerElementType.gasPedal) result['variant'] = 'gasPedal';
    if (type == DesignerElementType.steeringWheel) result['variant'] = 'steeringWheel';
    if (type == DesignerElementType.multiSelect) result['variant'] = 'multiSelect';
    if (type == DesignerElementType.multiButton) result['variant'] = 'multiButton';
    if (type == DesignerElementType.rockerSwitch) result['variant'] = 'rockerSwitch';

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
        'id', 'type', 'x', 'y', 'width', 'height',
        'rotation', 'label', 'labelHidden', 'properties', 'behavior',
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
      case 'button': parsedType = DesignerElementType.button; break;
      case 'switch': parsedType = DesignerElementType.rockerSwitch; break;
      case 'slideSwitch': parsedType = DesignerElementType.slideSwitch; break;
      case 'slider':
        parsedType = (props['variant'] == 'gasPedal') ? DesignerElementType.gasPedal : DesignerElementType.slider;
        break;
      case 'knob':
        parsedType = (props['variant'] == 'steeringWheel') ? DesignerElementType.steeringWheel : DesignerElementType.knob;
        break;
      case 'joystick': parsedType = DesignerElementType.joystick; break;
      case 'multiple':
        parsedType = (props['variant'] == 'multiSelect') ? DesignerElementType.multiSelect : DesignerElementType.multiButton;
        break;
      case 'led': parsedType = DesignerElementType.led; break;
      case 'text': parsedType = DesignerElementType.text; break;
      case 'display': parsedType = DesignerElementType.text; break;
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
    if (props.containsKey('enableHapticFeedback') && !props.containsKey('haptic')) {
      props['haptic'] = props.remove('enableHapticFeedback');
    }

    // Seed with all default property keys so missing values are filled in
    final seeded = _defaultProperties(parsedType);
    seeded.addAll(props);

    return DesignerElement(
      id: json['id'] as String,
      type: parsedType,
      x: json['x'] as int,
      y: json['y'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      properties: seeded,
      label: json['label'] as String? ?? '',
      labelHidden: json['labelHidden'] as bool? ?? false,
      rotation: json['rotation'] as int? ?? 0,
    );
  }
}
