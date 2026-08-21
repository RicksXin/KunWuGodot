#!/usr/bin/env python3
"""Build Map01 east-wall stair generation references and requirement sheet.

The outputs are generation inputs only.  They freeze the two-state visual contract,
source canvas, anchor and collision semantics without claiming that the candidate
Map01 coordinate is a formal runtime coordinate.
"""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
OVERVIEW_SOURCE = ROOT / "art" / "review" / "map01" / "map01_d1_landmark_overview.png"
RIDGE_SOURCE = ROOT / "assets" / "maps" / "map_01" / "blockers" / "ridge_ne_sw_base.png"
LAMP_CLOSED_SOURCE = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "array_lamp" / "array_lamp_broken.png"
LAMP_OPEN_SOURCE = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "array_lamp" / "array_lamp_repaired.png"
OUTPUT_DIR = ROOT / "art" / "candidates" / "map01_stairs"
REFERENCE_DIR = OUTPUT_DIR / "reference"
CONTEXT_PATH = REFERENCE_DIR / "map01_stairs_e_zone_context.png"
STYLE_PATH = REFERENCE_DIR / "map01_stairs_style_reference.png"
REQUIREMENT_PATH = OUTPUT_DIR / "map01_batch_e_stairs_requirement.png"
SPEC_PATH = OUTPUT_DIR / "map01_stairs_candidate_spec.json"

OVERVIEW_SIZE = (2352, 3120)
MAP_BORDER_PX = 24
DISPLAY_CELL_PX = 48
CANDIDATE_DOCUMENT_CELL = (39, 31)
CONTEXT_SIZE = (375, 817)

BACKGROUND = "#14171b"
CARD = "#1b2026"
CARD_BORDER = "#4a535c"
TEXT = "#eee8da"
MUTED = "#aeb6be"
GRID = "#66717a"
STONE_DARK = "#303d46"
STONE = "#53636c"
STONE_LIGHT = "#6f7b80"
ROAD = "#8b8069"
OLD_GOLD = "#977e52"
DARK_RED = "#6f3e45"
WARM = "#eee0b5"
STATIC_COLLISION = "#c49b68"
CLOSED_COLLISION = "#a85b5b"
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


def _anchor(draw: ImageDraw.ImageDraw, x: int, y: int) -> None:
    draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=ANCHOR, outline=TEXT, width=2)
    draw.line((x - 12, y, x + 12, y), fill=ANCHOR, width=2)
    draw.line((x, y - 12, x, y + 12), fill=ANCHOR, width=2)


def _grid(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int]) -> None:
    left, top, right, bottom = box
    draw.rectangle(box, fill="#20262c", outline=CARD_BORDER, width=2)
    for column in range(1, 4):
        x = round(left + (right - left) * column / 4)
        draw.line((x, top, x, bottom), fill=GRID, width=1)
    for row in range(1, 3):
        y = round(top + (bottom - top) * row / 3)
        draw.line((left, y, right, y), fill=GRID, width=1)


