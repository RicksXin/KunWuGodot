#!/usr/bin/env python3
"""Compile the approved Map01 three-state array-lamp master.

The source image is an approved visual master only. This compiler normalizes all
three states to the same 40x40 source canvas and bottom-centre anchor; runtime
state and collision semantics remain explicit in the manifest/component.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_landmarks" / "map01_lamp_three_state_master_20260820.png"
OUTPUT_DIR = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "array_lamp"
QA_DIR = ROOT / "art" / "candidates" / "map01_lamps" / "compiled"

APPROVED_SOURCE_SHA256 = "73e3ee65d37bfac053b0e0c915ae01af91c68ebcbf356ff47816d74f14b984ee"
EXPECTED_SOURCE_SIZE = (1254, 1254)
CANVAS_SIZE = (40, 40)
SUBJECT_MAX_SIZE = (32, 32)
ANCHOR_PX = (20, 36)
ALPHA_THRESHOLD = 128
PALETTE_SIZE = 20


@dataclass(frozen=True)
class LampStateSpec:
    state_id: str
    asset_id: str
    label: str
    bbox: tuple[int, int, int, int]


STATE_SPECS = (
    LampStateSpec("LAMP_BROKEN", "array_lamp_broken", "破损", (500, 102, 754, 383)),
    LampStateSpec("LAMP_REVERSED", "array_lamp_reversed", "逆转", (500, 487, 754, 767)),
    LampStateSpec("LAMP_REPAIRED", "array_lamp_repaired", "修复", (500, 854, 754, 1134)),
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


def _dim_broken_red(image: Image.Image) -> Image.Image:
    """Keep the broken rune visibly inert without changing its silhouette."""
    result = image.copy()
    pixels = []
    for red, green, blue, alpha in result.get_flattened_data():
        if not alpha or not (red > green * 1.22 and red > blue * 1.18 and red >= 92):
            pixels.append((red, green, blue, alpha))
            continue
        current = max(1.0, _luma((red, green, blue)))
        target = min(current * 0.62, 66.0)
        factor = target / current
        pixels.append((round(red * factor), round(green * factor), round(blue * factor), 255))
    result.putdata(pixels)
    return result


def _prepare_state(master: Image.Image, spec: LampStateSpec) -> tuple[Image.Image, tuple[int, int]]:
    crop = _hard_alpha(master.crop(spec.bbox))
    alpha_box = crop.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError(f"State crop is empty: {spec.state_id}")
    subject = crop.crop(alpha_box)
    scale = min(SUBJECT_MAX_SIZE[0] / subject.width, SUBJECT_MAX_SIZE[1] / subject.height)
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = subject.resize(target_size, Image.Resampling.NEAREST)
    subject = _hard_alpha(subject)
    if spec.state_id == "LAMP_BROKEN":
        subject = _dim_broken_red(subject)
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
    quantized = strip.quantize(
        colors=PALETTE_SIZE,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    raw_palette = quantized.getpalette()
    used_indexes = sorted(set(quantized.get_flattened_data()))
    colors = [tuple(raw_palette[index * 3:index * 3 + 3]) for index in used_indexes]
    return sorted(colors, key=_luma)


def _map_to_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    output = []
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


def _write_contact_sheet(images: dict[str, Image.Image]) -> None:
    scale = 6
    card_width = 260
    card_height = 330
    sheet = Image.new("RGB", (card_width * len(STATE_SPECS), card_height), "#0e1217")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=17)
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
        draw.text((left + 18, 18), f"{spec.label} · {spec.state_id}", fill="#eee8da", font=font)
        sprite = images[spec.asset_id].resize(
            (CANVAS_SIZE[0] * scale, CANVAS_SIZE[1] * scale),
            Image.Resampling.NEAREST,
        )
        sheet.paste(sprite, (left + 10, 56), sprite)
        anchor_x = left + 10 + ANCHOR_PX[0] * scale
        anchor_y = 56 + ANCHOR_PX[1] * scale
        draw.line((anchor_x - 7, anchor_y, anchor_x + 7, anchor_y), fill="#78a6b8", width=1)
        draw.line((anchor_x, anchor_y - 7, anchor_x, anchor_y + 7), fill="#78a6b8", width=1)
        draw.text((left + 18, 300), "40×40 · 锚点[20,36] · 显示3×", fill="#b0b6be", font=detail_font)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "map01_array_lamp_three_state_contact_sheet.png")


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing approved array-lamp master: {SOURCE}")
    source_sha256 = _sha256(SOURCE)
    if source_sha256 != APPROVED_SOURCE_SHA256:
        raise SystemExit(f"Array-lamp source SHA-256 changed: {source_sha256}")
    master = Image.open(SOURCE).convert("RGBA")
    if master.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Unexpected array-lamp source size: {master.size}")

    prepared: dict[str, Image.Image] = {}
    subject_sizes: dict[str, tuple[int, int]] = {}
    for spec in STATE_SPECS:
        prepared[spec.asset_id], subject_sizes[spec.asset_id] = _prepare_state(master, spec)
    palette = _build_palette(prepared.values())
    images = {asset_id: _map_to_palette(image, palette) for asset_id, image in prepared.items()}

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for spec in STATE_SPECS:
        images[spec.asset_id].save(OUTPUT_DIR / f"{spec.asset_id}.png", optimize=True)

    manifest = {
        "version": 1,
        "approved_date": "2026-08-20",
        "source_master": "res://art/source_archive/map01_landmarks/map01_lamp_three_state_master_20260820.png",
        "source_sha256": source_sha256,
        "source_size_px": list(master.size),
        "canvas_px": list(CANVAS_SIZE),
        "subject_max_px": list(SUBJECT_MAX_SIZE),
        "anchor_px": list(ANCHOR_PX),
        "visual_footprint_cells": [2, 2],
        "collision_size_source_px": [24, 18],
        "collision_center_source_px": [0, -9],
        "runtime_display_scale": 3,
        "map_scene_root_scale": 0.1875,
        "map_scene_instance_scale": 16,
        "component_scene": "res://scenes/maps/components/map01_array_lamp.tscn",
        "state_source_contract": "external product state; never inferred from artwork or collision",
        "collision_contract": "all three states share the same independent collision shape",
        "broken_treatment": "red rune highlights are intentionally darkened so the broken state does not read as active",
        "palette": ["#%02x%02x%02x" % color for color in palette],
        "states": {
            spec.state_id: {
                "asset_id": spec.asset_id,
                "path": f"res://assets/maps/map_01/landmarks/array_lamp/{spec.asset_id}.png",
                "source_bbox": list(spec.bbox),
                "normalized_subject_px": list(subject_sizes[spec.asset_id]),
            }
            for spec in STATE_SPECS
        },
    }
    (OUTPUT_DIR / "map01_array_lamp_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_contact_sheet(images)
    print("Map01 array-lamp extraction OK; 3 states, shared 40x40 canvas and 24x18 collision contract")
    print(f"Source SHA-256: {source_sha256}")
    print(f"Manifest: {OUTPUT_DIR / 'map01_array_lamp_manifest.json'}")
    print(f"QA: {QA_DIR / 'map01_array_lamp_three_state_contact_sheet.png'}")


if __name__ == "__main__":
    main()
