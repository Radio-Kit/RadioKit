import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/debug_log_entry.dart';
import '../services/debug_transport.dart';
import '../services/transport_service.dart';
import '../services/protocol_service.dart';
import '../services/settings_protocol_service.dart';

/// Maximum number of entries kept in the ring-buffer.
const int kDebugLogMaxEntries = 1000;

/// Manages the debug packet log.
///
/// Acts as a [DebugLogSink] for [DebugTransport] and exposes the filtered
/// log to the UI via [ChangeNotifier].
class DebugProvider extends ChangeNotifier implements DebugLogSink {
  final List<DebugLogEntry> _all = [];

  bool _paused = false;
  bool _autoScroll = true;
  String _searchTerm = '';
  PacketDirection? _dirFilter; // null = show both
  bool _debugMode = false;
  int _totalTransferred = 0;

  // The raw transport used when sending manual packets
  TransportService? _transport;

  bool get paused     => _paused;
  bool get autoScroll => _autoScroll;
  String get searchTerm  => _searchTerm;
  PacketDirection? get dirFilter => _dirFilter;
  bool get debugMode => _debugMode;
  TransportService? get transport => _transport;
  int get totalTransferred => _totalTransferred;

  /// Attach (or replace) the transport so the Send panel can write packets.
  void attachTransport(TransportService t) {
    _transport = t;
  }

  // ---------------------------------------------------------------------------
  // DebugLogSink
  // ---------------------------------------------------------------------------

  @override
  void addEntry(DebugLogEntry entry) {
    if (_paused) return;
    _totalTransferred++;
    if (_all.length >= kDebugLogMaxEntries) _all.removeAt(0);
    _all.add(entry);
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Filtered view
  // ---------------------------------------------------------------------------

  List<DebugLogEntry> get entries {
    var list = _all.toList();

    if (_dirFilter != null) {
      list = list.where((e) => e.direction == _dirFilter).toList();
    }

    if (_searchTerm.isNotEmpty) {
      final term = _searchTerm.toLowerCase();
      list = list.where((e) =>
          e.cmdName.toLowerCase().contains(term) ||
          e.hexDump.toLowerCase().contains(term) ||
          e.payloadHex.toLowerCase().contains(term)).toList();
    }

    return list;
  }

  int get totalCount => _all.length;

  // ---------------------------------------------------------------------------
  // Controls
  // ---------------------------------------------------------------------------

  void togglePause() {
    _paused = !_paused;
    notifyListeners();
  }

  void toggleAutoScroll() {
    _autoScroll = !_autoScroll;
    notifyListeners();
  }

  void clearLog() {
    _all.clear();
    _totalTransferred = 0;
    notifyListeners();
  }

  void setSearchTerm(String term) {
    _searchTerm = term;
    notifyListeners();
  }

  void setDirFilter(PacketDirection? dir) {
    _dirFilter = dir;
    notifyListeners();
  }

  void toggleDebugMode() {
    _debugMode = !_debugMode;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Manual APP (send packet)
  // ---------------------------------------------------------------------------

  /// Send a manually constructed packet: [cmd] byte + [payloadHex] hex string.
  /// Returns an error string on failure, or null on success.
  Future<String?> sendManual(int cmd, String payloadHex) async {
    final t = _transport;
    if (t == null || !t.isConnected) return 'Not connected';

    List<int> payload = [];
    if (payloadHex.trim().isNotEmpty) {
      final hex = payloadHex.replaceAll(RegExp(r'\s+'), '');
      if (hex.length.isOdd) return 'Odd hex length';
      try {
        for (int i = 0; i < hex.length; i += 2) {
          payload.add(int.parse(hex.substring(i, i + 2), radix: 16));
        }
      } catch (_) {
        return 'Invalid hex';
      }
    }

    try {
      final packet = ProtocolService.buildPacket(cmd, payload);
      await t.writePacket(packet);
      return null;
    } catch (e) {
      return 'Send failed: $e';
    }
  }

  /// Quick-send a named command.
  Future<String?> sendQuick(String name) async {
    final t = _transport;
    if (t == null || !t.isConnected) return 'Not connected';
    try {
      switch (name) {
        // PING removed; connection health is transport-driven.
        case 'GET_CONF': await t.writePacket(ProtocolService.buildGetConf());  break;
        case 'GET_VARS': await t.writePacket(ProtocolService.buildGetVars());  break;
        case 'GET_META': await t.writePacket(ProtocolService.buildGetMeta());  break;
        case 'GET_TELE': await t.writePacket(SettingsProtocolService.buildGetTelemetry(0)); break;
        default: return 'Unknown command';
      }
      return null;
    } catch (e) {
      return 'Send failed: $e';
    }
  }

  // ---------------------------------------------------------------------------
  // Export as CSV text
  // ---------------------------------------------------------------------------

  String exportCsv() {
    final buf = StringBuffer();
    buf.writeln('time,dir,cmd,bytes,payload_hex,crc_ok');
    for (final e in _all) {
      final crc = e.crcOk == null ? '' : (e.crcOk! ? 'ok' : 'fail');
      buf.writeln('${e.timeLabel},${e.dirLabel},${e.cmdName},'
          '${e.bytes.length},"${e.payloadHex}",$crc');
    }
    return buf.toString();
  }
}
