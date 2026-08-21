#!/usr/bin/env python3
"""Build traceable 64px texture inputs for the Map01 Meowa tileset pilot."""

from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent.parent
OUTPUT_DIR = ROOT / "art/candidates/map01_meowa_mountain_tileset/inputs"

SAMPLES = (
    {
        "id": "background_ground_64",
        "role": "preview_background_only",
        "source": ROOT / "assets/compiled/tilemapdual_standard.png",
        "box": (512, 256, 768, 512),
        "output_size": (64, 64),
    },
    {
        "id": "foreground_graywhite_bedrock_64_chatgpt_v1",
        "role": "foreground_texture",
        "source": ROOT
        / "art/candidates/map01_meowa_mountain_tileset/inputs/chatgpt_v1/map01_graywhite_bedrock_64_v1.png",
        "box": (0, 0, 64, 64),
        "output_size": (64, 64),
    },
)


def validate_sample(image: Image.Image, sample: dict[str, object]) -> None:
    box = sample["box"]
    assert isinstance(box, tuple)
    left, top, right, bottom = box
    if right <= left or bottom <= top:
        raise ValueError(f"{sample['id']} crop must have positive dimensions: {box}")
    if left < 0 or top < 0 or right > image.width or bottom > image.height:
        raise ValueError(f"{sample['id']} crop exceeds {image.size}: {box}")


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    records: list[dict[str, object]] = []
    previews: list[tuple[str, Image.Image]] = []

    for sample in SAMPLES:
        source = Path(sample["source"])
        image = Image.open(source).convert("RGBA")
        validate_sample(image, sample)
        crop = image.crop(sample["box"])
        output_size = sample["output_size"]
        assert isinstance(output_size, tuple)
        if crop.size != output_size:
            crop = crop.resize(output_size, Image.Resampling.NEAREST)
        output = OUTPUT_DIR / f"{sample['id']}.png"
        crop.save(output)
        repeated = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
        for row in range(4):
            for column in range(4):
                repeated.alpha_composite(crop, (column * 64, row * 64))
        previews.append((str(sample["id"]), repeated))
        records.append(
            {
                "id": sample["id"],
                "role": sample["role"],
                "source": str(source.relative_to(ROOT)),
                "source_size": list(image.size),
                "crop_box": list(sample["box"]),
                "source_crop_size": [
                    sample["box"][2] - sample["box"][0],
                    sample["box"][3] - sample["box"][1],
                ],
                "output": str(output.relative_to(ROOT)),
                "output_size": [64, 64],
            }
        )

    label_height = 36
    rows = (len(previews) + 1) // 2
    sheet = Image.new("RGB", (512, (256 + label_height) * rows), (28, 34, 39))
    draw = ImageDraw.Draw(sheet)
    for index, (label, preview) in enumerate(previews):
        column = index % 2
        row = index // 2
        x = column * 256
        y = row * (256 + label_height)
        sheet.paste(preview.convert("RGB"), (x, y))
        draw.text((x + 8, y + 264), label, fill=(232, 236, 238))
    sheet_path = OUTPUT_DIR / "map01_meowa_texture_input_contact_sheet.png"
    sheet.save(sheet_path)

    manifest = {
        "purpose": "Map01 foreground-only mountain Dual Grid tileset pilot; approved ground is preview context only",
        "status": "foreground_input_ready_pending_credit_approval",
        "samples": records,
        "contact_sheet": str(sheet_path.relative_to(ROOT)),
        "meowa_submission": {
            "command": "tileset-gen-run",
            "terrain_mode": "foreground",
            "foreground_texture": "art/candidates/map01_meowa_mountain_tileset/inputs/foreground_graywhite_bedrock_64_chatgpt_v1.png",
            "background_texture": None,
            "remove_bg_method": "standard",
            "prompt": None,
        },
    }
    manifest_path = OUTPUT_DIR / "map01_meowa_texture_input_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(sheet_path)
    print(manifest_path)


if __name__ == "__main__":
    main()
