#!/usr/bin/env python3
"""Extract approved Map01 C1/C2 concept sheets into hard-edged source sprites.

The accepted GPT sheets are 8x working masters. This tool downsamples them with
nearest-neighbour sampling, normalizes C2 matched-pair canvases and anchors, and
keeps collision semantics out of the generated PNGs.
"""

from __future__ import annotations

import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = ROOT / "art" / "source_archive" / "map01_blockers"
OUTPUT_DIR = ROOT / "assets" / "maps" / "map_01" / "blockers"
QA_DIR = ROOT / "art" / "candidates" / "map01_blockers" / "compiled"

C1_SOURCE = SOURCE_DIR / "map01_c1_ridges_blockers_master_20260820.png"
C2_SOURCE = SOURCE_DIR / "map01_c2_foreground_pairs_master_20260820.png"

DOWNSAMPLE = 8
SOURCE_PAD = 16
ALPHA_THRESHOLD = 128
PALETTE_SIZE = 12
MIN_LUMA = 36.0
MAX_LUMA = 132.0


@dataclass(frozen=True)
class AssetSpec:
    asset_id: str
    source: str
    bbox: tuple[int, int, int, int]
    footprint_hint: str
    fadeable: bool = False
    pair_id: str = ""


C1_SPECS = (
    AssetSpec("ridge_nw_se_static", "c1", (34, 15, 500, 452), "stepped diagonal family"),
    AssetSpec("ridge_ne_sw_static", "c1", (553, 22, 990, 448), "stepped diagonal family"),
    AssetSpec("blocker_1x1_a", "c1", (53, 466, 197, 620), "1x1"),
    AssetSpec("blocker_1x1_b", "c1", (328, 471, 475, 620), "1x1"),
    AssetSpec("blocker_1x2", "c1", (603, 471, 854, 615), "1x2"),
    AssetSpec("blocker_2x2", "c1", (33, 701, 266, 940), "2x2"),
    AssetSpec("blocker_2x3", "c1", (337, 656, 541, 993), "2x3"),
    AssetSpec("blocker_irregular", "c1", (592, 640, 999, 1009), "irregular large"),
)

C2_SPECS = (
    AssetSpec("ridge_nw_se_base", "c2", (86, 15, 452, 295), "graybox-authored", pair_id="ridge_nw_se"),
    AssetSpec("ridge_nw_se_foreground", "c2", (559, 9, 949, 287), "graybox-authored", True, "ridge_nw_se"),
    AssetSpec("ridge_ne_sw_base", "c2", (83, 316, 445, 577), "graybox-authored", pair_id="ridge_ne_sw"),
    AssetSpec("ridge_ne_sw_foreground", "c2", (561, 299, 939, 572), "graybox-authored", True, "ridge_ne_sw"),
    AssetSpec("tunnel_stay_base", "c2", (52, 592, 465, 779), "two-island base group", pair_id="tunnel"),
    AssetSpec("tunnel_roof_foreground", "c2", (548, 591, 972, 767), "matching roof group", True, "tunnel"),
    AssetSpec("gate_stay_base", "c2", (42, 803, 478, 993), "two-island base group", pair_id="gate"),
    AssetSpec("gate_top_foreground", "c2", (542, 802, 979, 949), "matching top group", True, "gate"),
)


def _luma(rgb: tuple[int, int, int]) -> float:
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722


def _clamp_luma(rgb: tuple[int, int, int]) -> tuple[int, int, int]:
    current = _luma(rgb)
    target = min(MAX_LUMA, max(MIN_LUMA, current))
    delta = target - current
    return tuple(max(0, min(255, round(channel + delta))) for channel in rgb)


