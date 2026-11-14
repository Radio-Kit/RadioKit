import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

import '../models/api_log_entry.dart';
import '../providers/account_provider.dart';
import '../providers/ble_provider.dart';
import '../providers/cloud_identity_provider.dart';
import '../providers/console_provider.dart';
import '../providers/debug_provider.dart';
import '../providers/designs_provider.dart';
import '../providers/device_provider.dart';
import '../providers/flasher_provider.dart';
import '../providers/history_provider.dart';
import '../providers/multi_device_provider.dart';
import '../providers/serial_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/app_version.dart';
import 'docs_service.dart';
import 'mcp/mcp_server.dart';
import 'mcp/radiokit_mcp_resources.dart';
import 'mcp/radiokit_mcp_tools.dart';

class RemoteAccessService {
  final DeviceProvider Function() _getActiveDevice;
  final BleProvider _bleProvider;
  final SerialProvider _serialProvider;
  final HistoryProvider _historyProvider;
  final SettingsProvider _settingsProvider;
  final ConsoleProvider _consoleProvider;
  final DebugProvider? _debugProvider;
  final DesignsProvider _designsProvider;
  final FlasherProvider _flasherProvider;
  final MultiDeviceProvider Function()? _getMultiDevice;
  final void Function(ApiLogEntry) _onLog;
  final void Function(String route)? _onFollowEvent;
  final DocsService? _docsService;

  HttpServer? _server;
  bool _isRunning = false;
  int _actualPort = 0;
  String _cachedLocalIp = '127.0.0.1';

  late final McpServer _mcpServer;
  late final RadioKitMcpTools _mcpTools;
  late final RadioKitMcpResources _mcpResources;

  bool get isRunning => _isRunning;
  int get actualPort => _actualPort;
  String get localIp => _cachedLocalIp;
  McpServer get mcpServer => _mcpServer;

  RemoteAccessService({
    required DeviceProvider Function() getActiveDevice,
    required BleProvider bleProvider,
    required SerialProvider serialProvider,
    required HistoryProvider historyProvider,
    required SettingsProvider settingsProvider,
    required ConsoleProvider consoleProvider,
    DebugProvider? debugProvider,
    required DesignsProvider designsProvider,
    required CloudIdentityProvider cloudIdentityProvider,
    required AccountProvider accountProvider,
    required FlasherProvider flasherProvider,
    MultiDeviceProvider Function()? getMultiDevice,
    required void Function(ApiLogEntry) onLog,
    void Function(String route)? onFollowEvent,
    String Function()? currentRouteGetter,
    Map<String, dynamic> Function()? viewStateGetter,
    Future<void> Function(String demoId)? connectDemo,
    DocsService? docsService,
  })  : _getActiveDevice = getActiveDevice,
        _bleProvider = bleProvider,
        _serialProvider = serialProvider,
        _historyProvider = historyProvider,
        _settingsProvider = settingsProvider,
        _consoleProvider = consoleProvider,
        _debugProvider = debugProvider,
        _designsProvider = designsProvider,
        _flasherProvider = flasherProvider,
        _getMultiDevice = getMultiDevice,
        _onLog = onLog,
        _onFollowEvent = onFollowEvent,
        _docsService = docsService {
    _mcpServer = McpServer(
      serverName: 'radiokit-app',
      serverVersion: AppVersion.semver,
      onToolInvoked: _handleToolInvoked,
    );

    _mcpTools = RadioKitMcpTools(
      getActiveDevice: _getActiveDevice,
      bleProvider: _bleProvider,
      serialProvider: _serialProvider,
      historyProvider: _historyProvider,
      settingsProvider: _settingsProvider,
      consoleProvider: _consoleProvider,
      debugProvider: _debugProvider,
      designsProvider: _designsProvider,
      flasherProvider: _flasherProvider,
      getMultiDevice: _getMultiDevice,
    );
    _mcpTools.registerAll(_mcpServer);

    _mcpResources = RadioKitMcpResources(
      getActiveDevice: _getActiveDevice,
      consoleProvider: _consoleProvider,
      debugProvider: _debugProvider,
      docsService: _docsService,
    );
    _mcpResources.registerAll(_mcpServer);
  }

