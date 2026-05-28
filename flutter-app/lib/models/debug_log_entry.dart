import 'package:flutter/foundation.dart';

/// Direction of a logged packet.
enum PacketDirection { mcu, app }

/// A single entry in the debug packet log.
@immutable
class DebugLogEntry {
  final DateTime timestamp;
  final PacketDirection direction;

  /// Raw packet bytes (full framed packet including START + LENGTH + CRC).
  final List<int> bytes;

  /// Human-readable command name decoded from cmd byte.
  final String cmdName;

  /// Hex string of the payload only (no header/CRC).
  final String payloadHex;

  /// Whether the CRC check passed (true = valid, false = invalid, null = unknown).
  final bool? crcOk;

  const DebugLogEntry({
    required this.timestamp,
    required this.direction,
    required this.bytes,
    required this.cmdName,
    required this.payloadHex,
    this.crcOk,
  });

  /// Full packet as an uppercase hex string, space-separated bytes.
  String get hexDump =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ');

  /// Printable ASCII representation (dots for non-printable).
  String get asciiDump => bytes
      .map((b) => (b >= 0x20 && b < 0x7F) ? String.fromCharCode(b) : '.')
      .join();

  String get dirLabel => direction == PacketDirection.app ? 'APP' : 'MCU';

  String get timeLabel {
    final t = timestamp;
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    final s = t.second.toString().padLeft(2, '0');
    final ms = t.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }
}
