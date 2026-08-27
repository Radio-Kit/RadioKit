import 'package:radiokit_widgets/radiokit_widgets.dart';

typedef WidgetTemplate = String Function(DesignerElement element, int pinIndex);

String _escape(String s) => s.replaceAll('"', '\\"');

String _comment(DesignerElement el) =>
    '  // ${el.type.name}: pos=(${el.x},${el.y}) size=${el.width}x${el.height}${el.label.isNotEmpty ? ' label="${el.label}"' : ''}';

/// Returns (cppWidth, cppHeight) — sets the derived dimension to 0 for fixed-AR
/// widgets so the C++ struct's defaultAspect() computes it.
(int, int) _cppSize(DesignerElement el) {
  final ar = el.aspectRatio;
  if (ar == null) return (el.width, el.height); // free-form
  if (ar >= 0) return (0, el.height);            // height is primary
  return (el.width, 0);                           // width is primary
}

/// Returns true when auto-center is enabled (position in array[0] is not null).
bool _acEnabled(List? ac) => ac != null && ac.isNotEmpty && ac[0] is String;

/// Returns the spring type string from array[1] (defaults to 'smooth').
String _acType(List? ac) {
  if (ac is List && ac.length >= 2 && ac[1] is String) return ac[1] as String;
  return 'smooth';
}

