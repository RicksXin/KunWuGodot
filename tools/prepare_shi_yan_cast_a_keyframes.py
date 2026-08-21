#!/usr/bin/env python3
"""Prepare fixed-canvas keyframes for the approved Shi Yan Cast A retry.

This is a local deterministic step. It does not call Meowa. The existing
high-detail punch sheet supplies frame 0 (ready), frame 4 (impact reference),
and frame 7 (recovery/return). All three outputs share one crop, scale, and
anchor on a 128×256 transparent canvas so keyframes-run can constrain timing.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source_archive/cultivators/shi_yan/shi_yan_cast_a_source_sheet.png"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/keyframes"
MANIFEST = OUTPUT_DIR / "manifest.json"
OUTPUT_SIZE = (128, 256)
CELL_X = (0, 154, 307, 461, 615)
CELL_Y = (0, 231, 462)
KEYFRAMES = (0, 4, 7)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing source punch sheet: {SOURCE}")
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (615, 462):
        raise SystemExit(f"unexpected source size: {source.size}")

    frames: dict[int, Image.Image] = {}
    bounds: dict[int, tuple[int, int, int, int]] = {}
    for index in KEYFRAMES:
        frame = source.crop((CELL_X[index % 4], CELL_Y[index // 4], CELL_X[index % 4 + 1], CELL_Y[index // 4 + 1]))
        bbox = frame.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"keyframe {index} is empty")
        frames[index] = frame
        bounds[index] = bbox

    shared = (
        min(bbox[0] for bbox in bounds.values()),
        min(bbox[1] for bbox in bounds.values()),
        max(bbox[2] for bbox in bounds.values()),
        max(bbox[3] for bbox in bounds.values()),
    )
    shared_size = (shared[2] - shared[0], shared[3] - shared[1])
    # Keep generous transparent motion space but let the subject use the
    # high-detail source canvas instead of shrinking it to the old 86px input.
    scale = min((OUTPUT_SIZE[0] - 8) / shared_size[0], (OUTPUT_SIZE[1] - 8) / shared_size[1])
    scaled_size = (max(1, round(shared_size[0] * scale)), max(1, round(shared_size[1] * scale)))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    outputs: dict[str, dict[str, object]] = {}
    for index in KEYFRAMES:
        crop = frames[index].crop(shared).resize(scaled_size, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", OUTPUT_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(crop, ((OUTPUT_SIZE[0] - scaled_size[0]) // 2, 4))
        output = OUTPUT_DIR / f"shi_yan_cast_a_keyframe_{index}_128x256.png"
        canvas.save(output, optimize=True)
        outputs[str(index)] = {
            "path": str(output.relative_to(ROOT)),
            "size": list(canvas.size),
            "sha256": _sha256(output),
            "source_bbox": list(bounds[index]),
        }

    manifest = {
        "asset_id": "combat_ally_shi_yan_cast_a_high_detail_keyframes",
        "stage": "candidate_keyframes",
        "provider": "existing high-detail punch sheet + local deterministic preparation",
        "source_path": str(SOURCE.relative_to(ROOT)),
        "source_canvas": list(source.size),
        "keyframe_indices": list(KEYFRAMES),
        "shared_source_bounds": list(shared),
        "shared_scaled_size": list(scaled_size),
        "canvas": list(OUTPUT_SIZE),
        "contains_historical_palm_light_in_frame_4_reference": True,
        "runtime_approved": False,
        "prepared_on": date.today().isoformat(),
        "outputs": outputs,
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"manifest={MANIFEST}")
    print(f"shared_bounds={shared} scaled_size={scaled_size}")
    for index in KEYFRAMES:
        print(f"keyframe_{index}={outputs[str(index)]['path']}")


if __name__ == "__main__":
    main()
