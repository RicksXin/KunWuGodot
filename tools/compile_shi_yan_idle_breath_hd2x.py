#!/usr/bin/env python3
"""Compile Shi Yan's anchored breathing frames as a 2x HD portrait candidate.

The logical combat slot remains 86x205.  This candidate stores two texture
pixels per logical unit (172x410) so the painterly source is not forced through
the project's 1x pixel-art path.  RGBA is resized in premultiplied-alpha space
to avoid dark color fringes around transparent edges.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0"
OUTPUT_DIR = SOURCE_DIR / "compiled_hd2x"
PIXEL_OUTPUT_DIR = SOURCE_DIR / "compiled"
LOGICAL_FRAME_SIZE = (86, 205)
ASSET_SCALE = 2
FRAME_SIZE = tuple(value * ASSET_SCALE for value in LOGICAL_FRAME_SIZE)
GRID = (4, 2)
SAFE_MARGIN_X = 2 * ASSET_SCALE
TOP_OFFSET = 4 * ASSET_SCALE
FPS = 8


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def resize_premultiplied_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Resize an RGBA image without pulling transparent RGB into its edges."""
    return image.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def main() -> None:
    source_paths = [SOURCE_DIR / f"shi_yan_idle_breath_{index:02d}_362x543.png" for index in range(8)]
    missing = [str(path) for path in source_paths if not path.is_file()]
    if missing:
        raise SystemExit("missing anchored candidate frame(s): " + ", ".join(missing))

    frames = [Image.open(path).convert("RGBA") for path in source_paths]
    bounds = [frame.getchannel("A").getbbox() for frame in frames]
    if any(bound is None for bound in bounds):
        raise SystemExit("one or more source frames are empty")
    typed_bounds = [bound for bound in bounds if bound is not None]
    shared_bounds = (
        min(bound[0] for bound in typed_bounds),
        min(bound[1] for bound in typed_bounds),
        max(bound[2] for bound in typed_bounds),
        max(bound[3] for bound in typed_bounds),
    )
    shared_width = shared_bounds[2] - shared_bounds[0]
    shared_height = shared_bounds[3] - shared_bounds[1]
    scale = min(
        (FRAME_SIZE[0] - SAFE_MARGIN_X * 2) / shared_width,
        (FRAME_SIZE[1] - TOP_OFFSET) / shared_height,
    )
    scaled_size = (
        max(1, round(shared_width * scale)),
        max(1, round(shared_height * scale)),
    )

    compiled_frames: list[Image.Image] = []
    for frame in frames:
        crop = frame.crop(shared_bounds)
        resized = resize_premultiplied_rgba(crop, scaled_size)
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(resized, ((FRAME_SIZE[0] - scaled_size[0]) // 2, TOP_OFFSET))
        compiled_frames.append(canvas)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    frame_outputs: list[str] = []
    for index, frame in enumerate(compiled_frames):
        filename = f"shi_yan_idle_breath_{index:02d}_172x410.png"
        frame.save(OUTPUT_DIR / filename, optimize=True)
        frame_outputs.append(filename)

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
    sheet_path = OUTPUT_DIR / "shi_yan_idle_breath_hd2x_sheet_688x820.png"
    sheet.save(sheet_path, optimize=True)

    preview_path = OUTPUT_DIR / "shi_yan_idle_breath_hd2x_preview_8fps.png"
    compiled_frames[0].save(
        preview_path,
        save_all=True,
        append_images=compiled_frames[1:],
        duration=[round(1000 / FPS)] * len(compiled_frames),
        loop=0,
        disposal=[0] * len(compiled_frames),
        blend=[0] * len(compiled_frames),
        optimize=True,
    )

    pixel_paths = [PIXEL_OUTPUT_DIR / f"shi_yan_idle_breath_{index:02d}_86x205.png" for index in range(8)]
    if not all(path.is_file() for path in pixel_paths):
        raise SystemExit("missing 1x pixel candidate frames required for the A/B preview")
    pixel_frames = [Image.open(path).convert("RGBA") for path in pixel_paths]
    comparison_frames: list[Image.Image] = []
    left_x = 5
    right_x = 187
    for pixel_frame, hd_frame in zip(pixel_frames, compiled_frames, strict=True):
        canvas = Image.new("RGBA", (364, 410), (10, 23, 29, 255))
        canvas.alpha_composite(
            pixel_frame.resize(FRAME_SIZE, Image.Resampling.NEAREST),
            (left_x, 0),
        )
        canvas.alpha_composite(hd_frame, (right_x, 0))
        comparison_frames.append(canvas)
    comparison_path = OUTPUT_DIR / "shi_yan_idle_breath_1x_vs_hd2x_preview_8fps.png"
    comparison_frames[0].save(
        comparison_path,
        save_all=True,
        append_images=comparison_frames[1:],
        duration=[round(1000 / FPS)] * len(comparison_frames),
        loop=0,
        disposal=[0] * len(comparison_frames),
        blend=[0] * len(comparison_frames),
        optimize=True,
    )

    manifest = {
        "asset_id": "combat_ally_shi_yan_idle_breath_hd2x_candidate",
        "stage": "candidate_compiled",
        "representation": "HD dynamic portrait",
        "provider": "local deterministic compile from user-provided breathing atlas",
        "source_dir": str(SOURCE_DIR.relative_to(ROOT)),
        "source_frame_count": len(frames),
        "source_frame_size": [frames[0].width, frames[0].height],
        "shared_source_bounds": list(shared_bounds),
        "logical_frame_size": list(LOGICAL_FRAME_SIZE),
        "asset_scale": ASSET_SCALE,
        "texture_frame_size": list(FRAME_SIZE),
        "scaled_content_size": list(scaled_size),
        "grid": list(GRID),
        "sheet_size": [sheet.width, sheet.height],
        "resampling": "Lanczos in premultiplied-alpha RGBA",
        "godot_texture_filter": "linear",
        "mipmaps": False,
        "fps": FPS,
        "loop": True,
        "frame_outputs": frame_outputs,
        "sheet_output": sheet_path.name,
        "sheet_sha256": sha256(sheet_path),
        "review_preview": {
            "output": preview_path.name,
            "size": list(FRAME_SIZE),
            "format": "animated lossless PNG (APNG)",
            "frame_duration_ms": round(1000 / FPS),
            "sha256": sha256(preview_path),
        },
        "comparison_preview": {
            "output": comparison_path.name,
            "size": [comparison_frames[0].width, comparison_frames[0].height],
            "layout": "left=86x205 pixel candidate enlarged 2x with nearest; right=172x410 HD candidate at native size",
            "format": "animated lossless PNG (APNG)",
            "frame_duration_ms": round(1000 / FPS),
            "sha256": sha256(comparison_path),
        },
        "contract_exception": "Comparison candidate only: tests a 2x HD texture inside the unchanged 86x205 logical slot.",
        "approved_for_runtime": False,
        "compiled_on": date.today().isoformat(),
    }
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"compiled={sheet_path}")
    print(f"preview={preview_path}")
    print(f"manifest={OUTPUT_DIR / 'manifest.json'}")
    print(f"shared_bounds={shared_bounds} scale={scale:.8f} scaled_size={scaled_size}")


if __name__ == "__main__":
    main()
