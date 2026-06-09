import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/device_info.dart';
import '../models/widget_config.dart';
import '../models/protocol.dart';
import '../services/transport_service.dart';
import '../services/protocol_service.dart';
import '../services/fs_protocol_service.dart';
import '../services/ota_protocol_service.dart';
import '../services/settings_protocol_service.dart';
import '../services/debug_transport.dart';
import '../services/demo_transport.dart';
import '../services/demo_fs_transport.dart';

import '../providers/console_provider.dart';
import '../providers/skin_provider.dart';
import '../providers/debug_provider.dart';
import '../models/console_entry.dart';
import '../models/fs_entry.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import '../services/secure_storage_service.dart';

enum DeviceConnectionState {
  disconnected,
  connecting,
  fetchingConfig,
  connected,
  error,
  otaRebooting,
}

/// Pending VAR_UPDATE entry for retry logic.
class _PendingUpdate {
  final int widgetId;
  final int seq;
  final List<int> values;
  int retries;
  Timer? timer;

  _PendingUpdate({
    required this.widgetId,
    required this.seq,
    required this.values,
  }) : retries = 0;
}

/// Manages the connected device, widget configuration, and variable
/// polling/update loop. Transport-agnostic.
class DeviceProvider extends ChangeNotifier {
  TransportService _transport;
  final ConsoleProvider? _console;
  final SkinProvider? _skinProvider;

  DeviceInfo?              _connectedDevice;
  DeviceConnectionState    _connectionState = DeviceConnectionState.disconnected;
  String?                  _configName;
  String?                  _description;
  List<WidgetConfig>       _widgets  = [];
  int                      _orientation = kOrientationLandscape;
  RadioWidgetState?        _widgetState;
  String?                  _errorMessage;
  int?                     _rssi;
  int?                     _latencyMs;



  Timer?                   _telemetryTimer;
  Timer?                   _confTimeoutTimer;
  DateTime?                _lastRxAt;
  DateTime?                _lastTxAt;
  final DebugLogSink?            _debugSink;
  Completer<void>?         _confCompleter;  Completer<Map<String, int>>? _bleInfoCompleter;
  int _deviceFeatures = 0;
  Completer<int>? _featuresCompleter;
  Map<String, dynamic>? _chipInfo;
  Completer<void>? _chipInfoCompleter;
  Completer<int>? _otaCompleter;
  Completer<({int status, int? value})>? _nvsRawReadCompleter;
  Completer<int>? _nvsRawWriteCompleter;
  Completer<int>? _authCompleter;  // For CMD_PWD_AUTH response
  Timer? _authTimeoutTimer;
  static const Duration _authTimeout = Duration(seconds: 60);
  DateTime? _connectedAt;
  DateTime? _authenticatedAt;
  DateTime? get authTimeoutAt =>
      _connectedAt != null ? _connectedAt!.add(_authTimeout) : null;
  Duration get remainingAuthTime {
    if (_authenticated || _connectedAt == null) return Duration.zero;
    final remaining = _authTimeout - DateTime.now().difference(_connectedAt!);
    return remaining.isNegative ? Duration.zero : remaining;
  }  final Map<int, _PendingUpdate> _pendingUpdates = {};
  int _nextSeq = 0;

  // ── FS (bulk protocol) ────────────────────────────────────────────────
  /// Active FS request per sub-cmd. The device may also send unsolic­ited
  /// FS frames (e.g. an upload begin from a server-side tool) — those
  /// are dispatched to [_handleUnsolicitedFs] instead.
  /// FS busy flag — when true, the ping timer is suppressed to prevent
  /// PONG responses from interleaving with FS response notifications over BLE.
  /// Uses a reference count so multi-chunk operations (HTTP readFile/writeFile)
  /// can hold the lock for their entire duration while per-chunk callers
  /// (["_ProviderAdapter.sendFs"]) also acquire/release without prematurely
  /// releasing an outer lock.
  int _fsBusyCount = 0;
  bool _fsBusy = false;

  /// Lock the FS bus — pings will be suppressed until all callers have
  /// called [setFsBusy(false)] an equal number of times.
  /// Called by [_ProviderAdapter.sendFs] around every FS operation, and by
  /// the HTTP handlers around entire multi-chunk read/write operations.
  void setFsBusy(bool busy) {
    if (busy) {
      _fsBusyCount++;
    } else {
      if (_fsBusyCount > 0) _fsBusyCount--;
    }
    _fsBusy = _fsBusyCount > 0;
  }

  /// Whether an FS frame exchange is in progress. Used by
  /// [FilesystemExplorerScreen] to defer its initial refresh when the
  /// transport is busy (e.g. an HTTP API write is in flight).
  bool get isFsBusy => _fsBusy;

  /// Pending FS responses per sub-cmd. Uses a List (queue) per sub-cmd so
  /// pipelined requests (e.g. readFile sending the next READ before the
  /// previous response arrives) don't overwrite each other's completers.
  /// Responses are matched to requests in FIFO order.
  final Map<int, List<Completer<ParsedFsPacket>>> _pendingFs = {};

  /// Cached FS tree: maps directory path to its listing (FsEntry list).
  /// Populated by [prefetchFsTree] after FS detection, so the filesystem
  /// explorer screen can render immediately without a network round-trip.
  /// Cleared on disconnect.
  Map<String, List<FsEntry>>? _fsTreeCache;

  /// Whether the root listing ("/") has been cached. Use this to show
  /// cached data instantly while a background refresh runs.
  bool get fsCacheReady =>
      _fsTreeCache != null && _fsTreeCache!.containsKey('/');

  /// The cached FS tree, or null if not yet populated.
  Map<String, List<FsEntry>>? get fsTreeCache => _fsTreeCache;

  /// Pre-fetch the root directory listing and cache it for instant
  /// filesystem explorer loading. Runs in the background (fire-and-forget).
  /// Starts after a short delay so the control screen has priority.
  /// Uses [sendFs] directly (via [FsProtocolService]) to avoid circular
  /// dependency with [DeviceFsService].
  ///
  /// NOTE: uses [_transport.isConnected] instead of [isConnected] because
  /// [isConnected] requires the full config load to complete, while the
  /// prefetch runs immediately after FS detection (config may still be
  /// loading).
  Future<void> prefetchFsTree() async {
    if (_connectedDevice == null || !_connectedDevice!.hasFs) return;
    if (!_transport.isConnected) return;
    // Brief delay: if the user tapped OPEN_CONTROLLER, let that render
    // before we consume BLE bandwidth with FS operations.
    await Future.delayed(const Duration(milliseconds: 500));
    if (_connectedDevice == null) return;
    if (!_transport.isConnected) return;
    try {
      setFsBusy(true);
      final resp = await sendFs(FsProtocolService.buildList('/'),
          timeout: const Duration(seconds: 3));
      if (resp == null) return;
      final entries = FsProtocolService.parseListData(resp.payload);
      if (entries == null) return;
      _fsTreeCache = {'/': entries};
      _log('FS tree cached: ${entries.length} entries at /',
          level: ConsoleLogLevel.success);
      notifyListeners();
    } catch (e) {
      _log('FS tree prefetch failed: $e', level: ConsoleLogLevel.info);
      // Non-critical; explorer will fetch on demand
    } finally {
      setFsBusy(false);
    }
  }

  /// Cached designer-format JSON for fast UI rendering.
  /// Populated from device CONF_DATA or demo assets.
  Map<String, dynamic>? _deviceConfigJson;

  /// The cached designer-format JSON config, or null if not yet loaded.
  Map<String, dynamic>? get deviceConfigJson => _deviceConfigJson;

  DeviceProvider({
    required TransportService transport,
    DebugLogSink? debugSink,
    ConsoleProvider? console,
    SkinProvider? skinProvider,
  })  : _debugSink = debugSink,
        _console = console,
        _skinProvider = skinProvider,
        _transport = transport {
    setTransport(transport);
  }

