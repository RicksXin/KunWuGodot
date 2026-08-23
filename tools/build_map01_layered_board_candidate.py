#!/usr/bin/env python3
"""Build a deterministic layered-board candidate for formal Map01.

The ChatGPT image is visual reference only. Its per-cell stone detail is
sampled and re-tinted according to the formal 48x64 greybox mask so generated
color mistakes cannot change layout or collision semantics. Outputs stay under
art/candidates and never replace runtime assets or the formal Map01 scene.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from collections import Counter
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps, ImageStat


MAP_CELLS = (48, 64)
CELL_SIZE = 48
BOARD_SIZE = (MAP_CELLS[0] * CELL_SIZE, MAP_CELLS[1] * CELL_SIZE)

CHAR_TO_SEMANTIC = {
    ".": "ground",
    "=": "road",
    "~": "difficult",
    "#": "blocked",
    "R": "blocked",
    "F": "blocked",
}

# Restrained bases keep future one-cell markers and building overlays readable.
SEMANTIC_BASES = {
    "ground": (112, 123, 132),
    "road": (157, 137, 99),
    "difficult": (105, 94, 82),
    "blocked": (40, 50, 62),
}

# Blocked terrain is intentionally quieter than the playable plane.
SEMANTIC_DETAIL_STRENGTH = {
    "ground": 0.48,
    "road": 0.44,
    "difficult": 0.40,
    "blocked": 0.30,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_mask(payload: dict) -> list[str]:
    if payload.get("mapSize") != list(MAP_CELLS):
        raise ValueError(f"Expected mapSize {list(MAP_CELLS)}, got {payload.get('mapSize')}")
    rows = payload.get("rows")
    if not isinstance(rows, list) or len(rows) != MAP_CELLS[1]:
        raise ValueError(f"Expected {MAP_CELLS[1]} rows")
    for index, row in enumerate(rows):
        if not isinstance(row, str) or len(row) != MAP_CELLS[0]:
            raise ValueError(f"Row {index} is not {MAP_CELLS[0]} cells wide")
        unknown = set(row) - set(CHAR_TO_SEMANTIC)
        if unknown:
            raise ValueError(f"Row {index} contains unknown cell codes: {sorted(unknown)}")
    return rows


def source_cell(source: Image.Image, cell_x: int, cell_y: int) -> Image.Image:
    """Extract one non-integer 22.625px source cell without cumulative drift."""
    left = round(cell_x * source.width / MAP_CELLS[0])
    right = round((cell_x + 1) * source.width / MAP_CELLS[0])
    top = round(cell_y * source.height / MAP_CELLS[1])
    bottom = round((cell_y + 1) * source.height / MAP_CELLS[1])
    return source.crop((left, top, right, bottom)).resize(
        (CELL_SIZE, CELL_SIZE), Image.Resampling.LANCZOS
    )


def tint_cell(tile: Image.Image, semantic: str) -> Image.Image:
    """Keep local relief while pinning the tile's mean color to its semantic."""
    gray = ImageOps.grayscale(tile).filter(ImageFilter.GaussianBlur(radius=0.35))
    mean = ImageStat.Stat(gray).mean[0]
    base = SEMANTIC_BASES[semantic]
    strength = SEMANTIC_DETAIL_STRENGTH[semantic]
    channels = []
    for component in base:
        lookup = [
            max(0, min(255, round(component + (value - mean) * strength)))
            for value in range(256)
        ]
        channels.append(gray.point(lookup))
    return Image.merge("RGB", channels)


def build_base(source: Image.Image, rows: list[str]) -> tuple[Image.Image, Counter[str]]:
    board = Image.new("RGB", BOARD_SIZE)
    counts: Counter[str] = Counter()
    for cell_y, row in enumerate(rows):
        for cell_x, cell_code in enumerate(row):
            semantic = CHAR_TO_SEMANTIC[cell_code]
            counts[semantic] += 1
            tile = tint_cell(source_cell(source, cell_x, cell_y), semantic)
            board.paste(tile, (cell_x * CELL_SIZE, cell_y * CELL_SIZE))
    return board, counts


