"""Compile a half-cell-aligned windmill master into a reusable Dual Grid atlas.

The master is a 4x4 logical terrain grid. Each exported visual tile is centered
on a logical-grid intersection and selected by its NW/NE/SW/SE 4-bit mask.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw


BIT_ORDER = {"nw": 1, "ne": 2, "sw": 4, "se": 8}
DEFAULT_LOGIC_GRID = [
    [0, 1, 0, 0],
    [0, 1, 1, 1],
    [1, 1, 1, 0],
    [0, 0, 1, 0],
]


def terrain_mask(grid: list[list[int]], visual_x: int, visual_y: int) -> int:
    def get(row: int, col: int) -> int:
        return grid[row][col] if 0 <= row < len(grid) and 0 <= col < len(grid[0]) else 0

    return (
        get(visual_y - 1, visual_x - 1) * BIT_ORDER["nw"]
        + get(visual_y - 1, visual_x) * BIT_ORDER["ne"]
        + get(visual_y, visual_x - 1) * BIT_ORDER["sw"]
        + get(visual_y, visual_x) * BIT_ORDER["se"]
    )


def sample_window(master: Image.Image, x: int, y: int, tile: int, background: tuple[int, int, int, int]) -> Image.Image:
    result = Image.new("RGBA", (tile, tile), background)
    left, top = x - tile // 2, y - tile // 2
    src_left, src_top = max(0, left), max(0, top)
    src_right, src_bottom = min(master.width, left + tile), min(master.height, top + tile)
    result.alpha_composite(master.crop((src_left, src_top, src_right, src_bottom)), (src_left - left, src_top - top))
    return result


def normalize_background(master: Image.Image, mode: str, tolerance: int) -> tuple[Image.Image, tuple[int, int, int, int]]:
    """Return a master with an explicit background contract.

    ``transparent`` expects the source already to contain alpha outside terrain.
    ``sample`` preserves the top-left source color as a baked base layer.
    ``key-top-left`` removes pixels matching the top-left color within tolerance;
    use it only for a flat, known background, never for a terrain with a similar
    border color.
    """
    if mode == "sample":
        return master, master.getpixel((0, 0))
    if mode == "transparent":
        return master, (0, 0, 0, 0)

    key = master.getpixel((0, 0))
    pixels = master.load()
    for y in range(master.height):
        for x in range(master.width):
            pixel = pixels[x, y]
            if all(abs(pixel[channel] - key[channel]) <= tolerance for channel in range(3)):
                pixels[x, y] = (pixel[0], pixel[1], pixel[2], 0)
    return master, (0, 0, 0, 0)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("master", type=Path)
    parser.add_argument("--out-dir", type=Path, required=True)
    parser.add_argument("--tile-size", type=int, default=256)
    parser.add_argument(
        "--background-mode",
        choices=("transparent", "sample", "key-top-left"),
        default="transparent",
        help="transparent: preserve source alpha; sample: retain top-left base color; key-top-left: key a flat top-left background.",
    )
    parser.add_argument("--background-tolerance", type=int, default=8)
    args = parser.parse_args()

    master = Image.open(args.master).convert("RGBA")
    tile = args.tile_size
    if master.size != (tile * 4, tile * 4):
        raise SystemExit(f"Expected a {tile * 4}x{tile * 4} master, received {master.width}x{master.height}.")

    master, background = normalize_background(master, args.background_mode, args.background_tolerance)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    samples: dict[int, Image.Image] = {}
    positions: dict[int, tuple[int, int]] = {}
    for visual_y in range(5):
        for visual_x in range(5):
            mask = terrain_mask(DEFAULT_LOGIC_GRID, visual_x, visual_y)
            if mask and mask not in samples:
                samples[mask] = sample_window(master, visual_x * tile, visual_y * tile, tile, background)
                positions[mask] = (visual_x, visual_y)

    # The chosen windmill has no diagonal-only intersections. Build those two
    # masks from the corresponding single-corner quadrants with a clear gap.
    for mask, bits in {6: (2, 4), 9: (1, 8)}.items():
        output = Image.new("RGBA", (tile, tile), background)
        quadrants = {1: (0, 0), 2: (1, 0), 4: (0, 1), 8: (1, 1)}
        for bit in bits:
            x, y = quadrants[bit]
            box = (x * tile // 2, y * tile // 2, (x + 1) * tile // 2, (y + 1) * tile // 2)
            output.alpha_composite(samples[bit].crop(box), box[:2])
        samples[mask] = output

    atlas = Image.new("RGBA", (tile * 5, tile * 3), background)
    for index, mask in enumerate(range(1, 16)):
        atlas.alpha_composite(samples[mask], ((index % 5) * tile, (index // 5) * tile))
    atlas_path = args.out_dir / "dual_grid_15piece.png"
    atlas.save(atlas_path)

    inspection = atlas.copy()
    draw = ImageDraw.Draw(inspection)
    for i in range(1, 5):
        draw.line((i * tile, 0, i * tile, tile * 3), fill=(255, 255, 255, 230), width=3)
    for i in range(1, 3):
        draw.line((0, i * tile, tile * 5, i * tile), fill=(255, 255, 255, 230), width=3)
    for index, mask in enumerate(range(1, 16)):
        x, y = (index % 5) * tile + 10, (index // 5) * tile + 10
        draw.rectangle((x - 4, y - 4, x + 62, y + 32), fill=(0, 0, 0, 175))
        draw.text((x, y), f"0x{mask:X}", fill="white")
    inspection_path = args.out_dir / "dual_grid_15piece_check.png"
    inspection.save(inspection_path)

    manifest = {
        "schema_version": 1,
        "system": "dual_grid_15piece",
        "master_source": str(args.master),
        "master_size_px": list(master.size),
        "tile_size_px": tile,
        "background_mode": args.background_mode,
        "atlas_size_px": list(atlas.size),
        "atlas_layout": {"columns": 5, "rows": 3, "order": "row-major masks 0x1 through 0xF"},
        "bit_order": BIT_ORDER,
        "empty_mask": 0,
        "logic_grid_rows_top_to_bottom": DEFAULT_LOGIC_GRID,
        "sampled_masks": sorted(positions),
        "synthesized_diagonal_masks": [6, 9],
        "integration": "TileMapDual: draw the fully-filled world tile; its display layer selects these 15 masks automatically.",
        "acceptance_required": ["Godot runtime placement screenshot", "edge seam inspection", "0x6 and 0x9 remain disconnected"],
    }
    (args.out_dir / "dual_grid_15piece_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(atlas_path)


if __name__ == "__main__":
    main()
