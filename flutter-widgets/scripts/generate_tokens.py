#!/usr/bin/env python3
"""Regenerate rk_tokens.dart from CSS theme files.

Reads all .css files from ../themes/, parses oklch colors and sizing tokens,
and writes a complete rk_tokens.dart with static const presets.

Usage: python3 scripts/generate_tokens.py
"""

import os
import re
import math

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
THEMES_DIR = os.path.join(SCRIPT_DIR, "..", "..", "themes")
OUTPUT_FILE = os.path.join(SCRIPT_DIR, "..", "lib", "src", "theme", "rk_tokens.dart")

# ── oklch → hex (pure math, no dependencies) ──

def oklch_to_hex(L, C, H_deg):
    """Convert OKLCH (lightness 0-1, chroma, hue degrees) to #RRGGBB hex."""
    H = math.radians(H_deg)
    a = C * math.cos(H)
    b = C * math.sin(H)

    # Oklab → LMS (cone responses)
    l_ = L + 0.3963377774 * a + 0.2158037573 * b
    m_ = L - 0.1055613458 * a - 0.0638541728 * b
    s_ = L - 0.0894841775 * a - 1.291485548 * b

    # LMS → LMS³ (cube)
    l = l_ * l_ * l_
    m = m_ * m_ * m_
    s = s_ * s_ * s_

    # LMS³ → linear sRGB
    r_lin = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
    g_lin = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
    b_lin = -0.0041960863 * l - 0.7034186147 * m + 1.707614701 * s

    # Linear sRGB → sRGB (gamma correction)
    def gamma(c):
        if c <= 0.0031308:
            return 12.92 * c
        return 1.055 * (c ** (1.0 / 2.4)) - 0.055

    r = max(0.0, min(1.0, gamma(r_lin)))
    g = max(0.0, min(1.0, gamma(g_lin)))
    b = max(0.0, min(1.0, gamma(b_lin)))

    ri = round(r * 255)
    gi = round(g * 255)
    bi = round(b * 255)
    return f"{ri:02X}{gi:02X}{bi:02X}"


# ── CSS parsing ──

# (dart field name, css suffix)
COLOR_MAP = [
    ("surface", "base-100"),
    ("onSurface", "base-content"),
    ("base200", "base-200"),
    ("base300", "base-300"),
    ("primary", "primary"),
    ("onPrimary", "primary-content"),
    ("secondary", "secondary"),
    ("onSecondary", "secondary-content"),
    ("accent", "accent"),
    ("onAccent", "accent-content"),
    ("neutral", "neutral"),
    ("onNeutral", "neutral-content"),
    ("info", "info"),
    ("onInfo", "info-content"),
    ("success", "success"),
    ("onSuccess", "success-content"),
    ("warning", "warning"),
    ("onWarning", "warning-content"),
    ("error", "error"),
    ("onError", "error-content"),
]

OKLCH_RE = re.compile(r"oklch\(\s*([\d.]+)%\s+([\d.]+)\s+([\d.]+)\s*\)")


def parse_css(content):
    tokens = {}

    for dart_field, css_suffix in COLOR_MAP:
        m = re.search(rf"--color-{re.escape(css_suffix)}:\s*([^;]+);", content)
        if m:
            om = OKLCH_RE.match(m.group(1).strip())
            if om:
                L = float(om.group(1)) / 100.0
                C = float(om.group(2))
                H = float(om.group(3))
                tokens[dart_field] = oklch_to_hex(L, C, H)

    def rem_val(key):
        m = re.search(rf"--{key}:\s*([\d.]+)rem;", content)
        return round(float(m.group(1)) * 16, 1) if m else None

    tokens["radiusSelector"] = rem_val("radius-selector")
    tokens["radiusField"] = rem_val("radius-field")
    tokens["borderRadius"] = rem_val("radius-box")
    tokens["sizeSelector"] = rem_val("size-selector")
    tokens["sizeField"] = rem_val("size-field")

    m = re.search(r"--border:\s*([\d.]+)px;", content)
    tokens["borderWidth"] = float(m.group(1)) if m else 1.0

    m = re.search(r"--depth:\s*(\d+);", content)
    tokens["depth"] = int(m.group(1)) if m else 1

    m = re.search(r"--noise:\s*(\d+);", content)
    tokens["noise"] = int(m.group(1)) if m else 0

    m = re.search(r'color-scheme:\s*"(\w+)";', content)
    tokens["isDark"] = m.group(1) == "dark" if m else False

    m = re.search(r'^\s+default:\s*(true|false);', content, re.MULTILINE)
    tokens["isDefault"] = m.group(1) == "true" if m else False

    return tokens


# ── Dart code generation ──

COLOR_PROPS = [
    "surface", "onSurface", "base200", "base300",
    "primary", "onPrimary", "secondary", "onSecondary",
    "accent", "onAccent", "neutral", "onNeutral",
    "info", "onInfo", "success", "onSuccess",
    "warning", "onWarning", "error", "onError",
]


