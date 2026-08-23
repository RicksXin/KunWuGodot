#!/usr/bin/env python3
"""Compile one user-generated ridge into review-only Map01 candidates.

The source is a candidate master, never a layout or collision source.  This
tool performs only deterministic alpha cleanup, nearest-neighbour sizing,
orientation matching, and a clipped visual review composite.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageOps


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/candidates/map01_mountain_ridge/raw/map01_mountain_ridge_gpt_ne_sw_raw.png"
MASK = ROOT / "art/candidates/map01_layout/map01_d1_environment_mask_20260820.json"
BASE = ROOT / "art/candidates/map01_mountain_ridge/review/map01_d1_landmark_no_ridge_base.png"
OUT = ROOT / "art/candidates/map01_mountain_ridge/compiled"
REVIEW = ROOT / "art/candidates/map01_mountain_ridge/review"
MODULE_SIZE = (96, 96)  # 6 x 6 display cells after the D1 environment scale.
DISPLAY_CELL = 48
DISPLAY_SIZE = (2352, 3120)
MAP_OFFSET = (24, 24)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_hard_alpha(path: Path) -> Image.Image:
    source = Image.open(path).convert("RGBA")
    alpha = source.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    source.putalpha(alpha)
    bbox = alpha.getbbox()
    if bbox is None:
        raise ValueError("ridge candidate has no non-transparent pixels")
    # Keep a small real transparent safety margin around the cropped master.
    margin = 12
    left = max(0, bbox[0] - margin)
    top = max(0, bbox[1] - margin)
    right = min(source.width, bbox[2] + margin)
    bottom = min(source.height, bbox[3] + margin)
    cropped = source.crop((left, top, right, bottom))
    return cropped.resize(MODULE_SIZE, Image.Resampling.NEAREST)


def ridge_mask() -> Image.Image:
    payload = json.loads(MASK.read_text(encoding="utf-8"))
    rows = payload["rows"]
    if len(rows) != 64 or any(len(row) != 48 for row in rows):
        raise ValueError("Map01 D1 mask must be 48x64")
    mask = Image.new("L", DISPLAY_SIZE, 0)
    draw = ImageDraw.Draw(mask)
    for y, row in enumerate(rows):
        for x, value in enumerate(row):
            if value == "R":
                draw.rectangle(
                    (
                        MAP_OFFSET[0] + x * DISPLAY_CELL,
                        MAP_OFFSET[1] + y * DISPLAY_CELL,
                        MAP_OFFSET[0] + (x + 1) * DISPLAY_CELL - 1,
                        MAP_OFFSET[1] + (y + 1) * DISPLAY_CELL - 1,
                    ),
                    fill=255,
                )
    return mask


def clean_old_ridge(base: Image.Image) -> Image.Image:
    """Hide the previous rectangular ridge only in this review composite.

    The formal scene is untouched.  Each old R cell is filled from the nearest
    same-row non-R ground cell so the new candidate can be judged on its own.
    """
    payload = json.loads(MASK.read_text(encoding="utf-8"))
    rows = payload["rows"]
    clean = base.copy()
    for y, row in enumerate(rows):
        for x, value in enumerate(row):
            if value != "R":
                continue
            donor_x = None
            for distance in range(1, 48):
                for candidate_x in (x - distance, x + distance):
                    if 0 <= candidate_x < 48 and rows[y][candidate_x] != "R":
                        donor_x = candidate_x
                        break
                if donor_x is not None:
                    break
            if donor_x is None:
                continue
            target = (MAP_OFFSET[0] + x * DISPLAY_CELL, MAP_OFFSET[1] + y * DISPLAY_CELL)
            donor = (MAP_OFFSET[0] + donor_x * DISPLAY_CELL, MAP_OFFSET[1] + y * DISPLAY_CELL)
            patch = base.crop((donor[0], donor[1], donor[0] + DISPLAY_CELL, donor[1] + DISPLAY_CELL))
            clean.alpha_composite(patch, target)
    return clean


def place_clipped(canvas: Image.Image, module: Image.Image, x: int, y: int, clip: Image.Image) -> None:
    layer = Image.new("RGBA", DISPLAY_SIZE, (0, 0, 0, 0))
    # The source is NW-SE; Map01's central R-band runs NE-SW in screen space.
    oriented = ImageOps.mirror(module)
    display = oriented.resize((MODULE_SIZE[0] * 3, MODULE_SIZE[1] * 3), Image.Resampling.NEAREST)
    layer.alpha_composite(display, (x, y))
    layer.putalpha(ImageChops.multiply(layer.getchannel("A"), clip))
    canvas.alpha_composite(layer)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    REVIEW.mkdir(parents=True, exist_ok=True)
    module = load_hard_alpha(SOURCE)
    module_path = OUT / "map01_mountain_ridge_gpt_ne_sw_compiled_96.png"
    module.save(module_path, format="PNG", optimize=False)

    # A simple three-background contact sheet supports the alpha/scale gate.
    contact = Image.new("RGBA", (960, 360), "#11161b")
    backgrounds = ["#65737a", "#20272d", "#b8b9b2"]
    for index, background in enumerate(backgrounds):
        tile = Image.new("RGBA", (320, 360), background)
        tile.alpha_composite(module.resize((256, 256), Image.Resampling.NEAREST), (32, 48))
        draw = ImageDraw.Draw(tile)
        draw.rectangle((0, 0, 319, 359), outline="#dbe4e2", width=1)
        draw.text((12, 12), ["MAP01", "DARK", "GRAY"][index], fill="#f2efe5")
        contact.alpha_composite(tile, (index * 320, 0))
    contact_path = REVIEW / "map01_mountain_ridge_gpt_ne_sw_contact_sheet.png"
    contact.save(contact_path, format="PNG", optimize=False)

    base = Image.open(BASE).convert("RGBA")
    if base.size != DISPLAY_SIZE:
        raise ValueError(f"Unexpected D1 overview size: {base.size}")
    clip = ridge_mask()
    # The base was captured from Godot with the previous ridge layer hidden.
    clean_base = base.copy()
    clean_base_path = REVIEW / "map01_d1_mountain_ridge_gpt_clean_base_unverified.png"
    clean_base.save(clean_base_path, format="PNG", optimize=False)
    composite = clean_base.copy()
    # Candidate review anchors only; they do not freeze object coordinates.
    anchors = [(14, 29), (15, 34), (16, 39), (13, 44), (12, 49), (11, 53)]
    for cell_x, cell_y in anchors:
        place_clipped(
            composite,
            module,
            MAP_OFFSET[0] + cell_x * DISPLAY_CELL - 60,
            MAP_OFFSET[1] + cell_y * DISPLAY_CELL - 48,
            clip,
        )
    composite_path = REVIEW / "map01_d1_mountain_ridge_gpt_ne_sw_overlay_unverified.png"
    composite.save(composite_path, format="PNG", optimize=False)

    manifest_path = OUT / "map01_mountain_ridge_gpt_ne_sw_candidate_manifest.json"
    manifest_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "status": "candidate_review_only",
                "supplier": "ChatGPT, user-executed",
                "source": str(SOURCE),
                "source_sha256": sha256(SOURCE),
                "source_size_px": list(Image.open(SOURCE).size),
                "compiled_module": str(module_path),
                "compiled_size_px": list(MODULE_SIZE),
                "alpha_policy": "hard threshold at 128; transparent safety margin; nearest resize",
                "orientation_policy": "horizontal mirror in review to match Map01 central R-band",
                "layout_mask": str(MASK),
                "review_base": str(BASE),
                "review_anchors_cells": [list(anchor) for anchor in anchors],
                "collision_source": "graybox mask only; candidate image does not author collision",
                "formal_scene_modified": False,
                "runtime_asset": False,
                "meowa_points_spent": 0,
                "clean_base": str(clean_base_path),
                "outputs": [str(module_path), str(contact_path), str(clean_base_path), str(composite_path)],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"MAP01_MOUNTAIN_RIDGE_GPT_CANDIDATE_OK module={module_path} review={composite_path}")


if __name__ == "__main__":
    main()
