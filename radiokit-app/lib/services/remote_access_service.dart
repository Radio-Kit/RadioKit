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
import 'settings_protocol_service.dart';
import '../providers/device_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/serial_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/console_provider.dart';
import '../providers/designs_provider.dart';
import 'device_fs_service.dart';
import 'fs_protocol_service.dart';
import 'transport_service.dart';
import 'websocket_service.dart';
import 'cloud_identity.dart';
import '../providers/cloud_identity_provider.dart';
import '../providers/account_provider.dart';
import '../providers/flasher_provider.dart';
import '../providers/multi_device_provider.dart';
import 'ble_transport.dart';
import 'demo_transport.dart';
import '../models/account.dart';
import 'docs_service.dart';
import 'library_service.dart';
import '../screens/designer/codegen/json_arduino_generator.dart';

class RemoteAccessService {
  final DeviceProvider Function() _getActiveDevice;
  DeviceProvider get _deviceProvider => _getActiveDevice();
  final BleProvider _bleProvider;
  final SerialProvider _serialProvider;
  final HistoryProvider _historyProvider;
  final SettingsProvider _settingsProvider;
  final ConsoleProvider _consoleProvider;
  final DesignsProvider _designsProvider;
  final CloudIdentityProvider _cloudIdentityProvider;
  final AccountProvider _accountProvider;
  final FlasherProvider _flasherProvider;
  final MultiDeviceProvider Function()? _getMultiDevice;
  final void Function(ApiLogEntry) _onLog;
  final void Function(String route)? _onFollowEvent;
  final Map<String, dynamic> Function()? _viewStateGetter;
  final String Function() _currentRouteGetter;
  final Future<dynamic> Function(String demoId)? _connectDemo;
  final DocsService? _docsService;
  final LibraryService? _libraryService;

  HttpServer? _server;
  bool _isRunning = false;
  int _actualPort = 0;
  String _cachedLocalIp = '127.0.0.1';

  bool get isRunning => _isRunning;
  int get actualPort => _actualPort;

  String get localIp => _cachedLocalIp;

