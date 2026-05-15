# MoveMark app icon & logo

**Source:** `mmasest.png` at repo root (`/Volumes/sss/movemark/mmasest.png`).

Assets are **cropped to remove the outer white canvas**, squared, and scaled to **1024×1024** so the home-screen icon fills the slot with no extra white border.

## Files

| File | Use |
|------|-----|
| `AppIcon-1024.png` | App Store Connect upload |
| `MoveMarkLogo-transparent.png` | M mark only (transparent) |
| `MoveMarkLogo-light-white.png` | Full icon (same as App Store) |

Xcode: `AppIcon.appiconset/AppIcon.png`, `MoveMarkLogo.imageset/`.

## Regenerate

```bash
/Volumes/sss/movemark/.venv-logo/bin/python3 movemork/scripts/process-movemark-logo.py
```

Optional: `MOVEMARK_LOGO_SOURCE=/path/to/icon.png`

## App Store Connect

Upload `AppIcon-1024.png`, then submit a **new build** so devices get the embedded icon.
