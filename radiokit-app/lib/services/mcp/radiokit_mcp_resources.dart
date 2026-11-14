import 'dart:convert';

import '../../models/api_log_entry.dart';
import '../../providers/console_provider.dart';
import '../../providers/debug_provider.dart';
import '../../providers/designs_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/flasher_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/multi_device_provider.dart';
import '../device_fs_service.dart';
import '../docs_service.dart';
import 'mcp_protocol.dart';
import 'mcp_server.dart';

class RadioKitMcpResources {
  final DeviceProvider Function() getActiveDevice;
  final ConsoleProvider consoleProvider;
  final DebugProvider? debugProvider;
  final DocsService? docsService;
  final MultiDeviceProvider Function()? getMultiDevice;
  final HistoryProvider? historyProvider;
  final DesignsProvider? designsProvider;
  final FlasherProvider? flasherProvider;
  final String Function()? currentRouteGetter;
  final Map<String, dynamic> Function()? viewStateGetter;
  final List<ApiLogEntry> Function()? apiLogsGetter;

  RadioKitMcpResources({
    required this.getActiveDevice,
    required this.consoleProvider,
    this.debugProvider,
    this.docsService,
    this.getMultiDevice,
    this.historyProvider,
    this.designsProvider,
    this.flasherProvider,
    this.currentRouteGetter,
    this.viewStateGetter,
    this.apiLogsGetter,
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

    // 6. Connection & Handshake Diagnostics Resource
    server.registerResource(McpResource(
      uri: 'radiokit://diagnostics/connection',
      name: 'RadioKit Connection Diagnostics',
      description: 'Detailed GATT services, characteristics, MTU, CCCD status, and handshake event history.',
      mimeType: 'application/json',
      readHandler: () async {
        return jsonEncode(_deviceProvider.getConnectionDiagnostics());
      },
    ));

    // 7. Packet Snoop Resource
    server.registerResource(McpResource(
      uri: 'radiokit://packets',
      name: 'RadioKit Raw Packet Log',
      description: 'Recent raw APP (TX) and MCU (RX) packets with hex dumps, command names, and CRC status.',
      mimeType: 'application/json',
      readHandler: () async {
        final entries = debugProvider?.getRecentEntries(limit: 50).map((e) => e.toJson()).toList() ?? [];
        return jsonEncode({'packets': entries});
      },
    ));

    // 8. Managed Devices Overview Resource
    server.registerResource(McpResource(
      uri: 'radiokit://devices',
      name: 'RadioKit Managed Devices',
      description: 'All connected and configured devices in the multi-device manager.',
      mimeType: 'application/json',
      readHandler: () async {
        final multi = getMultiDevice?.call();
        final list = multi != null
            ? multi.deviceEntries.map((e) {
                final mapKey = e.$1;
                final dp = e.$2;
                final conn = dp.connectedDevice;
                return {
                  'id': conn?.id ?? mapKey,
                  'mapKey': mapKey,
                  'name': dp.configName ?? conn?.name ?? 'Device',
                  'type': conn?.currentTransport.name ?? 'unknown',
                  'isConnected': dp.isConnected,
                  'isFocused': dp == multi.focusedDevice,
                  'rssi': conn?.rssi ?? 0,
                  'hasFs': conn?.hasFs ?? false,
                };
              }).toList()
            : [
                {
                  'id': _deviceProvider.connectedDevice?.id ?? '',
                  'name': _deviceProvider.configName ?? _deviceProvider.connectedDevice?.name ?? 'Device',
                  'type': _deviceProvider.connectedDevice?.currentTransport.name ?? 'unknown',
                  'isConnected': _deviceProvider.isConnected,
                  'isFocused': true,
                  'rssi': _deviceProvider.connectedDevice?.rssi ?? 0,
                  'hasFs': _deviceProvider.connectedDevice?.hasFs ?? false,
                }
              ];
        return jsonEncode({'devices': list, 'count': list.length});
      },
    ));

    // 9. Saved Models / Paired History Resource
    server.registerResource(McpResource(
      uri: 'radiokit://models',
      name: 'RadioKit Saved Paired Models',
      description: 'Persistent list of previously paired devices and connection history.',
      mimeType: 'application/json',
      readHandler: () async {
        final models = historyProvider?.pairedDevices.map((d) => d.toJson()).toList() ?? [];
        return jsonEncode({'models': models, 'count': models.length});
      },
    ));

    // 10. Saved Designer Layouts Resource
    server.registerResource(McpResource(
      uri: 'radiokit://designs',
      name: 'RadioKit Saved UI Designs',
      description: 'Saved visual UI designer layouts and templates.',
      mimeType: 'application/json',
      readHandler: () async {
        final designs = designsProvider?.designs.map((d) => {
              'id': d.id,
              'name': d.name,
              'timestamp': d.timestamp,
              'appVersion': d.appVersion,
            }).toList() ?? [];
        return jsonEncode({'designs': designs, 'count': designs.length});
      },
    ));

    // 11. UI Session & ViewState Resource
    server.registerResource(McpResource(
      uri: 'radiokit://session',
      name: 'RadioKit UI Session State',
      description: 'Active screen route, modal sheets, and current view state.',
      mimeType: 'application/json',
      readHandler: () async {
        final route = currentRouteGetter?.call() ?? '';
        final state = viewStateGetter?.call() ?? {'route': route};
        final dp = _deviceProvider;
        return jsonEncode({
          'route': route,
          'state': state,
          if (dp.isConnected) ...{
            'activePage': dp.activePage,
            'numPages': dp.numPages,
            'pages': dp.pageNames,
          },
        });
      },
    ));

    // 12. App Execution Log Resource
    server.registerResource(McpResource(
      uri: 'radiokit://app-log',
      name: 'RadioKit App Activity Log',
      description: 'Recent in-app MCP activity log entries.',
      mimeType: 'application/json',
      readHandler: () async {
        final logs = apiLogsGetter?.call() ?? [];
        final slice = logs.length > 50 ? logs.sublist(logs.length - 50) : logs;
        return jsonEncode({
          'logs': slice.map((l) => l.toJson()).toList(),
          'total': logs.length,
        });
      },
    ));

    // 13. Hardware Flasher Log Resource
    server.registerResource(McpResource(
      uri: 'radiokit://flasher/log',
      name: 'RadioKit Hardware Flasher Log',
      description: 'Live ESP32 hardware serial flasher console logs.',
      mimeType: 'text/plain',
      readHandler: () async {
        return flasherProvider?.logEntries.join('\n') ?? '';
      },
    ));

    // Setup push notification listener on console logs
    consoleProvider.addListener(() {
      server.notifyResourceUpdated('radiokit://console');
    });

    flasherProvider?.addListener(() {
      server.notifyResourceUpdated('radiokit://flasher/log');
    });
  }
}
