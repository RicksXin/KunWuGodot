#!/usr/bin/env python3
"""Compile the existing high-detail Shi Yan punch sheet for visual comparison.

This is a local, no-cost review fallback. It never overwrites the old D0 asset or
the Meowa candidate and is not approved for runtime because the source contains
the historical palm-light pixels inside the character sheet. The output is useful
for deciding the target sharpness and palm-light language before a new animation
batch is authorized.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source_archive/cultivators/shi_yan/shi_yan_cast_a_source_sheet.png"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/compiled"
OUTPUT = OUTPUT_DIR / "shi_yan_cast_a_crisp_fallback_sheet.png"
MANIFEST = OUTPUT_DIR / "crisp_fallback_manifest.json"
FRAME_SIZE = (86, 205)
GRID = (4, 2)
CELL_X = (0, 154, 307, 461, 615)
CELL_Y = (0, 231, 462)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing existing Shi Yan punch sheet: {SOURCE}")
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (615, 462):
        raise SystemExit(f"unexpected source size: {source.size}")

    frames: list[Image.Image] = []
    bounds: list[tuple[int, int, int, int]] = []
    for index in range(8):
        frame = source.crop((CELL_X[index % 4], CELL_Y[index // 4], CELL_X[index % 4 + 1], CELL_Y[index // 4 + 1]))
        bbox = frame.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"frame {index} is empty")
        frames.append(frame)
        bounds.append(bbox)

    shared = (
        min(bbox[0] for bbox in bounds),
        min(bbox[1] for bbox in bounds),
        max(bbox[2] for bbox in bounds),
        max(bbox[3] for bbox in bounds),
    )
    shared_size = (shared[2] - shared[0], shared[3] - shared[1])
    scale = min((FRAME_SIZE[0] - 4) / shared_size[0], (FRAME_SIZE[1] - 4) / shared_size[1])
    scaled = (max(1, round(shared_size[0] * scale)), max(1, round(shared_size[1] * scale)))

    compiled: list[Image.Image] = []
    for frame in frames:
        crop = frame.crop(shared).resize(scaled, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(crop, ((FRAME_SIZE[0] - scaled[0]) // 2, 2))
        compiled.append(canvas)

    sheet = Image.new("RGBA", (FRAME_SIZE[0] * GRID[0], FRAME_SIZE[1] * GRID[1]), (0, 0, 0, 0))
    for index, frame in enumerate(compiled):
        sheet.alpha_composite(frame, ((index % GRID[0]) * FRAME_SIZE[0], (index // GRID[0]) * FRAME_SIZE[1]))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT, optimize=True)
    MANIFEST.write_text(
        json.dumps(
            {
                "asset_id": "combat_ally_shi_yan_cast_a_crisp_fallback",
                "stage": "review_only",
                "provider": "existing approved D0 punch sheet + local deterministic compile",
                "source_path": str(SOURCE.relative_to(ROOT)),
                "source_canvas": list(source.size),
                "shared_source_bounds": list(shared),
                "runtime_frame_size": list(FRAME_SIZE),
                "grid": list(GRID),
                "runtime_sheet_size": [sheet.width, sheet.height],
                "fps": 10,
                "loop": False,
                "hit_frame": 4,
                "contains_historical_palm_light": True,
                "approved_for_runtime": False,
                "output_path": str(OUTPUT.relative_to(ROOT)),
                "output_sha256": _sha256(OUTPUT),
                "compiled_on": date.today().isoformat(),
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"compiled={OUTPUT}")
    print(f"manifest={MANIFEST}")
    print(f"shared_bounds={shared} scaled_size={scaled}")


if __name__ == "__main__":
    main()
