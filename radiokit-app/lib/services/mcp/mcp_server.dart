import 'dart:async';
import 'dart:convert';
import 'package:shelf/shelf.dart';

import 'mcp_protocol.dart';
import 'mcp_transport.dart';

typedef McpToolHook = void Function(String toolName, Map<String, dynamic> arguments);

/// Core MCP Server implementing JSON-RPC 2.0 protocol over HTTP/SSE.
class McpServer {
  final String serverName;
  final String serverVersion;
  final McpTransport transport = McpTransport();

  final Map<String, McpTool> _tools = {};
  final Map<String, McpResource> _resources = {};
  final Set<String> _subscribedResources = {};

  List<McpTool> get tools => _tools.values.toList();
  List<McpResource> get resources => _resources.values.toList();
  McpTool? getTool(String name) => _tools[name];
  McpResource? getResource(String uri) => _resources[uri];

  McpToolHook? onToolInvoked;

  McpServer({
    this.serverName = 'radiokit-app',
    this.serverVersion = '2.2.0',
    this.onToolInvoked,
  });

  /// Register an MCP tool
  void registerTool(McpTool tool) {
    _tools[tool.name] = tool;
  }

  /// Register an MCP resource
  void registerResource(McpResource resource) {
    _resources[resource.uri] = resource;
  }

  /// Broadcast a notification that a resource has updated
  void notifyResourceUpdated(String uri) {
    final notification = {
      'jsonrpc': '2.0',
      'method': 'notifications/resources/updated',
      'params': {
        'uri': uri,
      },
    };
    transport.broadcastEvent(
      event: 'message',
      data: jsonEncode(notification),
    );
  }

  /// Push an asynchronous progress notification
  void notifyProgress({
    required String progressToken,
    required double progress,
    double? total,
  }) {
    final notification = {
      'jsonrpc': '2.0',
      'method': 'notifications/progress',
      'params': {
        'progressToken': progressToken,
        'progress': progress,
        if (total != null) 'total': total,
      },
    };
    transport.broadcastEvent(
      event: 'message',
      data: jsonEncode(notification),
    );
  }

  /// Handle incoming JSON-RPC POST /messages request
  Future<Response> handleMessages(Request request) async {
    final sessionId = request.url.queryParameters['sessionId'];
    if (sessionId == null || sessionId.isEmpty) {
      return Response(400, body: 'Missing sessionId query parameter');
    }

    final session = transport.getSession(sessionId);
    if (session == null) {
      return Response(404, body: 'Session not found or expired');
    }

    String bodyStr;
    try {
      bodyStr = await request.readAsString();
    } catch (e) {
      return Response(400, body: 'Failed to read request body');
    }

    dynamic rawJson;
    try {
      rawJson = jsonDecode(bodyStr);
    } catch (e) {
      final errorResponse = _formatError(null, McpErrorCodes.parseError, 'Parse error: Invalid JSON');
      session.sendEvent(event: 'message', data: jsonEncode(errorResponse));
      return Response.ok('{"ok": true}', headers: {'Content-Type': 'application/json'});
    }

    // Process single message or batch
    if (rawJson is List) {
      for (final msg in rawJson) {
        if (msg is Map<String, dynamic>) {
          await _processMessage(session, msg);
        }
      }
    } else if (rawJson is Map<String, dynamic>) {
      await _processMessage(session, rawJson);
    } else {
      final errorResponse = _formatError(null, McpErrorCodes.invalidRequest, 'Invalid Request');
      session.sendEvent(event: 'message', data: jsonEncode(errorResponse));
    }

    // Return 200/202 to the HTTP POST per MCP specification
    return Response.ok(
      '{"status": "accepted"}',
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
      },
    );
  }

  Future<void> _processMessage(McpSseSession session, Map<String, dynamic> msg) async {
    final id = msg['id'];
    final method = msg['method'] as String?;
    final params = (msg['params'] as Map<String, dynamic>?) ?? {};

    // Notifications do not have an ID and do not return a response
    if (id == null) {
      _handleNotification(method, params);
      return;
    }

    if (method == null) {
      final resp = _formatError(id, McpErrorCodes.invalidRequest, 'Missing method in request');
      session.sendEvent(event: 'message', data: jsonEncode(resp));
      return;
    }

    try {
      final result = await _dispatchMethod(method, params);
      final successResponse = {
        'jsonrpc': '2.0',
        'id': id,
        'result': result,
      };
      session.sendEvent(event: 'message', data: jsonEncode(successResponse));
    } catch (e, stack) {
      print('Error dispatching MCP method $method: $e\n$stack');
      final errorResponse = _formatError(id, McpErrorCodes.internalError, e.toString());
      session.sendEvent(event: 'message', data: jsonEncode(errorResponse));
    }
  }

  void _handleNotification(String? method, Map<String, dynamic> params) {
    if (method == 'notifications/initialized') {
      print('MCP Client confirmed initialized');
    }
  }

  Future<Map<String, dynamic>> _dispatchMethod(String method, Map<String, dynamic> params) async {
    switch (method) {
      case 'initialize':
        return {
          'protocolVersion': '2024-11-05',
          'serverInfo': {
            'name': serverName,
            'version': serverVersion,
          },
          'capabilities': {
            'tools': {
              'listChanged': true,
            },
            'resources': {
              'subscribe': true,
              'listChanged': true,
            },
            'logging': {},
          },
        };

      case 'ping':
        return {};

      case 'tools/list':
        return {
          'tools': _tools.values.map((t) => t.toJson()).toList(),
        };

      case 'tools/call':
        final toolName = params['name'] as String?;
        final arguments = (params['arguments'] as Map<String, dynamic>?) ?? {};

        if (toolName == null || !_tools.containsKey(toolName)) {
          throw Exception('Tool not found: $toolName');
        }

        onToolInvoked?.call(toolName, arguments);

        final tool = _tools[toolName]!;
        return await tool.handler(arguments);

      case 'resources/list':
        return {
          'resources': _resources.values.map((r) => r.toJson()).toList(),
        };

      case 'resources/read':
        final uri = params['uri'] as String?;
        if (uri == null) {
          throw Exception('Missing uri parameter in resources/read');
        }

        // Exact match or template match
        McpResource? targetResource = _resources[uri];
        if (targetResource == null) {
          // Check prefix matches for dynamic resources
          for (final r in _resources.values) {
            if (uri.startsWith(r.uri.replaceAll('*', ''))) {
              targetResource = r;
              break;
            }
          }
        }

        if (targetResource == null) {
          throw Exception('Resource not found: $uri');
        }

        final content = await targetResource.readHandler();
        return {
          'contents': [
            {
              'uri': uri,
              'mimeType': targetResource.mimeType,
              'text': content,
            }
          ],
        };

      case 'resources/subscribe':
        final uri = params['uri'] as String?;
        if (uri != null) {
          _subscribedResources.add(uri);
        }
        return {};

      case 'resources/unsubscribe':
        final uri = params['uri'] as String?;
        if (uri != null) {
          _subscribedResources.remove(uri);
        }
        return {};

      default:
        throw Exception('Method not found: $method');
    }
  }

  Map<String, dynamic> _formatError(dynamic id, int code, String message) {
    return {
      'jsonrpc': '2.0',
      if (id != null) 'id': id,
      'error': {
        'code': code,
        'message': message,
      },
    };
  }

  void dispose() {
    transport.closeAll();
  }
}
