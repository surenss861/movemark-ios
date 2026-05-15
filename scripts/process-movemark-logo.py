#!/usr/bin/env python3
"""Fit MoveMark app icon source (mmasest.png) into Xcode assets with no outer white margin."""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image
import numpy as np

REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SOURCE = REPO_ROOT.parent / "mmasest.png"
OUT_DIR = REPO_ROOT / "docs" / "app-store-assets"
APPICON = REPO_ROOT / "movemork" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon.png"
LOGO_DIR = REPO_ROOT / "movemork" / "Assets.xcassets" / "MoveMarkLogo.imageset"

ICON_SIZE = 1024


def _near_white_mask(rgb: np.ndarray, threshold: int = 248) -> np.ndarray:
    return (
        (rgb[:, :, 0] > threshold)
        & (rgb[:, :, 1] > threshold)
        & (rgb[:, :, 2] > threshold)
    )


def _content_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    """Tight bounds excluding outer white canvas margin."""
    arr = np.array(img.convert("RGBA"))
    rgb = arr[:, :, :3].astype(int)
    green = (rgb[:, :, 1] > rgb[:, :, 0] + 15) & (rgb[:, :, 1] > 80)
    content = (~_near_white_mask(rgb)) | green
    ys, xs = np.where(content)
    if len(xs) == 0:
        return 0, 0, img.width - 1, img.height - 1
    return int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())


def _mark_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    """Bounds of the green M + check (in-app logo)."""
    rgb = np.array(img.convert("RGBA"))[:, :, :3].astype(int)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    mark = (
        (rgb[:, :, 1] > rgb[:, :, 0] + 20)
        & (rgb[:, :, 1] > 90)
        & (sat > 22)
    )
    ys, xs = np.where(mark)
    if len(xs) == 0:
        return _content_bbox(img)
    pad = 12
    x0 = max(0, int(xs.min()) - pad)
    y0 = max(0, int(ys.min()) - pad)
    x1 = min(img.width - 1, int(xs.max()) + pad)
    y1 = min(img.height - 1, int(ys.max()) + pad)
    return x0, y0, x1, y1


def _square_fill(crop: Image.Image, bg_rgb: tuple[int, int, int] | None = None) -> Image.Image:
    if bg_rgb is None:
        arr = np.array(crop.convert("RGB"))
        # Edge sample: median of border pixels (mint/cream from icon bg)
        top = arr[0, :, :]
        left = arr[:, 0, :]
        edge = np.concatenate([top, left], axis=0)
        bg_rgb = tuple(np.median(edge, axis=0).astype(int).tolist())

    w, h = crop.size
    side = max(w, h)
    square = Image.new("RGB", (side, side), bg_rgb)
    ox = (side - w) // 2
    oy = (side - h) // 2
    square.paste(crop.convert("RGB"), (ox, oy))
    return square


def _fit_app_icon(source: Image.Image) -> Image.Image:
    x0, y0, x1, y1 = _content_bbox(source)
    cropped = source.crop((x0, y0, x1 + 1, y1 + 1))
    square = _square_fill(cropped)
    return square.resize((ICON_SIZE, ICON_SIZE), Image.Resampling.LANCZOS)


def _fit_mark_logo(source: Image.Image, size: int) -> Image.Image:
    x0, y0, x1, y1 = _mark_bbox(source)
    cropped = source.crop((x0, y0, x1 + 1, y1 + 1))
    arr = np.array(cropped.convert("RGBA"))
    rgb = arr[:, :, :3].astype(int)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    is_mark = (
        (rgb[:, :, 1] > rgb[:, :, 0] + 18)
        & (rgb[:, :, 1] > 85)
        & (sat > 20)
    )
    # Drop faint watermark lines on mint
    alpha = np.where(is_mark, 255, 0).astype(np.uint8)
    mark_rgba = np.dstack([arr[:, :, :3], alpha])
    mark_img = Image.fromarray(mark_rgba.astype(np.uint8), "RGBA")

    w, h = mark_img.size
    side = max(w, h)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(mark_img, ((side - w) // 2, (side - h) // 2), mark_img)

  # Fill ~88% of output — no extra margin
    fill = int(size * 0.88)
    scaled = canvas.resize((fill, fill), Image.Resampling.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(scaled, ((size - fill) // 2, (size - fill) // 2), scaled)
    return out


def process(source: Path) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    img = Image.open(source)

    app_icon = _fit_app_icon(img)
    APPICON.parent.mkdir(parents=True, exist_ok=True)
    app_icon.save(APPICON, optimize=True)
    app_icon.save(OUT_DIR / "AppIcon-1024.png", optimize=True)

    # Full-bleed marketing copies
    app_icon.save(OUT_DIR / "MoveMarkLogo-light-white.png", optimize=True)
    app_icon.save(OUT_DIR / "MoveMarkLogo-light-mint.png", optimize=True)

    mark_master = _fit_mark_logo(img, 512)
    mark_master.save(OUT_DIR / "MoveMarkLogo-transparent.png", optimize=True)

    LOGO_DIR.mkdir(parents=True, exist_ok=True)
    for size, name in [(128, "MoveMarkLogo.png"), (256, "MoveMarkLogo@2x.png"), (384, "MoveMarkLogo@3x.png")]:
        _fit_mark_logo(img, size).save(LOGO_DIR / name, optimize=True)

    print(f"Fitted {source.name} → AppIcon 1024×1024 (no outer white) + MoveMarkLogo @1x–@3x")


if __name__ == "__main__":
    source = Path(os.environ.get("MOVEMARK_LOGO_SOURCE", DEFAULT_SOURCE))
    if not source.is_file():
        raise SystemExit(f"Missing source: {source}")
    process(source)
