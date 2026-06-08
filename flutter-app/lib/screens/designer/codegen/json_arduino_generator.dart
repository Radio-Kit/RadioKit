/// Generates the complete `RADIOKIT.h` content (minus the JSON config block)
/// from the designer's JSON configuration map.
///
/// Reads the same JSON schema that is embedded in the header comment block,
/// so the C++ code and the JSON config are always in sync.
class JsonArduinoGenerator {
  static String generate(Map<String, dynamic> json) {
    final buf = StringBuffer();
    final config = json['config'] as Map<String, dynamic>? ?? {};
    final widgets = json['widgets'] as List? ?? [];
    final features = json['features'] as Map<String, dynamic>? ?? {};
    final enableOta = (features['ota'] as bool?) ?? false;
    final enableFs = (features['filesystem'] as bool?) ?? false;

    buf.writeln('//__RadioKit_Generated_Code__');
    buf.writeln('//__Might_Be_Overwritten_');
    buf.writeln();
    buf.writeln('#ifndef RADIOKIT_H');
    buf.writeln('#define RADIOKIT_H');
    buf.writeln();
    buf.writeln('#include <RadioKitLib.h>');
    buf.writeln();

    // ─── Feature includes ───
    if (enableOta) {
      buf.writeln('#if defined(ESP32)');
      buf.writeln('#define RADIOKIT_FEATURE_OTA');
      buf.writeln('#include "connection/RadioKitOTA.h"');
      buf.writeln('#endif');
      buf.writeln();
    }
    if (enableFs) {
      buf.writeln('#if __has_include(<LittleFS.h>)');
      buf.writeln('#define RADIOKIT_FEATURE_FS');
      buf.writeln('#include <LittleFS.h>');
      buf.writeln('#endif');
      buf.writeln();
    }

    final setupBuf = StringBuffer();

    // ─── Widget Declarations ───
    if (widgets.isNotEmpty) {
      buf.writeln('// ─── Widget Declarations ───');
      for (final w in widgets) {
        if (w is! Map<String, dynamic>) continue;
        _generateWidget(w, buf, setupBuf);
        buf.writeln();
      }
    }

    // ─── Config Init ───
    buf.writeln('// ─── Config Init ───');
    buf.writeln('static inline void initRadioKit() {');
    _writeConfigInit(buf, '  ', config);
    buf.writeln();

    if (setupBuf.isNotEmpty) {
      buf.write(setupBuf.toString());
      buf.writeln();
    }

    buf.writeln('  RadioKit.begin();');
    final transport = (config['transport'] as String? ?? 'BLE').toLowerCase();
    if (transport == 'ble') {
      buf.writeln('  RadioKit.startBLE(RadioKit.config.name);');
    } else {
      buf.writeln('  RadioKit.startSerial(Serial);');
    }

    // ─── Feature initialization ───
    // OTA/FS callback registration is handled internally by RadioKit::startBLE()
    // / startSerial() when the feature #define flags are set.
    if (enableFs) {
      buf.writeln('');
      buf.writeln('  #if __has_include(<LittleFS.h>)');
      buf.writeln('  RKFs::begin();');
      buf.writeln('  #endif');
    }

    buf.writeln('}');
    buf.writeln();
    buf.writeln('#endif // RADIOKIT_H');
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
    final baudrate = config['baudrate'] as int? ?? 1000000;

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
    buf.writeln('${indent}RadioKit.config.baudrate    = $baudrate;');
  }

  // ── Widget generator ─────────────────────────────────────────────────────

  static void _generateWidget(
      Map<String, dynamic> w, StringBuffer declBuf, StringBuffer setupBuf) {
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
        
        declBuf.writeln('$widgetType $name({');
        declBuf.writeln('    .x = $x, .y = $y,');
        declBuf.writeln('    .height = $cppH, .width = $cppW,');
        declBuf.writeln('    .rotation = $rotation');
        declBuf.writeln('});$comment');
        
        setupBuf.writeln('  $name.setOnText("${_escapeC(onText)}");');
        setupBuf.writeln('  $name.setOffText("${_escapeC(offText)}");');
        break;
      }

      case 'slideSwitch': {
        final onText = props['onText'] ?? 'ON';
        final offText = props['offText'] ?? 'OFF';
        
        declBuf.writeln('RK_SlideSwitch $name({');
        declBuf.writeln('    .x = $x, .y = $y,');
        declBuf.writeln('    .height = $cppH, .width = $cppW,');
        declBuf.writeln('    .rotation = $rotation');
        declBuf.writeln('});$comment');
        
        setupBuf.writeln('  $name.setOnText("${_escapeC(onText)}");');
        setupBuf.writeln('  $name.setOffText("${_escapeC(offText)}");');
        break;
      }

      case 'switch': {
        declBuf.writeln('RK_RockerSwitch $name({');
        declBuf.writeln('    .x = $x, .y = $y,');
        declBuf.writeln('    .height = $cppH, .width = $cppW,');
        declBuf.writeln('    .rotation = $rotation');
        declBuf.writeln('});$comment');
        break;
      }

