/// Generates the complete `RadioKit_UI.h` content (minus the JSON config block)
/// from the designer's JSON configuration map.
///
/// Reads the same JSON schema that is embedded in the header comment block,
/// so the C++ code and the JSON config are always in sync.
class JsonArduinoGenerator {
  static String generate(Map<String, dynamic> json) {
    final buf = StringBuffer();
    final config = json['config'] as Map<String, dynamic>? ?? {};
    final widgets = json['widgets'] as List? ?? [];

    buf.writeln('//__RadioKit_Generated_Code__');
    buf.writeln('//__Might_Be_Overwritten_');
    buf.writeln();
    buf.writeln('#ifndef RADIOKIT_UI_H');
    buf.writeln('#define RADIOKIT_UI_H');
    buf.writeln();
    buf.writeln('#include <RadioKit.h>');
    buf.writeln();

    // ─── Widget Declarations ───
    if (widgets.isNotEmpty) {
      buf.writeln('// ─── Widget Declarations ───');
      for (final w in widgets) {
        if (w is! Map<String, dynamic>) continue;
        buf.writeln(_generateWidget(w));
        buf.writeln();
      }
    }

    // ─── Config Init ───
    buf.writeln('// ─── Config Init ───');
    buf.writeln('static inline void initRadioKit() {');
    _writeConfigInit(buf, '  ', config);
    buf.writeln();
    buf.writeln('  RadioKit.begin();');
    final transport = (config['transport'] as String? ?? 'BLE').toLowerCase();
    if (transport == 'ble') {
      buf.writeln('  RadioKit.startBLE(RadioKit.config.name);');
    }
    buf.writeln('}');
    buf.writeln();
    buf.writeln('#endif // RADIOKIT_UI_H');
    buf.writeln();

    return buf.toString();
  }

  // ── Config init ─────────────────────────────────────────────────────────

  static void _writeConfigInit(
      StringBuffer buf, String indent, Map<String, dynamic> config) {
    final name = config['name'] as String? ?? '';
    final description = config['description'] as String? ?? '';
    final type = config['type'] as String? ?? '';
    final theme = config['theme'] as String? ?? 'RK_DEFAULT';
    final password = config['password'] as String? ?? '';
    final transport = (config['transport'] as String? ?? 'BLE').toLowerCase();

    if (name.isNotEmpty) {
      buf.writeln('${indent}RadioKit.config.name        = "${_escapeC(name)}";');
    }
    if (description.isNotEmpty) {
      buf.writeln('${indent}RadioKit.config.description = "${_escapeC(description)}";');
    }
    if (type.isNotEmpty) {
      buf.writeln('${indent}RadioKit.config.type        = "${_escapeC(type)}";');
    }
    // theme
    buf.writeln('${indent}RadioKit.config.theme       = $theme;');
    if (password.isNotEmpty) {
      buf.writeln('${indent}RadioKit.config.password    = "${_escapeC(password)}";');
    }
    if (transport != 'ble') {
      buf.writeln('${indent}RadioKit.config.transport   = SerialTransport;');
    }
  }

  // ── Widget generator ─────────────────────────────────────────────────────

