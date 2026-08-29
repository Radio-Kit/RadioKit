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
  final List<DesignerPage> pages;

  /// Convenience: flatten all pages' widgets into a single list.
  List<DesignerElement> get widgets => pages.expand((p) => p.elements).toList();

  const HeaderFileConfig({
    required this.version,
    required this.app,
    required this.canvas,
    required this.pages,
  });

  factory HeaderFileConfig.fromJson(Map<String, dynamic> json) {
    final version = json['version'] as int? ?? 1;
    final appJson = json['config'] as Map<String, dynamic>? ?? {};
    final canvasJson = json['canvas'] as Map<String, dynamic>? ?? {};

    List<DesignerPage> parsedPages;
    if (version >= 2 && json.containsKey('pages')) {
      // v2 format: pages[]
      parsedPages = (json['pages'] as List? ?? [])
          .map((e) => DesignerPage.fromJson(e as Map<String, dynamic>))
          .toList();
    } else {
      // v1 format: flat widgets[]
      final widgetsJson = json['widgets'] as List? ?? [];
      final page = DesignerPage(name: 'Page 1');
      for (final wJson in widgetsJson) {
        page.elements.add(DesignerElement.fromJson(wJson as Map<String, dynamic>));
      }
      // Read orientation from canvas.size
      final rawSize = canvasJson['size'] ?? canvasJson['screenSize'];
      if (rawSize is List && rawSize.length >= 2) {
        final w = (rawSize[0] as num?)?.toInt() ?? 200;
        final h = (rawSize[1] as num?)?.toInt() ?? 100;
        page.isLandscape = w >= h;
      }
      parsedPages = [page];
    }

    if (parsedPages.isEmpty) {
      parsedPages = [DesignerPage(name: 'Page 1')];
    }

    return HeaderFileConfig(
      version: version,
      app: HeaderAppConfig.fromJson(appJson),
      canvas: HeaderCanvasConfig.fromJson(canvasJson),
      pages: parsedPages,
    );
  }

  Map<String, dynamic> toJson() => {
        'version': version,
        'config': app.toJson(),
        'canvas': canvas.toJson(),
        'pages': pages.map((p) => p.toJson()).toList(),
      };
}

class HeaderAppConfig {
  final String name;
  final String description;
  final String type;
  final Map<String, dynamic> transports;
  final String theme;
  final String password;
  final String userPassword;

  const HeaderAppConfig({
    this.name = '',
    this.description = '',
    this.type = 'Locomotive',
    this.transports = const {
      'ble': {'enabled': true},
      'wifi': {'enabled': false, 'ssid': '', 'pass': ''},
      'cloud': {'enabled': false, 'account': '', 'relay': ''},
    },
    this.theme = 'dragon',
    this.password = '',
    this.userPassword = '',
  });

  bool get bleEnabled => (transports['ble']?['enabled'] as bool?) ?? true;
  bool get wifiEnabled => (transports['wifi']?['enabled'] as bool?) ?? false;
  bool get cloudEnabled => (transports['cloud']?['enabled'] as bool?) ?? false;
  String get wifiSsid => (transports['wifi']?['ssid'] as String?) ?? '';
  String get wifiPass => (transports['wifi']?['pass'] as String?) ?? '';
  String get cloudAccount => (transports['cloud']?['account'] as String?) ?? '';
  String get cloudRelay => (transports['cloud']?['relay'] as String?) ?? '';

  factory HeaderAppConfig.fromJson(Map<String, dynamic> json) {
    final transports = json['transports'] as Map<String, dynamic>?;
    return HeaderAppConfig(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'Locomotive',
      transports: transports ??
          {
            'ble': {'enabled': true},
            'wifi': {'enabled': false, 'ssid': '', 'pass': ''},
            'cloud': {'enabled': false, 'account': '', 'relay': ''},
          },
      theme: json['theme'] as String? ?? 'dragon',
      password: json['password'] as String? ?? '',
      userPassword: json['user_password'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'type': type,
        'transports': transports,
        'theme': theme,
        'password': password,
        'user_password': userPassword,
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
