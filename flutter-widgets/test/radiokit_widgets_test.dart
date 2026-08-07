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
}
