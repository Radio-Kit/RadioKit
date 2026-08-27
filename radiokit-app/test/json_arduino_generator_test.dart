import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/screens/designer/codegen/json_arduino_generator.dart';

void main() {
  group('JsonArduinoGenerator.generate', () {
    group('v1 single-page configs', () {
      test('emits widget declarations and initRadioKit', () {
        final json = {
          'version': 1,
          'config': {
            'name': 'TestDevice',
            'description': 'A test device',
            'type': 'IOT',
            'transports': {
              'ble': {'enabled': true},
            },
            'theme': 'dragon',
          },
          'canvas': {'size': [200, 100]},
          'widgets': [
            {
              'type': 'button',
              'name': 'btn_1',
              'label': {'text': 'Button', 'show': true},
              'position': [50, 50, 0],
              'size': [30, 15],
              'properties': {'variant': 'push'},
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('#ifndef RADIOKIT_GENERATED_H'));
        expect(output, contains('#define RK_ENABLE_BLE'));
        expect(output, contains('#include <RadioKitLib.h>'));
        expect(output, contains('RK_PushButton btn_1'));
        expect(output, contains('static inline void initRadioKit()'));
        expect(output, contains('RadioKit.begin()'));
        expect(output, contains('RadioKit.startBLE()'));
      });

      test('does not emit multi-page directives for v1', () {
        final json = {
          'version': 1,
          'config': {'name': 'SinglePage'},
          'canvas': {'size': [200, 100]},
          'widgets': [
            {
              'type': 'led',
              'name': 'led_1',
              'label': {'text': 'LED', 'show': true},
              'position': [50, 50, 0],
              'size': [null, 20],
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);

        expect(output, isNot(contains('RK_NUM_PAGES')));
        expect(output, isNot(contains('rk_pageNames')));
        expect(output, isNot(contains('setNumPages')));
      });

      test('emits setPage only for multi-page configs', () {
        final json = {
          'version': 1,
          'config': {'name': 'Test'},
          'canvas': {'size': [200, 100]},
          'widgets': [
            {
              'type': 'button',
              'name': 'btn_1',
              'label': {'text': 'Btn', 'show': true},
              'position': [50, 50, 0],
              'size': [30, 15],
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);

        // Should NOT contain setPage for v1
        expect(output, isNot(contains('setPage(')));
        // Should NOT contain rk.page
        expect(output, isNot(contains('rk.page')));
      });

      test('emits rk.label for label text', () {
        final json = {
          'version': 1,
          'config': {'name': 'Test'},
          'canvas': {'size': [200, 100]},
          'widgets': [
            {
              'type': 'text',
              'name': 'txt_1',
              'label': {'text': 'Status', 'show': true},
              'position': [50, 50, 0],
              'size': [80, 15],
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('txt_1.rk.label = "Status"'));
        expect(output, contains('RK_Text txt_1'));
      });

      test('emits setLabelHidden when show is false', () {
        final json = {
          'version': 1,
          'config': {'name': 'Test'},
          'canvas': {'size': [200, 100]},
          'widgets': [
            {
              'type': 'led',
              'name': 'led_1',
              'label': {'text': 'LED', 'show': false},
              'position': [50, 50, 0],
              'size': [null, 20],
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('led_1.setLabelHidden(true)'));
        expect(output, isNot(contains('rk.labelHidden')));
      });

      test('emits setHidden when hidden is true', () {
        final json = {
          'version': 1,
          'config': {'name': 'Test'},
          'canvas': {'size': [200, 100]},
          'widgets': [
            {
              'type': 'text',
              'name': 'txt_1',
              'label': {'text': 'Hidden', 'show': true},
              'position': [50, 50, 0],
              'size': [80, 15],
              'hidden': true,
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('txt_1.setHidden(true)'));
        expect(output, isNot(contains('rk.hidden')));
      });

      test('emits transport defines correctly', () {
        final json = {
          'version': 1,
          'config': {
            'name': 'WiFiTest',
            'transports': {
              'ble': {'enabled': false},
              'wifi': {'enabled': true, 'ssid': 'MyNetwork', 'pass': 'secret'},
              'cloud': {'enabled': false},
            },
          },
          'canvas': {'size': [200, 100]},
          'widgets': [],
        };

        final output = JsonArduinoGenerator.generate(json);

        expect(output, isNot(contains('#define RK_ENABLE_BLE')));
        expect(output, contains('#define RK_ENABLE_WIFI'));
        expect(output, contains('sta_ssid'));
        expect(output, contains('sta_password'));
        expect(output, contains('RadioKit.startWiFi()'));
      });
    });

    group('v2 multi-page configs', () {
      late Map<String, dynamic> multiPageJson;

      setUp(() {
        multiPageJson = {
          'version': 2,
          'config': {
            'name': 'MultiPageTest',
            'description': 'Multi-page test device',
            'type': 'IOT',
            'transports': {
              'ble': {'enabled': true},
            },
            'theme': 'dragon',
          },
          'canvas': {'size': [200, 100]},
          'pages': [
            {
              'name': 'Control',
              'orientation': 'landscape',
              'widgets': [
                {
                  'type': 'slider',
                  'name': 'speed',
                  'label': {'text': 'Speed', 'show': true},
                  'position': [50, 50, 0],
                  'size': [60, 10],
                  'properties': {'min': 0, 'max': 100},
                },
                {
                  'type': 'button',
                  'name': 'toggle',
                  'label': {'text': 'Toggle', 'show': true},
                  'position': [50, 80, 0],
                  'size': [30, 15],
                  'properties': {'variant': 'toggle'},
                },
              ],
            },
            {
              'name': 'Settings',
              'orientation': 'landscape',
              'widgets': [
                {
                  'type': 'text',
                  'name': 'status',
                  'label': {'text': 'Status', 'show': true},
                  'position': [50, 30, 0],
                  'size': [80, 15],
                },
                {
                  'type': 'led',
                  'name': 'indicator',
                  'label': {'text': 'Indicator', 'show': true},
                  'position': [50, 70, 0],
                  'size': [null, 20],
                },
              ],
            },
          ],
        };
      });

      test('emits RK_NUM_PAGES and rk_pageNames', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        expect(output, contains('#define RK_NUM_PAGES 2'));
        expect(output, contains('static const char* rk_pageNames[]'));
        expect(output, contains('"Control"'));
        expect(output, contains('"Settings"'));
      });

      test('emits rk_pageOrientations and setPageOrientations', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        expect(output, contains('static const uint8_t rk_pageOrientations[]'));
        expect(output, contains('RadioKit.setPageOrientations(rk_pageOrientations)'));
        // Both pages are landscape (0)
        expect(output, contains('// Control'));
        expect(output, contains('// Settings'));
      });

      test('emits portrait orientation as 1 in rk_pageOrientations', () {
        final json = Map<String, dynamic>.from(multiPageJson);
        json['pages'] = [
          {
            'name': 'Landscape',
            'orientation': 'landscape',
            'widgets': [],
          },
          {
            'name': 'Portrait',
            'orientation': 'portrait',
            'widgets': [],
          },
        ];
        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('1,  // Portrait'));
      });

      test('does not emit setCanvasFlags when both flags are true', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);
        expect(output, isNot(contains('RadioKit.setCanvasFlags')));
      });

      test('emits setCanvasFlags when showControlPageBar is false', () {
        final json = Map<String, dynamic>.from(multiPageJson);
        json['canvas'] = {
          'showPageBar': true,
          'showControlPageBar': false,
          'orientation': 'landscape',
        };
        final output = JsonArduinoGenerator.generate(json);
        expect(output, contains('RadioKit.setCanvasFlags(0x01)'));
      });

      test('emits setCanvasFlags when showPageBar is false', () {
        final json = Map<String, dynamic>.from(multiPageJson);
        json['canvas'] = {
          'showPageBar': false,
          'showControlPageBar': true,
          'orientation': 'landscape',
        };
        final output = JsonArduinoGenerator.generate(json);
        expect(output, contains('RadioKit.setCanvasFlags(0x02)'));
      });

      test('emits page-grouped widget declarations', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        expect(output, contains('Page 0: Control'));
        expect(output, contains('Page 1: Settings'));
        expect(output, contains('RK_Slider speed'));
        expect(output, contains('RK_ToggleButton toggle'));
        expect(output, contains('RK_Text status'));
        expect(output, contains('RK_LED indicator'));
      });

      test('emits setPage() for page > 0 widgets', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        // Page 0 widgets should NOT have setPage
        expect(output, isNot(contains('speed.setPage(')));
        expect(output, isNot(contains('toggle.setPage(')));

        // Page 1 widgets SHOULD have setPage(1)
        expect(output, contains('status.setPage(1)'));
        expect(output, contains('indicator.setPage(1)'));

        // Must NOT contain rk.page anywhere
        expect(output, isNot(contains('rk.page')));
      });

      test('emits setNumPages before begin()', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        final setNumPagesIdx = output.indexOf('RadioKit.setNumPages(RK_NUM_PAGES)');
        final beginIdx = output.indexOf('RadioKit.begin()');

        expect(setNumPagesIdx, isNot(-1), reason: 'setNumPages should be present');
        expect(beginIdx, isNot(-1), reason: 'begin() should be present');
        expect(setNumPagesIdx, lessThan(beginIdx),
            reason: 'setNumPages must come before begin()');
      });

      test('emits setPage() not rk.page for all widget types', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        // Verify setPage is used, not rk.page
        expect(output, isNot(contains('.rk.page')));
        expect(output, contains('.setPage('));
      });

      test('emits config init with device name', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        expect(output, contains('MultiPageTest'));
        expect(output, contains('Multi-page test device'));
        expect(output, contains('config.type'));
      });

      test('emits BLE start for ble-enabled config', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        expect(output, contains('RadioKit.startBLE()'));
      });

      test('handles three pages correctly', () {
        final json3 = Map<String, dynamic>.from(multiPageJson);
        json3['pages'] = [
          {
            'name': 'Page A',
            'orientation': 'landscape',
            'widgets': [
              {
                'type': 'button',
                'name': 'btn_a',
                'label': {'text': 'A', 'show': true},
                'position': [50, 50, 0],
                'size': [30, 15],
              },
            ],
          },
          {
            'name': 'Page B',
            'orientation': 'portrait',
            'widgets': [
              {
                'type': 'led',
                'name': 'led_b',
                'label': {'text': 'B', 'show': true},
                'position': [50, 50, 0],
                'size': [null, 20],
              },
            ],
          },
          {
            'name': 'Page C',
            'orientation': 'landscape',
            'widgets': [
              {
                'type': 'text',
                'name': 'txt_c',
                'label': {'text': 'C', 'show': true},
                'position': [50, 50, 0],
                'size': [80, 15],
              },
            ],
          },
        ];

        final output = JsonArduinoGenerator.generate(json3);

        expect(output, contains('#define RK_NUM_PAGES 3'));
        expect(output, contains('"Page A"'));
        expect(output, contains('"Page B"'));
        expect(output, contains('"Page C"'));
        expect(output, contains('Page 0: Page A'));
        expect(output, contains('Page 1: Page B'));
        expect(output, contains('Page 2: Page C'));
        // Page 0: no setPage, pages 1 and 2: setPage
        expect(output, isNot(contains('btn_a.setPage(')));
        expect(output, contains('led_b.setPage(1)'));
        expect(output, contains('txt_c.setPage(2)'));
      });

      test('widget on page 0 does not emit setPage', () {
        final output = JsonArduinoGenerator.generate(multiPageJson);

        // speed and toggle are on page 0
        expect(output, isNot(contains('speed.setPage(')));
        expect(output, isNot(contains('toggle.setPage(')));
      });

      test('multi-page with hidden widget emits setHidden not rk.hidden', () {
        final json = Map<String, dynamic>.from(multiPageJson);
        (json['pages'] as List)[1]['widgets'] = [
          {
            'type': 'text',
            'name': 'secret',
            'label': {'text': 'Secret', 'show': true},
            'position': [50, 50, 0],
            'size': [80, 15],
            'hidden': true,
          },
        ];

        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('secret.setHidden(true)'));
        expect(output, isNot(contains('rk.hidden')));
      });

      test('sub-generators emit setPage(1) when on page 1', () {
        final json = {
          'version': 2,
          'config': {'name': 'SubGenPageTest'},
          'canvas': {'size': [200, 100]},
          'pages': [
            {
              'name': 'Page0',
              'widgets': [],
            },
            {
              'name': 'Page1',
              'widgets': [
                {
                  'type': 'slider',
                  'name': 'slider_1',
                  'position': [10, 10, 0],
                  'size': [50, 10],
                },
                {
                  'type': 'slider',
                  'variant': 'gasPedal',
                  'name': 'pedal_1',
                  'position': [10, 25, 0],
                  'size': [50, 10],
                },
                {
                  'type': 'knob',
                  'name': 'knob_1',
                  'position': [10, 40, 0],
                  'size': [30, 30],
                },
                {
                  'type': 'knob',
                  'variant': 'steeringWheel',
                  'name': 'wheel_1',
                  'position': [10, 70, 0],
                  'size': [40, 40],
                },
                {
                  'type': 'multiple',
                  'variant': 'multiButton',
                  'name': 'mbtn_1',
                  'position': [60, 10, 0],
                  'size': [60, 20],
                },
                {
                  'type': 'multiple',
                  'variant': 'multiSelect',
                  'name': 'msel_1',
                  'position': [60, 40, 0],
                  'size': [60, 20],
                },
              ],
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('slider_1.setPage(1)'));
        expect(output, contains('pedal_1.setPage(1)'));
        expect(output, contains('knob_1.setPage(1)'));
        expect(output, contains('wheel_1.setPage(1)'));
        expect(output, contains('mbtn_1.setPage(1)'));
        expect(output, contains('msel_1.setPage(1)'));
      });
    });

    group('widget type coverage', () {
      Map<String, dynamic> makeJson(String type, String name,
          {Map<String, dynamic>? properties, String? variant}) {
        final widget = <String, dynamic>{
          'type': type,
          'name': name,
          'label': {'text': name, 'show': true},
          'position': [50, 50, 0],
          'size': [30, 15],
        };
        if (properties != null) widget['properties'] = properties;
        if (variant != null) widget['variant'] = variant;
        return {
          'version': 1,
          'config': {'name': 'Test'},
          'canvas': {'size': [200, 100]},
          'widgets': [widget],
        };
      }

      test('button (push) emits RK_PushButton', () {
        final output =
            JsonArduinoGenerator.generate(makeJson('button', 'b1'));
        expect(output, contains('RK_PushButton b1'));
      });

      test('button (toggle) emits RK_ToggleButton', () {
        final output = JsonArduinoGenerator.generate(
            makeJson('button', 'b1', properties: {'variant': 'toggle'}));
        expect(output, contains('RK_ToggleButton b1'));
      });

      test('slider emits RK_Slider', () {
        final output =
            JsonArduinoGenerator.generate(makeJson('slider', 's1'));
        expect(output, contains('RK_Slider s1'));
      });

      test('gasPedal emits RK_GasPedal', () {
        final output = JsonArduinoGenerator.generate(
            makeJson('slider', 'g1', variant: 'gasPedal'));
        expect(output, contains('RK_GasPedal g1'));
      });

      test('knob emits RK_Knob', () {
        final output =
            JsonArduinoGenerator.generate(makeJson('knob', 'k1'));
        expect(output, contains('RK_Knob k1'));
      });

      test('steeringWheel emits RK_Knob with variant', () {
        final output = JsonArduinoGenerator.generate(
            makeJson('knob', 'sw1', variant: 'steeringWheel'));
        expect(output, contains('RK_Knob sw1'));
        expect(output, contains('rk.variant = 1'));
      });

      test('led emits RK_LED', () {
        final output =
            JsonArduinoGenerator.generate(makeJson('led', 'l1'));
        expect(output, contains('RK_LED l1'));
      });

      test('text emits RK_Text', () {
        final output =
            JsonArduinoGenerator.generate(makeJson('text', 't1'));
        expect(output, contains('RK_Text t1'));
      });

      test('joystick emits RK_Joystick', () {
        final output =
            JsonArduinoGenerator.generate(makeJson('joystick', 'j1'));
        expect(output, contains('RK_Joystick j1'));
      });

      test('multiButton emits RK_MultipleButton', () {
        final output = JsonArduinoGenerator.generate(
            makeJson('multiple', 'mb1', variant: 'multiButton'));
        expect(output, contains('RK_MultipleButton mb1'));
      });

      test('multiSelect emits RK_MultipleSelect', () {
        final output = JsonArduinoGenerator.generate(
            makeJson('multiple', 'ms1', variant: 'multiSelect'));
        expect(output, contains('RK_MultipleSelect ms1'));
      });

      test('button and switch emit rk.icon and rk.offIcon when configured', () {
        final json = {
          'version': 1,
          'config': {'name': 'Test'},
          'canvas': {'size': [200, 100]},
          'widgets': [
            {
              'type': 'button',
              'name': 'horn_btn',
              'label': {'text': 'Horn', 'show': false},
              'position': [50, 50, 0],
              'size': [null, 20],
              'properties': {
                'onIcon': 'bell-ringing',
                'offIcon': 'bell',
              },
            },
            {
              'type': 'slideSwitch',
              'name': 'dir_sw',
              'label': {'text': 'Dir', 'show': false},
              'position': [80, 50, 0],
              'size': [30, 15],
              'properties': {
                'onIcon': 'arrow-right',
                'offIcon': 'arrow-left',
              },
            },
          ],
        };

        final output = JsonArduinoGenerator.generate(json);
        expect(output, contains('horn_btn.rk.icon = "bell-ringing";'));
        expect(output, contains('horn_btn.rk.offIcon = "bell";'));
        expect(output, contains('dir_sw.rk.icon = "arrow-right";'));
        expect(output, contains('dir_sw.rk.offIcon = "arrow-left";'));
      });

      test('rc_controller.json generates matching RADIOKIT.h', () {
        final file = File('assets/demos/rc_controller.json');
        final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final output = JsonArduinoGenerator.generate(json);

        expect(output, contains('RK_GasPedal gas(23, 57, 54, 25, 0);'));
        expect(output, contains('gas.rk.label = "gas";'));
        expect(output, contains('gas.rk.centering = RK_SPRING_MIN;'));

        expect(output, contains('RK_Knob steering(162, 57, 55, 0, 0);'));
        expect(output, contains('steering.rk.label = "steering";'));
        expect(output, contains('steering.rk.variant = 1;     // steeringWheel'));
        expect(output, contains('steering.rk.centering = RK_SPRING_CENTER;'));
        expect(output, contains('steering.rk.startAngle = -135;'));
        expect(output, contains('steering.rk.endAngle = 135;'));
        expect(output, contains('steering.rk.centerIcon = "renault";'));

        expect(output, contains('RK_MultipleSelect lights(94, 58, 22, 0, 0);'));
        expect(output, contains('lights.rk.label = "lights";'));
        expect(output, contains('lights.rk.items[0] = {"Head", "lightbulb", 0};'));
        expect(output, contains('lights.rk.items[1] = {"Fog", "cloud", 1};'));
        expect(output, contains('lights.rk.items[2] = {"Hazard", "warning", 2};'));
        expect(output, contains('lights.rk.items[3] = {"Cabin", "home", 3};'));
        expect(output, contains('lights.rk.itemCount = 4;'));

        expect(output, contains('RK_Text telemetry(97, 10, 20, 87);'));
        expect(output, contains('telemetry.rk.label = "telemetry";'));
        expect(output, contains('telemetry.rk.content = "Display";'));

        expect(output, contains('RK_MultipleButton multi_button_1(51, 58, 0, 19, 0);'));
        expect(output, contains('multi_button_1.setLabelHidden(true);'));
        expect(output, contains('multi_button_1.rk.items[0] = {"D", nullptr, 0};'));
        expect(output, contains('multi_button_1.rk.items[1] = {"P", nullptr, 1};'));
        expect(output, contains('multi_button_1.rk.items[2] = {"R", nullptr, 2};'));
        expect(output, contains('multi_button_1.rk.itemCount = 3;'));
      });

      test('emits fs_url and ota_url when present in config.links', () {
        final json = {
          'version': 1,
          'config': {
            'name': 'LinkedDevice',
            'transports': {'ble': {'enabled': true}},
            'links': {
              'fs': 'https://github.com/rambros3d/RadioKit/tree/main/configs',
              'ota': 'https://example.com/firmware.bin',
            },
          },
          'canvas': {'size': [200, 100]},
          'widgets': [],
        };
        final output = JsonArduinoGenerator.generate(json);
        expect(output, contains('RadioKit.config.fs_url       = "https://github.com/rambros3d/RadioKit/tree/main/configs";'));
        expect(output, contains('RadioKit.config.ota_url      = "https://example.com/firmware.bin";'));
      });
    });
  });
}
