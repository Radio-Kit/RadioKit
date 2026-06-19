#!/usr/bin/env python3
"""
Parse DaisyUI theme CSS files from ../../themes/ and generate:
  - src/styles/themes-imports.css
    - @import lines pointing directly to source theme files (auto-discovery)
  - src/styles/themes-starlight.css
    - [data-theme][data-theme-variant] blocks with Starlight --sl-* variables

Auto-run before every `astro build` via package.json prebuild script.
"""

import re
import os
import sys

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
THEMES_DIR = os.path.normpath(os.path.join(PROJECT_ROOT, '..', 'themes'))
OUTPUT_IMPORTS = os.path.join(PROJECT_ROOT, 'src', 'styles', 'themes-imports.css')
OUTPUT_STARLIGHT = os.path.join(PROJECT_ROOT, 'src', 'styles', 'themes-starlight.css')

IMPORT_PREFIX = '@themes/'


def parse_theme(filepath):
    """Extract DaisyUI variable values from a theme CSS file."""
    with open(filepath, 'r') as f:
        content = f.read()

    vars_ = {}
    pattern = re.compile(r'(--[\w-]+):\s*(oklch\([^;]+\))\s*;')
    for match in pattern.finditer(content):
        name, value = match.groups()
        vars_[name] = value

    cs_match = re.search(r'color-scheme:\s*"(dark|light)"', content)
    color_scheme = cs_match.group(1) if cs_match else 'dark'

    name = os.path.splitext(os.path.basename(filepath))[0]
    return name, color_scheme, vars_


def oklch_adjust_lightness(oklch_str, factor):
    """Adjust the lightness of an oklch color. factor > 1 = lighter, < 1 = darker."""
    if 'oklch(' not in oklch_str:
        return oklch_str
    inner = oklch_str[6:-1].strip()
    parts = inner.split()
    if len(parts) < 3:
        return oklch_str
    l_str = parts[0].rstrip('%')
    try:
        l = float(l_str)
    except ValueError:
        return oklch_str
    new_l = max(0, min(100, l * factor))
    return f'oklch({new_l:.1f}% {parts[1]} {parts[2]})'


def oklch_with_alpha(oklch_str, alpha):
    """Add alpha channel to an oklch color."""
    if 'oklch(' not in oklch_str:
        return oklch_str
    inner = oklch_str[6:-1].strip()
    parts = inner.split()
    if len(parts) < 3:
        return oklch_str
    return f'oklch({parts[0]} {parts[1]} {parts[2]} / {alpha})'


def generate_starlight_block(name, color_scheme, vars_):
    """Generate Starlight CSS variable block for a theme variant."""
    lines = [f'[data-theme="{color_scheme}"][data-theme-variant="{name}"] {{']

    base_content = vars_.get('--color-base-content', 'oklch(50% 0 0)')
    base_100 = vars_.get('--color-base-100', 'oklch(20% 0 0)')
    base_200 = vars_.get('--color-base-200', 'oklch(15% 0 0)')
    base_300 = vars_.get('--color-base-300', 'oklch(10% 0 0)')
    neutral = vars_.get('--color-neutral', 'oklch(50% 0 0)')
    neutral_content = vars_.get('--color-neutral-content', 'oklch(80% 0 0)')

    primary = vars_.get('--color-primary', 'oklch(50% 0 0)')
    primary_content = vars_.get('--color-primary-content', base_content)
    secondary = vars_.get('--color-secondary', 'oklch(50% 0 0)')
    success = vars_.get('--color-success', 'oklch(50% 0 0)')
    info = vars_.get('--color-info', 'oklch(50% 0 0)')
    warning = vars_.get('--color-warning', 'oklch(50% 0 0)')
    error = vars_.get('--color-error', 'oklch(50% 0 0)')

    # --- Gray scale (Starlight uses 7 grays, white, black) ---
    # Dark mode: white=lightest text, black=darkest bg
    # Light mode: white=darkest text, black=lightest bg
    is_dark = color_scheme == 'dark'
    if is_dark:
        lines.append(f'  --sl-color-white: {base_content};')
        lines.append(f'  --sl-color-gray-1: {base_content};')
        lines.append(f'  --sl-color-gray-2: {neutral_content};')
        lines.append(f'  --sl-color-gray-3: {neutral_content};')
        lines.append(f'  --sl-color-gray-4: {neutral};')
        lines.append(f'  --sl-color-gray-5: {neutral};')
        lines.append(f'  --sl-color-gray-6: {base_200};')
        lines.append(f'  --sl-color-gray-7: {base_200};')
        lines.append(f'  --sl-color-black: {base_300};')
    else:
        lines.append(f'  --sl-color-white: {base_content};')
        lines.append(f'  --sl-color-gray-1: {base_200};')
        lines.append(f'  --sl-color-gray-2: {neutral};')
        lines.append(f'  --sl-color-gray-3: {neutral};')
        lines.append(f'  --sl-color-gray-4: {neutral_content};')
        lines.append(f'  --sl-color-gray-5: {neutral_content};')
        lines.append(f'  --sl-color-gray-6: {base_100};')
        lines.append(f'  --sl-color-gray-7: {base_100};')
        lines.append(f'  --sl-color-black: {base_content};')

    # --- Main text color ---
    lines.append(f'  --sl-color-text: {base_content};')

    # --- Backgrounds ---
    lines.append(f'  --sl-color-bg: {base_300};')
    lines.append(f'  --sl-color-bg-nav: {base_200};')
    lines.append(f'  --sl-color-bg-sidebar: {base_200};')
    lines.append(f'  --sl-color-bg-inline-code: {base_100};')
    # Starlight default: accent-high in dark, accent in light
    lines.append(f'  --sl-color-bg-accent: {oklch_adjust_lightness(primary, 1.6 if is_dark else 1.0)};')

    # --- Hairlines ---
    lines.append(f'  --sl-color-hairline-light: {neutral};')
    lines.append(f'  --sl-color-hairline: {neutral};')
    lines.append(f'  --sl-color-hairline-shade: {base_300};')

    # --- Accent (primary) ---
    lines.append(f'  --sl-color-accent: {primary};')
    if 'oklch(' in primary:
        inner = primary[6:-1].strip()
        parts = inner.split()
        if len(parts) >= 3:
            hue = parts[2].rstrip(')')
            high_l = min(100, float(parts[0].rstrip('%')) * 1.6)
            low_l = float(parts[0].rstrip('%')) * 0.6
            lines.append(f'  --sl-color-accent-high: oklch({high_l:.1f}% {parts[1]} {hue});')
            lines.append(f'  --sl-color-accent-low: oklch({low_l:.1f}% {parts[1]} {hue});')

    # --- Text colors ---
    lines.append(f'  --sl-color-text-accent: {primary};')
    lines.append(f'  --sl-color-text-invert: {base_100};')
    lines.append(f'  --sl-color-text-badge: {primary_content};')

    # --- Badge ---
    lines.append(f'  --sl-color-bg-badge: {primary};')
    lines.append(f'  --sl-color-border-badge: {primary};')

    # --- Semantic color variants (low/base/high) ---
    for sl_name, daisy_val in [
        ('green', success),
        ('blue', info),
        ('purple', secondary),
        ('red', error),
        ('orange', warning),
    ]:
        lines.append(f'  --sl-color-{sl_name}: {daisy_val};')
        lines.append(f'  --sl-color-{sl_name}-low: {oklch_adjust_lightness(daisy_val, 0.4)};')
        lines.append(f'  --sl-color-{sl_name}-high: {oklch_adjust_lightness(daisy_val, 1.6)};')

    # --- Asides ---
    lines.append(f'  --sl-color-asides-text-accent: {primary};')
    lines.append(f'  --sl-color-asides-border: {primary};')

    lines.append('}')
    return '\n'.join(lines)


