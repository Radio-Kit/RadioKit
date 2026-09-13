import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('SettingsProvider', () {
    test('initializes with default values', () {
      final provider = SettingsProvider();
      expect(provider.useFullscreen, isTrue);
      expect(provider.enableRemoteAccess, isFalse);
      expect(provider.followRemoteAccess, isFalse);
      expect(provider.overrideTheme, isFalse);
    });

    test('updates and persists settings', () async {
      final provider = SettingsProvider();
      await provider.setUseFullscreen(false);
      await provider.setEnableRemoteAccess(true);
      await provider.setFollowRemoteAccess(true);
      await provider.setOverrideTheme(true);

      expect(provider.useFullscreen, isFalse);
      expect(provider.enableRemoteAccess, isTrue);
      expect(provider.followRemoteAccess, isTrue);
      expect(provider.overrideTheme, isTrue);
    });

    test('manages spotlight tour flags and reset', () async {
      final provider = SettingsProvider();
      expect(provider.hasSeenModelsTour, isFalse);
      expect(provider.hasSeenFlasherTour, isFalse);
      expect(provider.hasSeenDesignerTour, isFalse);
      expect(provider.hasSeenTour('models'), isFalse);

      await provider.markTourSeen('models');
      await provider.markTourSeen('flasher');
      await provider.markTourSeen('designer');

      expect(provider.hasSeenModelsTour, isTrue);
      expect(provider.hasSeenFlasherTour, isTrue);
      expect(provider.hasSeenDesignerTour, isTrue);
      expect(provider.hasSeenTour('models'), isTrue);

      await provider.resetHelpGuides();
      expect(provider.hasSeenModelsTour, isFalse);
      expect(provider.hasSeenFlasherTour, isFalse);
      expect(provider.hasSeenDesignerTour, isFalse);
    });
  });
}
