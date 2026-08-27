import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';
import 'package:radiokit_widgets/radiokit_widgets.dart';

/// The 26 Phosphor fill icons added for designer widgets, keyed by their
/// kebab-case name in kDesignerIcons.
const Map<String, IconData> kPhosphorFillEntries = {
  'caret-left': PhosphorIconsFill.caretLeft,
  'caret-right': PhosphorIconsFill.caretRight,
  'siren': PhosphorIconsFill.siren,
  'headlights': PhosphorIconsFill.headlights,
  'arrow-fat-left': PhosphorIconsFill.arrowFatLeft,
  'arrow-fat-right': PhosphorIconsFill.arrowFatRight,
  'warning': PhosphorIconsFill.warning,
  'fallout-shelter': PhosphorIconsFill.falloutShelter,
  'biohazard': PhosphorIconsFill.biohazard,
  'radioactive': PhosphorIconsFill.radioactive,
  'lightbulb-filament': PhosphorIconsFill.lightbulbFilament,
  'lighthouse': PhosphorIconsFill.lighthouse,
  'lightning': PhosphorIconsFill.lightning,
  'fire': PhosphorIconsFill.fire,
  'subway': PhosphorIconsFill.subway,
  'cable-car': PhosphorIconsFill.cableCar,
  'ghost': PhosphorIconsFill.ghost,
  'car-simple': PhosphorIconsFill.carSimple,
  'megaphone': PhosphorIconsFill.megaphone,
  'steering-wheel': PhosphorIconsFill.steeringWheel,
  'rewind': PhosphorIconsFill.rewind,
  'fast-forward': PhosphorIconsFill.fastForward,
  'bell': PhosphorIconsFill.bell,
  'bell-ringing': PhosphorIconsFill.bellRinging,
  'cat': PhosphorIconsFill.cat,
  'charging-station': PhosphorIconsFill.chargingStation,
};

/// Former Lucide keys now resolved to their Phosphor fill equivalents.
const Map<String, IconData> kFormerLucideToPhosphor = {
  'zap': PhosphorIconsFill.lightning,
  'zap-off': PhosphorIconsFill.lightningSlash,
  'sun': PhosphorIconsFill.sun,
  'moon': PhosphorIconsFill.moon,
  'battery-charging': PhosphorIconsFill.batteryCharging,
  'settings': PhosphorIconsFill.gearSix,
  'cog': PhosphorIconsFill.gear,
  'save': PhosphorIconsFill.floppyDisk,
  'search': PhosphorIconsFill.magnifyingGlass,
  'home': PhosphorIconsFill.house,
  'trash-2': PhosphorIconsFill.trash,
  'gamepad-2': PhosphorIconsFill.gameController,
  'alert-triangle': PhosphorIconsFill.warning,
  'help-circle': PhosphorIconsFill.question,
  'maximize-2': PhosphorIconsFill.arrowsOut,
  'minimize-2': PhosphorIconsFill.arrowsIn,
  'rotate-ccw': PhosphorIconsFill.arrowCounterClockwise,
  'rotate-cw': PhosphorIconsFill.arrowClockwise,
  'refresh-ccw': PhosphorIconsFill.arrowsCounterClockwise,
  'smartphone': PhosphorIconsFill.deviceMobile,
  'tablet': PhosphorIconsFill.deviceTablet,
  'video': PhosphorIconsFill.videoCamera,
  'music': PhosphorIconsFill.musicNote,
  'chevron-up': PhosphorIconsFill.caretUp,
  'chevron-down': PhosphorIconsFill.caretDown,
  'wifi': PhosphorIconsFill.wifiHigh,
};

void main() {
  group('kDesignerIcons multi-pack resolution', () {
    test('resolves Phosphor fill icons by kebab-case name', () {
      expect(iconFromName('steering-wheel'),
          PhosphorIconsFill.steeringWheel);
      expect(iconFromName('lightbulb-filament'),
          PhosphorIconsFill.lightbulbFilament);
      expect(iconFromName('charging-station'),
          PhosphorIconsFill.chargingStation);
    });

    test('former Lucide keys resolve to Phosphor fill equivalents', () {
      for (final entry in kFormerLucideToPhosphor.entries) {
        expect(kDesignerIcons.containsKey(entry.key), isTrue,
            reason: 'missing registry key: ${entry.key}');
        expect(kDesignerIcons[entry.key], entry.value,
            reason: 'wrong glyph for key: ${entry.key}');
      }
    });

    test('returns null for unknown names and null input', () {
      expect(iconFromName('does-not-exist'), isNull);
      expect(iconFromName(null), isNull);
    });
  });

  group('Phosphor fill icon set', () {
    test('all 26 requested Phosphor icons resolve to fill glyphs', () {
      for (final entry in kPhosphorFillEntries.entries) {
        expect(kDesignerIcons.containsKey(entry.key), isTrue,
            reason: 'missing registry key: ${entry.key}');
        expect(kDesignerIcons[entry.key], entry.value,
            reason: 'wrong glyph for key: ${entry.key}');
      }
    });

    test('bell, rewind, fast-forward resolve to Phosphor fill', () {
      expect(kDesignerIcons['bell'], PhosphorIconsFill.bell);
      expect(kDesignerIcons['rewind'], PhosphorIconsFill.rewind);
      expect(kDesignerIcons['fast-forward'], PhosphorIconsFill.fastForward);
    });
  });

  test('icon picker discovery: every registry key is searchable by substring',
      () {
    // The picker derives its list from kDesignerIcons.keys with
    // case-insensitive substring search — any key present in the registry is
    // discoverable without UI changes.
    expect(kDesignerIcons.keys.where((k) => k.contains('steering')),
        contains('steering-wheel'));
    // Mirrors the picker: `k.toLowerCase().contains(_search.toLowerCase())`.
    expect(kDesignerIcons.keys.where((k) => k.toLowerCase().contains('caret')),
        contains('caret-left'));
    expect(kDesignerIcons.keys.length, greaterThanOrEqualTo(167));
  });
}
