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
import '../services/ble_service.dart';
import '../services/websocket_service.dart';

import '../providers/console_provider.dart';
import '../providers/theme_preset_provider.dart';
import '../providers/debug_provider.dart';
import '../providers/history_provider.dart';
import '../providers/designs_provider.dart';

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

/// Authentication level granted by the device.
/// Based on the password used: device password (full access)
/// or user password (widgets-only).
enum AuthLevel { none, user, device }

/// Page switch state machine states.
enum _PageSwitchState { idle, pagePending }

/// Manages the connected device, widget configuration, and variable
/// polling/update loop. Transport-agnostic.
class DeviceProvider extends ChangeNotifier {
  TransportService _transport;
  final ConsoleProvider? _console;
  final ThemePresetProvider? _themePresetProvider;

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
  final DebugLogSink?            _debugSink;
  /// True once a CONF_DATA has been parsed during the current connection.
  /// The firmware may push CONF_DATA on BLE subscribe before _requestConfig()
  /// sets up its wait, so the handshake must short-circuit when the config
  /// already arrived.
  bool _configReceived = false;
  Completer<void>? _confCompleter;
  Completer<int>? _setConfCompleter;
  Completer<Map<String, int>>? _bleInfoCompleter;
  int _deviceFeatures = 0;
  Completer<int>? _featuresCompleter;
  Map<String, dynamic>? _chipInfo;
  Completer<void>? _chipInfoCompleter;
  Completer<({int status, int? value, List<int>? rawBytes})>? _nvsRawReadCompleter;
  Completer<int>? _nvsRawWriteCompleter;
  Completer<int>? _authCompleter;  // For CMD_PWD_AUTH response
  Timer? _authTimeoutTimer;

  // ── Page state ───────────────────────────────────────────────
  int _activePage = 0;
  int _numPages = 1;
  List<String> _pageNames = [];
  List<int> _pageOrientations = []; // per-page effective orientations (kOrientationLandscape/kOrientationPortrait)
  _PageSwitchState _pageSwitchState = _PageSwitchState.idle;
  static const Duration _authTimeout = Duration(seconds: 30);
  DateTime? _connectedAt;
  DateTime? get authTimeoutAt =>
      _connectedAt != null ? _connectedAt!.add(_authTimeout) : null;
  Duration get remainingAuthTime {
    if (_authLevel != AuthLevel.none || _connectedAt == null) return Duration.zero;
    final remaining = _authTimeout - DateTime.now().difference(_connectedAt!);
    return remaining.isNegative ? Duration.zero : remaining;
  }

  // ── Telemetry values ─────────────────────────────────────────
  // Live values for telemetry widgets, keyed by widget index (0-based).
  final Map<int, String> _telemetryValues = <int, String>{};

  final Map<int, _PendingUpdate> _pendingUpdates = {};
  int _nextSeq = 0;

