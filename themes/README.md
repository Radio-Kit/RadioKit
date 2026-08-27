# RadioKit Themes

CSS theme files that drive the `RKTokens` presets in `lib/src/theme/rk_tokens.dart`.

## How it works

1. Each `.css` file defines a DaisyUI-compatible theme using `oklch()` colors.
2. Running `python3 scripts/generate_tokens.py` parses every CSS file and regenerates `rk_tokens.dart` with:
   - A `static const RKTokens <name>` preset for each file (filename = theme name)
   - A `static const Map<String, RKTokens> presets` map listing all themes
3. The example app and designer read `RKTokens.presets` directly -- no hardcoded lists.

## Adding a theme

1. Grab any theme from the [DaisyUI Theme Generator](https://daisyui.com/theme-generator) or write your own CSS following the DaisyUI `@plugin "daisyui/theme"` format.
2. Save it as `<themename>.css` in this directory (e.g. `forest.css`).
3. Run:
   ```bash
   python3 ../scripts/generate_tokens.py
   ```
4. The new theme is now available as `RKTokens.<themename>` and appears in the app's skin picker automatically.

## Removing a theme

Delete the `.css` file, re-run the script, and the theme is gone from both the Dart class and the UI.

## CSS format

```css
@plugin "daisyui/theme" {
    name: "mytheme";       /* ignored -- filename is used instead */
    default: false;        /* ignored */
    prefersdark: false;    /* ignored */
    color-scheme: "dark";

    /* Colors -- oklch(Lightness% Chroma Hue) */
    --color-base-100: oklch(21% 0.006 56.043);
    --color-base-200: oklch(14% 0.004 49.25);
    --color-base-300: oklch(0% 0 0);
    --color-base-content: oklch(84.955% 0 0);
    --color-primary: oklch(82% 0.189 84.429);
    --color-primary-content: oklch(19.693% 0.004 196.779);
    --color-secondary: oklch(45.98% 0.248 305.03);
    --color-secondary-content: oklch(89.196% 0.049 305.03);
    --color-accent: oklch(64.8% 0.223 136.073);
    --color-accent-content: oklch(0% 0 0);
    --color-neutral: oklch(24.371% 0.046 65.681);
    --color-neutral-content: oklch(84.874% 0.009 65.681);
    --color-info: oklch(54.615% 0.215 262.88);
    --color-info-content: oklch(90.923% 0.043 262.88);
    --color-success: oklch(62.705% 0.169 149.213);
    --color-success-content: oklch(12.541% 0.033 149.213);
    --color-warning: oklch(66.584% 0.157 58.318);
    --color-warning-content: oklch(13.316% 0.031 58.318);
    --color-error: oklch(65.72% 0.199 27.33);
    --color-error-content: oklch(13.144% 0.039 27.33);

    /* Sizing -- rem (converted to points: rem * 16) */
    --radius-selector: 1rem;
    --radius-field: 0.5rem;
    --radius-box: 1rem;
    --size-selector: 0.25rem;
    --size-field: 0.25rem;
    --border: 1px;
    --depth: 1;
    --noise: 0;
}
```

## CSS to RKTokens mapping

| CSS Variable | RKTokens Field |
|---|---|
| `--color-base-100` | `surface` |
| `--color-base-content` | `onSurface` |
| `--color-base-200` | `base200` |
| `--color-base-300` | `base300` |
| `--color-primary` | `primary` |
| `--color-primary-content` | `onPrimary` |
| `--color-secondary` | `secondary` |
| `--color-secondary-content` | `onSecondary` |
| `--color-accent` | `accent` |
| `--color-accent-content` | `onAccent` |
| `--color-neutral` | `neutral` |
| `--color-neutral-content` | `onNeutral` |
| `--color-info` | `info` |
| `--color-info-content` | `onInfo` |
| `--color-success` | `success` |
| `--color-success-content` | `onSuccess` |
| `--color-warning` | `warning` |
| `--color-warning-content` | `onWarning` |
| `--color-error` | `error` |
| `--color-error-content` | `onError` |
| `--radius-selector` | `radiusSelector` |
| `--radius-field` | `radiusField` |
| `--radius-box` | `borderRadius` |
| `--size-selector` | `sizeSelector` |
| `--size-field` | `sizeField` |
| `--border` | `borderWidth` |
| `--depth` | `depth` |
| `--noise` | `noise` |

`outlineColor` is not set from CSS (stays `null`, falls back to `onSurface.withValues(alpha: 0.2)`).
