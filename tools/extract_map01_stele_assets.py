#!/usr/bin/env python3
"""Compile the approved Map01 Wanxiu stele master into three runtime sprites.

The generated master supplies the approved stone silhouette and material.  Its
cross-like plaque marks and cyan screen are deliberately not runtime art: this
compiler replaces only the shared inset face with deterministic, non-textual
pixel marks while preserving one exact silhouette, anchor and collision contract.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_landmarks" / "map01_stele_three_state_master_20260820.png"
OUTPUT_DIR = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "wanxiu_stele"
QA_DIR = ROOT / "art" / "candidates" / "map01_stele" / "compiled"

APPROVED_SOURCE_SHA256 = "ac444400eccc60e00ed07ccf3de741c9b76bb71e4e4062870feceb4dfb23c7c3"
EXPECTED_SOURCE_SIZE = (1254, 1254)
CANVAS_SIZE = (56, 56)
SUBJECT_MAX_SIZE = (48, 48)
ANCHOR_PX = (28, 52)
ALPHA_THRESHOLD = 128
PALETTE_SIZE = 18

STONE_FACE_BASE = (61, 77, 80)
STONE_FACE_DARK = (49, 63, 68)
STONE_FACE_LIGHT = (70, 86, 88)
GROOVE = (27, 42, 49)
GROOVE_SOFT = (39, 55, 61)
OLD_GOLD = (151, 126, 82)
ACTIVE_GOLD = (197, 163, 91)
WARM_IVORY = (238, 224, 181)
RESERVED_CYAN = (155, 179, 189)
RESERVED_HIGHLIGHT = (203, 225, 226)


@dataclass(frozen=True)
class SteleStateSpec:
    state_id: str
    asset_id: str
    label: str
    source_bbox: tuple[int, int, int, int]


STATE_SPECS = (
    SteleStateSpec("STELE_DEFAULT", "wanxiu_stele_default", "默认", (468, 67, 760, 387)),
    SteleStateSpec("STELE_INTERACTED", "wanxiu_stele_interacted", "已交互", (468, 474, 760, 792)),
    SteleStateSpec("STELE_C07_RESERVED", "wanxiu_stele_c07_reserved", "C07预留", (468, 879, 760, 1195)),
)


def _luma(rgb: tuple[int, int, int]) -> float:
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _hard_alpha(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    result.putdata([
        (red, green, blue, 255) if alpha >= ALPHA_THRESHOLD else (0, 0, 0, 0)
        for red, green, blue, alpha in result.get_flattened_data()
    ])
    return result


def _prepare_shared_base(master: Image.Image) -> tuple[Image.Image, tuple[int, int]]:
    source_crop = _hard_alpha(master.crop(STATE_SPECS[0].source_bbox))
    alpha_box = source_crop.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError("STELE_DEFAULT source crop is empty")
    subject = source_crop.crop(alpha_box)
    scale = min(SUBJECT_MAX_SIZE[0] / subject.width, SUBJECT_MAX_SIZE[1] / subject.height)
    target_size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = _hard_alpha(subject.resize(target_size, Image.Resampling.NEAREST))
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    left = ANCHOR_PX[0] - target_size[0] // 2
    top = ANCHOR_PX[1] - target_size[1]
    canvas.alpha_composite(subject, (left, top))
    return canvas, target_size


def _build_palette(images: Iterable[Image.Image]) -> list[tuple[int, int, int]]:
    samples: list[tuple[int, int, int]] = []
    for image in images:
        samples.extend((red, green, blue) for red, green, blue, alpha in image.get_flattened_data() if alpha)
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    quantized = strip.quantize(colors=PALETTE_SIZE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
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


def _put_opaque(image: Image.Image, position: tuple[int, int], color: tuple[int, int, int]) -> None:
    if image.getpixel(position)[3]:
        image.putpixel(position, (*color, 255))


def _replace_inset_face(image: Image.Image) -> None:
    """Remove the generated cross/screen without touching the shared silhouette."""
    for y in range(14, 30):
        for x in range(24, 37):
            _put_opaque(image, (x, y), STONE_FACE_BASE)
    for x, y in (
        (24, 14), (25, 14), (35, 15), (36, 15),
        (24, 21), (36, 22), (25, 28), (35, 28),
    ):
        _put_opaque(image, (x, y), STONE_FACE_DARK)
    for x, y in ((26, 16), (34, 18), (25, 25), (35, 26)):
        _put_opaque(image, (x, y), STONE_FACE_LIGHT)


def _paint_default(image: Image.Image) -> None:
    # Two interrupted, uneven grooves suggest a sealed door without forming a cross or readable glyph.
    for point in (
        (29, 17), (29, 18), (29, 20), (29, 21), (29, 24), (29, 26), (29, 27),
        (32, 18), (32, 19), (32, 22), (32, 23), (32, 25),
    ):
        _put_opaque(image, point, GROOVE)


def _paint_interacted(image: Image.Image) -> None:
    # Thirteen disconnected response notches: contained, non-textual and never a continuous rune.
    marks = (
        ((28, 17), ACTIVE_GOLD), ((29, 17), WARM_IVORY),
        ((32, 18), OLD_GOLD), ((33, 18), ACTIVE_GOLD),
        ((29, 20), ACTIVE_GOLD), ((30, 20), OLD_GOLD),
        ((33, 21), WARM_IVORY),
        ((28, 23), OLD_GOLD), ((29, 23), ACTIVE_GOLD),
        ((32, 24), ACTIVE_GOLD), ((33, 24), OLD_GOLD),
        ((30, 27), ACTIVE_GOLD), ((31, 27), WARM_IVORY),
    )
    for point, color in marks:
        _put_opaque(image, point, color)


def _paint_reserved(image: Image.Image) -> None:
    # An open, broken replacement seam avoids reading as a screen or active portal.
    for point in (
        (27, 17), (28, 17), (29, 17), (32, 17), (33, 17),
        (27, 19), (27, 20), (27, 23), (27, 24),
        (34, 20), (34, 21), (34, 24), (34, 25),
        (28, 27), (29, 27), (32, 27), (33, 27), (34, 27),
    ):
        _put_opaque(image, point, GROOVE_SOFT)
    for point, color in (
        ((32, 22), RESERVED_HIGHLIGHT),
        ((31, 23), RESERVED_CYAN),
        ((31, 24), RESERVED_CYAN),
    ):
        _put_opaque(image, point, color)


def _write_contact_sheet(images: dict[str, Image.Image]) -> None:
    scale = 5
    card_width = 320
    card_height = 370
    sheet = Image.new("RGB", (card_width * len(STATE_SPECS), card_height), "#0e1217")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=16)
    detail_font = ImageFont.load_default(size=13)
    for index, spec in enumerate(STATE_SPECS):
        left = index * card_width
        draw.rounded_rectangle(
            (left + 8, 8, left + card_width - 8, card_height - 8),
            radius=8,
            fill="#1b2026",
            outline="#4a535c",
            width=2,
        )
        draw.text((left + 18, 18), f"{index + 1}. {spec.state_id}", fill="#eee8da", font=font)
        sprite = images[spec.asset_id].resize(
            (CANVAS_SIZE[0] * scale, CANVAS_SIZE[1] * scale),
            Image.Resampling.NEAREST,
        )
        sheet.paste(sprite, (left + 20, 53), sprite)
        anchor_x = left + 20 + ANCHOR_PX[0] * scale
        anchor_y = 53 + ANCHOR_PX[1] * scale
        draw.line((anchor_x - 7, anchor_y, anchor_x + 7, anchor_y), fill="#78a6b8", width=1)
        draw.line((anchor_x, anchor_y - 7, anchor_x, anchor_y + 7), fill="#78a6b8", width=1)
        draw.text((left + 18, 340), "56x56 | anchor [28,52] | runtime 3x", fill="#b0b6be", font=detail_font)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "map01_wanxiu_stele_three_state_contact_sheet.png")


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing approved Wanxiu stele master: {SOURCE}")
    source_sha256 = _sha256(SOURCE)
    if source_sha256 != APPROVED_SOURCE_SHA256:
        raise SystemExit(f"Wanxiu stele source SHA-256 changed: {source_sha256}")
    master = Image.open(SOURCE).convert("RGBA")
    if master.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Unexpected Wanxiu stele source size: {master.size}")

    shared_base, subject_size = _prepare_shared_base(master)
    source_palette = _build_palette((shared_base,))
    shared_base = _map_to_palette(shared_base, source_palette)
    _replace_inset_face(shared_base)

    images: dict[str, Image.Image] = {}
    for spec in STATE_SPECS:
        image = shared_base.copy()
        if spec.state_id == "STELE_DEFAULT":
            _paint_default(image)
        elif spec.state_id == "STELE_INTERACTED":
            _paint_interacted(image)
        else:
            _paint_reserved(image)
        images[spec.asset_id] = image

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for spec in STATE_SPECS:
        images[spec.asset_id].save(OUTPUT_DIR / f"{spec.asset_id}.png", optimize=True)

    all_colors = sorted({
        (red, green, blue)
        for image in images.values()
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha
    }, key=_luma)
    manifest = {
        "version": 1,
        "approved_date": "2026-08-20",
        "source_master": "res://art/source_archive/map01_landmarks/map01_stele_three_state_master_20260820.png",
        "source_sha256": source_sha256,
        "source_size_px": list(master.size),
        "canvas_px": list(CANVAS_SIZE),
        "subject_max_px": list(SUBJECT_MAX_SIZE),
        "normalized_subject_px": list(subject_size),
        "anchor_px": list(ANCHOR_PX),
        "visual_footprint_cells": [3, 3],
        "collision_size_source_px": [32, 20],
        "collision_center_source_px": [0, -10],
        "runtime_display_scale": 3,
        "map_scene_root_scale": 0.1875,
        "map_scene_instance_scale": 16,
        "component_scene": "res://scenes/maps/components/map01_wanxiu_stele.tscn",
        "formal_map_coordinate_frozen": False,
        "state_source_contract": "external product state; never inferred from artwork or collision",
        "collision_contract": "all three states share the same independent 32x20 collision shape",
        "silhouette_contract": "all runtime states use the exact STELE_DEFAULT outer silhouette and base geometry",
        "cleanup_treatment": "generated cross, readable-glyph risk and cyan screen were removed; only deterministic disconnected marks remain",
        "c07_boundary": "reserved replacement face only; no future writing, portal, character or time-river content",
        "palette": ["#%02x%02x%02x" % color for color in all_colors],
        "states": {
            spec.state_id: {
                "asset_id": spec.asset_id,
                "path": f"res://assets/maps/map_01/landmarks/wanxiu_stele/{spec.asset_id}.png",
                "source_reference_bbox": list(spec.source_bbox),
                "runtime_geometry_source": "STELE_DEFAULT",
            }
            for spec in STATE_SPECS
        },
    }
    (OUTPUT_DIR / "map01_wanxiu_stele_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_contact_sheet(images)
    print("Map01 Wanxiu stele extraction OK; 3 states, shared 56x56 canvas and exact silhouette")
    print(f"Source SHA-256: {source_sha256}")
    print(f"Manifest: {OUTPUT_DIR / 'map01_wanxiu_stele_manifest.json'}")
    print(f"QA: {QA_DIR / 'map01_wanxiu_stele_three_state_contact_sheet.png'}")


if __name__ == "__main__":
    main()
