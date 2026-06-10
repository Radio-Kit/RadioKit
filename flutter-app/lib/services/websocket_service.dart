import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/protocol.dart';
import 'protocol_service.dart';
import 'transport_service.dart';

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

  @override
  Future<void> connect(String url, {int baudRate = 1000000}) async {
    _log('Connecting to $url...');

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

      // Send cloud join message if account is set and URL is secure
      if (account != null && url.startsWith('wss://')) {
        _sendJson({
          'type': 'join',
          'device': _deviceIdFromUrl(url),
          'account': account,
        });
      }

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
    } catch (e) {
      _log('Connection failed: $e', level: 'error');
      _connected = false;
      rethrow;
    }
  }

  /// Extract device identifier from a cloud relay URL.
  /// URL format: "wss://relay.host/RK_AA:BB:CC:DD:EE:FF"
  String _deviceIdFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final path = uri.pathSegments;
      if (path.isNotEmpty) return path.last;
    } catch (_) {}
    return url;
  }

  /// Send a JSON control message (cloud relay only).
  void _sendJson(Map<String, dynamic> data) {
    final msg = jsonEncode(data);
    _log('Sending JSON: $msg');
    _channel?.sink.add(msg);
  }

  /// Handle an incoming WebSocket message.
  void _onMessage(dynamic data) {
    if (data is String) {
      // JSON control message (cloud relay)
      _handleControlMessage(data);
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
      default:
        _log('Unknown protocol type byte: 0x${typeByte.toRadixString(16)}', level: 'warn');
    }
  }

  /// Handle a JSON text control message (cloud relay protocol).
  void _handleControlMessage(String text) {
    try {
      final msg = jsonDecode(text) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'joined':
          final ok = msg['ok'] as bool? ?? false;
          if (ok) {
            _log('Cloud join succeeded: ${msg['device']}');
          } else {
            _log('Cloud join failed: ${msg['error']}', level: 'error');
          }
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
    // WebSocket doesn't have RSSI — return null
    return null;
  }

  @override
  Future<void> disconnect() async {
    _log('Disconnecting...');
    _connected = false;
    await _subscription?.cancel();
    _subscription = null;
    await _channel?.sink.close();
    _channel = null;
    _widgetBuffer.clear();
    _fsBuffer.clear();
    _otaBuffer.clear();
    _settingsBuffer.clear();
  }

  void _handleDisconnect(String reason) {
    _connected = false;
    _widgetBuffer.clear();
    _fsBuffer.clear();
    _otaBuffer.clear();
    _settingsBuffer.clear();
    onConnectionLost?.call(reason);
  }

  @override
  Future<void> dispose() async {
    await disconnect();
    await _logController.close();
  }
}
