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
  int rotation;

  /// Whether this widget type renders at a fixed 1:1 aspect ratio.
  /// These widgets use `size = min(width, height)`, so the debug overlay
  /// is always square and resize must maintain equal width/height.
  bool get hasFixedAspectRatio {
    switch (type) {
      case DesignerElementType.button:
      case DesignerElementType.knob:
      case DesignerElementType.steeringWheel:
      case DesignerElementType.joystick:
      case DesignerElementType.led:
        return true;
      default:
        return false;
    }
  }

  /// The effective rendered size in grid units.
  /// For fixed-aspect-ratio widgets this is `min(width, height)` × `min(width, height)`;
  /// for free-aspect widgets it is `width` × `height`.
  (int, int) get renderedGridSize {
    if (hasFixedAspectRatio) {
      final s = width < height ? width : height;
      return (s, s);
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
    this.rotation = 0,
  }) : properties = properties ?? _defaultProperties(type);

  static Map<String, dynamic> _defaultProperties(DesignerElementType type) {
    switch (type) {
      case DesignerElementType.button:
        return {
          'mode': 'push',
          'onText': 'ON',
          'offText': 'OFF',
          'enableHapticFeedback': true,
        };
      case DesignerElementType.slideSwitch:
        return {
          'onText': 'ON',
          'offText': 'OFF',
          'enableHapticFeedback': true,
        };
      case DesignerElementType.rockerSwitch:
        return {
          'enableHapticFeedback': true,
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
          'enableHapticFeedback': true,
          'itemCount': 3,
        };
      case DesignerElementType.multiSelect:
        return {
          'enableHapticFeedback': true,
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
    final props = Map<String, dynamic>.from(properties);
    if (type == DesignerElementType.gasPedal) props['variant'] = 'gasPedal';
    if (type == DesignerElementType.steeringWheel) props['variant'] = 'steeringWheel';
    if (type == DesignerElementType.multiSelect) props['variant'] = 'multiSelect';
    if (type == DesignerElementType.multiButton) props['variant'] = 'multiButton';
    if (type == DesignerElementType.rockerSwitch) props['variant'] = 'rockerSwitch';

    return {
      'id': id,
      'type': jsonTypeStr,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'properties': props,
      'label': label,
      'rotation': rotation,
    };
  }

  factory DesignerElement.fromJson(Map<String, dynamic> json) {
    String typeStr = json['type'] as String;
    Map<String, dynamic> props = Map<String, dynamic>.from(json['properties'] as Map? ?? {});
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

    return DesignerElement(
      id: json['id'] as String,
      type: parsedType,
      x: json['x'] as int,
      y: json['y'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      properties: props,
      label: json['label'] as String? ?? '',
      rotation: json['rotation'] as int? ?? 0,
    );
  }
}
