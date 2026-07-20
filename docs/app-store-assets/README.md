# MoveMark app icon & logo

**Source:** `source/movemark-mark.svg` — a single flat document+checkmark mark
(the checkmark is a true transparency cutout via an SVG mask, not a
solid-color fake-cutout). Replaces the old six-idea icon (M letterform +
checkmark + house + key + document/shield + window, bevels, drop shadows)
that was generated from `mmasest.png` via `scripts/process-movemark-logo.py`.
That script and source file are obsolete — do not run it, it will regress
the icon back to the old design.

## Files

| File | Use |
|------|-----|
| `AppIcon-1024.png` | App Store Connect upload — full color mark (`#21B866`) on app background (`#07120E`), opaque |
| `MoveMarkLogo-transparent.png` | Mark only, primary green, transparent background |
| `MoveMarkLogo-light-white.png` | Mark only, white, transparent background — for dark/colored surfaces |
| `MoveMarkLogo-light-mint.png` | Mark only, muted mint accent, transparent background — for light/paper surfaces |

Xcode: `AppIcon.appiconset/` (`AppIcon.png` default, `AppIcon-Dark.png`,
`AppIcon-Tinted.png` — a real grayscale variant per Apple's tinted-icon
guidance, not a copy of the color asset), `MoveMarkLogo.imageset/`.

## Regenerate

Edit `source/movemark-mark.svg` (or the fill colors within it), then
rasterize with `qlmanage -t -s <size> -o . movemark-mark.svg` and flatten
alpha for the opaque App Store icon with a JPEG round-trip via `sips`
(App Store icons must have no alpha channel; the logo variants keep theirs).

## App Store Connect

Upload `AppIcon-1024.png`, then submit a **new build** so devices get the embedded icon.
