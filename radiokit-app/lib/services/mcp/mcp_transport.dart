import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:shelf/shelf.dart';

/// Manages active SSE client sessions and message routing for the MCP server.
class McpSseSession {
  final String sessionId;
  final StreamController<List<int>> _streamController = StreamController<List<int>>();
  final DateTime createdAt = DateTime.now();
  Timer? _keepAliveTimer;

  Stream<List<int>> get stream => _streamController.stream;
  bool get isClosed => _streamController.isClosed;

  McpSseSession({
    required this.sessionId,
    void Function(McpSseSession session)? onStart,
    void Function(McpSseSession session)? onClose,
  }) {
    _streamController.onListen = () {
      if (onStart != null) {
        onStart(this);
      }
      // Send keep-alive ping comments every 15 seconds to prevent network timeout
      _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (!_streamController.isClosed) {
          _sendComment('ping');
        }
      });
    };

    _streamController.onCancel = () {
      close();
      if (onClose != null) {
        onClose(this);
      }
    };
  }

  void _sendComment(String comment) {
    if (_streamController.isClosed) return;
    try {
      _streamController.add(utf8.encode(': $comment\n\n'));
    } catch (_) {}
  }

  /// Send an SSE event (e.g. "endpoint" or "message")
  void sendEvent({required String event, required String data}) {
    if (_streamController.isClosed) return;
    try {
      final payload = 'event: $event\ndata: $data\n\n';
      _streamController.add(utf8.encode(payload));
    } catch (_) {}
  }

  /// Close session and clean up resources
  void close() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    if (!_streamController.isClosed) {
      _streamController.close();
    }
  }
}

class McpTransport {
  final Map<String, McpSseSession> _sessions = {};
  final Random _random = Random.secure();

  /// Handle GET /sse connection request
  Response handleSseConnect(Request request) {
    final sessionId = _generateSessionId();
    final session = McpSseSession(
      sessionId: sessionId,
      onStart: (s) {
        // Notify client of endpoint for JSON-RPC messages per MCP spec
        s.sendEvent(
          event: 'endpoint',
          data: '/messages?sessionId=$sessionId',
        );
      },
      onClose: (s) {
        _sessions.remove(sessionId);
      },
    );
    _sessions[sessionId] = session;

    return Response.ok(
      session.stream,
      headers: {
        'Content-Type': 'text/event-stream; charset=utf-8',
        'Cache-Control': 'no-cache, no-transform',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': '*',
      },
      context: {
        'shelf.io.buffer_output': false,
      },
    );
  }

  /// Retrieve active session by ID
  McpSseSession? getSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session != null && session.isClosed) {
      _sessions.remove(sessionId);
      return null;
    }
    return session;
  }

  /// Broadcast an event to all connected sessions
  void broadcastEvent({required String event, required String data}) {
    final closedIds = <String>[];
    for (final entry in _sessions.entries) {
      if (entry.value.isClosed) {
        closedIds.add(entry.key);
      } else {
        entry.value.sendEvent(event: event, data: data);
      }
    }
    for (final id in closedIds) {
      _sessions.remove(id);
    }
  }

  /// Close all active sessions
  void closeAll() {
    for (final session in _sessions.values) {
      session.close();
    }
    _sessions.clear();
  }

  String _generateSessionId() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
