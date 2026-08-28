import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:radiokit/screens/designer/widgets/designer_inspector.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Multi-item editor in DesignerInspector', () {
    testWidgets('renders items list with header counter and Add button',
        (tester) async {
      final state = DesignerState();
      state.addElement(
        DesignerElementType.multiButton,
        10,
        10,
        width: 120,
        height: 60,
      );
      final el = state.elements.last;
      state.updateElementProperty(el.id, 'itemCount', 3);
      state.updateElementProperty(el.id, 'items', [
        {'onLabel': 'A', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        {'onLabel': 'B', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        {'onLabel': 'C', 'onIcon': null, 'offLabel': null, 'offIcon': null},
      ]);
      state.selectElement(el.id);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 800,
                child: ListenableBuilder(
                  listenable: state,
                  builder: (context, _) => DesignerInspector(state: state),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ITEMS (3/8)'), findsOneWidget);
      expect(find.text('ADD'), findsOneWidget);
      expect(find.text('ITEM 1'), findsOneWidget);
      expect(find.text('ITEM 2'), findsOneWidget);
      expect(find.text('ITEM 3'), findsOneWidget);
    });

    testWidgets('tapping ADD button appends a new item and updates state',
        (tester) async {
      final state = DesignerState();
      state.addElement(
        DesignerElementType.multiButton,
        10,
        10,
        width: 120,
        height: 60,
      );
      final el = state.elements.last;
      state.updateElementProperty(el.id, 'itemCount', 3);
      state.updateElementProperty(el.id, 'items', [
        {'onLabel': 'A', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        {'onLabel': 'B', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        {'onLabel': 'C', 'onIcon': null, 'offLabel': null, 'offIcon': null},
      ]);
      state.selectElement(el.id);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 800,
                child: ListenableBuilder(
                  listenable: state,
                  builder: (context, _) => DesignerInspector(state: state),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('ADD'));
      await tester.pumpAndSettle();

      final updatedEl = state.elements.firstWhere((e) => e.id == el.id);
      expect(updatedEl.properties['itemCount'], 4);
      final items = updatedEl.properties['items'] as List;
      expect(items.length, 4);
      expect(items[3]['onLabel'], 'D');
      expect(find.text('ITEMS (4/8)'), findsOneWidget);
      expect(find.text('ITEM 4'), findsOneWidget);
    });

    testWidgets('tapping delete button removes middle item and updates count',
        (tester) async {
      final state = DesignerState();
      state.addElement(
        DesignerElementType.multiButton,
        10,
        10,
        width: 120,
        height: 60,
      );
      final el = state.elements.last;
      state.updateElementProperty(el.id, 'itemCount', 3);
      state.updateElementProperty(el.id, 'items', [
        {'onLabel': 'First', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        {'onLabel': 'Second', 'onIcon': null, 'offLabel': null, 'offIcon': null},
        {'onLabel': 'Third', 'onIcon': null, 'offLabel': null, 'offIcon': null},
      ]);
      state.selectElement(el.id);

      await tester.pumpWidget(
        RKTheme(
          tokens: RKTokens.dragon,
          child: MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 320,
                height: 800,
                child: ListenableBuilder(
                  listenable: state,
                  builder: (context, _) => DesignerInspector(state: state),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find trash icons in items (there's 1 delete button in TRANSFORM section + 3 in items = 4 total)
      final trashFinder = find.byIcon(PhosphorIconsFill.trash);
      expect(trashFinder, findsWidgets);

      // In items list, trash icons are for item 1, 2, 3
      await tester.tap(trashFinder.at(1));
      await tester.pumpAndSettle();

      final updatedEl = state.elements.firstWhere((e) => e.id == el.id);
      expect(updatedEl.properties['itemCount'], 2);
      final items = updatedEl.properties['items'] as List;
      expect(items.length, 2);
      expect(items[0]['onLabel'], 'First');
      expect(items[1]['onLabel'], 'Third');
      expect(find.text('ITEMS (2/8)'), findsOneWidget);
    });
  });
}
