#!/usr/bin/env python3
"""Compose a GPT forest-edge candidate into the Map01 D1 visual forest mask.

This is a deterministic candidate-only operation. It does not change the
layout mask, collision, formal scene, or product data. The source remains an
independent forest module; flips/rotations are only composition transforms.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops


MAP_SIZE = (768, 1024)
CELL_SIZE = 16
MODULE_SIZE = (384, 384)
EDGE_JITTER_MIN = 2
EDGE_JITTER_MAX = 6


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _jitter(seed: int, index: int, amount: int = EDGE_JITTER_MAX) -> int:
    # Small deterministic offsets make the visible forest edge organic while
    # keeping the underlying semantic mask unchanged.
    value = (seed * 1103515245 + index * 12345 + 1013904223) & 0x7FFFFFFF
    span = max(1, amount - EDGE_JITTER_MIN + 1)
    return EDGE_JITTER_MIN + value % span


def _notch(seed: int, index: int) -> bool:
    """Return a stable, sparse decision for a small edge bite."""
    value = (seed * 1664525 + index * 1013904223 + 2246822519) & 0xFFFFFFFF
    return value % 5 in (0, 1)


def _draw_edge_notch(draw, side: str, left: int, top: int, right: int, bottom: int, seed: int, index: int) -> None:
    """Carve a tiny rounded bite into one exposed cell edge.

    The bite stays inside the already blocked/foreground cell. It only changes
    the visual silhouette; walkability and collision continue to come from the
    scene-derived mask.
    """
    if not _notch(seed, index):
        return
    radius = 1 + ((seed + index * 17) & 0x3)  # 1–4 px at source-map scale
    fraction_index = (seed + index * 7) % 5
    center_fraction = (0.2, 0.35, 0.5, 0.65, 0.8)[fraction_index]
    if side in ("top", "bottom"):
        center_x = round(left + center_fraction * (right - left))
        if side == "top":
            center_y = top + EDGE_JITTER_MIN + radius
            bbox = (center_x - radius, top, center_x + radius, center_y + radius)
        else:
            center_y = bottom - EDGE_JITTER_MIN - radius
            bbox = (center_x - radius, center_y - radius, center_x + radius, bottom)
    else:
        center_y = round(top + center_fraction * (bottom - top))
        if side == "left":
            center_x = left + EDGE_JITTER_MIN + radius
            bbox = (left, center_y - radius, center_x + radius, center_y + radius)
        else:
            center_x = right - EDGE_JITTER_MIN - radius
            bbox = (center_x - radius, center_y - radius, right, center_y + radius)
    draw.ellipse(bbox, fill=0)


def organic_cell_mask(mask_path: Path) -> Image.Image:
    payload = json.loads(mask_path.read_text(encoding="utf-8"))
    rows = payload["rows"]
    width = MAP_SIZE[0] // CELL_SIZE
    height = MAP_SIZE[1] // CELL_SIZE
    if len(rows) != height or any(len(row) != width for row in rows):
        raise ValueError("Map01 mask must be exactly 48x64 cells")
    forest_cells = {
        tuple(cell) for cell in payload["foregroundCells"] + payload["blockedCells"]
    }
    result = Image.new("L", MAP_SIZE, 0)
    from PIL import ImageDraw

    draw = ImageDraw.Draw(result)
    for cell_x, cell_y in forest_cells:
        left = cell_x * CELL_SIZE
        top = cell_y * CELL_SIZE
        right = left + CELL_SIZE - 1
        bottom = top + CELL_SIZE - 1
        seed = cell_x * 92821 + cell_y * 68917
        exposed = {
            "left": (cell_x - 1, cell_y) not in forest_cells,
            "right": (cell_x + 1, cell_y) not in forest_cells,
            "top": (cell_x, cell_y - 1) not in forest_cells,
            "bottom": (cell_x, cell_y + 1) not in forest_cells,
        }

        # Five samples per exposed side break the square mask at mobile scale
        # without producing a noisy hand-drawn border.
        fractions = (0.0, 0.25, 0.5, 0.75, 1.0)
        top_points = []
        right_points = []
        bottom_points = []
        left_points = []
        for index, fraction in enumerate(fractions):
            x = round(left + fraction * (right - left))
            y = round(top + fraction * (bottom - top))
            top_points.append((x, top + (_jitter(seed, index, 5) if exposed["top"] else 0)))
            right_points.append((right - (_jitter(seed, 10 + index, 5) if exposed["right"] else 0), y))
            bottom_points.append((x, bottom - (_jitter(seed, 20 + index, 5) if exposed["bottom"] else 0)))
            left_points.append((left + (_jitter(seed, 30 + index, 5) if exposed["left"] else 0), y))

        polygon = top_points + right_points[1:] + list(reversed(bottom_points[:-1])) + list(reversed(left_points[1:-1]))
        draw.polygon(polygon, fill=255)
        for notch_index, side in enumerate(("top", "right", "bottom", "left")):
            if exposed[side]:
                _draw_edge_notch(draw, side, left, top, right, bottom, seed, notch_index)
    return result


def hard_alpha(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    image.putalpha(alpha)
    return image


def place(canvas: Image.Image, module: Image.Image, position: tuple[int, int], clip: Image.Image) -> None:
    layer = Image.new("RGBA", MAP_SIZE, (0, 0, 0, 0))
    layer.alpha_composite(module, position)
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    canvas.alpha_composite(layer)


def compose(source: Path, mask_path: Path, output: Path, manifest: Path) -> None:
    source_image = hard_alpha(Image.open(source).resize(MODULE_SIZE, Image.Resampling.NEAREST))
    source_flip = source_image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    source_cw = source_image.rotate(-90, expand=True)
    source_ccw = source_image.rotate(90, expand=True)
    clip = organic_cell_mask(mask_path)
    result = Image.new("RGBA", MAP_SIZE, (0, 0, 0, 0))

    # Four side modules, with modest overlap. The layout mask clips all visual
    # content back to the outer blocked/foreground band.
    placements = [
        ("left_top", source_image, (0, 0)),
        ("right_top", source_flip, (384, 0)),
        ("left_mid", source_image, (0, 320)),
        ("right_mid", source_flip, (384, 320)),
        ("bottom_left", source_cw, (0, 640)),
        ("bottom_right", source_ccw, (384, 640)),
    ]
    for _, module, position in placements:
        place(result, module, position, clip)

    output.parent.mkdir(parents=True, exist_ok=True)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, format="PNG", optimize=False)
    manifest.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "status": "candidate_deterministic_composite",
                "source": str(source),
                "source_sha256": sha256(source),
                "layout_mask": str(mask_path),
                "output": str(output),
                "output_size": list(MAP_SIZE),
                "module_size": list(MODULE_SIZE),
                "alpha_policy": "hard threshold at 128; nearest-neighbor resize",
                "edge_policy": "deterministic 2-6 px inward jitter plus sparse 1-4 px rounded bites on exposed forest-cell sides",
                "transforms": [name for name, _, _ in placements],
                "purpose": "Map01 D1 visual forest overlay candidate; collision remains scene-derived",
                "meowa_points_spent": 0,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"MAP01_FOREST_CANDIDATE_COMPOSE_OK output={output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("mask", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    compose(args.source, args.mask, args.output, args.manifest)


if __name__ == "__main__":
    main()
