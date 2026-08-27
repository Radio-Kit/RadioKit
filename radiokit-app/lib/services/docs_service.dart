import 'package:flutter/services.dart';

/// Serves SKILLS documentation as structured JSON for agent consumption.
///
/// Reads SKILL.md files from Flutter assets at startup, caches
/// name, description, and content in memory, and serves them via the
/// REST API. Also serves llms.txt for LLM discovery.
class DocsService {
  final List<SkillDoc> _skills = [];
  String _llmsTxt = '';

  /// Load all SKILL.md files from the assets/skills/ directory.
  /// Call once at startup before serving requests.
  Future<void> loadSkills() async {
    _skills.clear();

    // Load llms.txt
    try {
      _llmsTxt = await rootBundle.loadString('assets/skills/llms.txt');
    } catch (e) {
      _llmsTxt = '# RadioKit API\n\nNo documentation loaded.';
    }

    // List of skill files bundled as assets
    const skillFiles = [
      'assets/skills/radiokit-firmware.md',
      'assets/skills/radiokit-widgets.md',
      'assets/skills/radiokit-transports.md',
      'assets/skills/radiokit-filesystem.md',
      'assets/skills/radiokit-ota.md',
      'assets/skills/radiokit-remote.md',
    ];

    for (final path in skillFiles) {
      try {
        final content = await rootBundle.loadString(path);
        final metadata = _parseFrontmatter(content);
        // Extract name from filename: "assets/skills/radiokit-firmware.md" -> "radiokit-firmware"
        final filename = path.split('/').last;
        final name = filename.replaceAll('.md', '');
        final description = metadata['description'] ?? '';

        _skills.add(SkillDoc(
          name: name,
          description: description,
          content: content,
          path: '/api/docs/$name',
        ));
      } catch (e) {
        // Skip files that can't be loaded
      }
    }
  }

  /// Return the list of all available skills (index endpoint).
  List<Map<String, String>> getSkillsIndex() {
    return _skills
        .map((s) => {
              'name': s.name,
              'description': s.description,
              'path': s.path,
            })
        .toList();
  }

