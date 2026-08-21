#!/usr/bin/env python3
"""Compile the approved Meowa Cast A candidate into a reviewed local sheet.

The Meowa job returned an 8-frame 128×256 animation with an opaque gray matte.
This compiler removes only border-connected matte pixels, keeps one shared crop
and scale for all frames, and emits a candidate 4×2 86×205 sheet. It never writes
to res://assets and never calls Meowa.
"""

from __future__ import annotations

from collections import deque
from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
JOB_ROOT = ROOT / (
    "art/source_archive/meowa/combat_ally_shi_yan_cast_a_retry_128x256/2026-08-21/"
    "Keep_Shi_Yan_s_approved_identity_outfit_bald_head_prayer_beads_and_broad_grounded_stance_"
    "Create_one_short_one-_5304ee83"
)
SOURCE = JOB_ROOT / "result_output_url.webp"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/compiled"
OUTPUT = OUTPUT_DIR / "shi_yan_cast_a_sheet.png"
MANIFEST = OUTPUT_DIR / "manifest.json"

FRAME_SIZE = (86, 205)
GRID = (4, 2)
SAFE_MARGIN_X = 2
TOP_OFFSET = 4
MATTE = (98, 98, 98)
MATTE_TOLERANCE = 52
MATTE_CHROMA_TOLERANCE = 34


def _near_matte(pixel: tuple[int, int, int, int]) -> bool:
    red, green, blue, alpha = pixel
    if alpha == 0:
        return True
    distance = max(abs(red - MATTE[0]), abs(green - MATTE[1]), abs(blue - MATTE[2]))
    chroma = max(red, green, blue) - min(red, green, blue)
    return distance <= MATTE_TOLERANCE and chroma <= MATTE_CHROMA_TOLERANCE


def _remove_border_matte(image: Image.Image) -> Image.Image:
    """Remove gray pixels connected to the canvas border using hard alpha."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    removed: set[tuple[int, int]] = set()
    pending: deque[tuple[int, int]] = deque()

    def enqueue(x: int, y: int) -> None:
        if not (0 <= x < width and 0 <= y < height):
            return
        if (x, y) in removed or not _near_matte(pixels[x, y]):
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

    output = image.copy()
    output_pixels = output.load()
    for x, y in removed:
        red, green, blue, _alpha = output_pixels[x, y]
        output_pixels[x, y] = (red, green, blue, 0)
    return output


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing Meowa source animation: {SOURCE}")

    animated = Image.open(SOURCE)
    frame_count = int(getattr(animated, "n_frames", 1))
    if frame_count != 8:
        raise SystemExit(f"expected 8 source frames, got {frame_count}")

    frames: list[Image.Image] = []
    bounds: list[tuple[int, int, int, int]] = []
    for index in range(frame_count):
        animated.seek(index)
        frame = _remove_border_matte(animated.convert("RGBA"))
        bbox = frame.getchannel("A").getbbox()
        if bbox is None:
            raise SystemExit(f"frame {index} is empty after gray-matte removal")
        frames.append(frame)
        bounds.append(bbox)

    shared_bounds = (
        min(bound[0] for bound in bounds),
        min(bound[1] for bound in bounds),
        max(bound[2] for bound in bounds),
        max(bound[3] for bound in bounds),
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
        crop = frame.crop(shared_bounds)
        # Meowa pixel output is already pixel-art. Nearest preserves hard
        # clusters while fitting the approved Godot runtime canvas.
        crop = crop.resize(scaled_size, Image.Resampling.NEAREST)
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        x = (FRAME_SIZE[0] - scaled_size[0]) // 2
        canvas.alpha_composite(crop, (x, TOP_OFFSET))
        compiled_frames.append(canvas)

    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID[0], FRAME_SIZE[1] * GRID[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(compiled_frames):
        sheet.alpha_composite(
            frame,
            ((index % GRID[0]) * FRAME_SIZE[0], (index // GRID[0]) * FRAME_SIZE[1]),
        )

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(OUTPUT, optimize=True)
    manifest = {
        "asset_id": "combat_ally_shi_yan_cast_a_pilot",
        "stage": "candidate_compiled",
        "provider": "Meowa animate-run + local deterministic compile",
        "source_job_id": "job_a830fd556ac147a79f77b5ced7532744",
        "source_path": str(SOURCE.relative_to(ROOT)),
        "source_frame_count": frame_count,
        "source_canvas": [128, 256],
        "removed_matte": {"rgb": list(MATTE), "method": "border_connected_hard_alpha"},
        "shared_source_bounds": list(shared_bounds),
        "runtime_frame_size": list(FRAME_SIZE),
        "grid": [GRID[0], GRID[1]],
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
    print(f"source_frames={frame_count} shared_bounds={shared_bounds} scaled_size={scaled_size}")


if __name__ == "__main__":
    main()
