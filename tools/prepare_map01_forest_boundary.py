#!/usr/bin/env python3
"""Build the Map01 D1 outer-forest texture from the user-provided reference.

The layout mask, not the reference image, decides which cells are visual forest.
This keeps the generated texture independent from walkability/collision semantics.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image


SOURCE_SIZE = (768, 1024)
CELL_SIZE = 16
FOREST_FLOOR = (35, 52, 55, 255)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def build(source: Path, mask_path: Path, output: Path, archive: Path, manifest: Path) -> None:
    source.parent.mkdir(parents=True, exist_ok=True)
    archive.parent.mkdir(parents=True, exist_ok=True)
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, archive)

    reference = Image.open(source).convert("RGBA")
    reference = reference.resize(SOURCE_SIZE, Image.Resampling.NEAREST)
    mask = json.loads(mask_path.read_text(encoding="utf-8"))
    # The outer collision band is made of the old foreground and blocked
    # semantic cells. Keep the dedicated ridge cells as the interior mountain.
    forest_cells = {
        tuple(cell) for cell in mask["foregroundCells"] + mask["blockedCells"]
    }
    width, height = SOURCE_SIZE
    result = Image.new("RGBA", SOURCE_SIZE, (0, 0, 0, 0))
    result_pixels = result.load()
    reference_pixels = reference.load()
    width_cells = SOURCE_SIZE[0] // CELL_SIZE
    height_cells = SOURCE_SIZE[1] // CELL_SIZE
    dilated_cells = set(forest_cells)
    for cell_x, cell_y in forest_cells:
        for offset_y in (-1, 0, 1):
            for offset_x in (-1, 0, 1):
                candidate = (cell_x + offset_x, cell_y + offset_y)
                if 0 <= candidate[0] < width_cells and 0 <= candidate[1] < height_cells:
                    dilated_cells.add(candidate)
    for y in range(SOURCE_SIZE[1]):
        for x in range(SOURCE_SIZE[0]):
            cell = (x // CELL_SIZE, y // CELL_SIZE)
            red, green, blue, _ = reference_pixels[x, y]
            luminance = (red + green + blue) / 3.0
            is_dark_forest = luminance < 92 and blue >= red - 2
            if cell in forest_cells:
                # Keep the whole semantic forest cell covered, but suppress bright
                # paths/landmarks from the reference into a dark forest floor.
                result_pixels[x, y] = (red, green, blue, 255) if luminance < 108 else FOREST_FLOOR
            elif cell in dilated_cells and is_dark_forest:
                # Let dark tree silhouettes cross the semantic edge so the inner
                # forest boundary is organic instead of a rectangular cutout.
                result_pixels[x, y] = (red, green, blue, 255)
    result.save(output, format="PNG", optimize=False)

    manifest.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "status": "candidate_user_reference_derived",
                "source_reference": str(archive),
                "source_sha256": sha256(archive),
                "layout_mask": str(mask_path),
                "output": str(output),
                "output_size": list(SOURCE_SIZE),
                "cell_size": CELL_SIZE,
                "forest_cells": len(forest_cells),
                "purpose": "Visual forest cover for Map01 D1 foreground cells; collision remains scene-derived.",
                "meowa_points_spent": 0,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"MAP01_FOREST_BOUNDARY_OK cells={len(forest_cells)} output={output}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("mask", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("archive", type=Path)
    parser.add_argument("manifest", type=Path)
    args = parser.parse_args()
    build(args.source, args.mask, args.output, args.archive, args.manifest)


if __name__ == "__main__":
    main()
