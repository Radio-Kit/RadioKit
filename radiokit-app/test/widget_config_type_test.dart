import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/models/widget_config.dart';
import 'package:radiokit/models/protocol.dart';

void main() {
  group('WidgetConfig wire type mapping', () {
    test('telemetry typeId 0x0A maps to telemetry', () {
      const config = WidgetConfig(
        typeId: kWidgetTelemetry,
        widgetId: 15,
        x: 0,
        y: 0,
        width: 0,
        height: 1,
        label: 'Battery',
      );
      final json = config.toDesignerJsonMap(200, 100);
      expect(json['type'], 'telemetry');
    });

    test('button typeId 0x01 still maps to button', () {
      const config = WidgetConfig(
        typeId: kWidgetButton,
        widgetId: 4,
        x: 10,
        y: 10,
        width: 0,
        height: 20,
        label: 'start_button',
      );
      final json = config.toDesignerJsonMap(200, 100);
      expect(json['type'], 'button');
    });

    test('widgetTypeName display for telemetry', () {
      expect(widgetTypeName(kWidgetTelemetry), 'Telemetry');
      expect(widgetTypeName(kWidgetButton), 'Button');
    });
  });

  group('widgetConfigsToDesignerJson reconstruction', () {
    const knob = WidgetConfig(
      typeId: kWidgetKnob,
      widgetId: 0,
      x: 100,
      y: 50,
      width: 0,
      height: 40,
      label: 'steering_wheel',
      pageIndex: 0,
    );
    const slider = WidgetConfig(
      typeId: kWidgetSlider,
      widgetId: 1,
      x: 50,
      y: 50,
      width: 20,
      height: 40,
      label: 'throttle_slider',
      pageIndex: 1,
    );
    const battery = WidgetConfig(
      typeId: kWidgetTelemetry,
      widgetId: 2,
      x: 0,
      y: 0,
      width: 0,
      height: 1,
      label: 'Battery',
      icon: 'battery',
      pageIndex: 0,
    );
    const speed = WidgetConfig(
      typeId: kWidgetTelemetry,
      widgetId: 3,
      x: 0,
      y: 0,
      width: 0,
      height: 1,
      label: 'Speed',
      pageIndex: 0,
    );

    test('multi-page config emits pages[] with page grouping, no flat widgets', () {
      final json = widgetConfigsToDesignerJson(
        widgets: const [knob, slider, battery, speed],
        name: 'RC_UI',
        description: '',
        orientation: kOrientationLandscape,
        theme: 'dragon',
        pageNames: const ['Truck', 'Loco'],
      );
      expect(json['version'], 2);
      expect(json.containsKey('widgets'), isFalse,
          reason: 'multi-page reconstruction must not emit flat widgets[]');
      final pages = json['pages'] as List;
      expect(pages.length, 2);
      expect((pages[0] as Map)['name'], 'Truck');
      expect((pages[1] as Map)['name'], 'Loco');
      // Page 0 contains only the knob (telemetry is extracted out).
      final page0Widgets = (pages[0] as Map)['widgets'] as List;
      expect(page0Widgets, hasLength(1));
      expect((page0Widgets.first as Map)['name'], 'steering_wheel');
      // Page 1 contains only the slider.
      final page1Widgets = (pages[1] as Map)['widgets'] as List;
      expect(page1Widgets, hasLength(1));
      expect((page1Widgets.first as Map)['name'], 'throttle_slider');
    });

    test('telemetry widgets are extracted into top-level telemetry[]', () {
      final json = widgetConfigsToDesignerJson(
        widgets: const [knob, battery, speed],
        name: 'RC_UI',
        description: '',
        orientation: kOrientationLandscape,
        theme: 'dragon',
        pageNames: const ['Truck', 'Loco'],
      );
      final telemetry = json['telemetry'] as List;
      expect(telemetry, hasLength(2));
      expect((telemetry[0] as Map)['label'], 'Battery');
      expect((telemetry[0] as Map)['icon'], 'battery');
      expect((telemetry[1] as Map)['label'], 'Speed');
      // Telemetry must not appear in page widget lists.
      final pages = json['pages'] as List;
      final allWidgets = [
        for (final p in pages) ...((p as Map)['widgets'] as List),
      ];
      expect(allWidgets, hasLength(1));
      expect((allWidgets.first as Map)['name'], 'steering_wheel');
    });

    test('single-page config keeps flat widgets[]', () {
      final json = widgetConfigsToDesignerJson(
        widgets: const [knob],
        name: 'RC_UI',
        description: '',
        orientation: kOrientationLandscape,
        theme: 'dragon',
      );
      expect(json.containsKey('pages'), isFalse);
      expect(json.containsKey('telemetry'), isFalse);
      final widgets = json['widgets'] as List;
      expect(widgets, hasLength(1));
      expect((widgets.first as Map)['name'], 'steering_wheel');
    });

    test('features and enableControlUI preserved when provided', () {
      final json = widgetConfigsToDesignerJson(
        widgets: const [knob],
        name: 'RC_UI',
        description: '',
        orientation: kOrientationLandscape,
        theme: 'dragon',
        features: const {'ota': true, 'filesystem': true},
        enableControlUI: true,
      );
      expect(json['features'], {'ota': true, 'filesystem': true});
      expect(json['enableControlUI'], isTrue);
    });

    test('multi-page emitted from numPages even when widgets are all on page 0', () {
      // CONF_DATA only carries active-page widgets (all pageIndex 0), but the
      // v5 header reports numPages=2 — reconstruction must still emit pages[].
      final json = widgetConfigsToDesignerJson(
        widgets: const [knob],
        name: 'RC_UI',
        description: '',
        orientation: kOrientationLandscape,
        theme: 'dragon',
        numPages: 2,
      );
      expect(json.containsKey('widgets'), isFalse);
      final pages = json['pages'] as List;
      expect(pages.length, 2);
      expect((pages[0] as Map)['name'], 'Control');
      expect((pages[1] as Map)['name'], 'Page 2');
    });

    test('features and enableControlUI omitted when not provided', () {
      final json = widgetConfigsToDesignerJson(
        widgets: const [knob],
        name: 'RC_UI',
        description: '',
        orientation: kOrientationLandscape,
        theme: 'dragon',
      );
      expect(json.containsKey('features'), isFalse);
      expect(json.containsKey('enableControlUI'), isFalse);
    });

    test('toggle button (wire 0x02) reconstructs as button with toggle variant', () {
      const toggle = WidgetConfig(
        typeId: kWidgetSwitch, // 0x02 = RK_TYPE_TOGGLE_BUTTON
        widgetId: 4,
        x: 10,
        y: 10,
        width: 0,
        height: 20,
        label: 'start_button',
        onText: 'START',
        offText: 'STOP',
      );
      final json = toggle.toDesignerJsonMap(200, 100);
      expect(json['type'], 'button');
      expect(json['properties']['variant'], 'toggle');
      expect(json['properties']['onText'], 'START');
      expect(json['properties']['offText'], 'STOP');
    });

    test('icon-only toggle button emits empty onText/offText (no ON/OFF injection)', () {
      const indicator = WidgetConfig(
        typeId: kWidgetSwitch, // 0x02 = toggle button
        widgetId: 5,
        x: 10,
        y: 10,
        width: 0,
        height: 20,
        label: 'left_indicator',
        icon: 'arrow-left',
      );
      final json = indicator.toDesignerJsonMap(200, 100);
      // Empty text must be emitted explicitly so DesignerElement.fromJson
      // does not seed the button defaults 'ON'/'OFF' on load.
      expect(json['properties']['onText'], '');
      expect(json['properties']['offText'], '');
      expect(json['properties']['onIcon'], 'arrow-left');
      expect(json['type'], 'button');
      expect(json['properties']['variant'], 'toggle');
    });

    test('wire icon reconstructs into onIcon for buttons', () {
      const iconBtn = WidgetConfig(
        typeId: kWidgetButton,
        widgetId: 5,
        x: 10,
        y: 10,
        width: 0,
        height: 20,
        label: 'horn_button',
        icon: 'bell',
        onText: 'ON',
      );
      final json = iconBtn.toDesignerJsonMap(200, 100);
      expect(json['properties']['onIcon'], 'bell');
    });

    test('knob centerIcon reconstructs into properties', () {
      const knob2 = WidgetConfig(
        typeId: kWidgetKnob,
        widgetId: 0,
        x: 100,
        y: 50,
        width: 0,
        height: 40,
        label: 'steering_wheel',
        centerIcon: 'renault',
      );
      final json = knob2.toDesignerJsonMap(200, 100);
      expect(json['properties']['centerIcon'], 'renault');
    });

    test('disabled autoCenter survives reconstruction round-trip', () {
      const steering = WidgetConfig(
        typeId: kWidgetKnob,
        widgetId: 0,
        x: 100,
        y: 50,
        width: 0,
        height: 40,
        label: 'steering_wheel',
        variant: 0x80, // alternate shape (steering wheel) with centering NONE (0)
      );
      final json = steering.toDesignerJsonMap(200, 100);
      expect(json['type'], 'knob');
      expect(json['variant'], 'steeringWheel');
      expect(json['properties']['autoCenter'], equals([null, 'smooth', 300]));
    });

    test('page-bar flags emitted into canvas when provided', () {
      final json = widgetConfigsToDesignerJson(
        widgets: const [knob],
        name: 'RC_UI',
        description: '',
        orientation: kOrientationLandscape,
        theme: 'dragon',
        showPageBar: true,
        showControlPageBar: false,
      );
      final canvas = json['canvas'] as Map;
      expect(canvas['showPageBar'], isTrue);
      expect(canvas['showControlPageBar'], isFalse);
    });
  });

  group('designMetadataFromJson', () {
    test('extracts page-bar flags, features, and enableControlUI', () {
      final meta = designMetadataFromJson({
        'features': {'ota': true, 'filesystem': true},
        'enableControlUI': true,
        'canvas': {
          'showPageBar': true,
          'showControlPageBar': false,
          'size': [200, 100],
          'grid': 'none',
          'skin': 'dragon',
        },
      });
      expect(meta, isNotNull);
      expect(meta!['features'], {'ota': true, 'filesystem': true});
      expect(meta['enableControlUI'], isTrue);
      expect(meta['showPageBar'], isTrue);
      expect(meta['showControlPageBar'], isFalse);
    });

    test('returns null for null input and empty metadata', () {
      expect(designMetadataFromJson(null), isNull);
      expect(designMetadataFromJson({'canvas': {'size': [200, 100]}}), isNull);
      expect(designMetadataFromJson({'version': 2}), isNull);
    });

    test('ignores non-bool flags and non-map features', () {
      final meta = designMetadataFromJson({
        'features': 'ota',
        'enableControlUI': 'yes',
        'canvas': {
          'showPageBar': 'no',
          'showControlPageBar': false,
        },
      });
      expect(meta, isNotNull);
      expect(meta!['features'], isNull);
      expect(meta['enableControlUI'], isNull);
      expect(meta['showPageBar'], isNull);
      expect(meta['showControlPageBar'], isFalse);
    });
  });
}
