#!/usr/bin/env python3
"""Regenerate AppIcon and menu bar preview assets per equinox-design.mdc."""

from __future__ import annotations

import json
import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ICONS = ROOT / "equinox/Images.xcassets/AppIcon.appiconset"
LOGO = ROOT / "equinox/Images.xcassets/AppLogo.imageset"
MENUBAR = ROOT / "equinox/Images.xcassets"

WINDOW_DARK = (30, 31, 34, 255)  # #1E1F22
INK = (255, 255, 255, 255)

# macOS app-icon grid: rounded square inset ~9.8% with continuous ~22.5% corner.
ICON_MARGIN_RATIO = 0.098
ICON_CORNER_RATIO = 0.2237

SIZES = [
    ("AppIcon16.png", 16),
    ("AppIcon16@2x.png", 32),
    ("AppIcon32.png", 32),
    ("AppIcon32@2x.png", 64),
    ("AppIcon128.png", 128),
    ("AppIcon128@2x.png", 256),
    ("AppIcon256.png", 256),
    ("AppIcon256@2x.png", 512),
    ("AppIcon512.png", 512),
    ("AppIcon512@2x.png", 1024),
]


def load_font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    for name in (
        "/System/Library/Fonts/SFNSRounded.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ):
        path = Path(name)
        if path.exists():
            try:
                return ImageFont.truetype(str(path), size)
            except OSError:
                continue
    return ImageFont.load_default()


def draw_celestial_mark(draw: ImageDraw.ImageDraw, cx: float, cy: float, ref: float) -> None:
    """Draw the celestial mark centered at (cx, cy), scaled to a `ref`-px panel."""

    def s(v: float) -> float:
        return v * ref / 1024.0

    # Orbital rings — an upward dome over the central star.
    for rx, ry, width in ((220, 170, 18), (300, 230, 14), (360, 280, 10)):
        bbox = (cx - s(rx), cy - s(ry), cx + s(rx), cy + s(ry))
        draw.arc(bbox, start=200, end=340, fill=(255, 255, 255, 220), width=max(1, int(s(width))))

    # Central star
    star_r = s(48)
    points = []
    for i in range(10):
        angle = math.radians(-90 + i * 36)
        radius = star_r if i % 2 == 0 else star_r * 0.42
        points.append((cx + math.cos(angle) * radius, cy + math.sin(angle) * radius))
    draw.polygon(points, fill=INK)

    # Twinkle stars
    for ox, oy, r in ((-s(250), -s(110), 6), (s(210), -s(140), 5), (-s(180), s(180), 4), (s(260), s(130), 5)):
        x, y = cx + ox, cy + oy
        rr = max(1, int(s(r)))
        draw.ellipse((x - rr, y - rr, x + rr, y + rr), fill=INK)


def render_app_icon(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    margin = max(1, round(size * ICON_MARGIN_RATIO))
    panel_size = size - 2 * margin
    radius = max(2, int(panel_size * ICON_CORNER_RATIO))
    draw.rounded_rectangle(
        (margin, margin, size - margin - 1, size - margin - 1),
        radius=radius,
        fill=WINDOW_DARK,
    )

    draw_celestial_mark(draw, size / 2, size / 2, panel_size)
    return img


def regenerate_app_icons() -> None:
    for filename, size in SIZES:
        render_app_icon(size).save(ICONS / filename)

    logo_path = LOGO / "AppLogo.png"
    render_app_icon(256).save(logo_path)
    contents = {
        "images": [{"filename": "AppLogo.png", "idiom": "universal", "scale": "1x"}],
        "info": {"author": "xcode", "version": 1},
        "properties": {"preserves-vector-representation": True},
    }
    (LOGO / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def _badge_metrics(font) -> tuple[int, int, int]:
    pad_x = max(2, round(font.size * 0.38))
    pad_y = max(1, round(font.size * 0.16))
    radius = max(2, round(font.size * 0.23))
    return pad_x, pad_y, radius


def draw_menubar_minimal(draw: ImageDraw.ImageDraw, w: int, h: int, text: str, font) -> None:
    tw = draw.textlength(text, font=font)
    tx = (w - tw) / 2
    ty = (h - font.size) / 2 - 1
    pad_x, pad_y, radius = _badge_metrics(font)
    badge = (tx - pad_x, ty - pad_y, tx + tw + pad_x, ty + font.size + pad_y)
    draw.rounded_rectangle(badge, radius=radius, fill=INK)
    draw.text((tx, ty), text, fill=WINDOW_DARK, font=font)


def draw_menubar_classic(draw: ImageDraw.ImageDraw, w: int, h: int, text: str, font) -> None:
    tw = draw.textlength(text, font=font)
    tx = (w - tw) / 2
    ty = (h - font.size) / 2 - 1
    pad_x, pad_y, radius = _badge_metrics(font)
    badge = (tx - pad_x, ty - pad_y, tx + tw + pad_x, ty + font.size + pad_y)
    draw.rounded_rectangle(badge, radius=radius, outline=INK, width=max(1, round(font.size / 13)))
    draw.text((tx, ty), text, fill=INK, font=font)


def draw_menubar_compact(draw: ImageDraw.ImageDraw, w: int, h: int, text: str, font) -> None:
    tw = draw.textlength(text, font=font)
    tx = (w - tw) / 2
    ty = (h - font.size) / 2 - 1
    draw.text((tx, ty), text, fill=INK, font=font)


def regenerate_menubar_previews() -> None:
    text = "13"
    styles = (draw_menubar_minimal, draw_menubar_classic, draw_menubar_compact)
    for index, draw_style in enumerate(styles):
        for scale, suffix in ((1, ""), (2, "@2x")):
            w, h = 56 * scale, 28 * scale
            font = load_font(13 * scale)
            img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
            draw = ImageDraw.Draw(img)
            draw_style(draw, w, h, text, font)
            out = MENUBAR / f"menubaricon{index}.imageset/menubaricon{index}{suffix}.png"
            img.save(out)


def main() -> None:
    regenerate_app_icons()
    regenerate_menubar_previews()
    print("Regenerated AppIcon, AppLogo, and menubaricon0-2 (1x + 2x)")


if __name__ == "__main__":
    main()
