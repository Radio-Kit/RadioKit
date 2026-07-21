import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

void main() {
  group('DesignerPage.effectiveIsLandscape', () {
    test('returns true when override is null (defaults to global)', () {
      final page = DesignerPage(name: 'Test');
      expect(page.effectiveIsLandscape(true), isTrue);
      expect(page.effectiveIsLandscape(false), isFalse);
    });

    test('returns true when override is global and global is true', () {
      final page = DesignerPage(name: 'Test', orientationOverride: 'global');
      expect(page.effectiveIsLandscape(true), isTrue);
    });

    test('returns false when override is global and global is false', () {
      final page = DesignerPage(name: 'Test', orientationOverride: 'global');
      expect(page.effectiveIsLandscape(false), isFalse);
    });

    test('returns true when override is landscape', () {
      final page = DesignerPage(name: 'Test', orientationOverride: 'landscape');
      expect(page.effectiveIsLandscape(true), isTrue);
      expect(page.effectiveIsLandscape(false), isTrue);
    });

    test('returns false when override is portrait', () {
      final page = DesignerPage(name: 'Test', orientationOverride: 'portrait');
      expect(page.effectiveIsLandscape(true), isFalse);
      expect(page.effectiveIsLandscape(false), isFalse);
    });
  });

  group('DesignerPage JSON serialization', () {
    test('toJson emits override value when set', () {
      final page = DesignerPage(
        name: 'Test',
        orientationOverride: 'portrait',
        isLandscape: true,
      );
      final json = page.toJson();
      expect(json['orientation'], 'portrait');
    });

    test('toJson emits global when override is null', () {
      final page = DesignerPage(name: 'Test', isLandscape: true);
      final json = page.toJson();
      expect(json['orientation'], 'global');
    });

    test('toJson emits global when isLandscape is false and override is null', () {
      final page = DesignerPage(name: 'Test', isLandscape: false);
      final json = page.toJson();
      expect(json['orientation'], 'global');
    });

    test('fromJson reads global override', () {
      final json = {'name': 'Test', 'orientation': 'global', 'widgets': []};
      final page = DesignerPage.fromJson(json);
      expect(page.orientationOverride, 'global');
    });

    test('fromJson reads landscape override', () {
      final json = {'name': 'Test', 'orientation': 'landscape', 'widgets': []};
      final page = DesignerPage.fromJson(json);
      expect(page.orientationOverride, 'landscape');
      expect(page.isLandscape, isTrue);
    });

    test('fromJson reads portrait override', () {
      final json = {'name': 'Test', 'orientation': 'portrait', 'widgets': []};
      final page = DesignerPage.fromJson(json);
      expect(page.orientationOverride, 'portrait');
      expect(page.isLandscape, isFalse);
    });

    test('fromJson defaults to global when orientation is missing', () {
      final json = {'name': 'Test', 'widgets': []};
      final page = DesignerPage.fromJson(json);
      expect(page.orientationOverride, 'global');
    });

    test('fromJson defaults to global when orientation is null', () {
      final json = {'name': 'Test', 'orientation': null, 'widgets': []};
      final page = DesignerPage.fromJson(json);
      expect(page.orientationOverride, 'global');
    });
  });

  group('DesignerPage.copyWith', () {
    test('copies with new orientationOverride', () {
      final original = DesignerPage(
        name: 'Original',
        orientationOverride: 'global',
      );
      final copy = original.copyWith(orientationOverride: 'portrait');
      expect(copy.orientationOverride, 'portrait');
      expect(copy.name, 'Original');
    });

    test('preserves orientationOverride when not specified', () {
      final original = DesignerPage(
        name: 'Original',
        orientationOverride: 'landscape',
      );
      final copy = original.copyWith(name: 'New Name');
      expect(copy.orientationOverride, 'landscape');
      expect(copy.name, 'New Name');
    });
  });

  group('DesignerState orientation methods', () {
    test('setPageOrientationOverride sets override on active page', () {
      final state = DesignerState();
      state.setPageOrientationOverride('portrait');
      expect(state.activePage.orientationOverride, 'portrait');
    });

    test('setGlobalOrientation updates globalIsLandscape', () {
      final state = DesignerState();
      expect(state.globalIsLandscape, isTrue);
      state.setGlobalOrientation(false);
      expect(state.globalIsLandscape, isFalse);
    });

    test('addPage defaults orientationOverride to global', () {
      final state = DesignerState();
      state.addPage(name: 'New Page');
      state.setActivePage(1);
      expect(state.activePage.orientationOverride, 'global');
    });

    test('toJson includes global orientation in canvas', () {
      final state = DesignerState();
      state.setGlobalOrientation(false);
      final json = state.toJson();
      expect(json['canvas']['orientation'], 'portrait');
    });

    test('loadFromJson reads global orientation from canvas', () {
      final state = DesignerState();
      final json = {
        'version': 2,
        'canvas': {'orientation': 'portrait'},
        'pages': [
          {'name': 'Page 1', 'orientation': 'global', 'widgets': []},
        ],
      };
      state.loadFromJson(json);
      expect(state.globalIsLandscape, isFalse);
    });
  });

  group('showControlPageBar', () {
    test('defaults to true', () {
      final state = DesignerState();
      expect(state.showControlPageBar, isTrue);
    });

    test('toggle flips value', () {
      final state = DesignerState();
      expect(state.showControlPageBar, isTrue);
      state.toggleControlPageBar();
      expect(state.showControlPageBar, isFalse);
      state.toggleControlPageBar();
      expect(state.showControlPageBar, isTrue);
    });

    test('toJson includes showControlPageBar in canvas', () {
      final state = DesignerState();
      final json = state.toJson();
      expect(json['canvas']['showControlPageBar'], isTrue);
    });

    test('toJson reflects toggled value', () {
      final state = DesignerState();
      state.toggleControlPageBar();
      final json = state.toJson();
      expect(json['canvas']['showControlPageBar'], isFalse);
    });

    test('loadFromJson reads showControlPageBar from canvas', () {
      final state = DesignerState();
      final json = {
        'version': 2,
        'canvas': {'showControlPageBar': false},
        'pages': [
          {'name': 'Page 1', 'orientation': 'global', 'widgets': []},
        ],
      };
      state.loadFromJson(json);
      expect(state.showControlPageBar, isFalse);
    });

    test('loadFromJson defaults showControlPageBar to true when missing', () {
      final state = DesignerState();
      state.toggleControlPageBar(); // set to false first
      final json = {
        'version': 2,
        'canvas': {},
        'pages': [
          {'name': 'Page 1', 'orientation': 'global', 'widgets': []},
        ],
      };
      state.loadFromJson(json);
      expect(state.showControlPageBar, isTrue);
    });

    test('round-trip serialization preserves showControlPageBar', () {
      final state = DesignerState();
      state.toggleControlPageBar();
      final json = state.toJson();
      final state2 = DesignerState();
      state2.loadFromJson(json);
      expect(state2.showControlPageBar, state.showControlPageBar);
    });
  });

  group('Telemetry', () {
    test('defaults to empty list', () {
      final state = DesignerState();
      expect(state.telemetryWidgets, isEmpty);
    });

    test('addTelemetrySlot appends a slot (max 4)', () {
      final state = DesignerState();
      state.addTelemetrySlot();
      state.addTelemetrySlot();
      state.addTelemetrySlot();
      state.addTelemetrySlot();
      expect(state.telemetryWidgets.length, 4);
      // Fifth add is ignored
      state.addTelemetrySlot();
      expect(state.telemetryWidgets.length, 4);
    });

    test('removeTelemetrySlot removes at index', () {
      final state = DesignerState();
      state.addTelemetrySlot();
      state.addTelemetrySlot();
      state.setTelemetryLabel(0, 'Speed');
      state.removeTelemetrySlot(0);
      expect(state.telemetryWidgets.length, 1);
      expect(state.telemetryWidgets[0]['label'], '');
    });

    test('toJson emits variable-length telemetry array', () {
      final state = DesignerState();
      state.addTelemetrySlot();
      state.setTelemetryLabel(0, 'Speed');
      state.setTelemetryUnit(0, 'km/h');
      final json = state.toJson();
      final telemetry = json['telemetry'] as List;
      expect(telemetry.length, 1);
      expect(telemetry[0]['label'], 'Speed');
      expect(telemetry[0]['unit'], 'km/h');
    });

    test('toJson with no telemetry emits empty array', () {
      final state = DesignerState();
      final json = state.toJson();
      expect(json['telemetry'], isEmpty);
    });

    test('loadFromJson normalizes legacy 4-element array (strips trailing empties)', () {
      final state = DesignerState();
      final json = {
        'version': 2,
        'telemetry': [
          {'label': 'Speed', 'icon': null, 'unit': 'km/h'},
          {'label': '', 'icon': null, 'unit': ''},
          {'label': '', 'icon': null, 'unit': ''},
          {'label': '', 'icon': null, 'unit': ''},
        ],
        'pages': [
          {'name': 'Page 1', 'orientation': 'global', 'widgets': []},
        ],
      };
      state.loadFromJson(json);
      expect(state.telemetryWidgets.length, 1);
      expect(state.telemetryWidgets[0]['label'], 'Speed');
    });

    test('loadFromJson preserves variable-length array', () {
      final state = DesignerState();
      final json = {
        'version': 2,
        'telemetry': [
          {'label': 'Speed', 'icon': 'gauge', 'unit': 'km/h'},
          {'label': 'Battery', 'icon': 'battery', 'unit': '%'},
        ],
        'pages': [
          {'name': 'Page 1', 'orientation': 'global', 'widgets': []},
        ],
      };
      state.loadFromJson(json);
      expect(state.telemetryWidgets.length, 2);
      expect(state.telemetryWidgets[1]['label'], 'Battery');
    });

    test('undo supports telemetry mutations', () {
      final state = DesignerState();
      state.addTelemetrySlot();
      state.setTelemetryLabel(0, 'Speed');
      expect(state.telemetryWidgets[0]['label'], 'Speed');
      // Two undos: first reverts label, second reverts the add
      state.undo();
      expect(state.telemetryWidgets[0]['label'], '');
      state.undo();
      expect(state.telemetryWidgets, isEmpty);
    });

    test('reorderTelemetrySlot moves item to new position', () {
      final state = DesignerState();
      state.addTelemetrySlot();
      state.addTelemetrySlot();
      state.addTelemetrySlot();
      state.setTelemetryLabel(0, 'A');
      state.setTelemetryLabel(1, 'B');
      state.setTelemetryLabel(2, 'C');
      state.reorderTelemetrySlot(0, 2);
      expect(state.telemetryWidgets[0]['label'], 'B');
      expect(state.telemetryWidgets[1]['label'], 'C');
      expect(state.telemetryWidgets[2]['label'], 'A');
    });

    test('reorderTelemetrySlot is undoable', () {
      final state = DesignerState();
      state.addTelemetrySlot();
      state.addTelemetrySlot();
      state.setTelemetryLabel(0, 'Speed');
      state.setTelemetryLabel(1, 'Battery');
      state.reorderTelemetrySlot(0, 1);
      expect(state.telemetryWidgets[0]['label'], 'Battery');
      expect(state.telemetryWidgets[1]['label'], 'Speed');
      state.undo();
      expect(state.telemetryWidgets[0]['label'], 'Speed');
      expect(state.telemetryWidgets[1]['label'], 'Battery');
    });

    test('reorderTelemetrySlot no-ops when oldIndex equals newIndex', () {
      final state = DesignerState();
      state.addTelemetrySlot();
      state.setTelemetryLabel(0, 'Speed');
      state.reorderTelemetrySlot(0, 0);
      expect(state.telemetryWidgets[0]['label'], 'Speed');
      expect(state.telemetryWidgets.length, 1);
    });
  });
}
