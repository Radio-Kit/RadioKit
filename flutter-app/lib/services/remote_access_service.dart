import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import '../models/api_log_entry.dart';
import '../models/protocol.dart';
import '../models/device_info.dart';
import '../models/widget_config.dart';
import 'protocol_service.dart';
import '../providers/device_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/serial_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/console_provider.dart';
import '../providers/designs_provider.dart';
import 'device_fs_service.dart';
import 'fs_protocol_service.dart';

class RemoteAccessService {
  final DeviceProvider _deviceProvider;
  final BleProvider _bleProvider;
  final SerialProvider _serialProvider;
  final HistoryProvider _historyProvider;
  final SettingsProvider _settingsProvider;
  final ConsoleProvider _consoleProvider;
  final DesignsProvider _designsProvider;
  final void Function(ApiLogEntry) _onLog;
  final void Function(String route)? _onFollowEvent;
  final String Function() _currentRouteGetter;

  HttpServer? _server;
  bool _isRunning = false;
  int _actualPort = 0;
  String _cachedLocalIp = '127.0.0.1';

  bool get isRunning => _isRunning;
  int get actualPort => _actualPort;

  String get localIp => _cachedLocalIp;

  RemoteAccessService({
    required DeviceProvider deviceProvider,
    required BleProvider bleProvider,
    required SerialProvider serialProvider,
    required HistoryProvider historyProvider,
    required SettingsProvider settingsProvider,
    required ConsoleProvider consoleProvider,
    required DesignsProvider designsProvider,
    required void Function(ApiLogEntry) onLog,
    void Function(String route)? onFollowEvent,
    String Function() currentRouteGetter = _defaultRouteGetter,
  })  : _deviceProvider = deviceProvider,
        _bleProvider = bleProvider,
        _serialProvider = serialProvider,
        _historyProvider = historyProvider,
        _settingsProvider = settingsProvider,
        _consoleProvider = consoleProvider,
        _designsProvider = designsProvider,
        _onLog = onLog,
        _onFollowEvent = onFollowEvent,
        _currentRouteGetter = currentRouteGetter;

  static String _defaultRouteGetter() => '';

  // ── Middleware ──────────────────────────────────────────────────────────────

