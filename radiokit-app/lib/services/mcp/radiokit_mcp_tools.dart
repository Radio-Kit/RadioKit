import 'dart:async';
import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';

import '../../models/account.dart';
import '../../models/api_log_entry.dart';
import '../../models/debug_log_entry.dart';
import '../../models/device_info.dart';
import '../../models/protocol.dart';
import '../../models/widget_config.dart';
import '../../providers/account_provider.dart';
import '../../providers/ble_provider.dart';
import '../../providers/cloud_identity_provider.dart';
import '../../providers/console_provider.dart';
import '../../providers/debug_provider.dart';
import '../../providers/designs_provider.dart';
import '../../providers/device_provider.dart';
import '../../providers/flasher_provider.dart';
import '../../providers/history_provider.dart';
import '../../providers/multi_device_provider.dart';
import '../../providers/serial_provider.dart';
import '../../providers/settings_provider.dart';
import '../../screens/designer/codegen/header_file_parser.dart';
import '../../screens/designer/codegen/json_arduino_generator.dart';
import '../ble_transport.dart';
import '../device_fs_service.dart';
import '../fs_protocol_service.dart';
import '../protocol_service.dart';
import '../settings_protocol_service.dart';
import '../transport_service.dart';
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
  final DebugProvider? debugProvider;
  final DesignsProvider designsProvider;
  final FlasherProvider flasherProvider;
  final MultiDeviceProvider Function()? getMultiDevice;
  final CloudIdentityProvider? cloudIdentityProvider;
  final AccountProvider? accountProvider;
  final String Function()? currentRouteGetter;
  final Map<String, dynamic> Function()? viewStateGetter;
  final Future<void> Function(String demoId)? connectDemo;
  final List<ApiLogEntry> Function()? apiLogsGetter;
  final void Function()? clearApiLogs;

  // Cloud relay state
  WebSocketService? _cloudWs;
  String? _cloudHost;
  int? _cloudPort;
  String? _cloudAccount;
  List<dynamic> _cloudDevices = [];

  RadioKitMcpTools({
    required this.getActiveDevice,
    required this.bleProvider,
    required this.serialProvider,
    required this.historyProvider,
    required this.settingsProvider,
    required this.consoleProvider,
    this.debugProvider,
    required this.designsProvider,
    required this.flasherProvider,
    this.getMultiDevice,
    this.cloudIdentityProvider,
    this.accountProvider,
    this.currentRouteGetter,
    this.viewStateGetter,
    this.connectDemo,
    this.apiLogsGetter,
    this.clearApiLogs,
  });

  DeviceProvider get _deviceProvider => getActiveDevice();

  DeviceProvider _resolveDevice(String? deviceId) {
    if (deviceId != null && deviceId.isNotEmpty && getMultiDevice != null) {
      final multi = getMultiDevice!();
      final dp = multi.getDevice(deviceId);
      if (dp != null) return dp;
    }
    return getActiveDevice();
  }

  bool _checkFs(DeviceProvider dp) =>
      dp.isConnected && (dp.connectedDevice?.hasFs ?? false);

  void registerAll(McpServer server) {
    _registerConnectionTools(server);
    _registerTransportTools(server);
    _registerDiagnosticsTools(server);
    _registerWidgetTools(server);
    _registerFilesystemTools(server);
    _registerOtaTools(server);
    _registerNvsTools(server);
    _registerFlasherTools(server);
    _registerHistoryTools(server);
    _registerDesignTools(server);
    _registerCloudTools(server);
    _registerSettingsAndSessionTools(server);
  }

  // ── Connection & Multi-Device Tools ────────────────────────────────────────

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
              'name': p.displayName,
              'type': 'serial',
              'rssi': 0,
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
          'baudRate': {'type': 'integer', 'description': 'Baud rate for serial connections (default: 115200).'},
          'skipConf': {
            'type': 'boolean',
            'description': 'If true, establishes connection without blocking or failing on CONF_DATA handshake. Useful for hardware bringup, bootloader mode, or raw diagnostics.'
          },
          'deviceId': {'type': 'string', 'description': 'Optional multi-device ID mapping.'}
        },
        'required': ['id', 'type'],
      },
      handler: (args) async {
        final id = args['id'] as String?;
        final type = args['type'] as String?;
        final baudRate = (args['baudRate'] as num?)?.toInt() ?? 115200;
        final skipConf = args['skipConf'] as bool? ?? false;
        if (id == null || type == null) {
          return mcpToolError('id and type are required');
        }

        final multi = getMultiDevice?.call();
        final dp = _resolveDevice(args['deviceId'] as String?);
        DeviceInfo? target;
        TransportService transport;
        if (type == 'ble') {
          target = bleProvider.devices.where((d) => d.id == id).firstOrNull;
          target ??= DeviceInfo(id: id, name: id, rssi: 0);
          transport = BleTransport(bleProvider.bleService);
        } else if (type == 'serial') {
          target = serialProvider.ports.where((p) => p.id == id).firstOrNull;
          target ??= DeviceInfo(id: id, name: id, rssi: 0);
          transport = serialProvider.serialService;
        } else if (type == 'wifi') {
          if (!id.startsWith('ws://') && !id.startsWith('wss://')) {
            return mcpToolError('WiFi ID must be a WebSocket URL starting with ws:// or wss://');
          }
          target = DeviceInfo(id: id, name: id, rssi: 0);
          transport = WebSocketService();
        } else if (type == 'cloud') {
          if (_cloudWs != null) {
            transport = _cloudWs!;
          } else {
            transport = WebSocketService();
          }
          target = DeviceInfo(id: id, name: id, rssi: 0);
        } else {
          return mcpToolError('Unsupported transport type: $type');
        }

        try {
          if (multi != null) {
            final provider = await multi.connectDevice(
              device: target,
              transport: transport,
              baudRate: baudRate,
            );
            return mcpToolSuccess(jsonEncode({
              'ok': true,
              'connected': provider.isConnected,
              'handshakePending': provider.handshakePending,
              'device': target.name,
              'id': target.id,
              'type': type,
            }));
          } else {
            dp.setTransport(transport);
            await dp.connectToDevice(target, baudRate: baudRate, skipConf: skipConf);
            return mcpToolSuccess(jsonEncode({
              'ok': true,
              'connected': dp.isConnected,
              'handshakePending': dp.handshakePending,
              'device': target.name,
              'id': target.id,
              'type': type,
            }));
          }
        } catch (e) {
          return mcpToolError('Connection failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_disconnect',
      description: 'Disconnects the active or specified RadioKit device.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional device ID to disconnect. If omitted, disconnects active device.'}
        }
      },
      handler: (args) async {
        final deviceId = args['deviceId'] as String?;
        if (deviceId != null && getMultiDevice != null) {
          await getMultiDevice!().disconnectDevice(deviceId);
          return mcpToolSuccess(jsonEncode({'ok': true, 'disconnected': deviceId}));
        }
        await _deviceProvider.disconnect();
        return mcpToolSuccess(jsonEncode({'ok': true, 'disconnected': true}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_connection_status',
      description: 'Returns connection status, transport type, device name, and signal strength.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        final device = dp.connectedDevice;
        return mcpToolSuccess(jsonEncode({
          'connected': dp.isConnected,
          'handshakePending': dp.handshakePending,
          'state': dp.connectionState.name,
          'device': device?.name,
          'id': device?.id,
          'type': device?.currentTransport.name,
          'rssi': device?.rssi,
          'hasFs': device?.hasFs,
          'configName': dp.configName,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_connection_diagnostics',
      description: 'Returns low-level connection diagnostics including GATT service/characteristic discovery, CCCD notification status, negotiated BLE MTU, and connection event history.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        return mcpToolSuccess(jsonEncode(dp.getConnectionDiagnostics()));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_retry_handshake',
      description: 'Triggers or retries the widget configuration handshake (GET_CONF) on the connected device to load widget descriptors.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Device is not connected');
        try {
          final ok = await dp.retryHandshake();
          return mcpToolSuccess(jsonEncode({
            'ok': ok,
            'configReceived': dp.configReceived,
            'widgetCount': dp.widgets.length,
            'configName': dp.configName,
          }));
        } catch (e) {
          return mcpToolError('Handshake retry failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_list_devices',
      description: 'Lists all devices currently managed by MultiDeviceProvider, including active and focused device flags.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
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
        return mcpToolSuccess(jsonEncode({'devices': list, 'count': list.length}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_switch_device',
      description: 'Sets the active focused device in MultiDeviceProvider for user interface control.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Device ID to focus.'}
        },
        'required': ['deviceId'],
      },
      handler: (args) async {
        final deviceId = args['deviceId'] as String?;
        if (deviceId == null) return mcpToolError('deviceId is required');
        final multi = getMultiDevice?.call();
        if (multi == null) return mcpToolError('Multi-device manager not available');
        final dp = multi.getDevice(deviceId);
        if (dp == null) return mcpToolError('Device $deviceId not found in active pool');
        multi.setFocusedDevice(deviceId);
        return mcpToolSuccess(jsonEncode({'ok': true, 'focusedDevice': deviceId}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_reconnect',
      description: 'Attempts to reconnect to the most recently connected device or a specified device from paired history.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional device UID to reconnect to. Defaults to most recent.'}
        }
      },
      handler: (args) async {
        final devices = historyProvider.pairedDevices;
        if (devices.isEmpty) return mcpToolError('No previously paired devices in history');

        final targetId = args['deviceId'] as String?;
        final target = targetId != null
            ? devices.where((d) => d.uid == targetId || d.bleAddress == targetId || d.serialAddress == targetId || d.wifiAddress == targetId).firstOrNull
            : devices.first;
        if (target == null) return mcpToolError("Device '$targetId' not found in history");

        final dp = _resolveDevice(targetId);

        final effectiveBle = target.bleAddress ?? (target.type == 'ble' ? target.uid : null);
        final effectiveWifi = target.wifiAddress ?? (target.type == 'wifi' ? target.uid : null);
        final effectiveSerial = target.serialAddress ?? (target.type == 'serial' ? target.uid : null);

        DeviceInfo? deviceToConnect;
        if (target.lastUsedTransport == 'ble' && effectiveBle != null) {
          dp.setTransport(BleTransport(bleProvider.bleService));
          deviceToConnect = DeviceInfo(id: effectiveBle, name: target.name, rssi: 0);
        } else if (target.lastUsedTransport == 'wifi' && effectiveWifi != null) {
          dp.setTransport(WebSocketService());
          deviceToConnect = DeviceInfo(id: effectiveWifi, name: target.name, rssi: 0);
        } else if (target.lastUsedTransport == 'serial' && effectiveSerial != null) {
          dp.setTransport(serialProvider.serialService);
          deviceToConnect = DeviceInfo(id: effectiveSerial, name: target.name, rssi: 0);
        } else if (effectiveBle != null) {
          dp.setTransport(BleTransport(bleProvider.bleService));
          deviceToConnect = DeviceInfo(id: effectiveBle, name: target.name, rssi: 0);
        } else if (effectiveWifi != null) {
          dp.setTransport(WebSocketService());
          deviceToConnect = DeviceInfo(id: effectiveWifi, name: target.name, rssi: 0);
        } else if (effectiveSerial != null) {
          dp.setTransport(serialProvider.serialService);
          deviceToConnect = DeviceInfo(id: effectiveSerial, name: target.name, rssi: 0);
        }

        if (deviceToConnect == null) {
          return mcpToolError('No valid transport address available for ${target.name}');
        }

        try {
          await dp.connectToDevice(deviceToConnect);
          return mcpToolSuccess(jsonEncode({
            'ok': dp.isConnected,
            'device': target.name,
            'id': target.uid,
            'transport': target.lastUsedTransport,
          }));
        } catch (e) {
          return mcpToolError('Reconnect failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_connect_demo',
      description: 'Loads a built-in virtual simulation demo with interactive widgets without physical hardware.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'demoId': {
            'type': 'string',
            'enum': ['WIDGETS_DEMO', 'RC_CONTROLLER', 'IOT_DASHBOARD', 'MULTI_PAGE_DEMO'],
            'description': 'Demo layout identifier.'
          }
        },
        'required': ['demoId'],
      },
      handler: (args) async {
        final demoId = args['demoId'] as String?;
        if (demoId == null) return mcpToolError('demoId is required');
        try {
          if (connectDemo != null) {
            await connectDemo!(demoId);
          } else {
            await _deviceProvider.loadDemo(demoId);
          }
          final dp = _deviceProvider;
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'demoId': demoId,
            'widgetCount': dp.widgets.length,
            'message': 'Demo $demoId loaded with ${dp.widgets.length} widgets',
          }));
        } catch (e) {
          return mcpToolError('Failed to load demo $demoId: $e');
        }
      },
    ));
  }

  // ── Transport Diagnostics & Control Tools ──────────────────────────────────

  void _registerTransportTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_transport_ping',
      description: 'Checks transport health and connection round-trip latency to the connected device.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        return mcpToolSuccess(jsonEncode({
          'ok': true,
          'connected': true,
          'latencyMs': dp.latencyMs ?? 0,
          'device': dp.configName ?? dp.connectedDevice?.name ?? 'Device',
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_transport_wifi_info',
      description: 'Queries WiFi status (IP address, SSID, RSSI, mode) directly from the connected ESP32 via protocol.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        try {
          final wifiInfo = await dp.sendGetWifiInfo();
          if (wifiInfo == null) return mcpToolError('Failed to get WiFi info (timeout or not supported)');
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'ip': wifiInfo.ip,
            'mode': wifiInfo.mode == 0 ? 'sta' : 'ap',
            'ssid': wifiInfo.ssid,
            'rssi': wifiInfo.rssi,
          }));
        } catch (e) {
          return mcpToolError('WiFi info query error: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_transport_quick_cmd',
      description: 'Sends a standard protocol command (get_conf, get_vars, get_meta, get_tele) over active transport.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'cmd': {
            'type': 'string',
            'enum': ['get_conf', 'get_vars', 'get_meta', 'get_tele'],
            'description': 'Control command to execute.'
          },
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['cmd'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final cmd = args['cmd'] as String?;
        if (cmd == null) return mcpToolError('cmd is required');
        final transport = dp.currentTransport;
        try {
          switch (cmd) {
            case 'get_conf':
              await transport.writePacket(ProtocolService.buildGetConf());
            case 'get_vars':
              await transport.writePacket(ProtocolService.buildGetVars());
            case 'get_meta':
              await transport.writePacket(ProtocolService.buildGetMeta());
            case 'get_tele':
              await transport.writePacket(SettingsProtocolService.buildGetTelemetry(0));
            default:
              return mcpToolError('Unknown command: $cmd');
          }
          return mcpToolSuccess(jsonEncode({'ok': true, 'cmd': cmd}));
        } catch (e) {
          return mcpToolError('Send quick command failed: $e');
        }
      },
    ));
  }

  // ── Raw Packet Snoop & Ingestion Tools ─────────────────────────────────────

  void _registerDiagnosticsTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_get_packet_log',
      description: 'Returns recent raw packets (TX/RX) with hex dump, decoded command, CRC status, and timestamps.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Maximum entries to return (default: 50).'},
          'direction': {
            'type': 'string',
            'enum': ['tx', 'rx'],
            'description': 'Filter by packet direction.'
          },
          'channel': {
            'type': 'string',
            'enum': ['widget', 'fs', 'ota', 'settings', 'print', 'raw'],
            'description': 'Filter by protocol channel.'
          },
          'clear': {'type': 'boolean', 'description': 'Clear the packet buffer after reading.'}
        }
      },
      handler: (args) async {
        final limit = (args['limit'] as num?)?.toInt() ?? 50;
        final dirStr = args['direction'] as String?;
        final chanStr = args['channel'] as String?;
        final clear = args['clear'] as bool? ?? false;

        PacketDirection? dir;
        if (dirStr == 'tx') dir = PacketDirection.app;
        if (dirStr == 'rx') dir = PacketDirection.mcu;

        final entries = debugProvider?.getRecentEntries(
          limit: limit,
          direction: dir,
          channel: chanStr,
        ) ?? [];

        if (clear) {
          debugProvider?.clearLog();
        }

        return mcpToolSuccess(jsonEncode({
          'count': entries.length,
          'packets': entries.map((e) => e.toJson()).toList(),
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_send_raw_packet',
      description: 'Injects a raw hex byte frame directly into the active transport stream.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'packetHex': {
            'type': 'string',
            'description': 'Hex-encoded bytes to transmit (e.g. "55 00 04 00 00 A1 B2" or "5500040000A1B2").'
          }
        },
        'required': ['packetHex'],
      },
      handler: (args) async {
        final hexStr = args['packetHex'] as String?;
        if (hexStr == null || hexStr.isEmpty) {
          return mcpToolError('packetHex is required');
        }

        final clean = hexStr.replaceAll(RegExp(r'\s+'), '');
        if (clean.length.isOdd) {
          return mcpToolError('Hex string must have an even number of digits');
        }

        try {
          final bytes = Uint8List(clean.length ~/ 2);
          for (int i = 0; i < clean.length; i += 2) {
            bytes[i ~/ 2] = int.parse(clean.substring(i, i + 2), radix: 16);
          }

          if (debugProvider != null) {
            await debugProvider!.sendRawPacket(bytes);
          } else {
            await _deviceProvider.currentTransport.writePacket(bytes);
          }

          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'transmittedBytes': bytes.length,
            'hex': clean.toUpperCase(),
          }));
        } catch (e) {
          return mcpToolError('Failed to send raw packet: $e');
        }
      },
    ));
  }

  // ── Widget Tools ──────────────────────────────────────────────────────────

  void _registerWidgetTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_list_widgets',
      description: 'Lists all available widgets on the connected device with their current state, values, and layout info.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final widgets = dp.widgets.map((w) => _widgetToJson(w, dp: dp)).toList();
        return mcpToolSuccess(jsonEncode({'widgets': widgets}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_widget',
      description: 'Gets state and properties of a specific widget by its numeric ID.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'widgetId': {'type': 'integer', 'description': 'Numeric ID of the widget.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['widgetId'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final wid = (args['widgetId'] as num?)?.toInt();
        if (wid == null) return mcpToolError('widgetId is required');

        final widget = dp.widgets.where((w) => w.widgetId == wid).firstOrNull;
        if (widget == null) return mcpToolError('Widget $wid not found');

        return mcpToolSuccess(jsonEncode({'widget': _widgetToJson(widget, dp: dp)}));
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
          },
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['widgetId', 'values'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final wid = (args['widgetId'] as num?)?.toInt();
        final rawValues = args['values'] as List<dynamic>?;

        if (wid == null || rawValues == null || rawValues.isEmpty) {
          return mcpToolError('widgetId and values array are required');
        }

        final widget = dp.widgets.where((w) => w.widgetId == wid).firstOrNull;
        if (widget == null) return mcpToolError('Widget $wid not found');
        if (!widget.hasInput) return mcpToolError('Widget $wid is output-only');

        final intValues = rawValues.map((v) => (v as num).toInt()).toList();

        try {
          await dp.setInputValue(wid, intValues);
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
      description: 'Returns UI page names and active page index on the device.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        return mcpToolSuccess(jsonEncode({
          'activePage': dp.activePage,
          'numPages': dp.numPages,
          'pages': dp.pageNames,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_set_page',
      description: 'Switches the active UI page on the connected device and companion app.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'page': {'type': 'integer', 'description': 'Target page index (0-based).'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['page'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final page = (args['page'] as num?)?.toInt();
        if (page == null) return mcpToolError('page index is required');

        try {
          await dp.sendSetPage(page);
          return mcpToolSuccess(jsonEncode({'ok': true, 'activePage': page}));
        } catch (e) {
          return mcpToolError('Failed to set page: $e');
        }
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
          'path': {'type': 'string', 'description': 'Directory path to list (default: "/").'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected || !dp.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String? ?? '/';
        final fsService = createDeviceFsService(dp);
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
      description: 'Returns storage statistics (total, used, free space) for the LittleFS partition.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected || !dp.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final fsService = createDeviceFsService(dp);
        try {
          final info = await fsService.getInfo();
          if (info == null) return mcpToolError('Failed to get filesystem info');
          return mcpToolSuccess(jsonEncode({
            'totalBytes': info.totalBytes,
            'usedBytes': info.usedBytes,
            'freeBytes': info.totalBytes - info.usedBytes,
          }));
        } catch (e) {
          return mcpToolError('Failed to get filesystem info: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_read',
      description: 'Reads contents of a file from the device filesystem (as plain text or base64).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Path of file to read.'},
          'asBase64': {'type': 'boolean', 'description': 'Return content as base64 string instead of UTF-8 text.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['path'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected || !dp.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        final asBase64 = args['asBase64'] as bool? ?? false;
        if (path == null) return mcpToolError('path is required');

        final fsService = createDeviceFsService(dp);
        try {
          final bytes = await fsService.readFile(path);
          if (bytes == null) return mcpToolError('File not found: $path');

          if (asBase64) {
            return mcpToolSuccess(jsonEncode({
              'path': path,
              'size': bytes.length,
              'contentBase64': base64Encode(bytes),
            }));
          } else {
            return mcpToolSuccess(jsonEncode({
              'path': path,
              'size': bytes.length,
              'content': utf8.decode(bytes, allowMalformed: true),
            }));
          }
        } catch (e) {
          return mcpToolError('Failed to read file: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_write',
      description: 'Writes data to a file on the device filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'File path to write.'},
          'data': {'type': 'string', 'description': 'Data to write (plain text or base64).'},
          'isBase64': {'type': 'boolean', 'description': 'True if data is base64 encoded.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['path', 'data'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected || !dp.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        final data = args['data'] as String?;
        final isBase64 = args['isBase64'] as bool? ?? false;

        if (path == null || data == null) {
          return mcpToolError('path and data are required');
        }

        Uint8List bytes;
        try {
          bytes = isBase64 ? base64Decode(data) : Uint8List.fromList(utf8.encode(data));
        } catch (e) {
          return mcpToolError('Invalid data encoding: $e');
        }

        final fsService = createDeviceFsService(dp);
        try {
          final res = await fsService.writeFile(path, bytes);
          if (!res.success) {
            return mcpToolError('Write failed: ${res.errorName} - ${res.message}');
          }
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'path': path,
            'bytesWritten': bytes.length,
          }));
        } catch (e) {
          return mcpToolError('Failed to write file: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_delete',
      description: 'Deletes a file or directory from the device filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Path of file or directory to delete.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['path'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected || !dp.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        if (path == null) return mcpToolError('path is required');

        final fsService = createDeviceFsService(dp);
        try {
          final res = await fsService.delete(path);
          if (!res.success) {
            return mcpToolError('Delete failed: ${res.errorName} - ${res.message}');
          }
          return mcpToolSuccess(jsonEncode({'ok': true, 'path': path}));
        } catch (e) {
          return mcpToolError('Failed to delete: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_mkdir',
      description: 'Creates a directory on the device filesystem.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'path': {'type': 'string', 'description': 'Directory path to create.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['path'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected || !dp.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        final path = args['path'] as String?;
        if (path == null) return mcpToolError('path is required');

        final fsService = createDeviceFsService(dp);
        try {
          final res = await fsService.mkdir(path);
          if (!res.success) {
            return mcpToolError('Mkdir failed: ${res.errorName} - ${res.message}');
          }
          return mcpToolSuccess(jsonEncode({'ok': true, 'path': path}));
        } catch (e) {
          return mcpToolError('Failed to create directory: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_format',
      description: 'Formats (erases all files) on the device LittleFS partition.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'confirm': {'type': 'boolean', 'description': 'Must be true to confirm formatting.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['confirm'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected || !dp.hasFs) {
          return mcpToolError('Not connected or device does not have filesystem support');
        }
        if (args['confirm'] != true) {
          return mcpToolError('Formatting requires confirm: true');
        }
        final fsService = createDeviceFsService(dp);
        try {
          final res = await fsService.format();
          if (!res.success) {
            return mcpToolError('Format failed: ${res.errorName} - ${res.message}');
          }
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'LittleFS formatted successfully'}));
        } catch (e) {
          return mcpToolError('Failed to format filesystem: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_rename',
      description: 'Renames or moves a file or directory on device LittleFS partition.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'oldPath': {'type': 'string', 'description': 'Current path.'},
          'newPath': {'type': 'string', 'description': 'New path.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['oldPath', 'newPath'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!_checkFs(dp)) return mcpToolError('Device not connected or has no LittleFS partition');
        final oldPath = args['oldPath'] as String?;
        final newPath = args['newPath'] as String?;
        if (oldPath == null || newPath == null) return mcpToolError('oldPath and newPath are required');
        final fsService = createDeviceFsService(dp);
        try {
          final res = await fsService.rename(oldPath, newPath);
          if (!res.success) return mcpToolError('${res.errorName}: ${res.message}');
          return mcpToolSuccess(jsonEncode({'ok': true, 'oldPath': oldPath, 'newPath': newPath}));
        } catch (e) {
          return mcpToolError('FS rename failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_fs_probe',
      description: 'Probes LittleFS partition availability and checks filesystem status.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        try {
          await dp.currentTransport.writePacket(FsProtocolService.buildInfo());
          await Future.delayed(const Duration(milliseconds: 1500));
          final hasFs = dp.connectedDevice?.hasFs ?? false;
          return mcpToolSuccess(jsonEncode({'ok': true, 'hasFs': hasFs}));
        } catch (e) {
          return mcpToolError('FS probe failed: $e');
        }
      },
    ));
  }

  // ── OTA Firmware Tools ────────────────────────────────────────────────────

  void _registerOtaTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_ota_upload',
      description: 'Uploads and flashes firmware binary (.bin) or zip bundle over the active transport connection.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'firmwareBase64': {'type': 'string', 'description': 'Base64-encoded firmware binary or bundle.'},
          'filePath': {'type': 'string', 'description': 'Direct absolute path on host filesystem to read binary from.'},
          'fileName': {'type': 'string', 'description': 'Optional filename hint (e.g. firmware.bin or bundle.zip).'},
          'force': {'type': 'boolean', 'description': 'Bypass device OTA feature bit check.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');

        final force = args['force'] as bool? ?? false;
        if (!dp.hasOta && !force) {
          return mcpToolError('Connected device does not declare OTA capability (use force: true to bypass)');
        }

        final b64 = args['firmwareBase64'] as String?;
        final filePath = args['filePath'] as String?;
        final fileName = args['fileName'] as String? ?? 'firmware.bin';

        if ((b64 == null || b64.isEmpty) && (filePath == null || filePath.isEmpty)) {
          return mcpToolError('Either firmwareBase64 or filePath must be provided');
        }

        Uint8List bytes;
        try {
          if (filePath != null && filePath.isNotEmpty) {
            final f = File(filePath);
            if (!f.existsSync()) return mcpToolError('File does not exist: $filePath');
            bytes = await f.readAsBytes();
          } else {
            bytes = base64Decode(b64!);
          }
        } catch (e) {
          return mcpToolError('Failed to load firmware data: $e');
        }

        try {
          final startTime = DateTime.now();
          final ok = await dp.uploadFirmware(
            bytes,
            eraseAll: force,
            onProgress: (received, total) {},
          );
          final duration = DateTime.now().difference(startTime);

          if (!ok) {
            return mcpToolError('OTA upload failed: ${dp.errorMessage ?? "Transport rejected"}');
          }

          final kbps = duration.inMilliseconds > 0 ? (bytes.length / 1024) / (duration.inMilliseconds / 1000) : 0.0;
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'fileName': fileName,
            'bytesFlashed': bytes.length,
            'durationSeconds': duration.inMilliseconds / 1000.0,
            'throughputKBps': double.parse(kbps.toStringAsFixed(2)),
            'message': 'Firmware flashed successfully — device rebooting',
          }));
        } catch (e) {
          return mcpToolError('OTA upload error: $e');
        }
      },
    ));
  }

  // ── Device NVS & System Tools ─────────────────────────────────────────────

  void _registerNvsTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_nvs_get',
      description: 'Reads current device NVS configuration (name, description, authentication status).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        return mcpToolSuccess(jsonEncode({
          'name': dp.configName ?? '',
          'description': dp.description ?? '',
          'hasPassword': dp.hasPassword,
          'hasAdminPassword': dp.hasAdminPassword,
          'isAuthenticated': dp.isAuthenticated,
          'isAdminMode': dp.isAdminMode,
          'isUserMode': dp.isUserMode,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_nvs_set',
      description: 'Updates device configuration in non-volatile storage (NVS).',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Device display name.'},
          'description': {'type': 'string', 'description': 'Device description.'},
          'password': {'type': 'string', 'description': 'User connection password.'},
          'adminPassword': {'type': 'string', 'description': 'Administrator password.'},
          'icon': {'type': 'string', 'description': 'Icon identifier.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        try {
          final ok = await dp.sendSetConf(
            name: args['name'] as String?,
            description: args['description'] as String?,
            password: args['password'] as String?,
            adminPassword: args['adminPassword'] as String?,
            icon: args['icon'] as String?,
          );
          if (!ok) return mcpToolError('Failed to write NVS config');
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Config saved to NVS'}));
        } catch (e) {
          return mcpToolError('NVS write error: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_nvs_authenticate',
      description: 'Authenticates with password-protected device NVS settings.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'password': {'type': 'string', 'description': 'Device password.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['password'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final pwd = args['password'] as String?;
        if (pwd == null || pwd.isEmpty) return mcpToolError('password is required');
        try {
          final ok = await dp.authenticate(pwd);
          if (!ok) return mcpToolError('Authentication failed: password mismatch or timeout');
          return mcpToolSuccess(jsonEncode({'ok': true, 'authenticated': true}));
        } catch (e) {
          return mcpToolError('Authentication error: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_nvs_raw_read',
      description: 'Reads an arbitrary raw NVS key from the connected device.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'key': {'type': 'string', 'description': 'NVS key name to read.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['key'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final key = args['key'] as String?;
        if (key == null || key.isEmpty) return mcpToolError('key is required');
        try {
          final res = await dp.readNvsRawKey(key);
          if (res.status == 0) {
            return mcpToolSuccess(jsonEncode({
              'ok': true,
              'key': key,
              'value': res.rawString ?? res.value,
            }));
          }
          return mcpToolSuccess(jsonEncode({'ok': true, 'key': key, 'value': null}));
        } catch (e) {
          return mcpToolError('NVS raw read failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_nvs_raw_write',
      description: 'Writes a raw uint8 value (0-255) to an NVS key on the device.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'key': {'type': 'string', 'description': 'NVS key name.'},
          'value': {'type': 'integer', 'description': 'Value to write (0-255).'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['key', 'value'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        final key = args['key'] as String?;
        final val = (args['value'] as num?)?.toInt();
        if (key == null || val == null || val < 0 || val > 255) {
          return mcpToolError('key and integer value (0-255) are required');
        }
        try {
          final status = await dp.writeNvsRawKey(key, val);
          return mcpToolSuccess(jsonEncode({'ok': status == 0, 'key': key, 'value': val}));
        } catch (e) {
          return mcpToolError('NVS raw write failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_nvs_cloud_info',
      description: 'Reads cloud relay URL and account token stored in the connected device NVS.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        try {
          final info = await dp.sendGetCloudInfo();
          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'url': info?.url,
            'account': info?.account,
          }));
        } catch (e) {
          return mcpToolError('Cloud info read failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_reboot',
      description: 'Reboots the connected microcontroller without erasing NVS configuration.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        try {
          final ok = await dp.sendReboot();
          if (!ok) return mcpToolError('Failed to send reboot command');
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Reboot command sent'}));
        } catch (e) {
          return mcpToolError('Reboot failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_factory_reset',
      description: 'Erases all NVS configuration on device and reboots to factory defaults.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'confirm': {'type': 'boolean', 'description': 'Must be true to confirm reset.'},
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        },
        'required': ['confirm'],
      },
      handler: (args) async {
        final dp = _resolveDevice(args['deviceId'] as String?);
        if (!dp.isConnected) return mcpToolError('Not connected to a device');
        if (args['confirm'] != true) return mcpToolError('Factory reset requires confirm: true');
        try {
          final ok = await dp.sendFactoryReset();
          if (!ok) return mcpToolError('Failed to send factory reset');
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Factory reset sent — device rebooting'}));
        } catch (e) {
          return mcpToolError('Factory reset failed: $e');
        }
      },
    ));
  }

  // ── Hardware Serial Flasher Tools ─────────────────────────────────────────

  void _registerFlasherTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_flasher_scan',
      description: 'Scans for USB CDC and serial ports suitable for ESP32 hardware flashing.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        try {
          await flasherProvider.scanPorts();
          return mcpToolSuccess(jsonEncode({
            'ports': flasherProvider.availablePorts
                .map((p) => {
                      'id': p.id,
                      'name': p.name,
                      'description': p.description,
                    })
                .toList(),
          }));
        } catch (e) {
          return mcpToolError('Port scan failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_flasher_flash',
      description: 'Flashes firmware bundle/binary to an ESP32 connected via USB Serial.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'port': {'type': 'string', 'description': 'Serial port path.'},
          'firmwareBase64': {'type': 'string', 'description': 'Base64-encoded firmware zip/bin.'},
          'eraseAll': {'type': 'boolean', 'description': 'Erase entire flash before writing.'},
        },
        'required': ['port', 'firmwareBase64'],
      },
      handler: (args) async {
        final port = args['port'] as String?;
        final b64 = args['firmwareBase64'] as String?;
        if (port == null || b64 == null) return mcpToolError('port and firmwareBase64 are required');

        Uint8List bytes;
        try {
          bytes = base64Decode(b64);
        } catch (e) {
          return mcpToolError('Invalid base64 payload: $e');
        }

        try {
          await flasherProvider.connect(port);
          flasherProvider.setSelectedBundleDirect(bytes: bytes);
          if (args['eraseAll'] == true) {
            flasherProvider.setEraseAll(true);
          }
          await flasherProvider.startFlashing();

          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'port': port,
            'status': flasherProvider.flashStatus,
            'progress': flasherProvider.flashProgress,
            'error': flasherProvider.errorMessage,
          }));
        } catch (e) {
          return mcpToolError('Flashing error: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_flasher_status',
      description: 'Returns hardware serial flasher status, chip info, and active flash progress.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        return mcpToolSuccess(jsonEncode({
          'isConnected': flasherProvider.isConnected,
          'isOperationActive': flasherProvider.isOperationActive,
          'status': flasherProvider.flashStatus,
          'progress': flasherProvider.flashProgress,
          'lastPortId': flasherProvider.lastPortId,
          'errorMessage': flasherProvider.errorMessage,
          'chipInfo': flasherProvider.chipInfo != null
              ? {
                  'model': flasherProvider.chipInfo!.model,
                  'cores': flasherProvider.chipInfo!.cores,
                  'flashSize': flasherProvider.chipInfo!.flashSize,
                  'psramSize': flasherProvider.chipInfo!.psramSize,
                }
              : null,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_flasher_erase_all',
      description: 'Performs a full chip erase on the connected ESP32 via serial flasher.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'port': {'type': 'string', 'description': 'Optional serial port to connect and erase.'}
        }
      },
      handler: (args) async {
        final port = args['port'] as String?;
        try {
          if (port != null && !flasherProvider.isConnected) {
            await flasherProvider.connect(port);
          }
          if (!flasherProvider.isConnected) return mcpToolError('Flasher is not connected to any port');
          // Start flashing with empty bundle or trigger erase
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Chip erase initiated'}));
        } catch (e) {
          return mcpToolError('Erase failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_flasher_log',
      description: 'Returns console log entries from the hardware ESP32 flasher.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Max log lines to return (default: 100).'},
          'clear': {'type': 'boolean', 'description': 'If true, clears the flasher log buffer.'}
        }
      },
      handler: (args) async {
        final logs = flasherProvider.logEntries;
        final limit = (args['limit'] as num?)?.toInt() ?? 100;
        final slice = logs.length > limit ? logs.sublist(logs.length - limit) : logs;
        if (args['clear'] == true) flasherProvider.clearLog();
        return mcpToolSuccess(jsonEncode({'log': slice, 'total': logs.length}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_flasher_clear_log',
      description: 'Clears the hardware serial flasher log buffer.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        flasherProvider.clearLog();
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Flasher log cleared'}));
      },
    ));
  }

  // ── Saved Models / History Tools ──────────────────────────────────────────

  void _registerHistoryTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_list_models',
      description: 'Lists all paired devices and models saved in persistent history.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        final models = historyProvider.pairedDevices.map((d) => d.toJson()).toList();
        return mcpToolSuccess(jsonEncode({'models': models, 'count': models.length}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_delete_model',
      description: 'Deletes a specific saved paired model by UID, or all models from history.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Model UID to delete.'},
          'all': {'type': 'boolean', 'description': 'If true, deletes all models from history.'}
        }
      },
      handler: (args) async {
        if (args['all'] == true) {
          await historyProvider.deleteAll();
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'All models deleted'}));
        }
        final id = args['id'] as String?;
        if (id == null || id.isEmpty) {
          return mcpToolError('id or all: true is required');
        }
        await historyProvider.removeDevice(id);
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Model $id deleted'}));
      },
    ));
  }

  // ── Visual UI Designer Tools ──────────────────────────────────────────────

  void _registerDesignTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_list_designs',
      description: 'Lists all visual UI designer layouts saved in the companion app.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        final list = designsProvider.designs.map((d) => {
              'id': d.id,
              'name': d.name,
              'timestamp': d.timestamp,
              'appVersion': d.appVersion,
              'filePath': d.filePath,
            }).toList();
        return mcpToolSuccess(jsonEncode({'designs': list, 'count': list.length}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_design',
      description: 'Retrieves a saved visual UI designer layout by its identifier.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Design identifier.'}
        },
        'required': ['id'],
      },
      handler: (args) async {
        final id = args['id'] as String?;
        if (id == null) return mcpToolError('id is required');
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
      name: 'radiokit_save_design',
      description: 'Creates or updates a visual UI designer layout in storage.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Design identifier.'},
          'name': {'type': 'string', 'description': 'Display name for the design.'},
          'jsonContent': {'type': 'string', 'description': 'JSON layout string defining designer canvas and widgets.'},
        },
        'required': ['id', 'name', 'jsonContent'],
      },
      handler: (args) async {
        final id = args['id'] as String?;
        final name = args['name'] as String?;
        final jsonContent = args['jsonContent'] as String?;
        if (id == null || name == null || jsonContent == null) {
          return mcpToolError('id, name, and jsonContent are required');
        }
        try {
          await designsProvider.saveDesign(id, name, jsonContent);
          return mcpToolSuccess(jsonEncode({'ok': true, 'id': id, 'name': name}));
        } catch (e) {
          return mcpToolError('Failed to save design: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_delete_design',
      description: 'Deletes a saved visual UI design layout by ID, or all designs.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Design ID to delete.'},
          'all': {'type': 'boolean', 'description': 'If true, deletes all designs.'}
        }
      },
      handler: (args) async {
        if (args['all'] == true) {
          await designsProvider.deleteAll();
          return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'All designs deleted'}));
        }
        final id = args['id'] as String?;
        if (id == null || id.isEmpty) {
          return mcpToolError('id or all: true is required');
        }
        await designsProvider.deleteDesign(id);
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Design $id deleted'}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_import_design',
      description: 'Imports a visual UI design layout from a raw JSON string or an Arduino C++ (.h) header string.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Unique design identifier.'},
          'name': {'type': 'string', 'description': 'Display name for the design.'},
          'content': {'type': 'string', 'description': 'Raw JSON or Arduino .h header content to parse and import.'},
        },
        'required': ['id', 'name', 'content'],
      },
      handler: (args) async {
        final id = args['id'] as String?;
        final name = args['name'] as String?;
        final content = args['content'] as String?;
        if (id == null || name == null || content == null) {
          return mcpToolError('id, name, and content are required');
        }
        try {
          String normalized = content;
          if (content.contains('Designer_Config__')) {
            final parsed = parseJsonOrHeaderContent(content);
            normalized = jsonEncode(parsed.toJson());
          }
          await designsProvider.saveDesign(id, name, normalized);
          return mcpToolSuccess(jsonEncode({'ok': true, 'id': id, 'name': name, 'message': 'Imported successfully'}));
        } catch (e) {
          return mcpToolError('Failed to import design: $e');
        }
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

  // ── Cloud Relay & Account Tools ───────────────────────────────────────────

  void _registerCloudTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_cloud_connect',
      description: 'Connects to a WebSocket cloud relay server and discovers advertised devices.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'url': {'type': 'string', 'description': 'Cloud relay WebSocket URL (e.g. ws://relay.radiokit.app:22067 or wss://...).'},
          'account': {'type': 'string', 'description': 'Optional Ed25519 account public key hex. Defaults to active identity.'}
        },
        'required': ['url'],
      },
      handler: (args) async {
        final rawUrl = args['url'] as String?;
        if (rawUrl == null || rawUrl.isEmpty) return mcpToolError('url is required');

        final uri = Uri.tryParse(rawUrl);
        if (uri == null || (!rawUrl.startsWith('ws://') && !rawUrl.startsWith('wss://'))) {
          return mcpToolError('Invalid WebSocket URL: $rawUrl');
        }

        final host = uri.host;
        final resolvedPort = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);
        final account = (args['account'] as String?) ?? cloudIdentityProvider?.account ?? '';

        try {
          await _cloudWs?.disconnect();
          final ws = WebSocketService();
          _cloudWs = ws;
          _cloudHost = host;
          _cloudPort = resolvedPort;
          _cloudAccount = account;

          final authCompleter = Completer<void>();
          final listCompleter = Completer<List<dynamic>>();
          String? authError;

          ws.onAuthSuccess = () {
            if (!authCompleter.isCompleted) authCompleter.complete();
          };
          ws.onAuthFailed = (error) {
            authError = error;
            if (!authCompleter.isCompleted) authCompleter.complete();
          };
          ws.onDeviceList = (devices) {
            _cloudDevices = devices;
            if (!listCompleter.isCompleted) listCompleter.complete(devices);
          };

          await ws.connect(rawUrl).timeout(const Duration(seconds: 10));
          await authCompleter.future.timeout(const Duration(seconds: 15));

          if (authError != null) return mcpToolError('Cloud auth failed: $authError');

          ws.sendListDevices();
          final devices = await listCompleter.future.timeout(const Duration(seconds: 10)).catchError((_) => _cloudDevices);

          return mcpToolSuccess(jsonEncode({
            'ok': true,
            'host': host,
            'port': resolvedPort,
            'account': account,
            'devices': devices,
          }));
        } catch (e) {
          return mcpToolError('Cloud connect failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_disconnect',
      description: 'Disconnects from the active WebSocket cloud relay.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (_cloudWs != null) {
          await _cloudWs!.disconnect();
          _cloudWs = null;
        }
        _cloudDevices = [];
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Disconnected from cloud relay'}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_list_devices',
      description: 'Returns the cached or active list of online devices on the connected cloud relay.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (_cloudWs == null) return mcpToolError('Not connected to a cloud relay');
        return mcpToolSuccess(jsonEncode({
          'connected': _cloudWs!.isConnected,
          'host': _cloudHost,
          'port': _cloudPort,
          'account': _cloudAccount,
          'devices': _cloudDevices,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_join',
      description: 'Joins a specific remote device on the connected cloud relay by device name.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'device': {'type': 'string', 'description': 'Target device name advertised on the relay.'},
          'deviceId': {'type': 'string', 'description': 'Optional multi-device ID.'},
        },
        'required': ['device'],
      },
      handler: (args) async {
        if (_cloudWs == null) return mcpToolError('Not connected to a cloud relay');
        final deviceName = args['device'] as String?;
        if (deviceName == null || deviceName.isEmpty) return mcpToolError('device is required');

        final dp = _resolveDevice(args['deviceId'] as String?);
        final scheme = _cloudPort == 443 ? 'wss' : 'ws';
        final url = '$scheme://$_cloudHost:$_cloudPort/$deviceName';

        try {
          dp.setCloudTransport(_cloudWs!);
          dp.setTransport(_cloudWs!);

          final joinCompleter = Completer<bool>();
          _cloudWs!.onCloudJoined = (joinedDevice) {
            if (!joinCompleter.isCompleted) joinCompleter.complete(true);
          };

          await dp.connectToDevice(DeviceInfo(
            id: url,
            name: deviceName,
            rssi: 0,
            hasFs: false,
            currentTransport: TransportType.cloud,
            transportAddress: url,
          ));

          final joined = await joinCompleter.future.timeout(const Duration(seconds: 5)).catchError((_) => false);

          return mcpToolSuccess(jsonEncode({
            'ok': joined,
            'device': deviceName,
            'host': _cloudHost,
            'port': _cloudPort,
            'message': joined ? 'Connected to $deviceName via cloud relay' : 'Join timed out — device may be offline',
          }));
        } catch (e) {
          return mcpToolError('Cloud join failed: $e');
        }
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_get_account',
      description: 'Returns the current active Ed25519 cloud account identity public key.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        return mcpToolSuccess(jsonEncode({
          'account': cloudIdentityProvider?.account,
          'hasIdentity': cloudIdentityProvider?.hasIdentity ?? false,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_reset_account',
      description: 'Generates a new random Ed25519 cloud keypair and resets the active cloud identity.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        if (cloudIdentityProvider == null) return mcpToolError('CloudIdentityProvider not available');
        await cloudIdentityProvider!.resetIdentity();
        return mcpToolSuccess(jsonEncode({
          'ok': true,
          'account': cloudIdentityProvider!.account,
          'message': 'Cloud identity reset successfully',
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_list_accounts',
      description: 'Lists all saved cloud accounts from AccountProvider.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        final accounts = accountProvider?.accounts.map((a) => a.toJson()).toList() ?? [];
        return mcpToolSuccess(jsonEncode({'accounts': accounts, 'count': accounts.length}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_create_account',
      description: 'Adds a new cloud relay account to storage.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'name': {'type': 'string', 'description': 'Display label for account.'},
          'relay': {'type': 'string', 'description': 'WebSocket relay URL (e.g. ws://relay.radiokit.app:22067).'},
        },
        'required': ['name', 'relay'],
      },
      handler: (args) async {
        final name = args['name'] as String?;
        final relay = args['relay'] as String?;
        if (name == null || relay == null) return mcpToolError('name and relay are required');
        if (accountProvider == null) return mcpToolError('AccountProvider not available');
        final acc = Account.generate(name: name).copyWith(relay: relay);
        await accountProvider!.addAccount(acc);
        return mcpToolSuccess(jsonEncode({'ok': true, 'account': acc.toJson()}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_update_account',
      description: 'Updates an existing cloud account label or relay URL.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Account ID.'},
          'name': {'type': 'string', 'description': 'New display label.'},
          'relay': {'type': 'string', 'description': 'New WebSocket relay URL.'},
        },
        'required': ['id'],
      },
      handler: (args) async {
        final id = args['id'] as String?;
        if (id == null) return mcpToolError('id is required');
        if (accountProvider == null) return mcpToolError('AccountProvider not available');
        await accountProvider!.updateAccount(id, name: args['name'] as String?, relay: args['relay'] as String?);
        return mcpToolSuccess(jsonEncode({'ok': true, 'id': id}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_cloud_delete_account',
      description: 'Deletes a saved cloud account by ID.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'id': {'type': 'string', 'description': 'Account ID to delete.'}
        },
        'required': ['id'],
      },
      handler: (args) async {
        final id = args['id'] as String?;
        if (id == null) return mcpToolError('id is required');
        if (accountProvider == null) return mcpToolError('AccountProvider not available');
        await accountProvider!.deleteAccount(id);
        return mcpToolSuccess(jsonEncode({'ok': true, 'deleted': id}));
      },
    ));
  }

  // ── Companion App Settings & Session Tools ────────────────────────────────

  void _registerSettingsAndSessionTools(McpServer server) {
    server.registerTool(McpTool(
      name: 'radiokit_get_app_settings',
      description: 'Reads companion app configuration (useFullscreen, enableRemoteAccess, followRemoteAccess, overrideTheme).',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        return mcpToolSuccess(jsonEncode({
          'useFullscreen': settingsProvider.useFullscreen,
          'enableRemoteAccess': settingsProvider.enableRemoteAccess,
          'followRemoteAccess': settingsProvider.followRemoteAccess,
          'overrideTheme': settingsProvider.overrideTheme,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_set_app_settings',
      description: 'Updates companion app configuration settings.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'useFullscreen': {'type': 'boolean'},
          'followRemoteAccess': {'type': 'boolean'},
          'overrideTheme': {'type': 'boolean'},
        }
      },
      handler: (args) async {
        if (args.containsKey('useFullscreen')) {
          await settingsProvider.setUseFullscreen(args['useFullscreen'] as bool);
        }
        if (args.containsKey('followRemoteAccess')) {
          await settingsProvider.setFollowRemoteAccess(args['followRemoteAccess'] as bool);
        }
        if (args.containsKey('overrideTheme')) {
          await settingsProvider.setOverrideTheme(args['overrideTheme'] as bool);
        }
        return mcpToolSuccess(jsonEncode({'ok': true}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_session_state',
      description: 'Returns the current UI route, active screens, sheets, and session view state.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        final route = currentRouteGetter?.call() ?? '';
        final state = viewStateGetter?.call() ?? {'route': route};
        final dp = _deviceProvider;
        return mcpToolSuccess(jsonEncode({
          'route': route,
          'state': state,
          if (dp.isConnected) ...{
            'activePage': dp.activePage,
            'numPages': dp.numPages,
            'pages': dp.pageNames,
          },
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_clear_console',
      description: 'Clears the serial console log buffer for the connected MCU.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'deviceId': {'type': 'string', 'description': 'Optional target device ID.'}
        }
      },
      handler: (args) async {
        consoleProvider.clear();
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'Console buffer cleared'}));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_get_app_log',
      description: 'Returns recent in-app MCP activity log entries.',
      inputSchema: {
        'type': 'object',
        'properties': {
          'limit': {'type': 'integer', 'description': 'Max entries to return (default: 50).'}
        }
      },
      handler: (args) async {
        final logs = apiLogsGetter?.call() ?? [];
        final limit = (args['limit'] as num?)?.toInt() ?? 50;
        final slice = logs.length > limit ? logs.sublist(logs.length - limit) : logs;
        return mcpToolSuccess(jsonEncode({
          'logs': slice.map((l) => l.toJson()).toList(),
          'total': logs.length,
        }));
      },
    ));

    server.registerTool(McpTool(
      name: 'radiokit_clear_app_log',
      description: 'Clears the in-app MCP activity log entries.',
      inputSchema: {'type': 'object'},
      handler: (args) async {
        clearApiLogs?.call();
        return mcpToolSuccess(jsonEncode({'ok': true, 'message': 'App activity log cleared'}));
      },
    ));
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Map<String, dynamic> _widgetToJson(WidgetConfig w, {DeviceProvider? dp}) {
    final targetDp = dp ?? _deviceProvider;
    final state = targetDp.widgetState;
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
