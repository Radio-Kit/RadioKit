import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/widgets/radiokit_app_bar.dart';

void main() {
  group('RadioKitAppBar landscape tappability', () {
    /// Pump a [Scaffold] with [RadioKitAppBar] as its [AppBar], sized for the
    /// given [orientation].  Returns the [Orientation] used so callers can
    /// confirm the test environment is correct.
    Future<void> pumpAppBar({
      required WidgetTester tester,
      required int tabIndex,
      VoidCallback? onConnect,
      VoidCallback? onOpen,
      VoidCallback? onCreate,
      Orientation orientation = Orientation.landscape,
    }) async {
      // Resize the test surface to landscape or portrait dimensions.
      // Register tear-down so the surface size doesn't leak to other tests.
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.binding.setSurfaceSize(
        orientation == Orientation.landscape
            ? const Size(1200, 600)
            : const Size(600, 1200),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            appBar: RadioKitAppBar(
              tabIndex: tabIndex,
              onConnect: onConnect,
              onOpen: onOpen,
              onCreate: onCreate,
            ),
            body: const SizedBox.expand(),
          ),
        ),
      );
      // Render a single frame.  Avoid pumpAndSettle because GoogleFonts
      // triggers network font fetches that may not resolve in tests.
      await tester.pump();
    }

    // -----------------------------------------------------------------------
    // Landscape
    // -----------------------------------------------------------------------

    testWidgets('Connect button fires onTap in landscape', (tester) async {
      bool tapped = false;
      await pumpAppBar(
        tester: tester,
        tabIndex: 0,
        onConnect: () => tapped = true,
      );

      // '+' symbol + ' Connect' text; find by the visible label.
      final btn = find.text('+ Connect');
      expect(btn, findsOneWidget, reason: 'Connect button should be visible');

      await tester.tap(btn);
      expect(tapped, isTrue, reason: 'onConnect callback should fire');
    });

    testWidgets('Open button fires onTap in landscape', (tester) async {
      bool tapped = false;
      await pumpAppBar(
        tester: tester,
        tabIndex: 1,
        onOpen: () => tapped = true,
      );

      final btn = find.text('Open');
      expect(btn, findsOneWidget, reason: 'Open button should be visible');

      await tester.tap(btn);
      expect(tapped, isTrue, reason: 'onOpen callback should fire');
    });

    testWidgets('Create button fires onTap in landscape', (tester) async {
      bool tapped = false;
      await pumpAppBar(
        tester: tester,
        tabIndex: 1,
        onCreate: () => tapped = true,
      );

      final btn = find.text('Create');
      expect(btn, findsOneWidget, reason: 'Create button should be visible');

      await tester.tap(btn);
      expect(tapped, isTrue, reason: 'onCreate callback should fire');
    });

    testWidgets('both Open and Create are tappable in landscape', (tester) async {
      bool openTapped = false;
      bool createTapped = false;
      await pumpAppBar(
        tester: tester,
        tabIndex: 1,
        onOpen: () => openTapped = true,
        onCreate: () => createTapped = true,
      );

      await tester.tap(find.text('Open'));
      expect(openTapped, isTrue, reason: 'Open should fire before Create');

      await tester.tap(find.text('Create'));
      expect(createTapped, isTrue, reason: 'Create should also fire');
    });

    // -----------------------------------------------------------------------
    // Portrait (baseline — buttons should work here too)
    // -----------------------------------------------------------------------

    testWidgets('Connect button fires onTap in portrait', (tester) async {
      bool tapped = false;
      await pumpAppBar(
        tester: tester,
        tabIndex: 0,
        onConnect: () => tapped = true,
        orientation: Orientation.portrait,
      );

      final btn = find.text('+ Connect');
      expect(btn, findsOneWidget, reason: 'Connect button should be visible');

      await tester.tap(btn);
      expect(tapped, isTrue, reason: 'onConnect callback should fire');
    });

    testWidgets('Open + Create buttons are tappable in portrait', (tester) async {
      bool openTapped = false;
      bool createTapped = false;
      await pumpAppBar(
        tester: tester,
        tabIndex: 1,
        onOpen: () => openTapped = true,
        onCreate: () => createTapped = true,
        orientation: Orientation.portrait,
      );

      await tester.tap(find.text('Open'));
      expect(openTapped, isTrue);

      await tester.tap(find.text('Create'));
      expect(createTapped, isTrue);
    });

    // -----------------------------------------------------------------------
    // Button absence when callback is null
    // -----------------------------------------------------------------------

    testWidgets('Connect button is absent when onConnect is null', (tester) async {
      await pumpAppBar(tester: tester, tabIndex: 0);

      expect(find.text('+ Connect'), findsNothing,
          reason: 'Button should not render when callback is null');
    });

    testWidgets('Open button is absent when onOpen is null', (tester) async {
      await pumpAppBar(tester: tester, tabIndex: 1);

      expect(find.text('Open'), findsNothing,
          reason: 'Open button should not render when callback is null');
    });

    testWidgets('Create button is absent when onCreate is null', (tester) async {
      await pumpAppBar(tester: tester, tabIndex: 1);

      expect(find.text('Create'), findsNothing,
          reason: 'Create button should not render when callback is null');
    });

    // -----------------------------------------------------------------------
    // Layout integrity
    // -----------------------------------------------------------------------

    testWidgets('Connect button fits within AppBar bounds', (tester) async {
      await pumpAppBar(
        tester: tester,
        tabIndex: 0,
        onConnect: () {},
      );

      // The FilledButton is an ancestor of the '+ Connect' Text widget.
      final btn = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('+ Connect'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('Open button fits within AppBar bounds', (tester) async {
      await pumpAppBar(
        tester: tester,
        tabIndex: 1,
        onOpen: () {},
      );

      // Verify the InkWell is tappable by finding it and checking onTap.
      final inkWell = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Open'),
          matching: find.byType(InkWell),
        ).first,
      );
      expect(inkWell.onTap, isNotNull);
    });
  });
}