final Map<DesignerElementType, WidgetTemplate> templates = {
  DesignerElementType.button: (el, pin) {
    final mode = el.properties['variant'] ?? 'push';
    final widgetType = mode == 'toggle' ? 'RK_ToggleButton' : 'RK_PushButton';
    final onText = el.properties['onText'] ?? 'ON';
    final offText = el.properties['offText'] ?? 'OFF';
    final onIcon = el.properties['onIcon'] as String? ?? el.properties['icon'] as String?;
    final offIcon = el.properties['offIcon'] as String?;
    final (w, h) = _cppSize(el);
    final buf = StringBuffer();
    buf.writeln('$widgetType ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}');
    if (onText.toString().isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.onText = "${_escape(onText)}";');
    if (offText.toString().isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.offText = "${_escape(offText)}";');
    if (onIcon != null && onIcon.isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.icon = "$onIcon";');
    if (offIcon != null && offIcon.isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.offIcon = "$offIcon";');
    return buf.toString().trimRight();
  },

  DesignerElementType.slideSwitch: (el, pin) {
    final onText = el.properties['onText'] ?? 'ON';
    final offText = el.properties['offText'] ?? 'OFF';
    final onIcon = el.properties['onIcon'] as String? ?? el.properties['icon'] as String?;
    final offIcon = el.properties['offIcon'] as String?;
    final (w, h) = _cppSize(el);
    final buf = StringBuffer();
    buf.writeln('RK_SlideSwitch ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}');
    if (onText.toString().isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.onText = "${_escape(onText)}";');
    if (offText.toString().isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.offText = "${_escape(offText)}";');
    if (onIcon != null && onIcon.isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.icon = "$onIcon";');
    if (offIcon != null && offIcon.isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.offIcon = "$offIcon";');
    return buf.toString().trimRight();
  },

  DesignerElementType.rockerSwitch: (el, pin) {
    final (w, h) = _cppSize(el);
    final onIcon = el.properties['onIcon'] as String? ?? el.properties['icon'] as String?;
    final offIcon = el.properties['offIcon'] as String?;
    final buf = StringBuffer();
    buf.writeln('RK_RockerSwitch ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}');
    if (onIcon != null && onIcon.isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.icon = "$onIcon";');
    if (offIcon != null && offIcon.isNotEmpty) buf.writeln('  ${_widgetName(el)}.rk.offIcon = "$offIcon";');
    return buf.toString().trimRight();
  },

  DesignerElementType.slider: (el, pin) {
    final ac = el.properties['autoCenter'] as List?;
    final (w, h) = _cppSize(el);
    return '''
RK_Slider ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}
  ${_widgetName(el)}.rk.centering = ${_centeringFromAC(ac)};''';
  },

  DesignerElementType.gasPedal: (el, pin) {
    final ac = el.properties['autoCenter'] as List?;
    final (w, h) = _cppSize(el);
    final centering = _centeringFromAC(ac);
    return '''
RK_GasPedal ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}
  ${_widgetName(el)}.rk.centering = $centering;''';
  },

  DesignerElementType.knob: (el, pin) {
    final ac = el.properties['autoCenter'] as List?;
    final minAngle = el.properties['minAngle'] ?? -135;
    final maxAngle = el.properties['maxAngle'] ?? 135;
    final (w, h) = _cppSize(el);
    return '''
RK_Knob ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}
  ${_widgetName(el)}.rk.centering = ${_centeringFromAC(ac)};
  ${_widgetName(el)}.rk.startAngle = $minAngle;
  ${_widgetName(el)}.rk.endAngle = $maxAngle;''';
  },

  DesignerElementType.steeringWheel: (el, pin) {
    final ac = el.properties['autoCenter'] as List?;
    final minAngle = el.properties['minAngle'] ?? -135;
    final maxAngle = el.properties['maxAngle'] ?? 135;
    final (w, h) = _cppSize(el);
    return '''
RK_Knob ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}
  ${_widgetName(el)}.rk.variant = 1;     // steeringWheel
  ${_widgetName(el)}.rk.centering = ${_centeringFromAC(ac)};
  ${_widgetName(el)}.rk.startAngle = $minAngle;
  ${_widgetName(el)}.rk.endAngle = $maxAngle;''';
  },

  DesignerElementType.joystick: (el, pin) {
    final ac = el.properties['autoCenter'] as List?;
    final (w, h) = _cppSize(el);
    return '''
RK_Joystick ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}
  ${_widgetName(el)}.rk.centering = ${_centeringFromAC(ac)};''';
  },

  DesignerElementType.multiButton: (el, pin) {
    final items = _multiItems(el);
    return _buildMultiple('RK_MultipleButton', el, items);
  },

  DesignerElementType.multiSelect: (el, pin) {
    final items = _multiItems(el);
    return _buildMultiple('RK_MultipleSelect', el, items);
  },

  DesignerElementType.led: (el, pin) {
    final color = el.properties['color'] ?? 0x00FF00;
    final (w, h) = _cppSize(el);
    return '''
RK_LED ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}
  ${_widgetName(el)}.rk.color = 0x${color.toInt().toRadixString(16).padLeft(6, '0')};''';
  },

  DesignerElementType.text: (el, pin) {
    final text = el.properties['text'] ?? 'Display';
    final (w, h) = _cppSize(el);
    return '''
RK_Text ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w);${_comment(el)}
  ${_widgetName(el)}.rk.content = "${_escape(text)}";''';
  },

  DesignerElementType.serialMonitor: (el, pin) {
    final (w, h) = _cppSize(el);
    return '''
RK_SerialMonitor ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w);${_comment(el)}''';
  },
};

String _widgetName(DesignerElement el) {
  final base = el.type.name;
  return '${base[0].toLowerCase()}${base.substring(1)}_${el.id.hashCode.abs() % 10000}';
}

/// Converts the autoCenter array [position, type, duration] to an RK centering enum.
///
///   - position == null → RK_SPRING_NONE
///   - type == 'elastic' → RK_SPRING_ELASTIC
///   - type == 'linear' → RK_SPRING_LINEAR
///   - otherwise → RK_SPRING_CENTER (smooth)
String _centeringFromAC(List? ac) {
  if (!_acEnabled(ac)) return 'RK_SPRING_NONE';
  switch (_acType(ac)) {
    case 'elastic':
      return 'RK_SPRING_ELASTIC';
    case 'linear':
      return 'RK_SPRING_LINEAR';
    default:
      return 'RK_SPRING_CENTER';
  }
}

/// Extracts multi-item config from element properties.
List<Map<String, dynamic>> _multiItems(DesignerElement el) {
  final raw = el.properties['items'] as List?;
  if (raw == null) return [];
  return raw.map((e) => Map<String, dynamic>.from(e is Map ? e : {})).toList();
}

/// Builds an RK_MultipleButton or RK_MultipleSelect declaration with items.
String _buildMultiple(String widgetType, DesignerElement el, List<Map<String, dynamic>> items) {
  final buf = StringBuffer();
  final (w, h) = _cppSize(el);
  buf.writeln('$widgetType ${_widgetName(el)}(${el.x}, ${el.y}, $h, $w, ${el.rotation});${_comment(el)}');

  for (int i = 0; i < items.length; i++) {
    final item = items[i];
    final rawLabel = item['onLabel'] as String? ?? item['label'] as String? ?? item['text'] as String?;
    final icon = item['onIcon'] as String? ?? item['icon'] as String?;
    final hasIcon = icon != null && icon.isNotEmpty;
    final label = rawLabel ?? (hasIcon ? '' : String.fromCharCode(65 + i));
    if (hasIcon) {
      buf.writeln('  ${_widgetName(el)}.rk.items[$i] = {"${_escapeC(label)}", "$icon", 255};');
    } else {
      buf.writeln('  ${_widgetName(el)}.rk.items[$i] = {"${_escapeC(label)}", nullptr, 255};');
    }
  }

  return buf.toString();
}