      case 'slider': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'gasPedal') {
          _gasPedal(name, x, y, cppW, cppH, rotation, acList, comment, declBuf, setupBuf);
        } else {
          _slider(name, x, y, cppW, cppH, rotation, acList, comment, declBuf, setupBuf);
        }
        break;
      }

      case 'knob': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'steeringWheel') {
          _steeringWheel(
              name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf);
        } else {
          _knob(name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf);
        }
        break;
      }

      case 'joystick': {
        declBuf.writeln('RK_Joystick $name({');
        declBuf.writeln('    .x = $x, .y = $y,');
        declBuf.writeln('    .height = $cppH, .width = $cppW,');
        declBuf.writeln('    .rotation = $rotation');
        declBuf.writeln('});$comment');
        
        setupBuf.writeln('  $name.props.centering = ${_centeringEnum(acList)};');
        break;
      }

      case 'multiple': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'multiSelect') {
          _buildMultiple('RK_MultipleSelect', name, x, y, cppW, cppH,
              rotation, props, comment, declBuf, setupBuf);
        } else {
          _buildMultiple('RK_MultipleButton', name, x, y, cppW, cppH,
              rotation, props, comment, declBuf, setupBuf);
        }
        break;
      }

      case 'led': {
        final color = props['color'];
        final colorVal = (color is num) ? color.toInt() : 0x00FF00;
        final colorHex =
            colorVal.toRadixString(16).padLeft(6, '0');
            
        declBuf.writeln('RK_LED $name({');
        declBuf.writeln('    .x = $x, .y = $y,');
        declBuf.writeln('    .height = $cppH, .width = $cppW,');
        declBuf.writeln('    .rotation = $rotation');
        declBuf.writeln('});$comment');
        
        setupBuf.writeln('  $name.setColor(0x$colorHex);');
        break;
      }

      case 'text': {
        final text = props['text'] as String? ?? 'Display';
        
        declBuf.writeln('RK_Text $name({');
        declBuf.writeln('    .x = $x, .y = $y,');
        declBuf.writeln('    .height = $cppH, .width = $cppW');
        declBuf.writeln('});$comment');
        
        setupBuf.writeln('  $name.set("${_escapeC(text)}");');
        break;
      }

      case 'serialMonitor': {
        declBuf.writeln('RK_SerialMonitor $name({');
        declBuf.writeln('    .x = $x, .y = $y,');
        declBuf.writeln('    .height = $cppH, .width = $cppW');
        declBuf.writeln('});$comment');
        break;
      }

      default:
        declBuf.writeln('  // Unsupported widget type: $type');
        break;
    }

    // ── Label visibility ──────────────────────────────────────────────
    final labelObj = w['label'] as Map<String, dynamic>?;
    final show = labelObj?['show'] as bool? ?? true;
    if (!show) {
      setupBuf.writeln('  $name.setLabelHidden(true);');
    }
  }

  // ── Sub-generators for widget variants ────────────────────────────────────

  static void _slider(String name, int x, int y, int w, int h, int rot,
      List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf) {
    declBuf.writeln('RK_Slider $name({');
    declBuf.writeln('    .x = $x, .y = $y,');
    declBuf.writeln('    .height = $h, .width = $w,');
    declBuf.writeln('    .rotation = $rot');
    declBuf.writeln('});$comment');
    
    setupBuf.writeln('  $name.props.centering = ${_centeringEnum(ac)};');
  }

  static void _gasPedal(String name, int x, int y, int w, int h, int rot,
      List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf) {
    declBuf.writeln('RK_GasPedal $name({');
    declBuf.writeln('    .x = $x, .y = $y,');
    declBuf.writeln('    .height = $h, .width = $w,');
    declBuf.writeln('    .rotation = $rot');
    declBuf.writeln('});$comment');
    
    setupBuf.writeln('  $name.props.centering = ${_centeringEnum(ac)};');
  }

  static void _knob(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf) {
    final minAngle = props['minAngle'] ?? -135;
    final maxAngle = props['maxAngle'] ?? 135;
    
    declBuf.writeln('RK_Knob $name({');
    declBuf.writeln('    .x = $x, .y = $y,');
    declBuf.writeln('    .height = $h, .width = $w,');
    declBuf.writeln('    .rotation = $rot');
    declBuf.writeln('});$comment');
    
    setupBuf.writeln('  $name.props.centering = ${_centeringEnum(ac)};');
    setupBuf.writeln('  $name.props.startAngle = $minAngle;');
    setupBuf.writeln('  $name.props.endAngle = $maxAngle;');
  }

  static void _steeringWheel(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf) {
    final minAngle = props['minAngle'] ?? -135;
    final maxAngle = props['maxAngle'] ?? 135;
    
    declBuf.writeln('RK_Knob $name({');
    declBuf.writeln('    .x = $x, .y = $y,');
    declBuf.writeln('    .height = $h, .width = $w,');
    declBuf.writeln('    .rotation = $rot');
    declBuf.writeln('});$comment');
    
    setupBuf.writeln('  $name.props.variant = 1;     // steeringWheel');
    setupBuf.writeln('  $name.props.centering = ${_centeringEnum(ac)};');
    setupBuf.writeln('  $name.props.startAngle = $minAngle;');
    setupBuf.writeln('  $name.props.endAngle = $maxAngle;');
  }

  static void _buildMultiple(String widgetType, String name, int x, int y,
      int w, int h, int rot, Map<String, dynamic> props, String comment, StringBuffer declBuf, StringBuffer setupBuf) {
    final items = props['items'] as List? ?? [];
    
    declBuf.writeln('$widgetType $name({');
    declBuf.writeln('    .x = $x, .y = $y,');
    declBuf.writeln('    .height = $h, .width = $w,');
    declBuf.writeln('    .rotation = $rot');
    declBuf.writeln('});$comment');

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) continue;
      final label = item['onLabel'] as String? ?? String.fromCharCode(65 + i);
      final icon = item['onIcon'] as String?;
      if (icon != null && icon.isNotEmpty) {
        setupBuf.writeln('  $name.add({"$label", "$icon"});');
      } else {
        setupBuf.writeln('  $name.add({"$label"});');
      }
    }
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
