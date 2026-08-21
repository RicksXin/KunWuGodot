#!/usr/bin/env python3
"""Normalize one opaque Map01 material master into a reviewable 64px tile."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageStat


TILE_SIZE = 64
SEAM_BLEND_WIDTH = 6
PALETTE_COLORS = 16


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--crop-size", type=int)
    return parser.parse_args()


def _mix(first: tuple[int, int, int], second: tuple[int, int, int], amount: float) -> tuple[int, int, int]:
    return tuple(round(a * (1.0 - amount) + b * amount) for a, b in zip(first, second))


def blend_opposite_edges(image: Image.Image, width: int = SEAM_BLEND_WIDTH) -> Image.Image:
    result = image.convert("RGB")
    pixels = result.load()
    size = result.width

    for y in range(size):
        edge = tuple(round((a + b) / 2) for a, b in zip(pixels[0, y], pixels[size - 1, y]))
        for distance in range(width):
            amount = (width - distance) / width
            left = distance
            right = size - 1 - distance
            pixels[left, y] = _mix(pixels[left, y], edge, amount)
            pixels[right, y] = _mix(pixels[right, y], edge, amount)

    for x in range(size):
        edge = tuple(round((a + b) / 2) for a, b in zip(pixels[x, 0], pixels[x, size - 1]))
        for distance in range(width):
            amount = (width - distance) / width
            top = distance
            bottom = size - 1 - distance
            pixels[x, top] = _mix(pixels[x, top], edge, amount)
            pixels[x, bottom] = _mix(pixels[x, bottom], edge, amount)

    return result


def edge_mismatch(image: Image.Image) -> tuple[float, float]:
    rgb = image.convert("RGB")
    left = list(rgb.crop((0, 0, 1, rgb.height)).get_flattened_data())
    right = list(rgb.crop((rgb.width - 1, 0, rgb.width, rgb.height)).get_flattened_data())
    top = list(rgb.crop((0, 0, rgb.width, 1)).get_flattened_data())
    bottom = list(rgb.crop((0, rgb.height - 1, rgb.width, rgb.height)).get_flattened_data())

    def delta(first: list[tuple[int, int, int]], second: list[tuple[int, int, int]]) -> float:
        total = sum(abs(a - b) for pixel_a, pixel_b in zip(first, second) for a, b in zip(pixel_a, pixel_b))
        return total / (len(first) * 3)

    return delta(left, right), delta(top, bottom)


def main() -> None:
    args = parse_args()
    source = Image.open(args.input).convert("RGB")
    if source.width != source.height:
        raise ValueError(f"source must be square, got {source.size}")

    crop_box = [0, 0, source.width, source.height]
    if args.crop_size is not None:
        if args.crop_size <= 0 or args.crop_size > source.width:
            raise ValueError(f"crop size must be in 1..{source.width}, got {args.crop_size}")
        offset = (source.width - args.crop_size) // 2
        crop_box = [offset, offset, offset + args.crop_size, offset + args.crop_size]
        source_region = source.crop(tuple(crop_box))
    else:
        source_region = source

    tile = source_region.resize((TILE_SIZE, TILE_SIZE), Image.Resampling.LANCZOS)
    tile = blend_opposite_edges(tile)
    tile = tile.quantize(colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    args.manifest.parent.mkdir(parents=True, exist_ok=True)
    tile.save(args.output)

    preview = Image.new("RGB", (TILE_SIZE * 4, TILE_SIZE * 4))
    for row in range(4):
        for column in range(4):
            preview.paste(tile, (column * TILE_SIZE, row * TILE_SIZE))
    preview.save(args.preview)

    mismatch_x, mismatch_y = edge_mismatch(tile)
    manifest = {
        "status": "candidate_review_only",
        "source": str(args.input),
        "source_size": list(source.size),
        "source_crop_box": crop_box,
        "source_crop_size": list(source_region.size),
        "output": str(args.output),
        "output_size": [TILE_SIZE, TILE_SIZE],
        "output_mode": tile.mode,
        "opaque": True,
        "palette_colors_requested": PALETTE_COLORS,
        "palette_colors_actual": len(tile.getcolors(maxcolors=TILE_SIZE * TILE_SIZE) or []),
        "seam_blend_width": SEAM_BLEND_WIDTH,
        "edge_mismatch_x": round(mismatch_x, 3),
        "edge_mismatch_y": round(mismatch_y, 3),
        "mean_rgb": [round(value, 2) for value in ImageStat.Stat(tile).mean],
        "sha256": hashlib.sha256(args.output.read_bytes()).hexdigest(),
        "repeat_preview": str(args.preview),
        "runtime_promoted": False,
    }
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(args.output)
    print(args.preview)
    print(args.manifest)


if __name__ == "__main__":
    main()
