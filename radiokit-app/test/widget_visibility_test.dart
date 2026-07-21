import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:radiokit/models/widget_config.dart';

void main() {
  group('CanvasElement hidden rendering', () {
    test('hidden element returns SizedBox.shrink in play mode', () {
      final state = DesignerState();
      state.togglePlayMode();
      state.addElement(DesignerElementType.button, 10, 10, width: 40, height: 40);
      final elId = state.elements.first.id;
      state.setElementHidden(elId, true);

      expect(state.elements.first.hidden, isTrue);
    });

    test('hidden element returns SizedBox.shrink in designer mode', () {
      final state = DesignerState();
      state.addElement(DesignerElementType.button, 10, 10, width: 40, height: 40);
      final elId = state.elements.first.id;
      state.setElementHidden(elId, true);

      expect(state.elements.first.hidden, isTrue);
    });
  });

  group('DesignerState.setElementHidden', () {
    test('sets hidden flag on element', () {
      final state = DesignerState();
      state.addElement(DesignerElementType.button, 10, 10, width: 40, height: 40);
      final elId = state.elements.first.id;

      expect(state.elements.first.hidden, isFalse);
      state.setElementHidden(elId, true);
      expect(state.elements.first.hidden, isTrue);
    });

    test('does not push undo', () {
      final state = DesignerState();
      state.addElement(DesignerElementType.button, 10, 10, width: 40, height: 40);
      final elId = state.elements.first.id;

      state.setElementHidden(elId, true);

      // canUndo is from addElement, not from setHidden
      expect(state.canUndo, isTrue);
      state.undo();
      // After undo, element should be gone (undid addElement)
      expect(state.elements, isEmpty);
    });

    test('no-op for nonexistent id', () {
      final state = DesignerState();
      state.addElement(DesignerElementType.button, 10, 10, width: 40, height: 40);

      // Should not throw
      state.setElementHidden('nonexistent', true);
      expect(state.elements.length, 1);
    });

    test('notifyListeners is called', () {
      final state = DesignerState();
      state.addElement(DesignerElementType.button, 10, 10, width: 40, height: 40);
      final elId = state.elements.first.id;

      var notified = false;
      state.addListener(() => notified = true);

      state.setElementHidden(elId, true);
      expect(notified, isTrue);
    });

    test('can toggle back to visible', () {
      final state = DesignerState();
      state.addElement(DesignerElementType.button, 10, 10, width: 40, height: 40);
      final elId = state.elements.first.id;

      state.setElementHidden(elId, true);
      expect(state.elements.first.hidden, isTrue);

      state.setElementHidden(elId, false);
      expect(state.elements.first.hidden, isFalse);
    });
  });

  group('WidgetConfig hidden field', () {
    test('defaults to false', () {
      const config = WidgetConfig(
        typeId: 1,
        widgetId: 1,
        x: 10,
        y: 10,
        width: 40,
        height: 40,
      );
      expect(config.hidden, isFalse);
    });

    test('copyWith preserves hidden', () {
      const config = WidgetConfig(
        typeId: 1,
        widgetId: 1,
        x: 10,
        y: 10,
        width: 40,
        height: 40,
        hidden: true,
      );
      final copied = config.copyWith(label: 'test');
      expect(copied.hidden, isTrue);
    });

    test('copyWith can change hidden', () {
      const config = WidgetConfig(
        typeId: 1,
        widgetId: 1,
        x: 10,
        y: 10,
        width: 40,
        height: 40,
        hidden: true,
      );
      final copied = config.copyWith(hidden: false);
      expect(copied.hidden, isFalse);
    });
  });
}
