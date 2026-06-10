import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('RKLed renders on state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RKTheme(
          tokens: RKTokens.neon,
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
          tokens: RKTokens.neon,
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
          tokens: RKTokens.neon,
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
}