def _stairs(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], state: str) -> None:
    """Draw a flat plan-view diagram, deliberately without any vertical faces."""
    left, top, right, bottom = box
    width = right - left
    height = bottom - top
    center_x = round((left + right) * 0.5)
    outer_left = left + round(width * 0.17)
    outer_right = right - round(width * 0.17)
    passage_left = center_x - round(width * 0.115)
    passage_right = center_x + round(width * 0.115)
    run_top = top + round(height * 0.10)
    run_bottom = bottom - round(height * 0.06)

    # Two low top-view carved stone cheeks. They are static in both states.
    left_cheek = (
        (outer_left + 6, run_top + 8),
        (passage_left - 7, run_top),
        (passage_left - 2, run_bottom - 4),
        (outer_left - 5, run_bottom - 11),
        (outer_left, round((run_top + run_bottom) * 0.58)),
    )
    right_cheek = tuple((left + right - x, y) for x, y in left_cheek)
    draw.polygon(left_cheek, fill=STONE, outline=STONE_DARK)
    draw.polygon(right_cheek, fill=STONE, outline=STONE_DARK)
    draw.line((outer_left + 8, run_top + 15, passage_left - 8, run_top + 9), fill=STONE_LIGHT, width=3)
    draw.line((outer_right - 8, run_top + 15, passage_right + 8, run_top + 9), fill=STONE_LIGHT, width=3)

    # The stair run is a flat north-running strip; seams have no shaded risers.
    draw.polygon(
        (
            (passage_left + 2, run_top),
            (passage_right - 2, run_top),
            (passage_right + 2, run_bottom),
            (passage_left - 2, run_bottom),
        ),
        fill=ROAD,
        outline=STONE_DARK,
    )
    for index in range(1, 6):
        y = round(run_top + (run_bottom - run_top) * index / 6)
        draw.line((passage_left + 2, y, passage_right - 2, y), fill="#756f61", width=2)

    if state == "closed":
        barrier_y = round(run_top + (run_bottom - run_top) * 0.58)
        draw.polygon(
            (
                (passage_left - 12, barrier_y - 8),
                (passage_right + 13, barrier_y - 5),
                (passage_right + 10, barrier_y + 9),
                (center_x + 4, barrier_y + 5),
                (center_x - 2, barrier_y + 10),
                (passage_left - 14, barrier_y + 5),
            ),
            fill=STONE_DARK,
            outline=STONE,
        )
        draw.rectangle((passage_left - 7, barrier_y - 6, passage_left - 2, barrier_y + 6), fill=OLD_GOLD)
        draw.rectangle((passage_right + 1, barrier_y - 5, passage_right + 6, barrier_y + 7), fill=OLD_GOLD)
        draw.line((center_x - 7, barrier_y + 12, center_x - 1, barrier_y + 16), fill=DARK_RED, width=3)
        draw.line((center_x + 3, barrier_y + 12, center_x + 8, barrier_y + 15), fill=DARK_RED, width=2)
        _dashed_rect(
            draw,
            (passage_left - 16, barrier_y - 12, passage_right + 16, barrier_y + 19),
            CLOSED_COLLISION,
        )
    else:
        # The same broken cross-stone is parked flat against the cheeks.
        mid_y = round(run_top + (run_bottom - run_top) * 0.58)
        draw.polygon(
            (
                (outer_left + 2, mid_y - 7),
                (passage_left - 4, mid_y - 4),
                (passage_left - 5, mid_y + 6),
                (outer_left - 1, mid_y + 5),
            ),
            fill=STONE_DARK,
            outline=STONE,
        )
        draw.polygon(
            (
                (passage_right + 4, mid_y - 4),
                (outer_right - 2, mid_y - 7),
                (outer_right + 1, mid_y + 5),
                (passage_right + 5, mid_y + 6),
            ),
            fill=STONE_DARK,
            outline=STONE,
        )
        draw.line((passage_left + 5, run_top + 8, passage_left + 5, run_bottom - 8), fill=WARM, width=2)
        draw.line((passage_right - 5, run_top + 8, passage_right - 5, run_bottom - 8), fill=WARM, width=2)

    static_top = round(run_top + height * 0.26)
    _dashed_rect(draw, (outer_left - 8, static_top, passage_left - 5, run_bottom - 5), STATIC_COLLISION)
    _dashed_rect(draw, (passage_right + 5, static_top, outer_right + 8, run_bottom - 5), STATIC_COLLISION)
    _anchor(draw, center_x, bottom)


def _build_context_reference() -> None:
    overview = Image.open(OVERVIEW_SOURCE).convert("RGBA")
    if overview.size != OVERVIEW_SIZE:
        raise SystemExit(f"Unexpected Map01 landmark overview size: {overview.size}")
    cell_x, cell_y = CANDIDATE_DOCUMENT_CELL
    anchor_x = MAP_BORDER_PX + round((cell_x + 0.5) * DISPLAY_CELL_PX)
    anchor_y = MAP_BORDER_PX + round((cell_y + 1.0) * DISPLAY_CELL_PX)
    crop_left = anchor_x - CONTEXT_SIZE[0] // 2
    crop_top = anchor_y - CONTEXT_SIZE[1] // 2
    crop = overview.crop((crop_left, crop_top, crop_left + CONTEXT_SIZE[0], crop_top + CONTEXT_SIZE[1]))
    crop.save(CONTEXT_PATH, optimize=True)