def build_grid_overlay() -> Image.Image:
    overlay = Image.new("RGBA", BOARD_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    minor = (230, 237, 234, 33)
    major = (236, 241, 238, 50)
    for cell_x in range(MAP_CELLS[0] + 1):
        pixel_x = min(cell_x * CELL_SIZE, BOARD_SIZE[0] - 1)
        draw.line(
            (pixel_x, 0, pixel_x, BOARD_SIZE[1] - 1),
            fill=major if cell_x % 4 == 0 else minor,
            width=1,
        )
    for cell_y in range(MAP_CELLS[1] + 1):
        pixel_y = min(cell_y * CELL_SIZE, BOARD_SIZE[1] - 1)
        draw.line(
            (0, pixel_y, BOARD_SIZE[0] - 1, pixel_y),
            fill=major if cell_y % 4 == 0 else minor,
            width=1,
        )
    draw.rectangle(
        (0, 0, BOARD_SIZE[0] - 1, BOARD_SIZE[1] - 1),
        outline=(240, 244, 241, 82),
        width=2,
    )
    return overlay


def build_blocked_debug_overlay(collision_cells: list[list[int]]) -> Image.Image:
    overlay = Image.new("RGBA", BOARD_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    for cell in collision_cells:
        if not isinstance(cell, list) or len(cell) != 2:
            raise ValueError(f"Invalid collision cell: {cell!r}")
        cell_x, cell_y = map(int, cell)
        if not (0 <= cell_x < MAP_CELLS[0] and 0 <= cell_y < MAP_CELLS[1]):
            raise ValueError(f"Collision cell out of bounds: {cell}")
        left = cell_x * CELL_SIZE
        top = cell_y * CELL_SIZE
        right = left + CELL_SIZE - 1
        bottom = top + CELL_SIZE - 1
        draw.rectangle((left, top, right, bottom), fill=(218, 70, 62, 66))
        draw.rectangle((left, top, right, bottom), outline=(255, 151, 101, 142), width=1)
        draw.line((left + 10, bottom - 10, right - 10, top + 10), fill=(255, 185, 117, 102), width=1)
    return overlay


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path, help="User-approved ChatGPT V2 visual mother")
    parser.add_argument("mask", type=Path, help="Formal 48x64 environment mask JSON")
    parser.add_argument("output_dir", type=Path, help="Candidate output directory")
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGB")
    if source.width * MAP_CELLS[1] != source.height * MAP_CELLS[0]:
        raise ValueError(f"Source must be exact 3:4, got {source.size}")

    payload = json.loads(args.mask.read_text(encoding="utf-8"))
    rows = validate_mask(payload)
    collision_cells = payload.get("collisionBlockedCells")
    if not isinstance(collision_cells, list):
        raise ValueError("Mask has no collisionBlockedCells list")

    output_dir = args.output_dir
    archive_dir = output_dir / "source_archive"
    compiled_dir = output_dir / "compiled"
    archive_dir.mkdir(parents=True, exist_ok=True)
    compiled_dir.mkdir(parents=True, exist_ok=True)

    archived_source = archive_dir / "map01_visual_plane_gpt_v2.png"
    shutil.copy2(args.source, archived_source)

    base, counts = build_base(source, rows)
    grid = build_grid_overlay()
    blocked_debug = build_blocked_debug_overlay(collision_cells)

    base_path = compiled_dir / "map01_board_base_2304x3072.png"
    grid_path = compiled_dir / "map01_grid_overlay_2304x3072.png"
    blocked_path = compiled_dir / "map01_blocked_debug_overlay_2304x3072.png"
    manifest_path = compiled_dir / "manifest.json"

    base.save(base_path, format="PNG", optimize=False)
    grid.save(grid_path, format="PNG", optimize=False)
    blocked_debug.save(blocked_path, format="PNG", optimize=False)

    blocked_from_rows = sum(
        1 for row in rows for code in row if CHAR_TO_SEMANTIC[code] == "blocked"
    )
    if blocked_from_rows != len(collision_cells):
        raise ValueError(
            "Blocked mask mismatch: "
            f"rows={blocked_from_rows} collisionBlockedCells={len(collision_cells)}"
        )
    if sum(counts.values()) != MAP_CELLS[0] * MAP_CELLS[1]:
        raise ValueError(f"Compiled cell count mismatch: {sum(counts.values())}")

    outputs = [base_path, grid_path, blocked_path]
    manifest = {
        "schema_version": 1,
        "status": "candidate_layered_board_not_runtime_asset",
        "map_id": "map_01",
        "board_cells": list(MAP_CELLS),
        "cell_size_px": CELL_SIZE,
        "board_size_px": list(BOARD_SIZE),
        "visual_source": {
            "supplier": "ChatGPT, user-executed",
            "input_path": str(args.source),
            "archived_path": str(archived_source),
            "sha256": sha256(archived_source),
            "source_size_px": list(source.size),
        },
        "layout_source": {
            "path": str(args.mask),
            "sha256": sha256(args.mask),
            "coordinate_contract": payload.get("coordinateContract"),
        },
        "semantic_counts": dict(sorted(counts.items())),
        "collision_blocked_cells": len(collision_cells),
        "processing": (
            "Per-cell visual-detail sampling from the GPT V2 mother; deterministic "
            "semantic re-tint from the formal mask; separate low-alpha grid and "
            "collision debug overlays. No generated color or alpha controls collision."
        ),
        "layer_order": ["base", "grid", "future_buildings", "future_markers", "future_fog_and_player"],
        "future_building_contract": [
            "visual_cells",
            "blocked_cells",
            "interaction_cells",
            "anchor_cell",
        ],
        "runtime_asset": False,
        "formal_scene_modified": False,
        "meowa_points_spent": 0,
        "outputs": [
            {"path": str(path), "sha256": sha256(path), "size_px": list(Image.open(path).size)}
            for path in outputs
        ],
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        "MAP01_LAYERED_BOARD_BUILD_OK "
        f"cells={sum(counts.values())} blocked={len(collision_cells)} base={base_path}"
    )


if __name__ == "__main__":
    main()
