#!/usr/bin/env python3
"""Build deterministic generation references for the seven shared map markers.

The outputs are references and QA guides only. They never become runtime marker
textures, and they deliberately avoid inventing formal Map01 object coordinates.
"""

from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
MAP_SOURCE = ROOT / "art" / "review" / "map01" / "map01_d1_environment_viewport_375x817.png"
OUTPUT_DIR = ROOT / "art" / "candidates" / "map01_markers"
REFERENCE_DIR = OUTPUT_DIR / "reference"

MAP_REFERENCE = REFERENCE_DIR / "screenshot_map01_marker_scale.png"
DARK_REFERENCE = REFERENCE_DIR / "screenshot_marker_dark_contrast_board.png"
STYLE_REFERENCE = REFERENCE_DIR / "screenshot_project_icon_style.png"
GUIDE_PATH = OUTPUT_DIR / "map01_marker_dimensions_and_anchor_guide.png"
MANIFEST_PATH = OUTPUT_DIR / "map01_marker_generation_input_manifest.json"

MAP_CROP = (43, 216, 283, 456)
LOGICAL_TILE_SIZE = 48
PREVIEW_SCALE = 2
PREVIEW_TILE_SIZE = LOGICAL_TILE_SIZE * PREVIEW_SCALE

ICON_PATHS = (
    ROOT / "assets" / "camp" / "ui" / "expedition" / "icon_expedition_pickaxe.png",
    ROOT / "assets" / "camp" / "ui" / "expedition" / "icon_expedition_lens.png",
    ROOT / "assets" / "camp" / "ui" / "expedition" / "icon_expedition_lock.png",
    ROOT / "assets" / "camp" / "ui" / "top" / "icon_resource_spirit_wood.png",
)

MARKERS = (
    ("PARTY", "marker_explore_party.png", 32, "CENTER"),
    ("RESOURCE", "marker_explore_resource.png", 24, "BOTTOM_CENTER"),
    ("ENEMY", "marker_explore_enemy.png", 24, "BOTTOM_CENTER"),
    ("DUNGEON", "marker_explore_dungeon.png", 24, "BOTTOM_CENTER"),
    ("SPAWN", "marker_explore_spawn.png", 24, "BOTTOM_CENTER"),
    ("MAP EXIT", "marker_explore_map_exit.png", 24, "BOTTOM_CENTER"),
    ("BOSS", "marker_explore_boss.png", 32, "CENTER"),
)

BACKGROUND = "#11161b"
PANEL = "#1a2027"
BORDER = "#4d5964"
TEXT = "#eee8da"
MUTED = "#aeb6be"
CYAN = "#8cc9cf"
GOLD = "#c6a35e"
GRID = (169, 185, 196, 62)


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = ROOT / "assets" / "fonts" / "ark-pixel-12px-proportional-zh_cn.ttf"
    try:
        return ImageFont.truetype(path, size=size)
    except OSError:
        return ImageFont.load_default(size=size)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _dashed_line(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    fill: tuple[int, int, int, int] | str,
    width: int = 2,
    dash: int = 8,
    gap: int = 6,
) -> None:
    x1, y1 = start
    x2, y2 = end
    length = max(abs(x2 - x1), abs(y2 - y1))
    if length == 0:
        return
    for offset in range(0, length + 1, dash + gap):
        ratio_a = offset / length
        ratio_b = min(offset + dash, length) / length
        point_a = (round(x1 + (x2 - x1) * ratio_a), round(y1 + (y2 - y1) * ratio_a))
        point_b = (round(x1 + (x2 - x1) * ratio_b), round(y1 + (y2 - y1) * ratio_b))
        draw.line((point_a, point_b), fill=fill, width=width)


def _dashed_rect(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    fill: tuple[int, int, int, int] | str,
    width: int = 2,
) -> None:
    left, top, right, bottom = box
    _dashed_line(draw, (left, top), (right, top), fill, width)
    _dashed_line(draw, (right, top), (right, bottom), fill, width)
    _dashed_line(draw, (right, bottom), (left, bottom), fill, width)
    _dashed_line(draw, (left, bottom), (left, top), fill, width)


def _draw_grid(image: Image.Image, origin_y: int = 0) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    for index in range(6):
        coordinate = index * PREVIEW_TILE_SIZE
        draw.line((coordinate, origin_y, coordinate, origin_y + 5 * PREVIEW_TILE_SIZE), fill=GRID, width=2)
        draw.line((0, origin_y + coordinate, 5 * PREVIEW_TILE_SIZE, origin_y + coordinate), fill=GRID, width=2)
    image.alpha_composite(overlay)


