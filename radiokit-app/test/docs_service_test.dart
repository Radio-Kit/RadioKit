import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:radiokit/services/docs_service.dart';

void main() {
  group('DocsService', () {
    test('getApiSchema returns valid structure', () {
      final docsService = DocsService();
      final schema = docsService.getApiSchema();
      expect(schema['title'], 'RadioKit Remote Access API');
      expect(schema['endpoints'], isA<List>());
      expect(schema['endpoints'].length, greaterThan(0));
    });

    test('getSkillContent returns null for nonexistent skill', () {
      final docsService = DocsService();
      final doc = docsService.getSkillContent('nonexistent');
      expect(doc, isNull);
    });

    test('getSkillsIndex returns empty list when no skills loaded', () {
      final docsService = DocsService();
      final index = docsService.getSkillsIndex();
      expect(index, isA<List>());
      expect(index, isEmpty);
    });
  });

  group('/api/docs routes', () {
    late Router router;
    late DocsService docsService;

    setUp(() {
      docsService = DocsService();

      router = Router();
      router.get('/api/docs', (request) async {
        final skills = docsService.getSkillsIndex();
        return Response.ok(
          jsonEncode({'skills': skills}),
          headers: {'content-type': 'application/json'},
        );
      });
      router.get('/api/docs/api-schema', (request) async {
        return Response.ok(
          jsonEncode(docsService.getApiSchema()),
          headers: {'content-type': 'application/json'},
        );
      });
      router.get('/api/docs/<skill>', (request, String skill) async {
        final doc = docsService.getSkillContent(skill);
        if (doc == null) {
          return Response.notFound(
            jsonEncode({'error': 'not_found', 'message': 'Skill not found: $skill'}),
            headers: {'content-type': 'application/json'},
          );
        }
        return Response.ok(
          jsonEncode(doc.toJson()),
          headers: {'content-type': 'application/json'},
        );
      });
    });

    test('GET /api/docs returns skills list', () async {
      final request = Request('GET', Uri.parse('http://test/api/docs'));
      final response = await router(request);
      expect(response.statusCode, 200);

      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['skills'], isA<List>());
    });

    test('GET /api/docs/<skill> returns 404 for nonexistent skill', () async {
      final request = Request('GET', Uri.parse('http://test/api/docs/nonexistent'));
      final response = await router(request);
      expect(response.statusCode, 404);

      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['error'], 'not_found');
    });

    test('GET /api/docs/api-schema returns API schema', () async {
      final request = Request('GET', Uri.parse('http://test/api/docs/api-schema'));
      final response = await router(request);
      expect(response.statusCode, 200);

      final body = jsonDecode(await response.readAsString()) as Map<String, dynamic>;
      expect(body['title'], 'RadioKit Remote Access API');
      expect(body['endpoints'], isA<List>());
    });
  });
}
