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
import '../services/debug_transport.dart';
import '../services/demo_transport.dart';
import '../services/demo_fs_transport.dart';

import '../providers/console_provider.dart';
import '../providers/skin_provider.dart';
import '../providers/debug_provider.dart';
import '../models/console_entry.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

enum DeviceConnectionState {
  disconnected,
  connecting,
  fetchingConfig,
  connected,
  error,
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


  Timer?                   _pingTimer;
  Timer?                   _telemetryTimer;
  Timer?                   _confTimeoutTimer;
  DateTime?                _lastRxAt;
  DateTime?                _lastTxAt;
  final DebugLogSink?            _debugSink;
  Completer<void>?         _confCompleter;
  DateTime?                _pingSentAt;

  final Map<int, _PendingUpdate> _pendingUpdates = {};
  int _nextSeq = 0;

  // ── FS (bulk protocol) ────────────────────────────────────────────────
  /// Active FS request per sub-cmd. The device may also send unsolic­ited
  /// FS frames (e.g. an upload begin from a server-side tool) — those
  /// are dispatched to [_handleUnsolicitedFs] instead.
  final Map<int, Completer<ParsedFsPacket>> _pendingFs = {};

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

    // FS_PING handshake — runs in parallel with config fetch.
    // Sets hasFs=true only if the device actually responds.
    unawaited(_detectFs());

