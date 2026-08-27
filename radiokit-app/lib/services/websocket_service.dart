import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/protocol.dart';
import 'protocol_service.dart';
import 'transport_service.dart';
import 'settings_protocol_service.dart';
import 'cloud_identity.dart';


/// WebSocket transport service for both local WiFi (`ws://`) and cloud relay
/// (`wss://`) connections.
///
/// ### Type-byte protocol
///
/// Each binary WebSocket message is prefixed with a 1-byte protocol type:
///
///   [TYPE(1)][FRAME_BYTES...]
///
/// | Type | Protocol  |
/// |------|-----------|
/// | 0x55 | Widget    |
/// | 0xAA | Filesystem|
/// | 0xBB | OTA       |
/// | 0xDD | Settings  |
///
/// Text messages are JSON control messages used by the cloud relay.
class WebSocketService implements TransportService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  bool _connected = false;

  // Per-protocol receive buffers
  final List<int> _widgetBuffer = [];
  final List<int> _fsBuffer = [];
  final List<int> _otaBuffer = [];
  final List<int> _settingsBuffer = [];
  final List<int> _printBuffer = [];

  final _logController = StreamController<String>.broadcast();
  @override
  Stream<String> get logStream => _logController.stream;

  void _log(String msg, {String level = 'info'}) {
    final prefix = level == 'error' ? 'ERR' : level == 'warn' ? 'WRN' : 'INF';
    debugPrint('WS_SERVICE [$prefix]: $msg');
    _logController.add('[$prefix] $msg');
  }

  @override
  PacketReceivedCallback? onPacketReceived;
  @override
  FsPacketReceivedCallback? onFsPacketReceived;
  @override
  OtaPacketReceivedCallback? onOtaPacketReceived;
  @override
  SettingsPacketReceivedCallback? onSettingsPacketReceived;
  @override
  ConnectionLostCallback? onConnectionLost;

  @override
  bool get isConnected => _connected;

  /// Optional: account identifier for cloud relay join flow.
  String? account;

  /// Ed25519 identity for challenge-response auth with the relay.
  CloudIdentityService? identity;

  /// Callback fired when the relay returns a device list for the account.
  void Function(List<String> devices)? onDeviceList;

  /// Callback fired when a cloud join succeeds.
  void Function(String deviceName)? onCloudJoined;

  /// Callback fired when challenge-response auth succeeds.
  VoidCallback? onAuthSuccess;

  /// Callback fired when auth_ok includes the device list, providing the
  /// registered device names so the caller doesn't need a separate
  /// list_devices request.
  void Function(List<String> devices)? onAuthOkDevices;

  /// Callback fired when auth fails.
  void Function(String error)? onAuthFailed;



  /// Pending device name to join after relay auth completes.
  String? _pendingJoinDevice;

  @override
  Future<void> connect(String url, {int baudRate = 1000000}) async {
    _log('Connecting to $url...');

    // If already connected (e.g., re-using an authenticated relay session),
    // just send the appropriate message through the existing connection.
    if (_connected) {
      final uri = Uri.parse(url);
      final hasPath = uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty;
      if (hasPath && account != null && account!.isNotEmpty) {
        _log('Already connected — sending join for ${uri.pathSegments.last}');
        _sendJson({
          'type': 'join',
          'device': uri.pathSegments.last,
          'account': account,
        });
      }
      return;
    }

    _pendingJoinDevice = null;

    try {
      final uri = Uri.parse(url);
      _channel = WebSocketChannel.connect(uri);

      // Wait for the connection to complete
      await _channel!.ready;
      _connected = true;
      _log('Connected to $url');

      // Clear buffers
      _widgetBuffer.clear();
      _fsBuffer.clear();
      _otaBuffer.clear();
      _settingsBuffer.clear();

      // Set up stream listener first so we can receive messages
      _subscription = _channel!.stream.listen(
        _onMessage,
        onError: (error) {
          _log('WebSocket error: $error', level: 'error');
          _handleDisconnect('WebSocket error: $error');
        },
        onDone: () {
          _log('WebSocket closed');
          _handleDisconnect('WebSocket connection closed');
        },
        cancelOnError: false,
      );

      // Determine connection type and send appropriate message
      final hasPath = uri.pathSegments.isNotEmpty && uri.pathSegments.last.isNotEmpty;
      final isRelay = identity != null && account != null && account!.isNotEmpty;

      if (isRelay) {
        // Cloud relay — always authenticate first, join after auth_ok
        if (hasPath) {
          _pendingJoinDevice = uri.pathSegments.last;
        }
        _sendJson({'type': 'auth_request', 'account': account});
      } else if (hasPath && account != null && account!.isNotEmpty) {
        // Direct WiFi device — join immediately (no relay auth needed)
        _sendJson({
          'type': 'join',
          'device': uri.pathSegments.last,
          'account': account,
        });
      }
    } catch (e) {
      _log('Connection failed: $e', level: 'error');
      _connected = false;
      rethrow;
    }
  }

  /// Send a JSON control message (cloud relay only).
  void _sendJson(Map<String, dynamic> data) {
    final msg = jsonEncode(data);
    _log('Sending JSON: $msg');
    _channel?.sink.add(msg);
  }

  /// Ask the relay for devices registered under this account.
  void sendListDevices() {
    if (account == null || account!.isEmpty) return;
    _sendJson({
      'type': 'list_devices',
      'account': account,
    });
  }

  /// Join a specific device on the relay.
  /// Call this after the user selects a device from the list.
  void sendJoinForDevice(String deviceName) {
    if (account == null || account!.isEmpty) return;
    _sendJson({
      'type': 'join',
      'device': deviceName,
      'account': account,
    });
  }

  /// Handle an incoming WebSocket message.
  Future<void> _onMessage(dynamic data) async {
    if (data is String) {
      // JSON control message (cloud relay) — may need async for signing
      await _handleControlMessage(data);
    } else if (data is List<int>) {
      // Binary = type-byte-prefixed RadioKit frame
      _handleBinaryFrame(Uint8List.fromList(data));
    } else if (data is Uint8List) {
      _handleBinaryFrame(data);
    }
  }

  /// Handle a binary WebSocket message with type-byte prefix.
  void _handleBinaryFrame(Uint8List data) {
    if (data.isEmpty) return;
    final typeByte = data[0];
    final frameData = data.sublist(1);

    switch (typeByte) {
      case kStartByte:
        _widgetBuffer.addAll(frameData);
        _processWidgetBuffer();
        break;
      case kFsStartByte:
        _fsBuffer.addAll(frameData);
        _processFsBuffer();
        break;
      case kOtaStartByte:
        _otaBuffer.addAll(frameData);
        _processOtaBuffer();
        break;
      case kSettingsStartByte:
        _settingsBuffer.addAll(frameData);
        _processSettingsBuffer();
        break;
      case kPrintStartByte:
        _printBuffer.addAll(frameData);
        _processPrintBuffer();
        break;
      default:
        _log('Unknown protocol type byte: 0x${typeByte.toRadixString(16)}', level: 'warn');
    }
  }

  /// Handle a JSON text control message (cloud relay protocol).
  Future<void> _handleControlMessage(String text) async {
    try {
      final msg = jsonDecode(text) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'auth_challenge':
          await _handleAuthChallenge(msg);
          break;
        case 'auth_ok':
          _log('Relay auth succeeded');
          // Extract device list from auth_ok (relay now sends it inline)
          final devices = (msg['devices'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList();
          _log('Devices registered: $devices');
          onAuthOkDevices?.call(devices);
          // If we have a pending device join, send it now
          if (_pendingJoinDevice != null) {
            _log('Sending pending join for $_pendingJoinDevice');
            _sendJson({
              'type': 'join',
              'device': _pendingJoinDevice,
              'account': account,
            });
            _pendingJoinDevice = null;
          }
          onAuthSuccess?.call();
          break;
        case 'auth_failed':
          final error = msg['error'] as String? ?? 'unknown error';
          _log('Relay auth failed: $error', level: 'error');
          _pendingJoinDevice = null;
          onAuthFailed?.call(error);
          break;
        case 'joined':
          final ok = msg['ok'] as bool? ?? false;
          if (ok) {
            final deviceName = msg['device'] as String? ?? '';
            _log('Cloud join succeeded: $deviceName');
            onCloudJoined?.call(deviceName);
          } else {
            _log('Cloud join failed: ${msg['error']}', level: 'error');
          }
          break;
        case 'device_list':
          final devices = (msg['devices'] as List<dynamic>? ?? [])
              .map((e) => e as String)
              .toList();
          _log('Received device list: $devices');
          onDeviceList?.call(devices);
          break;
        case 'pong':
          _log('Pong received');
          break;
        case 'device_status':
          final status = msg['status'] as String?;
          _log('Device status: $status');
          break;
        case 'client_joined':
          _log('Client joined: ${msg['account']}');
          break;
        case 'error':
          _log('Relay error: ${msg['code']} — ${msg['message']}', level: 'error');
          break;
        default:
          _log('Unknown control message: $type', level: 'warn');
      }
    } catch (e) {
      _log('Failed to parse control message: $e', level: 'error');
    }
  }

  /// Handle an Ed25519 auth challenge from the relay.
  ///
  /// Signs the 32-byte nonce with the private key and sends the response.
  Future<void> _handleAuthChallenge(Map<String, dynamic> msg) async {
    if (identity == null) {
      _log('Auth challenge received but no identity configured', level: 'error');
      return;
    }

    final nonceB64 = msg['nonce'] as String?;
    if (nonceB64 == null || nonceB64.isEmpty) {
      _log('Auth challenge missing nonce', level: 'error');
      return;
    }

    try {
      final nonce = base64Decode(nonceB64);
      final signature = await identity!.sign(nonce);
      final sigB64 = base64Encode(signature);

      _sendJson({
        'type': 'auth_response',
        'signature': sigB64,
        'account': account,
      });
      _log('Auth response sent');
    } catch (e) {
      _log('Failed to sign auth challenge: $e', level: 'error');
      onAuthFailed?.call('Signing failed: $e');
    }
  }

  // ── Per-protocol buffer processing ─────────────────────────────────────

  void _processWidgetBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_widgetBuffer);
      if (drained == null) break;
      if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processFsBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_fsBuffer);
      if (drained == null) break;
      if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processOtaBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_otaBuffer);
      if (drained == null) break;
      if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      } else if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      }
    }
  }

  void _processPrintBuffer() {
    // 0xEE print frames: [START(1)][LEN_LO(1)][LEN_HI(1)][PAYLOAD...]
    // Forward the raw payload via the settings callback with kPrintStartByte marker
    while (_printBuffer.length >= 3) {
      if (_printBuffer[0] != kPrintStartByte) {
        _printBuffer.removeAt(0);
        continue;
      }
      final length = _printBuffer[1] | (_printBuffer[2] << 8);
      if (length < 3 || length > 0x100) {
        _printBuffer.removeAt(0);
        continue;
      }
      if (_printBuffer.length < length) break;
      final payload = Uint8List.fromList(_printBuffer.sublist(3, length));
      _printBuffer.removeRange(0, length);
      onSettingsPacketReceived?.call(
        ParsedSettingsPacket(subCmd: kPrintStartByte, payload: payload),
      );
    }
  }

  void _processSettingsBuffer() {
    while (true) {
      final drained = ProtocolService.drainBuffer(_settingsBuffer);
      if (drained == null) break;
      if (drained.kind == 'settings') {
        onSettingsPacketReceived?.call(drained.settingsPacket!);
      } else if (drained.kind == 'widget') {
        onPacketReceived?.call(drained.widgetPacket!);
      } else if (drained.kind == 'fs') {
        onFsPacketReceived?.call(drained.fsPacket!);
      } else if (drained.kind == 'ota') {
        onOtaPacketReceived?.call(drained.otaPacket!);
      }
    }
  }

  // ── Write / Disconnect ────────────────────────────────────────────────

  @override
  Future<void> writePacket(Uint8List data) async {
    if (!_connected || _channel == null) {
      throw StateError('Not connected');
    }

    // Build type-byte-prefixed message
    final framed = Uint8List(1 + data.length);
    if (data.isNotEmpty) {
      if (data[0] == kFsStartByte) {
        framed[0] = kFsStartByte;
      } else if (data[0] == kOtaStartByte) {
        framed[0] = kOtaStartByte;
      } else if (data[0] == kSettingsStartByte) {
        framed[0] = kSettingsStartByte;
      } else if (data[0] == kPrintStartByte) {
        framed[0] = kPrintStartByte;
      } else {
        framed[0] = kStartByte;
      }
    } else {
      framed[0] = kStartByte;
    }
    framed.setRange(1, 1 + data.length, data);

    try {
      _channel!.sink.add(framed);
    } catch (e) {
      _log('Write failed: $e', level: 'error');
      rethrow;
    }
  }

  @override
  Future<int?> getRssi() async {
    return null;
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _pendingJoinDevice = null;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _widgetBuffer.clear();
    _fsBuffer.clear();
    _otaBuffer.clear();
    _settingsBuffer.clear();
    _printBuffer.clear();
  }

  void _handleDisconnect(String reason) {
    _connected = false;
    _pendingJoinDevice = null;
    _widgetBuffer.clear();
    _fsBuffer.clear();
    _otaBuffer.clear();
    _settingsBuffer.clear();
    _printBuffer.clear();
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _logController.close();
  }
}
