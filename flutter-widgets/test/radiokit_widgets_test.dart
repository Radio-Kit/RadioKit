import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('RKLed renders on state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: const RKLed(state: RKLEDState.on),
        ),
      ),
    );
    expect(find.byType(RKLed), findsOneWidget);
  });

  testWidgets('RKDisplay renders text', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: const RKDisplay(text: 'Hello'),
        ),
      ),
    );
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('RKSlideSwitch renders and toggles', (tester) async {
    bool value = false;
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: RKSlideSwitch(
                  value: value,
                  onChanged: (v) => setState(() => value = v),
                ),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(RKSlideSwitch), findsOneWidget);
    expect(find.text('OFF'), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);

    await tester.tap(find.byType(RKSlideSwitch));
    await tester.pumpAndSettle();

    expect(value, isTrue);
  });

  testWidgets('MultiButtonWidgetDefinition generates itemCount buttons and flips orientation', (tester) async {
    final def = WidgetRegistry.instance.getById('multiButton')!;
    
    // Test itemCount = 5 horizontal (width > height)
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Builder(
            builder: (context) {
              return def.buildCanvasWidget(
                context,
                const WidgetBuildContext(
                  id: 'mb_1',
                  type: DesignerElementType.multiButton,
                  properties: {'itemCount': 5},
                  runtimeValue: null,
                  onChanged: null,
                  isPlayMode: false,
                  isSelected: false,
                  cellSize: 3.0,
                  width: 50,
                  height: 15,
                  label: '',
                  labelHidden: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(find.byType(RKMultiButton), findsOneWidget);
    final multiBtn = tester.widget<RKMultiButton>(find.byType(RKMultiButton));
    expect(multiBtn.items.length, equals(5));
    expect(multiBtn.orientation, equals(RKAxis.horizontal));

    // Test vertical orientation (height > width)
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Builder(
            builder: (context) {
              return def.buildCanvasWidget(
                context,
                const WidgetBuildContext(
                  id: 'mb_1',
                  type: DesignerElementType.multiButton,
                  properties: {'itemCount': 5},
                  runtimeValue: null,
                  onChanged: null,
                  isPlayMode: false,
                  isSelected: false,
                  cellSize: 3.0,
                  width: 15,
                  height: 50,
                  label: '',
                  labelHidden: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    final multiBtnVert = tester.widget<RKMultiButton>(find.byType(RKMultiButton));
    expect(multiBtnVert.orientation, equals(RKAxis.vertical));
  });

  Future<void> _pumpButton(WidgetTester tester, RKButton btn) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Scaffold(body: Center(child: btn)),
        ),
      ),
    );
  }

  testWidgets('RKButton text-only renders no default icon', (tester) async {
    await _pumpButton(
      tester,
      RKButton(
        value: false,
        onChanged: (_) {},
        onText: 'START',
        offText: 'STOP',
      ),
    );
    expect(find.byType(Icon), findsNothing,
        reason: 'text-only button must not show a default icon');
    expect(find.text('STOP'), findsOneWidget);
  });

  testWidgets('RKButton icon-only renders no default text', (tester) async {
    await _pumpButton(
      tester,
      RKButton(
        value: false,
        onChanged: (_) {},
        onIcon: Icons.arrow_back,
        offIcon: Icons.arrow_back,
        onText: '',
        offText: '',
      ),
    );
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    expect(find.text('ON'), findsNothing);
    expect(find.text('OFF'), findsNothing);
  });

  testWidgets('RKButton renders icon above text when both defined', (tester) async {
    await _pumpButton(
      tester,
      RKButton(
        value: false,
        onChanged: (_) {},
        onIcon: Icons.notifications,
        offIcon: null,
        onText: 'ON',
        offText: '',
      ),
    );
    // OFF is fully undefined, so ON content (icon + text) is shown in OFF too.
    expect(find.byIcon(Icons.notifications), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);
  });

  testWidgets('RKButton OFF override uses offIcon when defined', (tester) async {
    await _pumpButton(
      tester,
      RKButton(
        value: false,
        onChanged: (_) {},
        onIcon: Icons.notifications,
        offIcon: Icons.notifications_off,
        onText: 'ON',
        offText: 'STOP',
      ),
    );
    expect(find.byIcon(Icons.notifications_off), findsOneWidget);
    expect(find.byIcon(Icons.notifications), findsNothing);
    expect(find.text('STOP'), findsOneWidget);
  });

  testWidgets('RKButton ON state shows onIcon and onText', (tester) async {
    await _pumpButton(
      tester,
      RKButton(
        value: true,
        mode: RKButtonMode.toggle,
        onChanged: (_) {},
        onIcon: Icons.notifications,
        onText: 'ON',
        offText: 'STOP',
      ),
    );
    expect(find.byIcon(Icons.notifications), findsOneWidget);
    expect(find.text('ON'), findsOneWidget);
  });

  test('DesignerElement.fromJson keeps empty button text empty (no ON/OFF seed)', () {
    final el = DesignerElement.fromJson({
      'type': 'button',
      'name': 'left_indicator',
      'label': {'text': 'left_indicator', 'show': false},
      'position': [136, 16, 0],
      'size': [null, 13],
      'properties': {
        'widgetId': 5,
        'variant': 'toggle',
        'onText': '',
        'offText': '',
        'onIcon': 'arrow-left',
      },
    });
    expect(el.properties['onText'], '');
    expect(el.properties['offText'], '');
    expect(el.properties['onIcon'], 'arrow-left');
  });

  test('DesignerElement.fromJson normalizes stale itemCount to items.length', () {
    final el = DesignerElement.fromJson({
      'type': 'multiple',
      'variant': 'multiButton',
      'name': 'truck_light',
      'label': {'text': 'truck_light', 'show': false},
      'position': [97, 81, 0],
      'size': [70, 21],
      'properties': {
        'itemCount': 5,
        'items': [
          {'onLabel': 'A'},
          {'onLabel': 'B'},
          {'onLabel': 'C'},
        ],
      },
    });
    // itemCount must normalize to the actual items array length (3).
    expect(el.properties['itemCount'], 3);
  });

  test('DesignerElement.toJson serializes itemCount equal to items.length', () {
    final el = DesignerElement.fromJson({
      'type': 'multiple',
      'variant': 'multiButton',
      'name': 'truck_light',
      'label': {'text': 'truck_light', 'show': false},
      'position': [97, 81, 0],
      'size': [70, 21],
      'properties': {
        'itemCount': 8,
        'items': [
          {'onLabel': 'A'},
          {'onLabel': 'B'},
          {'onLabel': 'C'},
        ],
      },
    });
    final json = el.toJson();
    final props = json['properties'] as Map;
    final items = props['items'] as List;
    expect(props['itemCount'], items.length);
    expect(props['itemCount'], 3);
  });

  testWidgets('SteeringWheelWidgetDefinition renders centered before runtime value', (tester) async {
    final def = WidgetRegistry.instance.getById('steeringWheel')!;
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Builder(
            builder: (context) {
              return def.buildCanvasWidget(
                context,
                const WidgetBuildContext(
                  id: 'sw_1',
                  type: DesignerElementType.steeringWheel,
                  properties: {'min': -100.0, 'max': 100.0},
                  runtimeValue: null,
                  onChanged: null,
                  isPlayMode: false,
                  isSelected: false,
                  cellSize: 3.0,
                  width: 24,
                  height: 24,
                  label: '',
                  labelHidden: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(find.byType(RKSteeringWheel), findsOneWidget);
    final wheel = tester.widget<RKSteeringWheel>(find.byType(RKSteeringWheel));
    expect(wheel.value, equals(0.0));
  });

  testWidgets('KnobWidgetDefinition renders centered before runtime value', (tester) async {
    final def = WidgetRegistry.instance.getById('knob')!;
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Builder(
            builder: (context) {
              return def.buildCanvasWidget(
                context,
                const WidgetBuildContext(
                  id: 'k_1',
                  type: DesignerElementType.knob,
                  properties: {'min': 0.0, 'max': 100.0},
                  runtimeValue: null,
                  onChanged: null,
                  isPlayMode: false,
                  isSelected: false,
                  cellSize: 3.0,
                  width: 20,
                  height: 20,
                  label: '',
                  labelHidden: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(find.byType(RKKnob), findsOneWidget);
    final knob = tester.widget<RKKnob>(find.byType(RKKnob));
    expect(knob.value, equals(50.0));
  });

  testWidgets('GasPedalWidgetDefinition renders at min before runtime value', (tester) async {
    final def = WidgetRegistry.instance.getById('gasPedal')!;
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Builder(
            builder: (context) {
              return def.buildCanvasWidget(
                context,
                const WidgetBuildContext(
                  id: 'gp_1',
                  type: DesignerElementType.gasPedal,
                  properties: {'min': 0.0, 'max': 100.0},
                  runtimeValue: null,
                  onChanged: null,
                  isPlayMode: false,
                  isSelected: false,
                  cellSize: 3.0,
                  width: 10,
                  height: 30,
                  label: '',
                  labelHidden: true,
                ),
              );
            },
          ),
        ),
      ),
    );
    expect(find.byType(RKGasPedal), findsOneWidget);
    final pedal = tester.widget<RKGasPedal>(find.byType(RKGasPedal));
    expect(pedal.value, equals(0.0));
  });

  testWidgets('RKMultiSelect filters visible items and preserves bit contracts with itemMask', (tester) async {
    int changedBitmask = 0;
    final items = List.generate(8, (i) => RKToggleItem(onLabel: 'Btn$i'));

    // itemMask 0x0B = 0b00001011 (items 0, 1, 3 visible; item 2 hidden)
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Scaffold(
            body: Center(
              child: RKMultiSelect(
                items: items,
                bitmask: 0x01, // Item 0 selected
                itemMask: 0x0B,
                onChanged: (val) => changedBitmask = val,
              ),
            ),
          ),
        ),
      ),
    );

    // Visible buttons: BTN0, BTN1, BTN3. Hidden: BTN2, BTN4..BTN7.
    expect(find.text('BTN0'), findsOneWidget);
    expect(find.text('BTN1'), findsOneWidget);
    expect(find.text('BTN3'), findsOneWidget);
    expect(find.text('BTN2'), findsNothing);
    expect(find.text('BTN4'), findsNothing);

    // Tap BTN3 (index 3). Should toggle bit 3 (0x08). Since bitmask was 0x01, new val is 0x01 ^ 0x08 = 0x09.
    await tester.tap(find.text('BTN3'));
    expect(changedBitmask, equals(0x09));
  });

  testWidgets('RKMultiButton filters visible items and returns original index with itemMask', (tester) async {
    int changedIndex = -1;
    final items = List.generate(8, (i) => RKToggleItem(onLabel: 'L$i'));

    // itemMask 0x0A = 0b00001010 (items 1, 3 visible)
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.dragon,
          child: Scaffold(
            body: Center(
              child: RKMultiButton(
                items: items,
                selected: 1,
                itemMask: 0x0A,
                onChanged: (val) => changedIndex = val,
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('L1'), findsOneWidget);
    expect(find.text('L3'), findsOneWidget);
    expect(find.text('L0'), findsNothing);
    expect(find.text('L2'), findsNothing);

    // Tap L3 (index 3). Should return original index 3.
    await tester.tap(find.text('L3'));
    expect(changedIndex, equals(3));
  });
}