  // Debounced notify: coalesce multiple notifyListeners() per event-loop tick
  bool _notifyDirty = false;
  void _scheduleNotifyListeners() {
    if (_notifyDirty) return;  // Already scheduled
    _notifyDirty = true;
    scheduleMicrotask(() {
      _notifyDirty = false;
      notifyListeners();
    });
  }

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
    if (_fsTreeCache != null && _fsTreeCache!.containsKey('/')) return;
    // Brief delay: if the user tapped OPEN_CONTROLLER, let that render
    // before we consume BLE bandwidth with FS operations.
    await Future.delayed(const Duration(milliseconds: 500));
    if (_connectedDevice == null || !_connectedDevice!.hasFs) return;
    if (!_transport.isConnected) return;
    if (_fsTreeCache != null && _fsTreeCache!.containsKey('/')) return;
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
    ThemePresetProvider? themePresetProvider,
    HistoryProvider? historyProvider,
    DesignsProvider? designsProvider,
  })  : _debugSink = debugSink,
        _console = console,
        _themePresetProvider = themePresetProvider,
        _designsProvider = designsProvider,
        _transport = transport {
    this.historyProvider = historyProvider;
    setTransport(transport);
  }

  final DesignsProvider? _designsProvider;

  void _log(String message, {ConsoleLogLevel level = ConsoleLogLevel.info}) {
    _console?.log(message, level: level);
  }

  // ── Getters ──────────────────────────────────────────────────────────────

  DeviceInfo?           get connectedDevice  => _connectedDevice;
  DeviceConnectionState get connectionState  => _connectionState;
  String?               get configName       => _configName;
  String?               get description      => _description;
  String?               get deviceIcon       => _connectedDevice?.deviceIcon;
  List<WidgetConfig>    get widgets          => List.unmodifiable(_widgets);
  int                   get orientation      => _orientation;
  RadioWidgetState?     get widgetState      => _widgetState;
  String?               get errorMessage     => _errorMessage;
  bool                  get isConnected      =>
      _connectionState == DeviceConnectionState.connected;
  TransportService      get currentTransport => _transport;
  ConsoleProvider?      get consoleProvider => _console;
  int?                  get rssi             => _rssi;
  int?                  get latencyMs        => _latencyMs;

  /// Whether the connected device supports OTA firmware updates.
  bool get hasOta => (_deviceFeatures & kFeatureOta) != 0;

  /// Whether an OTA firmware update is currently in progress.
  bool get isOtaInProgress => _otaProgressCallback != null;

  /// Cached chip info from the device, or null if not yet fetched.
  Map<String, dynamic>? get chipInfo => _chipInfo;

  /// Whether the device has a device password set (detected via features bitmask).
  bool get hasDevicePassword => (_deviceFeatures & kFeatureHasDevicePassword) != 0;

  /// Whether the device has a user password set.
  bool get hasUserPassword => (_deviceFeatures & kFeatureHasUserPassword) != 0;

  /// Legacy alias — whether any password is set.
  bool get hasPassword => hasDevicePassword || hasUserPassword;

  /// Legacy aliases for backward compat during migration.
  bool get hasAdminPassword => hasUserPassword;

  /// Whether the device supports BLE transport.
  bool get hasBle => (_deviceFeatures & kFeatureBle) != 0;

  /// Whether the device supports WiFi transport.
  bool get hasWifi => (_deviceFeatures & kFeatureWiFi) != 0;

  /// Whether the device supports cloud relay.
  bool get hasCloud => (_deviceFeatures & kFeatureCloud) != 0;

  /// Whether the device has a LittleFS filesystem (detected via features bitmask).
  bool get hasFs => (_deviceFeatures & kFeatureFilesystem) != 0;

  String _fsUrl = '';
  String _otaUrl = '';
  String? _board;
  String? _firmwareVersion;

  /// Configured filesystem repo / subfolder link from the device.
  String get fsUrl => _fsUrl;

  /// Configured OTA firmware link placeholder from the device.
  String get otaUrl => _otaUrl;

  /// Hardware board identifier reported by the device (e.g. "TRACKLINK_V3").
  String? get board => _board;

  /// Firmware version reported by the device (e.g. "1.0.0").
  String? get firmwareVersion => _firmwareVersion;

  /// Current active page index (0-based).
  int get activePage => _activePage;

  /// Total number of pages.
  int get numPages => _numPages;

  /// Page names from the device.
  List<String> get pageNames => List.unmodifiable(_pageNames);

  /// Per-page effective orientations from the device.
  List<int> get pageOrientations => List.unmodifiable(_pageOrientations);

  /// Live telemetry values keyed by widget index (0-based).
  Map<int, String> get telemetryValues => Map.unmodifiable(_telemetryValues);

  /// Whether the device supports the 0xEE print stream.
  bool get hasPrintStream => (_deviceFeatures & kSettingsFeaturePrintStream) != 0;

  /// Current auth level.
  AuthLevel get authLevel => _authLevel;

  /// Legacy: whether any level of authentication is active.
  bool get isAuthenticated => _authLevel != AuthLevel.none;

  /// Whether device-level (full) access is active.
  bool get isDeviceMode => _authLevel == AuthLevel.device;

  /// Whether user-level (widgets-only) access is active.
  bool get isUserMode => _authLevel == AuthLevel.user;

  /// Legacy alias.
  bool get isAdminMode => isDeviceMode;

  /// Start the 30s auth timeout — auto-disconnect if not authenticated.
  void _startAuthTimeout() {
    _authTimeoutTimer?.cancel();
    _connectedAt = DateTime.now();
    _authTimeoutTimer = Timer(_authTimeout, () {
      if (_authLevel == AuthLevel.none && _transport.isConnected) {
        _log('Auth timeout — disconnecting (not authenticated within 30s)',
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

  AuthLevel _authLevel = AuthLevel.none;

  /// Read a raw NVS uint8/string key from the device via settings protocol.
  /// Returns (status, value, rawString) where status=0 (ok) or 1 (error).
  /// - For uint8 keys: value is set, rawString is null
  /// - For string keys: value is null, rawString is set
  Future<({int status, int? value, String? rawString})> readNvsRawKey(String key) async {
    if (!_transport.isConnected) {
      return (status: kSettingsNvsRawError, value: null, rawString: null);
    }
    final completer = Completer<({int status, int? value, List<int>? rawBytes})>();
    _nvsRawReadCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildNvsRawRead(key));
    } catch (e) {
      _nvsRawReadCompleter = null;
      _log('readNvsRawKey failed: $e', level: ConsoleLogLevel.error);
      return (status: kSettingsNvsRawError, value: null, rawString: null);
    }
    try {
      final result = await completer.future.timeout(const Duration(seconds: 5));
      final rawString = result.rawBytes != null
          ? utf8Decode(result.rawBytes!)
          : null;
      return (
        status: result.status,
        value: result.value,
        rawString: rawString,
      );
    } on TimeoutException catch (_) {
      _nvsRawReadCompleter = null;
      return (status: kSettingsNvsRawError, value: null, rawString: null);
    } catch (_) {
      _nvsRawReadCompleter = null;
      return (status: kSettingsNvsRawError, value: null, rawString: null);
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
  /// Also removes the device from history and clears saved password.
  /// Returns true if the command was sent successfully (device will reboot).
  Future<bool> sendFactoryReset() async {
    if (!_transport.isConnected) return false;
    try {
      await _transport.writePacket(SettingsProtocolService.buildFactoryReset());
      // Remove from history and clean up saved password
      if (_connectedDevice != null) {
        historyProvider?.removeDevice(_connectedDevice!.id);
        SecureStorageService.deletePassword(_connectedDevice!.id);
      }
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
    String? icon,
    bool clearIcon = false,
  }) async {
    if (!_transport.isConnected) return false;
    try {
      final pkt = SettingsProtocolService.buildSetConf(
        name: name,
        description: description,
        password: password,
        adminPassword: adminPassword,
        icon: icon,
        clearIcon: clearIcon,
      );
      await _transport.writePacket(pkt);
      // Wait for SET_CONF_ACK from the settings protocol
      final completer = Completer<int>();
      _setConfCompleter = completer;
      try {
        final status = await completer.future.timeout(const Duration(seconds: 5));
        final hasError = (status & kSettingsSetConfError) != 0;
        if (!hasError) {
          // Update local state with icon if provided
          if (icon != null && _connectedDevice != null) {
            _connectedDevice = _connectedDevice!.copyWith(deviceIcon: icon);
            notifyListeners();
          } else if (clearIcon && _connectedDevice != null) {
            _connectedDevice = _connectedDevice!.copyWith(deviceIcon: null);
            notifyListeners();
          }
          // Request fresh device info to update name/desc
          unawaited(_requestDeviceInfo());
          return true;
        }
        _log('sendSetConf: device returned error 0x${status.toRadixString(16)}',
            level: ConsoleLogLevel.error);
        return false;
      } on TimeoutException catch (_) {
        return false;
      } finally {
        if (_setConfCompleter == completer) {
          _setConfCompleter = null;
        }
      }
    } catch (e) {
      _log('sendSetConf failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
  }

  /// Authenticate with a password. The device checks against both
  /// stored device and user passwords and returns the granted level.
  ///
  /// Response codes:
  ///   0x00 → device level (full access)
  ///   0x01 → user level (widgets-only)
  ///   0x02 → denied (password did not match)
  ///
  /// Returns true on success (any level), false on mismatch or error.
  Future<bool> authenticate(String password) async {
    if (!_transport.isConnected) return false;
    if (_authLevel == AuthLevel.device) return true;
    try {
      final pkt = SettingsProtocolService.buildPwdAuth(password);
      await _transport.writePacket(pkt);
      final completer = Completer<int>();
      _authCompleter = completer;
      try {
        final status = await completer.future.timeout(const Duration(seconds: 5));
        if (status == kSettingsPwdDevice) {
          _authLevel = AuthLevel.device;
          _cancelAuthTimeout();
          notifyListeners();
          return true;
        } else if (status == kSettingsPwdUser) {
          _authLevel = AuthLevel.user;
          _cancelAuthTimeout();
          notifyListeners();
          return true;
        }
        // status == DENIED
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

  // ── Cloud transport reference (set by RemoteAccessService after relay auth) ─
  /// Stores the authenticated cloud WebSocket transport for re-use by
  /// [switchTransport]. Set by [setCloudTransport] after a successful
  /// cloud relay connection (via `/api/cloud/connect` + `/api/cloud/join`).
  WebSocketService? _cloudTransport;

  /// Store an authenticated cloud WebSocket transport for later use by
  /// [switchTransport]. Called by [RemoteAccessService._handleCloudJoin]
  /// after joining a device on the relay.
  void setCloudTransport(WebSocketService ws) {
    _cloudTransport = ws;
  }

  // ── Transport switch (detect-first) ─────────────────────────────────────────

  /// Switch to a different transport (ble, wifi, cloud).
  /// Connect-first approach: sets up callbacks on target transport,
  /// connects to it while source is still active, then disconnects
  /// the source transport only after the target is confirmed connected.
  /// Clears source transport's connectionLost callback before disconnecting
  /// to prevent it from triggering a spurious disconnect state change.
  /// Returns true on success, false if the target transport is unreachable.
  Future<bool> switchTransport(TransportType target) async {
    final device = _connectedDevice;
    if (device == null || !_transport.isConnected) return false;

    final currentSrc = _transport;
    TransportService? targetTransport;
    String targetAddress = '';
    TransportType? targetType;

    if (target == TransportType.ble) {
      // BLE: use device's persistent bleAddress, then fall back to transportAddress or id
      targetTransport = currentSrc is BleService ? currentSrc : BleService();
      targetAddress = device.bleAddress ?? device.transportAddress ?? device.id;
      targetType = TransportType.ble;
      _log('Switching to BLE — using address: $targetAddress', level: ConsoleLogLevel.info);
    } else if (target == TransportType.wifi) {
      // WiFi: try to get IP from device while on current transport
      // Fall back to persistent wifiAddress if device isn't reachable via current transport
      String? ip;
      try {
        final wifiInfo = await sendGetWifiInfo();
        if (wifiInfo != null && wifiInfo.ip.isNotEmpty) {
          ip = wifiInfo.ip;
        }
      } catch (_) {}

      // Fallback: use cached wifiAddress from a previous WiFi connection
      // (preserves scheme, host, and port from the cached URL)
      if (ip == null && device.wifiAddress != null) {
        targetAddress = device.wifiAddress!;
        targetTransport = WebSocketService();
        targetType = TransportType.wifi;
        _log('Using cached WiFi address: $targetAddress', level: ConsoleLogLevel.info);
      } else if (ip != null) {
        targetAddress = 'ws://$ip:${kDefaultWifiPort}';
        targetTransport = WebSocketService();
        targetType = TransportType.wifi;
      } else {
        _log('Cannot switch to WiFi: device IP unknown', level: ConsoleLogLevel.error);
        return false;
      }
    } else if (target == TransportType.cloud) {
      // Re-use existing authenticated cloud transport if available.
      // This is the normal path: RemoteAccessService._handleCloudJoin sets
      // _cloudTransport via setCloudTransport() after a successful relay
      // auth + join sequence. A new unauthenticated WebSocketService cannot
      // route frames through the relay (no auth_request sent).
      if (_cloudTransport != null && _cloudTransport!.isConnected) {
        targetTransport = _cloudTransport;
        targetAddress = 'cloud://${_cloudTransport!.account ?? "relay"}';
        targetType = TransportType.cloud;
        _log('Using existing cloud transport', level: ConsoleLogLevel.info);
      } else {
        // Fallback: try to create a new cloud transport from device info.
        // This only works if the relay doesn't require auth (unlikely for
        // production relays). Normal code should use _cloudTransport.
        String? url;
        try {
          final cloudInfo = await sendGetCloudInfo();
          if (cloudInfo != null && cloudInfo.url.isNotEmpty && cloudInfo.account.isNotEmpty) {
            url = cloudInfo.url;
          }
        } catch (_) {}

        if (url == null) {
          _log('Cannot switch to Cloud: no existing cloud transport and no relay URL from device',
              level: ConsoleLogLevel.error);
          return false;
        }

        targetAddress = (url.startsWith('ws://') || url.startsWith('wss://'))
            ? url
            : 'ws://$url';
        targetTransport = WebSocketService();
        targetType = TransportType.cloud;
      }
    } else {
      return false;
    }

    if (targetTransport == null) return false;

    // Connect to target FIRST (while source is still active)
    _log('Switching transport to ${target.name} ($targetAddress)...', level: ConsoleLogLevel.info);
    try {
      await targetTransport.connect(targetAddress);
      if (!targetTransport.isConnected) {
        _log('Failed to connect via ${target.name} — staying on current transport',
            level: ConsoleLogLevel.warning);
        return false;
      }
    } catch (e) {
      _log('Switch to ${target.name} failed: $e', level: ConsoleLogLevel.error);
      return false;
    }

    // Clear old transport's connectionLost callback to prevent it from
    // triggering a spurious disconnect/state-clear when we disconnect it.
    currentSrc.onConnectionLost = null;

    // Swap transport — setTransport handles DebugTransport wrapping + callbacks
    setTransport(targetTransport);

    if (_connectedDevice != null) {
      _connectedDevice = _connectedDevice!.copyWith(
        preferredTransport: _transportTypeToString(target),
        transportAddress: targetAddress,
        currentTransport: targetType,
        // Persist WiFi address so we can switch back from any transport
        wifiAddress: target == TransportType.wifi
            ? targetAddress
            : _connectedDevice!.wifiAddress,
      );
    }

    // Disconnect source transport, unless it's the same instance as the target
    // (e.g., already on cloud, re-using the same authenticated WebSocketService).
    if (!identical(currentSrc, targetTransport)) {
      try {
        await currentSrc.disconnect();
      } catch (_) {}
    }

    _log('Transport switched to ${target.name}', level: ConsoleLogLevel.success);
    notifyListeners();
    return true;
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
      _transport.onFsPacketReceived = _handleFsPacket;
      _transport.onOtaPacketReceived = _handleOtaPacket;
      _transport.onSettingsPacketReceived = _handleSettingsPacket;
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

  Future<void> connectToDevice(DeviceInfo device, {int baudRate = 115200}) async {
    _connectionState = DeviceConnectionState.connecting;
    _configReceived = false;
    _connectedDevice = device;
    _errorMessage    = null;
    _configName      = null;
    _description     = null;
    _authLevel   = AuthLevel.none;
    _authCompleter   = null;
    notifyListeners();

    // Use transportAddress for actual connection, fallback to id (which may be
    // a transport address at scan time, or a UID for reconnections)
    final connectAddress = device.transportAddress ?? device.id;
    _log('CONNECTING TO: ${device.name} via $connectAddress');

    // Save BLE address if we're connecting via BLE and don't have one yet
    // Check currentTransport rather than _transport type to handle DebugTransport wrapping
    if (device.bleAddress == null && device.currentTransport == TransportType.ble) {
      _connectedDevice = _connectedDevice!.copyWith(bleAddress: connectAddress);
    }

    try {
      await _transport.connect(connectAddress, baudRate: baudRate);
      if (_connectionState == DeviceConnectionState.disconnected) return;
    } catch (e) {
      _log('CONNECTION FAILED: $e', level: ConsoleLogLevel.error);
      _errorMessage    = 'Connection failed: $e';
      _connectionState = DeviceConnectionState.error;
      await _transport.disconnect(); // Hardened cleanup
      notifyListeners();
      return;
    }

    // No fixed settle delay: BLE connect() already completes MTU negotiation,
    // service discovery and notify subscription, and push-capable firmware
    // sends CONF_DATA on subscribe. _requestConfig() waits a short window for
    // that push (BLE) or requests immediately (other transports).
    if (_connectionState == DeviceConnectionState.disconnected) return;

    await _requestConfig();

    // Request device info (name, description, proto version) via settings protocol
    unawaited(_requestDeviceInfo());

    // Request features after config loads — fire-and-forget
    // Auth timeout is started in _handleFeaturesData() when hasPassword is detected.
    unawaited(_requestFeatures());

    // Request remote links (fs_url, ota_url) — fire-and-forget
    unawaited(_requestLinksInfo());

    // Request chip info — will be fetched on first display
    unawaited(_requestChipInfo());

    // Request page names so the reconstructed live config can emit a top-level
    // pages[] array (PAGES_DATA arrives after CONF_DATA).
    unawaited(sendGetPages());

    // Cache cloud account for fallback reconnect consideration
    // Note: actual fetch happens in _handleSettingsDeviceInfoData after UID is set
    // to avoid racing with _requestDeviceInfo()
  }

  Future<void> loadDemo(String demoId) async {
    _connectionState = DeviceConnectionState.connecting;      _connectedDevice = DeviceInfo(
      id: 'DEMO_$demoId',
      name: demoId.replaceAll('_', ' '),
      rssi: -50,
      hasFs: true,
      currentTransport: TransportType.demo,
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

      // Infer orientation from canvas size or page orientation
      final version = data['version'] as int? ?? 1;
      List<dynamic> widgetsJson;
      if (version >= 2 && data.containsKey('pages')) {
        // v2 format: pages[].widgets
        final pages = data['pages'] as List<dynamic>? ?? [];
        _pageNames = pages
            .map((p) => (p as Map<String, dynamic>?)?['name'] as String? ?? 'Page')
            .toList();
        _numPages = _pageNames.length;
        // Flatten all pages' widgets for demo rendering
        widgetsJson = [];
        _pageOrientations = [];
        // Read global orientation from canvas
        final canvasOrientation = canvas['orientation'] as String? ?? 'landscape';
        final globalIsLandscape = canvasOrientation != 'portrait';

        for (final page in pages) {
          final pageWidgets = (page as Map<String, dynamic>?)?['widgets'] as List<dynamic>? ?? [];
          widgetsJson.addAll(pageWidgets);
          // Compute per-page effective orientation
          final pageOrientation = page?['orientation'] as String? ?? 'global';
          bool effectiveIsLandscape;
          switch (pageOrientation) {
            case 'landscape':
              effectiveIsLandscape = true;
              break;
            case 'portrait':
              effectiveIsLandscape = false;
              break;
            case 'global':
            default:
              effectiveIsLandscape = globalIsLandscape;
              break;
          }
          _pageOrientations.add(effectiveIsLandscape
              ? kOrientationLandscape
              : kOrientationPortrait);
        }
        // Set initial orientation from first page
        _orientation = _pageOrientations.isNotEmpty
            ? _pageOrientations[0]
            : kOrientationLandscape;
      } else {
        // v1 format: flat widgets[], orientation from canvas.size
        widgetsJson = data['widgets'] as List<dynamic>? ?? [];
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
        _pageOrientations = [_orientation];
      }
      final nameToId = <String, int>{};
      _widgets = [];
      if (version >= 2 && data.containsKey('pages')) {
        final pages = data['pages'] as List<dynamic>? ?? [];
        for (int pIdx = 0; pIdx < pages.length; pIdx++) {
          final pageObj = pages[pIdx] as Map<String, dynamic>?;
          final pageWidgets = pageObj?['widgets'] as List<dynamic>? ?? [];
          for (final w in pageWidgets) {
            final parsed = _widgetConfigFromDesignerJson(w as Map<String, dynamic>, pageIndex: pIdx);
            _widgets.add(parsed);
            final widgetName = w['name'] as String?;
            if (widgetName != null && widgetName.isNotEmpty) {
              nameToId[widgetName] = parsed.widgetId;
            }
          }
        }
      } else {
        for (final w in widgetsJson) {
          final parsed = _widgetConfigFromDesignerJson(w as Map<String, dynamic>);
          _widgets.add(parsed);
          final widgetName = w['name'] as String?;
          if (widgetName != null && widgetName.isNotEmpty) {
            nameToId[widgetName] = parsed.widgetId;
          }
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

      _connectionState = DeviceConnectionState.connected;
      // Cache the original designer JSON for fast UI rendering.
      _deviceConfigJson = widgetConfigsToDesignerJson(
        widgets: _widgets,
        name: _configName ?? demoId,
        description: _description ?? 'Interactive Demo Mode',
        orientation: _orientation,
        theme: config['theme'] as String? ?? 'dragon',
        pageNames: _pageNames,
        features: data['features'] as Map<String, dynamic>?,
        enableControlUI: data['enableControlUI'] as bool?,
        showPageBar: canvas['showPageBar'] as bool?,
        showControlPageBar: canvas['showControlPageBar'] as bool?,
      );
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
  WidgetConfig _widgetConfigFromDesignerJson(Map<String, dynamic> w, {int pageIndex = 0}) {
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
    // Label is always present (no mask bit needed).
    if (icon.isNotEmpty) strMask |= kStrMaskIcon;
    if (onText.isNotEmpty) strMask |= kStrMaskOnText;
    if (offText.isNotEmpty) strMask |= kStrMaskOffText;
    if (content.isNotEmpty) strMask |= kStrMaskContent;

    final pIndex = (w['pageIndex'] as num?)?.toInt() ?? pageIndex;

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
      pageIndex: pIndex,
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
    // The firmware pushes CONF_DATA on BLE subscribe, which is parsed during
    // transport.connect() — before this method runs. Skip the handshake when
    // the config already arrived.
    if (_configReceived) {
      _log('CONF_DATA already received (device push) — skipping handshake');
      return;
    }

    _log('ESTABLISHING HANDSHAKE (Protocol v$kProtocolVersion)...');
    _connectionState = DeviceConnectionState.fetchingConfig;
    notifyListeners();

    // Push-capable firmware (BLE) sends CONF_DATA on client subscribe, so the
    // first attempt waits for that push instead of requesting; if it does not
    // arrive within kPushWaitTimeout we fall back to GET_CONF.
    final waitForPush = _connectedDevice?.currentTransport == TransportType.ble;

    for (int attempt = 0; attempt < 3; attempt++) {
      _confCompleter = Completer<void>();
      final isPushWait = waitForPush && attempt == 0;

      if (!isPushWait) {
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
      } else {
        _log('WAITING for pushed CONF_DATA (BLE subscribe, ${kPushWaitTimeout.inMilliseconds}ms)...');
      }

      _confTimeoutTimer?.cancel();
      _confTimeoutTimer = Timer(isPushWait ? kPushWaitTimeout : kConfTimeout, () {
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
        _log(isPushWait
            ? 'PUSH TIMEOUT: no CONF_DATA within ${kPushWaitTimeout.inMilliseconds}ms — falling back to GET_CONF.'
            : 'TIMEOUT: Device did not respond to GET_CONF.',
            level: ConsoleLogLevel.warning);
        if (_connectionState == DeviceConnectionState.disconnected) return;
        if (attempt < 2) continue;

        _errorMessage = 'Device did not respond with CONF_DATA after 3 attempts.';
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
      await _transport.writePacket(pkt);
    } catch (e) {
      debugPrint('RadioKit: _writePacket error: $e');
      rethrow;
    }
  }

  void _handlePacket(ParsedPacket packet) {
    final hex = packet.payload.take(32).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
    debugPrint('RadioKit _handlePacket: cmd=0x${packet.cmd.toRadixString(16).padLeft(2, '0')} payloadLen=${packet.payload.length} hex=$hex');
    switch (packet.cmd) {
      case kCmdConfData:  _handleConfData(packet.payload);  break;
      case kCmdVarData:   _handleVarData(packet.payload);   break;
      case kCmdSetInput:  _handleSetInput(packet.payload);  break;
      case kCmdVarUpdate: _handleVarUpdate(packet.payload); break;
      case kCmdMetaData:  _handleMetaData(packet.payload);  break;
      case kCmdMetaUpdate: _handleMetaUpdate(packet.payload); break;
      case kCmdAck:           _handleAck(packet.payload);       break;
      case kCmdWifiInfoData:
        _handleWifiInfoData(packet.payload);
        break;
      case kCmdSetPage:
        _handleSetPage(packet.payload);
        break;

      case kCmdPageChanged:
      case kCmdPageSwitch:
        _handlePageChanged(packet.cmd, packet.payload);
        break;
      case kCmdPagesData:
        _handlePagesData(packet.payload);
        break;
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
      case kSettingsRespSetWifiAck:
        _handleSettingsSetWifiAck(packet.payload);
        break;
      case kSettingsRespFactoryResetAck:
        _log('Factory reset ACK received', level: ConsoleLogLevel.success);
        break;        case kSettingsRespDeviceInfoData:
        _handleSettingsDeviceInfoData(packet.payload);
        break;
      case kSettingsRespCloudInfoData:
        _handleSettingsCloudInfoData(packet.payload);
        break;
      case kSettingsRespLinksInfoData:
        _handleSettingsLinksInfoData(packet.payload);
        break;
      case kSettingsRespRebootAck:
        _log('Reboot ACK received — device rebooting', level: ConsoleLogLevel.success);
        break;
      case kPrintStartByte:
        _handlePrintData(packet.payload);
        return;
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
        '(FS=${hasFs}, BLE=${hasBle}, WiFi=${hasWifi}, Cloud=${hasCloud}, OTA=${hasOta}, '
        'devicePwd=${hasDevicePassword}, userPwd=${hasUserPassword})',
        level: ConsoleLogLevel.success);
    
    // Skip auth timeout for serial — physical access implies full access.
    final isSerial = _connectedDevice?.currentTransport == TransportType.serial;
    if (hasPassword && _authLevel == AuthLevel.none && _connectionState == DeviceConnectionState.connected && !isSerial) {
      _startAuthTimeout();
    }
    // Clear saved password only if the device has NO passwords at all.
    // If either device or user password is set, keep the saved password
    // so auto-auth on reconnect can use it.
    if (!hasPassword && _connectedDevice != null) {
      SecureStorageService.deletePassword(_connectedDevice!.id);
    }
    
    // If the features bitmask reports FS, set hasFs immediately (no probe needed).
    if (hasFs && _connectedDevice != null && !_connectedDevice!.hasFs) {
      _connectedDevice = _connectedDevice!.copyWith(hasFs: true);
      _log('Filesystem detected via feature bit',
          level: ConsoleLogLevel.success);
      notifyListeners();
      unawaited(prefetchFsTree());
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
        completer.complete((status: kSettingsNvsRawError, value: null, rawBytes: null));
      }
      return;
    }
    final displayVal = parsed.rawBytes != null
        ? utf8Decode(parsed.rawBytes!)
        : parsed.value?.toString() ?? 'null';
    _log('NVS raw read: status=${parsed.status} value=$displayVal',
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

  void _handleSettingsSetWifiAck(Uint8List payload) {
    if (payload.isNotEmpty) {
      final status = payload[0];
      final hasError = (status & kSettingsSetConfError) != 0;
      if (hasError) {
        _log('SET_WIFI ACK: error (0x${status.toRadixString(16)})',
            level: ConsoleLogLevel.error);
      } else {
        _log('SET_WIFI ACK: SSID=${(status & kSettingsSetWifiSsid) != 0 ? "set" : "-"} '
            'PWD=${(status & kSettingsSetWifiPwd) != 0 ? "set" : "-"}',
            level: ConsoleLogLevel.success);
      }
    }
  }

  void _handleSettingsSetConfAck(Uint8List payload) {
    final status = payload.isNotEmpty ? payload[0] : kSettingsSetConfError;
    _log('SETTINGS_SET_CONF ACK: 0x${status.toRadixString(16)}',
        level: ConsoleLogLevel.info);
    final completer = _setConfCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(status);
    }
  }

  /// Request device info with retry. Tries up to 3 times on timeout.
  Future<void> _requestDeviceInfo() async {
    if (!_transport.isConnected) return;
    for (int attempt = 0; attempt < 3; attempt++) {
      if (!_transport.isConnected) return;
      final completer = Completer<void>();
      _deviceInfoCompleter = completer;
      try {
        await _writePacket(SettingsProtocolService.buildGetDeviceInfo());
      } catch (_) {
        _deviceInfoCompleter = null;
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 500));
          continue;
        }
        return;
      }
      try {
        await completer.future.timeout(const Duration(seconds: 5));
        _deviceInfoCompleter = null;
        return; // Success
      } on TimeoutException catch (_) {
        _deviceInfoCompleter = null;
        _log('DEVICE_INFO request timeout (attempt ${attempt + 1}/3)',
            level: ConsoleLogLevel.warning);
        if (attempt < 2) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      } catch (_) {
        _deviceInfoCompleter = null;
        return;
      }
    }
    _log('DEVICE_INFO: All 3 attempts timed out — device may not support GET_DEVICE_INFO',
        level: ConsoleLogLevel.warning);
  }

  /// Send SET_CLOUD_INFO command via settings protocol to configure cloud relay URL and account.
  /// The device saves to NVS (no reboot). Returns true if command was sent successfully.
  Future<bool> sendSetCloudInfo({
    String? url,
    String? account,
  }) async {
    if (!_transport.isConnected) return false;
    try {
      final pkt = SettingsProtocolService.buildSetCloudInfo(
        url: url,
        account: account,
      );
      await _writePacket(pkt);
      _log('SET_CLOUD_INFO sent (URL=${url != null ? "yes" : "no"} '
          'ACCT=${account != null ? "yes" : "no"})',
          level: ConsoleLogLevel.info);
      return true;
    } catch (e) {
      _log('sendSetCloudInfo failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
  }

  /// Send GET_CLOUD_INFO and wait for response.
  /// Returns (url, account) or null on timeout.
  Future<({String url, String account})?> sendGetCloudInfo() async {
    if (!_transport.isConnected) return null;
    final completer = Completer<({String url, String account})>();
    _cloudInfoCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildGetCloudInfo());
    } catch (e) {
      _cloudInfoCompleter = null;
      return null;
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException catch (_) {
      _cloudInfoCompleter = null;
      return null;
    } catch (_) {
      _cloudInfoCompleter = null;
      return null;
    }
  }

  void _handleSettingsCloudInfoData(Uint8List payload) {
    final parsed = SettingsProtocolService.parseCloudInfoData(payload.toList());
    if (parsed == null) {
      _log('CLOUD_INFO_DATA parse failed', level: ConsoleLogLevel.error);
      final completer = _cloudInfoCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(Exception('Parse failed'));
      }
      return;
    }
    _log('Cloud info: URL="${parsed.url}" account="${parsed.account.length > 16 ? parsed.account.substring(0, 16) + '...' : parsed.account}"',
        level: ConsoleLogLevel.success);
    notifyListeners();
    final completer = _cloudInfoCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(parsed);
    }
  }

  Completer<({String fsUrl, String otaUrl})>? _linksInfoCompleter;

  /// Send GET_LINKS_INFO and wait for response.
  /// Returns (fsUrl, otaUrl) or null on timeout.
  Future<({String fsUrl, String otaUrl})?> sendGetLinksInfo() async {
    if (!_transport.isConnected) return null;
    final completer = Completer<({String fsUrl, String otaUrl})>();
    _linksInfoCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildGetLinksInfo());
    } catch (e) {
      _linksInfoCompleter = null;
      return null;
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException catch (_) {
      _linksInfoCompleter = null;
      return null;
    } catch (_) {
      _linksInfoCompleter = null;
      return null;
    }
  }

  void _handleSettingsLinksInfoData(Uint8List payload) {
    final parsed = SettingsProtocolService.parseLinksInfoData(payload.toList());
    if (parsed == null) {
      _log('LINKS_INFO_DATA parse failed', level: ConsoleLogLevel.error);
      final completer = _linksInfoCompleter;
      if (completer != null && !completer.isCompleted) {
        completer.completeError(Exception('Parse failed'));
      }
      return;
    }
    _fsUrl = parsed.fsUrl;
    _otaUrl = parsed.otaUrl;
    _log('Remote links: fs="${parsed.fsUrl}" ota="${parsed.otaUrl}"',
        level: ConsoleLogLevel.info);
    notifyListeners();
    final completer = _linksInfoCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(parsed);
    }
  }

  /// Fire-and-forget: request remote links from device on connect.
  Future<void> _requestLinksInfo() async {
    if (!_transport.isConnected) return;
    try {
      await sendGetLinksInfo();
    } catch (e) {
      _log('Failed to fetch remote links: $e', level: ConsoleLogLevel.info);
    }
  }

  /// Migrate saved password from old device ID to new UID.
  Future<void> _migratePassword(String oldId, String newId) async {
    if (oldId == newId) return;
    final saved = await SecureStorageService.loadPassword(oldId);
    if (saved != null && saved.isNotEmpty) {
      await SecureStorageService.savePassword(newId, saved);
      await SecureStorageService.deletePassword(oldId);
    }
  }

  void _handleSettingsDeviceInfoData(Uint8List payload) {
    final parsed = SettingsProtocolService.parseDeviceInfoData(payload.toList());
    if (parsed == null) {
      _log('DEVICE_INFO_DATA parse failed', level: ConsoleLogLevel.error);
      return;
    }
    _log('Device info: v${parsed.version} "${parsed.name}" "${parsed.description}" uid="${parsed.uid}" board="${parsed.board ?? ''}" ver="${parsed.firmwareVersion ?? ''}"',
        level: ConsoleLogLevel.success);
    _configName = parsed.name.isNotEmpty ? parsed.name : _configName;
    _description = parsed.description.isNotEmpty ? parsed.description : _description;
    if (parsed.board != null && parsed.board!.isNotEmpty) {
      _board = parsed.board;
    }
    if (parsed.firmwareVersion != null && parsed.firmwareVersion!.isNotEmpty) {
      _firmwareVersion = parsed.firmwareVersion;
    }

    // Update DeviceInfo name to match the device's configured name,
    // not the transport address (e.g. "WiFi_Cloud_Switch", not "10.0.0.5").
    if (_configName != null && _configName!.isNotEmpty &&
        _connectedDevice != null && _connectedDevice!.name != _configName) {
      _connectedDevice = _connectedDevice!.copyWith(name: _configName!);
    }

    // Update _connectedDevice with parsed icon (on first connection, or refresh)
    if (_connectedDevice != null && parsed.icon != null) {
      _connectedDevice = _connectedDevice!.copyWith(deviceIcon: parsed.icon);
    } else if (_connectedDevice != null && parsed.icon == null && _connectedDevice!.deviceIcon != null) {
      // Icon was cleared on device — sync
      _connectedDevice = _connectedDevice!.copyWith(deviceIcon: null);
    }

    // Update _connectedDevice.id with the device UID (from NVS)
    // Preserve bleAddress across the ID transition
    if (_connectedDevice != null && parsed.uid.isNotEmpty) {
      final oldId = _connectedDevice!.id;

      // Skip if UID hasn't changed — prevents duplicate history saves
      // when _requestDeviceInfo() is called multiple times
      if (oldId == parsed.uid) {
        _log('UID unchanged: ${parsed.uid} (skipping history update)',
            level: ConsoleLogLevel.info);
      } else {
        _connectedDevice = _connectedDevice!.copyWith(
          // Use copyWith to avoid losing bleAddress; null fields are retained
          bleAddress: _connectedDevice!.bleAddress,
        );
        _connectedDevice!.id = parsed.uid;

        // Save to history with the real UID
        // If there was a previous entry with the transport address, remove it
        if (historyProvider != null) {
          historyProvider!.removeDevice(oldId);
          historyProvider!.saveDevice(
            _connectedDevice!,
            _transportTypeToString(_connectedDevice!.currentTransport),
            configName: _configName,
            description: _description,
          );

          // Restore transport addresses from the existing model onto
          // _connectedDevice so switchTransport can find them (e.g. BLE
          // address when switching from cloud).
          final existingDevice = historyProvider!.pairedDevices
              .where((d) => d.uid == parsed.uid).firstOrNull;
          if (existingDevice != null) {
            _connectedDevice = _connectedDevice!.copyWith(
              bleAddress: existingDevice.bleAddress ?? _connectedDevice!.bleAddress,
              wifiAddress: existingDevice.wifiAddress ?? _connectedDevice!.wifiAddress,
            );
          }
        }

        // Migrate saved password from old transport-address key to UID key
        unawaited(_migratePassword(oldId, parsed.uid));

        _log('UID set: ${parsed.uid} (was: $oldId)', level: ConsoleLogLevel.success);
        // Cache cloud account now that UID is confirmed
        unawaited(_cacheCloudAccount());
      }
    }

    notifyListeners();
    final completer = _deviceInfoCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  /// Convert [TransportType] to its string form for history persistence.
  static String _transportTypeToString(TransportType t) {
    switch (t) {
      case TransportType.ble:    return 'ble';
      case TransportType.wifi:   return 'wifi';
      case TransportType.cloud:  return 'cloud';
      case TransportType.serial: return 'serial';
      case TransportType.demo:   return 'demo';
    }
  }

  /// Fire-and-forget: fetch cloud info from the device and cache the account
  /// in the history provider so reconnect fallback can match accounts.
  /// Guards with [hasCloud] to skip devices without cloud support.
  Future<void> _cacheCloudAccount() async {
    if (!hasCloud || _connectedDevice == null || historyProvider == null) return;
    try {
      final cloudInfo = await sendGetCloudInfo();
      if (cloudInfo != null && cloudInfo.account.isNotEmpty) {
        historyProvider!.saveDevice(
          _connectedDevice!,
          _transportTypeToString(_connectedDevice!.currentTransport),
          cloudAccount: cloudInfo.account,
        );
        _log('Cloud account cached: ${cloudInfo.account.substring(0, 16)}...',
            level: ConsoleLogLevel.success);
      }
    } catch (e) {
      _log('Failed to cache cloud account: $e', level: ConsoleLogLevel.info);
    }
  }



  /// Request features from the device via settings protocol. Fire-and-forget.
  Future<void> _requestFeatures({int attempt = 0}) async {
    if (!_transport.isConnected) return;
    final completer = Completer<int>();
    _featuresCompleter = completer;
    try {
      await _writePacket(SettingsProtocolService.buildGetFeatures());
    } catch (e) {
      _log('GET_FEATURES write failed: $e', level: ConsoleLogLevel.warning);
      _featuresCompleter = null;
      return;
    }
    try {
      await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException catch (_) {
      if (attempt < 1) {
        _log('GET_FEATURES timeout (attempt ${attempt + 1}/2) — retrying in 300ms',
            level: ConsoleLogLevel.warning);
        _featuresCompleter = null;
        await Future.delayed(const Duration(milliseconds: 300));
        await _requestFeatures(attempt: attempt + 1);
        return;
      }
      _log('GET_FEATURES timeout (attempt ${attempt + 1}/2) — giving up',
          level: ConsoleLogLevel.warning);
    } catch (e) {
      _log('GET_FEATURES error: $e', level: ConsoleLogLevel.warning);
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
    if (_pageSwitchState == _PageSwitchState.pagePending) {
      _pageSwitchState = _PageSwitchState.idle;
    }
    _log('MCU <- CONF_DATA (${payload.length} bytes)');
    debugPrint('RadioKit CONF_DATA raw hex: ${payload.take(64).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}${payload.length > 64 ? ' ...' : ''}');
    final conf = ProtocolService.parseConfData(payload);
    if (conf == null) {
      _log('PARSE FAILED: Invalid CONF_DATA payload.', level: ConsoleLogLevel.error);
      debugPrint('RadioKit: CONF_DATA parse failed — raw: '
          '${payload.take(64).map((b) => b.toRadixString(16).padLeft(2, "0")).join(" ")}');
      return;
    }
    _log('RECEIVED CONFIG: ${_connectedDevice?.name ?? conf.name} with ${conf.widgets.length} widgets', level: ConsoleLogLevel.success);
    _configReceived = true;
    // Name/desc may come from device info (v4) or embedded in CONF_DATA (v3 fallback)
    final fallbackName = _connectedDevice?.name ?? 'RadioKit Device';
    _configName      = conf.name.isNotEmpty ? conf.name : _configName ?? fallbackName;
    _description     = conf.description.isNotEmpty ? conf.description : _description;
    // The wire only carries the active page's widgets (page gating), so stamp
    // them with the active page index — otherwise every widget is grouped
    // under page 0 and a switched page shows under the wrong page name.
    _widgets = conf.widgets
        .map((w) => w.pageIndex == conf.activePage
            ? w
            : w.copyWith(pageIndex: conf.activePage))
        .toList();
    _numPages = conf.numPages;
    _activePage = conf.activePage;
    // Use per-page orientations from device if available, fallback to global
    if (conf.pageOrientations.isNotEmpty && conf.pageOrientations.length == _numPages) {
      _pageOrientations = List<int>.from(conf.pageOrientations);
    } else {
      _pageOrientations = List.filled(_numPages, conf.orientation);
    }
    if (_activePage < _pageOrientations.length) {
      _orientation = _pageOrientations[_activePage];
    } else {
      _orientation = conf.orientation;
    }
    _widgetState     = RadioWidgetState.initial(conf.widgets);
    _connectionState = DeviceConnectionState.connected;

    final wireShowPageBar = (conf.canvasFlags & 0x01) != 0;
    final wireShowControlPageBar = (conf.canvasFlags & 0x02) != 0;

    // Convert to designer-format JSON and cache for fast UI rendering.
    // CONF_DATA carries `canvasFlags` for showPageBar/showControlPageBar;
    // designer-only features/enableControlUI are inherited from (1) a saved design
    // matching the device config name (source of truth), falling back to
    // (2) any previously reconstructed values from this session.
    final designSeed = _designSeedForConfig(_configName ?? fallbackName);
    final prev = _deviceConfigJson;
    _deviceConfigJson = widgetConfigsToDesignerJson(
      widgets: _widgets,
      name: _configName ?? fallbackName,
      description: _description ?? '',
      orientation: _orientation,
      theme: conf.theme,
      pageNames: _pageNames,
      numPages: conf.numPages,
      features: (designSeed?['features'] as Map<String, dynamic>?) ??
          prev?['features'] as Map<String, dynamic>?,
      enableControlUI: (designSeed?['enableControlUI'] as bool?) ??
          prev?['enableControlUI'] as bool?,
      showPageBar: (designSeed?['showPageBar'] as bool?) ??
          (prev?['canvas'] as Map?)?['showPageBar'] as bool? ??
          wireShowPageBar,
      showControlPageBar: (designSeed?['showControlPageBar'] as bool?) ??
          (prev?['canvas'] as Map?)?['showControlPageBar'] as bool? ??
          wireShowControlPageBar,
    );

    // Apply the skin provided by the device
    _themePresetProvider?.setTheme(conf.theme);

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

  /// Finds the most recent saved design whose name matches [configName] and
  /// extracts its designer-only metadata (features, enableControlUI, page-bar
  /// flags) for merging into the live wire reconstruction.
  Map<String, dynamic>? _designSeedForConfig(String configName) {
    final designs = _designsProvider;
    if (designs == null || configName.isEmpty) return null;
    SavedDesign? match;
    for (final d in designs.designs) {
      if (d.name == configName && (d.jsonContent?.isNotEmpty ?? false)) {
        if (match == null || d.timestamp > match.timestamp) match = d;
      }
    }
    if (match?.jsonContent == null) return null;
    try {
      final json = jsonDecode(match!.jsonContent!) as Map<String, dynamic>;
      return designMetadataFromJson(json);
    } catch (_) {
      return null;
    }
  }

  void _handleVarData(List<int> payload) {
    final current = _widgetState;
    if (current == null) return;
    final next = ProtocolService.parseVarData(payload, _widgets, current);
    if (next != null) {
      // Extract telemetry widget values (keyed by widget index)
      for (final w in _widgets) {
        if (w.typeId == kWidgetTelemetry) {
          final value = next.outputValues[w.widgetId];
          if (value != null) {
            _telemetryValues[w.widgetId] = value is String ? value : value.toString();
          }
        }
      }
      _widgetState = next;
      notifyListeners();
    }
  }

  void _handleSetInput(List<int> payload) {
    final result = ProtocolService.parseVarUpdate(payload, hasPagePrefix: false);
    if (result == null) return;
    final (_, widgetId, seq, values) = result;

    final current = _widgetState;
    if (current == null) return;

    final widget = _widgets.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => WidgetConfig(
          typeId: 0, widgetId: widgetId, x: 0, y: 0, width: 0, height: 0),
    );

    // 0x05 SET_INPUT forces a jump for an Input widget
    // Mutate in-place instead of copyWithInput() to avoid heap allocation.
    if (!widget.hasOutput) {
      // Sign-extend int8_t values for Slider and Knob
      final cooked = (widget.typeId == kWidgetSlider ||
                      widget.typeId == kWidgetKnob)
          ? values.map(_signedByte).toList()
          : values;
      current.inputValues[widgetId] = cooked;
      _log('MCU <- SET_INPUT (wid:$widgetId, seq:$seq, override:$cooked)');
    }

    notifyListeners();
  }

  void _handleVarUpdate(List<int> payload) {
    if (_pageSwitchState == _PageSwitchState.pagePending) {
      _pageSwitchState = _PageSwitchState.idle;
    }
    final result = ProtocolService.parseVarUpdate(payload, hasPagePrefix: false);
    if (result == null) return;
    final (_, widgetId, seq, values) = result;

    final current = _widgetState;
    if (current == null) return;

    final widget = _widgets.firstWhere(
      (w) => w.widgetId == widgetId,
      orElse: () => WidgetConfig(
          typeId: 0, widgetId: widgetId, x: 0, y: 0, width: 0, height: 0),
    );

    // 0x09 VAR_UPDATE handles Outputs. Inputs sent over 0x09 are echoes/bounces
    // and must be strictly ignored to prevent UI overwrite jitter.
    // Mutate in-place instead of copyWithOutput() to avoid heap allocation.
    if (widget.hasOutput) {
      if (widget.typeId == kWidgetLed && values.length >= 5) {
        // v3: [STATE, R, G, B, OPACITY]
        current.outputValues[widgetId] = List<int>.from(values.take(5));
      } else if (widget.typeId == kWidgetText || widget.typeId == kWidgetTelemetry) {
        // [LEN(1)] [CHARS...]
        if (values.isNotEmpty) {
          final len = values[0];
          final textLen = values.length - 1;
          // Use the minimum of declared length and actual bytes received
          final end = (1 + min(len, textLen)).clamp(0, values.length).toInt();
          
          final text = utf8Decode(values.sublist(1, end));
          current.outputValues[widgetId] = text;
          if (widget.typeId == kWidgetTelemetry) {
            _telemetryValues[widgetId] = text;
          }
        } else {
          current.outputValues[widgetId] = '';
          if (widget.typeId == kWidgetTelemetry) {
            _telemetryValues[widgetId] = '';
          }
        }
      } else {
        current.outputValues[widgetId] = values.isNotEmpty ? values[0] : 0;
      }
    } else {
      // It's an input bounce. Discard it.
      _log('MCU <- VAR_UPDATE (IGNORED BOUNCE for Input wid:$widgetId)');
    }

    _scheduleNotifyListeners();

    if (widget.hasOutput) {
        _log('MCU <- VAR_UPDATE (wid:$widgetId, seq:$seq)');
    }
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
  }

  /// Handle incoming 0xEE print data — log to console with PRINT level.
  void _handlePrintData(Uint8List payload) {
    if (payload.isEmpty) return;
    final text = utf8Decode(payload.toList());
    _log(text, level: ConsoleLogLevel.print);
  }

  /// Completer for GET_CLOUD_INFO response.
  Completer<({String url, String account})>? _cloudInfoCompleter;

  /// Optional reference to the HistoryProvider for auto-saving on UID receipt.
  /// Set from `app.dart` after construction.
  HistoryProvider? historyProvider;

  /// Send REBOOT command via settings protocol (preserves NVS).
  /// Returns true if the command was sent successfully (device will reboot).
  Future<bool> sendReboot() async {
    if (!_transport.isConnected) return false;
    try {
      await _transport.writePacket(SettingsProtocolService.buildReboot());
      return true;
    } catch (e) {
      _log('sendReboot failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
  }

  /// Completer for GET_WIFI_INFO response.
  Completer<({String ip, int mode, String ssid, int rssi})>? _wifiInfoCompleter;

  /// Send GET_WIFI_INFO and wait for response.
  /// Returns WiFi info or null on timeout.
  Future<({String ip, int mode, String ssid, int rssi})?> sendGetWifiInfo() async {
    if (!_transport.isConnected) return null;
    final completer = Completer<({String ip, int mode, String ssid, int rssi})>();
    _wifiInfoCompleter = completer;
    try {
      await _writePacket(ProtocolService.buildGetWifiInfo());
    } catch (e) {
      _wifiInfoCompleter = null;
      return null;
    }
    try {
      return await completer.future.timeout(const Duration(seconds: 3));
    } on TimeoutException catch (_) {
      _wifiInfoCompleter = null;
      return null;
    } catch (_) {
      _wifiInfoCompleter = null;
      return null;
    }
  }

  void _handleWifiInfoData(List<int> payload) {
    final parsed = ProtocolService.parseWifiInfoData(payload);
    if (parsed == null) {
      _log('WIFI_INFO_DATA parse failed', level: ConsoleLogLevel.error);
      return;
    }
    _log('WiFi info: IP=${parsed.ip} mode=${parsed.mode == kWifiModeSta ? "STA" : "AP"} '
        'SSID="${parsed.ssid}" RSSI=${parsed.rssi}',
        level: ConsoleLogLevel.success);
    notifyListeners();
    final completer = _wifiInfoCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(parsed);
    }
  }

  // ── Page management handlers ─────────────────────────────────────────────

  /// Handle CMD_PAGE_CHANGED (0x21) and CMD_PAGE_SWITCH (0x24).
  void _handlePageChanged(int cmd, List<int> payload) {
    final pageIndex = ProtocolService.parsePageIndex(payload);
    if (pageIndex == null) return;
    _log('MCU <- ${cmd == kCmdPageChanged ? "PAGE_CHANGED" : "PAGE_SWITCH"}: page=$pageIndex',
        level: ConsoleLogLevel.info);
    _activePage = pageIndex;
    // Update orientation from per-page data if available
    if (pageIndex < _pageOrientations.length) {
      _orientation = _pageOrientations[pageIndex];
    }
    // Return to idle state — page switch is complete.
    _pageSwitchState = _PageSwitchState.idle;
    notifyListeners();

    // Re-request CONF_DATA and VAR_DATA for the new page. During pagePending,
    // the firmware may have sent CONF_DATA/VAR_DATA before PAGE_CHANGED arrived
    // (BLE ordering). Those were discarded — request fresh data now.
    //
    // IMPORTANT: Do NOT use _requestConfig() here — it sets connectionState
    // to fetchingConfig which tears down DeviceDesignerBridge, causing a red
    // screen during the page switch transition. Instead, send GET_CONF and
    // GET_VARS directly — _handleConfData will process the response and
    // update widgets/configJson without changing connectionState.
    _writePacket(ProtocolService.buildGetConf()).catchError((_) {});
    _writePacket(ProtocolService.buildGetVars()).catchError((_) {});
  }

  /// Handle CMD_PAGES_DATA (0x23) — page name list from MCU.
  void _handlePagesData(List<int> payload) {
    final names = ProtocolService.parsePagesData(payload);
    if (names == null) return;
    _log('MCU <- PAGES_DATA: ${names.length} pages',
        level: ConsoleLogLevel.info);
    _pageNames = names;
    _numPages = names.length;
    // Rebuild the cached designer JSON so the live config carries the real
    // page names (PAGES_DATA arrives after CONF_DATA).
    if (_widgets.isNotEmpty && _deviceConfigJson != null) {
      _deviceConfigJson = widgetConfigsToDesignerJson(
        widgets: _widgets,
        name: _configName ?? (_connectedDevice?.name ?? 'RadioKit Device'),
        description: _description ?? '',
        orientation: _orientation,
        theme: (_deviceConfigJson!['config'] as Map?)?['theme'] as String? ??
            'dragon',
        pageNames: _pageNames,
        numPages: _numPages,
        features: _deviceConfigJson?['features'] as Map<String, dynamic>?,
        enableControlUI: _deviceConfigJson?['enableControlUI'] as bool?,
        showPageBar:
            (_deviceConfigJson?['canvas'] as Map?)?['showPageBar'] as bool?,
        showControlPageBar: (_deviceConfigJson?['canvas'] as Map?)?[
            'showControlPageBar'] as bool?,
      );
    }
    notifyListeners();
  }

  /// Handle incoming CMD_SET_PAGE (0x20) from device — device requests page switch.
  void _handleSetPage(List<int> payload) {
    final pageIndex = ProtocolService.parsePageIndex(payload);
    if (pageIndex == null) return;
    _log('MCU -> SET_PAGE: switch to page $pageIndex',
        level: ConsoleLogLevel.info);
    _activePage = pageIndex;
    // Update orientation from per-page data if available
    if (pageIndex < _pageOrientations.length) {
      _orientation = _pageOrientations[pageIndex];
    }
    notifyListeners();
  }

  /// Send CMD_SET_PAGE (0x20) to switch the MCU to a specific page.
  Future<void> sendSetPage(int pageIndex) async {
    if (!_transport.isConnected) return;
    _activePage = pageIndex;
    _pageSwitchState = _PageSwitchState.idle;
    if (pageIndex < _pageOrientations.length) {
      _orientation = _pageOrientations[pageIndex];
    }
    notifyListeners();
    if (_transport is DemoTransport || _transport is DemoFsTransport) {
      _log('DEMO -> SET_PAGE: switched to page $pageIndex', level: ConsoleLogLevel.info);
      return;
    }
    try {
      await _writePacket(ProtocolService.buildSetPage(pageIndex));
      _log('APP -> SET_PAGE: page=$pageIndex', level: ConsoleLogLevel.info);
    } catch (e) {
      _log('sendSetPage failed: $e', level: ConsoleLogLevel.error);
    }
  }

  /// Send CMD_GET_PAGES (0x22) to request page names from the MCU.
  Future<void> sendGetPages() async {
    if (!_transport.isConnected) return;
    try {
      await _writePacket(ProtocolService.buildGetPages());
      _log('APP -> GET_PAGES', level: ConsoleLogLevel.info);
    } catch (e) {
      _log('sendGetPages failed: $e', level: ConsoleLogLevel.error);
    }
  }

  // ── WiFi configuration ──────────────────────────────────────────────────

  /// Send SET_WIFI command via settings protocol to configure WiFi credentials.
  /// The device will save to NVS and reboot. Returns true if command was sent.
  Future<bool> sendSetWifi({
    String? ssid,
    String? password,
  }) async {
    if (!_transport.isConnected) return false;
    try {
      final pkt = SettingsProtocolService.buildSetWifi(
        ssid: ssid,
        password: password,
      );
      await _writePacket(pkt);
      _log('SET_WIFI sent (SSID=${ssid != null ? "yes" : "no"} '
          'PWD=${password != null ? "yes" : "no"})',
          level: ConsoleLogLevel.info);
      return true;
    } catch (e) {
      _log('sendSetWifi failed: $e', level: ConsoleLogLevel.error);
      return false;
    }
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
    _authLevel   = AuthLevel.none;
    _authCompleter   = null;
    _connectedAt     = null;
    _errorMessage    = reason;
    notifyListeners();
  }

  // ── Direct VAR_UPDATE (write-without-response, no ACK timeout stall) ─────────
  // Batching: accumulate packets and flush them all in one BLE write.
  // With 48ms connection interval, only one BLE write per connection event.
  // Packing multiple VAR_UPDATE packets into one write achieves 50Hz+ effective rate.

  final List<Uint8List> _pendingWriteBatch = [];
  Timer? _flushTimer;

  void _enqueueVarUpdate(int widgetId, List<int> values, {bool active = true}) {
    final pkt = ProtocolService.buildVarUpdate(widgetId, values, active: active, page: _activePage);
    _pendingWriteBatch.add(pkt);
    _flushTimer ??= Timer(const Duration(milliseconds: 8), _flushWriteBatch);
  }

  Future<void> _flushWriteBatch() async {
    _flushTimer = null;
    if (_pendingWriteBatch.isEmpty || !_transport.isConnected) return;
    // Concatenate all pending packets into one BLE write
    int totalLen = 0;
    for (final p in _pendingWriteBatch) {
      totalLen += p.length;
    }
    final combined = Uint8List(totalLen);
    int offset = 0;
    for (final p in _pendingWriteBatch) {
      combined.setRange(offset, offset + p.length, p);
      offset += p.length;
    }
    _pendingWriteBatch.clear();
    try {
      await _writePacket(combined);
    } catch (_) {}
  }

  Future<void> _sendVarUpdate(int widgetId, List<int> values, {bool active = true}) async {
    if (!_transport.isConnected) return;
    _enqueueVarUpdate(widgetId, values, active: active);
  }

  void _cancelAllPendingUpdates() {
    for (final e in _pendingUpdates.values) {
      e.timer?.cancel();
    }
    _pendingUpdates.clear();
  }

  // ── Widget interaction ──────────────────────────────────────────────────────────

  Future<void> setInputValue(int widgetId, List<int> values, {bool active = true, bool force = false}) async {
    final current = _widgetState;
    if (current == null) return;

    // Skip if value hasn't changed — avoids Map copy + notify + BLE write
    final currentInput = current.inputValues[widgetId];
    if (!force && currentInput != null && _listEquals(currentInput, values)) return;

    // Human-readable interaction log (discrete widgets only to avoid gesture log storms)
    final widget = _widgets.where((w) => w.widgetId == widgetId).firstOrNull;
    if (widget != null) {
      final isDiscrete = widget.typeId == kWidgetButton ||
          widget.typeId == kWidgetSwitch ||
          widget.typeId == kWidgetSlideSwitch ||
          widget.typeId == kWidgetMultiple;
      if (isDiscrete) {
        final label = widget.label.isNotEmpty ? '"${widget.label}"' : '#$widgetId';
        final desc = _describeInteraction(widget, values);
        _log('⚡ ${widget.typeName} $label $desc');
      }
    }

    // Mutate in-place instead of copyWithInput() to avoid heap allocation.
    // copyWithInput creates a new Map + new RadioWidgetState per call,
    // which causes GC pressure and event loop freeze under sustained load.
    current.inputValues[widgetId] = values;
    notifyListeners();  // synchronous — immediate visual update for touch path
    if (!_transport.isConnected) return;
    await _sendVarUpdate(widgetId, values, active: active);
  }

  /// List equality check for input values — avoids unnecessary Map copies.
  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
    if (_setConfCompleter != null && !_setConfCompleter!.isCompleted) {
      _setConfCompleter!.completeError(Exception('Disconnected'));
    }
    await _transport.disconnect();
    _connectedDevice  = null;
    _configName       = null;
    _widgets          = [];
    _widgetState      = null;
    _activePage       = 0;
    _numPages         = 1;
    _pageNames        = [];
    _pageSwitchState  = _PageSwitchState.idle;
    _telemetryValues.clear();
    _description      = null;
    _deviceConfigJson = null;
    _fsTreeCache      = null;
    _deviceFeatures   = 0;
    _chipInfo         = null;
    _authCompleter    = null;
    _authLevel    = AuthLevel.none;
    _cancelAuthTimeout();
    _connectedAt      = null;
    _otaCancelled     = false;
    _errorMessage     = null;
    _cloudTransport   = null;
    _fsUrl            = '';
    _otaUrl           = '';
    _board            = null;
    _firmwareVersion  = null;
    _linksInfoCompleter = null;
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
