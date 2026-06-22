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

    // ─── Telemetry Widgets ───
    final telemetry = json['telemetry'] as List? ?? [];
    final hasTelemetry = telemetry.any((t) {
      final label = (t is Map ? t['label'] : null) as String?;
      return label?.isNotEmpty == true;
    });
    if (hasTelemetry) {
      buf.writeln('// ─── Telemetry Widgets ───');
      for (int i = 0; i < telemetry.length; i++) {
        final t = telemetry[i];
        if (t is! Map<String, dynamic>) continue;
        final label = (t['label'] as String?) ?? '';
        if (label.isEmpty) continue;
        final sanitized = _sanitizeName(label);
        
        final cppName = 'telemetry_$sanitized';
        buf.writeln('RK_Telemetry $cppName("$sanitized");');
        
        final iconName = (t['icon'] as String?) ?? '';
        if (iconName.isNotEmpty) {
          setupBuf.writeln('  $cppName.rk.icon = "$iconName";');
        }
        final unit = (t['unit'] as String?) ?? '';
        if (unit.isNotEmpty) {
          setupBuf.writeln('  $cppName.rk.unit = "$unit";');
        }
        setupBuf.writeln('  $cppName.rk.content = "--";');
      }
      buf.writeln();
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
    final theme = config['theme'] as String? ?? 'dragon';
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
    buf.writeln('${indent}RadioKit.config.theme       = "${_escapeC(theme)}";');
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
    final labelObj = w['label'] as Map<String, dynamic>?;
    final labelText = labelObj?['text'] as String? ?? '';
    final showLabel = labelObj?['show'] as bool? ?? true;
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

    // Common label post-set (for widgets that have labels)
    void writeLabelAndHidden() {
      if (labelText.isNotEmpty) {
        setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
      }
      if (!showLabel) {
        setupBuf.writeln('  $name.rk.labelHidden = true;');
      }
    }

    switch (type) {
      case 'button': {
        final mode = props['variant'] ?? 'push';
        final widgetType =
            mode == 'toggle' ? 'RK_ToggleButton' : 'RK_PushButton';
        final onText = props['onText'] ?? 'ON';
        final offText = props['offText'] ?? 'OFF';
        final iconName = props['onIcon'] as String? ?? '';
        
        declBuf.writeln('$widgetType $name($x, $y, $cppH, $cppW, $rotation);$comment');
        
        writeLabelAndHidden();
        if (onText != 'ON') {
          setupBuf.writeln('  $name.rk.onText = "${_escapeC(onText)}";');
        }
        if (offText != 'OFF') {
          setupBuf.writeln('  $name.rk.offText = "${_escapeC(offText)}";');
        }
        if (iconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.icon = "$iconName";');
        }
        break;
      }

      case 'slideSwitch': {
        final onText = props['onText'] ?? 'ON';
        final offText = props['offText'] ?? 'OFF';
        final iconName = props['icon'] as String? ?? '';
        
        declBuf.writeln('RK_SlideSwitch $name($x, $y, $cppH, $cppW, $rotation);$comment');
        
        writeLabelAndHidden();
        if (onText != 'ON') {
          setupBuf.writeln('  $name.rk.onText = "${_escapeC(onText)}";');
        }
        if (offText != 'OFF') {
          setupBuf.writeln('  $name.rk.offText = "${_escapeC(offText)}";');
        }
        if (iconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.icon = "$iconName";');
        }
        break;
      }

      case 'switch': {
        final v = variant ?? props['variant'] as String?;
        final isRocker = v == 'rockerSwitch';
        final iconName = props['icon'] as String? ?? '';
        
        if (isRocker) {
          declBuf.writeln('RK_RockerSwitch $name($x, $y, $cppH, $cppW, $rotation);$comment');
        } else {
          declBuf.writeln('RK_SlideSwitch $name($x, $y, $cppH, $cppW, $rotation);$comment');
        }
        
        writeLabelAndHidden();
        if (iconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.icon = "$iconName";');
        }
        break;
      }

      case 'slider': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'gasPedal') {
          _gasPedal(name, x, y, cppW, cppH, rotation, acList, comment, declBuf, setupBuf, labelText, showLabel);
        } else {
          _slider(name, x, y, cppW, cppH, rotation, acList, comment, declBuf, setupBuf, labelText, showLabel);
        }
        break;
      }

      case 'knob': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'steeringWheel') {
          _steeringWheel(name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf, labelText, showLabel);
        } else {
          _knob(name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf, labelText, showLabel);
        }
        break;
      }

      case 'joystick': {
        declBuf.writeln('RK_Joystick $name($x, $y, $cppH, $cppW, $rotation);$comment');
        writeLabelAndHidden();
        setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(acList)};');
        break;
      }

      case 'multiple': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'multiSelect') {
          _buildMultiple('RK_MultipleSelect', name, x, y, cppW, cppH,
              rotation, props, comment, declBuf, setupBuf, labelText, showLabel);
        } else {
          _buildMultiple('RK_MultipleButton', name, x, y, cppW, cppH,
              rotation, props, comment, declBuf, setupBuf, labelText, showLabel);
        }
        break;
      }

      case 'led': {
        final color = props['color'];
        final colorVal = (color is num) ? color.toInt() : 0x00FF00;
        final colorHex =
            colorVal.toRadixString(16).padLeft(6, '0');
            
        declBuf.writeln('RK_LED $name($x, $y, $cppH, $cppW, $rotation);$comment');
        
        writeLabelAndHidden();
        setupBuf.writeln('  $name.rk.color = 0x$colorHex;');
        break;
      }

      case 'text': {
        final text = props['text'] as String? ?? 'Display';
        
        declBuf.writeln('RK_Text $name($x, $y, $cppH, $cppW);$comment');
        
        writeLabelAndHidden();
        setupBuf.writeln('  $name.rk.content = "${_escapeC(text)}";');
        break;
      }

      case 'serialMonitor': {
        declBuf.writeln('RK_SerialMonitor $name($x, $y, $cppH, $cppW);$comment');
        writeLabelAndHidden();
        break;
      }

      default:
        declBuf.writeln('  // Unsupported widget type: $type');
        break;
    }
  }

  // ── Sub-generators for widget variants ────────────────────────────────────

  static void _slider(String name, int x, int y, int w, int h, int rot,
      List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel) {
    declBuf.writeln('RK_Slider $name($x, $y, $h, $w, $rot);$comment');
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.rk.labelHidden = true;');
    }
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(ac)};');
  }

  static void _gasPedal(String name, int x, int y, int w, int h, int rot,
      List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel) {
    declBuf.writeln('RK_GasPedal $name($x, $y, $h, $w, $rot);$comment');
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.rk.labelHidden = true;');
    }
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(ac)};');
  }

  static void _knob(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel) {
    final minAngle = props['minAngle'] ?? -135;
    final maxAngle = props['maxAngle'] ?? 135;
    
    declBuf.writeln('RK_Knob $name($x, $y, $h, $w, $rot);$comment');
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.rk.labelHidden = true;');
    }
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(ac)};');
    setupBuf.writeln('  $name.rk.startAngle = $minAngle;');
    setupBuf.writeln('  $name.rk.endAngle = $maxAngle;');
    final iconName = props['icon'] as String? ?? '';
    if (iconName.isNotEmpty) {
      setupBuf.writeln('  $name.rk.icon = "$iconName";');
    }
    final centerIcon = props['centerIcon'] as String? ?? '';
    if (centerIcon.isNotEmpty) {
      setupBuf.writeln('  $name.rk.centerIcon = "$centerIcon";');
    }
  }

  static void _steeringWheel(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel) {
    final minAngle = props['minAngle'] ?? -135;
    final maxAngle = props['maxAngle'] ?? 135;
    
    declBuf.writeln('RK_Knob $name($x, $y, $h, $w, $rot);$comment');
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.rk.labelHidden = true;');
    }
    setupBuf.writeln('  $name.rk.variant = 1;     // steeringWheel');
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(ac)};');
    setupBuf.writeln('  $name.rk.startAngle = $minAngle;');
    setupBuf.writeln('  $name.rk.endAngle = $maxAngle;');
  }

  static void _buildMultiple(String widgetType, String name, int x, int y,
      int w, int h, int rot, Map<String, dynamic> props, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel) {
    final items = props['items'] as List? ?? [];
    
    declBuf.writeln('$widgetType $name($x, $y, $h, $w, $rot);$comment');
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.rk.labelHidden = true;');
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) continue;
      final label = item['onLabel'] as String? ?? String.fromCharCode(65 + i);
      final icon = item['onIcon'] as String?;
      final iconPart = (icon != null && icon.isNotEmpty) ? ', "$icon"' : '';
      setupBuf.writeln('  $name.rk.items[$i] = {"$label"$iconPart, $i};');
    }
    if (items.isNotEmpty) {
      setupBuf.writeln('  $name.rk.itemCount = ${items.length};');
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
