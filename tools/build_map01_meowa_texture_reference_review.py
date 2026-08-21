#!/usr/bin/env python3
"""Build a repeat-seam review sheet for free Meowa 64px texture references."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageStat


ROOT = Path(__file__).resolve().parent.parent
REFERENCE_ROOT = ROOT / "art/candidates/map01_meowa_mountain_tileset/reference_library"
OUTPUT_ROOT = ROOT / "art/candidates/map01_meowa_mountain_tileset/review"

REFERENCES = (
    ("cliff_top", REFERENCE_ROOT / "cliff_top/01_terrain_rock_cliff_top.png"),
    ("rock_mountain", REFERENCE_ROOT / "rock_mountain/01_terrain_rock_mountain.png"),
    ("stone_plain", REFERENCE_ROOT / "stone_plain/01_stone_plain.png"),
    ("stone_cracked", REFERENCE_ROOT / "stone_cracked/01_stone_cracked.png"),
    ("wall_cave_rock", REFERENCE_ROOT / "wall_cave_rock/01_wall_cave_rock.png"),
    ("rock_gravel", REFERENCE_ROOT / "rock_gravel/01_terrain_rock_gravel.png"),
    ("dirt_rocky", REFERENCE_ROOT / "dirt_rocky/01_dirt_rocky.png"),
    ("mine_floor", REFERENCE_ROOT / "mine_floor/01_terrain_rock_mine_floor.png"),
    ("minimal_cave", REFERENCE_ROOT / "minimal_cave/01_minimal_cave.png"),
    ("broken_small_rocks", REFERENCE_ROOT / "broken_small_rocks/01_破碎小石块.png"),
)


def edge_mismatch(image: Image.Image) -> tuple[float, float]:
    rgb = image.convert("RGB")
    left = list(rgb.crop((0, 0, 1, 64)).get_flattened_data())
    right = list(rgb.crop((63, 0, 64, 64)).get_flattened_data())
    top = list(rgb.crop((0, 0, 64, 1)).get_flattened_data())
    bottom = list(rgb.crop((0, 63, 64, 64)).get_flattened_data())

    def mean_channel_delta(first: list[tuple[int, int, int]], second: list[tuple[int, int, int]]) -> float:
        total = sum(abs(a - b) for pixel_a, pixel_b in zip(first, second) for a, b in zip(pixel_a, pixel_b))
        return total / (len(first) * 3)

    return mean_channel_delta(left, right), mean_channel_delta(top, bottom)


def repeat_texture(image: Image.Image, columns: int = 4, rows: int = 4) -> Image.Image:
    repeated = Image.new("RGBA", (image.width * columns, image.height * rows), (0, 0, 0, 0))
    for row in range(rows):
        for column in range(columns):
            repeated.alpha_composite(image, (column * image.width, row * image.height))
    return repeated


def main() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    panel_size = 256
    label_height = 34
    columns = 5
    rows = 2
    sheet = Image.new("RGB", (panel_size * columns, (panel_size + label_height) * rows), (25, 31, 36))
    draw = ImageDraw.Draw(sheet)
    records: list[dict[str, object]] = []

    for index, (name, path) in enumerate(REFERENCES):
        source_bytes = path.read_bytes()
        image = Image.open(path).convert("RGBA")
        if image.size != (64, 64):
            raise ValueError(f"{path} must be exactly 64x64, got {image.size}")
        alpha_extrema = image.getchannel("A").getextrema()
        repeated = repeat_texture(image)
        repeated_path = OUTPUT_ROOT / f"{name}_repeat_4x4.png"
        repeated.save(repeated_path)

        column = index % columns
        row = index // columns
        x = column * panel_size
        y = row * (panel_size + label_height)
        sheet.paste(repeated.convert("RGB"), (x, y))
        draw.text((x + 8, y + panel_size + 9), name, fill=(235, 239, 241))

        mismatch_x, mismatch_y = edge_mismatch(image)
        stat = ImageStat.Stat(image.convert("RGB"))
        records.append(
            {
                "name": name,
                "source": str(path.relative_to(ROOT)),
                "sha256": hashlib.sha256(source_bytes).hexdigest(),
                "size": [64, 64],
                "alpha_extrema": list(alpha_extrema),
                "mean_rgb": [round(channel, 2) for channel in stat.mean],
                "edge_mismatch_x": round(mismatch_x, 3),
                "edge_mismatch_y": round(mismatch_y, 3),
                "repeat_preview": str(repeated_path.relative_to(ROOT)),
            }
        )

    sheet_path = OUTPUT_ROOT / "map01_meowa_rock_reference_repeat_contact_sheet.png"
    sheet.save(sheet_path)
    manifest_path = OUTPUT_ROOT / "map01_meowa_rock_reference_review.json"
    manifest_path.write_text(
        json.dumps(
            {
                "status": "free_reference_input_review",
                "supplier": "Meowa official texture reference library",
                "generated_assets": False,
                "credits_spent": 0,
                "references": records,
                "contact_sheet": str(sheet_path.relative_to(ROOT)),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(sheet_path)
    print(manifest_path)


if __name__ == "__main__":
    main()
