import 'dart:convert';
import 'dart:io';
import 'package:radiokit_widgets/radiokit_widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Thin wrapper that exercises the DesignerState load/save API externally.
//  The actual markers / JSON lives in designer_state.dart — this module
//  provides convenience functions for call-sites that don't hold a state
//  instance yet (e.g. dialogs that create a state on the fly).
// ─────────────────────────────────────────────────────────────────────────────

Future<HeaderFileConfig> parseHeaderFile(String filePath) async {
  final content = await File(filePath).readAsString();
  final match = DesignerState.configPattern.firstMatch(content);
  if (match == null || match.group(1) == null) {
    throw FormatException(
      'No /*__RADIOKIT_Designer_Config__ … */ block found in $filePath',
    );
  }
  final jsonStr = (match.group(1) as String).trim();
  final decoded = json.decode(jsonStr) as Map<String, dynamic>;
  return HeaderFileConfig.fromJson(decoded);
}

class HeaderFileConfig {
  final int version;
  final HeaderAppConfig app;
  final HeaderCanvasConfig canvas;
  final List<DesignerElement> widgets;

  const HeaderFileConfig({
    required this.version,
    required this.app,
    required this.canvas,
    required this.widgets,
  });

  factory HeaderFileConfig.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    final appJson = json['config'] as Map<String, dynamic>? ?? {};
    final canvasJson = json['canvas'] as Map<String, dynamic>? ?? {};
    final widgetsJson = json['widgets'] as List? ?? [];

    return HeaderFileConfig(
      version: version,
      app: HeaderAppConfig.fromJson(appJson),
      canvas: HeaderCanvasConfig.fromJson(canvasJson),
      widgets: widgetsJson
          .map((e) => DesignerElement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'config': app.toJson(),
        'canvas': canvas.toJson(),
        'widgets': widgets.map((e) => e.toJson()).toList(),
      };
}

class HeaderAppConfig {
  final String name;
  final String description;
  final String type;
  final String transport;
  final String theme;
  final String password;

  const HeaderAppConfig({
    this.name = '',
    this.description = '',
    this.type = 'Locomotive',
    this.transport = 'BLE',
    this.theme = 'dragon',
    this.password = '',
  });

  factory HeaderAppConfig.fromJson(Map<String, dynamic> json) => HeaderAppConfig(
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        type: json['type'] as String? ?? 'Locomotive',
        transport: json['transport'] as String? ?? 'BLE',
        theme: json['theme'] as String? ?? 'dragon',
        password: json['password'] as String? ?? '',
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'type': type,
        'transport': transport,
        'theme': theme,
        'password': password,
      };
}

class HeaderCanvasConfig {
  final String size;
  final String grid;
  final String skin;

  const HeaderCanvasConfig({
    this.size = '200 x 100',
    this.grid = 'none',
    this.skin = 'dragon',
  });

  factory HeaderCanvasConfig.fromJson(Map<String, dynamic> json) {
    // read 'size' (array [w, h] or legacy string "W x H")
    final rawSize = json['size'] ?? json['screenSize'];
    String resolvedSize;
    if (rawSize is List && rawSize.length >= 2) {
      final w = (rawSize[0] as num?)?.toInt() ?? 200;
      final h = (rawSize[1] as num?)?.toInt() ?? 100;
      resolvedSize = '${w} x ${h}';
    } else if (rawSize is String) {
      resolvedSize = rawSize;
    } else {
      resolvedSize = '200 x 100';
    }
    return HeaderCanvasConfig(
      size: resolvedSize,
      grid: json['grid'] as String? ?? 'none',
      skin: json['skin'] as String? ?? 'dragon',
    );
  }

  Map<String, dynamic> toJson() => {
        'size': size,
        'grid': grid,
        'skin': skin,
      };
}
