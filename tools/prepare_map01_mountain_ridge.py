#!/usr/bin/env python3
"""Compose the Map01 D1 interior ridge as a standalone transparent PNG.

The graybox mask remains the only source of the ridge footprint. This tool only
assembles already-approved ridge/blocker PNGs into a visual candidate; it does
not author collision or alter the Godot map layout.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageOps


MAP_WIDTH = 48
MAP_HEIGHT = 64
CELL_SIZE = 16
OUTPUT_SIZE = (MAP_WIDTH * CELL_SIZE, MAP_HEIGHT * CELL_SIZE)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--mask",
        type=Path,
        default=Path("art/candidates/map01_layout/map01_d1_environment_mask_20260820.json"),
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("assets/maps/map_01/environment/map01_d1_mountain_ridge.png"),
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("art/candidates/map01_mountain_ridge/map01_d1_mountain_ridge_manifest.json"),
    )
    parser.add_argument(
        "--material",
        type=Path,
        default=Path(
            "art/candidates/map01_mountain_windmill/compiled_v2/"
            "map01_mountain_windmill_normalized_v2c_bedrock_interior.png"
        ),
    )
    return parser.parse_args()


def semantic_mask(rows: list[str], semantic: str) -> Image.Image:
    mask = Image.new("L", OUTPUT_SIZE, 0)
    pixels = mask.load()
    for y, row in enumerate(rows):
        for x, value in enumerate(row):
            if value != semantic:
                continue
            left = x * CELL_SIZE
            top = y * CELL_SIZE
            for py in range(top, top + CELL_SIZE):
                for px in range(left, left + CELL_SIZE):
                    pixels[px, py] = 255
    return mask


def paste_clipped(canvas: Image.Image, sprite: Image.Image, position: tuple[int, int], clip: Image.Image) -> None:
    temp = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    temp.alpha_composite(sprite, position)
    temp.putalpha(ImageChops.multiply(temp.getchannel("A"), clip))
    canvas.alpha_composite(temp)


def load_sprite(path: Path, flip_horizontal: bool = False) -> Image.Image:
    sprite = Image.open(path).convert("RGBA")
    if flip_horizontal:
        sprite = sprite.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
    return sprite


def build_material(material_path: Path) -> Image.Image:
    """Make a low-repeat D1-scale bedrock texture from the approved master."""
    source = Image.open(material_path).convert("RGB")
    # This interior crop is fully opaque in the approved v2c master; it avoids
    # importing the master windmill's transparent holes or its outer silhouette.
    sample = source.crop((400, 400, 650, 650))
    tile_size = 112  # seven D1 source cells; enough strata detail at mobile scale.
    tile = sample.resize((tile_size, tile_size), Image.Resampling.BILINEAR)
    texture = Image.new("RGB", OUTPUT_SIZE)
    transforms = (
        lambda image: image,
        ImageOps.mirror,
        ImageOps.flip,
        ImageOps.flip,
    )
    for tile_y, top in enumerate(range(0, OUTPUT_SIZE[1], tile_size)):
        for tile_x, left in enumerate(range(0, OUTPUT_SIZE[0], tile_size)):
            variant = transforms[(tile_x + tile_y) % len(transforms)](tile)
            if (tile_x + tile_y) % 4 == 3:
                variant = variant.rotate(180)
            texture.paste(variant, (left, top))
    texture = ImageEnhance.Contrast(texture).enhance(1.38)
    texture = ImageEnhance.Brightness(texture).enhance(0.88)
    return texture.convert("RGBA")


def compose(mask_path: Path, output: Path, manifest: Path, material_path: Path) -> None:
    payload = json.loads(mask_path.read_text(encoding="utf-8"))
    rows = payload["rows"]
    if len(rows) != MAP_HEIGHT or any(len(row) != MAP_WIDTH for row in rows):
        raise ValueError("Map01 environment mask must be exactly 48x64 cells")

    ridge_mask = semantic_mask(rows, "R")
    result = build_material(material_path)
    result.putalpha(ridge_mask)
    project_root = Path(__file__).resolve().parents[1]
    blocker_dir = project_root / "assets/maps/map_01/blockers"
    sprite_specs = [
        ("ridge_ne_sw_static", False),
        ("ridge_ne_sw_base", False),
        ("ridge_nw_se_static", True),
        ("ridge_nw_se_base", True),
    ]
    sprites = [
        (name, load_sprite(blocker_dir / f"{name}.png", flip))
        for name, flip in sprite_specs
        if (blocker_dir / f"{name}.png").exists()
    ]
    placements: list[dict[str, object]] = []
    # Add sparse, approved rock clusters over the continuous material. The
    # material carries the mountain mass; these clusters supply readable strata
    # at normal map scale without becoming a repeated wall edge.
    for index, anchor_y in enumerate(range(30, 56, 4)):
        xs = [x for x in range(MAP_WIDTH) if rows[anchor_y][x] == "R"]
        if not xs or not sprites:
            continue
        name, source = sprites[index % len(sprites)]
        anchor_x = round(sum(xs) / len(xs))
        scale = (0.78, 0.9, 0.84, 0.88)[index % 4]
        sprite = source.resize(
            (max(1, round(source.width * scale)), max(1, round(source.height * scale))),
            Image.Resampling.NEAREST,
        )
        position = (
            anchor_x * CELL_SIZE + CELL_SIZE // 2 - sprite.width // 2 + (-2, 1, 0, 2)[index % 4],
            (anchor_y + 1) * CELL_SIZE - sprite.height,
        )
        paste_clipped(result, sprite, position, ridge_mask)
        placements.append({"asset": name, "cell": [anchor_x, anchor_y], "position_px": list(position)})

    east_path = blocker_dir / "blocker_2x3.png"
    if east_path.exists():
        east_sprite = load_sprite(east_path).resize((26, 41), Image.Resampling.NEAREST)
        east_position = (45 * CELL_SIZE + CELL_SIZE // 2 - east_sprite.width // 2, 48 * CELL_SIZE - east_sprite.height)
        paste_clipped(result, east_sprite, east_position, ridge_mask)
        placements.append({"asset": "blocker_2x3", "cell": [45, 47], "position_px": list(east_position)})

    # A restrained, one-to-two-pixel cold rim makes the standalone texture read
    # as raised bedrock without recreating the old Dual Grid wall face. The rim
    # is clipped to the ridge cells and is never used as collision.
    rim = Image.new("RGBA", OUTPUT_SIZE, (0, 0, 0, 0))
    rim_draw = ImageDraw.Draw(rim)
    for y, row in enumerate(rows):
        for x, semantic in enumerate(row):
            if semantic != "R":
                continue
            left = x * CELL_SIZE
            top = y * CELL_SIZE
            jitter = (x * 13 + y * 7) % 3
            if x == 0 or row[x - 1] != "R":
                rim_draw.line((left + jitter, top, left + jitter, top + CELL_SIZE - 1), fill=(43, 55, 64, 220), width=2)
            if x == MAP_WIDTH - 1 or row[x + 1] != "R":
                rim_draw.line((left + CELL_SIZE - 1 - jitter, top, left + CELL_SIZE - 1 - jitter, top + CELL_SIZE - 1), fill=(43, 55, 64, 220), width=2)
            if y == 0 or rows[y - 1][x] != "R":
                rim_draw.line((left, top + jitter, left + CELL_SIZE - 1, top + jitter), fill=(180, 188, 191, 180), width=1)
            if y == MAP_HEIGHT - 1 or rows[y + 1][x] != "R":
                rim_draw.line((left, top + CELL_SIZE - 1 - jitter, left + CELL_SIZE - 1, top + CELL_SIZE - 1 - jitter), fill=(43, 55, 64, 220), width=2)
    rim.putalpha(ImageChops.multiply(rim.getchannel("A"), ridge_mask))
    result.alpha_composite(rim)

    output.parent.mkdir(parents=True, exist_ok=True)
    manifest.parent.mkdir(parents=True, exist_ok=True)
    result.save(output, format="PNG", optimize=False)
    ridge_cells = sum(row.count("R") for row in rows)
    manifest.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "status": "candidate_deterministic_composite",
                "layout_mask": str(mask_path),
                "layout_mask_sha256": sha256(mask_path),
                "output": str(output),
                "output_size": list(OUTPUT_SIZE),
                "cell_size": CELL_SIZE,
                "ridge_cells": ridge_cells,
                "source_material": str(material_path),
                "source_material_sha256": sha256(material_path),
                "accent_placements": placements,
                "source_accent_assets": [f"assets/maps/map_01/blockers/{name}.png" for name, _ in sprites]
                + (["assets/maps/map_01/blockers/blocker_2x3.png"] if east_path.exists() else []),
                "texture_recipe": "approved v2c opaque interior crop, mirrored low-repeat bedrock fill, deterministic cold rim",
                "purpose": "Standalone visual ridge texture for Map01 D1; collision remains graybox/scene-derived.",
                "meowa_points_spent": 0,
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"MAP01_MOUNTAIN_RIDGE_OK cells={ridge_cells} output={output}")


def main() -> None:
    args = parse_args()
    compose(args.mask, args.output, args.manifest, args.material)


if __name__ == "__main__":
    main()
