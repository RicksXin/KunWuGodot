#!/usr/bin/env python3
"""Compile and preview the user-provided Map01 derelict-camp HD candidate.

The source is treated as a visual candidate only. This tool performs
deterministic alpha trimming, fit-to-contract scaling, and isolated board
previews. It never edits the formal Map01 scene or writes assets/.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageOps


MAP_CELLS = (48, 64)
CELL_SIZE = 48
BOARD_SIZE = (2304, 3072)
ANCHOR_CELL = (31, 49)
VISUAL_ORIGIN = (28, 45)
VISUAL_SIZE = (7, 5)
INTERACTION_CELL = (31, 50)
VIEWPORT_SIZE = (375, 817)
CONTEXT_ORIGIN = (24, 41)
CONTEXT_CELLS = (15, 14)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def fit_candidate(source: Image.Image) -> Image.Image:
    if source.mode != "RGBA":
        source = source.convert("RGBA")
    alpha = source.getchannel("A")
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("Candidate has no non-transparent pixels")
    # Keep a small transparent safety margin around the actual subject.
    pad = 6
    left = max(0, bbox[0] - pad)
    top = max(0, bbox[1] - pad)
    right = min(source.width, bbox[2] + pad)
    bottom = min(source.height, bbox[3] + pad)
    trimmed = source.crop((left, top, right, bottom))
    fitted = ImageOps.contain(trimmed, (VISUAL_SIZE[0] * CELL_SIZE, VISUAL_SIZE[1] * CELL_SIZE), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (VISUAL_SIZE[0] * CELL_SIZE, VISUAL_SIZE[1] * CELL_SIZE), (0, 0, 0, 0))
    canvas.alpha_composite(fitted, ((canvas.width - fitted.width) // 2, (canvas.height - fitted.height) // 2))
    return canvas


def load_board(base_path: Path, grid_path: Path) -> Image.Image:
    base = Image.open(base_path).convert("RGBA")
    grid = Image.open(grid_path).convert("RGBA")
    if base.size != BOARD_SIZE or grid.size != BOARD_SIZE:
        raise ValueError(f"Board layers must be {BOARD_SIZE}; got {base.size} and {grid.size}")
    return Image.alpha_composite(base, grid)


def draw_debug_contract(image: Image.Image, board_origin: tuple[int, int], scale: float) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    ox, oy = board_origin
    x0 = (VISUAL_ORIGIN[0] - ox) * CELL_SIZE * scale
    y0 = (VISUAL_ORIGIN[1] - oy) * CELL_SIZE * scale
    x1 = x0 + VISUAL_SIZE[0] * CELL_SIZE * scale
    y1 = y0 + VISUAL_SIZE[1] * CELL_SIZE * scale
    draw.rectangle((x0, y0, x1 - 1, y1 - 1), outline=(89, 215, 224, 220), width=max(1, round(2 * scale)))
    for cell_y in range(VISUAL_ORIGIN[1], VISUAL_ORIGIN[1] + VISUAL_SIZE[1]):
        for cell_x in range(VISUAL_ORIGIN[0], VISUAL_ORIGIN[0] + VISUAL_SIZE[0]):
            left = (cell_x - ox) * CELL_SIZE * scale
            top = (cell_y - oy) * CELL_SIZE * scale
            draw.rectangle((left, top, left + CELL_SIZE * scale - 1, top + CELL_SIZE * scale - 1), outline=(238, 110, 94, 125), width=max(1, round(scale)))
    ix, iy = INTERACTION_CELL
    left = (ix - ox) * CELL_SIZE * scale
    top = (iy - oy) * CELL_SIZE * scale
    draw.rectangle((left + 2 * scale, top + 2 * scale, left + CELL_SIZE * scale - 3 * scale, top + CELL_SIZE * scale - 3 * scale), outline=(244, 201, 101, 240), width=max(1, round(2 * scale)))


def compose_context(board: Image.Image, sprite: Image.Image, debug: bool, scale: float = 1.0) -> Image.Image:
    ox, oy = CONTEXT_ORIGIN
    left = ox * CELL_SIZE
    top = oy * CELL_SIZE
    width = CONTEXT_CELLS[0] * CELL_SIZE
    height = CONTEXT_CELLS[1] * CELL_SIZE
    context = board.crop((left, top, left + width, top + height))
    if scale != 1.0:
        context = context.resize((round(width * scale), round(height * scale)), Image.Resampling.LANCZOS)
    sprite_scaled = sprite.resize((round(sprite.width * scale), round(sprite.height * scale)), Image.Resampling.LANCZOS)
    sprite_left = round((VISUAL_ORIGIN[0] - ox) * CELL_SIZE * scale)
    sprite_top = round((VISUAL_ORIGIN[1] - oy) * CELL_SIZE * scale)
    context.alpha_composite(sprite_scaled, (sprite_left, sprite_top))
    if debug:
        draw_debug_contract(context, (ox, oy), scale)
    return context


def compose_runtime_viewport(board: Image.Image, sprite: Image.Image, debug: bool) -> Image.Image:
    anchor_world = ((ANCHOR_CELL[0] + 0.5) * CELL_SIZE, (ANCHOR_CELL[1] + 1.0) * CELL_SIZE)
    left = round(anchor_world[0] - VIEWPORT_SIZE[0] / 2)
    top = round(anchor_world[1] - VIEWPORT_SIZE[1] / 2)
    viewport = board.crop((left, top, left + VIEWPORT_SIZE[0], top + VIEWPORT_SIZE[1]))
    sprite_left = round((VISUAL_ORIGIN[0] * CELL_SIZE) - left)
    sprite_top = round((VISUAL_ORIGIN[1] * CELL_SIZE) - top)
    viewport.alpha_composite(sprite, (sprite_left, sprite_top))
    if debug:
        draw_debug_contract(viewport, (left // CELL_SIZE, top // CELL_SIZE), 1.0)
    return viewport


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("--board-base", type=Path, required=True)
    parser.add_argument("--grid", type=Path, required=True)
    parser.add_argument("--contract", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    source = Image.open(args.source)
    if source.mode != "RGBA":
        raise ValueError(f"Expected RGBA PNG, got {source.mode}")
    contract = json.loads(args.contract.read_text(encoding="utf-8"))
    if contract.get("logical_size_cells") != list(VISUAL_SIZE):
        raise ValueError("Candidate contract is not the 7x5 v2 contract")
    if contract.get("anchor_cell") != list(ANCHOR_CELL):
        raise ValueError("Candidate contract anchor differs from preview anchor")

    candidate = fit_candidate(source)
    board = load_board(args.board_base, args.grid)

    output = args.output_dir
    archive = output / "source_archive"
    compiled = output / "compiled"
    review = output / "review"
    archive.mkdir(parents=True, exist_ok=True)
    compiled.mkdir(parents=True, exist_ok=True)
    review.mkdir(parents=True, exist_ok=True)

    archived_source = archive / "map01_derelict_camp_hd_base_gpt_v2_raw.png"
    shutil.copy2(args.source, archived_source)
    candidate_path = compiled / "map01_derelict_camp_hd_base_336x240_candidate.png"
    candidate.save(candidate_path, format="PNG", optimize=False)

    compose_context(board, candidate, debug=False, scale=1.0).save(review / "map01_derelict_camp_hd_v2_context_100.png")
    compose_context(board, candidate, debug=False, scale=0.75).save(review / "map01_derelict_camp_hd_v2_context_75.png")
    compose_context(board, candidate, debug=False, scale=0.5).save(review / "map01_derelict_camp_hd_v2_context_50.png")
    compose_context(board, candidate, debug=True, scale=1.0).save(review / "map01_derelict_camp_hd_v2_context_contract_debug.png")
    runtime = compose_runtime_viewport(board, candidate, debug=False)
    runtime.save(review / "map01_derelict_camp_hd_v2_runtime_viewport_375x817.png")
    ImageOps.grayscale(runtime).convert("RGBA").save(review / "map01_derelict_camp_hd_v2_runtime_viewport_grayscale.png")

    alpha = candidate.getchannel("A")
    manifest = {
        "schema_version": 1,
        "status": "candidate_visual_review_only",
        "asset_id": "map01_derelict_camp_hd_base_v2",
        "supplier": "ChatGPT, user-executed",
        "source": {
            "path": str(args.source),
            "sha256": sha256(args.source),
            "size_px": list(source.size),
            "mode": source.mode,
            "alpha_bbox": list(source.getchannel("A").getbbox()),
        },
        "compiled": {
            "path": str(candidate_path),
            "sha256": sha256(candidate_path),
            "size_px": list(candidate.size),
            "mode": candidate.mode,
            "alpha_bbox": list(alpha.getbbox()),
            "anchor_cell": list(ANCHOR_CELL),
            "visual_cells": [list(cell) for cell in ((x, y) for y in range(VISUAL_ORIGIN[1], VISUAL_ORIGIN[1] + VISUAL_SIZE[1]) for x in range(VISUAL_ORIGIN[0], VISUAL_ORIGIN[0] + VISUAL_SIZE[0]))],
            "blocked_cells": 35,
            "interaction_cell": list(INTERACTION_CELL),
        },
        "review_outputs": [str(path) for path in sorted(review.glob("*.png"))],
        "runtime_asset": False,
        "formal_scene_modified": False,
        "meowa_points_spent": 0,
        "notes": [
            "Candidate is fitted to 7x5 visual contract with 336x240 runtime delivery size.",
            "Visual review does not approve collision or object coordinates.",
            "Corpse overlays are not generated or inferred from this base.",
        ],
    }
    (compiled / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"MAP01_DERELICT_CAMP_HD_COMPILE_OK candidate={candidate_path} viewport={review / 'map01_derelict_camp_hd_v2_runtime_viewport_375x817.png'}")


if __name__ == "__main__":
    main()
