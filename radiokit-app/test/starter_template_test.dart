import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/models/starter_template.dart';

void main() {
  group('StarterTemplate.fromParsed', () {
    test('parses a complete template JSON', () {
      final json = {
        'config': {
          'name': 'Test-Template',
          'type': 'Locomotive',
          'transport': 'BLE',
        },
        'canvas': {
          'size': [200, 100],
          'skin': 'dragon',
        },
        'widgets': [
          {'type': 'button'},
          {'type': 'slider'},
        ],
      };

      final template = StarterTemplate.fromParsed(
        assetPath: 'starter-templates/Test.json',
        json: json,
        jsonContent: '{"config":{"name":"Test-Template"}}',
      );

      expect(template.name, 'Test-Template');
      expect(template.type, 'Locomotive');
      expect(template.transport, 'BLE');
      expect(template.canvasSize, [200, 100]);
      expect(template.widgetCount, 2);
      expect(template.skin, 'dragon');
      expect(template.assetPath, 'starter-templates/Test.json');
      expect(template.jsonContent, '{"config":{"name":"Test-Template"}}');
    });

    test('uses defaults for missing fields', () {
      final json = <String, dynamic>{};

      final template = StarterTemplate.fromParsed(
        assetPath: 'starter-templates/Empty.json',
        json: json,
        jsonContent: '{}',
      );

      expect(template.name, 'Untitled');
      expect(template.type, '');
      expect(template.transport, '');
      expect(template.canvasSize, [200, 100]);
      expect(template.widgetCount, 0);
      expect(template.skin, 'dragon');
    });

    test('handles canvas size as legacy string format', () {
      final json = {
        'canvas': {'size': [100, 200]},
        'widgets': <dynamic>[],
      };

      final template = StarterTemplate.fromParsed(
        assetPath: 'starter-templates/Legacy.json',
        json: json,
        jsonContent: '{}',
      );

      expect(template.canvasSize, [100, 200]);
      expect(template.widgetCount, 0);
    });

    test('handles multi-page template widget count', () {
      final json = {
        'config': {'name': 'FULL_RC', 'type': 'RC'},
        'canvas': {'size': [200, 100], 'skin': 'dragon'},
        'pages': [
          {
            'name': 'Truck',
            'widgets': [
              {'type': 'knob'},
              {'type': 'slider'},
            ],
          },
          {
            'name': 'Loco',
            'widgets': [
              {'type': 'switch'},
            ],
          },
        ],
      };

      final template = StarterTemplate.fromParsed(
        assetPath: 'starter-templates/FULL_RC.json',
        json: json,
        jsonContent: '{}',
      );

      expect(template.name, 'FULL_RC');
      expect(template.widgetCount, 3);
    });
  });

  group('StarterTemplate.id', () {
    test('generates ID from asset path', () {
      final template = StarterTemplate(
        assetPath: 'starter-templates/Locomotive_Remote.json',
        name: 'Locomotive-Remote',
        type: 'Locomotive',
        transport: 'BLE',
        canvasSize: [100, 200],
        widgetCount: 3,
        skin: 'dragon',
        jsonContent: '{}',
      );

      expect(
        template.id,
        'template_starter-templates_Locomotive_Remote_json',
      );
    });

    test('generates unique IDs for different paths', () {
      final t1 = StarterTemplate(
        assetPath: 'starter-templates/Template_A.json',
        name: 'A',
        type: '',
        transport: '',
        canvasSize: [200, 100],
        widgetCount: 0,
        skin: 'dragon',
        jsonContent: '{}',
      );
      final t2 = StarterTemplate(
        assetPath: 'starter-templates/Template_B.json',
        name: 'B',
        type: '',
        transport: '',
        canvasSize: [200, 100],
        widgetCount: 0,
        skin: 'dragon',
        jsonContent: '{}',
      );

      expect(t1.id, isNot(t2.id));
    });
  });

  group('StarterTemplate constructor', () {
    test('creates instance with all required fields', () {
      final template = StarterTemplate(
        assetPath: 'starter-templates/Test.json',
        name: 'Test',
        type: 'IOT',
        transport: 'WiFi',
        canvasSize: [200, 100],
        widgetCount: 5,
        skin: 'matrix',
        jsonContent: '{"test": true}',
      );

      expect(template.assetPath, 'starter-templates/Test.json');
      expect(template.name, 'Test');
      expect(template.type, 'IOT');
      expect(template.transport, 'WiFi');
      expect(template.canvasSize, [200, 100]);
      expect(template.widgetCount, 5);
      expect(template.skin, 'matrix');
      expect(template.jsonContent, '{"test": true}');
    });
  });
}
