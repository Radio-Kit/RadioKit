import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:radiokit/widgets/back_button_dispatcher.dart';

void main() {
  late ModalRouteTracker tracker;
  late RadioKitBackDispatcher dispatcher;
  late GoRouter router;

  Widget buildApp() {
    return MaterialApp.router(
      routerDelegate: router.routerDelegate,
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      backButtonDispatcher: dispatcher,
    );
  }

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(buildApp());
    await tester.pumpAndSettle();
  }

  group('RadioKitBackDispatcher', () {
    setUp(() {
      tracker = ModalRouteTracker();
      dispatcher = RadioKitBackDispatcher(tracker: tracker);
      router = GoRouter(
        initialLocation: '/home',
        observers: [tracker],
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => showModalBottomSheet<void>(
                        context: context,
                        builder: (_) => const SizedBox(
                          height: 200,
                          child: Center(child: Text('open sheet')),
                        ),
                      ),
                      child: const Text('open sheet button'),
                    ),
                    TextButton(
                      onPressed: () => context.push('/detail'),
                      child: const Text('push detail'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/detail',
            builder: (context, state) =>
                const Scaffold(body: Center(child: Text('detail page'))),
          ),
        ],
      );
    });

    testWidgets('pops an open modal and consumes the back event',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('open sheet button'));
      await tester.pumpAndSettle();
      expect(find.text('open sheet'), findsOneWidget);
      expect(tracker.topModal, isNotNull);

      final handled = await dispatcher.didPopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue,
          reason: 'dispatcher must consume the back when a modal is open');
      expect(find.text('open sheet'), findsNothing);
      expect(tracker.topModal, isNull);
      // The page below must be unaffected.
      expect(find.text('open sheet button'), findsOneWidget);
    });

    testWidgets('delegates to the navigator when no modal is open',
        (tester) async {
      await pumpApp(tester);

      // Push a page (no modal) — back should pop the page, not exit.
      await tester.tap(find.text('push detail'));
      await tester.pumpAndSettle();
      expect(find.text('detail page'), findsOneWidget);
      expect(tracker.topModal, isNull);

      final handled = await dispatcher.didPopRoute();
      await tester.pumpAndSettle();

      expect(handled, isTrue);
      expect(find.text('detail page'), findsNothing);
      expect(find.text('open sheet button'), findsOneWidget);
    });

    testWidgets('returns false on a root page with nothing to pop',
        (tester) async {
      await pumpApp(tester);
      expect(tracker.topModal, isNull);

      final handled = await dispatcher.didPopRoute();
      await tester.pumpAndSettle();

      // Nothing to pop — false signals the framework it may exit the app.
      expect(handled, isFalse);
    });

    testWidgets('tracker removes swipe-dismissed sheets from its stack',
        (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('open sheet button'));
      await tester.pumpAndSettle();
      expect(tracker.topModal, isNotNull);

      // Tap the barrier to dismiss the sheet.
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();
      expect(find.text('open sheet'), findsNothing);
      expect(tracker.topModal, isNull,
          reason: 'stale modal must not remain tracked');
    });
  });
}