  Middleware _corsMiddleware() {
    return (handler) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response(200,
              headers: _corsHeaders());
        }
        final response = await handler(request);
        return response.change(headers: _corsHeaders());
      };
    };
  }

  Map<String, String> _corsHeaders() => {
        'access-control-allow-origin': '*',
        'access-control-allow-methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'access-control-allow-headers': 'content-type, authorization',
        'access-control-max-age': '86400',
      };

  Middleware _logMiddleware() {
    return (handler) {
      return (request) async {
        final sw = Stopwatch()..start();
        final response = await handler(request);
        sw.stop();
        final path = request.requestedUri.path;
        final entry = ApiLogEntry(
          timestamp: DateTime.now(),
          method: request.method,
          path: path,
          statusCode: response.statusCode,
          durationMs: sw.elapsedMilliseconds,
        );
        _logEntries.add(entry);
        if (_logEntries.length > 500) _logEntries.removeAt(0);
        _onLog(entry);

        // Follow-mode route mapping
        if (_onFollowEvent != null && response.statusCode >= 200 && response.statusCode < 300) {
          final route = _followRoute(path);
          if (route != null) _onFollowEvent?.call(route);
        }

        return response;
      };
    };
  }

  static String? _followRoute(String path) {
    if (path.startsWith('/api/pair/')) return '/pair';
    if (path.startsWith('/api/connection/connect')) return '/control';
    if (path.startsWith('/api/connection/disconnect')) return '/models';
    if (path.startsWith('/api/connection/reconnect')) return '/models';
    if (path.startsWith('/api/connection/demo')) return '/control';
    if (path == '/api/widgets' || path.startsWith('/api/widgets/')) return '/control';
    if (path.startsWith('/api/fs/')) return '/dev-tools/esp32-fs';
    if (path.startsWith('/api/designs')) return '/designs';
    if (path.startsWith('/api/transport/')) return '/debug';
    if (path.startsWith('/api/settings')) return '/system';
    if (path.startsWith('/api/console')) return '/system';
    if (path.startsWith('/api/log')) return '/system';
    if (path.startsWith('/api/models')) return '/models';
    return null;
  }

  /// Exposed for testing only — delegates to [_followRoute].
  @visibleForTesting
  static String? testOnlyFollowRoute(String path) => _followRoute(path);

  // ── Start / Stop ────────────────────────────────────────────────────────────

  Future<String?> start() async {
    if (_isRunning) return null;

    final router = Router();

    router.get('/api/status', _handleStatus);
    router.get('/api/log', _handleLog);
    router.delete('/api/log', _handleLogClear);
    router.get('/api/settings', _handleSettings);
    router.put('/api/settings', _handleSettingsUpdate);
    router.get('/api/pair/devices', _handlePairDevices);
    router.post('/api/pair/scan', _handlePairScan);
    router.get('/api/connection', _handleConnection);
    router.get('/api/connection/params', _handleConnectionParams);
    router.post('/api/connection/connect', _handleConnect);
    router.post('/api/connection/disconnect', _handleDisconnect);
    router.post('/api/connection/reconnect', _handleReconnect);
    router.get('/api/models', _handleModels);
    router.delete('/api/models', _handleModelsDeleteAll);
    router.delete('/api/models/<id>', _handleModelsDeleteOne);
    router.post('/api/transport/send', _handleTransportSend);
    router.post('/api/transport/ping', _handleTransportPing);
    router.post('/api/transport/<cmd>', _handleTransportQuick);
    router.get('/api/widgets', _handleWidgets);
    router.get('/api/widgets/<id>', _handleWidget);
    router.put('/api/widgets/<id>', _handleWidgetSet);
    router.get('/api/fs/list', _handleFsList);
    router.get('/api/fs/info', _handleFsInfo);
    router.get('/api/fs/read', _handleFsRead);
    router.post('/api/fs/write', _handleFsWrite);
    router.post('/api/fs/upload', _handleFsUpload);
    router.post('/api/fs/mkdir', _handleFsMkdir);
    router.post('/api/fs/delete', _handleFsDelete);
    router.post('/api/fs/rename', _handleFsRename);
    router.post('/api/fs/format', _handleFsFormat);
    router.post('/api/fs/probe', _handleFsProbe);
    router.get('/api/console', _handleConsole);
    router.delete('/api/console', _handleConsoleClear);
    router.post('/api/connection/demo', _handleConnectionDemo);
    router.get('/api/designs', _handleDesigns);
    router.post('/api/designs', _handleDesignsSave);
    router.delete('/api/designs', _handleDesignsDeleteAll);
    router.delete('/api/designs/<id>', _handleDesignsDeleteOne);
    router.get('/api/session/route', _handleSessionRoute);

    final pipeline = Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_logMiddleware());
    final handler = pipeline.addHandler(router.call);

    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.anyIPv4,
        7007,
      );
      _isRunning = true;
      _actualPort = _server!.port;
      _cachedLocalIp = await _localIp();
      return null;
    } on SocketException catch (e) {
      return 'Failed to bind port 7007: ${e.message}';
    } catch (e) {
      return 'Failed to start server: $e';
    }
  }

  Future<void> stop() async {
    if (!_isRunning) return;
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _actualPort = 0;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Response _json(Map<String, dynamic> data, {int status = 200}) {
    return Response(status,
        headers: {'content-type': 'application/json'},
        body: jsonEncode(data));
  }

  Response _error(String code, String message, {int status = 400}) {
    return Response(status,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'error': code, 'message': message}));
  }

  Future<Map<String, dynamic>> _parseBody(Request request) async {
    final body = await request.readAsString();
    if (body.isEmpty) return {};
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<String> _localIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLoopback: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '127.0.0.1';
  }

  String _platformName() {
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isWindows) return 'windows';
    return 'unknown';
  }

  String _widgetTypeName(int typeId) {
    switch (typeId) {
      case kWidgetButton:
        return 'button';
      case kWidgetSlideSwitch:
        return 'slideSwitch';
      case kWidgetSwitch:
        return 'switch';
      case kWidgetSlider:
        return 'slider';
      case kWidgetKnob:
        return 'knob';
      case kWidgetJoystick:
        return 'joystick';
      case kWidgetLed:
        return 'led';
      case kWidgetText:
        return 'text';
      case kWidgetMultiple:
        return 'multiple';
      default:
        return 'unknown';
    }
  }

  String? _variantName(int typeId, int variant) {
    switch (typeId) {
      case kWidgetButton:
        return variant == 1 ? 'toggle' : 'push';
      case kWidgetSlider:
        if (variantIsAlternateShape(variant)) return 'gasPedal';
        return null;
      case kWidgetKnob:
        if (variantIsAlternateShape(variant)) return 'steeringWheel';
        return null;
      case kWidgetMultiple:
        return variant == 1 ? 'multiSelect' : 'multiButton';
      default:
        return null;
    }
  }

  Map<String, dynamic> _widgetToJson(WidgetConfig w) {
    final state = _deviceProvider.widgetState;
    final inputs = state?.inputValues[w.widgetId];
    final outputs = state?.outputValues[w.widgetId];

    Map<String, dynamic> stateJson = {};
    if (w.hasOutput) {
      if (w.typeId == kWidgetText) {
        stateJson['text'] = outputs is String ? outputs : '';
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
        final arr = inputs ?? [0, 0];
        stateJson['values'] = arr;
      } else {
        stateJson['value'] = inputs?.isNotEmpty == true ? inputs![0] : 0;
      }
    }

    return {
      'widgetId': w.widgetId,
      'type': _widgetTypeName(w.typeId),
      'name': w.label.isNotEmpty ? w.label : 'widget_${w.widgetId}',
      'label': w.label,
      'x': w.x,
      'y': w.y,
      'rotation': w.rotationDegrees,
      'variant': _variantName(w.typeId, w.variant),
      'hasOutput': w.hasOutput,
      'hasInput': w.hasInput,
      'state': stateJson,
    };
  }

  final List<ApiLogEntry> _logEntries = [];

  // ── Route Handlers ──────────────────────────────────────────────────────────

  Future<Response> _handleStatus(Request request) async {
    return _json({
      'version': '1.0.0',
      'uptime': 0,
      'port': _actualPort,
      'localIp': await _localIp(),
      'platform': _platformName(),
      'debug': bool.fromEnvironment('dart.vm.product') == false,
    });
  }

  Future<Response> _handleLog(Request request) async {
    return _json({
      'entries': _logEntries.map((e) => e.toJson()).toList(),
    });
  }

  Future<Response> _handleLogClear(Request request) async {
    _logEntries.clear();
    return _json({'ok': true});
  }

  Future<Response> _handleSettings(Request request) async {
    return _json({
      'showDemo': _settingsProvider.showDemo,
      'useFullscreen': _settingsProvider.useFullscreen,
      'enableDevTools': _settingsProvider.enableDevTools,
      'interfaceScale': _settingsProvider.interfaceScale,
      'enableRemoteAccess': _settingsProvider.enableRemoteAccess,
      'followRemoteAccess': _settingsProvider.followRemoteAccess,
    });
  }

  Future<Response> _handleSettingsUpdate(Request request) async {
    final body = await _parseBody(request);
    if (body.containsKey('showDemo')) {
      await _settingsProvider.setShowDemo(body['showDemo'] as bool);
    }
    if (body.containsKey('useFullscreen')) {
      await _settingsProvider.setUseFullscreen(body['useFullscreen'] as bool);
    }
    if (body.containsKey('enableDevTools')) {
      await _settingsProvider.setEnableDevTools(body['enableDevTools'] as bool);
    }
    if (body.containsKey('interfaceScale')) {
      await _settingsProvider.setInterfaceScale(body['interfaceScale'] as int);
    }
    if (body.containsKey('enableRemoteAccess')) {
      await _settingsProvider.setEnableRemoteAccess(
          body['enableRemoteAccess'] as bool);
    }
    if (body.containsKey('followRemoteAccess')) {
      await _settingsProvider.setFollowRemoteAccess(
          body['followRemoteAccess'] as bool);
    }
    return _json({'ok': true});
  }

  Future<Response> _handlePairDevices(Request request) async {
    final devices = <Map<String, dynamic>>[];
    for (final d in _bleProvider.devices) {
      devices.add({
        'id': d.id,
        'name': d.displayName,
        'type': 'ble',
        'rssi': d.rssi,
      });
    }
    for (final p in _serialProvider.ports) {
      devices.add({
        'id': p.id,
        'name': p.displayName,
        'type': 'serial',
        'rssi': 0,
      });
    }
    return _json({'devices': devices});
  }

  Future<Response> _handlePairScan(Request request) async {
    final body = await _parseBody(request);
    final type = body['type'] as String?;
    if (type == null || (type != 'ble' && type != 'serial')) {
      return _error('invalid_type', "type must be 'ble' or 'serial'");
    }
    if (type == 'ble') {
      await _bleProvider.startScan();
    } else {
      await _serialProvider.startScan();
    }
    return _json({'ok': true, 'message': 'Scan started for $type'},
        status: 201);
  }

  Future<Response> _handleConnection(Request request) async {
    final device = _deviceProvider.connectedDevice;
    if (!_deviceProvider.isConnected || device == null) {
      return _json({
        'connected': false,
        'device': null,
        'configJson': null,
        'latencyMs': null,
        'rssi': null,
        'orientation': null,
      });
    }
    final orientation = _deviceProvider.orientation == kOrientationLandscape
        ? 'landscape'
        : 'portrait';
    return _json({
      'connected': true,
      'device': {
        'id': device.id,
        'name': device.displayName,
        'type': device.id.startsWith('demo_') ? 'demo' : 'ble',
        'configName': _deviceProvider.configName,
        'description': _deviceProvider.description,
        'hasFs': device.hasFs,
      },
      'configJson': _deviceProvider.deviceConfigJson,
      'latencyMs': _deviceProvider.latencyMs,
      'rssi': _deviceProvider.rssi,
      'orientation': orientation,
    });
  }

  Future<Response> _handleConnectionParams(Request request) async {
    final device = _deviceProvider.connectedDevice;
    if (!_deviceProvider.isConnected || device == null) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    
    // Try to get BLE info from the device (may timeout or fail)
    final bleInfo = await _deviceProvider.sendGetBleInfo();
    
    return _json({
      'connIntervalMs': bleInfo?['connIntervalMs'],
      'negotiatedMtu': bleInfo?['negotiatedMtu'],
      'rssi': _deviceProvider.rssi ?? bleInfo?['rssi'],
      'latencyMs': _deviceProvider.latencyMs,
      'deviceRssi': bleInfo?['rssi'],
    });
  }

  Future<Response> _handleConnect(Request request) async {
    final body = await _parseBody(request);
    final id = body['id'] as String?;
    final type = body['type'] as String?;

    if (id == null || type == null) {
      return _error('invalid_params', 'id and type are required');
    }

    final baudRate = (body['baudRate'] as num?)?.toInt() ?? 1000000;

    // Find device info
    DeviceInfo? target;
    if (type == 'ble') {
      target = _bleProvider.devices.where((d) => d.id == id).firstOrNull;
      if (target == null) {
        return _error('not_found', 'BLE device $id not found in scan results');
      }
      _deviceProvider.setTransport(_bleProvider.bleService);
    } else if (type == 'serial') {
      target = _serialProvider.ports.where((p) => p.id == id).firstOrNull;
      if (target == null) {
        return _error('not_found',
            'Serial device $id not found in scan results');
      }
      _deviceProvider.setTransport(_serialProvider.serialService);
    } else {
      return _error('invalid_type', "type must be 'ble' or 'serial'");
    }

    try {
      await _deviceProvider.connectToDevice(target, baudRate: baudRate);
    } catch (e) {
      return _error('connection_failed', e.toString(), status: 500);
    }

    if (!_deviceProvider.isConnected) {
      return _error('connection_failed',
          _deviceProvider.errorMessage ?? 'Connection failed',
          status: 500);
    }

    await _historyProvider.saveDevice(target, type);

    return _json({
      'ok': true,
      'message': 'Connected to ${target.displayName}',
    });
  }

  Future<Response> _handleDisconnect(Request request) async {
    await _deviceProvider.disconnect();
    return _json({'ok': true, 'message': 'Disconnected'});
  }

  Future<Response> _handleReconnect(Request request) async {
    final devices = _historyProvider.pairedDevices;
    if (devices.isEmpty) {
      return _error('no_history', 'No previously paired device found');
    }

    final last = devices.first;
    DeviceInfo info = last.toDeviceInfo();

    if (last.type == 'ble') {
      _deviceProvider.setTransport(_bleProvider.bleService);
    } else {
      _deviceProvider.setTransport(_serialProvider.serialService);
    }

    try {
      await _deviceProvider.connectToDevice(info);
    } catch (e) {
      return _error('connection_failed', e.toString(), status: 500);
    }

    if (!_deviceProvider.isConnected) {
      return _error('connection_failed',
          _deviceProvider.errorMessage ?? 'Reconnection failed',
          status: 500);
    }

    await _historyProvider.saveDevice(info, last.type);

    return _json({
      'ok': true,
      'message': 'Reconnected to ${last.name}',
    });
  }

  Future<Response> _handleModels(Request request) async {
    final models = _historyProvider.pairedDevices.map((d) => {
      'id': d.id,
      'name': d.name,
      'type': d.type,
      'configName': d.configName,
      'description': d.description,
    }).toList();
    return _json({'models': models});
  }

  Future<Response> _handleModelsDeleteAll(Request request) async {
    await _historyProvider.deleteAll();
    return _json({'ok': true, 'message': 'All models removed'});
  }

  Future<Response> _handleModelsDeleteOne(Request request, String id) async {
    final devices = _historyProvider.pairedDevices;
    final exists = devices.any((d) => d.id == id);
    if (!exists) {
      return _error('not_found', "No model with id '$id'", status: 404);
    }
    await _historyProvider.removeDevice(id);
    return _json({'ok': true, 'message': 'Model removed'});
  }

  Future<Response> _handleTransportSend(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }

    final body = await _parseBody(request);
    final cmd = body['cmd'] as int?;
    if (cmd == null) {
      return _error('invalid_params', 'cmd is required');
    }

    final payloadHex = body['payload'] as String? ?? '';
    List<int> payload = [];
    if (payloadHex.isNotEmpty) {
      final hex = payloadHex.replaceAll(RegExp(r'\s+'), '');
      if (hex.length.isOdd) {
        return _error('invalid_hex',
            'Payload must be an even-length hex string');
      }
      try {
        for (int i = 0; i < hex.length; i += 2) {
          payload.add(int.parse(hex.substring(i, i + 2), radix: 16));
        }
      } catch (_) {
        return _error('invalid_hex', 'Invalid hex string');
      }
    }

    try {
      final pkt = ProtocolService.buildPacket(cmd, payload);
      await _deviceProvider.currentTransport.writePacket(pkt);
      return _json({'ok': true, 'message': 'Packet sent'});
    } catch (e) {
      return _error('send_failed', e.toString(), status: 500);
    }
  }

  Future<Response> _handleTransportPing(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    try {
      await _deviceProvider.currentTransport
          .writePacket(ProtocolService.buildPing());
      return _json({'ok': true});
    } catch (e) {
      return _error('send_failed', e.toString(), status: 500);
    }
  }

  Future<Response> _handleTransportQuick(Request request, String cmd) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }

    var transport = _deviceProvider.currentTransport;
    try {
      switch (cmd) {
        case 'ping':
          await transport.writePacket(ProtocolService.buildPing());
        case 'get_conf':
          await transport.writePacket(ProtocolService.buildGetConf());
        case 'get_vars':
          await transport.writePacket(ProtocolService.buildGetVars());
        case 'get_meta':
          await transport.writePacket(ProtocolService.buildGetMeta());
        case 'get_tele':
          await transport.writePacket(ProtocolService.buildGetTelemetry());
        default:
          return _error('unknown_cmd', 'Unknown command: $cmd');
      }
      return _json({'ok': true});
    } catch (e) {
      return _error('send_failed', e.toString(), status: 500);
    }
  }

  Future<Response> _handleWidgets(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    final widgets = _deviceProvider.widgets;
    return _json({
      'widgets': widgets.map((w) => _widgetToJson(w)).toList(),
    });
  }

  Future<Response> _handleWidget(Request request, String id) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }

    final widgetId = int.tryParse(id);
    if (widgetId == null) {
      return _error('invalid_id', 'Widget ID must be an integer');
    }

    final widget = _deviceProvider.widgets
        .where((w) => w.widgetId == widgetId)
        .firstOrNull;
    if (widget == null) {
      return _error('not_found', 'Widget $id not found', status: 404);
    }

    return _json({'widget': _widgetToJson(widget)});
  }

  Future<Response> _handleWidgetSet(Request request, String id) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }

    final widgetId = int.tryParse(id);
    if (widgetId == null) {
      return _error('invalid_id', 'Widget ID must be an integer');
    }

    final widget = _deviceProvider.widgets
        .where((w) => w.widgetId == widgetId)
        .firstOrNull;
    if (widget == null) {
      return _error('not_found', 'Widget $id not found', status: 404);
    }

    if (!widget.hasInput) {
      return _error(
          'not_input', 'Widget $id is an output-only widget (LED/Text)');
    }

    final body = await _parseBody(request);
    final values = body['values'] as List<dynamic>?;
    if (values == null || values.isEmpty) {
      return _error('invalid_values', 'values array is required');
    }

    final intValues = values.map((v) => (v as num).toInt()).toList();

    if (widget.typeId == kWidgetJoystick && intValues.length != 2) {
      return _error('invalid_values',
          'Joystick expects exactly 2 values [x, y]');
    }

    try {
      await _deviceProvider.setInputValue(widgetId, intValues);
      return _json({
        'ok': true,
        'message': 'Widget $widgetId set to $intValues',
      });
    } catch (e) {
      return _error('set_failed', e.toString(), status: 500);
    }
  }

  // ── FS Handlers ─────────────────────────────────────────────────────────────

  bool _checkFs(Request request) {
    final device = _deviceProvider.connectedDevice;
    return _deviceProvider.isConnected && device != null && device.hasFs;
  }

  DeviceFsService _fsService() =>
      createDeviceFsService(_deviceProvider);

  Future<Response> _handleFsList(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    final path = request.url.queryParameters['path'] ?? '/';
    try {
      final entries = await _fsService().listDir(path);
      return _json({
        'path': path,
        'entries': entries
            .map((e) => {
              'name': e.name,
              'type': e.isDirectory ? 'directory' : 'file',
              'size': e.size,
            })
            .toList(),
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  Future<Response> _handleFsInfo(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    try {
      final info = await _fsService().getInfo();
      if (info == null) {
        return _error('fs_error', 'Failed to get FS info', status: 500);
      }
      return _json({
        'totalBytes': info.totalBytes,
        'usedBytes': info.usedBytes,
        'freeBytes': info.freeBytes,
        'blockSize': info.blockSize,
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  Future<Response> _handleFsRead(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    final path = request.url.queryParameters['path'];
    if (path == null || path.isEmpty) {
      return _error('invalid_params', 'path query parameter is required');
    }
    // Hold the FS busy lock for the entire multi-chunk read to prevent
    // the Follow Mode FS screen from interleaving its own FS operations
    // (listDir/getInfo) between chunks and corrupting the response stream.
    _deviceProvider.setFsBusy(true);
    try {
      final data = await _fsService().readFile(path);
      if (data == null) {
        return _error('not_found', 'File not found: $path', status: 404);
      }
      return _json({
        'path': path,
        'size': data.length,
        'encoding': 'base64',
        'data': base64Encode(data),
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    } finally {
      _deviceProvider.setFsBusy(false);
    }
  }

  Future<Response> _handleFsUpload(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    final dataB64 = body['data'] as String?;
    final chunkSize = body['chunkSize'] as int? ?? 0;
    if (path == null || dataB64 == null) {
      return _error('invalid_params', 'path and data are required');
    }
    _deviceProvider.setFsBusy(true);
    try {
      final data = base64Decode(dataB64);
      final result = chunkSize > 0
          ? await _fsService().writeFileUpload(path, data, chunkSize: chunkSize)
          : await _fsService().writeFileUpload(path, data);
      if (!result.success) {
        return _error('fs_error',
            '${result.errorName}: ${result.message}',
            status: 500);
      }
      return _json({
        'ok': true,
        'path': path,
        'bytesWritten': data.length,
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    } finally {
      _deviceProvider.setFsBusy(false);
    }
  }

  Future<Response> _handleFsWrite(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    final dataB64 = body['data'] as String?;
    if (path == null || dataB64 == null) {
      return _error('invalid_params', 'path and data are required');
    }
    // Hold the FS busy lock for the entire multi-chunk write to prevent
    // the Follow Mode FS screen from interleaving its own FS operations.
    _deviceProvider.setFsBusy(true);
    try {
      final data = base64Decode(dataB64);
      final result = await _fsService().writeFile(path, data);
      if (!result.success) {
        return _error('fs_error',
            '${result.errorName}: ${result.message}',
            status: 500);
      }
      return _json({
        'ok': true,
        'path': path,
        'bytesWritten': data.length,
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    } finally {
      _deviceProvider.setFsBusy(false);
    }
  }

  Future<Response> _handleFsMkdir(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    if (path == null) {
      return _error('invalid_params', 'path is required');
    }
    try {
      final result = await _fsService().mkdir(path);
      if (!result.success) {
        return _error('fs_error',
            '${result.errorName}: ${result.message}',
            status: 500);
      }
      return _json({'ok': true, 'path': path});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  Future<Response> _handleFsDelete(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    if (path == null) {
      return _error('invalid_params', 'path is required');
    }
    final recursive = body['recursive'] as bool? ?? false;
    try {
      final result = await _fsService().delete(path, recursive: recursive);
      if (!result.success) {
        return _error('fs_error',
            '${result.errorName}: ${result.message}',
            status: 500);
      }
      return _json({'ok': true, 'path': path});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  Future<Response> _handleFsRename(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    final body = await _parseBody(request);
    final oldPath = body['oldPath'] as String?;
    final newPath = body['newPath'] as String?;
    if (oldPath == null || newPath == null) {
      return _error('invalid_params', 'oldPath and newPath are required');
    }
    try {
      final result = await _fsService().rename(oldPath, newPath);
      if (!result.success) {
        return _error('fs_error',
            '${result.errorName}: ${result.message}',
            status: 500);
      }
      return _json({'ok': true, 'oldPath': oldPath, 'newPath': newPath});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  Future<Response> _handleFsFormat(Request request) async {
    if (!_checkFs(request)) {
      return _error('not_connected', 'Not connected or device has no FS',
          status: 503);
    }
    try {
      final result = await _fsService().format();
      if (!result.success) {
        return _error('fs_error',
            '${result.errorName}: ${result.message}',
            status: 500);
      }
      return _json({'ok': true, 'message': 'Filesystem formatted'});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  // ── Console Log ──────────────────────────────────────────────────────────────

  Future<Response> _handleConsole(Request request) async {
    final entries = _consoleProvider.entries.map((e) => {
      'timestamp': e.timestamp.toIso8601String(),
      'level': e.level.name,
      'message': e.message,
    }).toList();
    return _json({'entries': entries});
  }

  Future<Response> _handleConsoleClear(Request request) async {
    _consoleProvider.clear();
    return _json({'ok': true});
  }

  // ── Demo Loading ──────────────────────────────────────────────────────────────

  Future<Response> _handleConnectionDemo(Request request) async {
    final body = await _parseBody(request);
    final demoId = body['demoId'] as String?;

    if (demoId == null) {
      return _error('invalid_params', 'demoId is required');
    }

    const validDemos = {'WIDGETS_DEMO', 'RC_CONTROLLER', 'IOT_DASHBOARD'};
    if (!validDemos.contains(demoId)) {
      return _error('demo_not_found', 'Invalid demo ID: $demoId');
    }

    try {
      await _deviceProvider.loadDemo(demoId);
    } catch (e) {
      return _error('demo_load_failed', e.toString(), status: 500);
    }

    if (!_deviceProvider.isConnected) {
      return _error('demo_load_failed',
          _deviceProvider.errorMessage ?? 'Failed to load demo',
          status: 500);
    }

    final count = _deviceProvider.widgets.length;
    return _json({
      'ok': true,
      'message': 'Demo $demoId loaded with $count widgets',
    });
  }

  // ── Session / Route ──────────────────────────────────────────────────────────

  Future<Response> _handleSessionRoute(Request request) async {
    return _json({
      'route': _currentRouteGetter(),
    });
  }

  // ── Designs ──────────────────────────────────────────────────────────────────

  Future<Response> _handleDesigns(Request request) async {
    final designs = _designsProvider.designs.map((d) => {
      'id': d.id,
      'name': d.name,
      'timestamp': d.timestamp,
      'jsonContent': d.jsonContent,
      'filePath': d.filePath,
      'appVersion': d.appVersion,
    }).toList();
    return _json({'designs': designs});
  }

  Future<Response> _handleDesignsSave(Request request) async {
    final body = await _parseBody(request);
    final id = body['id'] as String?;
    final name = body['name'] as String?;
    final jsonContent = body['jsonContent'] as String?;

    if (id == null || name == null || jsonContent == null) {
      return _error('invalid_params', 'id, name, and jsonContent are required');
    }

    try {
      await _designsProvider.saveDesign(id, name, jsonContent);
      return _json({'ok': true, 'message': 'Design saved'});
    } catch (e) {
      return _error('save_failed', e.toString(), status: 500);
    }
  }

  Future<Response> _handleDesignsDeleteAll(Request request) async {
    // DesignsProvider doesn't have deleteAll, so iterate
    for (final d in _designsProvider.designs.toList()) {
      await _designsProvider.deleteDesign(d.id);
    }
    return _json({'ok': true, 'message': 'All designs removed'});
  }

  Future<Response> _handleDesignsDeleteOne(
      Request request, String id) async {
    final exists = _designsProvider.designs.any((d) => d.id == id);
    if (!exists) {
      return _error('not_found', 'Design not found: $id', status: 404);
    }
    await _designsProvider.deleteDesign(id);
    return _json({'ok': true, 'message': 'Design removed'});
  }

  // ── FS Probe ──────────────────────────────────────────────────────────────────

  Future<Response> _handleFsProbe(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    // Force re-detect FS by temporarily bypassing the cached hasFs
    final device = _deviceProvider.connectedDevice;
    if (device == null) {
      return _error('not_connected', 'No device info', status: 503);
    }
    // Try a direct FS read to test the transport
    try {
      await _deviceProvider.currentTransport.writePacket(
          FsProtocolService.buildPing());
      await Future.delayed(const Duration(milliseconds: 2000));
    } catch (e) {
      return _error('fs_probe_failed', e.toString(), status: 500);
    }
    final hasFs = device.hasFs;
    return _json({
      'ok': true,
      'hasFs': hasFs,
    });
  }
}
