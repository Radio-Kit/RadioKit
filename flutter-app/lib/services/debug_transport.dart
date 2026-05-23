import 'dart:typed_data';
import 'transport_service.dart';
import '../models/debug_log_entry.dart';
import '../models/protocol.dart';
import 'protocol_service.dart';

/// Transparent [TransportService] decorator that logs every RX/TX packet
/// to a [DebugLogSink] without altering transport behaviour.
///
/// Usage:
///   final debug = DebugTransport(inner: realService, sink: debugProvider);
///   deviceProvider.setTransport(debug);
class DebugTransport implements TransportService {
  final TransportService _inner;
  final DebugLogSink sink;

  DebugTransport({required TransportService inner, required this.sink})
      : _inner = inner;

  TransportService get inner => _inner;

  @override
  Stream<String> get logStream => _inner.logStream;

  // ---------------------------------------------------------------------------
  // Delegate callbacks — intercept RX
  // ---------------------------------------------------------------------------

  @override
  set onPacketReceived(PacketReceivedCallback? cb) {
    _inner.onPacketReceived = cb == null
        ? null
        : (packet) {
            // Log before forwarding
            final entry = _makeEntry(
              direction: PacketDirection.rx,
              bytes: _rebuildFramedBytes(packet),
              crcOk: true, // ProtocolService only calls back on valid CRC
            );
            sink.addEntry(entry);
            cb(packet);
          };
  }

  @override
  PacketReceivedCallback? get onPacketReceived => _inner.onPacketReceived;

  @override
  set onConnectionLost(ConnectionLostCallback? cb) =>
      _inner.onConnectionLost = cb;

  @override
  ConnectionLostCallback? get onConnectionLost => _inner.onConnectionLost;

  // ---------------------------------------------------------------------------
  // Delegate core methods — intercept TX
  // ---------------------------------------------------------------------------

  @override
  bool get isConnected => _inner.isConnected;

  @override
  Future<void> connect(String deviceId, {int baudRate = 1000000}) =>
      _inner.connect(deviceId, baudRate: baudRate);

  @override
  Future<void> disconnect() => _inner.disconnect();

  @override
  Future<void> writePacket(Uint8List data) async {
    final entry = _makeEntry(
      direction: PacketDirection.tx,
      bytes: data,
      crcOk: _verifyCrc(data),
    );
    sink.addEntry(entry);
    await _inner.writePacket(data);
  }

  @override
  Future<void> dispose() => _inner.dispose();

  @override
  Future<int?> getRssi() => _inner.getRssi();

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Rebuild the full framed packet bytes from a [ParsedPacket] (RX path).
  /// Since ProtocolService already validated and stripped the frame, we
  /// rebuild it for display purposes.
  List<int> _rebuildFramedBytes(ParsedPacket packet) {
    final rebuilt = ProtocolService.buildPacket(packet.cmd, packet.payload);
    return rebuilt.toList();
  }

  DebugLogEntry _makeEntry({
    required PacketDirection direction,
    required List<int> bytes,
    bool? crcOk,
  }) {
    int? cmd;
    String cmdName = '?';
    String payloadHex = '';

    if (bytes.length >= 4) {
      cmd = bytes[3];
      cmdName = _cmdName(cmd);
    }
    if (bytes.length > 6) {
      final payloadBytes = bytes.sublist(4, bytes.length - 2);
      payloadHex = payloadBytes
          .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
          .join(' ');
    }

    final entry = DebugLogEntry(
      timestamp: DateTime.now(),
      direction: direction,
      bytes: bytes,
      cmdName: cmdName,
      payloadHex: payloadHex,
      crcOk: crcOk,
    );

    // We send a raw message to the sink if it supports it, 
    // but the current Sink interface only has addEntry.
    // The DebugProvider usually handles the translation to ConsoleProvider.
    
    return entry;
  }

  bool _verifyCrc(List<int> data) {
    final packet = ProtocolService.parsePacket(data);
    return packet != null;
  }

  String _cmdName(int cmd) {
    switch (cmd) {
      case kCmdGetConf:  return 'GET_CONF';
      case kCmdConfData: return 'CONF_DATA';
      case kCmdGetVars:  return 'GET_VARS';
      case kCmdVarData:  return 'VAR_DATA';
      case kCmdSetInput: return 'SET_INPUT';
      case kCmdPing:     return 'PING';
      case kCmdPong:     return 'PONG';
      case kCmdAck:      return 'ACK';
      case kCmdVarUpdate: return 'VAR_UPDATE';
      case kCmdGetMeta:   return 'GET_META';
      case kCmdMetaData:  return 'META_DATA';
      case kCmdMetaUpdate: return 'META_UPDATE';
      case kCmdGetTelemetry: return 'GET_TELEMETRY';
      case kCmdTelemetryData: return 'TELEMETRY_DATA';
      default: return '0x${cmd.toRadixString(16).padLeft(2, '0').toUpperCase()}';
    }
  }
}

/// Interface implemented by [DebugProvider] so that [DebugTransport]
/// has no dependency on the provider layer.
abstract class DebugLogSink {
  void addEntry(DebugLogEntry entry);
}
