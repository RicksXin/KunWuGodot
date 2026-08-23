#!/usr/bin/env python3
"""Prepare a deterministic, anchored Shi Yan breathing candidate.

The source is a 4x2 transparent atlas.  No resampling or repainting is done:
each source cell is copied to the same-size canvas after a small integer
translation.  The translation removes accidental whole-body drift while
preserving the breathing changes in the torso, sleeves, and robe.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image


COLS = 4
ROWS = 2
ALPHA_THRESHOLD = 128
HEAD_Y0 = 20
HEAD_Y1 = 160


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def alpha_bbox(image: Image.Image) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A").point(lambda value: 255 if value > ALPHA_THRESHOLD else 0)
    return alpha.getbbox()


def head_center(image: Image.Image) -> float:
    alpha = image.getchannel("A")
    values = alpha.crop((0, HEAD_Y0, image.width, HEAD_Y1))
    points = [(x, y) for y in range(values.height) for x in range(values.width) if values.getpixel((x, y)) > ALPHA_THRESHOLD]
    if not points:
        raise ValueError("source frame has no visible pixels in head region")
    return sum(x for x, _ in points) / len(points)


def shifted_copy(image: Image.Image, dx: int, dy: int) -> Image.Image:
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    src_left = max(0, -dx)
    src_top = max(0, -dy)
    src_right = min(image.width, image.width - dx)
    src_bottom = min(image.height, image.height - dy)
    if src_right <= src_left or src_bottom <= src_top:
        return result
    source = image.crop((src_left, src_top, src_right, src_bottom))
    result.alpha_composite(source, (max(0, dx), max(0, dy)))
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    source = args.source.expanduser().resolve()
    output_dir = args.output_dir
    output_dir.mkdir(parents=True, exist_ok=True)

    atlas = Image.open(source).convert("RGBA")
    width, height = atlas.size
    if width % COLS or height % ROWS:
        raise ValueError(f"source size {atlas.size} is not divisible by {COLS}x{ROWS}")
    cell_width, cell_height = width // COLS, height // ROWS

    cells: list[Image.Image] = []
    for index in range(COLS * ROWS):
        col, row = index % COLS, index // COLS
        cells.append(
            atlas.crop(
                (
                    col * cell_width,
                    row * cell_height,
                    (col + 1) * cell_width,
                    (row + 1) * cell_height,
                )
            )
        )

    head_centers = [head_center(cell) for cell in cells]
    target_head_center = round(sum(head_centers) / len(head_centers))
    bboxes = [alpha_bbox(cell) for cell in cells]
    bottoms = [bbox[3] - 1 for bbox in bboxes if bbox is not None]
    target_bottom = max(bottoms)

    normalized: list[Image.Image] = []
    frame_records: list[dict[str, object]] = []
    for index, cell in enumerate(cells):
        bbox = bboxes[index]
        if bbox is None:
            raise ValueError(f"source frame {index} is empty")
        dx = target_head_center - round(head_centers[index])
        dy = target_bottom - (bbox[3] - 1)
        frame = shifted_copy(cell, dx, dy)
        normalized.append(frame)
        frame_name = f"shi_yan_idle_breath_{index:02d}_{cell_width}x{cell_height}.png"
        frame.save(output_dir / frame_name)
        frame_records.append(
            {
                "index": index,
                "source_cell": {"column": index % COLS, "row": index // COLS},
                "source_alpha_bbox_threshold_128": list(bbox),
                "source_head_center_x": round(head_centers[index], 3),
                "translation_px": {"x": dx, "y": dy},
                "output": frame_name,
            }
        )

    normalized_atlas = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    for index, frame in enumerate(normalized):
        col, row = index % COLS, index // COLS
        normalized_atlas.alpha_composite(frame, (col * cell_width, row * cell_height))
    atlas_name = f"shi_yan_idle_breath_anchored_{width}x{height}.png"
    normalized_atlas.save(output_dir / atlas_name)

    manifest = {
        "character_id": "shi_yan",
        "animation": "idle_breath",
        "source": str(source),
        "source_sha256": sha256(source),
        "source_size": [width, height],
        "grid": {"columns": COLS, "rows": ROWS, "frame_count": len(cells)},
        "cell_size": [cell_width, cell_height],
        "alpha_threshold_for_anchor_analysis": ALPHA_THRESHOLD,
        "anchor_policy": {
            "horizontal": "head-region centroid, integer translation only",
            "vertical": "max visible bottom baseline, integer translation only",
            "resampling": "none",
            "source_pixels_preserved": True,
        },
        "target_head_center_x": target_head_center,
        "target_bottom_y": target_bottom,
        "atlas_output": atlas_name,
        "frames": frame_records,
        "status": "candidate_only_not_approved_runtime_asset",
    }
    (output_dir / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )


if __name__ == "__main__":
    main()
