#!/usr/bin/env python3
"""Prepare fixed 64px Meowa dual-terrain inputs from approved Map01 brushes."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops


PROJECT_ROOT = Path(__file__).resolve().parents[1]
OUTPUT_DIR = PROJECT_ROOT / "art/source_archive/meowa/map01_road_dual_transition_input_20260821"
GROUND_MASTER = PROJECT_ROOT / "assets/compiled/tilemapdual_standard.png"
ROAD_MASTER = PROJECT_ROOT / "assets/compiled/map01_road/tilemapdual_standard.png"
COMPLETE_TILE_BOX = (512, 256, 768, 512)


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def make_seamless_reference(source: Path, output: Path) -> dict[str, object]:
    with Image.open(source) as image:
        complete_tile = image.convert("RGBA").crop(COMPLETE_TILE_BOX)
    if complete_tile.getextrema()[3] != (255, 255):
        raise ValueError(f"Complete tile is not fully opaque: {source}")

    reduced = complete_tile.resize((64, 64), Image.Resampling.NEAREST)
    wrapped = ImageChops.offset(reduced, 32, 32)
    mask = Image.new("L", (64, 64))
    mask_pixels = mask.load()
    for y in range(64):
        for x in range(64):
            distance = max(abs(x - 31.5), abs(y - 31.5)) / 31.5
            smooth = distance * distance * (3.0 - 2.0 * distance)
            mask_pixels[x, y] = round(255.0 * smooth)
    blended = Image.composite(wrapped, reduced, mask).convert("RGB")
    seamless = blended.quantize(colors=32, dither=Image.Dither.NONE).convert("RGBA")
    seamless.save(output)

    left = list(seamless.crop((0, 0, 1, 64)).get_flattened_data())
    right = list(seamless.crop((63, 0, 64, 64)).get_flattened_data())
    top_edge = list(seamless.crop((0, 0, 64, 1)).get_flattened_data())
    bottom = list(seamless.crop((0, 63, 64, 64)).get_flattened_data())

    def mean_rgb_delta(first: list[tuple[int, ...]], second: list[tuple[int, ...]]) -> float:
        total = sum(abs(a[channel] - b[channel]) for a, b in zip(first, second) for channel in range(3))
        return round(total / (len(first) * 3), 3)

    return {
        "source": str(source.relative_to(PROJECT_ROOT)),
        "output": str(output.relative_to(PROJECT_ROOT)),
        "size_px": [64, 64],
        "opaque": seamless.getextrema()[3] == (255, 255),
        "horizontal_seam_mean_rgb_delta": mean_rgb_delta(left, right),
        "vertical_seam_mean_rgb_delta": mean_rgb_delta(top_edge, bottom),
        "sha256": sha256(output),
    }


def save_repeat_preview(textures: list[tuple[str, Path]], output: Path) -> None:
    zoom = 3
    repeats = 3
    card_size = 64 * repeats * zoom
    gutter = 24
    preview = Image.new("RGB", (card_size * len(textures) + gutter, card_size), "#172027")
    for index, (_, path) in enumerate(textures):
        with Image.open(path) as source:
            tile = source.convert("RGBA")
        repeated = Image.new("RGBA", (64 * repeats, 64 * repeats))
        for y in range(repeats):
            for x in range(repeats):
                repeated.paste(tile, (x * 64, y * 64))
        repeated = repeated.resize((card_size, card_size), Image.Resampling.NEAREST)
        preview.paste(repeated.convert("RGB"), (index * (card_size + gutter), 0))
    preview.save(output)


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    ground_output = OUTPUT_DIR / "map01_gray_ground_64.png"
    road_output = OUTPUT_DIR / "map01_ochre_road_64.png"
    records = [
        make_seamless_reference(GROUND_MASTER, ground_output),
        make_seamless_reference(ROAD_MASTER, road_output),
    ]
    preview_output = OUTPUT_DIR / "map01_road_dual_input_repeat_preview.png"
    save_repeat_preview(
        [("gray ground", ground_output), ("ochre road", road_output)],
        preview_output,
    )
    manifest = {
        "schema_version": 1,
        "purpose": "Meowa dual-terrain input for Map01 ochre road to gray ground transition",
        "terrain_mode": "dual",
        "background_texture": str(ground_output.relative_to(PROJECT_ROOT)),
        "foreground_texture": str(road_output.relative_to(PROJECT_ROOT)),
        "complete_tile_box": list(COMPLETE_TILE_BOX),
        "resampling": "nearest",
        "seam_strategy": "half-tile wrap with smooth center blend and 32-color palette quantization",
        "textures": records,
        "repeat_preview": str(preview_output.relative_to(PROJECT_ROOT)),
    }
    manifest_path = OUTPUT_DIR / "input_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
