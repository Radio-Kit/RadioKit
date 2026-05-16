enum DesignerElementType {
  button,
  slideSwitch,
  rockerSwitch,
  slider,
  knob,
  joystick,
  multiButton,
  multiSelect,
  gasPedal,
  led,
  display,
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
          'min': 0.0,
          'max': 100.0,
          'autoCenter': false,
          'center': 0.5,
          'springBehavior': 'smooth',
          'springDuration': 300.0,
          'divisions': null,
        };
      case DesignerElementType.knob:
        return {
          'min': 0.0,
          'max': 100.0,
          'minAngle': -135.0,
          'maxAngle': 135.0,
          'autoCenter': false,
          'center': 0.5,
          'springBehavior': 'smooth',
          'springDuration': 500.0,
          'divisions': null,
          'variant': 'standard',
        };
      case DesignerElementType.joystick:
        return {
          'autoCenter': true,
          'centerX': 0.0,
          'centerY': 0.0,
          'springBehavior': 'smooth',
          'springDuration': 300.0,
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
          'min': 0.0,
          'max': 100.0,
          'autoCenter': false,
          'center': 0.0,
          'springBehavior': 'smooth',
          'springDuration': 300.0,
        };
      case DesignerElementType.led:
        return {
          'state': 'off',
          'shape': 'circle',
          'color': 0x00FF00,
          'timing': 500,
        };
      case DesignerElementType.display:
        return {
          'text': 'Display',
          'fontSize': 14.0,
          'fontFamily': 'monospace',
        };
      case DesignerElementType.serialMonitor:
        return {
          'fontSize': 12.0,
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
      case DesignerElementType.display:
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

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'x': x,
        'y': y,
        'width': width,
        'height': height,
        'properties': properties,
        'label': label,
        'rotation': rotation,
      };

  factory DesignerElement.fromJson(Map<String, dynamic> json) {
    return DesignerElement(
      id: json['id'] as String,
      type: DesignerElementType.values.byName(json['type'] as String),
      x: json['x'] as int,
      y: json['y'] as int,
      width: json['width'] as int,
      height: json['height'] as int,
      properties: Map<String, dynamic>.from(json['properties'] as Map),
      label: json['label'] as String? ?? '',
      rotation: json['rotation'] as int? ?? 0,
    );
  }
}