def _build_style_reference() -> None:
    ridge = Image.open(RIDGE_SOURCE).convert("RGBA")
    lamp_closed = Image.open(LAMP_CLOSED_SOURCE).convert("RGBA")
    lamp_open = Image.open(LAMP_OPEN_SOURCE).convert("RGBA")
    sheet = Image.new("RGB", (720, 300), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    title_font = _font(19)
    note_font = _font(13)
    draw.text((24, 18), "MAP01 STYLE REFERENCE · MATERIAL + PIXEL DENSITY", fill=TEXT, font=title_font)
    cards = ((20, 56, 280, 270), (300, 56, 490, 270), (510, 56, 700, 270))
    for box in cards:
        draw.rounded_rectangle(box, radius=8, fill=CARD, outline=CARD_BORDER, width=2)
    ridge_preview = ridge.resize((ridge.width * 4, ridge.height * 4), Image.Resampling.NEAREST)
    closed_preview = lamp_closed.resize((lamp_closed.width * 4, lamp_closed.height * 4), Image.Resampling.NEAREST)
    open_preview = lamp_open.resize((lamp_open.width * 4, lamp_open.height * 4), Image.Resampling.NEAREST)
    sheet.paste(ridge_preview, (46, 78), ridge_preview)
    sheet.paste(closed_preview, (315, 78), closed_preview)
    sheet.paste(open_preview, (525, 78), open_preview)
    draw.text((40, 242), "grey-blue stone · flat top view", fill=MUTED, font=note_font)
    draw.text((316, 242), "broken · dark red restrained", fill=MUTED, font=note_font)
    draw.text((526, 242), "open · warm ivory restrained", fill=MUTED, font=note_font)
    sheet.save(STYLE_PATH, optimize=True)


def _build_requirement() -> None:
    sheet = Image.new("RGB", (1024, 1024), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    title_font = _font(27)
    id_font = _font(19)
    text_font = _font(14)
    note_font = _font(12)

    draw.text((46, 32), "MAP01 · BATCH E · EAST-WALL PERMANENT STAIRS", fill=TEXT, font=title_font)
    draw.text((46, 70), "One flat stair run, two visual states, one anchor. No riser facade, platform thickness or perspective.", fill=MUTED, font=text_font)
    draw.rounded_rectangle((46, 100, 978, 168), radius=8, fill="#20272f", outline=CARD_BORDER, width=2)
    draw.text((66, 119), "SOURCE CANVAS 72×56 px · ART ABOUT 64×48 px · BOTTOM-CENTER ANCHOR (36,52)", fill=MUTED, font=text_font)
    draw.text((66, 145), "VISUAL 4×3 CELLS · STATIC STONE CHEEKS · CENTER BLOCKER CHANGES PASSAGE SEMANTICS", fill=MUTED, font=note_font)

    cards = ((46, 190, 978, 535), (46, 555, 978, 900))
    rows = (
        (
            cards[0],
            "STAIRS_CLOSED",
            ("same flat stair run · cross-stone blocks center", "tiny old-gold fasteners · dull dark-red lock traces"),
            "closed",
        ),
        (
            cards[1],
            "STAIRS_OPEN",
            ("same outer silhouette · cross-stone lies at sides", "continuous center strip · thin warm-ivory edge traces"),
            "open",
        ),
    )
    for box, state_id, notes, state in rows:
        left, top, _right, bottom = box
        draw.rounded_rectangle(box, radius=10, fill=CARD, outline=CARD_BORDER, width=2)
        draw.text((left + 20, top + 20), state_id, fill=TEXT, font=id_font)
        draw.text((left + 20, top + 54), notes[0], fill=MUTED, font=note_font)
        draw.text((left + 20, top + 78), notes[1], fill=MUTED, font=note_font)
        draw.text((left + 20, top + 110), "exact 90-degree overhead · north-running strip", fill=MUTED, font=note_font)
        draw.text((left + 20, top + 136), "same canvas / outer stone / scale / anchor", fill=MUTED, font=note_font)
        draw.text((left + 20, top + 162), "no enemy, marker, ground tile, cliff or reward", fill=MUTED, font=note_font)
        art_box = (430, top + 45, 814, bottom - 20)
        _grid(draw, art_box)
        _stairs(draw, art_box, state)
        draw.text((832, top + 92), "gold dash: static", fill=STATIC_COLLISION, font=note_font)
        draw.text((832, top + 118), "red dash: closed only", fill=CLOSED_COLLISION, font=note_font)
        draw.text((832, top + 144), "center: passage", fill=MUTED, font=note_font)

    draw.text((46, 930), "CANDIDATE ONLY: stair anchor (39,31); elite candidate moved to (36,29); formal runtime coordinates remain UNVERIFIED.", fill="#d4b87d", font=note_font)
    draw.text((46, 957), "EXCLUDED: stair front/side faces, slope or cliff facade, shadows, large glow, text, icon, character, enemy, loot, ground or chroma green.", fill="#d39a83", font=note_font)
    sheet.save(REQUIREMENT_PATH, optimize=True)


def _write_spec() -> None:
    spec = {
        "version": 1,
        "status": "generation_input_candidate",
        "mapId": "map_01",
        "assetFamily": "east_wall_permanent_stairs",
        "states": ["STAIRS_CLOSED", "STAIRS_OPEN"],
        "canvasPx": [72, 56],
        "subjectMaxPx": [64, 48],
        "anchorPx": [36, 52],
        "visualFootprintCells": [4, 3],
        "runtimeDisplayScale": 3,
        "mapSceneRootScale": 0.1875,
        "mapSceneInstanceScale": 16,
        "staticCollisionRects": [
            {"id": "left_stone_cheek", "sizePx": [18, 24], "centerPx": [-20, -12]},
            {"id": "right_stone_cheek", "sizePx": [18, 24], "centerPx": [20, -12]},
        ],
        "statePassageSemantics": {
            "STAIRS_CLOSED": "center route has an independent blocking collision",
            "STAIRS_OPEN": "center route blocking collision is disabled; static cheek collisions remain",
        },
        "stateInvariants": [
            "same outer stone alpha silhouette",
            "same static stone cheek geometry and collision",
            "same stair-run geometry, source canvas and bottom-center anchor",
            "state changes remain on the cross-stone and center passage cues",
        ],
        "productBoundary": {
            "objectId": "m1_shortcut_stairs",
            "candidateDocumentCell": list(CANDIDATE_DOCUMENT_CELL),
            "formalMapCoordinateFrozen": False,
            "pairedEliteId": "m1_e01",
            "pairedEliteCandidateDocumentCell": [36, 29],
            "sameViewFeedbackRequired": True,
            "stateOwner": "external Map01 runtime/save adapter",
        },
    }
    SPEC_PATH.write_text(json.dumps(spec, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    for source_path in (OVERVIEW_SOURCE, RIDGE_SOURCE, LAMP_CLOSED_SOURCE, LAMP_OPEN_SOURCE):
        if not source_path.is_file():
            raise SystemExit(f"Missing Map01 stair generation input: {source_path}")
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    REFERENCE_DIR.mkdir(parents=True, exist_ok=True)
    _build_context_reference()
    _build_style_reference()
    _build_requirement()
    _write_spec()
    print("Map01 east-wall stair generation input OK; two-state plan-view contract preserved")
    print(f"Context reference: {CONTEXT_PATH}")
    print(f"Style reference: {STYLE_PATH}")
    print(f"Requirement: {REQUIREMENT_PATH}")
    print(f"Spec: {SPEC_PATH}")


if __name__ == "__main__":
    main()