  static String _generateWidget(Map<String, dynamic> w) {
    final type = w['type'] as String;
    final name = _sanitizeName(w['name'] as String? ?? '');
    final position = w['position'] as List? ?? [10, 10, 0];
    final size = w['size'] as List? ?? [20, 20];
    final props = w['properties'] as Map<String, dynamic>? ?? {};
    final variant = w['variant'] as String?;
    final x = (position.length >= 1 && position[0] is num)
        ? (position[0] as num).toInt()
        : 10;
    final y = (position.length >= 2 && position[1] is num)
        ? (position[1] as num).toInt()
        : 10;
    final rotation = (position.length >= 3 && position[2] is num)
        ? (position[2] as num).toInt()
        : 0;

    // size: [w, h] — null means auto-derive from aspect ratio
    final int cppW;
    final int cppH;
    if (size.length >= 2) {
      cppW = (size[0] is num) ? (size[0] as num).toInt() : 0;
      cppH = (size[1] is num) ? (size[1] as num).toInt() : 0;
    } else {
      cppW = 0;
      cppH = 0;
    }

    final ac = props['autoCenter'];
    final acList = (ac is List) ? ac : null;

    final comment = _comment(w, type);

    switch (type) {
      case 'button': {
        final mode = props['variant'] ?? 'push';
        final widgetType =
            mode == 'toggle' ? 'RK_ToggleButton' : 'RK_PushButton';
        final onText = props['onText'] ?? 'ON';
        final offText = props['offText'] ?? 'OFF';
        final buf = StringBuffer();
        buf.writeln('$widgetType $name {');
        buf.writeln('    .x = $x, .y = $y,');
        buf.writeln('    .width = $cppW, .height = $cppH,');
        buf.writeln('    .rotation = $rotation');
        buf.writeln('};$comment');
        buf.writeln('  $name.setOnText("${_escapeC(onText)}");');
        buf.writeln('  $name.setOffText("${_escapeC(offText)}");');
        return buf.toString();
      }

      case 'slideSwitch': {
        final onText = props['onText'] ?? 'ON';
        final offText = props['offText'] ?? 'OFF';
        return '''
RK_SlideSwitch $name {
    .x = $x, .y = $y,
    .width = $cppW, .height = $cppH,
    .rotation = $rotation
};$comment
  $name.setOnText("${_escapeC(onText)}");
  $name.setOffText("${_escapeC(offText)}");''';
      }

      case 'switch': {
        return '''
RK_RockerSwitch $name {
    .x = $x, .y = $y,
    .width = $cppW, .height = $cppH,
    .rotation = $rotation
};$comment''';
      }

      case 'slider': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'gasPedal') {
          return _gasPedal(name, x, y, cppW, cppH, rotation, acList, comment);
        }
        return _slider(name, x, y, cppW, cppH, rotation, acList, comment);
      }