def _draw_anchor_examples(image: Image.Image, origin_y: int = 0) -> None:
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    center = (
        3 * PREVIEW_TILE_SIZE + PREVIEW_TILE_SIZE // 2,
        origin_y + PREVIEW_TILE_SIZE + PREVIEW_TILE_SIZE // 2,
    )
    centered_side = 32 * PREVIEW_SCALE
    centered_box = (
        center[0] - centered_side // 2,
        center[1] - centered_side // 2,
        center[0] + centered_side // 2,
        center[1] + centered_side // 2,
    )
    _dashed_rect(draw, centered_box, CYAN, width=3)
    draw.line((center[0] - 8, center[1], center[0] + 8, center[1]), fill=CYAN, width=2)
    draw.line((center[0], center[1] - 8, center[0], center[1] + 8), fill=CYAN, width=2)

    anchor = (
        3 * PREVIEW_TILE_SIZE + PREVIEW_TILE_SIZE // 2,
        origin_y + 3 * PREVIEW_TILE_SIZE + PREVIEW_TILE_SIZE // 2,
    )
    bottom_side = 24 * PREVIEW_SCALE
    bottom_box = (
        anchor[0] - bottom_side // 2,
        anchor[1] - bottom_side,
        anchor[0] + bottom_side // 2,
        anchor[1],
    )
    _dashed_rect(draw, bottom_box, GOLD, width=3)
    draw.ellipse((anchor[0] - 5, anchor[1] - 5, anchor[0] + 5, anchor[1] + 5), fill=GOLD)
    image.alpha_composite(overlay)


def _build_map_reference() -> None:
    source = Image.open(MAP_SOURCE).convert("RGBA")
    if source.size != (375, 817):
        raise SystemExit(f"Unexpected Map01 viewport size: {source.size}")
    cropped = source.crop(MAP_CROP)
    if cropped.size != (240, 240):
        raise SystemExit(f"Unexpected Map01 marker crop size: {cropped.size}")
    reference = cropped.resize((480, 480), Image.Resampling.NEAREST)
    _draw_grid(reference)
    _draw_anchor_examples(reference)
    reference.save(MAP_REFERENCE, optimize=True)


def _build_dark_reference() -> None:
    header_height = 56
    board = Image.new("RGBA", (480, 480 + header_height), BACKGROUND)
    draw = ImageDraw.Draw(board)
    draw.rectangle((0, 0, 480, header_height), fill="#0d1116")
    draw.text((18, 13), "DARK CONTRAST TEST ONLY · NOT MAP04", fill=TEXT, font=_font(18))

    map_top = header_height
    palette = ("#171921", "#1c1b26", "#20222a", "#24212b")
    for row in range(5):
        for column in range(5):
            left = column * PREVIEW_TILE_SIZE
            top = map_top + row * PREVIEW_TILE_SIZE
            fill = palette[(row * 3 + column * 2) % len(palette)]
            draw.rectangle((left, top, left + PREVIEW_TILE_SIZE, top + PREVIEW_TILE_SIZE), fill=fill)

    fog_overlay = Image.new("RGBA", board.size, (0, 0, 0, 0))
    fog_draw = ImageDraw.Draw(fog_overlay)
    fog_draw.rectangle(
        (0, map_top, 2 * PREVIEW_TILE_SIZE, map_top + 3 * PREVIEW_TILE_SIZE),
        fill=(3, 6, 10, 188),
    )
    board.alpha_composite(fog_overlay)

    rng = random.Random(120607)
    draw = ImageDraw.Draw(board)
    for _ in range(92):
        x = rng.randrange(2 * PREVIEW_TILE_SIZE + 5, 475)
        y = rng.randrange(map_top + 5, map_top + 475)
        draw.point((x, y), fill=(74, 68, 84, rng.randrange(48, 94)))

    _draw_grid(board, origin_y=header_height)
    _draw_anchor_examples(board, origin_y=header_height)
    board.save(DARK_REFERENCE, optimize=True)


def _build_style_reference() -> None:
    canvas = Image.new("RGBA", (512, 176), BACKGROUND)
    draw = ImageDraw.Draw(canvas)
    draw.text((16, 12), "PROJECT PIXEL ICON STYLE · SHAPE REFERENCE ONLY", fill=TEXT, font=_font(17))
    draw.text(
        (16, 38),
        "hard clusters · dark contour · upper-left light · transparent padding",
        fill=MUTED,
        font=_font(12),
    )

    for index, path in enumerate(ICON_PATHS):
        if not path.is_file():
            raise SystemExit(f"Missing icon style reference: {path}")
        icon = Image.open(path).convert("RGBA")
        if icon.getextrema()[3] == (255, 255):
            raise SystemExit(f"Style icon is unexpectedly opaque: {path}")
        card_left = 16 + index * 124
        draw.rounded_rectangle(
            (card_left, 68, card_left + 108, 160),
            radius=7,
            fill=PANEL,
            outline=BORDER,
            width=2,
        )
        if icon.width > 72 or icon.height > 72:
            icon.thumbnail((72, 72), Image.Resampling.NEAREST)
        x = card_left + (108 - icon.width) // 2
        y = 68 + (92 - icon.height) // 2
        canvas.alpha_composite(icon, (x, y))

    canvas.save(STYLE_REFERENCE, optimize=True)