def _aligned_crop(image: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    x0, y0, x1, y1 = bbox
    x0 = max(0, math.floor((x0 - SOURCE_PAD) / DOWNSAMPLE) * DOWNSAMPLE)
    y0 = max(0, math.floor((y0 - SOURCE_PAD) / DOWNSAMPLE) * DOWNSAMPLE)
    x1 = min(image.width, math.ceil((x1 + SOURCE_PAD) / DOWNSAMPLE) * DOWNSAMPLE)
    y1 = min(image.height, math.ceil((y1 + SOURCE_PAD) / DOWNSAMPLE) * DOWNSAMPLE)
    return image.crop((x0, y0, x1, y1))


def _reduce_asset(sheet: Image.Image, spec: AssetSpec) -> Image.Image:
    crop = _aligned_crop(sheet, spec.bbox)
    reduced = crop.resize(
        (crop.width // DOWNSAMPLE, crop.height // DOWNSAMPLE),
        Image.Resampling.NEAREST,
    ).convert("RGBA")
    pixels = []
    for red, green, blue, alpha in reduced.get_flattened_data():
        if alpha < ALPHA_THRESHOLD:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((*_clamp_luma((red, green, blue)), 255))
    reduced.putdata(pixels)
    _remove_tiny_alpha_components(reduced)
    return reduced


def _remove_tiny_alpha_components(image: Image.Image, minimum_area: int = 4) -> None:
    width, height = image.size
    pixels = image.load()
    seen: set[tuple[int, int]] = set()
    for start_y in range(height):
        for start_x in range(width):
            start = (start_x, start_y)
            if start in seen or pixels[start_x, start_y][3] == 0:
                continue
            component = [start]
            seen.add(start)
            for x, y in component:
                for next_x, next_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
                    point = (next_x, next_y)
                    if not (0 <= next_x < width and 0 <= next_y < height):
                        continue
                    if point in seen or pixels[next_x, next_y][3] == 0:
                        continue
                    seen.add(point)
                    component.append(point)
            if len(component) < minimum_area:
                for x, y in component:
                    pixels[x, y] = (0, 0, 0, 0)


def _normalize_pair(images: dict[str, Image.Image], specs: Iterable[AssetSpec]) -> None:
    pair_specs = tuple(specs)
    width = max(images[spec.asset_id].width for spec in pair_specs)
    height = max(images[spec.asset_id].height for spec in pair_specs)
    for spec in pair_specs:
        source = images[spec.asset_id]
        canvas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
        x = (width - source.width) // 2
        y = height - source.height
        canvas.alpha_composite(source, (x, y))
        images[spec.asset_id] = canvas


def _build_reference_palette(images: Iterable[Image.Image]) -> list[tuple[int, int, int]]:
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
    mapped = Image.new("RGBA", image.size, (0, 0, 0, 0))
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
    mapped.putdata(output)
    return mapped


def _write_contact_sheet(images: dict[str, Image.Image], ordered_specs: tuple[AssetSpec, ...]) -> None:
    scale = 3
    card_width = 320
    card_height = 176
    columns = 3
    rows = math.ceil(len(ordered_specs) / columns)
    sheet = Image.new("RGB", (card_width * columns, card_height * rows), "#14171b")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=14)
    for index, spec in enumerate(ordered_specs):
        column = index % columns
        row = index // columns
        left = column * card_width
        top = row * card_height
        draw.rounded_rectangle(
            (left + 8, top + 8, left + card_width - 8, top + card_height - 8),
            radius=8,
            fill="#1b2026",
            outline="#4a535c",
            width=2,
        )
        draw.text((left + 18, top + 18), spec.asset_id, fill="#eee8da", font=font)
        sprite = images[spec.asset_id].resize(
            (images[spec.asset_id].width * scale, images[spec.asset_id].height * scale),
            Image.Resampling.NEAREST,
        )
        max_width = card_width - 36
        max_height = card_height - 58
        if sprite.width > max_width or sprite.height > max_height:
            fit = min(max_width / sprite.width, max_height / sprite.height)
            fit = max(1, math.floor(fit)) if fit >= 1 else fit
            sprite = sprite.resize(
                (max(1, round(sprite.width * fit)), max(1, round(sprite.height * fit))),
                Image.Resampling.NEAREST,
            )
        x = left + (card_width - sprite.width) // 2
        y = top + 48 + (max_height - sprite.height) // 2
        sheet.paste(sprite, (x, y), sprite)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "map01_blockers_foreground_contact_sheet.png")


def main() -> None:
    for path in (C1_SOURCE, C2_SOURCE):
        if not path.is_file():
            raise SystemExit(f"Missing approved source: {path}")

    sheets = {
        "c1": Image.open(C1_SOURCE).convert("RGBA"),
        "c2": Image.open(C2_SOURCE).convert("RGBA"),
    }
    specs = C1_SPECS + C2_SPECS
    images = {spec.asset_id: _reduce_asset(sheets[spec.source], spec) for spec in specs}

    for pair_id in ("ridge_nw_se", "ridge_ne_sw", "tunnel", "gate"):
        _normalize_pair(images, (spec for spec in C2_SPECS if spec.pair_id == pair_id))

    palette = _build_reference_palette(images[spec.asset_id] for spec in C1_SPECS)
    images = {asset_id: _map_to_palette(image, palette) for asset_id, image in images.items()}

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for spec in specs:
        images[spec.asset_id].save(OUTPUT_DIR / f"{spec.asset_id}.png", optimize=True)

    manifest_assets = []
    for spec in specs:
        image = images[spec.asset_id]
        manifest_assets.append({
            "id": spec.asset_id,
            "path": f"res://assets/maps/map_01/blockers/{spec.asset_id}.png",
            "source_sheet": spec.source,
            "source_bbox": list(spec.bbox),
            "canvas_px": [image.width, image.height],
            "anchor_px": [image.width // 2, image.height - 2],
            "footprint_hint": spec.footprint_hint,
            "fadeable": spec.fadeable,
            "pair_id": spec.pair_id,
            "collision": "Authored from Map01 graybox cells; never inferred from this PNG",
        })

    manifest = {
        "version": 1,
        "approved_date": "2026-08-20",
        "source_masters": {
            "c1": "res://art/source_archive/map01_blockers/map01_c1_ridges_blockers_master_20260820.png",
            "c2": "res://art/source_archive/map01_blockers/map01_c2_foreground_pairs_master_20260820.png",
        },
        "source_pixel_per_logical_cell": 16,
        "runtime_display_scale": 3,
        "working_master_downsample": DOWNSAMPLE,
        "alpha_threshold": ALPHA_THRESHOLD,
        "palette": ["#%02x%02x%02x" % color for color in palette],
        "layer_contract": {
            "base": "always visible visual only",
            "foreground": "separate Sprite2D; runtime alpha may fade",
            "collision": "graybox-authored cells or shapes; unaffected by foreground alpha",
            "markers": "render above fadeable foreground",
        },
        "assets": manifest_assets,
    }
    (OUTPUT_DIR / "map01_blockers_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_contact_sheet(images, specs)
    print(f"Extracted {len(specs)} Map01 blocker/foreground sprites")
    print(f"Palette: {', '.join(manifest['palette'])}")
    print(f"Manifest: {OUTPUT_DIR / 'map01_blockers_manifest.json'}")
    print(f"QA sheet: {QA_DIR / 'map01_blockers_foreground_contact_sheet.png'}")


if __name__ == "__main__":
    main()
