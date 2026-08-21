#!/usr/bin/env python3
"""Compile the approved high-detail keyframes Job into a runtime-size candidate."""

from __future__ import annotations

from collections import deque
from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
JOB_ROOT = ROOT / (
    "art/source_archive/meowa/combat_ally_shi_yan_cast_a_high_detail_keyframes/2026-08-21/"
    "Keep_Shi_Yan_s_approved_identity_outfit_bald_head_prayer_beads_and_broad_grounded_stance_"
    "Use_the_supplied_fram_0f186b0a"
)
SOURCE = JOB_ROOT / "result_output_url.webp"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/compiled"
OUTPUT = OUTPUT_DIR / "shi_yan_cast_a_high_detail_sheet.png"
MANIFEST = OUTPUT_DIR / "high_detail_manifest.json"
FRAME_SIZE = (86, 205)
GRID = (4, 2)
SAFE_MARGIN_X = 2
TOP_OFFSET = 4


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _near_transparent(pixel: tuple[int, int, int, int]) -> bool:
    return pixel[3] == 0


def _remove_border_transparent_only(image: Image.Image) -> Image.Image:
    """Keep the service alpha intact; this only normalizes border-connected alpha=0."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    removed: set[tuple[int, int]] = set()
    pending: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if not (0 <= x < width and 0 <= y < height):
            return
        if (x, y) in removed or not _near_transparent(pixels[x, y]):
            return
        removed.add((x, y))
        pending.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)
    while pending:
        x, y = pending.popleft()
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            enqueue(nx, ny)
    return image


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing keyframes Job output: {SOURCE}")
    animated = Image.open(SOURCE)
    if int(getattr(animated, "n_frames", 1)) != 8:
        raise SystemExit(f"expected 8 source frames, got {getattr(animated, 'n_frames', 1)}")

    frames: list[Image.Image] = []
    bounds: list[tuple[int, int, int, int]] = []
    for index in range(8):
        animated.seek(index)
        frame = _remove_border_transparent_only(animated.convert("RGBA"))
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
    scale = min((FRAME_SIZE[0] - SAFE_MARGIN_X * 2) / shared_size[0], (FRAME_SIZE[1] - TOP_OFFSET) / shared_size[1])
    scaled_size = (max(1, round(shared_size[0] * scale)), max(1, round(shared_size[1] * scale)))

    compiled: list[Image.Image] = []
    for frame in frames:
        crop = frame.crop(shared).resize(scaled_size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(crop, ((FRAME_SIZE[0] - scaled_size[0]) // 2, TOP_OFFSET))
        compiled.append(canvas)

    sheet = Image.new("RGBA", (FRAME_SIZE[0] * GRID[0], FRAME_SIZE[1] * GRID[1]), (0, 0, 0, 0))
    for index, frame in enumerate(compiled):
        sheet.alpha_composite(frame, ((index % GRID[0]) * FRAME_SIZE[0], (index // GRID[0]) * FRAME_SIZE[1]))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT, optimize=True)
    manifest = {
        "asset_id": "combat_ally_shi_yan_cast_a_high_detail",
        "stage": "candidate_compiled",
        "provider": "Meowa keyframes-run + local deterministic compile",
        "source_job_id": "job_0f0b2692ba7a4de5b79022dba67d66be",
        "source_path": str(SOURCE.relative_to(ROOT)),
        "source_frame_count": 8,
        "source_canvas": [128, 256],
        "shared_source_bounds": list(shared),
        "runtime_frame_size": list(FRAME_SIZE),
        "grid": list(GRID),
        "runtime_sheet_size": [sheet.width, sheet.height],
        "fps": 10,
        "loop": False,
        "hit_frame": 4,
        "output_path": str(OUTPUT.relative_to(ROOT)),
        "output_sha256": _sha256(OUTPUT),
        "approved_for_runtime": False,
        "compiled_on": date.today().isoformat(),
    }
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"compiled={OUTPUT}")
    print(f"manifest={MANIFEST}")
    print(f"source_frames=8 shared_bounds={shared} scaled_size={scaled_size}")


if __name__ == "__main__":
    main()
