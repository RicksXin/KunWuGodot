#!/usr/bin/env python3
"""Compile the approved Map01 derelict-camp master into layered runtime art.

The first generated camp is the sole geometry source. Corpse evidence is kept in
an independent overlay so state changes never move tents or alter collision.
The ledger remains a separate map object and is intentionally absent here.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_landmarks" / "map01_camp_three_piece_master_20260820.png"
OUTPUT_DIR = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "derelict_camp"
QA_DIR = ROOT / "art" / "candidates" / "map01_camp" / "compiled"
FONT_PATH = ROOT / "assets" / "fonts" / "ark-pixel-12px-proportional-zh_cn.ttf"

APPROVED_SOURCE_SHA256 = "3f79b9111c2a8706e8fac707dd9b2e2dd978d0ff9b5140162a3196e397ba3b01"
EXPECTED_SOURCE_SIZE = (1254, 1254)
CANVAS_SIZE = (96, 56)
ANCHOR_PX = (48, 52)
BASE_SUBJECT_SIZE = (64, 43)
BASE_POSITION = (16, 9)
ALPHA_THRESHOLD = 128
PALETTE_SIZE = 24

BASE_SOURCE_BBOX = (367, 73, 832, 385)
DEFAULT_CORPSE_SPECS = (
    ((809, 578, 924, 648), (14, 9), (80, 29)),
    ((859, 666, 970, 731), (14, 8), (81, 41)),
)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _luma(rgb: tuple[int, int, int]) -> float:
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722


def _hard_alpha(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    result.putdata([
        (red, green, blue, 255) if alpha >= ALPHA_THRESHOLD else (0, 0, 0, 0)
        for red, green, blue, alpha in result.get_flattened_data()
    ])
    return result


def _crop_subject(master: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    crop = _hard_alpha(master.crop(bbox))
    alpha_box = crop.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError(f"Source crop is empty: {bbox}")
    return crop.crop(alpha_box)


def _resize_subject(subject: Image.Image, size: tuple[int, int]) -> Image.Image:
    return _hard_alpha(subject.resize(size, Image.Resampling.NEAREST))


def _build_palette(images: Iterable[Image.Image]) -> list[tuple[int, int, int]]:
    samples = [
        (red, green, blue)
        for image in images
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha
    ]
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    quantized = strip.quantize(
        colors=PALETTE_SIZE,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    raw_palette = quantized.getpalette()
    indexes = sorted(set(quantized.get_flattened_data()))
    return sorted((tuple(raw_palette[index * 3:index * 3 + 3]) for index in indexes), key=_luma)


def _map_to_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    output: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in image.get_flattened_data():
        if not alpha:
            output.append((0, 0, 0, 0))
            continue
        source = (red, green, blue)
        nearest = min(
            palette,
            key=lambda color: (
                (source[0] - color[0]) ** 2 * 2
                + (source[1] - color[1]) ** 2 * 4
                + (source[2] - color[2]) ** 2 * 3
            ),
        )
        output.append((*nearest, 255))
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.putdata(output)
    return result


def _make_processed_overlay() -> Image.Image:
    """Leave two tied cloth remnants, never the generated red droplets."""
    image = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    shadow = (39, 46, 47, 255)
    cloth_dark = (67, 71, 68, 255)
    cloth_mid = (96, 97, 90, 255)
    tie = (72, 57, 45, 255)

    for x, y in ((82, 32), (83, 31), (84, 31), (85, 31), (86, 32), (87, 32), (88, 33)):
        image.putpixel((x, y), shadow)
    for x, y in ((82, 31), (83, 30), (84, 30), (85, 30), (86, 31), (87, 31)):
        image.putpixel((x, y), cloth_dark)
    for x, y in ((83, 30), (84, 30), (85, 30), (86, 31)):
        image.putpixel((x, y), cloth_mid)
    image.putpixel((85, 30), tie)
    image.putpixel((85, 31), tie)

    for x, y in ((84, 44), (85, 43), (86, 43), (87, 43), (88, 44), (89, 44), (90, 44), (91, 45), (92, 45)):
        image.putpixel((x, y), shadow)
    for x, y in ((84, 43), (85, 42), (86, 42), (87, 42), (88, 43), (89, 43), (90, 43), (91, 44)):
        image.putpixel((x, y), cloth_dark)
    for x, y in ((85, 42), (86, 42), (87, 42), (88, 43), (89, 43), (90, 43)):
        image.putpixel((x, y), cloth_mid)
    image.putpixel((88, 42), tie)
    image.putpixel((88, 43), tie)
    return image


def _write_contact_sheet(base: Image.Image, overlays: dict[str, Image.Image]) -> None:
    scale = 3
    card_width = 375
    card_height = 260
    sheet = Image.new("RGB", (card_width, card_height * 2), "#0e1217")
    draw = ImageDraw.Draw(sheet)
    title_font = ImageFont.truetype(FONT_PATH, size=16)
    detail_font = ImageFont.truetype(FONT_PATH, size=12)
    rows = (
        ("CAMP_CORPSES_DEFAULT", "尸首证据 · 未处理"),
        ("CAMP_CORPSES_PROCESSED", "尸首证据 · 已处理"),
    )
    for index, (state_id, label) in enumerate(rows):
        top = index * card_height
        draw.rounded_rectangle((8, top + 8, 367, top + 252), radius=8, fill="#1b2026", outline="#4a535c", width=2)
        draw.text((18, top + 18), f"{label} · {state_id}", fill="#eee8da", font=title_font)
        composite = Image.alpha_composite(base, overlays[state_id]).resize(
            (CANVAS_SIZE[0] * scale, CANVAS_SIZE[1] * scale),
            Image.Resampling.NEAREST,
        )
        sheet.paste(composite, (43, top + 52), composite)
        anchor_x = 43 + ANCHOR_PX[0] * scale
        anchor_y = top + 52 + ANCHOR_PX[1] * scale
        draw.line((anchor_x - 7, anchor_y, anchor_x + 7, anchor_y), fill="#78a6b8", width=1)
        draw.line((anchor_x, anchor_y - 7, anchor_x, anchor_y + 7), fill="#78a6b8", width=1)
        draw.text((18, top + 232), "96×56 · 锚点[48,52] · 显示3× · 粮册独立", fill="#b0b6be", font=detail_font)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "map01_derelict_camp_two_state_contact_sheet.png", optimize=True)


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing approved camp master: {SOURCE}")
    source_sha256 = _sha256(SOURCE)
    if source_sha256 != APPROVED_SOURCE_SHA256:
        raise SystemExit(f"Camp source SHA-256 changed: {source_sha256}")
    master = Image.open(SOURCE).convert("RGBA")
    if master.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Unexpected camp source size: {master.size}")

    base_subject = _resize_subject(_crop_subject(master, BASE_SOURCE_BBOX), BASE_SUBJECT_SIZE)
    corpse_subjects = [
        _resize_subject(_crop_subject(master, bbox), size)
        for bbox, size, _position in DEFAULT_CORPSE_SPECS
    ]
    palette = _build_palette((base_subject, *corpse_subjects))
    base_subject = _map_to_palette(base_subject, palette)
    corpse_subjects = [_map_to_palette(subject, palette) for subject in corpse_subjects]

    base = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    base.alpha_composite(base_subject, BASE_POSITION)
    default_overlay = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    for subject, (_bbox, _size, position) in zip(corpse_subjects, DEFAULT_CORPSE_SPECS, strict=True):
        default_overlay.alpha_composite(subject, position)
    processed_overlay = _make_processed_overlay()
    overlays = {
        "CAMP_CORPSES_DEFAULT": default_overlay,
        "CAMP_CORPSES_PROCESSED": processed_overlay,
    }

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    base.save(OUTPUT_DIR / "camp_stay_base.png", optimize=True)
    default_overlay.save(OUTPUT_DIR / "camp_corpses_default_overlay.png", optimize=True)
    processed_overlay.save(OUTPUT_DIR / "camp_corpses_processed_overlay.png", optimize=True)

    manifest = {
        "version": 1,
        "approved_date": "2026-08-20",
        "source_master": "res://art/source_archive/map01_landmarks/map01_camp_three_piece_master_20260820.png",
        "source_sha256": source_sha256,
        "source_size_px": list(master.size),
        "generation_request": {
            "canvas_px": [72, 56],
            "visual_footprint_cells": [4, 3],
        },
        "accepted_runtime_deviation": {
            "canvas_px": list(CANVAS_SIZE),
            "visual_footprint_cells": [5, 3],
            "reason": "The approved master places corpse evidence beside the shared camp base; a wider canvas preserves legibility without overlapping the tents.",
        },
        "canvas_px": list(CANVAS_SIZE),
        "base_subject_px": list(BASE_SUBJECT_SIZE),
        "base_bbox_px": [16, 9, 80, 52],
        "anchor_px": list(ANCHOR_PX),
        "visual_footprint_cells": [5, 3],
        "runtime_display_scale": 3,
        "map_scene_root_scale": 0.1875,
        "map_scene_instance_scale": 16,
        "formal_map_coordinate_frozen": False,
        "component_scene": "res://scenes/maps/components/map01_derelict_camp.tscn",
        "base_contract": "CAMP_STAY_BASE is the sole geometry and collision source for both corpse states.",
        "state_source_contract": "External corpse-event state selects one overlay; presentation never writes save data.",
        "ledger_contract": "m1_event_ledger remains an independent distant map object and has no camp sprite state API.",
        "processed_cleanup": "Generated red droplets were rejected; the processed overlay contains only two dark folded binding-cloth remnants.",
        "collision_shapes": [
            {"id": "left_tent", "size_source_px": [20, 14], "center_source_px": [-15, -21]},
            {"id": "right_tent", "size_source_px": [22, 16], "center_source_px": [14, -14]},
        ],
        "palette": ["#%02x%02x%02x" % color for color in palette],
        "layers": {
            "CAMP_STAY_BASE": {
                "path": "res://assets/maps/map_01/landmarks/derelict_camp/camp_stay_base.png",
                "source_bbox": list(BASE_SOURCE_BBOX),
            },
            "CAMP_CORPSES_DEFAULT": {
                "path": "res://assets/maps/map_01/landmarks/derelict_camp/camp_corpses_default_overlay.png",
                "source_bboxes": [list(spec[0]) for spec in DEFAULT_CORPSE_SPECS],
            },
            "CAMP_CORPSES_PROCESSED": {
                "path": "res://assets/maps/map_01/landmarks/derelict_camp/camp_corpses_processed_overlay.png",
                "source_bboxes": [],
            },
        },
    }
    (OUTPUT_DIR / "map01_derelict_camp_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_contact_sheet(base, overlays)
    print("Map01 derelict-camp extraction OK; shared base plus two corpse-evidence overlays")
    print(f"Source SHA-256: {source_sha256}")
    print(f"Manifest: {OUTPUT_DIR / 'map01_derelict_camp_manifest.json'}")
    print(f"QA: {QA_DIR / 'map01_derelict_camp_two_state_contact_sheet.png'}")


if __name__ == "__main__":
    main()