def generate_preset(name, tokens):
    lines = [f"  static const RKTokens {name} = RKTokens("]
    for prop in COLOR_PROPS:
        if prop in tokens:
            lines.append(f"    {prop}: Color(0xFF{tokens[prop]}),")
    lines.append(f"    borderRadius: {tokens.get('borderRadius', 16.0)},")
    lines.append(f"    radiusSelector: {tokens.get('radiusSelector', 16.0)},")
    lines.append(f"    radiusField: {tokens.get('radiusField', 8.0)},")
    lines.append(f"    sizeSelector: {tokens.get('sizeSelector', 4.0)},")
    lines.append(f"    sizeField: {tokens.get('sizeField', 4.0)},")
    lines.append(f"    borderWidth: {tokens.get('borderWidth', 1.0)},")
    lines.append(f"    depth: {tokens.get('depth', 1)},")
    lines.append(f"    noise: {tokens.get('noise', 0)},")
    lines.append(f"    isDark: {str(tokens.get('isDark', False)).lower()},")
    lines.append(f"    isDefault: {str(tokens.get('isDefault', False)).lower()},")
    lines.append("  );")
    return "\n".join(lines)


CLASS_HEADER = '''import 'package:flutter/material.dart';

/// Design tokens shared across all RadioKit widgets.
///
/// Follows the DaisyUI semantic color model with 20 color fields,
/// 3 border-radius tokens, 3 sizing tokens, and 2 effect tokens.
class RKTokens {
  const RKTokens({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.accent,
    required this.onAccent,
    required this.neutral,
    required this.onNeutral,
    required this.surface,
    required this.onSurface,
    required this.base200,
    required this.base300,
    required this.info,
    required this.onInfo,
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.error,
    required this.onError,
    this.outlineColor,
    this.borderRadius = 16.0,
    this.radiusSelector = 16.0,
    this.radiusField = 8.0,
    this.sizeSelector = 4.0,
    this.sizeField = 4.0,
    this.borderWidth = 1.0,
    this.depth = 1,
    this.noise = 0,
    this.isDark = false,
    this.isDefault = false,
  });

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color accent;
  final Color onAccent;
  final Color neutral;
  final Color onNeutral;
  final Color surface;
  final Color onSurface;
  final Color base200;
  final Color base300;
  final Color info;
  final Color onInfo;
  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color error;
  final Color onError;
  final Color? outlineColor;
  final double borderRadius;
  final double radiusSelector;
  final double radiusField;
  final double sizeSelector;
  final double sizeField;
  final double borderWidth;
  final int depth;
  final int noise;
  final bool isDark;
  final bool isDefault;

  Color get effectiveOutline => outlineColor ?? onSurface.withValues(alpha: 0.35);

  /// A recessed-groove / track color with guaranteed contrast against [surface].
  /// Blends [base200] toward [onSurface] so dark themes remain legible.
  Color get track => Color.lerp(base200, onSurface, 0.12)!;

  /// Standardised active-state glow highlight derived from [primary].
  Color get glow => primary.withValues(alpha: 0.45);

  // -- Presets --
'''

COPY_WITH = '''
  RKTokens copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? accent,
    Color? onAccent,
    Color? neutral,
    Color? onNeutral,
    Color? surface,
    Color? onSurface,
    Color? base200,
    Color? base300,
    Color? info,
    Color? onInfo,
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? error,
    Color? onError,
    Color? outlineColor,
    double? borderRadius,
    double? radiusSelector,
    double? radiusField,
    double? sizeSelector,
    double? sizeField,
    double? borderWidth,
    int? depth,
    int? noise,
    bool? isDark,
    bool? isDefault,
  }) {
    return RKTokens(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      neutral: neutral ?? this.neutral,
      onNeutral: onNeutral ?? this.onNeutral,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      base200: base200 ?? this.base200,
      base300: base300 ?? this.base300,
      info: info ?? this.info,
      onInfo: onInfo ?? this.onInfo,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      error: error ?? this.error,
      onError: onError ?? this.onError,
      outlineColor: outlineColor ?? this.outlineColor,
      borderRadius: borderRadius ?? this.borderRadius,
      radiusSelector: radiusSelector ?? this.radiusSelector,
      radiusField: radiusField ?? this.radiusField,
      sizeSelector: sizeSelector ?? this.sizeSelector,
      sizeField: sizeField ?? this.sizeField,
      borderWidth: borderWidth ?? this.borderWidth,
      depth: depth ?? this.depth,
      noise: noise ?? this.noise,
      isDark: isDark ?? this.isDark,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  static Map<String, RKTokens> get presetsByName => {
    for (final e in presets.entries) e.key.toLowerCase(): e.value,
  };

  static String get defaultPreset =>
      presetsByName.entries.firstWhere((e) => e.value.isDefault, orElse: () => presetsByName.entries.first).key;
}
'''


def main():
    css_files = sorted(
        f for f in os.listdir(THEMES_DIR)
        if f.endswith(".css")
    )

    presets = []
    for fname in css_files:
        name = fname[:-4]  # strip .css
        path = os.path.join(THEMES_DIR, fname)
        with open(path, "r") as fh:
            content = fh.read()
        tokens = parse_css(content)
        presets.append(generate_preset(name, tokens))

    # Collect theme names for the presets map
    theme_names = []
    for fname in css_files:
        name = fname[:-4]
        theme_names.append(name.upper())

    presets_map = (
        "\n  /// Auto-generated from CSS themes -- do not edit manually.\n"
        "  static const Map<String, RKTokens> presets = {\n"
        + "".join(f"    '{n}': {n.lower()},\n" for n in theme_names)
        + "  };\n"
    )

    output = CLASS_HEADER + "\n".join(presets) + "\n" + presets_map + COPY_WITH

    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    with open(OUTPUT_FILE, "w") as fh:
        fh.write(output)

    print(f"Generated {len(presets)} themes -> {OUTPUT_FILE}")
    for p in presets:
        m = re.search(r"static const RKTokens (\w+)", p)
        if m:
            print(f"  - {m.group(1)}")


if __name__ == "__main__":
    main()
