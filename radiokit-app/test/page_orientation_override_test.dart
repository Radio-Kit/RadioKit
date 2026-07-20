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
}