  void _handleToolInvoked(String toolName, Map<String, dynamic> arguments) {
    // 1. Follow Mode Navigation
    final targetRoute = _followRouteForTool(toolName);
    if (targetRoute != null && _onFollowEvent != null) {
      _onFollowEvent(targetRoute);
    }

    // 2. Live Activity Logging
    _onLog(ApiLogEntry(
      timestamp: DateTime.now(),
      method: 'TOOL',
      path: toolName,
      statusCode: 200,
      durationMs: 0,
    ));
  }

  static String? _followRouteForTool(String toolName) {
    if (toolName.startsWith('radiokit_fs_')) return '/dev-tools/esp32-fs';
    if (toolName == 'radiokit_scan_devices') return '/models?sheet=pair';
    if (toolName == 'radiokit_disconnect') return '/models';
    if (toolName == 'radiokit_connect') return '/control';
    if (toolName.contains('widget') || toolName.contains('page')) return '/control';
    if (toolName.contains('design')) return '/designs';
    if (toolName.contains('nvs') || toolName.contains('reboot') || toolName.contains('reset')) return '/system';
    if (toolName.contains('console')) return '/system';
    if (toolName.contains('flasher')) return '/flasher';
    return null;
  }

  static String? _followRoute(String path) {
    if (path.startsWith('/api/fs/')) return '/dev-tools/esp32-fs';
    if (path.startsWith('/api/pair/')) return '/models?sheet=pair';
    if (path == '/api/connection/disconnect') return '/models';
    if (path.startsWith('/api/connection')) return '/control';
    if (path.startsWith('/api/widgets')) return '/control';
    if (path.startsWith('/api/designs')) return '/designs';
    if (path.startsWith('/api/settings/nvs')) return '/system';
    if (path.startsWith('/api/console')) return '/system';
    if (path.startsWith('/api/flasher/')) return '/flasher';
    if (path.startsWith('/api/models')) return '/models';
    return null;
  }

  @visibleForTesting
  static String? testOnlyFollowRoute(String path) => _followRoute(path);

  Future<Response> _handleRequest(Request request) async {
    final path = request.url.path;

    // SSE endpoint
    if ((path == 'sse' || path == 'sse/') && request.method == 'GET') {
      return _mcpServer.transport.handleSseConnect(request);
    }

    // Messages endpoint
    if ((path == 'messages' || path == 'messages/') && request.method == 'POST') {
      return await _mcpServer.handleMessages(request);
    }

    // Landing root
    if ((path.isEmpty || path == '/' || path == '') && request.method == 'GET') {
      return Response.ok(
        'RadioKit In-App Model Context Protocol (MCP) Server\n'
        'Connect via SSE to: /sse\n'
        'Post JSON-RPC messages to: /messages?sessionId=<sessionId>\n',
        headers: {'content-type': 'text/plain; charset=utf-8'},
      );
    }

    // Status endpoint
    if ((path == 'status' || path == 'status/') && request.method == 'GET') {
      return Response.ok(
        jsonEncode({
          'server': 'radiokit-app',
          'protocol': 'mcp',
          'version': '2.2.0',
          'status': 'running',
          'port': 7007,
          'localIp': _cachedLocalIp,
        }),
        headers: {'content-type': 'application/json'},
      );
    }

    return Response.notFound('Not found');
  }

  Future<String?> start() async {
    if (_isRunning) return null;

    final pipeline = const Pipeline()
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_logMiddleware());
    final handler = pipeline.addHandler(_handleRequest);

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
    _mcpServer.dispose();
    await _server?.close(force: true);
    _server = null;
    _isRunning = false;
    _actualPort = 0;
  }

  static Middleware _corsMiddleware() {
    return (innerHandler) {
      return (request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': '*',
          });
        }
        final response = await innerHandler(request);
        return response.change(headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': '*',
        });
      };
    };
  }

  Middleware _logMiddleware() {
    return (innerHandler) {
      return (request) async {
        final stopwatch = Stopwatch()..start();
        final response = await innerHandler(request);
        stopwatch.stop();

        _onLog(ApiLogEntry(
          timestamp: DateTime.now(),
          method: request.method,
          path: request.url.path,
          statusCode: response.statusCode,
          durationMs: stopwatch.elapsedMilliseconds,
        ));

        return response;
      };
    };
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
}
