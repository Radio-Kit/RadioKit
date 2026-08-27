import 'package:radiokit_widgets/radiokit_widgets.dart';

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
    buf.writeln('#ifndef RADIOKIT_GENERATED_H');
    buf.writeln('#define RADIOKIT_GENERATED_H');
    buf.writeln();

    // ─── Transport defines ───
    final transports = config['transports'] as Map<String, dynamic>? ?? {};
    final bleEnabled = (transports['ble']?['enabled'] as bool?) ?? true;
    final wifiEnabled = (transports['wifi']?['enabled'] as bool?) ?? false;
    final cloudEnabled = (transports['cloud']?['enabled'] as bool?) ?? false;

    // ─── Feature defines (must precede #include) ───
    if (enableOta) {
      buf.writeln('#define RK_ENABLE_OTA');
    }
    if (enableFs) {
      buf.writeln('#define RK_ENABLE_FS');
    }
    if (bleEnabled) {
      buf.writeln('#define RK_ENABLE_BLE');
    }
    if (wifiEnabled || cloudEnabled) {
      buf.writeln('#define RK_ENABLE_WIFI');
    }
    if (cloudEnabled) {
      buf.writeln('#define RK_ENABLE_CLOUD');
    }
    if (enableOta || enableFs || bleEnabled || wifiEnabled || cloudEnabled) buf.writeln();
    buf.writeln('#include <RadioKitLib.h>');
    buf.writeln();

    final setupBuf = StringBuffer();

    // ─── Multi-page support ───
    final version = json['version'] as int? ?? 1;
    final pages = json['pages'] as List? ?? [];
    final isMultiPage = version >= 2 && pages.isNotEmpty;

    if (isMultiPage) {
      // v2 format: pages[] array
      buf.writeln('#define RK_NUM_PAGES ${pages.length}');
      buf.writeln('static const char* rk_pageNames[] = {');
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i] as Map<String, dynamic>? ?? {};
        final pageName = page['name'] as String? ?? 'Page ${i + 1}';
        buf.writeln('  "${_escapeC(pageName)}",');
      }
      buf.writeln('};');
      buf.writeln();

      // Per-page orientations (0=landscape, 1=portrait)
      buf.writeln('static const uint8_t rk_pageOrientations[] = {');
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i] as Map<String, dynamic>? ?? {};
        final orientation = page['orientation'] as String? ?? 'global';
        // 'global' uses the canvas orientation, default to landscape (0)
        final isPortrait = orientation == 'portrait';
        buf.writeln('  ${isPortrait ? 1 : 0},  // ${page['name'] ?? 'Page ${i + 1}'}');
      }
      buf.writeln('};');
      buf.writeln();

      // Widget declarations grouped by page
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i] as Map<String, dynamic>? ?? {};
        final pageName = page['name'] as String? ?? 'Page ${i + 1}';
        final pageWidgets = page['widgets'] as List? ?? [];
        if (pageWidgets.isNotEmpty) {
          buf.writeln('// ─── Page $i: $pageName ───');
        for (final w in pageWidgets) {
          if (w is! Map<String, dynamic>) continue;
          _generateWidget(w, buf, setupBuf, pageIndex: i);
          buf.writeln();
        }
        }
      }
    } else {
      // v1 format: flat widgets[]
      if (widgets.isNotEmpty) {
        buf.writeln('// ─── Widget Declarations ───');
        for (final w in widgets) {
          if (w is! Map<String, dynamic>) continue;
          _generateWidget(w, buf, setupBuf);
          buf.writeln();
        }
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

    // ─── Canvas Display Flags ───
    final canvas = json['canvas'] as Map<String, dynamic>? ?? {};
    final showPageBar = canvas['showPageBar'] as bool? ?? true;
    final showControlPageBar = canvas['showControlPageBar'] as bool? ?? true;
    int canvasFlags = 0;
    if (showPageBar) canvasFlags |= 0x01;
    if (showControlPageBar) canvasFlags |= 0x02;

    // ─── Multi-page initialization ───
    if (isMultiPage) {
      buf.writeln('  RadioKit.setNumPages(RK_NUM_PAGES);');
      buf.writeln('  RadioKit.setPageNames(rk_pageNames);');
      buf.writeln('  RadioKit.setPageOrientations(rk_pageOrientations);');
      if (canvasFlags != 0x03) {
        buf.writeln('  RadioKit.setCanvasFlags(0x${canvasFlags.toRadixString(16).padLeft(2, '0')});');
      }
      buf.writeln();
    }

    buf.writeln('  RadioKit.begin();');
    buf.writeln();
    buf.writeln('  RadioKit.startSerial(Serial);');
    if (bleEnabled) {
      buf.writeln('  RadioKit.startBLE();');
    }
    if (wifiEnabled) {
      buf.writeln('  RadioKit.startWiFi();');
    }
    if (cloudEnabled) {
      buf.writeln('  RadioKit.startCloud();');
    }

    // ─── Feature initialization ───
    if (enableFs) {
      buf.writeln('');
      buf.writeln('  RadioKit.enableFS();');
    }

    buf.writeln('}');
    buf.writeln();
    buf.writeln('#endif // RADIOKIT_GENERATED_H');
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

    // ── Transport config fields ──
    final transports = config['transports'] as Map<String, dynamic>? ?? {};
    final wifi = transports['wifi'] as Map<String, dynamic>? ?? {};
    final cloud = transports['cloud'] as Map<String, dynamic>? ?? {};
    final wifiEnabled = (wifi['enabled'] as bool?) ?? false;
    final cloudEnabled = (cloud['enabled'] as bool?) ?? false;

    if (wifiEnabled) {
      final ssid = (wifi['ssid'] as String?) ?? '';
      final pass = (wifi['pass'] as String?) ?? '';
      if (ssid.isNotEmpty) {
        buf.writeln('${indent}RadioKit.config.sta_ssid     = "${_escapeC(ssid)}";');
      }
      if (pass.isNotEmpty) {
        buf.writeln('${indent}RadioKit.config.sta_password = "${_escapeC(pass)}";');
      }
    }

    if (cloudEnabled) {
      final account = (cloud['account'] as String?) ?? '';
      final relay = (cloud['relay'] as String?) ?? '';
      if (relay.isNotEmpty) {
        buf.writeln('${indent}RadioKit.config.cloud_url     = "${_escapeC(relay)}";');
      }
      if (account.isNotEmpty) {
        buf.writeln('${indent}RadioKit.config.cloud_account = "${_escapeC(account)}";');
      }
    }

    // ── Remote link config fields ──
    final links = config['links'] as Map<String, dynamic>? ?? {};
    final fsUrl = (links['fs'] as String?) ?? '';
    final otaUrl = (links['ota'] as String?) ?? '';

    if (fsUrl.isNotEmpty) {
      buf.writeln('${indent}RadioKit.config.fs_url       = "${_escapeC(fsUrl)}";');
    }
    if (otaUrl.isNotEmpty) {
      buf.writeln('${indent}RadioKit.config.ota_url      = "${_escapeC(otaUrl)}";');
    }
  }

  // ── Widget generator ─────────────────────────────────────────────────────

  static void _generateWidget(
      Map<String, dynamic> w, StringBuffer declBuf, StringBuffer setupBuf,
      {int pageIndex = 0}) {
    final type = w['type'] as String;
    final name = _sanitizeName(w['name'] as String? ?? '');
    final position = w['position'] as List? ?? [10, 10, 0];
    final size = w['size'] as List? ?? [20, 20];
    final props = w['properties'] as Map<String, dynamic>? ?? {};
    final labelObj = w['label'] as Map<String, dynamic>?;
    final labelText = labelObj?['text'] as String? ?? '';
    final showLabel = labelObj?['show'] as bool? ?? true;
    final variant = w['variant'] as String?;
    final x = (position.isNotEmpty && position[0] is num)
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

    // Read hidden flag from top-level.
    final isHidden = (w['hidden'] as bool?) ?? false;

    // Common label post-set (for widgets that have labels)
    void writeLabelAndHidden() {
      // Emit page assignment for multi-page configs.
      if (pageIndex > 0) {
        setupBuf.writeln('  $name.setPage($pageIndex);');
      }
      if (labelText.isNotEmpty) {
        setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
      }
      if (!showLabel) {
        setupBuf.writeln('  $name.setLabelHidden(true);');
      }
    }

    final definition = WidgetRegistry.instance.getById(type);
    if (definition != null) {
      final customCode = definition.generateCppCode(CodegenContext(
        varName: name,
        cppType: type,
        variant: variant,
        properties: props,
        label: labelText,
        pageIndex: pageIndex,
      ));
      if (customCode.isNotEmpty) {
        setupBuf.write(customCode);
      }
    }

    switch (type) {
      case 'button': {
        final mode = props['variant'] ?? 'push';
        final widgetType =
            mode == 'toggle' ? 'RK_ToggleButton' : 'RK_PushButton';
        final onText = (props['onText'] as String?) ?? 'ON';
        final offText = (props['offText'] as String?) ?? 'OFF';
        final onIconName = props['onIcon'] as String? ?? props['icon'] as String? ?? '';
        final offIconName = props['offIcon'] as String? ?? '';
        
        declBuf.writeln('$widgetType $name($x, $y, $cppH, $cppW, $rotation);$comment');
        
        writeLabelAndHidden();
        if (onText.isNotEmpty) {
          setupBuf.writeln('  $name.rk.onText = "${_escapeC(onText)}";');
        }
        if (offText.isNotEmpty) {
          setupBuf.writeln('  $name.rk.offText = "${_escapeC(offText)}";');
        }
        if (onIconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.icon = "$onIconName";');
        }
        if (offIconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.offIcon = "$offIconName";');
        }
        break;
      }

      case 'slideSwitch': {
        final onText = (props['onText'] as String?) ?? 'ON';
        final offText = (props['offText'] as String?) ?? 'OFF';
        final onIconName = props['onIcon'] as String? ?? props['icon'] as String? ?? '';
        final offIconName = props['offIcon'] as String? ?? '';
        
        declBuf.writeln('RK_SlideSwitch $name($x, $y, $cppH, $cppW, $rotation);$comment');
        
        writeLabelAndHidden();
        if (onText.isNotEmpty) {
          setupBuf.writeln('  $name.rk.onText = "${_escapeC(onText)}";');
        }
        if (offText.isNotEmpty) {
          setupBuf.writeln('  $name.rk.offText = "${_escapeC(offText)}";');
        }
        if (onIconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.icon = "$onIconName";');
        }
        if (offIconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.offIcon = "$offIconName";');
        }
        break;
      }

      case 'switch': {
        final v = variant ?? props['variant'] as String?;
        final isRocker = v == 'rockerSwitch';
        final onText = props['onText'] as String? ?? '';
        final offText = props['offText'] as String? ?? '';
        final onIconName = props['onIcon'] as String? ?? props['icon'] as String? ?? '';
        final offIconName = props['offIcon'] as String? ?? '';
        
        if (isRocker) {
          declBuf.writeln('RK_RockerSwitch $name($x, $y, $cppH, $cppW, $rotation);$comment');
        } else {
          declBuf.writeln('RK_SlideSwitch $name($x, $y, $cppH, $cppW, $rotation);$comment');
        }
        
        writeLabelAndHidden();
        if (onText.isNotEmpty) {
          setupBuf.writeln('  $name.rk.onText = "${_escapeC(onText)}";');
        }
        if (offText.isNotEmpty) {
          setupBuf.writeln('  $name.rk.offText = "${_escapeC(offText)}";');
        }
        if (onIconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.icon = "$onIconName";');
        }
        if (offIconName.isNotEmpty) {
          setupBuf.writeln('  $name.rk.offIcon = "$offIconName";');
        }
        break;
      }

      case 'slider': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'gasPedal') {
          _gasPedal(name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf, labelText, showLabel, pageIndex: pageIndex);
        } else {
          _slider(name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf, labelText, showLabel, pageIndex: pageIndex);
        }
        break;
      }

      case 'knob': {
        final v = variant ?? props['variant'] as String?;
        if (v == 'steeringWheel') {
          _steeringWheel(name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf, labelText, showLabel, pageIndex: pageIndex);
        } else {
          _knob(name, x, y, cppW, cppH, rotation, props, acList, comment, declBuf, setupBuf, labelText, showLabel, pageIndex: pageIndex);
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
        if (v == 'select' || v == 'multiSelect') {
          _buildMultiple('RK_MultipleSelect', name, x, y, cppW, cppH,
              rotation, props, comment, declBuf, setupBuf, labelText, showLabel, pageIndex: pageIndex, variant: v);
        } else {
          _buildMultiple('RK_MultipleButton', name, x, y, cppW, cppH,
              rotation, props, comment, declBuf, setupBuf, labelText, showLabel, pageIndex: pageIndex, variant: v);
        }
        break;
      }

      case 'led': {
        final color = props['color'];
        final colorVal = (color is num) ? color.toInt() : 0x00FF00;
        final colorHex =
            colorVal.toRadixString(16).padLeft(6, '0');
        final shapeStr = (props['shape'] as String?) ?? '';
            
        declBuf.writeln('RK_LED $name($x, $y, $cppH, $cppW, $rotation);$comment');
        
        writeLabelAndHidden();
        setupBuf.writeln('  $name.rk.color = 0x$colorHex;');
        if (shapeStr == 'square') {
          setupBuf.writeln('  $name.rk.shape = RK_LED_SHAPE_SQUARE;');
        } else if (shapeStr == 'diamond') {
          setupBuf.writeln('  $name.rk.shape = RK_LED_SHAPE_DIAMOND;');
        } else if (shapeStr == 'star') {
          setupBuf.writeln('  $name.rk.shape = RK_LED_SHAPE_STAR;');
        }
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

    // Emit setHidden() for ALL widget types (including sub-method variants).
    if (isHidden) {
      setupBuf.writeln('  $name.setHidden(true);');
    }
  }

  // ── Sub-generators for widget variants ────────────────────────────────────

  static void _slider(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel, {int pageIndex = 0}) {
    final detents = props['detents'] ?? props['divisions'] ?? 0;
    declBuf.writeln('RK_Slider $name($x, $y, $h, $w, $rot);$comment');
    if (pageIndex > 0) {
      setupBuf.writeln('  $name.setPage($pageIndex);');
    }
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.setLabelHidden(true);');
    }
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(ac)};');
    if (detents is num && detents > 0) {
      setupBuf.writeln('  $name.rk.detents = ${detents.toInt()};');
    }
  }

  static void _gasPedal(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel, {int pageIndex = 0}) {
    final detents = props['detents'] ?? props['divisions'] ?? 0;
    declBuf.writeln('RK_GasPedal $name($x, $y, $h, $w, $rot);$comment');
    if (pageIndex > 0) {
      setupBuf.writeln('  $name.setPage($pageIndex);');
    }
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.setLabelHidden(true);');
    }
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(ac)};');
    if (detents is num && detents > 0) {
      setupBuf.writeln('  $name.rk.detents = ${detents.toInt()};');
    }
  }

  static void _knob(String name, int x, int y, int w, int h, int rot,
      Map<String, dynamic> props, List? ac, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel, {int pageIndex = 0}) {
    final startAngle = props['startAngle'] ?? props['minAngle'] ?? -135;
    final endAngle = props['endAngle'] ?? props['maxAngle'] ?? 135;
    final detents = props['detents'] ?? props['divisions'] ?? 0;
    
    declBuf.writeln('RK_Knob $name($x, $y, $h, $w, $rot);$comment');
    if (pageIndex > 0) {
      setupBuf.writeln('  $name.setPage($pageIndex);');
    }
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.setLabelHidden(true);');
    }
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(ac)};');
    setupBuf.writeln('  $name.rk.startAngle = $startAngle;');
    setupBuf.writeln('  $name.rk.endAngle = $endAngle;');
    if (detents is num && detents > 0) {
      setupBuf.writeln('  $name.rk.detents = ${detents.toInt()};');
    }
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
      String labelText, bool showLabel, {int pageIndex = 0}) {
    final startAngle = props['startAngle'] ?? props['minAngle'] ?? -150;
    final endAngle = props['endAngle'] ?? props['maxAngle'] ?? 150;
    final detents = props['detents'] ?? props['divisions'] ?? 0;
    
    declBuf.writeln('RK_Knob $name($x, $y, $h, $w, $rot);$comment');
    if (pageIndex > 0) {
      setupBuf.writeln('  $name.setPage($pageIndex);');
    }
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.setLabelHidden(true);');
    }
    setupBuf.writeln('  $name.rk.variant = 1;     // steeringWheel');
    final acEffective = (ac != null && ac.isNotEmpty) ? ac : ['center', 'smooth', 500];
    setupBuf.writeln('  $name.rk.centering = ${_centeringEnum(acEffective)};');
    setupBuf.writeln('  $name.rk.startAngle = $startAngle;');
    setupBuf.writeln('  $name.rk.endAngle = $endAngle;');
    if (detents is num && detents > 0) {
      setupBuf.writeln('  $name.rk.detents = ${detents.toInt()};');
    }
    final iconName = props['icon'] as String? ?? '';
    if (iconName.isNotEmpty) {
      setupBuf.writeln('  $name.rk.icon = "$iconName";');
    }
    final centerIcon = props['centerIcon'] as String? ?? '';
    if (centerIcon.isNotEmpty) {
      setupBuf.writeln('  $name.rk.centerIcon = "$centerIcon";');
    }
  }

  static void _buildMultiple(String widgetType, String name, int x, int y,
      int w, int h, int rot, Map<String, dynamic> props, String comment, StringBuffer declBuf, StringBuffer setupBuf,
      String labelText, bool showLabel, {int pageIndex = 0, String? variant}) {
    final items = props['items'] as List? ?? [];
    
    declBuf.writeln('$widgetType $name($x, $y, $h, $w, $rot);$comment');
    if (pageIndex > 0) {
      setupBuf.writeln('  $name.setPage($pageIndex);');
    }
    if (labelText.isNotEmpty) {
      setupBuf.writeln('  $name.rk.label = "${_escapeC(labelText)}";');
    }
    if (!showLabel) {
      setupBuf.writeln('  $name.setLabelHidden(true);');
    }

    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      if (item is! Map) continue;
      final rawLabel = item['onLabel'] as String? ?? item['label'] as String? ?? item['text'] as String?;
      final icon = item['onIcon'] as String? ?? item['icon'] as String?;
      final hasIcon = icon != null && icon.isNotEmpty;
      final label = rawLabel ?? (hasIcon ? '' : String.fromCharCode(65 + i));
      final iconPart = hasIcon ? '"$icon"' : 'nullptr';
      setupBuf.writeln('  $name.rk.items[$i] = {"${_escapeC(label)}", $iconPart, $i};');
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
    switch (pos) {
      case 'min':
        return 'RK_SPRING_MIN';
      case 'max':
        return 'RK_SPRING_MAX';
      case 'top':
        return 'RK_SPRING_TOP';
      case 'bottom':
        return 'RK_SPRING_BOTTOM';
      case 'center':
        return 'RK_SPRING_CENTER';
      default:
        return 'RK_SPRING_NONE';
    }
  }
}
