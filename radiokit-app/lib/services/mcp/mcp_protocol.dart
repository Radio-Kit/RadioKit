import 'dart:async';

/// JSON-RPC 2.0 Error Codes as defined by JSON-RPC and MCP specifications.
class McpErrorCodes {
  static const int parseError = -32700;
  static const int invalidRequest = -32600;
  static const int methodNotFound = -32601;
  static const int invalidParams = -32602;
  static const int internalError = -32603;
}

class McpError {
  final int code;
  final String message;
  final dynamic data;

  McpError({required this.code, required this.message, this.data});

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
        if (data != null) 'data': data,
      };
}

/// A registered MCP Tool definition.
class McpTool {
  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> arguments) handler;

  McpTool({
    required this.name,
    required this.description,
    required this.inputSchema,
    required this.handler,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'inputSchema': inputSchema,
      };
}

/// A registered MCP Resource definition.
class McpResource {
  final String uri;
  final String name;
  final String description;
  final String mimeType;
  final Future<String> Function() readHandler;

  McpResource({
    required this.uri,
    required this.name,
    required this.description,
    this.mimeType = 'text/plain',
    required this.readHandler,
  });

  Map<String, dynamic> toJson() => {
        'uri': uri,
        'name': name,
        'description': description,
        'mimeType': mimeType,
      };
}

/// Helper to wrap tool execution results into standard MCP tool response format.
Map<String, dynamic> mcpToolSuccess(dynamic content, {bool isError = false}) {
  String text;
  if (content is String) {
    text = content;
  } else {
    text = content.toString();
  }
  return {
    'content': [
      {
        'type': 'text',
        'text': text,
      }
    ],
    if (isError) 'isError': true,
  };
}

Map<String, dynamic> mcpToolError(String message) {
  return mcpToolSuccess(message, isError: true);
}
