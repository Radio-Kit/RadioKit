import 'dart:convert';

import '../../providers/console_provider.dart';
import '../../providers/device_provider.dart';
import '../device_fs_service.dart';
import '../docs_service.dart';
import 'mcp_protocol.dart';
import 'mcp_server.dart';

class RadioKitMcpResources {
  final DeviceProvider Function() getActiveDevice;
  final ConsoleProvider consoleProvider;
  final DocsService? docsService;

  RadioKitMcpResources({
    required this.getActiveDevice,
    required this.consoleProvider,
    this.docsService,
  });

  DeviceProvider get _deviceProvider => getActiveDevice();

  void registerAll(McpServer server) {
    // 1. Console Log Resource
    server.registerResource(McpResource(
      uri: 'radiokit://console',
      name: 'RadioKit Device Console',
      description: 'Live MCU serial console logs and print frames.',
      mimeType: 'text/plain',
      readHandler: () async {
        return consoleProvider.entries
            .map((e) => '[${e.timeLabel}] ${e.message}')
            .join('\n');
      },
    ));

    // 2. Widget Tree Resource
    server.registerResource(McpResource(
      uri: 'radiokit://widgets',
      name: 'RadioKit Widget Tree',
      description: 'Active widget layout, hierarchy, and current state values.',
      mimeType: 'application/json',
      readHandler: () async {
        final widgets = _deviceProvider.widgets.map((w) => {
              'widgetId': w.widgetId,
              'label': w.label,
              'hasInput': w.hasInput,
              'hasOutput': w.hasOutput,
            }).toList();
        return jsonEncode({'widgets': widgets});
      },
    ));

    // 3. Filesystem Root Resource
    server.registerResource(McpResource(
      uri: 'radiokit://fs',
      name: 'RadioKit Device Filesystem',
      description: 'Listing of files and directories on the LittleFS partition.',
      mimeType: 'application/json',
      readHandler: () async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return jsonEncode({'error': 'Device disconnected or no filesystem'});
        }
        final fs = createDeviceFsService(_deviceProvider);
        final entries = await fs.listDir('/');
        return jsonEncode({
          'entries': entries
              .map((e) => {
                    'name': e.name,
                    'type': e.isDirectory ? 'directory' : 'file',
                    'size': e.size,
                  })
              .toList(),
        });
      },
    ));

    // 4. Docs Index Resource
    server.registerResource(McpResource(
      uri: 'radiokit://docs',
      name: 'RadioKit Firmware & Agent Skills Documentation',
      description: 'Index of available RadioKit developer skills and API reference.',
      mimeType: 'application/json',
      readHandler: () async {
        if (docsService == null) return jsonEncode({'skills': []});
        return jsonEncode({'skills': docsService!.getSkillsIndex()});
      },
    ));

    // 5. Skill Documentation Template Resource
    server.registerResource(McpResource(
      uri: 'radiokit://docs/*',
      name: 'RadioKit Skill Document',
      description: 'Full markdown content of a specific RadioKit skill.',
      mimeType: 'text/markdown',
      readHandler: () async {
        return docsService?.getSkillContent('radiokit-firmware')?.content ?? 'Documentation not available';
      },
    ));

    // Setup push notification listener on console logs
    consoleProvider.addListener(() {
      server.notifyResourceUpdated('radiokit://console');
    });

    // Setup push notification listener on device state changes
    _deviceProvider.addListener(() {
      server.notifyResourceUpdated('radiokit://widgets');
    });
  }
}
