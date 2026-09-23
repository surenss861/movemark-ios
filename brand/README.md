# MoveMark brand assets

Every logo file in the app, on both clients, and in `docs/app-store-assets/` is
generated from one vector. Do not hand-edit the PNGs — change the geometry or the
palette here and re-export.

```sh
../.venv-logo/bin/python brand/export_assets.py
```

## The mark

Two nested chevrons, four parallelograms. Both chevrons run on a **0.70 slope**
with vertical end caps; the lower chevron is the smaller of the pair. The mark is
464 × 470 in its own tight crop (`movemark-mark.svg`, filled with `currentColor`
so it inherits colour from its container).

`source-render.png` is the original design render. It is a textured mockup, not an
asset: no alpha, baked-in deboss shadows, and the two chevrons drawn at slightly
different slopes (0.735 and 0.664). The vector normalises both to 0.70 and enforces
mirror symmetry, matching the render at **93.4% IoU** — the remaining difference is
the deboss shadow along the edges.

## Palette

| Token | Hex | Used for |
| --- | --- | --- |
| primary | `#21B866` | the mark, everywhere |
| appBackground | `#07120E` | icon ground |
| tinted | `#EBEBEB` | iOS tinted-appearance icon |
| mint | `#8BB899` | press-kit mark on white |

These mirror `movemork/Theme/MoveMarkTheme.swift` and
`movemark-android/.../res/values/colors.xml`. If the brand green moves, change it
in all three.

## Sizing rules

- **App icons** place the mark at 45.3% of the canvas, centred at 51.2% width and
  51.2% height. The mark sits fractionally low on purpose: its visual mass is in
  the upper chevron, so a geometrically centred mark reads high.
- **Lockup marks** (transparent, used beside the "MoveMark" wordmark) fill 87% of
  their box.
- **Android adaptive icon** is a vector, `drawable/ic_launcher_foreground.xml`, at
  46dp inside the 108dp viewport. That is the largest size that keeps the two top
  tips — the mark's furthest points, 32.73 from centre — inside the 33dp radius
  every launcher mask guarantees. Do not scale it up without redoing that maths.
  `ic_launcher_monochrome.xml` is the same geometry with a flat fill for Android
  13+ themed icons.

## Files this generates

| Path | Form |
| --- | --- |
| `movemork/Assets.xcassets/AppIcon.appiconset/` | `AppIcon`, `-Dark`, `-Tinted` — 1024, opaque RGB (App Store rejects alpha) |
| `movemork/Assets.xcassets/MoveMarkLogo.imageset/` | 1x/2x/3x transparent green |
| `movemark-android/.../res/drawable/movemark_logo.png` | 256 transparent green |
| `docs/app-store-assets/` | store icon plus transparent, white and mint press variants |

The Android launcher vectors are written by hand, not by the script — they are
checked by `brand/` geometry but live as XML in the resource tree.
