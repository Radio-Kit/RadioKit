import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../../models/device_info.dart';
import '../../models/protocol.dart';
import '../../models/widget_config.dart';
import '../../providers/ble_provider.dart';
import '../../providers/console_provider.dart';
import '../../providers/designs_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/flasher_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/multi_device_provider.dart';
import '../../providers/serial_provider.dart';
import '../../providers/settings_provider.dart';
import '../../screens/designer/codegen/json_arduino_generator.dart';
import '../ble_transport.dart';
import '../device_fs_service.dart';
import '../firmware_bundle_parser.dart';
import '../websocket_service.dart';
import 'mcp_protocol.dart';
import 'mcp_server.dart';

class RadioKitMcpTools {
  final DeviceProvider Function() getActiveDevice;
  final BleProvider bleProvider;
  final SerialProvider serialProvider;
  final HistoryProvider historyProvider;
  final SettingsProvider settingsProvider;
  final ConsoleProvider consoleProvider;
  final DesignsProvider designsProvider;
  final FlasherProvider flasherProvider;
  final MultiDeviceProvider Function()? getMultiDevice;

  RadioKitMcpTools({
    required this.getActiveDevice,
    required this.bleProvider,
    required this.serialProvider,
    required this.historyProvider,
    required this.settingsProvider,
    required this.consoleProvider,
    required this.designsProvider,
    required this.flasherProvider,
    this.getMultiDevice,
  });

  DeviceProvider get _deviceProvider => getActiveDevice();

  void registerAll(McpServer server) {
    _registerConnectionTools(server);
    _registerWidgetTools(server);
    _registerFilesystemTools(server);
    _registerOtaTools(server);
    _registerNvsTools(server);
    _registerFlasherTools(server);
    _registerDesignTools(server);
  }

  // ── Connection Tools ──────────────────────────────────────────────────────