  void _log(String message, {ConsoleLogLevel level = ConsoleLogLevel.info}) {
    _console?.log(message, level: level);
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  DeviceInfo?           get connectedDevice  => _connectedDevice;
  DeviceConnectionState get connectionState  => _connectionState;
  String?               get configName       => _configName;
  String?               get description      => _description;
  List<WidgetConfig>    get widgets          => List.unmodifiable(_widgets);
  int                   get orientation      => _orientation;
  RadioWidgetState?     get widgetState      => _widgetState;
  String?               get errorMessage     => _errorMessage;
  bool                  get isConnected      =>
      _connectionState == DeviceConnectionState.connected;
  TransportService      get currentTransport => _transport;
  int?                  get rssi             => _rssi;
  int?                  get latencyMs        => _latencyMs;

  /// Whether the connected device supports OTA firmware updates.
  bool get hasOta => (_deviceFeatures & kFeatureOta) != 0;

  /// Cached chip info from the device, or null if not yet fetched.
  Map<String, dynamic>? get chipInfo => _chipInfo;

  /// Whether the device has a connection password set (detected via features bitmask).
  bool get hasPassword => (_deviceFeatures & kFeatureHasConnPassword) != 0;

  /// Whether the device has an admin password set.
  bool get hasAdminPassword => (_deviceFeatures & kFeatureHasAdminPassword) != 0;

  /// Current authentication state (user mode).
  bool get isAuthenticated => _authenticated;

  /// Whether admin mode is active (or no admin password means auto-admin).
  bool get isAdminMode => _authenticatedAdmin || !hasAdminPassword;

  /// Whether user mode is active (authenticated but not admin).
  bool get isUserMode => _authenticated && !isAdminMode;

  /// Start the 60s auth timeout — auto-disconnect if not authenticated.
  void _startAuthTimeout() {
    _authTimeoutTimer?.cancel();
    _connectedAt = DateTime.now();
    _authenticatedAt = null;
    _authTimeoutTimer = Timer(_authTimeout, () {
      if (!_authenticated && _transport.isConnected) {
        _log('Auth timeout — disconnecting (not authenticated within 60s)',
            level: ConsoleLogLevel.warning);
        disconnect();
      }
    });
  }

  /// Cancel the auth timeout (called on successful auth or disconnect).
  void _cancelAuthTimeout() {
    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = null;
  }

  // ── NVS Config API (CMD_SET_CONF / CMD_PWD_AUTH) ─────────────────────────

  bool _authenticated = false;
  bool _authenticatedAdmin = false;

  /// Read a raw NVS uint8 key from the device via settings protocol.
  /// Returns (status, value) where status=0 (ok) or 1 (error).
  /// Value is null on error or timeout.
  Future<({int status, int? value})> readNvsRawKey(String key) async {
    if (!_transport.isConnected) {
      return (status: kSettingsNvsRawError, value: null);
    }
    final completer = Completer<({int status, int? value})>();
    _nvsRawReadCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildNvsRawRead(key));
    } catch (e) {
      _nvsRawReadCompleter = null;
      _log('readNvsRawKey failed: $e', level: ConsoleLogLevel.error);
      return (status: kSettingsNvsRawError, value: null);
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 5));
    } on TimeoutException catch (_) {
      _nvsRawReadCompleter = null;
      return (status: kSettingsNvsRawError, value: null);
    } catch (_) {
      _nvsRawReadCompleter = null;
      return (status: kSettingsNvsRawError, value: null);
    }
  }

  /// Write a raw uint8 value to an NVS key on the device via settings protocol.
  /// Returns 0 (ok) or 1 (error) on success/timeout.
  Future<int> writeNvsRawKey(String key, int value) async {
    if (!_transport.isConnected) return kSettingsNvsRawError;
    final completer = Completer<int>();
    _nvsRawWriteCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildNvsRawWrite(key, value));
    } catch (e) {
      _nvsRawWriteCompleter = null;
      _log('writeNvsRawKey failed: $e', level: ConsoleLogLevel.error);
      return kSettingsNvsRawError;
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 5));
    } on TimeoutException catch (_) {
      _nvsRawWriteCompleter = null;
      return kSettingsNvsRawError;
    } catch (_) {
      _nvsRawWriteCompleter = null;
      return kSettingsNvsRawError;
    }
  }

  /// Send factory reset command via settings protocol — erases NVS config and reboots.
  /// Returns true if the command was sent successfully (device will reboot).
  Future<bool> sendFactoryReset() async {
    if (!_transport.isConnected) return false;
    try {
      await _transport.writePacket(SettingsProtocolService.buildFactoryReset());
      return true;
    } catch (e) {
      _log('sendFactoryReset failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
  }

  /// Send updated config values to the device's NVS via settings protocol.
  /// Pass null for fields you don't want to change.
  /// Returns true on success, false on timeout/error.
  Future<bool> sendSetConf({
    String? name,
    String? description,
    String? password,
    String? adminPassword,
  }) async {
    if (!_transport.isConnected) return false;
    try {
      final pkt = SettingsProtocolService.buildSetConf(
        name: name,
        description: description,
        password: password,
        adminPassword: adminPassword,
      );
      await _transport.writePacket(pkt);
      // Wait for the re-broadcasted CONF_DATA on widget protocol
      // (Arduino _handleSettingsSetConf re-broadcasts CONF_DATA via _handleGetConf())
      final completer = Completer<void>();
      _confCompleter = completer;
      try {
        await completer.future.timeout(const Duration(seconds: 5));
        // Also request fresh device info to update name/desc
        unawaited(_requestDeviceInfo());
        return true;
      } on TimeoutException catch (_) {
        return false;
      } finally {
        if (_confCompleter == completer) {
          _confCompleter = null;
        }
      }
    } catch (e) {
      _log('sendSetConf failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
  }

  /// Authenticate with the device password (connection auth).
  ///
  /// The entered password is sent as normal connection auth first.
  /// If the device has an admin password and connection auth fails,
  /// the password is automatically retried as admin auth (since admin
  /// password can also be used for connection).
  ///
  /// Returns true on success, false on mismatch or error.
  Future<bool> authenticate(String password) async {
    if (!_transport.isConnected) return false;
    if (_authenticated && _authenticatedAdmin) return true;
    try {
      // Try connection auth first — via settings protocol (0xDD)
      final pkt = SettingsProtocolService.buildPwdAuth(password);
      await _transport.writePacket(pkt);
      final completer = Completer<int>();
      _authCompleter = completer;
      try {
        final status = await completer.future.timeout(const Duration(seconds: 5));
        if (status == kSettingsPwdOk) {
          _authenticated = true;
          _authenticatedAt = DateTime.now();
          _cancelAuthTimeout();
          notifyListeners();
          return true;
        }
        // Connection auth failed — retry as admin auth
        // (admin password can also be used for connection)
        if (hasAdminPassword) {
          return authenticateAdmin(password);
        }
        return false;
      } on TimeoutException catch (_) {
        return false;
      } finally {
        _authCompleter = null;
      }
    } catch (e) {
      _log('authenticate failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
  }

  /// Authenticate as admin with the admin password.
  /// Uses CMD_PWD_AUTH with the admin flag byte.
  /// Returns true on success, false on mismatch or error.
  Future<bool> authenticateAdmin(String password) async {
    if (!_transport.isConnected) return false;
    if (_authenticatedAdmin) return true;
    try {
      final pkt = SettingsProtocolService.buildPwdAuth(password, admin: true);
      await _transport.writePacket(pkt);
      final completer = Completer<int>();
      _authCompleter = completer;
      try {
        final status = await completer.future.timeout(const Duration(seconds: 5));
        if (status == kSettingsPwdOk) {
          _authenticated = true;
          _authenticatedAdmin = true;
          _authenticatedAt = DateTime.now();
          _cancelAuthTimeout();
          notifyListeners();
          return true;
        }
        return false;
      } on TimeoutException catch (_) {
        return false;
      } finally {
        _authCompleter = null;
      }
    } catch (e) {
      _log('authenticateAdmin failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
  }

  // ── Transport swap ───────────────────────────────────────────────────────────

  void setTransport(TransportService transport) {
    // 1. Strip all existing DebugTransport wrappers to find the true base transport
    TransportService base = transport;
    while (base is DebugTransport) {
      base = (base).inner;
    }
    
    // 2. Identify current true base
    TransportService currentBase = _transport;
    while (currentBase is DebugTransport) {
      currentBase = (currentBase).inner;
    }
        
    // 3. Check if we have exactly the right number of wrapper layers
    bool hasCorrectLayers = false;
    if (_debugSink != null) {
      hasCorrectLayers = (_transport is DebugTransport) && 
                         ((_transport as DebugTransport).inner == currentBase);
    } else {
      hasCorrectLayers = identical(_transport, currentBase);
    }

    // 4. If base is same AND layers are correct, only update callbacks
    if (identical(currentBase, base) && hasCorrectLayers) {
      _transport.onPacketReceived = _handlePacket;
      _transport.onConnectionLost = _handleConnectionLost;
      return;
    }

    // 5. Build exactly one layer of wrapper if sink is available
    TransportService next = base;
    if (_debugSink != null) {
      next = DebugTransport(inner: base, sink: _debugSink);
    }
    
    _transport = next;

    // 6. Always ensure callbacks are assigned to the current transport instance
    _transport.onPacketReceived = _handlePacket;
    _transport.onFsPacketReceived = _handleFsPacket;
    _transport.onOtaPacketReceived = _handleOtaPacket;
    _transport.onSettingsPacketReceived = _handleSettingsPacket;
    _transport.onConnectionLost = _handleConnectionLost;

    // 7. Synchronize DebugProvider if it's our sink
    if (_debugSink is DebugProvider) {
      (_debugSink).attachTransport(_transport);
    }
  }

  // ── Connection ─────────────────────────────────────────────────────────────

  Future<void> connectToDevice(DeviceInfo device, {int baudRate = 1000000}) async {
    _connectionState = DeviceConnectionState.connecting;
    _connectedDevice = device;
    _errorMessage    = null;
    _configName      = null;
    _description     = null;
    _authenticated   = false;
    _authenticatedAdmin = false;
    _authCompleter   = null;
    notifyListeners();

    _log('CONNECTING TO: ${device.name} (${device.id})');
    try {
      await _transport.connect(device.id, baudRate: baudRate);
      if (_connectionState == DeviceConnectionState.disconnected) return;
    } catch (e) {
      _log('CONNECTION FAILED: $e', level: ConsoleLogLevel.error);
      _errorMessage    = 'Connection failed: $e';
      _connectionState = DeviceConnectionState.error;
      await _transport.disconnect(); // Hardened cleanup
      notifyListeners();
      return;
    }

    await Future.delayed(const Duration(milliseconds: 3500));
    if (_connectionState == DeviceConnectionState.disconnected) return;

    await _requestConfig();

    // Request device info (name, description, proto version) via settings protocol        unawaited(_requestDeviceInfo());

    // Request features after config loads — fire-and-forget
    // Auth timeout is started in _handleFeaturesData() when hasPassword is detected.
    unawaited(_requestFeatures());

    // Request chip info — will be fetched on first display
    unawaited(_requestChipInfo());

    // Start FS detection in parallel — uses INFO instead of PING
    unawaited(_detectFs());
  }

  /// Detect filesystem support using FS_INFO (instead of the old FS_PING).
  /// Resilient to no-FS boards and transport jitter.
  Future<void> _detectFs() async {
    if (_connectedDevice == null) return;
    if (_connectedDevice!.hasFs) return; // already true (e.g. demos)
    for (int attempt = 0; attempt < 3; attempt++) {
      if (_connectionState == DeviceConnectionState.disconnected) return;
      if (!_transport.isConnected) return;
      final resp = await sendFs(
        FsProtocolService.buildInfo(),
        timeout: const Duration(milliseconds: 1500),
      );
      if (resp == null) {
        await Future.delayed(const Duration(milliseconds: 250));
        continue;
      }
      // INFO returns 11 bytes when mounted, or a 1-byte error code (NO_FS) when not.
      final info = FsProtocolService.parseInfoData(resp.payload);
      if (info != null) {
        _connectedDevice = _connectedDevice!.copyWith(hasFs: true);
        _log('FS_INFO OK — filesystem detected (${_connectedDevice!.name})',
            level: ConsoleLogLevel.success);
        notifyListeners();
        // Start background FS tree prefetch for instant explorer loading
        unawaited(prefetchFsTree());
        return;
      }
    }
    _log('FS_INFO: no response after 3 attempts — assuming no FS',
        level: ConsoleLogLevel.info);
  }

  Future<void> loadDemo(String demoId) async {
    _connectionState = DeviceConnectionState.connecting;      _connectedDevice = DeviceInfo(
      id: 'demo_$demoId',
      name: demoId.replaceAll('_', ' '),
      rssi: -50,
      hasFs: true,
    );
    _deviceFeatures = 0;
    _errorMessage = null;
    notifyListeners();

    setTransport(DemoFsTransport());
    await _transport.connect(_connectedDevice!.id);

    // Load config from designer-format JSON asset
    final assetPath = 'assets/demos/${demoId.toLowerCase()}.json';
    try {
      final jsonStr = await rootBundle.loadString(assetPath);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;

      final config = data['config'] as Map<String, dynamic>? ?? {};
      final canvas = data['canvas'] as Map<String, dynamic>? ?? {};

      _configName = config['name'] as String? ?? demoId;
      _description = config['description'] as String? ?? 'Interactive Demo Mode';

      // Infer orientation from canvas size (array [w, h] or legacy string)
      final rawSize = canvas['size'];
      int cw, ch;
      if (rawSize is List && rawSize.length >= 2) {
        cw = (rawSize[0] as num?)?.toInt() ?? 200;
        ch = (rawSize[1] as num?)?.toInt() ?? 100;
      } else if (rawSize is String) {
        final parts = rawSize.split(' x ');
        cw = int.tryParse(parts[0]) ?? 200;
        ch = int.tryParse(parts[1]) ?? 100;
      } else {
        cw = 200;
        ch = 100;
      }
      _orientation = cw >= ch
          ? kOrientationLandscape
          : kOrientationPortrait;

      // Parse widgets and build name→widgetId lookup
      final widgetsJson = data['widgets'] as List<dynamic>? ?? [];
      final nameToId = <String, int>{};
      _widgets = [];
      for (final w in widgetsJson) {
        final parsed = _widgetConfigFromDesignerJson(w as Map<String, dynamic>);
        _widgets.add(parsed);
        final widgetName = w['name'] as String?;
        if (widgetName != null && widgetName.isNotEmpty) {
          nameToId[widgetName] = parsed.widgetId;
        }
      }

      _widgetState = RadioWidgetState.initial(_widgets);

      // Apply initial output values (keyed by widget name, top-level in new format)
      final initialOutputs = (data['initialOutputs'] ?? config['initialOutputs']) as Map<String, dynamic>?;
      if (initialOutputs != null) {
        for (final entry in initialOutputs.entries) {
          final wid = nameToId[entry.key];
          if (wid == null) continue;
          final value = entry.value;
          if (value is List) {
            _widgetState =
                _widgetState?.copyWithOutput(wid, value.cast<int>());
          } else if (value is String) {
            _widgetState = _widgetState?.copyWithOutput(wid, value);
          }
        }
      }

      // Apply initial input values (keyed by widget name, top-level in new format)
      final initialInputs = (data['initialInputs'] ?? config['initialInputs']) as Map<String, dynamic>?;
      if (initialInputs != null) {
        for (final entry in initialInputs.entries) {
          final wid = nameToId[entry.key];
          if (wid == null) continue;
          final value = entry.value;
          if (value is List) {
            _widgetState =
                _widgetState?.copyWithInput(wid, value.cast<int>());
          }
        }
      }

      // Cache the original designer JSON for fast UI rendering.
      _deviceConfigJson = data;

      _connectionState = DeviceConnectionState.connected;
      _log('CONFIG LOADED: "$_configName" with ${_widgets.length} widgets',
          level: ConsoleLogLevel.success);
    } catch (e) {
      _log('FAILED TO LOAD DEMO "$demoId": $e', level: ConsoleLogLevel.error);
      _widgets = [];
      _orientation = kOrientationPortrait;
      _connectionState = DeviceConnectionState.error;
      _errorMessage = 'Failed to load demo config: $e';
    }

    _startPolling();
    notifyListeners();
  }

  /// Parses a [WidgetConfig] from the designer-format JSON used by the
  /// designer UI and stored in `assets/demos/*.json`.
  WidgetConfig _widgetConfigFromDesignerJson(Map<String, dynamic> w) {
    final typeStr = w['type'] as String? ?? '';
    final typeId = _typeNameToId(typeStr);
    final name = w['name'] as String? ?? '';
    final labelObj = w['label'] as Map<String, dynamic>?;
    final labelText = (labelObj?['text'] as String?) ?? name;

    final pos = w['position'] as List? ?? [0, 0, 0];
    final size = w['size'] as List? ?? [10, 10];
    final props = w['properties'] as Map<String, dynamic>? ?? {};

    final widgetId = (props['widgetId'] as num?)?.toInt() ?? 0;
    final x = ((pos[0] as num?)?.toDouble() ?? 0);
    final y = ((pos[1] as num?)?.toDouble() ?? 0);
    final rotation = (pos[2] as num?)?.toInt() ?? 0;

    // Convert designer JSON grid-unit sizes to wire SCALE/ASPECT ×10 values.
    // WidgetConfig stores width as SCALE×10 and height as ASPECT×10, used by
    // DeviceDesignerBridge to compute grid-unit sizes via designer defaults.
    final rawW = size[0];
    final rawH = size[1];
    int width = 10;  // SCALE ×10
    int height = 10; // ASPECT ×10
    final designerType = _wireTypeToDesignerType(typeId);
    if (designerType != null) {
      final (defaultW, defaultH) = DesignerElement.defaultSize(designerType);
      final jsonH = (rawH is num) ? rawH.toInt() : defaultH;
      if (defaultH > 0) {
        height = (jsonH / defaultH * 10).round().clamp(0, 255);
      }
      final ar = DesignerElement.aspectRatioFor(designerType, props);
      final jsonW = (rawW is num) ? rawW.toInt() : defaultW;
      if (ar != null) {
        // Fixed-aspect: SCALE is unused by bridge (width = h × ar)
        width = 10;
      } else {
        // Free-form: need SCALE to achieve jsonW width
        final aspectF = height / 10.0;
        if (aspectF > 0 && defaultW > 0) {
          final scaleF = jsonW / (defaultW * aspectF);
          width = (scaleF * 10).round().clamp(0, 255);
        }
      }
    }

    // ── variant ──────────────────────────────────────────────────
    final variantStr =
        (w['variant'] as String?) ?? (props['variant'] as String?);
    int variant = 0;
    switch (variantStr) {
      case 'toggle':
        variant = 1;
        break;
      case 'multiSelect':
        variant = 1;
        break;
      case 'gasPedal':
        variant = 0x80;
        break;
      case 'steeringWheel':
        variant = 0x80;
        break;
    }

    // ── string fields ─────────────────────────────────────────────
    final onText = props['onText'] as String? ?? '';
    final offText = props['offText'] as String? ?? '';
    final icon = props['onIcon'] as String? ?? '';

    // For Multiple widgets, build pipe-delimited content from items
    String content = '';
    if (typeId == kWidgetMultiple) {
      final items = props['items'] as List? ?? [];
      content = items
          .map((item) {
            final m = item as Map;
            final onLabel = m['onLabel'] as String? ?? '';
            final onIcon = m['onIcon'] as String? ?? '';
            if (onIcon.isNotEmpty) return '$onLabel:$onIcon';
            return onLabel;
          })
          .join('|');
    }

    // ── strMask ───────────────────────────────────────────────────
    int strMask = 0;
    if (labelText.isNotEmpty) strMask |= kStrMaskLabel;
    if (icon.isNotEmpty) strMask |= kStrMaskIcon;
    if (onText.isNotEmpty) strMask |= kStrMaskOnText;
    if (offText.isNotEmpty) strMask |= kStrMaskOffText;
    if (content.isNotEmpty) strMask |= kStrMaskContent;

    return WidgetConfig(
      typeId: typeId,
      widgetId: widgetId,
      x: x,
      y: y,
      width: width,
      height: height,
      variant: variant,
      strMask: strMask,
      label: labelText,
      icon: icon,
      onText: onText,
      offText: offText,
      content: content,
      rotation: rotation,
    );
  }

  /// Maps a designer-format type string to the wire-format typeId.
  int _typeNameToId(String name) {
    switch (name) {
      case 'button':
        return kWidgetButton;
      case 'rockerSwitch':
      case 'switch':
      case 'slideSwitch':
        return kWidgetSlideSwitch;
      case 'slider':
        return kWidgetSlider;
      case 'knob':
        return kWidgetKnob;
      case 'joystick':
        return kWidgetJoystick;
      case 'led':
        return kWidgetLed;
      case 'text':
        return kWidgetText;
      case 'multiple':
        return kWidgetMultiple;
      default:
        return 0;
    }
  }

  /// Maps a wire-format typeId to a [DesignerElementType] for size conversion,
  /// or `null` for unknown types.
  DesignerElementType? _wireTypeToDesignerType(int typeId) {
    switch (typeId) {
      case kWidgetButton:
        return DesignerElementType.button;
      case kWidgetSlideSwitch:
        return DesignerElementType.slideSwitch;
      case kWidgetSlider:
        return DesignerElementType.slider;
      case kWidgetKnob:
        return DesignerElementType.knob;
      case kWidgetJoystick:
        return DesignerElementType.joystick;
      case kWidgetLed:
        return DesignerElementType.led;
      case kWidgetText:
        return DesignerElementType.text;
      case kWidgetMultiple:
        return DesignerElementType.multiButton;
      default:
        return null;
    }
  }

  Future<void> _requestConfig() async {
    _log('ESTABLISHING HANDSHAKE (Protocol v$kProtocolVersion)...');
    _connectionState = DeviceConnectionState.fetchingConfig;
    notifyListeners();

    for (int attempt = 0; attempt < 3; attempt++) {
      _confCompleter = Completer<void>();

      try {
        final pkt = ProtocolService.buildGetConf();
        final hex = pkt.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');
        _log('APP -> GET_CONF (attempt ${attempt + 1}/3) bytes: $hex');
        await _writePacket(pkt);
      } catch (e) {
        _log('FAILED TO SEND GET_CONF: $e', level: ConsoleLogLevel.error);
        _errorMessage    = 'Failed to send GET_CONF: $e';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      }

      _confTimeoutTimer?.cancel();
      _confTimeoutTimer = Timer(kConfTimeout, () {
        if (_confCompleter != null && !_confCompleter!.isCompleted) {
          _confCompleter!.completeError(
              TimeoutException('CONF_DATA timeout (attempt ${attempt + 1})'));
        }
      });

      try {
        await _confCompleter!.future;
        _confTimeoutTimer?.cancel();
        _confTimeoutTimer = null;
        _confCompleter = null;
        _log('MCU <- CONF_DATA (${_transport.isConnected ? "connected" : "handshake done"})');
        break; // Success
      } on TimeoutException catch (_) {
        _confTimeoutTimer?.cancel();
        _confTimeoutTimer = null;
        _log('TIMEOUT: Device did not respond to GET_CONF.',
            level: ConsoleLogLevel.warning);
        if (_connectionState == DeviceConnectionState.disconnected) return;
        if (attempt < 2) continue;

        _errorMessage = 'Device did not respond to GET_CONF after 3 attempts.';
        _connectionState = DeviceConnectionState.error;
        await _transport.disconnect(); // Hardened cleanup
        notifyListeners();
        return;
      } catch (e) {
        _confTimeoutTimer?.cancel();
        _confTimeoutTimer = null;
        if (_connectionState == DeviceConnectionState.disconnected) return;
        _errorMessage    = 'Error receiving config: $e';
        _connectionState = DeviceConnectionState.error;
        notifyListeners();
        return;
      }
    }
  }

  // ── Polling loop ───────────────────────────────────────────────────────────

  void _startPolling() {
    // Always cancel existing timers before creating new ones.
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    _demoTimer?.cancel();
    _demoTimer = null;

    // Only start demo simulation for known demo configs, not real devices.
    const demoConfigs = {'WIDGETS_DEMO', 'RC_CONTROLLER', 'IOT_DASHBOARD'};
    if (_configName != null && demoConfigs.contains(_configName)) {
      _startDemoSimulation();
    }

    // Helper to send GET_TELEMETRY with a 2-byte LE timestamp for RTT measurement
    void sendTelemetry() {
      final ts = DateTime.now().millisecondsSinceEpoch & 0xFFFF;
      _writePacket(SettingsProtocolService.buildGetTelemetry(ts))
          .catchError((_) {});
    }

    // Request initial telemetry and variables immediately on connection
    if (_transport.isConnected) {
      sendTelemetry();
      _writePacket(ProtocolService.buildGetVars()).catchError((_) {});
    }

    _telemetryTimer = Timer.periodic(kTelemetryInterval, (_) async {
      sendTelemetry();
    });
  }

  void _stopPolling() {
    _telemetryTimer?.cancel(); _telemetryTimer = null;
    _demoTimer?.cancel(); _demoTimer = null;
  }

  // ── Simulation Logic ────────────────────────────────────────────────────────

  Timer? _demoTimer;
  double _simTime = 0;

  void _startDemoSimulation() {
    _demoTimer?.cancel();
    _demoTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (_widgetState == null || _configName == null) return;
      _simTime += 0.05;

      final current = _widgetState!;
      RadioWidgetState next = current;

      if (_configName == 'WIDGETS_DEMO') {
        // ID 9: Alive LED pulses opacity
        final brightness = (128 + 127 * sin(_simTime * 2)).toInt();
        next = next.copyWithOutput(9, [1, 57, 255, 20, brightness]);
        
        // ID 4: Text update based on time
        if ((_simTime * 10).toInt() % 10 == 0) {
           next = next.copyWithOutput(4, 'SYSTEM_UP: ${_simTime.toInt()}s');
        }

        // ID 7: Knob oscillation (Disabled)
        // final knobVal = (127 * math.sin(_simTime * 0.5)).toInt();
        // next = next.copyWithInput(7, [knobVal]);

        // ID 10: Joystick orbiting (Disabled)
        // final jsx = (40 * cos(_simTime)).toInt();
        // final jsy = (40 * sin(_simTime)).toInt();
        // next = next.copyWithInput(10, [jsx, jsy]);

        // ID 11: FLAGS bitmask cycling (Disabled)
        // final mask = (1 << ((_simTime * 0.5).toInt() % 4)) - 1; // 0, 1, 3, 7
        // next = next.copyWithInput(11, [mask & 0x07]);
      } 
      else if (_configName == 'RC_CONTROLLER') {
        // ID 1 & 2: Joysticks slow drift (Disabled)
        // final driftX = (10 * sin(_simTime)).toInt();
        // final driftY = (10 * cos(_simTime * 0.7)).toInt();
        // next = next.copyWithInput(1, [driftX, driftY]);
        // next = next.copyWithInput(2, [-driftY, driftX]);
        
        // ID 5: Dynamic telemetry
        if ((_simTime * 10).toInt() % 20 == 0) {
           final bat = 85 + (5 * sin(_simTime * 0.1)).toInt();
           next = next.copyWithOutput(5, 'BATT: $bat% | PKT: 1.2k');
        }
      }
      else if (_configName == 'IOT_DASHBOARD') {
        // ID 1 & 2: Knobs sensor drift
        final temp = (22 + 4 * sin(_simTime * 0.3)).toInt();
        final hum = (45 + 10 * cos(_simTime * 0.5)).toInt();
        next = next.copyWithInput(1, [temp]);
        next = next.copyWithInput(2, [hum]);
        
        // ID 8: System load text
        if ((_simTime * 10).toInt() % 15 == 0) {
           final load = (10 + 5 * sin(_simTime)).round().toString();
           next = next.copyWithOutput(8, 'LOAD: $load%');
        }
        
        // ID 5: "NET" LED blinks fast
        final netPulse = (sin(_simTime * 10) > 0) ? 1 : 0;
        next = next.copyWithOutput(5, [netPulse, 255, 255, 0, 255]);
      }

      _widgetState = next;
      notifyListeners();
    });
  }

  // ── Packet handling ──────────────────────────────────────────────────────────

  /// Centralized packet transmission with timestamp tracking for heartbeat optimization.
  Future<void> _writePacket(Uint8List pkt) async {
    if (!_transport.isConnected) return;
    try {
      _lastTxAt = DateTime.now();
      await _transport.writePacket(pkt);
    } catch (e) {
      debugPrint('RadioKit: _writePacket error: $e');
      rethrow;
    }
  }

  void _handlePacket(ParsedPacket packet) {
    _lastRxAt = DateTime.now(); // Activity detected
    switch (packet.cmd) {
      case kCmdConfData:  _handleConfData(packet.payload);  break;
      case kCmdVarData:   _handleVarData(packet.payload);   break;
      case kCmdSetInput:  _handleSetInput(packet.payload);  break;
      case kCmdVarUpdate: _handleVarUpdate(packet.payload); break;
      case kCmdMetaData:  _handleMetaData(packet.payload);  break;
      case kCmdMetaUpdate: _handleMetaUpdate(packet.payload); break;
      case kCmdAck:       _handleAck(packet.payload);       break;
      default:
        debugPrint('RadioKit: Unknown cmd 0x${packet.cmd.toRadixString(16)}');
    }
  }

  void _handleChipInfoData(List<int> payload) {
    if (payload.isEmpty) return;
    int offset = 0;

    // 1. Chip model string
    if (offset >= payload.length) return;
    final modelLen = payload[offset++];
    String chipModel = '';
    if (offset + modelLen <= payload.length) {
      chipModel = utf8Decode(payload.sublist(offset, offset + modelLen));
      offset += modelLen;
    }

    // 2. Chip revision
    if (offset >= payload.length) return;
    final chipRevision = payload[offset++];

    // 3. Cores
    if (offset >= payload.length) return;
    final chipCores = payload[offset++];

    // 4. Flash size (4 bytes LE)
    if (offset + 4 > payload.length) return;
    final flashSize = payload[offset] |
        (payload[offset + 1] << 8) |
        (payload[offset + 2] << 16) |
        (payload[offset + 3] << 24);
    offset += 4;

    // 5. PSRAM size (4 bytes LE)
    if (offset + 4 > payload.length) return;
    final psramSize = payload[offset] |
        (payload[offset + 1] << 8) |
        (payload[offset + 2] << 16) |
        (payload[offset + 3] << 24);
    offset += 4;

    // 6. SDK version string
    if (offset >= payload.length) return;
    final sdkLen = payload[offset++];
    String sdkVersion = '';
    if (offset + sdkLen <= payload.length) {
      sdkVersion = utf8Decode(payload.sublist(offset, offset + sdkLen));
      offset += sdkLen;
    }

    // 7. MAC address (6 bytes)
    String chipId = '';
    if (offset + 6 <= payload.length) {
      final parts = <String>[];
      for (int i = 0; i < 6; i++) {
        parts.add(payload[offset + i].toRadixString(16).padLeft(2, '0'));
      }
      chipId = parts.join(':');
    }

    _chipInfo = {
      'chipModel': chipModel,
      'chipRevision': chipRevision,
      'chipCores': chipCores,
      'flashSize': flashSize,
      'psramSize': psramSize,
      'sdkVersion': sdkVersion,
      'chipId': chipId,
    };

    _log('Chip info received: $_chipInfo', level: ConsoleLogLevel.success);
    notifyListeners();

    final completer = _chipInfoCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  // ── Settings protocol (0xDD) handlers ───────────────────────────────────

  /// Incoming Settings packet dispatcher. Settings sub-commands carry
  /// telemetry, BLE info, features, chip info, auth, config, and device info.
  void _handleSettingsPacket(ParsedSettingsPacket packet) {
    _lastRxAt = DateTime.now();
    switch (packet.subCmd) {
      case kSettingsRespTelemetryData:
        _handleSettingsTelemetryData(packet.payload);
        break;
      case kSettingsRespBleInfoData:
        _handleSettingsBleInfoData(packet.payload);
        break;
      case kSettingsRespFeaturesData:
        _handleSettingsFeaturesData(packet.payload);
        break;
      case kSettingsRespChipInfoData:
        _handleChipInfoData(packet.payload.toList());
        break;
      case kSettingsRespPwdAuthAck:
        _handleSettingsPwdAuthAck(packet.payload);
        break;
      case kSettingsRespSetConfAck:
        _handleSettingsSetConfAck(packet.payload);
        break;
      case kSettingsRespFactoryResetAck:
        _log('Factory reset ACK received', level: ConsoleLogLevel.success);
        break;
      case kSettingsRespDeviceInfoData:
        _handleSettingsDeviceInfoData(packet.payload);
        break;
      case kSettingsRespNvsRawReadData:
        _handleSettingsNvsRawReadData(packet.payload);
        break;
      case kSettingsRespNvsRawWriteAck:
        _handleSettingsNvsRawWriteAck(packet.payload);
        break;
      default:
        _log('Unknown settings sub-cmd 0x${packet.subCmd.toRadixString(16)}',
            level: ConsoleLogLevel.info);
    }
  }

  /// Cache for device info from settings protocol.
  String? _deviceInfoProtocolVersion;
  Completer<void>? _deviceInfoCompleter;

  void _handleSettingsTelemetryData(Uint8List payload) {
    final parsed = SettingsProtocolService.parseTelemetryData(payload.toList());
    if (parsed == null) return;
    _rssi = parsed.rssi;
    // Compute true round-trip latency using echoed 2-byte timestamp.
    // payload[0] = RSSI, payload[1] = device-side latency,
    // payload[2..3] = echoed request timestamp (LE).
    if (payload.length >= 4) {
      final echoed = payload[2] | (payload[3] << 8);
      final now = DateTime.now().millisecondsSinceEpoch & 0xFFFF;
      final rtt = (now - echoed) & 0xFFFF;
      _latencyMs = rtt > 30000 ? null : rtt; // sanity: reject > 30s
    } else {
      _latencyMs = parsed.latency; // fallback to device-side latency
    }
    debugPrint('RadioKit: SETTINGS_TELEMETRY_DATA rssi=$_rssi rtt=$_latencyMs');
    notifyListeners();
  }

  void _handleSettingsBleInfoData(Uint8List payload) {
    final parsed = SettingsProtocolService.parseBleInfoData(payload.toList());
    if (parsed == null) return;
    debugPrint('RadioKit: SETTINGS_BLE_INFO_DATA interval=${parsed.connIntervalMs}ms MTU=${parsed.mtu} RSSI=${parsed.rssi}');
    final completer = _bleInfoCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete({
        'connIntervalMs': parsed.connIntervalMs,
        'negotiatedMtu': parsed.mtu,
        'rssi': parsed.rssi,
      });
    }
  }

  void _handleSettingsFeaturesData(Uint8List payload) {
    final bitmask = SettingsProtocolService.parseFeaturesData(payload.toList());
    if (bitmask == null) return;
    _deviceFeatures = bitmask;
    _log('Features bitmask: 0x${_deviceFeatures.toRadixString(16)} '
        '(OTA=${hasOta}, connPwd=${hasPassword}, adminPwd=${hasAdminPassword})',
        level: ConsoleLogLevel.success);
    
    if (hasPassword && !_authenticated && _connectionState == DeviceConnectionState.connected) {
      _startAuthTimeout();
    }
    if (!hasAdminPassword && _connectedDevice != null) {
      SecureStorageService.deleteAdminPassword(_connectedDevice!.id);
    }
    
    notifyListeners();
    final completer = _featuresCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(_deviceFeatures);
    }
  }

  void _handleSettingsPwdAuthAck(Uint8List payload) {
    final status = SettingsProtocolService.parsePwdAuthAck(payload.toList());
    if (status == null) return;
    if (_authCompleter != null && !_authCompleter!.isCompleted) {
      _authCompleter!.complete(status);
    }
  }

  void _handleSettingsNvsRawReadData(Uint8List payload) {
    final parsed = SettingsProtocolService.parseNvsRawReadData(payload.toList());
    if (parsed == null) {
      _log('NVS_RAW_READ_DATA parse failed', level: ConsoleLogLevel.error);
      final completer = _nvsRawReadCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete((status: kSettingsNvsRawError, value: null));
      }
      return;
    }
    _log('NVS raw read: status=${parsed.status} value=${parsed.value}',
        level: ConsoleLogLevel.info);
    final completer = _nvsRawReadCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(parsed);
    }
  }

  void _handleSettingsNvsRawWriteAck(Uint8List payload) {
    final status = SettingsProtocolService.parseNvsRawWriteAck(payload.toList());
    if (status == null) {
      _log('NVS_RAW_WRITE_ACK parse failed', level: ConsoleLogLevel.error);
      final completer = _nvsRawWriteCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.complete(kSettingsNvsRawError);
      }
      return;
    }
    _log('NVS raw write: status=$status', level: ConsoleLogLevel.info);
    final completer = _nvsRawWriteCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(status);
    }
  }

  void _handleSettingsSetConfAck(Uint8List payload) {
    // SET_CONF on Arduino re-broadcasts CONF_DATA via _handleGetConf(),
    // which arrives on the widget protocol and completes _confCompleter.
    // This ack is informational only.
    if (payload.isNotEmpty) {
      _log('SETTINGS_SET_CONF ACK: 0x${payload[0].toRadixString(16)}',
          level: ConsoleLogLevel.info);
    }
  }

  void _handleSettingsDeviceInfoData(Uint8List payload) {
    final parsed = SettingsProtocolService.parseDeviceInfoData(payload.toList());
    if (parsed == null) {
      _log('DEVICE_INFO_DATA parse failed', level: ConsoleLogLevel.error);
      return;
    }
    _log('Device info: v${parsed.version} "${parsed.name}" "${parsed.description}"',
        level: ConsoleLogLevel.success);
    _deviceInfoProtocolVersion = parsed.version.toString();
    _configName = parsed.name.isNotEmpty ? parsed.name : _configName;
    _description = parsed.description.isNotEmpty ? parsed.description : _description;
    notifyListeners();
    final completer = _deviceInfoCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// Request device info (name, description, protocol version) via settings protocol.
  Future<void> _requestDeviceInfo() async {
    if (!_transport.isConnected) return;
    final completer = Completer<void>();
    _deviceInfoCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildGetDeviceInfo());
    } catch (_) {
      _deviceInfoCompleter = null;
      return;
    }
    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException catch (_) {
      // Device may be running older firmware without settings protocol
    } catch (_) {}
    _deviceInfoCompleter = null;
  }

  /// Request features from the device via settings protocol. Fire-and-forget.
  Future<void> _requestFeatures() async {
    if (!_transport.isConnected) return;
    final completer = Completer<int>();
    _featuresCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildGetFeatures());
    } catch (_) {
      return;
    }
    try {
      await completer.future.timeout(const Duration(seconds: 2));
    } on TimeoutException catch (_) {
    } catch (_) {
    } finally {
      _featuresCompleter = null;
    }
  }

  /// Request chip info from the device via settings protocol. Fire-and-forget.
  Future<void> _requestChipInfo() async {
    if (!_transport.isConnected) return;
    final completer = Completer<void>();
    _chipInfoCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildGetChipInfo());
    } catch (_) {
      _chipInfoCompleter = null;
      return;
    }
    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException catch (_) {
    } catch (_) {
    } finally {
      _chipInfoCompleter = null;
    }
  }

  /// Public: request chip info on demand (e.g. when bottom sheet opens).
  /// Returns immediately if already cached, else fetches fresh.
  Future<void> requestChipInfo() async {
    if (_chipInfo != null) return;
    await _requestChipInfo();
  }

  /// Send a GET_BLE_INFO command via settings protocol and wait for the response.
  /// Returns a map with connIntervalMs, negotiatedMtu, rssi, or null on timeout.
  Future<Map<String, int>?> sendGetBleInfo() async {
    if (!_transport.isConnected) return null;
    final completer = Completer<Map<String, int>>();
    _bleInfoCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildBleInfo());
    } catch (e) {
      _bleInfoCompleter = null;
      return null;
    }
    try {
      final result = await completer.future.timeout(const Duration(seconds: 3));
      _bleInfoCompleter = null;
      return result;
    } on TimeoutException catch (_) {
      _bleInfoCompleter = null;
      return null;
    } catch (_) {
      _bleInfoCompleter = null;
      return null;
    }
  }



  void _handleConfData(List<int> payload) {
    _log('MCU <- CONF_DATA (${payload.length} bytes)');
    final conf = ProtocolService.parseConfData(payload);
    if (conf == null) {
      _log('PARSE FAILED: Invalid CONF_DATA payload.', level: ConsoleLogLevel.error);
      debugPrint('RadioKit: CONF_DATA parse failed — raw: '
          '${payload.take(32).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');
      return;
    }
    _log('RECEIVED CONFIG: ${_connectedDevice?.name ?? conf.name} with ${conf.widgets.length} widgets', level: ConsoleLogLevel.success);
    // Name/desc may come from device info (v4) or embedded in CONF_DATA (v3 fallback)
    final fallbackName = _connectedDevice?.name ?? 'RadioKit Device';
    _configName      = conf.name.isNotEmpty ? conf.name : _configName ?? fallbackName;
    _description     = conf.description.isNotEmpty ? conf.description : _description;
    _widgets         = conf.widgets;
    _orientation     = conf.orientation;
    _widgetState     = RadioWidgetState.initial(conf.widgets);
    _connectionState = DeviceConnectionState.connected;

    // Convert to designer-format JSON and cache for fast UI rendering.
    _deviceConfigJson = widgetConfigsToDesignerJson(
      widgets: conf.widgets,
      name: _configName ?? fallbackName,
      description: _description ?? '',
      orientation: conf.orientation,
      theme: conf.theme,
    );

    // Apply the skin provided by the device
    _skinProvider?.setSkin(conf.theme);

    _startPolling();
    
    // Request initial variable states immediately after config is processed
    if (_transport.isConnected) {
      _writePacket(ProtocolService.buildGetVars()).catchError((_) {});
    }

    notifyListeners();
    final completer = _confCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  void _handleVarData(List<int> payload) {
    final current = _widgetState;
    if (current == null) return;
    final next = ProtocolService.parseVarData(payload, _widgets, current);
    if (next != null) { _widgetState = next; notifyListeners(); }
  }

  void _handleSetInput(List<int> payload) {
    final result = ProtocolService.parseVarUpdate(payload);
    if (result == null) return;
    final (widgetId, seq, values) = result;

    final current = _widgetState;
    if (current == null) return;

    final widget = _widgets.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => WidgetConfig(
          typeId: 0, widgetId: widgetId, x: 0, y: 0, width: 0, height: 0),
    );

    RadioWidgetState next = current;
    // 0x05 SET_INPUT forces a jump for an Input widget
    if (!widget.hasOutput) {
      // Sign-extend int8_t values for Slider and Knob
      final cooked = (widget.typeId == kWidgetSlider ||
                      widget.typeId == kWidgetKnob)
          ? values.map(_signedByte).toList()
          : values;
      next = current.copyWithInput(widgetId, cooked);
      _log('MCU <- SET_INPUT (wid:$widgetId, seq:$seq, override:$cooked)');
    }

    _widgetState = next;
    notifyListeners();

    _writePacket(ProtocolService.buildAck(seq)).catchError((_){});
  }

  void _handleVarUpdate(List<int> payload) {
    final result = ProtocolService.parseVarUpdate(payload);
    if (result == null) return;
    final (widgetId, seq, values) = result;

    final current = _widgetState;
    if (current == null) return;

    final widget = _widgets.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => WidgetConfig(
          typeId: 0, widgetId: widgetId, x: 0, y: 0, width: 0, height: 0),
    );

    // 0x09 VAR_UPDATE handles Outputs. Inputs sent over 0x09 are echoes/bounces
    // and must be strictly ignored to prevent UI overwrite jitter.
    RadioWidgetState next = current;
    if (widget.hasOutput) {
      if (widget.typeId == kWidgetLed && values.length >= 5) {
        // v3: [STATE, R, G, B, OPACITY]
        next = current.copyWithOutput(widgetId, List<int>.from(values.take(5)));
      } else if (widget.typeId == kWidgetText) {
        // [LEN(1)] [CHARS...]
        if (values.isNotEmpty) {
          final len = values[0];
          final textLen = values.length - 1;
          // Use the minimum of declared length and actual bytes received
          final end = (1 + min(len, textLen)).clamp(0, values.length).toInt();
          
          final text = utf8Decode(values.sublist(1, end));
          debugPrint('RadioKit: VAR_UPDATE Text wid=$widgetId len=$len actual=$textLen text="$text"');
          next = current.copyWithOutput(widgetId, text);
        } else {
          debugPrint('RadioKit: VAR_UPDATE Text wid=$widgetId received with NO payload');
          next = current.copyWithOutput(widgetId, '');
        }
      } else {
        next = current.copyWithOutput(
            widgetId, values.isNotEmpty ? values[0] : 0);
      }
    } else {
      // It's an input bounce. Discard it.
      _log('MCU <- VAR_UPDATE (IGNORED BOUNCE for Input wid:$widgetId)');
    }

    _widgetState = next;
    notifyListeners();

    if (widget.hasOutput) {
        _log('MCU <- VAR_UPDATE (wid:$widgetId, seq:$seq)');
    }

    _writePacket(ProtocolService.buildAck(seq)).catchError((_) {});
  }

  void _handleMetaData(List<int> payload) {
    final updated = ProtocolService.parseMetaData(payload, _widgets);
    if (updated != null) {
      _widgets = updated;
      _log('MCU <- META_DATA (${_widgets.length} widgets updated)');
      notifyListeners();
    }
  }

  void _handleMetaUpdate(List<int> payload) {
    final result = ProtocolService.parseMetaUpdate(payload, _widgets);
    if (result == null) return;
    final (widgetId, seq, updatedWidget) = result;

    final idx = _widgets.indexWhere((w) => w.widgetId == widgetId);
    if (idx != -1) {
      _widgets[idx] = updatedWidget;
      _log('MCU <- META_UPDATE (wid:$widgetId, label:"${updatedWidget.label}")');
      notifyListeners();
    }

    _writePacket(ProtocolService.buildAck(seq)).catchError((_) {});
  }

  void _handleAck(List<int> payload) {
    if (payload.isEmpty) return;
    final seq     = payload[0];
    final pending = _pendingUpdates.remove(seq);
    pending?.timer?.cancel();
  }

  // ── Bulk FS protocol (0xAA) ──────────────────────────────────────────

  /// Incoming FS frame dispatcher. Completes a pending FS request if the
  /// sub-cmd matches one, or logs it as unsolicited.
  /// Supports pipelined requests via FIFO queue per sub-cmd.
  void _handleFsPacket(ParsedFsPacket packet) {
    _lastRxAt = DateTime.now(); // FS traffic also counts as activity
    
    // Try exact match first, then match with ACK-mask (responses set bit 7)
    Completer<ParsedFsPacket>? pending;
    final queue = _pendingFs[packet.subCmd];
    if (queue != null && queue.isNotEmpty) {
      pending = queue.removeAt(0);
      if (queue.isEmpty) _pendingFs.remove(packet.subCmd);
    }
    if (pending == null) {
      final altCmd = packet.subCmd & 0x7F;
      final altQueue = _pendingFs[altCmd];
      if (altQueue != null && altQueue.isNotEmpty) {
        pending = altQueue.removeAt(0);
        if (altQueue.isEmpty) _pendingFs.remove(altCmd);
      }
    }
    if (pending != null && !pending.isCompleted) {
      pending.complete(packet);
    } else {
      _log('MCU <- UNSOL FS 0x${packet.subCmd.toRadixString(16).padLeft(2, "0")} '
          '(${packet.payload.length} bytes)');
    }
  }

  /// Send an FS request and await the matching response.
  /// Returns null on timeout or disconnect.
  Future<ParsedFsPacket?> _sendFsRequest(
    Uint8List frame, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (!_transport.isConnected) return null;
    final subCmd = frame[1];

    final completer = Completer<ParsedFsPacket>();
    _pendingFs.putIfAbsent(subCmd, () => []).add(completer);

    try {
      await _writePacket(frame);
    } catch (e) {
      _pendingFs[subCmd]?.remove(completer);
      return null;
    }

    // Manual timeout — using completer.future.timeout would force
    // us to return a non-null value from onTimeout which collides
    // with our "no response" semantics.
    final timedOut = await completer.future
        .then<ParsedFsPacket?>((p) => p)
        .timeout(timeout, onTimeout: () => null)
        .catchError((_) => null as ParsedFsPacket?);
    if (timedOut == null) {
      _pendingFs[subCmd]?.remove(completer);
      if (_pendingFs[subCmd]?.isEmpty == true) _pendingFs.remove(subCmd);
    }
    return timedOut;
  }

  void _cancelAllPendingFs() {
    for (final list in _pendingFs.values) {
      for (final c in list) {
        if (!c.isCompleted) c.completeError(Exception('Disconnected'));
      }
    }
    _pendingFs.clear();
  }

  /// Public entry point for sending an FS request frame and awaiting
  /// the matching response. Returns null on timeout or disconnect.
  Future<ParsedFsPacket?> sendFs(
    Uint8List frame, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return _sendFsRequest(frame, timeout: timeout);
  }



  // ── OTA protocol (0xBB) ─────────────────────────────────────────────

  /// Pending OTA operation result.
  Completer<int>? _otaOperationCompleter;
  bool _otaCancelled = false;

  /// Handle an incoming OTA frame from the device.
  void _handleOtaPacket(ParsedOtaPacket packet) {
    _lastRxAt = DateTime.now();
    final completer = _otaOperationCompleter;
    if (packet.subCmd == kOtaRespAck) {
      final err = OtaProtocolService.parseAck(packet.payload) ?? kOtaErrInvalidState;
      if (completer != null && !completer.isCompleted) {
        completer.complete(err);
      }
    } else if (packet.subCmd == kOtaRespProgress) {
      // Progress is handled by the uploadFirmware method via _otaProgressCallback
      if (_otaProgressCallback != null) {
        final progress = OtaProtocolService.parseProgress(packet.payload);
        if (progress != null) {
          _otaProgressCallback!(progress.$1, progress.$2);
        }
      }
    }
  }

  /// Callback for OTA progress reports. Set by [uploadFirmware].
  void Function(int received, int total)? _otaProgressCallback;

  /// Upload firmware to the device via OTA. Returns true on success.
  /// [firmware] contains the raw firmware binary bytes.
  /// [eraseAll] if true, sets a deferred erase flag (NVS + FS) in the device.
  /// [onProgress] is called with (bytesSent, totalBytes) during upload.
  /// Throws on error.
  Future<bool> uploadFirmware(
    List<int> firmware, {
    bool eraseAll = false,
    required void Function(int received, int total) onProgress,
  }) async {
    if (!_transport.isConnected) {
      throw Exception('Not connected');
    }

    _otaCancelled = false;

    const int chunkSize = kOtaMaxPayload - 4; // 4 bytes for offset

    // 1. Compute CRC32 of the full firmware
    int crc32 = _computeCrc32(firmware);

    // 2. Set erase flag before OTA if requested
    if (eraseAll) {
      final flagCompleter = Completer<int>();
      _otaOperationCompleter = flagCompleter;
      try {
        await _writePacket(OtaProtocolService.buildSetEraseFlag(1)); // 1 = both NVS + FS
      } catch (e) {
        _otaOperationCompleter = null;
        throw Exception('Failed to send SET_ERASE_FLAG: $e');
      }
      int flagResult;
      try {
        flagResult = await flagCompleter.future.timeout(
          const Duration(seconds: 5));
      } on TimeoutException catch (_) {
        _otaOperationCompleter = null;
        throw Exception('SET_ERASE_FLAG timed out');
      }
      if (flagResult != kOtaErrOk) {
        _otaOperationCompleter = null;
        throw Exception('SET_ERASE_FLAG failed: ${otaErrorName(flagResult)}');
      }
    }

    // 3. Send OTA_BEGIN
    final beginCompleter = Completer<int>();
    _otaOperationCompleter = beginCompleter;
    _otaProgressCallback = onProgress;

    try {
      await _writePacket(OtaProtocolService.buildBegin(firmware.length));
    } catch (e) {
      _otaOperationCompleter = null;
      _otaProgressCallback = null;
      throw Exception('Failed to send OTA_BEGIN: $e');
    }

    int beginResult;
    try {
      beginResult = await beginCompleter.future.timeout(
        const Duration(seconds: 10));
    } on TimeoutException catch (_) {
      _otaOperationCompleter = null;
      _otaProgressCallback = null;
      throw Exception('OTA_BEGIN timed out');
    } catch (e) {
      _otaOperationCompleter = null;
      _otaProgressCallback = null;
      rethrow;
    }

    if (beginResult != kOtaErrOk) {
      _otaOperationCompleter = null;
      _otaProgressCallback = null;
      throw Exception('OTA_BEGIN failed: ${otaErrorName(beginResult)}');
    }

    // 3. Send OTA_CHUNK in sequence, waiting for each ACK
    final stopwatch = Stopwatch()..start();
    for (int offset = 0; offset < firmware.length; offset += chunkSize) {
      if (_otaCancelled) {
        _otaCancelled = false;
        throw Exception('OTA cancelled by user');
      }
      final end = (offset + chunkSize).clamp(0, firmware.length);
      final chunk = firmware.sublist(offset, end);

      final chunkCompleter = Completer<int>();
      _otaOperationCompleter = chunkCompleter;

      int retries = 0;
      int chunkResult = kOtaErrFlash;
      while (retries < 3) {
        try {
          await _writePacket(OtaProtocolService.buildChunk(offset, chunk));
        } catch (e) {
          if (retries < 2) {
            retries++;
            await Future.delayed(Duration(milliseconds: 100 * retries));
            continue;
          }            await abortOta();
          _otaProgressCallback = null;
          throw Exception('Failed to send OTA_CHUNK at offset $offset: $e');
        }

        try {
          chunkResult = await chunkCompleter.future.timeout(
            const Duration(seconds: 10));
          if (chunkResult != kOtaErrSeq) break;
          // Sequence error — retry
          retries++;
        } on TimeoutException catch (_) {
          retries++;
          if (retries >= 3) {
            await abortOta();
            _otaProgressCallback = null;
            throw Exception('OTA_CHUNK timeout at offset $offset after 3 retries');
          }
        }
      }

      if (chunkResult != kOtaErrOk) {
        await abortOta();
        _otaProgressCallback = null;
        throw Exception('OTA_CHUNK failed at offset $offset: ${otaErrorName(chunkResult)}');
      }

      // Report progress with speed
      final elapsed = stopwatch.elapsedMilliseconds;
      onProgress(offset + chunk.length, firmware.length);
    }

    // 4. Send OTA_END
    final endCompleter = Completer<int>();
    _otaOperationCompleter = endCompleter;
    try {
      await _writePacket(OtaProtocolService.buildEnd(crc32));
    } catch (e) {
      _otaOperationCompleter = null;
      _otaProgressCallback = null;
      throw Exception('Failed to send OTA_END: $e');
    }

    int endResult;
    try {
      endResult = await endCompleter.future.timeout(
        const Duration(seconds: 15));
    } on TimeoutException catch (_) {
      _otaOperationCompleter = null;
      _otaProgressCallback = null;
      throw Exception('OTA_END timed out — device may be rebooting');
    } catch (e) {
      _otaOperationCompleter = null;
      _otaProgressCallback = null;
      rethrow;
    }

    _otaOperationCompleter = null;
    _otaProgressCallback = null;

    if (endResult != kOtaErrOk) {
      throw Exception('OTA_END failed: ${otaErrorName(endResult)}');
    }

    // Post-OTA auto-reconnect (fire-and-forget, so dialog can update)
    _log('OTA complete — device rebooting, reconnecting...',
        level: ConsoleLogLevel.success);
    _connectionState = DeviceConnectionState.otaRebooting;
    notifyListeners();
    unawaited(_reconnectAfterOta());
    return true;
  }

  /// After OTA reboot, scan for the device and auto-reconnect.
  Future<void> _reconnectAfterOta() async {
    try {
      // Brief delay to let the transport process the disconnect
      await Future.delayed(const Duration(seconds: 1));

      final originalId = _connectedDevice?.id;
      _log('OTA: scanning for device to reconnect...',
          level: ConsoleLogLevel.info);

      final deadline = DateTime.now().add(const Duration(seconds: 30));
      bool reconnected = false;

      while (DateTime.now().isBefore(deadline)) {
        if (_connectionState != DeviceConnectionState.otaRebooting) return;
        if (_transport.isConnected) {
          reconnected = true;
          break;
        }

        // Try connecting by original ID
        if (originalId != null) {
          try {
            await _transport.connect(originalId);
            await Future.delayed(const Duration(milliseconds: 500));
            if (_transport.isConnected) {
              reconnected = true;
              break;
            }
          } catch (_) {
            // Connection failed, retry
          }
        }

        await Future.delayed(const Duration(seconds: 1));
      }

      if (reconnected) {
        _log('OTA: device reconnected successfully',
            level: ConsoleLogLevel.success);
        // Re-request config to verify we're talking to the same device
        _connectionState = DeviceConnectionState.fetchingConfig;
        notifyListeners();
        await _requestConfig();
        unawaited(_requestFeatures());
      } else if (_connectionState == DeviceConnectionState.otaRebooting) {
        _log('OTA: reconnect timeout — device not found after 30s',
            level: ConsoleLogLevel.warning);
        _connectionState = DeviceConnectionState.disconnected;
        _errorMessage = 'OTA reboot timeout — device not found';
        notifyListeners();
      }
    } catch (e) {
      _log('OTA reconnect error: $e', level: ConsoleLogLevel.error);
      if (_connectionState == DeviceConnectionState.otaRebooting) {
        _connectionState = DeviceConnectionState.disconnected;
        _errorMessage = 'OTA reconnect failed: $e';
        notifyListeners();
      }
    }
  }

  /// Send OTA_ABORT to cancel an in-progress upload.
  /// Public so the UI can call it from the cancel button.
  Future<void> abortOta() async {
    _otaCancelled = true;
    try {
      await _writePacket(OtaProtocolService.buildAbort());
    } catch (_) {
      // Best-effort
    }
    _otaOperationCompleter = null;
  }

  // ── CRC-32 (IEEE 802.3) ────────────────────────────────────────────────

  /// Compute CRC-32 of [data]. Polynomial 0xEDB88320.
  static int _computeCrc32(List<int> data) {
    const poly = 0xEDB88320;
    int crc = 0xFFFFFFFF;
    for (final byte in data) {
      crc ^= byte & 0xFF;
      for (int i = 0; i < 8; i++) {
        if ((crc & 1) != 0) {
          crc = (crc >> 1) ^ poly;
        } else {
          crc >>= 1;
        }
      }
    }
    return crc ^ 0xFFFFFFFF;
  }

  void _handleConnectionLost(String reason) {
    if (_connectionState == DeviceConnectionState.otaRebooting) {
      // Reconnect is in progress — don't clear state
      return;
    }
    _cancelAllPendingUpdates();
    _cancelAllPendingFs();
    _stopPolling();
    _cancelAuthTimeout();
    _connectionState = DeviceConnectionState.disconnected;
    _authenticated   = false;
    _authenticatedAdmin = false;
    _authCompleter   = null;
    _connectedAt     = null;
    _authenticatedAt = null;
    _errorMessage    = reason;
    notifyListeners();
  }

  // ── VAR_UPDATE with retry (app → device) ──────────────────────────────────────

  Future<void> _sendVarUpdate(int widgetId, List<int> values) async {
    final seq = _nextSeq++ & 0xFF;
    final pkt = ProtocolService.buildVarUpdate(widgetId, seq, values);

    final entry = _PendingUpdate(
        widgetId: widgetId, seq: seq, values: values);
    _pendingUpdates[seq] = entry;

    Future<void> trySend() async {
      if (!_transport.isConnected) {
        _pendingUpdates.remove(seq);
        return;
      }
      try { await _writePacket(pkt); } catch (_) {}

      if (!_pendingUpdates.containsKey(seq)) return;

      if (entry.retries >= kVarUpdateMaxRetries) {
        _pendingUpdates.remove(seq);
        try { await _writePacket(ProtocolService.buildGetVars()); } catch (_) {}
        return;
      }

      entry.retries++;
      entry.timer = Timer(
        const Duration(milliseconds: kVarUpdateTimeoutMs),
        trySend,
      );
    }

    await trySend();
  }

  void _cancelAllPendingUpdates() {
    for (final e in _pendingUpdates.values) {
      e.timer?.cancel();
    }
    _pendingUpdates.clear();
  }

  // ── Widget interaction ──────────────────────────────────────────────────────────

  Future<void> setInputValue(int widgetId, List<int> values) async {
    final current = _widgetState;
    if (current == null) return;

    // Human-readable interaction log
    final widget = _widgets.where((w) => w.widgetId == widgetId).firstOrNull;
    if (widget != null) {
      final label = widget.label.isNotEmpty ? '"${widget.label}"' : '#$widgetId';
      final desc = _describeInteraction(widget, values);
      _log('⚡ ${widget.typeName} $label $desc');
    }

    final next = current.copyWithInput(widgetId, values);
    _widgetState = next;
    notifyListeners();
    if (!_transport.isConnected) return;
    await _sendVarUpdate(widgetId, values);
  }

  String _describeInteraction(WidgetConfig w, List<int> values) {
    final v = values.isNotEmpty ? values[0] : 0;
    switch (w.typeId) {
      case kWidgetButton:
        if (w.variant == 1) {
          return v != 0 ? '→ ON' : '→ OFF';
        }
        return v != 0 ? '→ PRESSED' : '→ RELEASED';
      case kWidgetSwitch:
        final onLabel = w.onText.isNotEmpty ? w.onText : 'ON';
        final offLabel = w.offText.isNotEmpty ? w.offText : 'OFF';
        return v != 0 ? '→ $onLabel' : '→ $offLabel';
      case kWidgetSlideSwitch:
        final items = w.multipleItems;
        if (v < items.length) {
          return '→ "${items[v].label}" (idx:$v)';
        }
        return '→ index $v';
      case kWidgetMultiple:
        final items = w.multipleItems;
        if (w.variant == 1) {
          final parts = <String>[];
          for (int i = 0; i < items.length; i++) {
            if ((v >> i) & 1 == 1) parts.add(items[i].label);
          }
          return '→ [${parts.join(", ")}] (mask:$v)';
        } else {
          if (v < items.length) {
            return '→ "${items[v].label}" (idx:$v)';
          }
          return '→ index $v';
        }
      case kWidgetKnob:
        if (variantIsAlternateShape(w.variant)) {
          return '→ Steering ${v.toString().padLeft(4)}%';
        }
        return '→ $v%';
      case kWidgetSlider:
        if (variantIsAlternateShape(w.variant)) {
          return '→ Gas Pedal ${v.toString().padLeft(4)}%';
        }
        return '→ $v%';
      case kWidgetJoystick:
        final vx = values.isNotEmpty ? values[0] : 0;
        final vy = values.length > 1 ? values[1] : 0;
        return '→ X:$vx Y:$vy';
      default:
        return '→ $values';
    }
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _connectionState = DeviceConnectionState.disconnected;
    notifyListeners();

    _cancelAllPendingUpdates();
    _cancelAllPendingFs();
    _stopPolling();
    _confTimeoutTimer?.cancel();
    _confTimeoutTimer = null;
    if (_confCompleter != null && !_confCompleter!.isCompleted) {
      _confCompleter!.completeError(TimeoutException('Disconnected by user'));
    }
    await _transport.disconnect();
    _connectedDevice  = null;
    _configName       = null;
    _widgets          = [];
    _widgetState      = null;
    _description      = null;
    _deviceConfigJson = null;
    _fsTreeCache      = null;
    _deviceFeatures   = 0;
    _chipInfo         = null;
    _authCompleter    = null;
    _authenticated    = false;
    _authenticatedAdmin = false;
    _cancelAuthTimeout();
    _connectedAt      = null;
    _authenticatedAt  = null;
    _otaCancelled     = false;
    _errorMessage     = null;
    // Note: saved password is NOT cleared on disconnect so it persists
    // for reconnection. Clear only on factory reset or explicit unpair.
    notifyListeners();
  }

  // ── Cleanup ──────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _cancelAllPendingUpdates();
    _cancelAllPendingFs();
    _stopPolling();
    _confTimeoutTimer?.cancel();
    super.dispose();
  }
}

String utf8Decode(List<int> bytes) {
  try { return const Utf8Decoder(allowMalformed: true).convert(bytes); }
  catch (_) { return ''; }
}

/// Interpret a raw unsigned wire byte as a signed int8 (-128..127).
/// Used for Slider and Knob which use two's complement on the wire.
int _signedByte(int b) => b > 127 ? b - 256 : b;