def _draw_anchor_diagram(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    logical_size: int,
    anchor: str,
) -> None:
    left, top, right, bottom = box
    center_x = (left + right) // 2
    center_y = (top + bottom) // 2
    tile_side = 144
    tile_box = (
        center_x - tile_side // 2,
        center_y - tile_side // 2,
        center_x + tile_side // 2,
        center_y + tile_side // 2,
    )
    draw.rectangle(tile_box, fill="#303942", outline=BORDER, width=2)
    draw.line((center_x, tile_box[1], center_x, tile_box[3]), fill="#56636d", width=1)
    draw.line((tile_box[0], center_y, tile_box[2], center_y), fill="#56636d", width=1)
    marker_side = logical_size * 3
    if anchor == "CENTER":
        marker_box = (
            center_x - marker_side // 2,
            center_y - marker_side // 2,
            center_x + marker_side // 2,
            center_y + marker_side // 2,
        )
        color = CYAN
    else:
        marker_box = (
            center_x - marker_side // 2,
            center_y - marker_side,
            center_x + marker_side // 2,
            center_y,
        )
        color = GOLD
    _dashed_rect(draw, marker_box, color, width=3)
    draw.ellipse((center_x - 5, center_y - 5, center_x + 5, center_y + 5), fill=color)


def _build_anchor_guide() -> None:
    sheet = Image.new("RGB", (1024, 1024), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((40, 28), "MAP01 · SHARED OVERLAY MARKER SIZE / ANCHOR GUIDE", fill=TEXT, font=_font(26))
    draw.text((40, 65), "Reference only. Empty boxes are safe areas, not marker artwork.", fill=MUTED, font=_font(14))
    draw.text((40, 89), "One world cell = 48×48 logical px · runtime textures use nearest filtering", fill=MUTED, font=_font(14))

    card_width = 304
    card_height = 278
    positions = (
        (40, 132), (360, 132), (680, 132),
        (40, 426), (360, 426), (680, 426),
        (360, 720),
    )
    for marker, (left, top) in zip(MARKERS, positions):
        marker_id, filename, logical_size, anchor = marker
        box = (left, top, left + card_width, top + card_height)
        draw.rounded_rectangle(box, radius=8, fill=PANEL, outline=BORDER, width=2)
        draw.text((left + 16, top + 12), marker_id, fill=TEXT, font=_font(17))
        draw.text((left + 16, top + 39), filename, fill=MUTED, font=_font(11))
        draw.text(
            (left + 16, top + 61),
            f"{logical_size}×{logical_size} logical · {logical_size * 3}×{logical_size * 3} @3x",
            fill=MUTED,
            font=_font(11),
        )
        draw.text(
            (left + 16, top + 82),
            f"anchor: {anchor}",
            fill=CYAN if anchor == "CENTER" else GOLD,
            font=_font(11),
        )
        _draw_anchor_diagram(
            draw,
            (left + 8, top + 103, left + card_width - 8, top + card_height - 8),
            logical_size,
            anchor,
        )

    sheet.save(GUIDE_PATH, optimize=True)


def _write_manifest() -> None:
    files = (MAP_REFERENCE, DARK_REFERENCE, STYLE_REFERENCE, GUIDE_PATH)
    payload = {
        "schema_version": 1,
        "purpose": "generation_reference_only",
        "formal_map_scene_modified": False,
        "map_source": MAP_SOURCE.relative_to(ROOT).as_posix(),
        "map_crop": list(MAP_CROP),
        "logical_tile_size": LOGICAL_TILE_SIZE,
        "preview_scale": PREVIEW_SCALE,
        "references": [
            {
                "path": path.relative_to(ROOT).as_posix(),
                "size": list(Image.open(path).size),
                "sha256": _sha256(path),
            }
            for path in files
        ],
        "marker_contract": [
            {
                "id": marker_id,
                "filename": filename,
                "logical_size": [logical_size, logical_size],
                "delivery_size": [logical_size * 3, logical_size * 3],
                "anchor": anchor.lower(),
            }
            for marker_id, filename, logical_size, anchor in MARKERS
        ],
    }
    MANIFEST_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    if not MAP_SOURCE.is_file():
        raise SystemExit(f"Missing Map01 viewport source: {MAP_SOURCE}")
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    _build_map_reference()
    _build_dark_reference()
    _build_style_reference()
    _build_anchor_guide()
    _write_manifest()
    print("MAP01_MARKER_GENERATION_INPUT_OK")
    print(f"Map reference: {MAP_REFERENCE}")
    print(f"Dark reference: {DARK_REFERENCE}")
    print(f"Style reference: {STYLE_REFERENCE}")
    print(f"Anchor guide: {GUIDE_PATH}")
    print(f"Manifest: {MANIFEST_PATH}")


if __name__ == "__main__":
    main()