def main():
    if not os.path.isdir(THEMES_DIR):
        print(f'Error: themes directory not found at {THEMES_DIR}', file=sys.stderr)
        sys.exit(1)

    css_files = sorted([
        os.path.join(THEMES_DIR, f)
        for f in os.listdir(THEMES_DIR)
        if f.endswith('.css')
    ])

    if not css_files:
        print('Error: no .css files found in themes directory', file=sys.stderr)
        sys.exit(1)

    all_themes = []
    for filepath in css_files:
        try:
            name, cs, vars_ = parse_theme(filepath)
            all_themes.append((name, cs, vars_))
            print(f'  Parsed: {name} ({cs})')
        except Exception as e:
            print(f'  Error parsing {filepath}: {e}', file=sys.stderr)

    header = [
        '/* Auto-generated by scripts/generate_web_themes.py */',
        '/* Do not edit manually. Add/remove .css files in themes/ and rebuild. */',
        '',
    ]

    # Part 1: Auto-discovery @import lines (for DaisyUI registration on landing page)
    import_lines = list(header)
    import_lines.append('/* ===== Direct theme imports from @themes/ ===== */')
    for name, _, _ in all_themes:
        import_lines.append(f'@import "{IMPORT_PREFIX}{name}.css";')

    import_content = '\n'.join(import_lines) + '\n'
    os.makedirs(os.path.dirname(OUTPUT_IMPORTS), exist_ok=True)
    with open(OUTPUT_IMPORTS, 'w') as f:
        f.write(import_content)
    print(f'  Wrote {OUTPUT_IMPORTS}')

    # Part 2: Starlight CSS variable blocks (for docs pages)
    sl_lines = list(header)
    sl_lines.append('/* ===== Starlight CSS Variable Mappings ===== */')
    for name, cs, vars_ in all_themes:
        sl_lines.append(generate_starlight_block(name, cs, vars_))
        sl_lines.append('')

    # Fallback for legacy [data-theme="dark"] / [data-theme="light"]
    for name, cs, vars_ in all_themes:
        if cs == 'dark':
            sl_lines.append(f'[data-theme="dark"]:not([data-theme-variant]) {{\n/* falls back to {name} */')
            for line in generate_starlight_block(name, cs, vars_).split('\n')[1:-1]:
                sl_lines.append(line)
            sl_lines.append('}\n')
            break
    for name, cs, vars_ in all_themes:
        if cs == 'light':
            sl_lines.append(f'[data-theme="light"]:not([data-theme-variant]) {{\n/* falls back to {name} */')
            for line in generate_starlight_block(name, cs, vars_).split('\n')[1:-1]:
                sl_lines.append(line)
            sl_lines.append('}\n')
            break

    sl_content = '\n'.join(sl_lines)
    with open(OUTPUT_STARLIGHT, 'w') as f:
        f.write(sl_content)
    print(f'  Wrote {OUTPUT_STARLIGHT}')

    count = len(all_themes)
    dark = sum(1 for _, cs, _ in all_themes if cs == 'dark')
    light = count - dark
    print(f'\nGenerated {count} themes ({dark} dark, {light} light)')


if __name__ == '__main__':
    main()
