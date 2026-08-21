#!/usr/bin/env python3
"""Build reference crops and the generation requirement sheet for Map01's derelict camp.

The output is generation input only. It deliberately keeps the camp base separate
from the corpse-evidence overlay, because corpse handling and the remote ledger
event are independent product objects rather than mutually exclusive camp states.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_visual" / "map01_visual_mother_20260820.png"
OUTPUT_DIR = ROOT / "art" / "candidates" / "map01_camp"
REFERENCE_DIR = OUTPUT_DIR / "reference"
REQUIREMENT_PATH = OUTPUT_DIR / "map01_batch_e_camp_requirement.png"

EXPECTED_SOURCE_SIZE = (1086, 1448)
SUBJECT_REFERENCE_BBOX = (350, 1080, 530, 1255)
CONTEXT_REFERENCE_BBOX = (285, 1040, 705, 1305)

BACKGROUND = "#14171b"
CARD = "#1b2026"
CARD_BORDER = "#4a535c"
TEXT = "#eee8da"
MUTED = "#aeb6be"
STONE = "#4f5e67"
STONE_DARK = "#303d46"
CANVAS = "#68675f"
CANVAS_DARK = "#454942"
WOOD = "#756b55"
OLD_GOLD = "#977e52"
DARK_RED = "#6f3e45"
SHROUD = "#777c79"
SHROUD_DARK = "#474f50"
COLLISION = "#c49b68"
ANCHOR = "#c5a35b"
GRID = "#77808a"


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


def _grid(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], columns: int = 4, rows: int = 3) -> None:
    left, top, right, bottom = box
    draw.rectangle(box, fill="#20262c", outline=CARD_BORDER, width=2)
    for column in range(1, columns):
        x = round(left + (right - left) * column / columns)
        draw.line((x, top, x, bottom), fill=GRID, width=1)
    for row in range(1, rows):
        y = round(top + (bottom - top) * row / rows)
        draw.line((left, y, right, y), fill=GRID, width=1)


def _tent(draw: ImageDraw.ImageDraw, center: tuple[int, int], width: int, height: int) -> None:
    x, y = center
    points = ((x, y - height // 2), (x + width // 2, y), (x, y + height // 2), (x - width // 2, y))
    draw.polygon(points, fill=CANVAS, outline=STONE_DARK)
    draw.line((x, y - height // 2 + 4, x, y + height // 2 - 4), fill=CANVAS_DARK, width=3)
    for px, py in points:
        draw.ellipse((px - 3, py - 3, px + 3, py + 3), fill=OLD_GOLD)


def _camp_base(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], show_collisions: bool = True) -> None:
    left, top, right, bottom = box
    width = right - left
    height = bottom - top
    _tent(draw, (round(left + width * 0.27), round(top + height * 0.42)), round(width * 0.24), round(height * 0.38))
    _tent(draw, (round(left + width * 0.52), round(top + height * 0.52)), round(width * 0.27), round(height * 0.42))
    pole_y = round(top + height * 0.77)
    draw.line((round(left + width * 0.18), pole_y, round(left + width * 0.45), pole_y - 14), fill=WOOD, width=7)
    draw.line((round(left + width * 0.21), pole_y + 7, round(left + width * 0.48), pole_y - 7), fill=STONE_DARK, width=3)
    draw.polygon(
        (
            (round(left + width * 0.23), pole_y - 2),
            (round(left + width * 0.42), pole_y - 12),
            (round(left + width * 0.43), pole_y + 1),
            (round(left + width * 0.26), pole_y + 10),
        ),
        fill=DARK_RED,
        outline=STONE_DARK,
    )
    draw.rectangle(
        (
            round(left + width * 0.53), round(top + height * 0.73),
            round(left + width * 0.66), round(top + height * 0.83),
        ),
        fill=WOOD,
        outline=STONE_DARK,
        width=2,
    )
    if show_collisions:
        _dashed_rect(
            draw,
            (
                round(left + width * 0.14), round(top + height * 0.23),
                round(left + width * 0.39), round(top + height * 0.62),
            ),
            COLLISION,
        )
        _dashed_rect(
            draw,
            (
                round(left + width * 0.39), round(top + height * 0.31),
                round(left + width * 0.66), round(top + height * 0.72),
            ),
            COLLISION,
        )


def _evidence_default(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    width = right - left
    height = bottom - top
    for cx, cy, angle in ((0.77, 0.43, -1), (0.85, 0.65, 1)):
        x = round(left + width * cx)
        y = round(top + height * cy)
        w = round(width * 0.07)
        h = round(height * 0.13)
        points = ((x - w, y - h // 2), (x + w, y - h // 3), (x + w - 4, y + h // 2), (x - w + 3, y + h // 3))
        draw.polygon(points if angle < 0 else tuple(reversed(points)), fill=SHROUD, outline=SHROUD_DARK)
        draw.line((x - w // 3, y, x + w // 3, y), fill=OLD_GOLD, width=2)
    draw.line(
        (
            round(left + width * 0.70), round(top + height * 0.24),
            round(left + width * 0.87), round(top + height * 0.33),
        ),
        fill=DARK_RED,
        width=3,
    )


def _evidence_processed(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    width = right - left
    height = bottom - top
    for cx, cy in ((0.77, 0.44), (0.85, 0.66)):
        x = round(left + width * cx)
        y = round(top + height * cy)
        draw.line((x - 12, y - 3, x + 13, y + 2), fill=SHROUD_DARK, width=3)
        draw.rectangle((x + 3, y - 7, x + 12, y - 2), fill=OLD_GOLD)
    draw.line(
        (
            round(left + width * 0.73), round(top + height * 0.29),
            round(left + width * 0.84), round(top + height * 0.35),
        ),
        fill="#574348",
        width=2,
    )


def _anchor(draw: ImageDraw.ImageDraw, x: int, y: int) -> None:
    draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=ANCHOR, outline=TEXT, width=2)
    draw.line((x - 12, y, x + 12, y), fill=ANCHOR, width=2)
    draw.line((x, y - 12, x, y + 12), fill=ANCHOR, width=2)


def _build_requirement() -> None:
    sheet = Image.new("RGB", (1024, 1024), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    title_font = _font(28)
    id_font = _font(18)
    text_font = _font(14)
    note_font = _font(12)

    draw.text((48, 34), "MAP01 · BATCH E · DERELICT CAMP LAYERED REQUIREMENT", fill=TEXT, font=title_font)
    draw.text((48, 72), "Static camp base + independent corpse-evidence overlay. Ledger remains a separate map object.", fill=MUTED, font=text_font)
    draw.rounded_rectangle((48, 102, 976, 168), radius=8, fill="#20272f", outline=CARD_BORDER, width=2)
    draw.text((70, 120), "SOURCE CANVAS 72×56 px · ART ABOUT 64×48 px · BOTTOM-CENTER ANCHOR (36,52)", fill=MUTED, font=text_font)
    draw.text((70, 145), "VISUAL 4×3 CELLS · BASE COMPOUND COLLISION: 20×14 + 22×16 px · OVERLAY HAS NO COLLISION", fill=MUTED, font=note_font)

    cards = ((48, 190, 976, 430), (48, 450, 976, 685), (48, 705, 976, 940))
    for box in cards:
        draw.rounded_rectangle(box, radius=10, fill=CARD, outline=CARD_BORDER, width=2)

    draw.text((68, 210), "CAMP_STAY_BASE", fill=TEXT, font=id_font)
    draw.text((68, 241), "unchanging landmark · two collapsed canvas roofs", fill=MUTED, font=note_font)
    draw.text((68, 265), "flat fallen banner · low supply frame", fill=MUTED, font=note_font)
    draw.text((68, 289), "no corpses · no ledger · no wall, road or ground", fill=MUTED, font=note_font)
    base_box = (430, 225, 814, 405)
    _grid(draw, base_box)
    _camp_base(draw, base_box)
    _anchor(draw, 622, 405)
    draw.text((830, 270), "4×3 visual", fill=MUTED, font=note_font)
    draw.text((830, 294), "2 collision rects", fill=COLLISION, font=note_font)
    draw.text((830, 318), "same in all states", fill=MUTED, font=note_font)

    draw.text((68, 470), "CAMP_CORPSES_DEFAULT", fill=TEXT, font=id_font)
    draw.text((68, 501), "same base + two small fully covered grey shrouds", fill=MUTED, font=note_font)
    draw.text((68, 525), "right-side evidence socket only", fill=MUTED, font=note_font)
    draw.text((68, 549), "no anatomy/gore/bones · overlay has no collision", fill=MUTED, font=note_font)
    default_box = (430, 488, 814, 660)
    _grid(draw, default_box)
    _camp_base(draw, default_box, show_collisions=False)
    _evidence_default(draw, default_box)
    _anchor(draw, 622, 660)

    draw.text((68, 725), "CAMP_CORPSES_PROCESSED", fill=TEXT, font=id_font)
    draw.text((68, 756), "same base · covered remains removed", fill=MUTED, font=note_font)
    draw.text((68, 780), "only folded binding cloth + short dull traces", fill=MUTED, font=note_font)
    draw.text((68, 804), "no repair, reward, marker, text, aura or ledger", fill=MUTED, font=note_font)
    processed_box = (430, 744, 814, 916)
    _grid(draw, processed_box)
    _camp_base(draw, processed_box, show_collisions=False)
    _evidence_processed(draw, processed_box)
    _anchor(draw, 622, 916)

    draw.text((48, 968), "EXCLUDED: m1_event_ledger / CAMP_LEDGER_READ. The ledger is remote and independent; do not bake it into this sprite.", fill="#d39a83", font=note_font)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(REQUIREMENT_PATH, optimize=True)


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing Map01 visual mother: {SOURCE}")
    master = Image.open(SOURCE).convert("RGBA")
    if master.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Unexpected Map01 visual mother size: {master.size}")
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    master.crop(SUBJECT_REFERENCE_BBOX).save(REFERENCE_DIR / "map01_camp_subject_reference.png", optimize=True)
    master.crop(CONTEXT_REFERENCE_BBOX).save(REFERENCE_DIR / "map01_camp_context_reference.png", optimize=True)
    _build_requirement()
    print("Map01 camp generation input OK; layered base/corpse evidence contract preserved")
    print(f"Subject reference: {REFERENCE_DIR / 'map01_camp_subject_reference.png'}")
    print(f"Context reference: {REFERENCE_DIR / 'map01_camp_context_reference.png'}")
    print(f"Requirement: {REQUIREMENT_PATH}")


if __name__ == "__main__":
    main()
