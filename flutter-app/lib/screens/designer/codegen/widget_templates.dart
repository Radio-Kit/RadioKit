import 'package:radiokit_widgets/radiokit_widgets.dart';

typedef WidgetTemplate = String Function(DesignerElement element, int pinIndex);

String _escape(String s) => s.replaceAll('"', '\\"');

String _comment(DesignerElement el) =>
    '  // ${el.type.name}: pos=(${el.x},${el.y}) size=${el.width}x${el.height}${el.label.isNotEmpty ? ' label="${el.label}"' : ''}';

final Map<DesignerElementType, WidgetTemplate> templates = {
  DesignerElementType.button: (el, pin) {
    final mode = el.properties['variant'] ?? 'push';
    final widgetType = mode == 'toggle' ? 'RK_ToggleButton' : 'RK_PushButton';
    final onText = el.properties['onText'] ?? 'ON';
    final offText = el.properties['offText'] ?? 'OFF';
    return '''
$widgetType ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}
  ${_widgetName(el)}.setOnText("${_escape(onText)}");
  ${_widgetName(el)}.setOffText("${_escape(offText)}");''';
  },

  DesignerElementType.slideSwitch: (el, pin) {
    final onText = el.properties['onText'] ?? 'ON';
    final offText = el.properties['offText'] ?? 'OFF';
    return '''
RK_SlideSwitch ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}
  ${_widgetName(el)}.setOnText("${_escape(onText)}");
  ${_widgetName(el)}.setOffText("${_escape(offText)}");''';
  },

  DesignerElementType.rockerSwitch: (el, pin) => '''
RK_RockerSwitch ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}''',

  DesignerElementType.slider: (el, pin) {
    final autoCenter = el.properties['autoCenter'] == true;
    final springBehavior = el.properties['springBehavior'] ?? 'smooth';
    return '''
RK_Slider ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}
  ${_widgetName(el)}.props.centering = ${_centeringEnum(autoCenter, springBehavior)};''';
  },

  DesignerElementType.knob: (el, pin) {
    final autoCenter = el.properties['autoCenter'] == true;
    final springBehavior = el.properties['springBehavior'] ?? 'smooth';
    final minAngle = el.properties['minAngle'] ?? -135;
    final maxAngle = el.properties['maxAngle'] ?? 135;
    return '''
RK_Knob ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}
  ${_widgetName(el)}.props.centering = ${_centeringEnum(autoCenter, springBehavior)};
  ${_widgetName(el)}.props.startAngle = $minAngle;
  ${_widgetName(el)}.props.endAngle = $maxAngle;''';
  },

  DesignerElementType.joystick: (el, pin) {
    final autoCenter = el.properties['autoCenter'] != false;
    final springBehavior = el.properties['springBehavior'] ?? 'smooth';
    return '''
RK_Joystick ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}
  ${_widgetName(el)}.props.centering = ${_centeringEnum(autoCenter, springBehavior)};''';
  },

  DesignerElementType.led: (el, pin) {
    final color = el.properties['color'] ?? 0x00FF00;
    return '''
RK_LED ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}
  ${_widgetName(el)}.setColor(0x${color.toInt().toRadixString(16).padLeft(6, '0')});''';
  },

  DesignerElementType.text: (el, pin) {
    final text = el.properties['text'] ?? 'Display';
    return '''
RK_Text ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}
  ${_widgetName(el)}.set("${_escape(text)}");''';
  },

  DesignerElementType.serialMonitor: (el, pin) => '''
RK_SerialMonitor ${_widgetName(el)} {
    .x = ${el.x}, .y = ${el.y},
    .width = ${el.width}, .height = ${el.height},
    .rotation = ${el.rotation}
};${_comment(el)}''',
};

String _widgetName(DesignerElement el) {
  final base = el.type.name;
  return '${base[0].toLowerCase()}${base.substring(1)}_${el.id.hashCode.abs() % 10000}';
}

String _centeringEnum(bool autoCenter, String springBehavior) {
  if (!autoCenter) return 'RK_SPRING_NONE';
  switch (springBehavior) {
    case 'elastic':
      return 'RK_SPRING_ELASTIC';
    case 'linear':
      return 'RK_SPRING_LINEAR';
    default:
      return 'RK_SPRING_CENTER';
  }
}
