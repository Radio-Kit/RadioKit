import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import '../lib/services/mcp/mcp_protocol.dart';
import '../lib/services/mcp/mcp_server.dart';

void main() {
  test('MCP server protocol handshake, tool invocation, and resources', () async {
    print('=== Testing MCP Server Protocol ===');

  final server = McpServer(serverName: 'test-server', serverVersion: '1.0.0');

  // Register dummy tool
  server.registerTool(McpTool(
    name: 'test_echo',
    description: 'Echoes back argument',
    inputSchema: {
      'type': 'object',
      'properties': {
        'message': {'type': 'string'},
      },
      'required': ['message'],
    },
    handler: (args) async {
      return mcpToolSuccess('Echo: ${args['message']}');
    },
  ));

  // Register dummy resource
  server.registerResource(McpResource(
    uri: 'test://status',
    name: 'Status Resource',
    description: 'System status',
    readHandler: () async => 'All systems nominal',
  ));

  // 1. Test SSE connect
  final sseReq = Request('GET', Uri.parse('http://localhost:7007/sse'));
  final sseResp = server.transport.handleSseConnect(sseReq);
  assert(sseResp.statusCode == 200, 'SSE connect should return 200');
  assert(sseResp.headers['Content-Type']!.contains('text/event-stream'), 'SSE content-type header missing');
  print('✓ SSE Connect successful');

  // Listen to SSE stream to get session ID
  final sseEvents = <String>[];
  final sub = sseResp.read().transform(utf8.decoder).listen((event) {
    sseEvents.add(event);
  });

  await Future.delayed(const Duration(milliseconds: 50));
  assert(sseEvents.isNotEmpty, 'Expected at least endpoint event');
  final endpointLine = sseEvents.first;
  print('Received endpoint event: $endpointLine');

  final match = RegExp(r'sessionId=([a-f0-9]+)').firstMatch(endpointLine);
  assert(match != null, 'Could not find sessionId in endpoint event');
  final sessionId = match!.group(1)!;
  print('✓ Session ID extracted: $sessionId');

  // 2. Test initialize
  final initMsg = {
    'jsonrpc': '2.0',
    'id': 1,
    'method': 'initialize',
    'params': {
      'protocolVersion': '2024-11-05',
      'clientInfo': {'name': 'test-client', 'version': '1.0.0'},
    },
  };

  final initReq = Request(
    'POST',
    Uri.parse('http://localhost:7007/messages?sessionId=$sessionId'),
    body: jsonEncode(initMsg),
  );

  final initResp = await server.handleMessages(initReq);
  assert(initResp.statusCode == 200, 'handleMessages should return 200');
  await Future.delayed(const Duration(milliseconds: 50));

  final initEvent = sseEvents.lastWhere((e) => e.contains('"id":1'));
  assert(initEvent.contains('"name":"test-server"'), 'Expected serverName in init response');
  print('✓ Initialize RPC successful');

  // 3. Test tools/list
  final toolsMsg = {
    'jsonrpc': '2.0',
    'id': 2,
    'method': 'tools/list',
    'params': {},
  };
  await server.handleMessages(Request(
    'POST',
    Uri.parse('http://localhost:7007/messages?sessionId=$sessionId'),
    body: jsonEncode(toolsMsg),
  ));
  await Future.delayed(const Duration(milliseconds: 50));

  final toolsEvent = sseEvents.lastWhere((e) => e.contains('"id":2'));
  assert(toolsEvent.contains('test_echo'), 'Expected test_echo in tools/list response');
  print('✓ tools/list RPC successful');

  // 4. Test tools/call
  final callMsg = {
    'jsonrpc': '2.0',
    'id': 3,
    'method': 'tools/call',
    'params': {
      'name': 'test_echo',
      'arguments': {'message': 'Hello MCP!'},
    },
  };
  await server.handleMessages(Request(
    'POST',
    Uri.parse('http://localhost:7007/messages?sessionId=$sessionId'),
    body: jsonEncode(callMsg),
  ));
  await Future.delayed(const Duration(milliseconds: 50));

  final callEvent = sseEvents.lastWhere((e) => e.contains('"id":3'));
  assert(callEvent.contains('Echo: Hello MCP!'), 'Expected echo result in tools/call response');
  print('✓ tools/call RPC successful');

  // 5. Test resources/read
  final readMsg = {
    'jsonrpc': '2.0',
    'id': 4,
    'method': 'resources/read',
    'params': {
      'uri': 'test://status',
    },
  };
  await server.handleMessages(Request(
    'POST',
    Uri.parse('http://localhost:7007/messages?sessionId=$sessionId'),
    body: jsonEncode(readMsg),
  ));
  await Future.delayed(const Duration(milliseconds: 50));

  final readEvent = sseEvents.lastWhere((e) => e.contains('"id":4'));
  assert(readEvent.contains('All systems nominal'), 'Expected resource content in resources/read');
  print('✓ resources/read RPC successful');

  // 6. Test resource update notification
  server.notifyResourceUpdated('test://status');
  await Future.delayed(const Duration(milliseconds: 50));

  final notifyEvent = sseEvents.lastWhere((e) => e.contains('notifications/resources/updated'));
  assert(notifyEvent.contains('test://status'), 'Expected uri in resource update notification');
  print('✓ notifications/resources/updated push successful');

  await sub.cancel();
  server.dispose();
  print('=== ALL MCP PROTOCOL TESTS PASSED! ===');
  });
}