  /// Return the full content of a specific skill, or null if not found.
  SkillDoc? getSkillContent(String name) {
    try {
      return _skills.firstWhere((s) => s.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Return the llms.txt content for LLM discovery.
  String getLlmsTxt() => _llmsTxt;

  /// Return API schema describing all registered routes.
  /// This is a static description of the REST API surface.
  Map<String, dynamic> getApiSchema() {
    return {
      'title': 'RadioKit Remote Access API',
      'version': '1.0.0',
      'baseUrl': 'http://<app-ip>:7007',
      'endpoints': _apiEndpoints,
    };
  }

  /// Parse YAML-like frontmatter from markdown content.
  /// Expects format: `---\nkey: value\n...\n` at the start of the file.
  static Map<String, String> _parseFrontmatter(String content) {
    final result = <String, String>{};
    if (!content.startsWith('---')) return result;

    final endIdx = content.indexOf('---', 3);
    if (endIdx == -1) return result;

    final frontmatter = content.substring(3, endIdx).trim();
    for (final line in frontmatter.split('\n')) {
      final colonIdx = line.indexOf(':');
      if (colonIdx == -1) continue;
      final key = line.substring(0, colonIdx).trim();
      final value = line.substring(colonIdx + 1).trim();
      result[key] = value;
    }
    return result;
  }

  static const _apiEndpoints = [
    {
      'method': 'GET',
      'path': '/api/status',
      'description': 'Server health and version info',
    },
    {
      'method': 'GET',
      'path': '/api/settings',
      'description': 'Read app settings',
    },
    {
      'method': 'PUT',
      'path': '/api/settings',
      'description': 'Update app settings',
    },
    {
      'method': 'GET',
      'path': '/api/pair/devices',
      'description': 'List scanned BLE/serial devices',
    },
    {
      'method': 'POST',
      'path': '/api/pair/scan',
      'description': 'Start BLE or serial scan',
    },
    {
      'method': 'GET',
      'path': '/api/connection',
      'description': 'Get connection status and device info',
    },
    {
      'method': 'POST',
      'path': '/api/connection/connect',
      'description': 'Connect to a device',
      'body': {
        'id': 'string (required)',
        'type': 'string (ble|serial|wifi)',
        'baudRate': 'int (optional, default 1000000)',
      },
    },
    {
      'method': 'POST',
      'path': '/api/connection/disconnect',
      'description': 'Disconnect from device',
    },
    {
      'method': 'POST',
      'path': '/api/connection/reconnect',
      'description': 'Auto-reconnect to last paired device',
    },
    {
      'method': 'POST',
      'path': '/api/connection/switch',
      'description': 'Switch transport without disconnecting',
      'body': {'transport': 'string (ble|wifi|cloud)'},
    },
    {
      'method': 'POST',
      'path': '/api/connection/demo',
      'description': 'Load a demo (WIDGETS_DEMO, RC_CONTROLLER, IOT_DASHBOARD)',
      'body': {'demoId': 'string'},
    },
    {
      'method': 'GET',
      'path': '/api/widgets',
      'description': 'List all widgets with current state',
    },
    {
      'method': 'GET',
      'path': '/api/widgets/<id>',
      'description': 'Get single widget state',
    },
    {
      'method': 'PUT',
      'path': '/api/widgets/<id>',
      'description': 'Set widget value',
      'body': {'values': 'int[]'},
    },
    {
      'method': 'GET',
      'path': '/api/fs/list',
      'description': 'List directory contents',
      'query': {'path': 'string (default /)'},
    },
    {
      'method': 'GET',
      'path': '/api/fs/info',
      'description': 'Get filesystem usage info',
    },
    {
      'method': 'GET',
      'path': '/api/fs/read',
      'description': 'Read file content (base64)',
      'query': {'path': 'string (required)'},
    },
    {
      'method': 'POST',
      'path': '/api/fs/write',
      'description': 'Write file',
      'body': {'path': 'string', 'data': 'string (base64)'},
    },
    {
      'method': 'POST',
      'path': '/api/fs/upload',
      'description': 'Upload file with chunked protocol',
      'body': {
        'path': 'string',
        'data': 'string (base64)',
        'chunkSize': 'int (optional)',
      },
    },
    {
      'method': 'POST',
      'path': '/api/fs/mkdir',
      'description': 'Create directory',
      'body': {'path': 'string'},
    },
    {
      'method': 'POST',
      'path': '/api/fs/delete',
      'description': 'Delete file or directory',
      'body': {'path': 'string', 'recursive': 'bool (optional)'},
    },
    {
      'method': 'POST',
      'path': '/api/fs/rename',
      'description': 'Rename or move file',
      'body': {'oldPath': 'string', 'newPath': 'string'},
    },
    {
      'method': 'POST',
      'path': '/api/fs/format',
      'description': 'Format filesystem (destructive)',
    },
    {
      'method': 'POST',
      'path': '/api/ota/upload',
      'description': 'Upload firmware via OTA',
      'body': {'data': 'string (base64)', 'eraseAll': 'bool (optional)'},
    },
    {
      'method': 'GET',
      'path': '/api/ota/progress',
      'description': 'Get OTA upload progress',
    },
    {
      'method': 'GET',
      'path': '/api/console',
      'description': 'Get console log entries',
    },
    {
      'method': 'DELETE',
      'path': '/api/console',
      'description': 'Clear console log',
    },
    {
      'method': 'GET',
      'path': '/api/settings/nvs',
      'description': 'Read device NVS config',
    },
    {
      'method': 'POST',
      'path': '/api/settings/nvs',
      'description': 'Write device NVS config',
      'body': {
        'name': 'string (optional)',
        'description': 'string (optional)',
        'password': 'string (optional)',
        'adminPassword': 'string (optional)',
      },
    },
    {
      'method': 'POST',
      'path': '/api/settings/nvs/authenticate',
      'description': 'Authenticate with device password',
      'body': {'password': 'string'},
    },
    {
      'method': 'POST',
      'path': '/api/settings/nvs/reboot',
      'description': 'Reboot device',
    },
    {
      'method': 'POST',
      'path': '/api/settings/nvs/factory-reset',
      'description': 'Erase NVS and reboot',
      'body': {'confirm': 'bool (must be true)'},
    },
    {
      'method': 'GET',
      'path': '/api/devices',
      'description': 'List all connected devices',
    },
    {
      'method': 'POST',
      'path': '/api/devices/connect',
      'description': 'Connect a new device',
      'body': {
        'id': 'string',
        'type': 'string (ble|serial|wifi|cloud)',
        'baudRate': 'int (optional)',
      },
    },
    {
      'method': 'POST',
      'path': '/api/devices/disconnect',
      'description': 'Disconnect a specific device',
      'body': {'id': 'string'},
    },
    {
      'method': 'GET',
      'path': '/api/devices/<id>',
      'description': 'Get detailed device info',
    },
    {
      'method': 'GET',
      'path': '/api/devices/<id>/widgets',
      'description': 'List widgets on a specific device',
    },
    {
      'method': 'PUT',
      'path': '/api/devices/<id>/widgets/<wid>',
      'description': 'Set widget value on a specific device',
      'body': {'values': 'int[]'},
    },
    {
      'method': 'GET',
      'path': '/api/flasher/ports',
      'description': 'List available serial ports',
    },
    {
      'method': 'POST',
      'path': '/api/flasher/scan',
      'description': 'Trigger serial port scan',
    },
    {
      'method': 'POST',
      'path': '/api/flasher/connect',
      'description': 'Connect to serial port',
      'body': {'portId': 'string'},
    },
    {
      'method': 'POST',
      'path': '/api/flasher/flash',
      'description': 'Start flashing firmware',
    },
    {
      'method': 'GET',
      'path': '/api/flasher/status',
      'description': 'Get flasher status and progress',
    },
    {
      'method': 'POST',
      'path': '/api/cloud/connect',
      'description': 'Connect to cloud relay',
      'body': {
        'host': 'string',
        'port': 'int',
        'account': 'string',
        'privateKey': 'string',
      },
    },
    {
      'method': 'GET',
      'path': '/api/cloud/devices',
      'description': 'List cloud-connected devices',
    },
    {
      'method': 'POST',
      'path': '/api/cloud/join',
      'description': 'Join a device through cloud relay',
      'body': {'device': 'string'},
    },
    {
      'method': 'POST',
      'path': '/api/cloud/disconnect',
      'description': 'Disconnect from cloud relay',
    },
    {
      'method': 'GET',
      'path': '/api/designs',
      'description': 'List all saved designs',
    },
    {
      'method': 'POST',
      'path': '/api/designs',
      'description': 'Save a design',
      'body': {
        'id': 'string',
        'name': 'string',
        'jsonContent': 'string (designer JSON)',
      },
    },
    {
      'method': 'GET',
      'path': '/api/designs/<id>/json',
      'description': 'Get design JSON config by ID',
    },
    {
      'method': 'GET',
      'path': '/api/designs/<id>/header',
      'description': 'Fetch RADIOKIT.h file (text/plain)',
    },
    {
      'method': 'DELETE',
      'path': '/api/designs/<id>',
      'description': 'Delete a design',
    },
    {
      'method': 'GET',
      'path': '/api/library/version',
      'description': 'Get Arduino library version',
    },
    {
      'method': 'GET',
      'path': '/api/library/download',
      'description': 'Download Arduino library as ZIP archive',
    },
  ];
}

/// A parsed skill document.
class SkillDoc {
  final String name;
  final String description;
  final String content;
  final String path;

  const SkillDoc({
    required this.name,
    required this.description,
    required this.content,
    required this.path,
  });

  Map<String, String> toJson() => {
        'name': name,
        'description': description,
        'content': content,
        'path': path,
      };
}
