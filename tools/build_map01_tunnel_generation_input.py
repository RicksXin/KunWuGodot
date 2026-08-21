#!/usr/bin/env python3
"""Build the Map01 mountain-tunnel reference crops and requirement sheet.

These outputs are generation inputs only. The tunnel keeps one static rock base,
one separately fadeable roof and a center-only visual state insert. Runtime state,
collision and dungeon transitions remain external product responsibilities.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_visual" / "map01_visual_mother_20260820.png"
BASE_SOURCE = ROOT / "assets" / "maps" / "map_01" / "blockers" / "tunnel_stay_base.png"
ROOF_SOURCE = ROOT / "assets" / "maps" / "map_01" / "blockers" / "tunnel_roof_foreground.png"
OUTPUT_DIR = ROOT / "art" / "candidates" / "map01_tunnel"
REFERENCE_DIR = OUTPUT_DIR / "reference"
REQUIREMENT_PATH = OUTPUT_DIR / "map01_batch_e_tunnel_requirement.png"

EXPECTED_SOURCE_SIZE = (1086, 1448)
CONTEXT_REFERENCE_BBOX = (70, 345, 455, 705)

BACKGROUND = "#14171b"
CARD = "#1b2026"
CARD_BORDER = "#4a535c"
TEXT = "#eee8da"
MUTED = "#aeb6be"
GRID = "#77808a"
STONE = "#53636c"
STONE_LIGHT = "#6f7b80"
STONE_DARK = "#303d46"
PATH = "#7f7d70"
RUBBLE = "#46535a"
WOOD = "#756b55"
EMBER = "#9e5d44"
WARM = "#eee0b5"
FADE = "#66899b"
COLLISION = "#c49b68"
ANCHOR = "#c5a35b"


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    path = ROOT / "assets" / "fonts" / "ark-pixel-12px-proportional-zh_cn.ttf"
    try:
        return ImageFont.truetype(path, size=size)
    except OSError:
        return ImageFont.load_default(size=size)


def _dashed_line(
    draw: ImageDraw.ImageDraw,
    start: tuple[int, int],
    end: tuple[int, int],
    fill: str,
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
        a = (round(x1 + (x2 - x1) * ratio_a), round(y1 + (y2 - y1) * ratio_a))
        b = (round(x1 + (x2 - x1) * ratio_b), round(y1 + (y2 - y1) * ratio_b))
        draw.line((a, b), fill=fill, width=width)


def _dashed_rect(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], fill: str, width: int = 2) -> None:
    left, top, right, bottom = box
    _dashed_line(draw, (left, top), (right, top), fill, width)
    _dashed_line(draw, (right, top), (right, bottom), fill, width)
    _dashed_line(draw, (right, bottom), (left, bottom), fill, width)
    _dashed_line(draw, (left, bottom), (left, top), fill, width)


def _grid(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    draw.rectangle(box, fill="#20262c", outline=CARD_BORDER, width=2)
    for column in range(1, 4):
        x = round(left + (right - left) * column / 4)
        draw.line((x, top, x, bottom), fill=GRID, width=1)
    for row in range(1, 3):
        y = round(top + (bottom - top) * row / 3)
        draw.line((left, y, right, y), fill=GRID, width=1)


def _anchor(draw: ImageDraw.ImageDraw, x: int, y: int) -> None:
    draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=ANCHOR, outline=TEXT, width=2)
    draw.line((x - 12, y, x + 12, y), fill=ANCHOR, width=2)
    draw.line((x, y - 12, x, y + 12), fill=ANCHOR, width=2)


def _tunnel(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], state: str) -> None:
    left, top, right, bottom = box
    width = right - left
    height = bottom - top
    center_x = round((left + right) * 0.5)

    # Flat plan-view rock shoulders around one north-running entrance strip.
    shoulder_top = round(top + height * 0.38)
    shoulder_bottom = round(top + height * 0.90)
    gap_half = round(width * 0.075)
    side_pad = round(width * 0.09)
    left_shoulder = (
        (left + side_pad + 5, shoulder_top + 8),
        (left + round(width * 0.23), shoulder_top - 3),
        (center_x - gap_half - 13, shoulder_top + 5),
        (center_x - gap_half, shoulder_top + 22),
        (center_x - gap_half + 2, shoulder_bottom - 4),
        (left + round(width * 0.32), shoulder_bottom + 2),
        (left + round(width * 0.20), shoulder_bottom - 7),
        (left + side_pad, shoulder_bottom - 19),
    )
    right_shoulder = tuple((left + right - x, y) for x, y in left_shoulder)
    draw.polygon(left_shoulder, fill=STONE, outline=STONE_DARK)
    draw.polygon(right_shoulder, fill=STONE, outline=STONE_DARK)
    draw.line((left + round(width * 0.18), shoulder_top + 18, center_x - gap_half - 10, shoulder_top + 12), fill=STONE_LIGHT, width=4)
    draw.line((right - round(width * 0.18), shoulder_top + 18, center_x + gap_half + 10, shoulder_top + 12), fill=STONE_LIGHT, width=4)

    # One irregular flat rock mass crossing above the path. It is a plan-view foreground cap.
    roof = (
        (left + side_pad + 4, top + 38),
        (left + round(width * 0.18), top + 20),
        (left + round(width * 0.32), top + 27),
        (left + round(width * 0.43), top + 14),
        (center_x, top + 23),
        (right - round(width * 0.43), top + 14),
        (right - round(width * 0.32), top + 27),
        (right - round(width * 0.18), top + 20),
        (right - side_pad - 4, top + 38),
        (right - side_pad - 17, shoulder_top + 20),
        (right - round(width * 0.27), shoulder_top + 13),
        (center_x + gap_half + 8, shoulder_top + 22),
        (center_x, shoulder_top + 14),
        (center_x - gap_half - 8, shoulder_top + 22),
        (left + round(width * 0.27), shoulder_top + 13),
        (left + side_pad + 17, shoulder_top + 20),
    )
    draw.polygon(roof, fill=FADE, outline="#8eb0c2")
    draw.polygon(
        (
            (left + round(width * 0.22), top + 33),
            (left + round(width * 0.34), top + 28),
            (left + round(width * 0.40), top + 37),
            (left + round(width * 0.28), top + 43),
        ),
        fill=STONE_LIGHT,
    )

    state_left = center_x - gap_half + 2
    state_right = center_x + gap_half - 2
    state_top = shoulder_top + 8
    state_bottom = bottom - 1
    _dashed_rect(draw, (state_left - 7, state_top - 5, state_right + 7, state_bottom + 2), MUTED, width=1)
    if state == "default":
        draw.polygon(
            (
                (state_left - 5, state_top + 10),
                (center_x - 3, state_top),
                (state_right + 4, state_top + 8),
                (state_right - 2, state_bottom - 4),
                (state_left + 2, state_bottom - 1),
            ),
            fill=RUBBLE,
            outline=STONE_DARK,
        )
        draw.rectangle((center_x - 9, state_top + 17, center_x - 3, state_top + 23), fill=STONE_LIGHT)
        draw.rectangle((center_x + 3, state_top + 28, center_x + 10, state_top + 35), fill=STONE_DARK)
    elif state == "discovered":
        draw.polygon(
            ((state_left + 3, state_top), (state_right - 3, state_top), (state_right + 1, state_bottom), (state_left - 1, state_bottom)),
            fill=STONE_DARK,
        )
        draw.line((state_left - 3, state_top + 8, center_x - 4, state_top + 16), fill=RUBBLE, width=5)
        draw.line((center_x + 5, state_top + 24, state_right + 2, state_top + 31), fill=RUBBLE, width=4)
        draw.line((center_x - 10, state_bottom - 12, center_x + 10, state_bottom - 9), fill=WOOD, width=3)
        draw.rectangle((center_x - 3, state_top + 14, center_x + 3, state_top + 20), fill=EMBER)
    else:
        draw.polygon(
            (
                (state_left + 1, state_top),
                (state_right - 1, state_top),
                (state_right + 5, state_bottom),
                (state_left - 5, state_bottom),
            ),
            fill=PATH,
            outline=STONE_DARK,
        )
        draw.line((center_x - 10, state_bottom - 12, center_x + 10, state_bottom - 9), fill=WOOD, width=3)
        draw.rectangle((center_x - 3, state_top + 13, center_x + 3, state_top + 19), fill=WOOD)
        draw.rectangle((center_x - 1, state_top + 14, center_x + 1, state_top + 17), fill=WARM)

    collision_top = round(top + height * 0.62)
    _dashed_rect(draw, (left + round(width * 0.17), collision_top, center_x - gap_half - 7, shoulder_bottom - 2), COLLISION)
    _dashed_rect(draw, (center_x + gap_half + 7, collision_top, right - round(width * 0.17), shoulder_bottom - 2), COLLISION)
    _anchor(draw, center_x, bottom)


def _build_layer_reference() -> Path:
    base = Image.open(BASE_SOURCE).convert("RGBA")
    roof = Image.open(ROOF_SOURCE).convert("RGBA")
    scale = 5
    sheet = Image.new("RGB", (720, 250), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    label_font = _font(18)
    note_font = _font(12)
    draw.rounded_rectangle((20, 18, 346, 232), radius=8, fill=CARD, outline=CARD_BORDER, width=2)
    draw.rounded_rectangle((374, 18, 700, 232), radius=8, fill=CARD, outline=CARD_BORDER, width=2)
    draw.text((36, 34), "EXISTING TECHNICAL STAY BASE", fill=TEXT, font=label_font)
    draw.text((390, 34), "EXISTING TECHNICAL FADE ROOF", fill=TEXT, font=label_font)
    draw.text((36, 204), "use layer logic only; redesign final silhouette", fill=MUTED, font=note_font)
    draw.text((390, 204), "same anchor; top-view; no cave facade", fill=MUTED, font=note_font)
    base_preview = base.resize((base.width * scale, base.height * scale), Image.Resampling.NEAREST)
    roof_preview = roof.resize((roof.width * scale, roof.height * scale), Image.Resampling.NEAREST)
    sheet.paste(base_preview, (38, 68), base_preview)
    sheet.paste(roof_preview, (392, 68), roof_preview)
    path = REFERENCE_DIR / "map01_tunnel_layer_reference.png"
    sheet.save(path, optimize=True)
    return path


def _build_requirement() -> None:
    sheet = Image.new("RGB", (1024, 1024), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    title_font = _font(27)
    id_font = _font(18)
    text_font = _font(14)
    note_font = _font(12)

    draw.text((48, 34), "MAP01 · BATCH E · MOUNTAIN TUNNEL LAYERED REQUIREMENT", fill=TEXT, font=title_font)
    draw.text((48, 72), "One rock shell + one fadeable top cap + center-only state insert. No cave facade or black-hole icon.", fill=MUTED, font=text_font)
    draw.rounded_rectangle((48, 102, 976, 168), radius=8, fill="#20272f", outline=CARD_BORDER, width=2)
    draw.text((70, 120), "SOURCE CANVAS 72×56 px · ART ABOUT 64×48 px · BOTTOM-CENTER ANCHOR (36,52)", fill=MUTED, font=text_font)
    draw.text((70, 145), "VISUAL 4×3 CELLS · TWO ROCK-SHOULDER COLLISIONS · TOP CAP FADES · CENTER STATE IS VISUAL ONLY", fill=MUTED, font=note_font)

    cards = ((48, 190, 976, 430), (48, 450, 976, 685), (48, 705, 976, 940))
    for box in cards:
        draw.rounded_rectangle(box, radius=10, fill=CARD, outline=CARD_BORDER, width=2)

    rows = (
        (cards[0], "TUNNEL_DEFAULT", "cold ordinary collapse · no furnace cue · entrance not yet readable", "default"),
        (cards[1], "TUNNEL_DISCOVERED", "narrow readable fissure · small dull forge ember · interaction available", "discovered"),
        (cards[2], "TUNNEL_CLEARED", "center route cleared · tiny steady warm-white forge trace · remains passable", "cleared"),
    )
    for box, state_id, note, state in rows:
        left, top, _right, bottom = box
        draw.text((left + 20, top + 20), state_id, fill=TEXT, font=id_font)
        draw.text((left + 20, top + 51), note, fill=MUTED, font=note_font)
        draw.text((left + 20, top + 79), "same outer rock / same roof / same anchor", fill=MUTED, font=note_font)
        draw.text((left + 20, top + 103), "no NPC, marker, dungeon room or reward", fill=MUTED, font=note_font)
        art_box = (430, top + 46, 814, bottom - 20)
        _grid(draw, art_box)
        _tunnel(draw, art_box, state)
        draw.text((830, top + 90), "cyan: fade roof", fill=FADE, font=note_font)
        draw.text((830, top + 116), "gold: collisions", fill=COLLISION, font=note_font)
        draw.text((830, top + 142), "center: state only", fill=MUTED, font=note_font)

    draw.text((48, 968), "EXCLUDED: facade, cliff side, tunnel depth, large fire/glow, Gu Nanlu, enemies, loot, text, floor tile or formal map coordinate.", fill="#d39a83", font=note_font)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(REQUIREMENT_PATH, optimize=True)


def main() -> None:
    for source_path in (SOURCE, BASE_SOURCE, ROOF_SOURCE):
        if not source_path.is_file():
            raise SystemExit(f"Missing tunnel generation input: {source_path}")
    master = Image.open(SOURCE).convert("RGBA")
    if master.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Unexpected Map01 visual mother size: {master.size}")
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    master.crop(CONTEXT_REFERENCE_BBOX).save(REFERENCE_DIR / "map01_tunnel_context_reference.png", optimize=True)
    layer_reference = _build_layer_reference()
    _build_requirement()
    print("Map01 tunnel generation input OK; layered roof/base and three-state center contract preserved")
    print(f"Context reference: {REFERENCE_DIR / 'map01_tunnel_context_reference.png'}")
    print(f"Layer reference: {layer_reference}")
    print(f"Requirement: {REQUIREMENT_PATH}")


if __name__ == "__main__":
    main()
