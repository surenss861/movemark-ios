#!/usr/bin/env python
"""Regenerate every MoveMark logo asset from the vector mark in brand/movemark-mark.svg.

Run with the repo's logo venv:  ../.venv-logo/bin/python brand/export_assets.py
"""
from pathlib import Path
from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parent.parent
IOS = REPO / "movemork/Assets.xcassets"
ANDROID = REPO / "movemark-android/app/src/main/res"
STORE = REPO / "docs/app-store-assets"

# Brand palette (mirrors MoveMarkTheme.Colors)
GREEN = (33, 184, 102)      # #21B866  primary
GROUND = (7, 18, 14)        # #07120E  appBackground
TINTED = (235, 235, 235)    # iOS tinted-appearance mark
MINT = (139, 184, 153)      # #8BB899  press-kit mint
WHITE = (255, 255, 255)

# The mark, tight-cropped: 464 x 470. Two chevrons, four parallelograms,
# both arms on a 0.70 slope with vertical end caps.
MARK_W, MARK_H = 464.0, 470.0
MARK = [
    [(0, 0), (186, 130.2), (186, 242.2), (0, 112)],
    [(464, 0), (278, 130.2), (278, 242.2), (464, 112)],
    [(47, 283), (178, 374.7), (178, 469.7), (47, 378)],
    [(417, 283), (286, 374.7), (286, 469.7), (417, 378)],
]

# Placement inside a square canvas, taken from the approved render: the mark is
# 45.3% of the canvas and sits fractionally low, which optically centres a form
# whose visual mass is in the upper chevron.
ICON_SCALE = 464.0 / 1024.0
ICON_CX, ICON_CY = 512.0 / 1024.0, 523.85 / 1024.0

SS = 4  # supersampling factor for clean edges


def draw(size, scale, cx, cy, fill, bg=None):
    """Render the mark at `scale` (fraction of size) centred on (cx, cy)."""
    s = size * SS
    im = Image.new("RGBA", (s, s), (*bg, 255) if bg else (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    k = (size * scale / MARK_W) * SS
    ox = cx * s - (MARK_W * k) / 2
    oy = cy * s - (MARK_H * k) / 2
    for poly in MARK:
        d.polygon([(ox + x * k, oy + y * k) for x, y in poly], fill=(*fill, 255))
    return im.resize((size, size), Image.LANCZOS)


def save(im, path, opaque=False):
    path.parent.mkdir(parents=True, exist_ok=True)
    (im.convert("RGB") if opaque else im).save(path)
    print(f"  {path.relative_to(REPO)}")


def icon(size, fill, bg):
    return draw(size, ICON_SCALE, ICON_CX, ICON_CY, fill, bg)


def glyph(size, fill, bg=None):
    """Transparent lockup mark: fills 87% of the box, matching the old drawable."""
    return draw(size, 0.87, 0.5, 0.5, fill, bg)


print("iOS app icon")
for name, f, b in (("AppIcon", GREEN, GROUND), ("AppIcon-Dark", GREEN, GROUND),
                   ("AppIcon-Tinted", TINTED, GROUND)):
    save(icon(1024, f, b), IOS / f"AppIcon.appiconset/{name}.png", opaque=True)

print("iOS in-app logo")
for suffix, px in (("", 128), ("@2x", 256), ("@3x", 384)):
    save(glyph(px, GREEN), IOS / f"MoveMarkLogo.imageset/MoveMarkLogo{suffix}.png")

print("Android in-app logo")
save(glyph(256, GREEN), ANDROID / "drawable/movemark_logo.png")

print("App Store / press kit")
save(icon(1024, GREEN, GROUND), STORE / "AppIcon-1024.png", opaque=True)
save(glyph(1024, GREEN), STORE / "MoveMarkLogo-transparent.png")
save(glyph(1024, WHITE), STORE / "MoveMarkLogo-light-white.png")
save(glyph(1024, MINT, WHITE), STORE / "MoveMarkLogo-light-mint.png")