    await _requestConfig();
  }

  /// Send a few FS_PING frames and set [connectedDevice.hasFs] based on
  /// the response. Resilient to no-FS boards and transport jitter.
  Future<void> _detectFs() async {
    if (_connectedDevice == null) return;
    if (_connectedDevice!.hasFs) return; // already true (e.g. demos)
    for (int attempt = 0; attempt < 3; attempt++) {
      if (_connectionState == DeviceConnectionState.disconnected) return;
      if (!_transport.isConnected) return;
      final resp = await sendFs(
        FsProtocolService.buildPing(),
        timeout: const Duration(milliseconds: 1500),
      );
      if (resp == null) {
        await Future.delayed(const Duration(milliseconds: 250));
        continue;
      }
      final code = FsProtocolService.parseAck(resp.payload) ?? kFsErrNoFs;
      if (code == kFsErrOk) {
        _connectedDevice = _connectedDevice!.copyWith(hasFs: true);
        _log('FS_PING OK — filesystem detected (${_connectedDevice!.name})',
            level: ConsoleLogLevel.success);
        notifyListeners();
        return;
      }
    }
    _log('FS_PING: no response after 3 attempts — assuming no FS',
        level: ConsoleLogLevel.info);
  }

  Future<void> loadDemo(String demoId) async {
    _connectionState = DeviceConnectionState.connecting;
    _connectedDevice = DeviceInfo(
      id: 'demo_$demoId',
      name: demoId.replaceAll('_', ' '),
      rssi: -50,
      hasFs: true,
    );
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
    _pingTimer?.cancel();
    _telemetryTimer?.cancel();
    _pingTimer = null;
    _telemetryTimer = null;
    _demoTimer?.cancel();
    _demoTimer = null;

    // Only start demo simulation for known demo configs, not real devices.
    const demoConfigs = {'WIDGETS_DEMO', 'RC_CONTROLLER', 'IOT_DASHBOARD'};
    if (_configName != null && demoConfigs.contains(_configName)) {
      _startDemoSimulation();
    }

    // Request initial telemetry and variables immediately on connection
    if (_transport.isConnected) {
      _writePacket(ProtocolService.buildGetTelemetry()).catchError((_) {});
      _writePacket(ProtocolService.buildGetVars()).catchError((_) {});
    }

    _pingTimer = Timer.periodic(kPingInterval, (_) async {
      if (!_transport.isConnected) return;
      
      final now = DateTime.now();
      // Heartbeat optimization: Only ping if no packets sent OR received recently.
      if (_lastRxAt != null) {
        final idleRx = now.difference(_lastRxAt!);
        if (idleRx < kPingInterval) return;
      }
      if (_lastTxAt != null) {
        final idleTx = now.difference(_lastTxAt!);
        if (idleTx < kPingInterval) return;
      }

      try {
        _pingSentAt = now;
        await _writePacket(ProtocolService.buildPing());
      } catch (_) {}
    });

    _telemetryTimer = Timer.periodic(kTelemetryInterval, (_) async {
      try {
        await _writePacket(ProtocolService.buildGetTelemetry());
      } catch (_) {}
    });
  }

  void _stopPolling() {
    _pingTimer?.cancel(); _pingTimer = null;
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
      case kCmdPong:      _handlePong();                    break;
      case kCmdTelemetryData: _handleTelemetryData(packet.payload); break;
      default:
        debugPrint('RadioKit: Unknown cmd 0x${packet.cmd.toRadixString(16)}');
    }
  }

  void _handlePong() {
    if (_pingSentAt != null) {
      final now = DateTime.now();
      _latencyMs = now.difference(_pingSentAt!).inMilliseconds;
      _pingSentAt = null;
      notifyListeners();
    }
  }

  void _handleTelemetryData(List<int> payload) {
    if (payload.isNotEmpty) {
      final rawRssi = payload[0];
      // Protocol uses a single byte for RSSI, interpreted as signed int8.
      _rssi = rawRssi > 127 ? rawRssi - 256 : rawRssi;
      
      // If firmware sends more bytes, we can parse latency/uptime here.
      if (payload.length >= 4) {
         // Future: parse other telemetry fields
      }

      debugPrint('RadioKit: TELEMETRY_DATA rssi=$_rssi (raw=$rawRssi, len=${payload.length})');
      notifyListeners();
    } else {
      debugPrint('RadioKit: TELEMETRY_DATA received but payload is empty');
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
    _log('RECEIVED CONFIG: "${(conf).name}" with ${conf.widgets.length} widgets', level: ConsoleLogLevel.success);
    _configName      = conf.name;
    _description     = conf.description;
    _widgets         = conf.widgets;
    _orientation     = conf.orientation;
    _widgetState     = RadioWidgetState.initial(conf.widgets);
    _connectionState = DeviceConnectionState.connected;

    // Convert to designer-format JSON and cache for fast UI rendering.
    _deviceConfigJson = widgetConfigsToDesignerJson(
      widgets: conf.widgets,
      name: conf.name,
      description: conf.description,
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
  void _handleFsPacket(ParsedFsPacket packet) {
    // Try exact match first, then match with ACK-mask (responses set bit 7)
    Completer<ParsedFsPacket>? pending = _pendingFs.remove(packet.subCmd);
    if (pending == null) {
      pending = _pendingFs.remove(packet.subCmd & 0x7F);
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
    _pendingFs[subCmd] = completer;

    try {
      await _writePacket(frame);
    } catch (e) {
      _pendingFs.remove(subCmd);
      return null;
    }

    // Manual timeout — using completer.future.timeout would force
    // us to return a non-null value from onTimeout which collides
    // with our "no response" semantics.
    final timedOut = await completer.future
        .then<ParsedFsPacket?>((p) => p)
        .timeout(timeout, onTimeout: () => null)
        .catchError((_) => null as ParsedFsPacket?);
    if (timedOut == null) _pendingFs.remove(subCmd);
    return timedOut;
  }

  void _cancelAllPendingFs() {
    for (final c in _pendingFs.values) {
      if (!c.isCompleted) c.completeError(Exception('Disconnected'));
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

  void _handleConnectionLost(String reason) {
    _cancelAllPendingUpdates();
    _cancelAllPendingFs();
    _stopPolling();
    _connectionState = DeviceConnectionState.disconnected;
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
    _widgets          = [];
    _widgetState      = null;
    _description      = null;
    _deviceConfigJson = null;
    _errorMessage     = null;
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
