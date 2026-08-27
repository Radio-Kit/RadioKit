import 'package:flutter_test/flutter_test.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';
import 'package:radiokit/screens/home/design_preview.dart';

void main() {
  // Dragon primary = 0xFFFA9700 (orange), Matrix primary = 0xFF19C63C (green).
  // These distinct colors let us verify which skin is resolved.

  group('DesignPreview.resolveTokens', () {
    test('returns design skin tokens when overrideTheme is false and skin is not default', () {
      final result = DesignPreview.resolveTokens(
        overrideTheme: false,
        skin: 'matrix',
        fallbackTokens: RKTokens.dragon,
      );
      expect(result.primary, RKTokens.matrix.primary);
    });

    test('returns fallback tokens when overrideTheme is true', () {
      final result = DesignPreview.resolveTokens(
        overrideTheme: true,
        skin: 'matrix',
        fallbackTokens: RKTokens.dragon,
      );
      expect(result.primary, RKTokens.dragon.primary);
    });

    test('returns fallback tokens when skin is default', () {
      final result = DesignPreview.resolveTokens(
        overrideTheme: false,
        skin: 'default',
        fallbackTokens: RKTokens.dragon,
      );
      expect(result.primary, RKTokens.dragon.primary);
    });

    test('returns fallback tokens when both overrideTheme is true and skin is default', () {
      final result = DesignPreview.resolveTokens(
        overrideTheme: true,
        skin: 'default',
        fallbackTokens: RKTokens.dragon,
      );
      expect(result.primary, RKTokens.dragon.primary);
    });

    test('returns fallback tokens when skin is not found in presets', () {
      final result = DesignPreview.resolveTokens(
        overrideTheme: false,
        skin: 'nonexistent',
        fallbackTokens: RKTokens.dragon,
      );
      expect(result.primary, RKTokens.dragon.primary,
          reason: 'Should fall back when skin name is unknown');
    });

    test('returns fallback tokens when skin is empty string', () {
      final result = DesignPreview.resolveTokens(
        overrideTheme: false,
        skin: '',
        fallbackTokens: RKTokens.dragon,
      );
      expect(result.primary, RKTokens.dragon.primary,
          reason: 'Empty skin is not default so it tries presets, falls back');
    });

    test('works with all built-in presets', () {
      for (final entry in RKTokens.presetsByName.entries) {
        final result = DesignPreview.resolveTokens(
          overrideTheme: false,
          skin: entry.key,
          fallbackTokens: RKTokens.dragon,
        );
        expect(result.primary, entry.value.primary,
            reason: 'Skin "${entry.key}" should resolve to its own tokens');
      }
    });

    test('overrideTheme forces fallback for every preset', () {
      for (final entry in RKTokens.presetsByName.entries) {
        final result = DesignPreview.resolveTokens(
          overrideTheme: true,
          skin: entry.key,
          fallbackTokens: RKTokens.dragon,
        );
        expect(result.primary, RKTokens.dragon.primary,
            reason: 'Skin "${entry.key}" should be ignored when overrideTheme is true');
      }
    });
  });
}
