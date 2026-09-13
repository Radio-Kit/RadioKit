import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:radiokit/widgets/help/help_badge.dart';
import 'package:radiokit/widgets/help/help_bottom_sheet.dart';
import 'package:radiokit/widgets/help/help_content.dart';
import 'package:radiokit/widgets/help/hardware_troubleshooting.dart';
import 'package:radiokit/widgets/help/spotlight_tour.dart';

void main() {
  Widget buildTestable(Widget child) {
    return RKTheme(
      tokens: RKTokens.dragon,
      child: MaterialApp(
        theme: ThemeData.dark(),
        home: Scaffold(body: child),
      ),
    );
  }

  group('HelpBadge and HelpBottomSheet', () {
    testWidgets('renders HelpBadge and opens bottom sheet on tap', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const Center(
            child: HelpBadge(topic: HelpTopics.baudRate),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('?'), findsOneWidget);

      await tester.tap(find.byType(HelpBadge));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HelpBottomSheet), findsOneWidget);
      expect(find.text('SERIAL BAUD RATE'), findsOneWidget);
      expect(find.text('GOT IT'), findsOneWidget);

      await tester.tap(find.text('GOT IT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(HelpBottomSheet), findsNothing);
    });
  });

  group('Hardware Troubleshooting Widgets', () {
    testWidgets('DiscoveryDiagnosticChecklist renders checklist and handles scan', (tester) async {
      bool scanCalled = false;
      await tester.pumpWidget(
        buildTestable(
          DiscoveryDiagnosticChecklist(
            onScanAgain: () => scanCalled = true,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('HARDWARE_CHECKLIST'), findsOneWidget);
      expect(find.text('Bluetooth & Permissions'), findsOneWidget);
      expect(find.text('USB Data Cable'), findsOneWidget);
      expect(find.text('RESCAN'), findsOneWidget);

      await tester.tap(find.text('RESCAN'));
      await tester.pump();

      expect(scanCalled, isTrue);
    });

    testWidgets('BootloaderGuideDialog steps through sequence', (tester) async {
      await tester.pumpWidget(
        buildTestable(
          const BootloaderGuideDialog(),
        ),
      );
      await tester.pump();

      expect(find.text('ESP32 BOOTLOADER SEQUENCE'), findsOneWidget);
      expect(find.text('HOLD BOOT BUTTON'), findsOneWidget);
      expect(find.text('NEXT STEP'), findsOneWidget);

      await tester.tap(find.text('NEXT STEP'));
      await tester.pump();

      expect(find.text('CLICK EN / RESET'), findsOneWidget);

      await tester.tap(find.text('NEXT STEP'));
      await tester.pump();

      expect(find.text('RELEASE BOOT'), findsOneWidget);
      expect(find.text('READY TO FLASH'), findsOneWidget);
    });
  });

  group('SpotlightTour', () {
    testWidgets('runs through spotlight tour and completes', (tester) async {
      final key1 = GlobalKey();
      final key2 = GlobalKey();
      bool tourFinished = false;

      late SpotlightTour tour;

      await tester.pumpWidget(
        buildTestable(
          Builder(
            builder: (context) {
              return Column(
                children: [
                  Container(key: key1, width: 100, height: 40, child: const Text('Target 1')),
                  Container(key: key2, width: 100, height: 40, child: const Text('Target 2')),
                  ElevatedButton(
                    onPressed: () {
                      tour = SpotlightTour(
                        context: context,
                        tourId: 'test_tour',
                        steps: [
                          SpotlightStep(
                            targetKey: key1,
                            title: 'Step 1',
                            description: 'First target',
                          ),
                          SpotlightStep(
                            targetKey: key2,
                            title: 'Step 2',
                            description: 'Second target',
                          ),
                        ],
                        onComplete: () => tourFinished = true,
                      );
                      tour.start();
                    },
                    child: const Text('Start Tour'),
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Start Tour'));
      await tester.pump();

      expect(find.text('STEP 1'), findsOneWidget);
      expect(find.text('First target'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);

      await tester.tap(find.text('NEXT'));
      await tester.pump();

      expect(find.text('STEP 2'), findsOneWidget);
      expect(find.text('DONE'), findsOneWidget);

      await tester.tap(find.text('DONE'));
      await tester.pump();

      expect(tourFinished, isTrue);
      expect(find.text('STEP 2'), findsNothing);
    });
  });
}
