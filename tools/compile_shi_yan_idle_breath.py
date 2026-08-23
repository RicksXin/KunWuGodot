#!/usr/bin/env python3
"""Compile the anchored Shi Yan breathing candidate to the Godot runtime grid.

This is a local deterministic step.  It reads the eight anchored 362x543
candidate frames, derives one shared content crop and one scale for the whole
animation, then emits 86x205 frames and the fixed 4x2 344x410 atlas required by
the current combat-character contract.  Nearest sampling is intentional for
the current pixel-runtime candidate; the source-resolution atlas remains the
review fallback.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0"
OUTPUT_DIR = SOURCE_DIR / "compiled"
FRAME_SIZE = (86, 205)
GRID = (4, 2)
SAFE_MARGIN_X = 2
TOP_OFFSET = 4
FPS = 8
PREVIEW_SCALE = 3


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    frame_paths = [SOURCE_DIR / f"shi_yan_idle_breath_{index:02d}_362x543.png" for index in range(8)]
    missing = [str(path) for path in frame_paths if not path.is_file()]
    if missing:
        raise SystemExit("missing anchored candidate frame(s): " + ", ".join(missing))

    frames = [Image.open(path).convert("RGBA") for path in frame_paths]
    bounds = [frame.getchannel("A").getbbox() for frame in frames]
    if any(bound is None for bound in bounds):
        raise SystemExit("one or more candidate frames are empty")

    typed_bounds = [bound for bound in bounds if bound is not None]
    shared_bounds = (
        min(bound[0] for bound in typed_bounds),
        min(bound[1] for bound in typed_bounds),
        max(bound[2] for bound in typed_bounds),
        max(bound[3] for bound in typed_bounds),
    )
    shared_width = shared_bounds[2] - shared_bounds[0]
    shared_height = shared_bounds[3] - shared_bounds[1]
    safe_width = FRAME_SIZE[0] - SAFE_MARGIN_X * 2
    scale = min(safe_width / shared_width, (FRAME_SIZE[1] - TOP_OFFSET) / shared_height)
    scaled_size = (
        max(1, round(shared_width * scale)),
        max(1, round(shared_height * scale)),
    )

    compiled_frames: list[Image.Image] = []
    for frame in frames:
        crop = frame.crop(shared_bounds).resize(scaled_size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(crop, ((FRAME_SIZE[0] - scaled_size[0]) // 2, TOP_OFFSET))
        compiled_frames.append(canvas)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    frame_outputs: list[str] = []
    for index, frame in enumerate(compiled_frames):
        filename = f"shi_yan_idle_breath_{index:02d}_86x205.png"
        frame.save(OUTPUT_DIR / filename, optimize=True)
        frame_outputs.append(filename)

    sheet = Image.new("RGBA", (FRAME_SIZE[0] * GRID[0], FRAME_SIZE[1] * GRID[1]), (0, 0, 0, 0))
    for index, frame in enumerate(compiled_frames):
        sheet.alpha_composite(frame, ((index % GRID[0]) * FRAME_SIZE[0], (index // GRID[0]) * FRAME_SIZE[1]))
    sheet_path = OUTPUT_DIR / "shi_yan_idle_breath_sheet_344x410.png"
    sheet.save(sheet_path, optimize=True)

    preview_frames = [
        frame.resize(
            (FRAME_SIZE[0] * PREVIEW_SCALE, FRAME_SIZE[1] * PREVIEW_SCALE),
            Image.Resampling.NEAREST,
        )
        for frame in compiled_frames
    ]
    preview_path = OUTPUT_DIR / "shi_yan_idle_breath_preview_3x_8fps.png"
    preview_frames[0].save(
        preview_path,
        save_all=True,
        append_images=preview_frames[1:],
        duration=[round(1000 / FPS)] * len(preview_frames),
        loop=0,
        disposal=[0] * len(preview_frames),
        blend=[0] * len(preview_frames),
        optimize=True,
    )

    manifest = {
        "asset_id": "combat_ally_shi_yan_idle_breath_candidate",
        "stage": "candidate_compiled",
        "provider": "local deterministic compile from user-provided breathing atlas",
        "source_dir": str(SOURCE_DIR.relative_to(ROOT)),
        "source_frame_count": len(frames),
        "source_frame_size": [frames[0].width, frames[0].height],
        "shared_source_bounds": list(shared_bounds),
        "scale": round(scale, 8),
        "scaled_content_size": list(scaled_size),
        "runtime_frame_size": list(FRAME_SIZE),
        "grid": list(GRID),
        "runtime_sheet_size": [sheet.width, sheet.height],
        "resampling": "nearest",
        "top_offset": TOP_OFFSET,
        "safe_margin_x": SAFE_MARGIN_X,
        "fps": FPS,
        "loop": True,
        "frame_outputs": frame_outputs,
        "sheet_output": sheet_path.name,
        "sheet_sha256": sha256(sheet_path),
        "review_preview": {
            "output": preview_path.name,
            "size": [preview_frames[0].width, preview_frames[0].height],
            "integer_scale": PREVIEW_SCALE,
            "resampling": "nearest",
            "format": "animated lossless PNG (APNG)",
            "frame_duration_ms": round(1000 / FPS),
            "sha256": sha256(preview_path),
        },
        "approved_for_runtime": False,
        "compiled_on": date.today().isoformat(),
    }
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(f"compiled={sheet_path}")
    print(f"manifest={OUTPUT_DIR / 'manifest.json'}")
    print(f"shared_bounds={shared_bounds} scale={scale:.8f} scaled_size={scaled_size}")


if __name__ == "__main__":
    main()