  void _registerConnectionTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_scan_devices',
      description: 'Scans for available RadioKit devices over BLE and Serial.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'transport': {
            'type': 'string',
            'enum': ['ble', 'serial', 'all'],
            'description': 'Transport type to scan for. Defaults to "all".'
          },
          'timeoutSeconds': {
            'type': 'integer',
            'description': 'Scan duration in seconds. Defaults to 3.'
          }
        },
      },
      handler: (args) async {
        final transport = args['transport'] as String? ?? 'all';
        final timeout = (args['timeoutSeconds'] as num?)?.toInt() ?? 3;

        final results = <Map<String, dynamic>>[];

        if (transport == 'ble' || transport == 'all') {
          await bleProvider.startScan();
        }
        if (transport == 'serial' || transport == 'all') {
          await serialProvider.startScan();
        }

        await Future.delayed(Duration(seconds: timeout));

        if (transport == 'ble' || transport == 'all') {
          for (final d in bleProvider.devices) {
            results.add({
              'id': d.id,
              'name': d.name,
              'type': 'ble',
              'rssi': d.rssi,
              'hasFs': d.hasFs,
            });
          }
          await bleProvider.stopScan();
        }
        if (transport == 'serial' || transport == 'all') {
          for (final p in serialProvider.ports) {
            results.add({
              'id': p.id,
              'name': p.name,
              'type': 'serial',
              'hasFs': p.hasFs,
            });
          }
          await serialProvider.stopScan();
        }

        return mcpToolSuccess(jsonEncode({'devices': results}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_connect',
      description: 'Connects to a RadioKit device via BLE, Serial, WiFi WebSocket, or Cloud.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Device ID, BLE MAC, Serial port ID, or ws:// URL.'},
          'type': {
            'type': 'string',
            'enum': ['ble', 'serial', 'wifi', 'cloud'],
            'description': 'Transport type to use for connection.'
          },
          'baudRate': {'type': 'integer', 'description': 'Baud rate for serial connections (default: 115200).'}
        },
        'required': ['id', 'type'],
      },
      handler: (args) async {
        final id = args['id'] as String?;
        final type = args['type'] as String?;
        if (id == null || type == null) {
          return mcpToolError('id and type are required');
        }

        DeviceInfo? target;
        if (type == 'ble') {
          target = bleProvider.devices.where((d) => d.id == id).firstOrNull;
          target ??= DeviceInfo(id: id, name: id, rssi: 0);
          _deviceProvider.setTransport(BleTransport(bleProvider.bleService));
        } else if (type == 'serial') {
          target = serialProvider.ports.where((p) => p.id == id).firstOrNull;
          target ??= DeviceInfo(id: id, name: id, rssi: 0);
          _deviceProvider.setTransport(serialProvider.serialService);
        } else if (type == 'wifi') {
          if (!id.startsWith('ws://') && !id.startsWith('wss://')) {
            return mcpToolError('WiFi ID must be a WebSocket URL starting with ws:// or wss://');
          }
          target = DeviceInfo(id: id, name: id, rssi: 0);
          _deviceProvider.setTransport(WebSocketService());
        } else {
          return mcpToolError('Unsupported transport type: $type');
        }

        try {
          await _deviceProvider.connectToDevice(target);
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'connected': _deviceProvider.isConnected,
            'device': target.name,
            'id': target.id,
            'type': type,
          }));
        } catch (e) {
          return mcpToolError('Connection failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_disconnect',
      description: 'Disconnects from the active RadioKit device.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        await _deviceProvider.disconnect();
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Disconnected'}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_connection_status',
      description: 'Returns connection status, active device info, RSSI, and latency.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        final isConnected = _deviceProvider.isConnected;
        final device = _deviceProvider.connectedDevice;
        return mcpToolSuccess(jsonEncode({
          'connected': isConnected,
          'device': device != null
              ? {
                  'id': device.id,
                  'name': device.displayName,
                  'configName': _deviceProvider.configName,
                  'type': device.currentTransport.name,
                  'hasFs': _deviceProvider.hasFs,
                  'hasOta': _deviceProvider.hasOta,
                }
              : null,
          'rssi': _deviceProvider.rssi,
          'latencyMs': _deviceProvider.latencyMs,
        }));
      },
    ));
  }

  // ── Widget Tools ──────────────────────────────────────────────────────────

  void _registerWidgetTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_list_widgets',
      description: 'Lists all widgets and their current values from the connected device.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (!_deviceProvider.isConnected) {
          return mcpToolError('Not connected to a device');
        }
        final widgets = _deviceProvider.widgets.map((w) => _widgetToJson(w)).toList();
        return mcpToolSuccess(jsonEncode({'widgets': widgets}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_widget',
      description: 'Gets state and properties of a specific widget by its numeric ID.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'widgetId': {'type': 'integer', 'description': 'Numeric ID of the widget.'}
        },
        'required': ['widgetId'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected) {
          return mcpToolError('Not connected to a device');
        }
        final wid = (args['widgetId'] as num?)?.toInt();
        if (wid == null) return mcpToolError('widgetId is required');

        final widget = _deviceProvider.widgets.where((w) => w.widgetId == wid).firstOrNull;
        if (widget == null) return mcpToolError('Widget $wid not found');

        return mcpToolSuccess(jsonEncode({'widget': _widgetToJson(widget)}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_set_widget',
      description: 'Sets input values for a widget (e.g. button state, slider value, joystick [x, y]).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'widgetId': {'type': 'integer', 'description': 'Numeric ID of the widget.'},
          'values': {
            'type': 'array',
            'items': {'type': 'number'},
            'description': 'Array of values to set (e.g. [1] for button on, [50] for slider, [0, 100] for joystick).'
          }
        },
        'required': ['widgetId', 'values'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected) {
          return mcpToolError('Not connected to a device');
        }
        final wid = (args['widgetId'] as num?)?.toInt();
        final rawValues = args['values'] as List<dynamic>?;

        if (wid == null || rawValues == null || rawValues.isEmpty) {
          return mcpToolError('widgetId and values array are required');
        }

        final widget = _deviceProvider.widgets.where((w) => w.widgetId == wid).firstOrNull;
        if (widget == null) return mcpToolError('Widget $wid not found');
        if (!widget.hasInput) return mcpToolError('Widget $wid is output-only');

        final intValues = rawValues.map((v) => (v as num).toInt()).toList();

        try {
          await _deviceProvider.setInputValue(wid, intValues);
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'widgetId': wid,
            'values': intValues,
          }));
        } catch (e) {
          return mcpToolError('Failed to set widget value: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_pages',
      description: 'Returns the list of available pages and current active page.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        return mcpToolSuccess(jsonEncode({
          'activePage': _deviceProvider.activePage,
          'numPages': _deviceProvider.numPages,
          'pages': _deviceProvider.pageNames,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_set_page',
      description: 'Switches the active UI page on the device and companion app.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'page': {'type': 'integer', 'description': 'Page index to activate.'}
        },
        'required': ['page'],
      },
      handler: (args) async {
        final page = (args['page'] as num?)?.toInt();
        if (page == null) return mcpToolError('page parameter is required');

        await _deviceProvider.sendSetPage(page);
        return mcpToolSuccess(jsonEncode({'ok': true, 'page': page}));
      },
    ));
  }

  // ── Filesystem Tools ──────────────────────────────────────────────────────

  void _registerFilesystemTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_fs_list',
      description: 'Lists files and directories on the connected device LittleFS filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Directory path to list (default: "/").'}
        }
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String? ?? '/';
        final fsService = createDeviceFsService(_deviceProvider);
        try {
          final entries = await fsService.listDir(path);
          return mcpToolSuccess(jsonEncode({
            'path': path,
            'entries': entries
                .map((e) => {
                      'name': e.name,
                      'type': e.isDirectory ? 'directory' : 'file',
                      'size': e.size,
                    })
                .toList(),
          }));
        } catch (e) {
          return mcpToolError('Failed to list directory: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_info',
      description: 'Returns storage usage statistics (total, used, and free bytes) of the device filesystem.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final fsService = createDeviceFsService(_deviceProvider);
        try {
          final info = await fsService.getInfo();
          if (info == null) return mcpToolError('Failed to retrieve FS info');
          return mcpToolSuccess(jsonEncode({
            'totalBytes': info.totalBytes,
            'usedBytes': info.usedBytes,
            'freeBytes': info.freeBytes,
            'blockSize': info.blockSize,
          }));
        } catch (e) {
          return mcpToolError('FS info error: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_read',
      description: 'Reads the contents of a file from the device LittleFS filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Path of the file to read.'},
          'asBase64': {'type': 'boolean', 'description': 'Return as base64 instead of utf-8 text. Default false.'}
        },
        'required': ['path'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        if (path == null) return mcpToolError('path is required');

        final asBase64 = args['asBase64'] as bool? ?? false;
        final fsService = createDeviceFsService(_deviceProvider);
        _deviceProvider.setFsBusy(true);

        try {
          final bytes = await fsService.readFile(path);
          if (bytes == null) return mcpToolError('File not found or empty: $path');

          final content = asBase64 ? base64Encode(bytes) : utf8.decode(bytes, allowMalformed: true);
          return mcpToolSuccess(jsonEncode({
            'path': path,
            'size': bytes.length,
            'content': content,
            'isBase64': asBase64,
          }));
        } catch (e) {
          return mcpToolError('Failed to read file: $e');
        } finally {
          _deviceProvider.setFsBusy(false);
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_write',
      description: 'Writes data to a file on the device LittleFS filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Target file path.'},
          'data': {'type': 'string', 'description': 'Content string to write (utf-8 or base64).'},
          'isBase64': {'type': 'boolean', 'description': 'Whether data is base64 encoded. Default false.'}
        },
        'required': ['path', 'data'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        final dataStr = args['data'] as String?;
        if (path == null || dataStr == null) {
          return mcpToolError('path and data are required');
        }

        final isBase64 = args['isBase64'] as bool? ?? false;
        List<int> bytes;
        try {
          bytes = isBase64 ? base64Decode(dataStr) : utf8.encode(dataStr);
        } catch (e) {
          return mcpToolError('Failed to decode data: $e');
        }

        final fsService = createDeviceFsService(_deviceProvider);
        _deviceProvider.setFsBusy(true);
        try {
          await fsService.writeFile(path, Uint8List.fromList(bytes));
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'path': path,
            'bytesWritten': bytes.length,
          }));
        } catch (e) {
          return mcpToolError('Failed to write file: $e');
        } finally {
          _deviceProvider.setFsBusy(false);
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_delete',
      description: 'Deletes a file or directory from the device filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Path to delete.'},
          'recursive': {'type': 'boolean', 'description': 'Recursively delete directory contents.'}
        },
        'required': ['path'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        if (path == null) return mcpToolError('path is required');

        final fsService = createDeviceFsService(_deviceProvider);
        _deviceProvider.setFsBusy(true);
        try {
          await fsService.delete(path);
          return mcpToolSuccess(jsonEncode({'ok': true, 'deleted': path}));
        } catch (e) {
          return mcpToolError('Delete failed: $e');
        } finally {
          _deviceProvider.setFsBusy(false);
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_mkdir',
      description: 'Creates a directory on the device LittleFS filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Directory path to create.'}
        },
        'required': ['path'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        if (path == null) return mcpToolError('path is required');

        final fsService = createDeviceFsService(_deviceProvider);
        try {
          await fsService.mkdir(path);
          return mcpToolSuccess(jsonEncode({'ok': true, 'created': path}));
        } catch (e) {
          return mcpToolError('Failed to create directory: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_format',
      description: 'Formats the device LittleFS filesystem, erasing all data.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final fsService = createDeviceFsService(_deviceProvider);
        try {
          await fsService.format();
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Filesystem formatted'}));
        } catch (e) {
          return mcpToolError('Format failed: $e');
        }
      },
    ));
  }

  // ── OTA Tools ─────────────────────────────────────────────────────────────

  void _registerOtaTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_ota_upload',
      description: 'Uploads binary firmware to the connected MCU via Over-The-Air (OTA) update.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'firmwareBase64': {'type': 'string', 'description': 'Base64-encoded firmware binary or .zip bundle.'},
          'fileName': {'type': 'string', 'description': 'Optional filename (e.g. firmware.zip or app.bin).'},
          'eraseAll': {'type': 'boolean', 'description': 'Erase flash before OTA upload (default: false).'}
        },
        'required': ['firmwareBase64'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected || !_deviceProvider.hasOta) {
          return mcpToolError('Not connected or device does not support OTA');
        }

        final b64 = args['firmwareBase64'] as String?;
        if (b64 == null) return mcpToolError('firmwareBase64 is required');

        final eraseAll = args['eraseAll'] as bool? ?? false;
        final fileName = args['fileName'] as String?;

        List<int> bytes;
        try {
          bytes = base64Decode(b64);
        } catch (e) {
          return mcpToolError('Invalid base64 payload: $e');
        }

        // Check if payload is a firmware bundle zip
        if ((fileName != null && fileName.toLowerCase().endsWith('.zip')) ||
            (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B)) {
          try {
            final bundle = FirmwareBundleParser.parseZip(
              Uint8List.fromList(bytes),
              fileName: fileName ?? 'firmware.zip',
            );
            final appPart = bundle.appPart;
            if (appPart == null) {
              return mcpToolError('No application firmware partition found in bundle');
            }
            bytes = appPart.bytes;
          } catch (e) {
            return mcpToolError('Failed to parse zip bundle: $e');
          }
        }

        try {
          await _deviceProvider.uploadFirmware(
            bytes,
            eraseAll: eraseAll,
            onProgress: (received, total) {
              server.notifyProgress(
                progressToken: 'ota',
                progress: received.toDouble(),
                total: total.toDouble(),
              );
            },
          );
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'size': bytes.length,
            'message': 'Firmware uploaded successfully — MCU is rebooting',
          }));
        } catch (e) {
          return mcpToolError('OTA upload failed: $e');
        }
      },
    ));
  }

  // ── NVS & System Tools ────────────────────────────────────────────────────

  void _registerNvsTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_nvs_get',
      description: 'Reads device Non-Volatile Storage (NVS) configuration and authentication state.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (!_deviceProvider.isConnected) return mcpToolError('Not connected to a device');
        return mcpToolSuccess(jsonEncode({
          'name': _deviceProvider.configName ?? '',
          'description': _deviceProvider.description ?? '',
          'hasPassword': _deviceProvider.hasPassword,
          'hasAdminPassword': _deviceProvider.hasAdminPassword,
          'isAuthenticated': _deviceProvider.isAuthenticated,
          'isAdminMode': _deviceProvider.isAdminMode,
          'isUserMode': _deviceProvider.isUserMode,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_nvs_set',
      description: 'Writes device configuration values to NVS (name, description, passwords).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Device name.'},
          'description': {'type': 'string', 'description': 'Device description.'},
          'password': {'type': 'string', 'description': 'User connection password.'},
          'adminPassword': {'type': 'string', 'description': 'Admin password.'},
          'icon': {'type': 'string', 'description': 'Device icon identifier.'}
        },
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected) return mcpToolError('Not connected to a device');
        final name = args['name'] as String?;
        final description = args['description'] as String?;
        final password = args['password'] as String?;
        final adminPassword = args['adminPassword'] as String?;
        final icon = args['icon'] as String?;

        try {
          final ok = await _deviceProvider.sendSetConf(
            name: name,
            description: description,
            password: password,
            adminPassword: adminPassword,
            icon: icon,
          );
          return mcpToolSuccess(jsonEncode({'ok': ok, 'message': 'NVS configuration saved'}));
        } catch (e) {
          return mcpToolError('Failed to save NVS config: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_nvs_authenticate',
      description: 'Authenticates user or admin session password with the device.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'password': {'type': 'string', 'description': 'Device connection or admin password.'}
        },
        'required': ['password'],
      },
      handler: (args) async {
        if (!_deviceProvider.isConnected) return mcpToolError('Not connected to a device');
        final pwd = args['password'] as String?;
        if (pwd == null) return mcpToolError('password is required');

        final ok = await _deviceProvider.authenticate(pwd);
        return mcpToolSuccess(jsonEncode({
          'ok': ok,
          'isAuthenticated': _deviceProvider.isAuthenticated,
          'isAdminMode': _deviceProvider.isAdminMode,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_reboot',
      description: 'Sends a reboot command to the connected MCU.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (!_deviceProvider.isConnected) return mcpToolError('Not connected to a device');
        await _deviceProvider.sendReboot();
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Reboot command sent'}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_factory_reset',
      description: 'Erases device configuration in NVS and reboots.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (!_deviceProvider.isConnected) return mcpToolError('Not connected to a device');
        await _deviceProvider.sendFactoryReset();
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Factory reset executed'}));
      },
    ));
  }

  // ── Flasher Tools ─────────────────────────────────────────────────────────

  void _registerFlasherTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_flasher_scan',
      description: 'Scans for USB serial ports available for direct hardware flashing.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        await flasherProvider.scanPorts();
        final ports = flasherProvider.availablePorts;
        return mcpToolSuccess(jsonEncode({
          'ports': ports.map((p) => {
            'id': p.id,
            'name': p.name,
            'description': p.description,
          }).toList(),
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_flasher_flash',
      description: 'Flashes firmware bundle to an ESP32 microcontroller connected via USB serial.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'portId': {'type': 'string', 'description': 'Serial port ID from flasher scan.'},
          'firmwareBase64': {'type': 'string', 'description': 'Base64 firmware bundle zip.'},
        },
        'required': ['portId', 'firmwareBase64'],
      },
      handler: (args) async {
        final portId = args['portId'] as String?;
        final b64 = args['firmwareBase64'] as String?;
        if (portId == null || b64 == null) {
          return mcpToolError('portId and firmwareBase64 are required');
        }

        List<int> bytes;
        try {
          bytes = base64Decode(b64);
        } catch (e) {
          return mcpToolError('Invalid base64 payload: $e');
        }

        try {
          flasherProvider.setSelectedBundleDirect(
            bytes: Uint8List.fromList(bytes),
            name: 'firmware.zip',
          );
          await flasherProvider.connect(portId);
          flasherProvider.startFlashing();
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'port': portId,
            'message': 'Flashing started',
          }));
        } catch (e) {
          return mcpToolError('Flashing error: $e');
        }
      },
    ));
  }

  // ── Design & Codegen Tools ────────────────────────────────────────────────

  void _registerDesignTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_get_design',
      description: 'Returns the full designer JSON configuration for a specific UI design.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'designId': {'type': 'string', 'description': 'Identifier of the saved design.'}
        },
        'required': ['designId'],
      },
      handler: (args) async {
        final id = args['designId'] as String?;
        if (id == null) return mcpToolError('designId is required');

        final design = designsProvider.designs.where((d) => d.id == id).firstOrNull;
        if (design == null) return mcpToolError('Design $id not found');

        return mcpToolSuccess(jsonEncode({
          'id': design.id,
          'name': design.name,
          'jsonContent': design.jsonContent,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_generate_design_header',
      description: 'Generates the C++ Arduino header (RADIOKIT.h) for a design.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'designId': {'type': 'string', 'description': 'Identifier of the saved design.'}
        },
        'required': ['designId'],
      },
      handler: (args) async {
        final id = args['designId'] as String?;
        if (id == null) return mcpToolError('designId is required');

        final design = designsProvider.designs.where((d) => d.id == id).firstOrNull;
        if (design == null) return mcpToolError('Design $id not found');

        final jsonContent = design.jsonContent;
        if (jsonContent == null) {
          return mcpToolError('Design $id does not contain JSON layout configuration');
        }

        try {
          final jsonMap = jsonDecode(jsonContent) as Map<String, dynamic>;
          final headerText = JsonArduinoGenerator.generateFullHeader(jsonMap);
          return mcpToolSuccess(headerText);
        } catch (e) {
          return mcpToolError('Failed to generate Arduino header: $e');
        }
      },
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _widgetToJson(WidgetConfig w) {
    final state = _deviceProvider.widgetState;
    final inputs = state?.inputValues[w.widgetId];
    final outputs = state?.outputValues[w.widgetId];

    Map<String, dynamic> stateJson = {};
    if (w.hasOutput) {
      if (w.typeId == kWidgetText || w.typeId == kWidgetTelemetry) {
        stateJson['text'] = outputs is String ? outputs : (outputs?.toString() ?? '');
      } else if (w.typeId == kWidgetLed) {
        final arr = outputs is List ? outputs as List<int> : <int>[0, 0, 0, 0, 0];
        stateJson['values'] = arr;
        stateJson['value'] = arr.isNotEmpty ? arr[0] : 0;
      } else {
        stateJson['value'] = outputs is int ? outputs : 0;
      }
    }
    if (w.hasInput) {
      if (w.typeId == kWidgetJoystick) {
        stateJson['values'] = inputs ?? [0, 0];
      } else {
        stateJson['value'] = inputs?.isNotEmpty == true ? inputs![0] : 0;
      }
    }

    return {
      'widgetId': w.widgetId,
      'type': _widgetTypeName(w.typeId),
      'name': w.label.isNotEmpty ? w.label : 'widget_${w.widgetId}',
      'label': w.label,
      'hidden': w.hidden,
      'hasOutput': w.hasOutput,
      'hasInput': w.hasInput,
      'state': stateJson,
      'x': w.x,
      'y': w.y,
      'rotation': w.rotationDegrees,
    };
  }

  String _widgetTypeName(int typeId) {
    switch (typeId) {
      case kWidgetButton: return 'button';
      case kWidgetSlider: return 'slider';
      case kWidgetKnob: return 'knob';
      case kWidgetJoystick: return 'joystick';
      case kWidgetLed: return 'led';
      case kWidgetText: return 'text';
      case kWidgetMultiple: return 'multiple';
      case kWidgetTelemetry: return 'telemetry';
      default: return 'unknown';
    }
  }
}