  RemoteAccessService({
    required DeviceProvider Function() getActiveDevice,
    required BleProvider bleProvider,
    required SerialProvider serialProvider,
    required HistoryProvider historyProvider,
    required SettingsProvider settingsProvider,
    required ConsoleProvider consoleProvider,
    required DesignsProvider designsProvider,
    required CloudIdentityProvider cloudIdentityProvider,
    required AccountProvider accountProvider,
    required FlasherProvider flasherProvider,
    MultiDeviceProvider Function()? getMultiDevice,
    required void Function(ApiLogEntry) onLog,
    void Function(String route)? onFollowEvent,
  String Function() currentRouteGetter = _defaultRouteGetter,
  Map<String, dynamic> Function()? viewStateGetter,
  Future<void> Function(String demoId)? connectDemo,
  DocsService? docsService,
  LibraryService? libraryService,
  })  :        _getActiveDevice = getActiveDevice,
        _bleProvider = bleProvider,
        _serialProvider = serialProvider,
        _historyProvider = historyProvider,
        _settingsProvider = settingsProvider,
        _consoleProvider = consoleProvider,
        _designsProvider = designsProvider,
        _cloudIdentityProvider = cloudIdentityProvider,
        _accountProvider = accountProvider,
        _flasherProvider = flasherProvider,
        _getMultiDevice = getMultiDevice,
        _onLog = onLog,
        _onFollowEvent = onFollowEvent,
      _viewStateGetter = viewStateGetter,
        _currentRouteGetter = currentRouteGetter,
        _connectDemo = connectDemo,
        _docsService = docsService,
        _libraryService = libraryService;

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
          if (route != null) _onFollowEvent(route);
        }

        return response;
      };
    };
  }


  /// Defines which follow-mode sheets are available on each route.
  /// Single source of truth for both [_followRoute] and [_handleSessionSheets].
  static const Map<String, List<String>> _sheetDefinitions = {
    '/models': ['pair', 'deviceSettings'],
    '/system': ['accounts'],
    '/control': <String>[],
    '/dev-tools/esp32-fs': <String>[],
    '/designs': <String>[],
    '/debug': <String>[],
  };

  /// Appends the sheet query parameter to [route] if [sheetName] is defined
  /// in [_sheetDefinitions] for that route.
  static String _applySheet(String route, String sheetName) {
    final sheets = _sheetDefinitions[route];
    if (sheets != null && sheets.contains(sheetName)) {
      return '$route?sheet=$sheetName';
    }
    return route;
  }

  static String? _followRoute(String path) {

    if (path.startsWith('/api/devices/connect')) return '/control';
    if (path.endsWith('/console') && path.startsWith('/api/devices/')) return '/system';
    if (path.endsWith('/fs/format') && path.startsWith('/api/devices/')) return '/dev-tools/esp32-fs';
    if (path.endsWith('/ota/progress') && path.startsWith('/api/devices/')) return '/control';
    if (path.endsWith('/ota/upload') && path.startsWith('/api/devices/')) return '/control';
    if (path.endsWith('/fs/rename') && path.startsWith('/api/devices/')) return '/dev-tools/esp32-fs';
    if (path.endsWith('/fs/probe') && path.startsWith('/api/devices/')) return '/dev-tools/esp32-fs';
    if (path.endsWith('/transport/ping') && path.startsWith('/api/devices/')) return '/control';
    if (path.endsWith('/transport/wifi_info') && path.startsWith('/api/devices/')) return '/control';
    if (path.startsWith('/api/devices/') && path.endsWith('/transport/get_conf')) return '/control';
    if (path.startsWith('/api/devices/') && path.endsWith('/transport/get_vars')) return '/control';
    if (path.startsWith('/api/devices/') && path.endsWith('/transport/get_meta')) return '/control';
    if (path.startsWith('/api/devices/') && path.endsWith('/transport/get_tele')) return '/control';
    if (path.startsWith('/api/devices/') && path.contains('/settings/')) return _applySheet('/models', 'deviceSettings');
    if (path.startsWith('/api/devices/disconnect')) return '/models';
    if (path == '/api/devices') return '/models';
    if (path.startsWith('/api/pair/')) return _applySheet('/models', 'pair');
    if (path.startsWith('/api/connection/connect')) return '/control';
    if (path.startsWith('/api/connection/disconnect')) return '/models';
    if (path.startsWith('/api/connection/reconnect')) return '/models';
    if (path.startsWith('/api/connection/demo')) return '/control';
    if (path == '/api/widgets' || path.startsWith('/api/widgets/')) return '/control';
    if (path.startsWith('/api/ota/')) return '/control';
    if (path.startsWith('/api/fs/')) return '/dev-tools/esp32-fs';
    if (path.startsWith('/api/designs')) return '/designs';
    if (path.startsWith('/api/transport/')) return '/debug';
    // /api/settings (app-level) excluded: toggling followRemoteAccess via API
    // would navigate away from /control, disconnecting the active BLE device.
    // Device-level /api/settings/nvs paths still navigate to /system.
    if (path.startsWith('/api/settings/nvs')) return '/system';
    if (path == '/api/settings') return null;
    if (path.startsWith('/api/cloud/accounts')) return _applySheet('/system', 'accounts');
    if (path.startsWith('/api/cloud/account')) return _applySheet('/system', 'accounts');
    if (path == '/api/page' || path.startsWith('/api/pages')) return '/control';
    if (path.startsWith('/api/console')) return '/system';
    if (path.startsWith('/api/log')) return '/system';
    if (path.startsWith('/api/models')) return '/models';
    if (path.startsWith('/api/flasher/')) return '/flasher';
    if (path.startsWith('/api/library/')) return null;
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
    router.get('/api/settings/nvs', _handleNvsGet);
    router.post('/api/settings/nvs', _handleNvsSet);
    router.post('/api/settings/nvs/authenticate', _handleNvsAuthenticate);
    router.post('/api/settings/nvs/factory-reset', _handleNvsFactoryReset);
    router.post('/api/settings/nvs/reboot', _handleNvsReboot);
    router.get('/api/settings/nvs/raw/<key>', _handleNvsRawRead);
    router.post('/api/settings/nvs/raw/<key>', _handleNvsRawWrite);
    router.get('/api/settings/nvs/cloud-info', _handleNvsCloudInfo);
    router.get('/api/pair/devices', _handlePairDevices);
    router.post('/api/pair/scan', _handlePairScan);
    router.get('/api/connection', _handleConnection);
    router.get('/api/connection/params', _handleConnectionParams);
    router.post('/api/connection/connect', _handleConnect);
    router.post('/api/connection/disconnect', _handleDisconnect);
    router.post('/api/connection/switch', _handleConnectionSwitch);
    router.post('/api/connection/reconnect', _handleReconnect);
    router.get('/api/models', _handleModels);
    router.delete('/api/models', _handleModelsDeleteAll);
    router.delete('/api/models/<id>', _handleModelsDeleteOne);
    router.post('/api/transport/send', _handleTransportSend);
    router.post('/api/transport/ping', _handleTransportPing);
    router.post('/api/transport/wifi_info', _handleTransportWifiInfo);
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
    router.post('/api/ota/upload', _handleOtaUpload);
    router.get('/api/ota/progress', _handleOtaProgress);
    router.get('/api/console', _handleConsole);
    router.delete('/api/console', _handleConsoleClear);
    router.post('/api/connection/demo', _handleConnectionDemo);
    router.get('/api/designs', _handleDesigns);
    router.post('/api/designs', _handleDesignsSave);
    router.get('/api/designs/<id>/json', _handleDesignJson);
    router.get('/api/designs/<id>/header', _handleDesignHeader);
    router.delete('/api/designs', _handleDesignsDeleteAll);
    router.delete('/api/designs/<id>', _handleDesignsDeleteOne);
    router.get('/api/session/route', _handleSessionRoute);
    router.get('/api/session/state', _handleSessionState);
    router.get('/api/session/sheets', _handleSessionSheets);

    // ── Library API ──────────────────────────────────────────────────
    router.get('/api/library/version', _handleLibraryVersion);
    router.get('/api/library/download', _handleLibraryDownload);

    // ── Flasher API ───────────────────────────────────────────────────
    router.get('/api/flasher/ports', _handleFlasherPorts);
    router.post('/api/flasher/scan', _handleFlasherScan);
    router.post('/api/flasher/connect', _handleFlasherConnect);
    router.post('/api/flasher/disconnect', _handleFlasherDisconnect);
    router.get('/api/flasher/status', _handleFlasherStatus);
    router.get('/api/flasher/log', _handleFlasherLog);
    router.post('/api/flasher/log/clear', _handleFlasherLogClear);
    router.post('/api/flasher/select-firmware', _handleFlasherSelectFirmware);
    router.post('/api/flasher/clear-firmware', _handleFlasherClearFirmware);
    router.post('/api/flasher/erase-all', _handleFlasherEraseAll);
    router.post('/api/flasher/flash', _handleFlasherFlash);

    // ── Multi-device API ────────────────────────────────────────────────
    router.get('/api/devices', _handleDevices);
    router.post('/api/devices/connect', _handleDeviceConnect);
    router.post('/api/devices/disconnect', _handleDeviceDisconnect);
    router.get('/api/devices/<id>', _handleDeviceInfo);
    router.get('/api/devices/<id>/widgets', _handleDeviceWidgets);
    router.put('/api/devices/<id>/widgets/<wid>', _handleDeviceWidgetSet);
    router.get('/api/devices/<id>/console', _handleDeviceConsole);
    router.get('/api/devices/<id>/fs/list', _handleDeviceFsList);
    router.get('/api/devices/<id>/fs/info', _handleDeviceFsInfo);
    router.get('/api/devices/<id>/fs/read', _handleDeviceFsRead);
    router.post('/api/devices/<id>/fs/write', _handleDeviceFsWrite);
    router.post('/api/devices/<id>/fs/upload', _handleDeviceFsUpload);
    router.post('/api/devices/<id>/fs/mkdir', _handleDeviceFsMkdir);
    router.post('/api/devices/<id>/fs/delete', _handleDeviceFsDelete);
    router.post('/api/devices/<id>/transport/send', _handleDeviceTransportSend);
    router.delete('/api/devices/<id>/console', _handleDeviceConsoleClear);
    router.post('/api/devices/<id>/fs/format', _handleDeviceFsFormat);
    router.get('/api/devices/<id>/ota/progress', _handleDeviceOtaProgress);
    router.post('/api/devices/<id>/ota/upload', _handleDeviceOtaUpload);
    router.post('/api/devices/<id>/fs/rename', _handleDeviceFsRename);
    router.post('/api/devices/<id>/fs/probe', _handleDeviceFsProbe);
    router.post('/api/devices/<id>/transport/ping', _handleDeviceTransportPing);
    router.post('/api/devices/<id>/transport/wifi_info', _handleDeviceTransportWifiInfo);
    router.post('/api/devices/<id>/transport/<cmd>', _handleDeviceTransportQuick);
    router.get('/api/devices/<id>/settings/nvs', _handleDeviceNvsGet);
    router.post('/api/devices/<id>/settings/nvs', _handleDeviceNvsSet);
    router.post('/api/devices/<id>/settings/nvs/authenticate', _handleDeviceNvsAuthenticate);
    router.post('/api/devices/<id>/settings/nvs/factory-reset', _handleDeviceNvsFactoryReset);
    router.post('/api/devices/<id>/settings/nvs/reboot', _handleDeviceNvsReboot);
    router.get('/api/devices/<id>/settings/nvs/raw/<key>', _handleDeviceNvsRawRead);
    router.post('/api/devices/<id>/settings/nvs/raw/<key>', _handleDeviceNvsRawWrite);
    router.get('/api/devices/<id>/settings/nvs/cloud-info', _handleDeviceNvsCloudInfo);
    router.get('/api/devices/<id>/widgets/<wid>', _handleDeviceWidgetInfo);

    // ── Page API ──────────────────────────────────────────────────────
    router.get('/api/page', _handleGetPage);
    router.post('/api/page', _handleSetPage);
    router.get('/api/pages', _handleGetPages);

    // ── Cloud relay API ────────────────────────────────────────────────
    router.post('/api/cloud/connect', _handleCloudConnect);
    router.get('/api/cloud/devices', _handleCloudDevices);
    router.post('/api/cloud/join', _handleCloudJoin);
    router.post('/api/cloud/disconnect', _handleCloudDisconnect);
    router.get('/api/cloud/account', _handleCloudAccount);
    router.post('/api/cloud/account', _handleCloudAccountReset);
    router.get('/api/cloud/accounts', _handleCloudAccountsList);
    router.post('/api/cloud/accounts', _handleCloudAccountsCreate);
    router.put('/api/cloud/accounts/<id>', _handleCloudAccountsUpdate);
    router.delete('/api/cloud/accounts/<id>', _handleCloudAccountsDelete);

    // ── Docs API ───────────────────────────────────────────────────────
    if (_docsService != null) {
      router.get('/', _handleLlmsTxt);
      router.get('/api/docs', _handleDocsIndex);
      router.get('/api/docs/api-schema', _handleDocsSchema);
      router.get('/api/docs/<skill>', _handleDocsSkill);
    }

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
        // 0x02 is RK_TYPE_TOGGLE_BUTTON on the wire.
        return 'button';
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
      case kWidgetTelemetry:
        return 'telemetry';
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

  /// Serialize a [WidgetConfig] + optional state to JSON.
  /// When [dp] is provided, reads state from that provider (multi-device).
  /// When null, reads from the default [DeviceProvider] (single-device).
  Map<String, dynamic> _widgetToJson(WidgetConfig w, {DeviceProvider? dp}) {
    final provider = dp ?? _deviceProvider;
    final state = provider.widgetState;
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

    final Map<String, dynamic> json = {
      'widgetId': w.widgetId,
      'type': _widgetTypeName(w.typeId),
      'name': w.label.isNotEmpty ? w.label : 'widget_${w.widgetId}',
      'label': w.label,
      'hidden': w.hidden,
      'hasOutput': w.hasOutput,
      'hasInput': w.hasInput,
      'state': stateJson,
    };

    // Include geometry only for single-device endpoints (backwards compat)
    if (dp == null) {
      json['x'] = w.x;
      json['y'] = w.y;
      json['rotation'] = w.rotationDegrees;
      json['variant'] = _variantName(w.typeId, w.variant);
    }

    return json;
  }

  final List<ApiLogEntry> _logEntries = [];

  /// Current OTA upload progress — set by [_handleOtaUpload] during upload,
  /// read by [_handleOtaProgress]. Reset on upload completion/error.
  (int, int, String)? _otaProgress;

  /// Per-device OTA progress keyed by device ID.
  final Map<String, (int, int, String)?> _deviceOtaProgress = {};

  // ── Cloud relay state ───────────────────────────────────────────────────

  /// Active WebSocketService for the cloud relay connection.
  WebSocketService? _cloudWs;

  // ── Account Management ────────────────────────────────────────────────────

  /// Handle GET /api/cloud/account — returns current Ed25519 identity info.
  /// The account public key is what users set on their ESP32 devices.
  Future<Response> _handleCloudAccount(Request request) async {
    final identityProvider = _cloudIdentityProvider;
    if (!identityProvider.hasIdentity) {
      return _json({
        'hasIdentity': false,
        'account': null,
      });
    }
    return _json({
      'hasIdentity': true,
      'account': identityProvider.account,
    });
  }

  /// Handle POST /api/cloud/account — generate a new Ed25519 identity.
  /// This resets the account. After calling this, you must update the
  /// cloud_account config on your ESP32 device to match the new public key.
  Future<Response> _handleCloudAccountReset(Request request) async {
    await _cloudIdentityProvider.resetIdentity();
    return _json({
      'ok': true,
      'account': _cloudIdentityProvider.account,
      'message': 'New Ed25519 identity generated. Set cloud_account on your ESP32 to the public key above.',
    });
  }

  // ── Account Management Handlers ────────────────────────────────────────

  /// Handle GET /api/cloud/accounts — list all stored accounts.
  Future<Response> _handleCloudAccountsList(Request request) async {
    return _json({
      'accounts': _accountProvider.accounts.map((a) => {
        'id': a.id,
        'name': a.name,
        'publicKey': a.publicKey,
        'relay': a.relay,
      }).toList(),
    });
  }

  /// Handle POST /api/cloud/accounts — create a new account with name and relay.
  /// Body: { "name": "Local Relay", "relay": "ws://10.0.0.17:9000" }
  /// Uses the existing Ed25519 keypair from CloudIdentityService.
  Future<Response> _handleCloudAccountsCreate(Request request) async {
    final body = await _parseBody(request);
    final name = body['name'] as String?;
    final relay = body['relay'] as String? ?? '';

    if (name == null || name.trim().isEmpty) {
      return _error('invalid_params', 'name is required');
    }

    // Use existing Ed25519 keypair from CloudIdentityService
    final identityProvider = _cloudIdentityProvider;
    if (!identityProvider.hasIdentity) {
      await identityProvider.initialize();
    }

    final publicKey = identityProvider.account ?? '';
    final privateKey = identityProvider.identityService.privateKeyHex ?? '';

    if (publicKey.isEmpty || privateKey.isEmpty) {
      return _error('no_identity', 'No Ed25519 identity found. Generate one first via POST /api/cloud/account', status: 400);
    }

    final account = Account(
      id: DateTime.now().millisecondsSinceEpoch.toRadixString(36),
      name: name.trim(),
      publicKey: publicKey,
      privateKey: privateKey,
      relay: relay.trim(),
    );

    await _accountProvider.addAccount(account);

    return _json({
      'ok': true,
      'account': {
        'id': account.id,
        'name': account.name,
        'publicKey': account.publicKey,
        'relay': account.relay,
      },
    });
  }

  /// Handle PUT /api/cloud/accounts/<id> — update an account's name/relay.
  /// Body: { "name": "...", "relay": "..." }
  Future<Response> _handleCloudAccountsUpdate(Request request, String id) async {
    final body = await _parseBody(request);
    final name = body['name'] as String?;
    final relay = body['relay'] as String?;

    if (name == null && relay == null) {
      return _error('invalid_params', 'At least one of: name, relay');
    }

    // Check account exists
    final exists = _accountProvider.accounts.any((a) => a.id == id);
    if (!exists) {
      return _error('not_found', 'Account $id not found', status: 404);
    }

    await _accountProvider.updateAccount(id, name: name, relay: relay);
    return _json({'ok': true});
  }

  /// Handle DELETE /api/cloud/accounts/<id> — delete an account.
  Future<Response> _handleCloudAccountsDelete(Request request, String id) async {
    final exists = _accountProvider.accounts.any((a) => a.id == id);
    if (!exists) {
      return _error('not_found', 'Account $id not found', status: 404);
    }
    await _accountProvider.deleteAccount(id);
    return _json({'ok': true, 'message': 'Account deleted'});
  }

  // ── Docs Handlers ────────────────────────────────────────────────────────

  Future<Response> _handleLlmsTxt(Request request) async {
    final llmsTxt = _docsService?.getLlmsTxt() ?? '# RadioKit API\n\nNo documentation loaded.';
    return Response.ok(
      llmsTxt,
      headers: {'content-type': 'text/plain; charset=utf-8'},
    );
  }

  Future<Response> _handleDocsIndex(Request request) async {
    if (_docsService == null) {
      return _error('not_available', 'Docs service not initialized');
    }
    final skills = _docsService.getSkillsIndex();
    return _json({'skills': skills});
  }

  Future<Response> _handleDocsSkill(Request request, String skill) async {
    if (_docsService == null) {
      return _error('not_available', 'Docs service not initialized');
    }
    final doc = _docsService.getSkillContent(skill);
    if (doc == null) {
      return _error('not_found', 'Skill not found: $skill', status: 404);
    }
    return _json(doc.toJson());
  }

  Future<Response> _handleDocsSchema(Request request) async {
    if (_docsService == null) {
      return _error('not_available', 'Docs service not initialized');
    }
    return _json(_docsService.getApiSchema());
  }

  /// Last device list returned by the relay.
  List<String> _cloudDevices = [];

  /// Cloud relay connection params.
  String _cloudHost = '';
  int _cloudPort = 0;
  String _cloudAccount = '';

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
      'useFullscreen': _settingsProvider.useFullscreen,
      'enableRemoteAccess': _settingsProvider.enableRemoteAccess,
      'followRemoteAccess': _settingsProvider.followRemoteAccess,
    });
  }

  Future<Response> _handleSettingsUpdate(Request request) async {
    final body = await _parseBody(request);
    if (body.containsKey('useFullscreen')) {
      await _settingsProvider.setUseFullscreen(body['useFullscreen'] as bool);
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
        'type': device.id.startsWith('demo_')
        ? 'demo'
        : device.id.startsWith('ws://') || device.id.startsWith('wss://')
            ? 'wifi'
            : 'ble',
        'configName': _deviceProvider.configName,
        'description': _deviceProvider.description,
        'hasFs': device.hasFs,
        'hasOta': _deviceProvider.hasOta,
        'deviceIcon': device.deviceIcon,
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

    final baudRate = (body['baudRate'] as num?)?.toInt() ?? 115200;

    // Find device info
    DeviceInfo? target;
    if (type == 'ble') {
      target = _bleProvider.devices.where((d) => d.id == id).firstOrNull;
      if (target == null) {
        return _error('not_found', 'BLE device $id not found in scan results');
      }
      TransportService transport = BleTransport(_bleProvider.bleService);
      _deviceProvider.setTransport(transport);
    } else if (type == 'serial') {
      target = _serialProvider.ports.where((p) => p.id == id).firstOrNull;
      if (target == null) {
        // Fall back to flasher's last connected port (auto-handoff after flash).
        if (_flasherProvider.lastPortId == id) {
          await _flasherProvider.handoffSerial();
          // Scan for the device via serial provider. Now both the serial
          // provider and the flasher use flserial, so port IDs match
          // exactly (usb:/dev/bus/usb/... format).
          await _serialProvider.startScan();
          await Future.delayed(const Duration(seconds: 3));
          if (_serialProvider.ports.isNotEmpty) {
            // Exact port ID match — both use the same library now.
            target = _serialProvider.ports
                .where((p) => p.id == id)
                .firstOrNull;
            // Fallback: any ESP-compatible port by name.
            target ??= _serialProvider.ports.where((p) {
              final n = p.name.toLowerCase();
              return n.contains('espressif') ||
                  n.contains('esp32') || n.contains('esp8266') ||
                  n.contains('cp210') || n.contains('ch340') ||
                  n.contains('ch910') || n.contains('silicon labs') ||
                  n.startsWith('ftdi');
            }).firstOrNull;
            // Last resort: pick the first available port.
            target ??= _serialProvider.ports.first;
            _deviceProvider.setTransport(_serialProvider.serialService);
            await _serialProvider.stopScan();
          } else {
            return _error('not_found',
                'No serial ports found after flasher handoff. '
                'Try reconnecting the device manually.');
          }
        } else {
          return _error('not_found',
              'Serial device $id not found in scan results');
        }
      } else {
        _deviceProvider.setTransport(_serialProvider.serialService);
      }
    } else if (type == 'wifi') {
      if (!id.startsWith('ws://') && !id.startsWith('wss://')) {
        return _error('invalid_url', 'WiFi ID must be a WebSocket URL (ws:// or wss://)');
      }
      target = DeviceInfo(
        id: id,
        name: Uri.tryParse(id)?.host ?? id,
        rssi: 0,
        hasFs: false,
        currentTransport: TransportType.wifi,
        transportAddress: id,
      );
      _deviceProvider.setTransport(WebSocketService());
    } else {
      return _error('invalid_type', "type must be 'ble', 'serial', or 'wifi'");
    }

    try {
      final multi = _getMulti();
      if (multi != null) {
        final transport = type == 'ble'
            ? BleTransport(_bleProvider.bleService)
            : type == 'serial'
                ? _serialProvider.serialService
                : WebSocketService();
        final dp = await multi.connectDevice(
          device: target,
          transport: transport,
          baudRate: baudRate,
        );
        multi.setFocusedDevice(dp.connectedDevice?.id ?? target.id);
      } else {
        await _deviceProvider.connectToDevice(target, baudRate: baudRate);
      }
    } catch (e) {
      return _error('connection_failed', e.toString(), status: 500);
    }

    final activeDp = _getMulti()?.primaryDevice ?? _deviceProvider;
    if (!activeDp.isConnected) {
      return _error('connection_failed',
          activeDp.errorMessage ?? 'Connection failed',
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

  /// Handle POST /api/connection/switch — switch transport (ble, wifi, cloud).
  /// Body: { "transport": "wifi" }
  /// Does connect-first: connects to target while source is still active,
  /// then disconnects source on success.
  Future<Response> _handleConnectionSwitch(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    final body = await _parseBody(request);
    final transportStr = body['transport'] as String?;
    if (transportStr == null) {
      return _error('invalid_params', 'transport is required (ble, wifi, cloud)');
    }

    TransportType target;
    switch (transportStr) {
      case 'ble':
        target = TransportType.ble;
        break;
      case 'wifi':
        target = TransportType.wifi;
        break;
      case 'cloud':
        target = TransportType.cloud;
        break;
      default:
        return _error('invalid_transport', "transport must be 'ble', 'wifi', or 'cloud'");
    }

    try {
      final ok = await _deviceProvider.switchTransport(target);
      if (ok) {
        return _json({
          'ok': true,
          'message': 'Switched to $transportStr',
          'transport': transportStr,
        });
      }
      return _error('switch_failed',
          'Failed to switch to $transportStr — target transport unreachable',
          status: 500);
    } catch (e) {
      return _error('switch_error', e.toString(), status: 500);
    }
  }

  /// Reconnect to a previously paired device, trying available transports
  /// in priority order until one succeeds. Uses parallel availability checks.
  Future<Response> _handleReconnect(Request request) async {
    final devices = _historyProvider.pairedDevices;
    if (devices.isEmpty) {
      return _error('no_history', 'No previously paired device found');
    }

    final last = devices.first;

    // Build prioritized list of transports to try.
    // Order: last used first, then remaining transports, then cloud if account matches.
    final seen = <String>{};
    final attempts = <(String, TransportType, String, TransportService Function())>[];

    void addIf(String key, TransportType type, String? address, TransportService Function() factory) {
      if (address == null || address.isEmpty || seen.contains(key)) return;
      seen.add(key);
      attempts.add((type.name, type, address, factory));
    }

    // 1. Last-used transport first
    if (last.lastUsedTransport == 'wifi') addIf('wifi', TransportType.wifi, last.wifiAddress, () => WebSocketService());
    if (last.lastUsedTransport == 'ble') addIf('ble', TransportType.ble, last.bleAddress, () => _bleProvider.bleService);
    if (last.lastUsedTransport == 'cloud') addIf('cloud', TransportType.cloud, last.cloudAddress, () => WebSocketService());
    if (last.lastUsedTransport == 'serial') addIf('serial', TransportType.serial, last.serialAddress, () => _serialProvider.serialService);

    // 2. Then remaining transports
    addIf('wifi', TransportType.wifi, last.wifiAddress, () => WebSocketService());
    addIf('ble', TransportType.ble, last.bleAddress, () => _bleProvider.bleService);
    addIf('serial', TransportType.serial, last.serialAddress, () => _serialProvider.serialService);

    // 3. Cloud fallback: only if cached cloud account matches app identity
    if (last.cloudAccount != null && last.cloudAccount!.isNotEmpty) {
      final identity = CloudIdentityService();
      await identity.initialize();
      if (identity.hasIdentity && identity.account == last.cloudAccount) {
        String? cloudAddr = last.cloudAddress;
        if (cloudAddr == null || cloudAddr.isEmpty) {
          if (_cloudWs != null && _cloudWs!.isConnected) {
            cloudAddr = 'cloud://${_cloudWs!.account ?? "relay"}';
          }
        }
        addIf('cloud', TransportType.cloud, cloudAddr, () {
          if (_cloudWs != null && _cloudWs!.isConnected &&
              _cloudWs!.account != null && _cloudWs!.identity != null) {
            return _cloudWs!;
          }
          final ws = WebSocketService()
            ..account = identity.account
            ..identity = identity;
          _cloudWs = ws;
          return ws;
        });
      }
    }

    // 4. Fallback: no addresses found — try original toDeviceInfo() logic
    if (attempts.isEmpty) {
      DeviceInfo info = last.toDeviceInfo();
      switch (info.currentTransport) {
        case TransportType.ble:
          _deviceProvider.setTransport(_bleProvider.bleService);
          break;
        case TransportType.wifi:
          _deviceProvider.setTransport(WebSocketService());
          break;
        case TransportType.cloud:
          if (_cloudWs != null && _cloudWs!.isConnected &&
              _cloudWs!.account != null && _cloudWs!.identity != null) {
            _deviceProvider.setTransport(_cloudWs!);
          } else {
            final identity = CloudIdentityService();
            await identity.initialize();
            if (!identity.hasIdentity || identity.account == null) {
              return _error('no_identity',
                  'No cloud identity found. Connect to cloud relay first.',
                  status: 400);
            }
            final ws = WebSocketService()
              ..account = identity.account
              ..identity = identity;
            _cloudWs = ws;
            _deviceProvider.setTransport(ws);
          }
          break;
        case TransportType.serial:
          _deviceProvider.setTransport(_serialProvider.serialService);
          break;
        case TransportType.demo:
          return _error('demo_only', 'Cannot reconnect to demo devices',
              status: 400);
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

    // Try each transport in priority order (no parallel check — connect attempt
    // itself acts as the availability probe for the API)
    for (final attempt in attempts) {
      final (label, type, address, factory) = attempt;
      _deviceProvider.setTransport(factory());

      try {
        final info = DeviceInfo(
          id: last.uid,
          name: last.name,
          rssi: 0,
          hasFs: false,
          bleAddress: last.bleAddress,
          wifiAddress: last.wifiAddress,
          transportAddress: address,
          currentTransport: type,
        );
        await _deviceProvider.connectToDevice(info);
        if (_deviceProvider.isConnected) {
          await _historyProvider.saveDevice(info, last.type, cloudAccount: last.cloudAccount);
          return _json({
            'ok': true,
            'message': 'Reconnected to ${last.name} via $label',
            'transport': label,
          });
        }
      } catch (_) {
        // Try next transport
      }
    }

    return _error('connection_failed',
        '${last.name} is not reachable on any available transport.',
        status: 503);
  }

  Future<Response> _handleModels(Request request) async {
    final models = _historyProvider.pairedDevices.map((d) => {
      'id': d.uid,
      'name': d.name,
      'type': d.type,
      'configName': d.configName,
      'description': d.description,
      'deviceIcon': d.deviceIcon,
    }).toList();
    return _json({'models': models});
  }

  Future<Response> _handleModelsDeleteAll(Request request) async {
    await _historyProvider.deleteAll();
    return _json({'ok': true, 'message': 'All models removed'});
  }

  Future<Response> _handleModelsDeleteOne(Request request, String id) async {
    final devices = _historyProvider.pairedDevices;
    final exists = devices.any((d) => d.uid == id);
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
    // PING removed — connection health is transport-driven.
    // Endpoint kept for API compatibility; returns ok when connected.
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    return _json({'ok': true});
  }

  /// Handle POST /api/transport/wifi_info — get WiFi info from connected device.
  /// Sends GET_WIFI_INFO protocol command and returns the parsed response.
  Future<Response> _handleTransportWifiInfo(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    try {
      final wifiInfo = await _deviceProvider.sendGetWifiInfo();
      if (wifiInfo == null) {
        return _error('wifi_info_timeout', 'Failed to get WiFi info (no response)', status: 500);
      }
      return _json({
        'ok': true,
        'ip': wifiInfo.ip,
        'mode': wifiInfo.mode == 0 ? 'sta' : 'ap',
        'ssid': wifiInfo.ssid,
        'rssi': wifiInfo.rssi,
      });
    } catch (e) {
      return _error('wifi_info_error', e.toString(), status: 500);
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
          break; // PING removed — connection health is transport-driven.
        case 'get_conf':
          await transport.writePacket(ProtocolService.buildGetConf());
        case 'get_vars':
          await transport.writePacket(ProtocolService.buildGetVars());
        case 'get_meta':
          await transport.writePacket(ProtocolService.buildGetMeta());
        case 'get_tele':
          await transport.writePacket(SettingsProtocolService.buildGetTelemetry(0));
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
      debugPrint('FS_HANDLER: Calling listDir for path=$path');
      final entries = await _fsService().listDir(path);
      debugPrint('FS_HANDLER: listDir returned ${entries.length} entries');
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
      debugPrint('FS_HANDLER: listDir threw: $e');
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
    // Optional chunkSize parameter (default 16376) for throughput profiling.
    final chunkSizeParam = request.url.queryParameters['chunkSize'];
    final chunkSize = (chunkSizeParam != null) ? int.tryParse(chunkSizeParam) : null;
    // Hold the FS busy lock for the entire multi-chunk read to prevent
    // the Follow Mode FS screen from interleaving its own FS operations
    // (listDir/getInfo) between chunks and corrupting the response stream.
    _deviceProvider.setFsBusy(true);
    try {
      final data = chunkSize != null && chunkSize > 0
          ? await _fsService().readFile(path, chunkSize: chunkSize)
          : await _fsService().readFile(path);
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
    // Optional chunk_size parameter (default 4096) for throughput profiling.
    final chunkSize = (body['chunkSize'] as num?)?.toInt() ?? 0;
    // Hold the FS busy lock for the entire multi-chunk write to prevent
    // the Follow Mode FS screen from interleaving its own FS operations.
    _deviceProvider.setFsBusy(true);
    try {
      final data = base64Decode(dataB64);
      final result = chunkSize > 0
          ? await _fsService().writeFile(path, data, chunkSize: chunkSize)
          : await _fsService().writeFile(path, data);
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

    const validDemos = {'WIDGETS_DEMO', 'RC_CONTROLLER', 'IOT_DASHBOARD', 'MULTI_PAGE_DEMO'};
    if (!validDemos.contains(demoId)) {
      return _error('demo_not_found', 'Invalid demo ID: $demoId');
    }

    try {
      // connectDemo creates a new DeviceProvider in MultiDeviceProvider
      // and sets focus so it becomes the active device for API calls.
      if (_connectDemo != null) {
        await _connectDemo(demoId);
      } else {
        // Fallback for test environments without MultiDeviceProvider.
        await _deviceProvider.loadDemo(demoId);
      }
    } catch (e) {
      return _error('demo_load_failed', e.toString(), status: 500);
    }

    // After connectDemo, the demo device is focused — resolve via _deviceProvider.
    final dp = _deviceProvider;
    if (!dp.isConnected) {
      return _error('demo_load_failed',
          dp.errorMessage ?? 'Failed to load demo',
          status: 500);
    }

    final count = dp.widgets.length;
    return _json({
      'ok': true,
      'message': 'Demo $demoId loaded with $count widgets',
    });
  }
  // ── NVS Config / Settings / Device Info ──────────────────────────────────────

  /// Handle GET /api/settings/nvs — returns current NVS config values
  /// (name, description) and password/authentication state.
  Future<Response> _handleNvsGet(Request request) async {
    final device = _deviceProvider.connectedDevice;
    if (!_deviceProvider.isConnected || device == null) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    return _json({
      'name': _deviceProvider.configName ?? '',
      'description': _deviceProvider.description ?? '',
      'hasPassword': _deviceProvider.hasPassword,
      'hasAdminPassword': _deviceProvider.hasAdminPassword,
      'isAuthenticated': _deviceProvider.isAuthenticated,
      'isAdminMode': _deviceProvider.isAdminMode,
      'isUserMode': _deviceProvider.isUserMode,
    });
  }

  /// Handle POST /api/settings/nvs — writes new config values to NVS.
  /// Accepts optional fields: name, description, password, adminPassword.
  /// Only fields provided in the body will be updated.
  Future<Response> _handleNvsSet(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    final body = await _parseBody(request);
    final name = body['name'] as String?;
    final description = body['description'] as String?;
    final password = body['password'] as String?;
    final adminPassword = body['adminPassword'] as String?;
    final icon = body['icon'] as String?;

    if (name == null && description == null && password == null && adminPassword == null && icon == null) {
      return _error(
          'invalid_params', 'At least one of: name, description, password, adminPassword, icon');
    }

    if (name != null && (name.length < 1 || name.length > kMaxConfigName)) {
      return _error('invalid_name',
          'Name must be 1-${kMaxConfigName} characters');
    }
    if (description != null && description.length > kMaxConfigDesc) {
      return _error('invalid_description',
          'Description must be at most ${kMaxConfigDesc} characters');
    }
    if (password != null && password.length > kMaxConfigPwd) {
      return _error('invalid_password',
          'Password must be at most ${kMaxConfigPwd} characters');
    }
    if (adminPassword != null && adminPassword.length > kMaxConfigPwd) {
      return _error('invalid_admin_password',
          'Admin password must be at most ${kMaxConfigPwd} characters');
    }
    if (icon != null && icon.length > kMaxDeviceIcon) {
      return _error('invalid_icon',
          'Icon must be at most ${kMaxDeviceIcon} characters');
    }

    try {
      final ok = await _deviceProvider.sendSetConf(
        name: name,
        description: description,
        password: password,
        adminPassword: adminPassword,
        icon: icon,
      );
      if (ok) {
        return _json({'ok': true, 'message': 'Config saved to NVS'});
      }
      return _error('nvs_error', 'Failed to write config to NVS', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/settings/nvs/authenticate — authenticate with
  /// the device password.
  Future<Response> _handleNvsAuthenticate(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    final body = await _parseBody(request);
    final password = body['password'] as String?;

    if (password == null || password.isEmpty) {
      return _error('invalid_params', 'password is required');
    }

    try {
      final ok = await _deviceProvider.authenticate(password);
      if (ok) {
        return _json({
          'ok': true,
          'message': 'Authenticated successfully',
        });
      }
      return _error('auth_failed', 'Password mismatch or timeout', status: 401);
    } catch (e) {
      return _error('auth_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/settings/nvs/raw/<key> — read a raw NVS key from the device.
  /// Supports both uint8 and string keys.
  Future<Response> _handleNvsRawRead(Request request, String key) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    try {
      final result = await _deviceProvider.readNvsRawKey(key);
      if (result.status == kSettingsNvsRawOk) {
        if (result.rawString != null) {
          return _json({'ok': true, 'key': key, 'value': result.rawString});
        }
        if (result.value != null) {
          return _json({'ok': true, 'key': key, 'value': result.value});
        }
      }
      return _json({'ok': true, 'key': key, 'value': null});
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/settings/nvs/cloud-info — read cloud relay URL + account
  /// from the device via GET_CLOUD_INFO protocol command.
  Future<Response> _handleNvsCloudInfo(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    try {
      final cloudInfo = await _deviceProvider.sendGetCloudInfo();
      if (cloudInfo != null) {
        return _json({
          'ok': true,
          'url': cloudInfo.url,
          'account': cloudInfo.account,
        });
      }
      return _json({
        'ok': true,
        'url': null,
        'account': null,
      });
    } catch (e) {
      return _error('cloud_info_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/settings/nvs/raw/<key> — write a raw uint8 value to an NVS key.
  /// Body: { "value": <int> }
  Future<Response> _handleNvsRawWrite(Request request, String key) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    final body = await _parseBody(request);
    final value = body['value'] as int?;
    if (value == null || value < 0 || value > 255) {
      return _error('invalid_params', 'value must be an integer 0-255');
    }
    try {
      final status = await _deviceProvider.writeNvsRawKey(key, value);
      if (status == kSettingsNvsRawOk) {
        return _json({'ok': true, 'key': key, 'value': value});
      }
      return _error('nvs_error', 'Failed to write NVS key', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/settings/nvs/factory-reset — erases NVS config and
  /// reboots the device. This cannot be undone.
  Future<Response> _handleNvsFactoryReset(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }

    // Require confirmation parameter for safety
    final body = await _parseBody(request);
    final confirm = body['confirm'] as bool? ?? false;
    if (!confirm) {
      return _error(
          'confirmation_required',
          'Set confirm: true to proceed with factory reset. '
          'This will erase all config and reboot the device.',
          status: 400);
    }

    try {
      final ok = await _deviceProvider.sendFactoryReset();
      if (ok) {
        return _json({
          'ok': true,
          'message': 'Factory reset sent — device will reboot',
        });
      }
      return _error('nvs_error', 'Failed to send factory reset', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/settings/nvs/reboot — reboot the device without erasing NVS.
  /// The device's NVS keys (rk_ble_on, rk_wifi_on, etc.) are preserved.
  Future<Response> _handleNvsReboot(Request request) async {
    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }

    try {
      final ok = await _deviceProvider.sendReboot();
      if (ok) {
        return _json({
          'ok': true,
          'message': 'Reboot sent — device will reboot (NVS preserved)',
        });
      }
      return _error('nvs_error', 'Failed to send reboot', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  // ── Flasher Handlers ────────────────────────────────────────────────────

  /// Handle GET /api/flasher/ports — return currently scanned serial ports.
  Future<Response> _handleFlasherPorts(Request request) async {
    final ports = _flasherProvider.availablePorts.map((p) => {
      'id': p.id,
      'name': p.name,
      if (p.description != null) 'description': p.description,
    }).toList();
    return _json({'ports': ports});
  }

  /// Handle POST /api/flasher/scan — trigger a port scan.
  /// Fire-and-forget: the scan runs asynchronously. Poll /api/flasher/status
  /// and /api/flasher/ports for results.
  Future<Response> _handleFlasherScan(Request request) async {
    // Not awaited — fire-and-forget, status is polled via status endpoint
    _flasherProvider.scanPorts();
    return _json({'ok': true, 'message': 'Port scan started'});
  }

  /// Handle POST /api/flasher/connect — connect to a serial port and sync.
  /// Body: { "portId": "/dev/ttyACM0" }
  Future<Response> _handleFlasherConnect(Request request) async {
    final body = await _parseBody(request);
    final portId = body['portId'] as String?;
    if (portId == null || portId.isEmpty) {
      return _error('invalid_params', 'portId is required');
    }
    try {
      await _flasherProvider.connect(portId);
      if (_flasherProvider.isConnected) {
        return _json({'ok': true, 'message': 'Connected to $portId'});
      }
      return _error('connection_failed',
          _flasherProvider.errorMessage ?? 'Failed to connect to $portId',
          status: 500);
    } catch (e) {
      return _error('connection_failed', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/flasher/disconnect — disconnect from the serial port.
  Future<Response> _handleFlasherDisconnect(Request request) async {
    await _flasherProvider.disconnect();
    return _json({'ok': true, 'message': 'Disconnected'});
  }

  /// Handle GET /api/flasher/status — return current flasher state.
  Future<Response> _handleFlasherStatus(Request request) async {
    final info = _flasherProvider.chipInfo;
    final firmware = _flasherProvider.selectedFirmware;
    return _json({
      'isConnected': _flasherProvider.isConnected,
      'isScanning': _flasherProvider.isScanning,
      'isLoadingChipInfo': _flasherProvider.isLoadingChipInfo,
      'isFlashing': _flasherProvider.isFlashing,
      'isOperationActive': _flasherProvider.isOperationActive,
      'portName': _flasherProvider.portName,
      'baudRate': _flasherProvider.baudRate,
      'errorMessage': _flasherProvider.errorMessage,
      'flashProgress': _flasherProvider.flashProgress,
      'flashStatus': _flasherProvider.flashStatus,
      'eraseAll': _flasherProvider.eraseAll,
      'chipInfo': info != null
          ? {
              'model': info.model,
              'revision': info.revision,
              'mac': info.mac,
              'flashSize': info.flashSize,
              'psramSize': info.psramSize,
              'cores': info.cores,
            }
          : null,
      'selectedFirmware': firmware != null
          ? {
              'name': firmware.name,
              'size': firmware.size,
              'bytes': firmware.bytes,
            }
          : null,
    });
  }

  /// Handle GET /api/flasher/log — return flasher log entries.
  Future<Response> _handleFlasherLog(Request request) async {
    return _json({
      'entries': _flasherProvider.logEntries,
    });
  }

  /// Handle POST /api/flasher/log/clear — clear flasher log.
  Future<Response> _handleFlasherLogClear(Request request) async {
    _flasherProvider.clearLog();
    return _json({'ok': true});
  }

  /// Handle POST /api/flasher/select-firmware — accept base64 firmware data.
  /// Body: { "data": "<base64>", "name": "firmware.bin" }
  /// Saves the firmware to a temp file and sets it as the selected firmware.
  Future<Response> _handleFlasherSelectFirmware(Request request) async {
    final body = await _parseBody(request);
    final dataB64 = body['data'] as String?;
    final name = body['name'] as String? ?? 'firmware.bin';
    if (dataB64 == null || dataB64.isEmpty) {
      return _error('invalid_params', 'data (base64-encoded firmware) is required');
    }
    List<int> firmwareBytes;
    try {
      firmwareBytes = base64Decode(dataB64);
    } catch (e) {
      return _error('invalid_encoding', 'Failed to decode base64: $e', status: 400);
    }
    // Write to a temp file so FlasherProvider can read it
    final tempDir = Directory.systemTemp;
    final tempFile = File('${tempDir.path}/$name');
    try {
      await tempFile.writeAsBytes(firmwareBytes);
    } catch (e) {
      return _error('file_error', 'Failed to write temp file: $e', status: 500);
    }
    // Directly set the selected firmware on the provider
    // (bypassing the file picker in selectFirmwareFile)
    _flasherProvider.setSelectedFirmwareDirect(
      name: name,
      path: tempFile.path,
      bytes: firmwareBytes.length,
    );
    return _json({
      'ok': true,
      'name': name,
      'size': firmwareBytes.length,
    });
  }

  /// Handle POST /api/flasher/clear-firmware — clear firmware selection.
  Future<Response> _handleFlasherClearFirmware(Request request) async {
    _flasherProvider.clearFirmwareSelection();
    return _json({'ok': true});
  }

  /// Handle POST /api/flasher/erase-all — toggle erase all setting.
  /// Body: { "eraseAll": true }
  Future<Response> _handleFlasherEraseAll(Request request) async {
    final body = await _parseBody(request);
    final value = body['eraseAll'] as bool?;
    if (value == null) {
      return _error('invalid_params', 'eraseAll (boolean) is required');
    }
    _flasherProvider.setEraseAll(value);
    return _json({'ok': true, 'eraseAll': value});
  }

  /// Handle POST /api/flasher/flash — start the flashing operation.
  /// Requires firmware selected via [select-firmware] first.
  /// Fire-and-forget: the flash runs asynchronously. Poll /api/flasher/status
  /// for progress (flashProgress, flashStatus, isFlashing).
  Future<Response> _handleFlasherFlash(Request request) async {
    if (!_flasherProvider.isConnected) {
      return _error('not_connected', 'Not connected to a serial port', status: 503);
    }
    if (_flasherProvider.selectedFirmware == null) {
      return _error('no_firmware', 'No firmware selected. Use /api/flasher/select-firmware first', status: 400);
    }
    if (_flasherProvider.isFlashing) {
      return _error('already_flashing', 'A flashing operation is already in progress', status: 409);
    }
    // Fire-and-forget: startFlashing has its own error handling
    // and the provider's state is pollable via /api/flasher/status
    _flasherProvider.startFlashing();
    return _json({'ok': true, 'message': 'Flashing started'});
  }

  // ── Multi-device Handlers ──────────────────────────────────────────────────

  /// Resolve a [MultiDeviceProvider] instance, or null if unavailable.
  MultiDeviceProvider? _getMulti() => _getMultiDevice?.call();

  /// Helper to create a transport for a given type.
  /// Each call returns an independent transport instance.
  TransportService _createTransport(String type) {
    switch (type) {
      case 'ble':
        // BleTransport wraps the shared BleService singleton.
        // universal_ble on Android supports multiple concurrent connections;
        // BleService routes notifications per-device via _activeTransports.
        return BleTransport(_bleProvider.bleService);
      case 'serial':
        // SerialService is per-port; return the shared instance since
        // serial connections are inherently single-port.
        return _serialProvider.serialService;
      case 'wifi':
        return WebSocketService();
      default:
        return BleTransport(_bleProvider.bleService);
    }
  }

  /// Handle GET /api/devices — list all devices in the multi-device collection.
  Future<Response> _handleDevices(Request request) async {
    final multi = _getMulti();
    if (multi == null) {
      return _error('not_supported', 'Multi-device not available', status: 501);
    }

    final devices = <Map<String, dynamic>>[];
    for (final (key, dp) in multi.deviceEntries) {
      final device = dp.connectedDevice;
      devices.add({
        'id': key,
        'name': dp.configName ?? device?.displayName ?? 'Unknown',
        'connected': dp.isConnected,
        'hasFs': device?.hasFs ?? false,
        'hasOta': dp.hasOta,
        'hasPassword': dp.hasPassword,
        'rssi': dp.rssi,
        'latencyMs': dp.latencyMs,
        'transport': _transportTypeLabel(device?.currentTransport),
      });
    }
    return _json({
      'devices': devices,
      'count': devices.length,
      'focusedDeviceId': multi.focusedDeviceId,
    });
  }

  String _transportTypeLabel(TransportType? t) {
    switch (t) {
      case TransportType.ble:    return 'ble';
      case TransportType.wifi:   return 'wifi';
      case TransportType.cloud:  return 'cloud';
      case TransportType.serial: return 'serial';
      case TransportType.demo:   return 'demo';
      case null:                 return 'unknown';
    }
  }

  /// Handle POST /api/devices/connect — connect a new device (any transport).
  /// Body: { "id": "...", "type": "ble|serial|wifi|cloud|demo", "baudRate": 115200 }
  Future<Response> _handleDeviceConnect(Request request) async {
    final multi = _getMulti();
    if (multi == null) {
      return _error('not_supported', 'Multi-device not available', status: 501);
    }

    final body = await _parseBody(request);
    final id = body['id'] as String?;
    final type = body['type'] as String?;
    if (id == null || type == null) {
      return _error('invalid_params', 'id and type are required');
    }

    final baudRate = (body['baudRate'] as num?)?.toInt() ?? 115200;

    // If device is already connected, return it directly
    final existing = multi.getDevice(id);
    if (existing != null && existing.isConnected) {
      return _json({
        'ok': true,
        'message': 'Already connected',
        'device': {
          'id': id,
          'name': existing.configName ?? existing.connectedDevice?.displayName ?? 'Unknown',
          'connected': true,
        },
      });
    }

    // Resolve device info and create transport
    DeviceInfo? target;
    TransportService? transport;

    switch (type) {
      case 'ble':
        target = _bleProvider.devices.where((d) => d.id == id).firstOrNull;
        if (target == null) {
          target = DeviceInfo(
            id: id,
            name: id == 'B4:3A:45:AE:BA:25' ? 'FS LED' : (id == '10:20:BA:2F:91:1D' ? 'Basic_Switch' : 'BLE Device'),
            rssi: -50,
            hasFs: false,
            currentTransport: TransportType.ble,
          );
        }
        transport = _createTransport('ble');
      case 'serial':
        target = _serialProvider.ports.where((p) => p.id == id).firstOrNull;
        if (target == null) {
          return _error('not_found', 'Serial device $id not found. Run a scan first via POST /api/pair/scan.');
        }
        transport = _createTransport('serial');
      case 'wifi':
        if (!id.startsWith('ws://') && !id.startsWith('wss://')) {
          return _error('invalid_url', 'WiFi ID must be a WebSocket URL (ws:// or wss://)');
        }
        target = DeviceInfo(
          id: id,
          name: Uri.tryParse(id)?.host ?? id,
          rssi: 0,
          hasFs: false,
          currentTransport: TransportType.wifi,
          transportAddress: id,
        );
        transport = _createTransport('wifi');
      case 'cloud':
        if (_cloudWs == null || !_cloudWs!.isConnected) {
          return _error('not_connected', 'Cloud relay not connected. Use POST /api/cloud/connect first.', status: 503);
        }
        final deviceName = body['deviceName'] as String? ?? id;
        final scheme = _cloudPort == 443 ? 'wss' : 'ws';
        final url = '$scheme://$_cloudHost:$_cloudPort/$deviceName';
        target = DeviceInfo(
          id: url,
          name: deviceName,
          rssi: 0,
          hasFs: false,
          currentTransport: TransportType.cloud,
          transportAddress: url,
        );
        transport = _cloudWs!;
      case 'demo':
        final dp = await multi.connectDemo(id);
        multi.setFocusedDevice('DEMO_$id');
        return _json({
          'ok': true,
          'message': 'Demo $id loaded',
          'device': {
            'id': dp.connectedDevice?.id ?? id,
            'name': dp.configName ?? id,
            'connected': dp.isConnected,
          },
        });
      default:
        return _error('invalid_type', "type must be 'ble', 'serial', 'wifi', 'cloud', or 'demo'");
    }

    try {
      final dp = await multi.connectDevice(
        device: target,
        transport: transport,
        baudRate: baudRate,
      );

      // Set cloud transport so switchTransport can re-use the
      // authenticated relay connection later.
      if (type == 'cloud' && dp.isConnected) {
        dp.setCloudTransport(_cloudWs!);
      }

      // Set focus so subsequent /api/widgets calls target this device
      multi.setFocusedDevice(target.id);

      return _json({
        'ok': true,
        'message': 'Connected to ${target.displayName}',
        'device': {
          'id': target.id,
          'name': dp.configName ?? target.displayName,
          'connected': dp.isConnected,
          'transport': _transportTypeLabel(target.currentTransport),
        },
      });
    } catch (e) {
      // Clean up transport on failure to prevent orphaned BLE connections
      try { await transport.disconnect(); } catch (_) {}
      return _error('connection_failed', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/devices/disconnect — disconnect a specific device.
  /// Body: { "id": "..." }
  Future<Response> _handleDeviceDisconnect(Request request) async {
    final multi = _getMulti();
    if (multi == null) {
      return _error('not_supported', 'Multi-device not available', status: 501);
    }

    final body = await _parseBody(request);
    final id = body['id'] as String?;
    if (id == null) {
      return _error('invalid_params', 'id is required');
    }

    final dp = multi.getDevice(id);
    if (dp == null) {
      return _error('not_found', 'Device $id not found in collection', status: 404);
    }

    final name = dp.configName ?? dp.connectedDevice?.displayName ?? id;
    _deviceOtaProgress.remove(id);
    await multi.disconnectDevice(id);
    return _json({'ok': true, 'message': 'Disconnected $name'});
  }

  /// Handle GET /api/devices/<id> — get info for a specific device.
  Future<Response> _handleDeviceInfo(Request request, String id) async {
    final decodedId = Uri.decodeComponent(id);
    final multi = _getMulti();
    if (multi == null) {
      return _error('not_supported', 'Multi-device not available', status: 501);
    }

    final dp = multi.getDevice(decodedId);
    if (dp == null) {
      return _error('not_found', 'Device $decodedId not found', status: 404);
    }

    final device = dp.connectedDevice;
    final orientation = dp.orientation == kOrientationLandscape
        ? 'landscape' : 'portrait';

    return _json({
      'id': device?.id ?? decodedId,
      'name': dp.configName ?? device?.displayName ?? 'Unknown',
      'description': dp.description,
      'connected': dp.isConnected,
      'hasFs': device?.hasFs ?? false,
      'hasOta': dp.hasOta,
      'hasPassword': dp.hasPassword,
      'rssi': dp.rssi,
      'latencyMs': dp.latencyMs,
      'transport': _transportTypeLabel(device?.currentTransport),
      'configJson': dp.deviceConfigJson,
      'orientation': orientation,
      'isFocused': multi.focusedDeviceId == decodedId,
    });
  }

  /// Handle GET /api/devices/<id>/widgets — get widgets for a specific device.
  Future<Response> _handleDeviceWidgets(Request request, String id) async {
    final decodedId = Uri.decodeComponent(id);
    final multi = _getMulti();
    if (multi == null) {
      return _error('not_supported', 'Multi-device not available', status: 501);
    }

    final dp = multi.getDevice(decodedId);
    if (dp == null) {
      return _error('not_found', 'Device $decodedId not found', status: 404);
    }
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $decodedId is not connected', status: 503);
    }

    final widgets = dp.widgets;
    final result = widgets.map((w) => _widgetToJson(w, dp: dp)).toList();
    return _json({
      'device': decodedId,
      'widgets': result,
    });
  }

  /// Handle PUT /api/devices/<id>/widgets/<wid> — set widget value on a specific device.
  Future<Response> _handleDeviceWidgetSet(Request request, String id, String wid) async {
    final decodedId = Uri.decodeComponent(id);
    final multi = _getMulti();
    if (multi == null) {
      return _error('not_supported', 'Multi-device not available', status: 501);
    }

    final dp = multi.getDevice(decodedId);
    if (dp == null) {
      return _error('not_found', 'Device $decodedId not found', status: 404);
    }
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $decodedId is not connected', status: 503);
    }

    final widgetId = int.tryParse(wid);
    if (widgetId == null) {
      return _error('invalid_id', 'Widget ID must be an integer');
    }

    final widget = dp.widgets.where((w) => w.widgetId == widgetId).firstOrNull;
    if (widget == null) {
      return _error('not_found', 'Widget $wid not found on device $decodedId', status: 404);
    }
    if (!widget.hasInput) {
      return _error('not_input', 'Widget $wid is an output-only widget');
    }

    final body = await _parseBody(request);
    final values = body['values'] as List<dynamic>?;
    if (values == null || values.isEmpty) {
      return _error('invalid_values', 'values array is required');
    }

    final intValues = values.map((v) => (v as num).toInt()).toList();
    if (widget.typeId == kWidgetJoystick && intValues.length != 2) {
      return _error('invalid_values', 'Joystick expects exactly 2 values [x, y]');
    }

    try {
      await dp.setInputValue(widgetId, intValues);
      return _json({
        'ok': true,
        'device': decodedId,
        'message': 'Widget $widgetId set to $intValues',
      });
    } catch (e) {
      return _error('set_failed', e.toString(), status: 500);
    }
  }

  // ── Per-device Console / FS / Transport Handlers ─────────────────────────

  /// Resolve a device from the multi-device collection by ID.
  /// Returns (deviceProvider, null) on success or (dummy, errorResponse) on failure.
  /// The caller always returns immediately after err != null, so the dummy is never used.
  (DeviceProvider, Response?) _resolveDevice(String id) {
    final decodedId = Uri.decodeComponent(id);
    final multi = _getMulti();
    if (multi == null) {
      return (_idleProvider, _error('not_supported', 'Multi-device not available', status: 501));
    }
    final dp = multi.getDevice(decodedId);
    if (dp == null) {
      return (_idleProvider, _error('not_found', 'Device $decodedId not found', status: 404));
    }
    return (dp, null);
  }

  /// Shared idle DeviceProvider used only as a non-null filler on error paths.
  final DeviceProvider _idleProvider = DeviceProvider(transport: DemoTransport());

  /// Handle GET /api/devices/<id>/console — per-device console log.
  Future<Response> _handleDeviceConsole(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    final entries = (dp.consoleProvider?.entries ?? []).map((e) => {
      'timestamp': e.timestamp.toIso8601String(),
      'level': e.level.name,
      'message': e.message,
    }).toList();
    return _json({'device': id, 'entries': entries});
  }

  /// Helper: resolve a device and check it has FS support.
  (DeviceProvider, Response?) _resolveDeviceFs(String id) {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return (dp, err);
    if (!dp.isConnected) {
      return (dp, _error('not_connected', 'Device $id is not connected', status: 503));
    }
    final device = dp.connectedDevice;
    if (device == null || !device.hasFs) {
      return (dp, _error('not_supported', 'Device $id has no filesystem', status: 400));
    }
    return (dp, null);
  }

  DeviceFsService _deviceFsService(DeviceProvider dp) => createDeviceFsService(dp);

  /// Handle GET /api/devices/<id>/fs/list — per-device FS directory listing.
  Future<Response> _handleDeviceFsList(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    final path = request.url.queryParameters['path'] ?? '/';
    try {
      final entries = await _deviceFsService(dp).listDir(path);
      return _json({
        'device': id,
        'path': path,
        'entries': entries.map((e) => {
          'name': e.name,
          'type': e.isDirectory ? 'directory' : 'file',
          'size': e.size,
        }).toList(),
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/devices/<id>/fs/info — per-device FS info.
  Future<Response> _handleDeviceFsInfo(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    try {
      final info = await _deviceFsService(dp).getInfo();
      if (info == null) {
        return _error('fs_error', 'Failed to get FS info', status: 500);
      }
      return _json({
        'device': id,
        'totalBytes': info.totalBytes,
        'usedBytes': info.usedBytes,
        'freeBytes': info.freeBytes,
        'blockSize': info.blockSize,
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/devices/<id>/fs/read — per-device FS file read.
  Future<Response> _handleDeviceFsRead(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    final path = request.url.queryParameters['path'];
    if (path == null || path.isEmpty) {
      return _error('invalid_params', 'path query parameter is required');
    }
    dp.setFsBusy(true);
    try {
      final data = await _deviceFsService(dp).readFile(path);
      if (data == null) {
        return _error('not_found', 'File not found: $path', status: 404);
      }
      return _json({
        'device': id,
        'path': path,
        'size': data.length,
        'encoding': 'base64',
        'data': base64Encode(data),
      });
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    } finally {
      dp.setFsBusy(false);
    }
  }

  /// Handle POST /api/devices/<id>/fs/write — per-device FS file write.
  Future<Response> _handleDeviceFsWrite(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    final dataB64 = body['data'] as String?;
    if (path == null || dataB64 == null) {
      return _error('invalid_params', 'path and data are required');
    }
    dp.setFsBusy(true);
    try {
      final data = base64Decode(dataB64);
      final result = await _deviceFsService(dp).writeFile(path, data);
      if (!result.success) {
        return _error('fs_error', '${result.errorName}: ${result.message}', status: 500);
      }
      return _json({'ok': true, 'device': id, 'path': path, 'bytesWritten': data.length});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    } finally {
      dp.setFsBusy(false);
    }
  }

  /// Handle POST /api/devices/<id>/fs/upload — per-device FS file upload.
  Future<Response> _handleDeviceFsUpload(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    final dataB64 = body['data'] as String?;
    if (path == null || dataB64 == null) {
      return _error('invalid_params', 'path and data are required');
    }
    dp.setFsBusy(true);
    try {
      final data = base64Decode(dataB64);
      final result = await _deviceFsService(dp).writeFileUpload(path, data);
      if (!result.success) {
        return _error('fs_error', '${result.errorName}: ${result.message}', status: 500);
      }
      return _json({'ok': true, 'device': id, 'path': path, 'bytesWritten': data.length});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    } finally {
      dp.setFsBusy(false);
    }
  }

  /// Handle POST /api/devices/<id>/fs/mkdir — per-device FS mkdir.
  Future<Response> _handleDeviceFsMkdir(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    if (path == null) {
      return _error('invalid_params', 'path is required');
    }
    try {
      final result = await _deviceFsService(dp).mkdir(path);
      if (!result.success) {
        return _error('fs_error', '${result.errorName}: ${result.message}', status: 500);
      }
      return _json({'ok': true, 'device': id, 'path': path});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/devices/<id>/fs/delete — per-device FS delete.
  Future<Response> _handleDeviceFsDelete(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    final body = await _parseBody(request);
    final path = body['path'] as String?;
    if (path == null) {
      return _error('invalid_params', 'path is required');
    }
    try {
      final result = await _deviceFsService(dp).delete(path);
      if (!result.success) {
        return _error('fs_error', '${result.errorName}: ${result.message}', status: 500);
      }
      return _json({'ok': true, 'device': id, 'path': path});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  /// Handle DELETE /api/devices/<id>/console — clear per-device console log.
  Future<Response> _handleDeviceConsoleClear(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    dp.consoleProvider?.clear();
    return _json({'ok': true, 'device': id, 'message': 'Console cleared'});
  }

  /// Handle POST /api/devices/<id>/fs/format — format per-device filesystem.
  Future<Response> _handleDeviceFsFormat(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    dp.setFsBusy(true);
    try {
      final result = await _deviceFsService(dp).format();
      if (!result.success) {
        return _error('fs_error', '${result.errorName}: ${result.message}', status: 500);
      }
      return _json({'ok': true, 'device': id, 'message': 'Filesystem formatted'});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    } finally {
      dp.setFsBusy(false);
    }
  }

  /// Handle GET /api/devices/<id>/ota/progress — per-device OTA upload progress.
  Future<Response> _handleDeviceOtaProgress(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    final progress = _deviceOtaProgress[id];
    if (progress == null) {
      return _json({
        'device': id,
        'active': false,
        'received': 0,
        'total': 0,
        'status': 'idle',
      });
    }
    final r = progress.$1;
    final t = progress.$2;
    final s = progress.$3;
    return _json({
      'device': id,
      'active': true,
      'received': r,
      'total': t,
      'status': s,
      'percentage': t > 0 ? ((r / t) * 100).round() : 0,
    });
  }

  /// Handle POST /api/devices/<id>/transport/send — per-device raw packet send.
  Future<Response> _handleDeviceTransportSend(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
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
        return _error('invalid_hex', 'Payload must be an even-length hex string');
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
      await dp.currentTransport.writePacket(pkt);
      return _json({'ok': true, 'device': id, 'message': 'Packet sent'});
    } catch (e) {
      return _error('send_failed', e.toString(), status: 500);
    }
  }


  // -- Per-device OTA Upload ---------------------------------------------------

  /// Handle POST /api/devices/<id>/ota/upload -- per-device OTA firmware upload.
  /// Body: { "data": "<base64>", "eraseAll": false }
  Future<Response> _handleDeviceOtaUpload(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    if (!dp.hasOta) {
      return _error('ota_not_supported',
          'Device $id does not support OTA', status: 400);
    }

    final body = await _parseBody(request);
    final dataB64 = body['data'] as String?;
    if (dataB64 == null || dataB64.isEmpty) {
      return _error('invalid_params',
          'data (base64-encoded firmware) is required');
    }

    final eraseAll = body['eraseAll'] as bool? ?? false;

    List<int> firmware;
    try {
      firmware = base64Decode(dataB64);
    } catch (e) {
      return _error('invalid_encoding',
          'Failed to decode base64 data: $e', status: 400);
    }

    _deviceOtaProgress.remove(id);
    _deviceOtaProgress[id] = (0, firmware.length, 'starting');

    try {
      await dp.uploadFirmware(
        firmware,
        eraseAll: eraseAll,
        onProgress: (received, total) {
          _deviceOtaProgress[id] = (received, total, 'uploading');
        },
      );

      _deviceOtaProgress[id] = (firmware.length, firmware.length, 'rebooting');

      return _json({
        'ok': true,
        'device': id,
        'size': firmware.length,
        'eraseAll': eraseAll,
        'message': 'Firmware uploaded successfully -- device rebooting',
      });
    } catch (e) {
      _deviceOtaProgress.remove(id);
      return _error('ota_failed', e.toString(), status: 500);
    }
  }

  // -- Per-device FS Rename -----------------------------------------------------

  /// Handle POST /api/devices/<id>/fs/rename -- per-device FS file rename.
  /// Body: { "oldPath": "...", "newPath": "..." }
  Future<Response> _handleDeviceFsRename(Request request, String id) async {
    final (dp, err) = _resolveDeviceFs(id);
    if (err != null) return err;
    final body = await _parseBody(request);
    final oldPath = body['oldPath'] as String?;
    final newPath = body['newPath'] as String?;
    if (oldPath == null || newPath == null) {
      return _error('invalid_params', 'oldPath and newPath are required');
    }
    try {
      final result = await _deviceFsService(dp).rename(oldPath, newPath);
      if (!result.success) {
        return _error('fs_error',
            '${result.errorName}: ${result.message}', status: 500);
      }
      return _json({'ok': true, 'device': id, 'oldPath': oldPath, 'newPath': newPath});
    } catch (e) {
      return _error('fs_error', e.toString(), status: 500);
    }
  }

  // -- Per-device FS Probe ------------------------------------------------------

  /// Handle POST /api/devices/<id>/fs/probe -- probe FS availability on a device.
  Future<Response> _handleDeviceFsProbe(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    final device = dp.connectedDevice;
    if (device == null) {
      return _error('not_connected', 'No device info for $id', status: 503);
    }
    try {
      await dp.currentTransport.writePacket(FsProtocolService.buildInfo());
      await Future.delayed(const Duration(milliseconds: 2000));
    } catch (e) {
      return _error('fs_probe_failed', e.toString(), status: 500);
    }
    final hasFs = device.hasFs;
    return _json({
      'ok': true,
      'device': id,
      'hasFs': hasFs,
    });
  }

  // -- Per-device Transport Ping ------------------------------------------------

  /// Handle POST /api/devices/<id>/transport/ping -- connection check (transport-driven).
  Future<Response> _handleDeviceTransportPing(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    return _json({'ok': true, 'device': id});
  }

  // -- Per-device Transport WiFi Info -------------------------------------------

  /// Handle POST /api/devices/<id>/transport/wifi_info -- get WiFi info from device.
  Future<Response> _handleDeviceTransportWifiInfo(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    try {
      final wifiInfo = await dp.sendGetWifiInfo();
      if (wifiInfo == null) {
        return _error('wifi_info_timeout', 'Failed to get WiFi info from $id (no response)', status: 500);
      }
      return _json({
        'ok': true,
        'device': id,
        'ip': wifiInfo.ip,
        'mode': wifiInfo.mode == 0 ? 'sta' : 'ap',
        'ssid': wifiInfo.ssid,
        'rssi': wifiInfo.rssi,
      });
    } catch (e) {
      return _error('wifi_info_error', e.toString(), status: 500);
    }
  }

  // -- Per-device Transport Quick Commands --------------------------------------

  /// Handle POST /api/devices/<id>/transport/<cmd> -- quick transport commands.
  /// Supported: get_conf, get_vars, get_meta, get_tele
  Future<Response> _handleDeviceTransportQuick(Request request, String id, String cmd) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    try {
      switch (cmd) {
        case 'ping':
          break; // connection health is transport-driven
        case 'get_conf':
          await dp.currentTransport.writePacket(ProtocolService.buildGetConf());
        case 'get_vars':
          await dp.currentTransport.writePacket(ProtocolService.buildGetVars());
        case 'get_meta':
          await dp.currentTransport.writePacket(ProtocolService.buildGetMeta());
        case 'get_tele':
          await dp.currentTransport.writePacket(SettingsProtocolService.buildGetTelemetry(0));
        default:
          return _error('unknown_cmd', 'Unknown command: $cmd');
      }
      return _json({'ok': true, 'device': id});
    } catch (e) {
      return _error('send_failed', e.toString(), status: 500);
    }
  }


  // -- Per-device Settings / NVS Handlers ---------------------------------------

  /// Handle GET /api/devices/<id>/settings/nvs -- per-device NVS config.
  Future<Response> _handleDeviceNvsGet(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    return _json({
      'device': id,
      'name': dp.configName ?? '',
      'description': dp.description ?? '',
      'hasPassword': dp.hasPassword,
      'hasAdminPassword': dp.hasAdminPassword,
      'isAuthenticated': dp.isAuthenticated,
      'isAdminMode': dp.isAdminMode,
      'isUserMode': dp.isUserMode,
    });
  }

  /// Handle POST /api/devices/<id>/settings/nvs -- write config to device NVS.
  /// Accepts optional: name, description, password, adminPassword, icon.
  Future<Response> _handleDeviceNvsSet(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    final body = await _parseBody(request);
    final name = body['name'] as String?;
    final description = body['description'] as String?;
    final password = body['password'] as String?;
    final adminPassword = body['adminPassword'] as String?;
    final icon = body['icon'] as String?;

    if (name == null && description == null && password == null && adminPassword == null && icon == null) {
      return _error('invalid_params', 'At least one of: name, description, password, adminPassword, icon');
    }
    if (name != null && (name.length < 1 || name.length > kMaxConfigName)) {
      return _error('invalid_name', 'Name must be 1-$kMaxConfigName characters');
    }
    if (description != null && description.length > kMaxConfigDesc) {
      return _error('invalid_description', 'Description must be at most $kMaxConfigDesc characters');
    }
    if (password != null && password.length > kMaxConfigPwd) {
      return _error('invalid_password', 'Password must be at most $kMaxConfigPwd characters');
    }
    if (adminPassword != null && adminPassword.length > kMaxConfigPwd) {
      return _error('invalid_admin_password', 'Admin password must be at most $kMaxConfigPwd characters');
    }
    if (icon != null && icon.length > kMaxDeviceIcon) {
      return _error('invalid_icon', 'Icon must be at most $kMaxDeviceIcon characters');
    }

    try {
      final ok = await dp.sendSetConf(
        name: name,
        description: description,
        password: password,
        adminPassword: adminPassword,
        icon: icon,
      );
      if (ok) {
        return _json({'ok': true, 'device': id, 'message': 'Config saved to NVS'});
      }
      return _error('nvs_error', 'Failed to write config to NVS', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/devices/<id>/settings/nvs/authenticate -- authenticate with device password.
  Future<Response> _handleDeviceNvsAuthenticate(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    final body = await _parseBody(request);
    final password = body['password'] as String?;
    if (password == null || password.isEmpty) {
      return _error('invalid_params', 'password is required');
    }
    try {
      final ok = await dp.authenticate(password);
      if (ok) {
        return _json({'ok': true, 'device': id, 'message': 'Authenticated successfully'});
      }
      return _error('auth_failed', 'Password mismatch or timeout', status: 401);
    } catch (e) {
      return _error('auth_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/devices/<id>/settings/nvs/factory-reset -- erase NVS and reboot.
  Future<Response> _handleDeviceNvsFactoryReset(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    final body = await _parseBody(request);
    final confirm = body['confirm'] as bool? ?? false;
    if (!confirm) {
      return _error('confirmation_required',
          'Set confirm: true to proceed with factory reset. This will erase all config and reboot the device.',
          status: 400);
    }
    try {
      final ok = await dp.sendFactoryReset();
      if (ok) {
        return _json({'ok': true, 'device': id, 'message': 'Factory reset sent -- device will reboot'});
      }
      return _error('nvs_error', 'Failed to send factory reset', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/devices/<id>/settings/nvs/reboot -- reboot device (NVS preserved).
  Future<Response> _handleDeviceNvsReboot(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    try {
      final ok = await dp.sendReboot();
      if (ok) {
        return _json({'ok': true, 'device': id, 'message': 'Reboot sent -- device will reboot (NVS preserved)'});
      }
      return _error('nvs_error', 'Failed to send reboot', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/devices/<id>/settings/nvs/raw/<key> -- read raw NVS key.
  Future<Response> _handleDeviceNvsRawRead(Request request, String id, String key) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    try {
      final result = await dp.readNvsRawKey(key);
      if (result.status == kSettingsNvsRawOk) {
        if (result.rawString != null) {
          return _json({'ok': true, 'device': id, 'key': key, 'value': result.rawString});
        }
        if (result.value != null) {
          return _json({'ok': true, 'device': id, 'key': key, 'value': result.value});
        }
      }
      return _json({'ok': true, 'device': id, 'key': key, 'value': null});
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/devices/<id>/settings/nvs/raw/<key> -- write raw NVS key.
  Future<Response> _handleDeviceNvsRawWrite(Request request, String id, String key) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    final body = await _parseBody(request);
    final value = body['value'] as int?;
    if (value == null || value < 0 || value > 255) {
      return _error('invalid_params', 'value must be an integer 0-255');
    }
    try {
      final status = await dp.writeNvsRawKey(key, value);
      if (status == kSettingsNvsRawOk) {
        return _json({'ok': true, 'device': id, 'key': key, 'value': value});
      }
      return _error('nvs_error', 'Failed to write NVS key', status: 500);
    } catch (e) {
      return _error('nvs_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/devices/<id>/settings/nvs/cloud-info -- read cloud relay info from device.
  Future<Response> _handleDeviceNvsCloudInfo(Request request, String id) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    try {
      final cloudInfo = await dp.sendGetCloudInfo();
      if (cloudInfo != null) {
        return _json({
          'ok': true,
          'device': id,
          'url': cloudInfo.url,
          'account': cloudInfo.account,
        });
      }
      return _json({'ok': true, 'device': id, 'url': null, 'account': null});
    } catch (e) {
      return _error('cloud_info_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/devices/<id>/widgets/<wid> -- get a single widget from a device.
  Future<Response> _handleDeviceWidgetInfo(Request request, String id, String wid) async {
    final (dp, err) = _resolveDevice(id);
    if (err != null) return err;
    if (!dp.isConnected) {
      return _error('not_connected', 'Device $id is not connected', status: 503);
    }
    final widgetId = int.tryParse(wid);
    if (widgetId == null) {
      return _error('invalid_id', 'Widget ID must be an integer');
    }
    final widget = dp.widgets.where((w) => w.widgetId == widgetId).firstOrNull;
    if (widget == null) {
      return _error('not_found', 'Widget $wid not found on device $id', status: 404);
    }
    return _json({'device': id, 'widget': _widgetToJson(widget, dp: dp)});
  }

  // ── Page Handlers ───────────────────────────────────────────────────────────

  /// Handle GET /api/page — returns current page index, total pages, and page names.
  Future<Response> _handleGetPage(Request request) async {
    final dp = _getMulti()?.primaryDevice ?? _deviceProvider;
    if (!dp.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    return _json({
      'activePage': dp.activePage,
      'numPages': dp.numPages,
      'pages': dp.pageNames,
    });
  }

  /// Handle POST /api/page — switch to a specific page.
  /// Body: { "page": 0 }
  Future<Response> _handleSetPage(Request request) async {
    final dp = _getMulti()?.primaryDevice ?? _deviceProvider;
    if (!dp.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    final body = await _parseBody(request);
    final page = body['page'] as int?;
    if (page == null) {
      return _error('invalid_params', 'page is required');
    }
    if (page < 0 || page >= dp.numPages) {
      return _error('invalid_page',
          'page must be between 0 and ${dp.numPages - 1}',
          status: 400);
    }
    try {
      await dp.sendSetPage(page);
      return _json({
        'ok': true,
        'page': page,
        'message': 'Switched to page $page',
      });
    } catch (e) {
      return _error('set_page_failed', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/pages — returns the page name list with metadata.
  Future<Response> _handleGetPages(Request request) async {
    final dp = _getMulti()?.primaryDevice ?? _deviceProvider;
    if (!dp.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }
    return _json({
      'pages': dp.pageNames,
      'numPages': dp.numPages,
      'activePage': dp.activePage,
    });
  }

  // ── Cloud Relay Handlers ────────────────────────────────────────────────────

  /// Handle POST /api/cloud/connect — connect to relay, authenticate, list devices.
  /// Uses the app's stored Ed25519 identity for relay authentication.
  /// Body: {
  ///   "host": "10.0.0.17",   // optional, defaults to relay.radiokit.app
  ///   "port": 9000,         // optional, defaults to 443
  /// }
  Future<Response> _handleCloudConnect(Request request) async {
    final body = await _parseBody(request);
    final rawHost = body['host'] as String? ?? '';
    final port = (body['port'] as num?)?.toInt() ?? 443;

    // Use the app's stored Ed25519 identity
    final identityProvider = _cloudIdentityProvider;
    if (!identityProvider.hasIdentity) {
      await identityProvider.initialize();
    }
    final account = identityProvider.account;
    if (account == null || account.isEmpty) {
      return _error('no_identity', 'No Ed25519 identity found in app. Create one first via POST /api/cloud/account.', status: 400);
    }

    // Parse host:port — try the connected device's cloud_url first if not specified
    String host = rawHost.trim();
    int resolvedPort = port;

    if (host.isEmpty && _deviceProvider.isConnected) {
      try {
        final cloudInfo = await _deviceProvider.sendGetCloudInfo();
        if (cloudInfo != null && cloudInfo.url.isNotEmpty) {
          final colonPos = cloudInfo.url.lastIndexOf(':');
          if (colonPos > 0) {
            host = cloudInfo.url.substring(0, colonPos).trim();
            resolvedPort = int.tryParse(
                cloudInfo.url.substring(colonPos + 1)) ?? port;
          } else {
            host = cloudInfo.url.trim();
          }
        }
      } catch (_) {
        // Fall through to default
      }
    }

    if (host.isEmpty) {
      host = 'relay.radiokit.app';
    }

    final scheme = resolvedPort == 443 ? 'wss' : 'ws';
    final url = '$scheme://$host:$resolvedPort';

    _cloudHost = host;
    _cloudPort = resolvedPort;
    _cloudAccount = account;

    try {
      // Clean up any existing connection
      await _cloudWs?.disconnect();

      final ws = WebSocketService()..account = account;
      _cloudWs = ws;

      // Use the app's stored identity for relay auth
      ws.identity = identityProvider.identityService;
      // Use completers to bridge the async event-driven flow
      final authCompleter = Completer<void>();
      final listCompleter = Completer<List<String>>();
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

      ws.onConnectionLost = (reason) {
        if (!authCompleter.isCompleted) {
          authCompleter.completeError(Exception('Connection lost: $reason'));
        }
        if (!listCompleter.isCompleted) {
          listCompleter.completeError(Exception('Connection lost: $reason'));
        }
      };

      // Connect to relay — auth_request is sent automatically by WebSocketService
      await ws.connect(url).timeout(const Duration(seconds: 10));

      // Wait for auth to complete
      await authCompleter.future.timeout(const Duration(seconds: 15));

      if (authError != null) {
        return _error('auth_failed', authError!, status: 401);
      }

      // Request device list
      ws.sendListDevices();

      // Wait for device list
      final devices = await listCompleter.future.timeout(const Duration(seconds: 10));

      return _json({
        'ok': true,
        'host': host,
        'port': resolvedPort,
        'account': account,
        'devices': devices,
      });
    } on TimeoutException {
      return _error('timeout',
          'Timed out waiting for relay response', status: 504);
    } catch (e) {
      return _error('cloud_error', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/cloud/devices — returns cached device list from relay.
  Future<Response> _handleCloudDevices(Request request) async {
    if (_cloudWs == null) {
      return _error('not_connected', 'Not connected to a relay', status: 503);
    }
    return _json({
      'connected': _cloudWs!.isConnected,
      'host': _cloudHost,
      'port': _cloudPort,
      'account': _cloudAccount,
      'devices': _cloudDevices,
    });
  }

  /// Handle POST /api/cloud/join — join a specific device on the relay.
  /// Body: { "device": "DeviceName" }
  /// Wires up the DeviceProvider so widget interaction works through the cloud.
  Future<Response> _handleCloudJoin(Request request) async {
    if (_cloudWs == null) {
      return _error('not_connected', 'Not connected to a relay', status: 503);
    }
    final body = await _parseBody(request);
    final deviceName = body['device'] as String?;
    if (deviceName == null || deviceName.isEmpty) {
      return _error('invalid_params', 'device is required');
    }

    final scheme = _cloudPort == 443 ? 'wss' : 'ws';
    final url = '$scheme://$_cloudHost:$_cloudPort/$deviceName';

    try {
      // Wire up the DeviceProvider to use the cloud WebSocket as transport.
      // Store it so switchTransport can re-use it (instead of creating an
      // unauthenticated WebSocketService that can't relay frames).
      _deviceProvider.setCloudTransport(_cloudWs!);
      _deviceProvider.setTransport(_cloudWs!);

      // Wait for join confirmation via onCloudJoined callback
      final joinCompleter = Completer<bool>();
      _cloudWs!.onCloudJoined = (joinedDevice) {
        if (!joinCompleter.isCompleted) joinCompleter.complete(true);
      };

      await _deviceProvider.connectToDevice(
          DeviceInfo(
            id: url,
            name: deviceName,
            rssi: 0,
            hasFs: false,
            currentTransport: TransportType.cloud,
            transportAddress: url,
          ),
        );

      // Wait for join ACK or short delay
      final joined = await joinCompleter.future
          .timeout(const Duration(seconds: 5))
          .catchError((_) => false);

      // Save to history so device appears in models list.
      // Only save if no model with matching configName already exists
      // (UID may have already been received by _handleSettingsDeviceInfoData
      // during connectToDevice, which saves the model with correct UID).
      if (joined) {
        final alreadySaved = _historyProvider.pairedDevices
            .any((d) => d.configName == deviceName);
        if (!alreadySaved) {
          await _historyProvider.saveDevice(
            DeviceInfo(
              id: url,
              name: deviceName,
              rssi: 0,
              hasFs: false,
              currentTransport: TransportType.cloud,
              transportAddress: url,
            ),
            'cloud',
            configName: deviceName,
          );
        }
      }

      return _json({
        'ok': joined,
        'device': deviceName,
        'host': _cloudHost,
        'port': _cloudPort,
        'message': joined
            ? 'Connected to $deviceName via cloud relay'
            : 'Join timed out — device may be offline',
      });
    } catch (e) {
      return _error('cloud_error', e.toString(), status: 500);
    }
  }

  /// Handle POST /api/cloud/disconnect — disconnect from the relay.
  Future<Response> _handleCloudDisconnect(Request request) async {
    await _cloudWs?.disconnect();
    _cloudWs = null;
    _cloudDevices = [];
    return _json({'ok': true, 'message': 'Disconnected from relay'});
  }

  // ── Session / Route ──────────────────────────────────────────────────────────

  Future<Response> _handleSessionRoute(Request request) async {
    final route = _currentRouteGetter();
    final dp = _deviceProvider;
    return _json({
      'route': route,
      if (dp.isConnected) ...{
        'activePage': dp.activePage,
        'numPages': dp.numPages,
        'pages': dp.pageNames,
      },
    });
  }

  /// Handle GET /api/session/state -- rich view state for follow-mode verification.
  Future<Response> _handleSessionState(Request request) async {
    final state = _viewStateGetter?.call() ?? {'route': _currentRouteGetter()};
    return _json(state);
  }


  /// Handle GET /api/session/sheets -- available follow-mode sheets per route.
  /// Returns [_sheetDefinitions] as the single source of truth.
  Future<Response> _handleSessionSheets(Request request) async {
    return _json({'sheets': _sheetDefinitions});
  }

  // ── Designs ──────────────────────────────────────────────────────────────────

  Future<Response> _handleDesigns(Request request) async {
    final designs = _designsProvider.designs.map((d) => {
      'id': d.id,
      'name': d.name,
      'timestamp': d.timestamp,
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

  Future<Response> _handleDesignJson(Request request, String id) async {
    try {
      final design = _designsProvider.designs.firstWhere((d) => d.id == id);
      if (design.jsonContent == null) {
        return _error('no_content', 'Design has no JSON content', status: 400);
      }
      final json = jsonDecode(design.jsonContent!) as Map<String, dynamic>;
      return _json(json);
    } catch (_) {
      return _error('not_found', 'Design not found: $id', status: 404);
    }
  }

  Future<Response> _handleDesignHeader(Request request, String id) async {
    try {
      final design = _designsProvider.designs.firstWhere((d) => d.id == id);
      if (design.jsonContent == null) {
        return _error('no_content', 'Design has no JSON content', status: 400);
      }
      final json = jsonDecode(design.jsonContent!) as Map<String, dynamic>;
      final header = JsonArduinoGenerator.generate(json);
      return Response.ok(
        header,
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    } catch (_) {
      return _error('not_found', 'Design not found: $id', status: 404);
    }
  }

  // ── OTA Upload ────────────────────────────────────────────────────────────────

  /// Handle POST /api/ota/upload — accepts base64-encoded firmware and
  /// uploads it to the connected device via the OTA protocol.
  /// Supports optional `eraseAll` parameter to clear NVS + FS after update.
  Future<Response> _handleOtaUpload(Request request) async {
    _otaProgress = null; // Clear any stale progress from previous upload

    if (!_deviceProvider.isConnected) {
      return _error('not_connected', 'Not connected to a device', status: 503);
    }

    if (!_deviceProvider.hasOta) {
      return _error('ota_not_supported',
          'Connected device does not support OTA',
          status: 400);
    }

    final body = await _parseBody(request);
    final dataB64 = body['data'] as String?;
    if (dataB64 == null || dataB64.isEmpty) {
      return _error('invalid_params',
          'data (base64-encoded firmware) is required');
    }

    final eraseAll = body['eraseAll'] as bool? ?? false;

    List<int> firmware;
    try {
      firmware = base64Decode(dataB64);
    } catch (e) {
      return _error('invalid_encoding',
          'Failed to decode base64 data: $e',
          status: 400);
    }

    final deviceId = _deviceProvider.connectedDevice?.id ?? 'unknown';
    _otaProgress = (0, firmware.length, 'starting');
    _deviceOtaProgress.remove(deviceId);
    _deviceOtaProgress[deviceId] = (0, firmware.length, 'starting');

    try {
      await _deviceProvider.uploadFirmware(
        firmware,
        eraseAll: eraseAll,
        onProgress: (received, total) {
          _otaProgress = (received, total, 'uploading');
          _deviceOtaProgress[deviceId] = (received, total, 'uploading');
        },
      );

      _otaProgress = (firmware.length, firmware.length, 'rebooting');
      _deviceOtaProgress[deviceId] = (firmware.length, firmware.length, 'rebooting');

      return _json({
        'ok': true,
        'size': firmware.length,
        'eraseAll': eraseAll,
        'message': 'Firmware uploaded successfully — device rebooting',
      });
    } catch (e) {
      _otaProgress = null;
      _deviceOtaProgress.remove(deviceId);
      return _error('ota_failed', e.toString(), status: 500);
    }
  }

  /// Handle GET /api/ota/progress — returns current OTA upload progress.
  Future<Response> _handleOtaProgress(Request request) async {
    final progress = _otaProgress;
    if (progress == null) {
      return _json({
        'active': false,
        'received': 0,
        'total': 0,
        'status': 'idle',
      });
    }
    final r = progress.$1;
    final t = progress.$2;
    final s = progress.$3;
    return _json({
      'active': true,
      'received': r,
      'total': t,
      'status': s,
      'percentage': t > 0 ? ((r / t) * 100).round() : 0,
    });
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
    // Try a direct FS info to test the transport (PING was removed)
    try {
      await _deviceProvider.currentTransport.writePacket(
          FsProtocolService.buildInfo());
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

  // ── Library API ────────────────────────────────────────────────────────────

  Future<Response> _handleLibraryVersion(Request request) async {
    final lib = _libraryService;
    if (lib == null || !lib.isInitialized) {
      return _error('library_not_ready', 'Library service not initialized',
          status: 503);
    }
    return _json({'version': lib.version});
  }

  Future<Response> _handleLibraryDownload(Request request) async {
    final lib = _libraryService;
    if (lib == null || !lib.isInitialized) {
      return _error('library_not_ready', 'Library service not initialized',
          status: 503);
    }
    final zipBytes = await lib.downloadZip();
    return Response.ok(
      zipBytes,
      headers: {
        'content-type': 'application/zip',
        'content-length': '${zipBytes.length}',
        'content-disposition': 'attachment; filename="rk-arduino.zip"',
      },
    );
  }
}