      case 'knob': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'steeringWheel') {
          return _steeringWheel(
              name, x, y, cppW, cppH, rotation, props, acList, comment);
        }
        return _knob(name, x, y, cppW, cppH, rotation, props, acList, comment);
      }

      case 'joystick': {
        final buf = StringBuffer();
        buf.writeln('RK_Joystick $name {');
        buf.writeln('    .x = $x, .y = $y,');
        buf.writeln('    .width = $cppW, .height = $cppH,');
        buf.writeln('    .rotation = $rotation');
        buf.writeln('};$comment');
        buf.writeln('  $name.props.centering = ${_centeringEnum(acList)};');
        return buf.toString();
      }

      case 'multiple': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'multiSelect') {
          return _buildMultiple('RK_MultipleSelect', name, x, y, cppW, cppH,
              rotation, props, comment);
        }
        return _buildMultiple('RK_MultipleButton', name, x, y, cppW, cppH,
            rotation, props, comment);
      }

      case 'led': {
        final color = props['color'];
        final colorVal = (color is num) ? color.toInt() : 0x00FF00;
        final colorHex =
            colorVal.toRadixString(16).padLeft(6, '0');
        return '''
RK_LED $name {
    .x = $x, .y = $y,
    .width = $cppW, .height = $cppH,
    .rotation = $rotation
};$comment
  $name.setColor(0x$colorHex);''';
      }

      case 'text': {
        final text = props['text'] as String? ?? 'Display';
        return '''
RK_Text $name {
    .x = $x, .y = $y,
    .width = $cppW, .height = $cppH,
    .rotation = $rotation
};$comment
  $name.set("${_escapeC(text)}");''';
      }

      case 'serialMonitor': {
        return '''
RK_SerialMonitor $name {
    .x = $x, .y = $y,
    .width = $cppW, .height = $cppH,
    .rotation = $rotation
};$comment''';
      }

      default:
        return '  // Unsupported widget type: $type';
    }
  }

  // ── Sub-generators for widget variants ────────────────────────────────────

  static String _slider(String name, int x, int y, int w, int h, int rot,
      List? ac, String comment) {
    return '''
RK_Slider $name {
    .x = $x, .y = $y,
    .width = $w, .height = $h,
    .rotation = $rot
};$comment
  $name.props.centering = ${_centeringEnum(ac)};''';
  }

  static String _gasPedal(String name, int x, int y, int w, int h, int rot,
      List? ac, String comment) {
    return '''
RK_GasPedal $name {
    .x = $x, .y = $y,
    .width = $w, .height = $h,
    .rotation = $rot
};$comment
  $name.props.centering = ${_centeringEnum(ac)};''';
  }

  static String _knob(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment) {
    final minAngle = props['minAngle'] ?? -135;
    final maxAngle = props['maxAngle'] ?? 135;
    return '''
RK_Knob $name {
    .x = $x, .y = $y,
    .width = $w, .height = $h,
    .rotation = $rot
};$comment
  $name.props.centering = ${_centeringEnum(ac)};
  $name.props.startAngle = $minAngle;
  $name.props.endAngle = $maxAngle;''';
  }

  static String _steeringWheel(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment) {
    final minAngle = props['minAngle'] ?? -135;
    final maxAngle = props['maxAngle'] ?? 135;
    return '''
RK_Knob $name {
    .x = $x, .y = $y,
    .width = $w, .height = $h,
    .rotation = $rot
};$comment
  $name.props.variant = 1;     // steeringWheel
  $name.props.centering = ${_centeringEnum(ac)};
  $name.props.startAngle = $minAngle;
  $name.props.endAngle = $maxAngle;''';
  }

  static String _buildMultiple(String widgetType, String name, int x, int y,
      int w, int h, int rot, Map<String, dynamic> props, String comment) {
    final items = props['items'] as List? ?? [];
    final buf = StringBuffer();
    buf.writeln('$widgetType $name {');
    buf.writeln('    .x = $x, .y = $y,');
    buf.writeln('    .width = $w, .height = $h,');
    buf.writeln('    .rotation = $rot');
    buf.writeln('};$comment');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) continue;
      final label = item['onLabel'] as String? ?? String.fromCharCode(65 + i);
      final icon = item['onIcon'] as String?;
      if (icon != null && icon.isNotEmpty) {
        buf.writeln('  $name.add({"$label", "$icon"});');
      } else {
        buf.writeln('  $name.add({"$label"});');
      }
    }

    return buf.toString();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Sanitizes a string for use as a C++ identifier.
  static String _sanitizeName(String name) {
    return name.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
  }

  static String _comment(Map<String, dynamic> w, String typeName) {
    final name = w['name'] as String? ?? '';
    final pos = w['position'] as List? ?? [];
    final size = w['size'] as List? ?? [];
    final x = pos.isNotEmpty ? (pos[0] is num ? pos[0] : '?') : '?';
    final y = pos.length >= 2 ? (pos[1] is num ? pos[1] : '?') : '?';
    final sw = size.isNotEmpty ? (size[0] is num ? size[0] : '?') : '?';
    final sh = size.length >= 2 ? (size[1] is num ? size[1] : '?') : '?';
    final labelPart =
        name.isNotEmpty ? ' label="$name"' : '';
    return '  // $typeName: pos=($x,$y) size=${sw}x$sh$labelPart';
  }

  static String _escapeC(String s) =>
      s.replaceAll('"', '\\"').replaceAll('\n', '\\n');

  /// Converts the autoCenter array [position, type, duration] to an RK centering enum.
  ///
  ///   - position == null → RK_SPRING_NONE
  ///   - type == 'elastic' → RK_SPRING_ELASTIC
  ///   - type == 'linear' → RK_SPRING_LINEAR
  ///   - otherwise → RK_SPRING_CENTER (smooth)
  static String _centeringEnum(List? ac) {
    if (ac == null || ac.isEmpty) return 'RK_SPRING_NONE';
    final pos = ac[0];
    if (pos is! String) return 'RK_SPRING_NONE';
    final type = (ac.length >= 2 && ac[1] is String)
        ? ac[1] as String
        : 'smooth';
    switch (type) {
      case 'elastic':
        return 'RK_SPRING_ELASTIC';
      case 'linear':
        return 'RK_SPRING_LINEAR';
      default:
        return 'RK_SPRING_CENTER';
    }
  }
}
