import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:radiokit/screens/designer/widgets/designer_page_bar.dart';

/// Creates a DesignerState with exactly the given page names (no default page).
DesignerState _createStateWithPages(List<String> names) {
  final state = DesignerState();
  // Default state has one page "Page 1" — rename it to the first name
  state.renamePage(0, names.first);
  // Add remaining pages
  for (int i = 1; i < names.length; i++) {
    state.addPage(name: names[i]);
  }
  return state;
}

void main() {
  group('DesignerPageBar tab rendering', () {
    testWidgets('renders tab buttons with page names', (tester) async {
      final state = _createStateWithPages(['Control', 'Settings']);
      state.setActivePage(0);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Control'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });

    testWidgets('active tab has primary color background', (tester) async {
      final state = _createStateWithPages(['Alpha', 'Beta']);
      state.setActivePage(0);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the active tab container (Alpha at index 0)
      final activeTab = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Alpha'),
          matching: find.byType(AnimatedContainer),
        ).first,
      );

      final decoration = activeTab.decoration as BoxDecoration;
      expect(decoration.color, equals(RKTokens.dragon.primary));
    });

    testWidgets('inactive tab has surface color background', (tester) async {
      final state = _createStateWithPages(['Alpha', 'Beta']);
      state.setActivePage(0);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pump();

      // Find the inactive tab container (Beta)
      final inactiveTab = tester.widget<AnimatedContainer>(
        find.ancestor(
          of: find.text('Beta'),
          matching: find.byType(AnimatedContainer),
        ).first,
      );

      final decoration = inactiveTab.decoration as BoxDecoration;
      expect(decoration.color, equals(RKTokens.dragon.surface));
    });

    testWidgets('tapping inactive tab switches active page', (tester) async {
      final state = _createStateWithPages(['Control', 'Settings']);
      state.setActivePage(0);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pump();

      // Initially on page 0 (Control)
      expect(state.activePageIndex, equals(0));

      // Tap the Settings tab (index 1)
      await tester.tap(find.text('Settings'));
      await tester.pump();

      // Should now be on page 1
      expect(state.activePageIndex, equals(1));
    });

    testWidgets('toggle button hides page bar', (tester) async {
      final state = DesignerState();

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Column(
                children: [
                  DesignerPageBar(state: state),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(state.showPageBar, isTrue);

      // Find the toggle button by its Lucide icon
      final toggleFinder = find.byIcon(PhosphorIconsFill.caretDown);
      expect(toggleFinder, findsOneWidget, reason: 'Toggle button should be visible');

      await tester.tap(toggleFinder);
      await tester.pump();

      expect(state.showPageBar, isFalse);
    });

    testWidgets('context menu shows on long press', (tester) async {
      final state = _createStateWithPages(['My Page']);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pump();

      // Long press on the tab
      await tester.longPress(find.text('My Page').first);
      await tester.pumpAndSettle();

      // Should show context menu with options
      expect(find.text('Rename Page'), findsOneWidget);
      expect(find.text('Duplicate Page'), findsOneWidget);
    });

    testWidgets('add page button adds a new page', (tester) async {
      final state = _createStateWithPages(['Page 1']);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(state.numPages, equals(1));

      // Find and tap the + button (PhosphorIconsFill.plus)
      await tester.tap(find.byIcon(PhosphorIconsFill.plus));
      await tester.pump();

      // Should have 2 pages now
      expect(state.numPages, equals(2));
    });
  });

  group('DesignerState showPageBar serialization', () {
    test('showPageBar defaults to true', () {
      final state = DesignerState();
      expect(state.showPageBar, isTrue);
    });

    test('togglePageBar flips showPageBar', () {
      final state = DesignerState();
      expect(state.showPageBar, isTrue);

      state.togglePageBar();
      expect(state.showPageBar, isFalse);

      state.togglePageBar();
      expect(state.showPageBar, isTrue);
    });

    test('toJson includes showPageBar in canvas', () {
      final state = DesignerState();
      final json = state.toJson();

      expect(json['canvas']['showPageBar'], isTrue);
    });

    test('toJson reflects toggled showPageBar', () {
      final state = DesignerState();
      state.togglePageBar();

      final json = state.toJson();
      expect(json['canvas']['showPageBar'], isFalse);
    });

    test('loadFromJson reads showPageBar from canvas', () {
      final state = DesignerState();
      expect(state.showPageBar, isTrue);

      state.loadFromJson({
        'version': 2,
        'canvas': {'showPageBar': false},
        'pages': [],
      });

      expect(state.showPageBar, isFalse);
    });

    test('loadFromJson defaults showPageBar to true when missing', () {
      final state = DesignerState();
      state.togglePageBar();
      expect(state.showPageBar, isFalse);

      state.loadFromJson({
        'version': 2,
        'canvas': {},
        'pages': [],
      });

      expect(state.showPageBar, isTrue);
    });

    test('loadFromJson defaults showPageBar to true for v1 format', () {
      final state = DesignerState();
      state.togglePageBar();

      state.loadFromJson({
        'version': 1,
        'widgets': [],
      });

      expect(state.showPageBar, isTrue);
    });

    test('round-trip serialization preserves showPageBar', () {
      final state = DesignerState();
      state.addPage(name: 'Test Page');
      state.togglePageBar();

      final json = state.toJson();
      final state2 = DesignerState();
      state2.loadFromJson(json);

      expect(state2.showPageBar, isFalse);
    });
  });

  group('DesignerPageBar orientation badge', () {
    testWidgets('shows badge when page has landscape override', (tester) async {
      final state = _createStateWithPages(['Control', 'Settings']);
      state.setActivePage(0);
      state.setPageOrientationOverride('landscape');

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find the rotate icon
      expect(find.byIcon(PhosphorIconsFill.arrowClockwise), findsOneWidget);
    });

    testWidgets('shows badge when page has portrait override', (tester) async {
      final state = _createStateWithPages(['Control', 'Settings']);
      state.setActivePage(0);
      state.setPageOrientationOverride('portrait');

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsFill.arrowClockwise), findsOneWidget);
    });

    testWidgets('hides badge when page has global override', (tester) async {
      final state = _createStateWithPages(['Control', 'Settings']);
      state.setActivePage(0);
      state.setPageOrientationOverride('global');

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsFill.arrowClockwise), findsNothing);
    });

    testWidgets('hides badge when override is null', (tester) async {
      final state = _createStateWithPages(['Control', 'Settings']);
      state.setActivePage(0);
      // Don't set any override

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: DesignerPageBar(state: state),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(PhosphorIconsFill.arrowClockwise), findsNothing);
    });
  });
}
