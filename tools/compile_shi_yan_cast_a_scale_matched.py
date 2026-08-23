#!/usr/bin/env python3
"""Compile a scale-matched wide-motion candidate for Shi Yan Cast A.

The approved Idle occupies about 161x301 physical pixels inside its 172x410
HD2x cell.  The previous Cast A compile fitted the whole forward palm reach
inside the narrower 172px cell and reduced the actor to about 117x217 pixels.
This deterministic variant keeps the actor at the Idle scale and expands only
the attack motion canvas to 240x410 (120x205 logical).  It writes candidates
only and never promotes the runtime asset.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source_archive/cultivators/shi_yan/shi_yan_cast_a_source_sheet.png"
IDLE_SHEET = ROOT / "assets/camp/ui/expedition/animations/shi_yan/shi_yan_idle_sheet.png"
PREVIOUS_CAST = ROOT / "assets/camp/ui/expedition/animations/shi_yan/shi_yan_punch_sheet.png"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/cast_a_hd2x/scale_matched"
FRAME_SIZE = (240, 410)
LOGICAL_FRAME_SIZE = (120, 205)
GRID = (4, 2)
CELL_X = (0, 154, 307, 461, 615)
CELL_Y = (0, 231, 462)
SOURCE_SCALE = 1.4
HORIZONTAL_OFFSET = 18
TOP_OFFSET = 4
FPS = 10
HIT_FRAME = 4
RUNTIME_PRESENTATION_SCALE = 0.98
RUNTIME_VERTICAL_OFFSET = 0.0
UNSHARP_RADIUS = 0.8
UNSHARP_PERCENT = 130
UNSHARP_THRESHOLD = 2


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def alpha_bounds(image: Image.Image, threshold: int = 16) -> tuple[int, int, int, int] | None:
    return image.getchannel("A").point(lambda value: 255 if value >= threshold else 0).getbbox()


def resize_premultiplied_rgba(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.convert("RGBa").resize(size, Image.Resampling.LANCZOS).convert("RGBA")


def sharpen_premultiplied_rgb(image: Image.Image) -> Image.Image:
    image = image.convert("RGBA")
    original_alpha = image.getchannel("A")
    premultiplied = image.convert("RGBa")
    red, green, blue, alpha = premultiplied.split()
    unsharp = ImageFilter.UnsharpMask(
        radius=UNSHARP_RADIUS,
        percent=UNSHARP_PERCENT,
        threshold=UNSHARP_THRESHOLD,
    )
    sharpened = Image.merge(
        "RGBa",
        (red.filter(unsharp), green.filter(unsharp), blue.filter(unsharp), alpha),
    ).convert("RGBA")
    sharpened.putalpha(original_alpha)
    return sharpened


def save_animation(frames: list[Image.Image], path: Path) -> None:
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=[round(1000 / FPS)] * len(frames),
        loop=0,
        disposal=[0] * len(frames),
        blend=[0] * len(frames),
        optimize=True,
    )


def frame_from_sheet(sheet: Image.Image, index: int) -> Image.Image:
    cell_width = sheet.width // 4
    cell_height = sheet.height // 2
    return sheet.crop(
        (
            (index % 4) * cell_width,
            (index // 4) * cell_height,
            (index % 4 + 1) * cell_width,
            (index // 4 + 1) * cell_height,
        )
    )


def main() -> None:
    if not SOURCE.is_file() or not IDLE_SHEET.is_file() or not PREVIOUS_CAST.is_file():
        raise SystemExit("missing Cast A source, approved Idle, or previous Cast runtime sheet")
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (615, 462):
        raise SystemExit(f"unexpected source size: {source.size}")

    source_frames: list[Image.Image] = []
    source_bounds: list[tuple[int, int, int, int]] = []
    for index in range(8):
        frame = source.crop(
            (
                CELL_X[index % 4],
                CELL_Y[index // 4],
                CELL_X[index % 4 + 1],
                CELL_Y[index // 4 + 1],
            )
        )
        bounds = alpha_bounds(frame, 1)
        if bounds is None:
            raise SystemExit(f"source frame {index} is empty")
        source_frames.append(frame)
        source_bounds.append(bounds)

    shared_bounds = (
        min(bounds[0] for bounds in source_bounds),
        min(bounds[1] for bounds in source_bounds),
        max(bounds[2] for bounds in source_bounds),
        max(bounds[3] for bounds in source_bounds),
    )
    shared_size = (
        shared_bounds[2] - shared_bounds[0],
        shared_bounds[3] - shared_bounds[1],
    )
    scaled_size = (
        round(shared_size[0] * SOURCE_SCALE),
        round(shared_size[1] * SOURCE_SCALE),
    )
    if HORIZONTAL_OFFSET + scaled_size[0] > FRAME_SIZE[0] or TOP_OFFSET + scaled_size[1] > FRAME_SIZE[1]:
        raise SystemExit("scaled shared bounds do not fit the wide motion canvas")

    compiled_frames: list[Image.Image] = []
    compiled_bounds: list[tuple[int, int, int, int] | None] = []
    for frame in source_frames:
        cropped = frame.crop(shared_bounds)
        resized = resize_premultiplied_rgba(cropped, scaled_size)
        crisp = sharpen_premultiplied_rgb(resized)
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(crisp, (HORIZONTAL_OFFSET, TOP_OFFSET))
        compiled_frames.append(canvas)
        compiled_bounds.append(alpha_bounds(canvas))

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    frame_outputs: list[str] = []
    for index, frame in enumerate(compiled_frames):
        filename = f"shi_yan_cast_a_scale_matched_{index:02d}_240x410.png"
        frame.save(OUTPUT_DIR / filename, optimize=True)
        frame_outputs.append(filename)

    sheet = Image.new("RGBA", (FRAME_SIZE[0] * 4, FRAME_SIZE[1] * 2), (0, 0, 0, 0))
    for index, frame in enumerate(compiled_frames):
        sheet.alpha_composite(frame, ((index % 4) * FRAME_SIZE[0], (index // 4) * FRAME_SIZE[1]))
    sheet_path = OUTPUT_DIR / "shi_yan_cast_a_scale_matched_sheet_960x820.png"
    sheet.save(sheet_path, optimize=True)

    preview_path = OUTPUT_DIR / "shi_yan_cast_a_scale_matched_preview_10fps.png"
    save_animation(compiled_frames, preview_path)

    idle_sheet = Image.open(IDLE_SHEET).convert("RGBA")
    previous_sheet = Image.open(PREVIOUS_CAST).convert("RGBA")
    comparison = Image.new("RGBA", (760, 456), (8, 21, 27, 255))
    draw = ImageDraw.Draw(comparison)
    columns = [
        ("Idle frame 0", frame_from_sheet(idle_sheet, 0)),
        ("Current Cast frame 0", frame_from_sheet(previous_sheet, 0)),
        ("Scale-matched frame 0", compiled_frames[0]),
    ]
    for column, (label, frame) in enumerate(columns):
        left = 10 + column * 250
        comparison.alpha_composite(frame, (left + (240 - frame.width) // 2, 28))
        draw.text((left + 8, 420), label, fill=(226, 213, 177, 255))
    comparison_path = OUTPUT_DIR / "shi_yan_cast_a_idle_scale_comparison.png"
    comparison.save(comparison_path, optimize=True)

    idle_frame = frame_from_sheet(idle_sheet, 0)
    previous_frame = frame_from_sheet(previous_sheet, 0)
    manifest = {
        "asset_id": "combat_ally_shi_yan_cast_a_hd2x_scale_matched_candidate",
        "stage": "candidate_scale_correction",
        "representation": "HD dynamic portrait with wide attack motion canvas",
        "provider": "archived Cast A source + local deterministic scale-matched compile",
        "source_path": str(SOURCE.relative_to(ROOT)),
        "source_sha256": sha256(SOURCE),
        "approved_idle_path": str(IDLE_SHEET.relative_to(ROOT)),
        "approved_idle_sha256": sha256(IDLE_SHEET),
        "previous_cast_path": str(PREVIOUS_CAST.relative_to(ROOT)),
        "previous_cast_sha256": sha256(PREVIOUS_CAST),
        "source_frame_count": 8,
        "source_shared_bounds": list(shared_bounds),
        "source_scale": SOURCE_SCALE,
        "scaled_shared_size": list(scaled_size),
        "texture_frame_size": list(FRAME_SIZE),
        "logical_motion_canvas": list(LOGICAL_FRAME_SIZE),
        "unit_slot_size": [86, 205],
        "runtime_presentation_scale": RUNTIME_PRESENTATION_SCALE,
        "runtime_display_canvas": [
            round(LOGICAL_FRAME_SIZE[0] * RUNTIME_PRESENTATION_SCALE, 1),
            round(LOGICAL_FRAME_SIZE[1] * RUNTIME_PRESENTATION_SCALE, 1),
        ],
        "runtime_horizontal_offset": round(
            (86 - LOGICAL_FRAME_SIZE[0] * RUNTIME_PRESENTATION_SCALE) / 2, 1
        ),
        "runtime_vertical_offset": RUNTIME_VERTICAL_OFFSET,
        "runtime_mask": {
            "outer_frame": [86, 205],
            "inner_clip_position": [1, 1],
            "inner_clip_size": [84, 203],
            "frame_overlay_above_portrait": True,
        },
        "grid": list(GRID),
        "sheet_size": [sheet.width, sheet.height],
        "fps": FPS,
        "loop": False,
        "hit_frame": HIT_FRAME,
        "godot_texture_filter": "linear",
        "mipmaps": False,
        "alpha_policy": "premultiplied-alpha Lanczos resize; resized alpha preserved during RGB sharpening",
        "sharpening": {
            "method": "UnsharpMask",
            "radius": UNSHARP_RADIUS,
            "percent": UNSHARP_PERCENT,
            "threshold": UNSHARP_THRESHOLD,
        },
        "scale_evidence": {
            "idle_frame_0_alpha_bounds": list(alpha_bounds(idle_frame) or ()),
            "previous_cast_frame_0_alpha_bounds": list(alpha_bounds(previous_frame) or ()),
            "candidate_frame_0_alpha_bounds": list(compiled_bounds[0] or ()),
            "candidate_frame_4_alpha_bounds": list(compiled_bounds[4] or ()),
        },
        "frame_outputs": frame_outputs,
        "sheet_output": sheet_path.name,
        "sheet_sha256": sha256(sheet_path),
        "preview_output": preview_path.name,
        "preview_sha256": sha256(preview_path),
        "comparison_output": comparison_path.name,
        "comparison_sha256": sha256(comparison_path),
        "approved_for_runtime": False,
        "compiled_on": date.today().isoformat(),
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"sheet={sheet_path}")
    print(f"preview={preview_path}")
    print(f"comparison={comparison_path}")
    print(f"manifest={manifest_path}")
    print(f"idle_frame_0={alpha_bounds(idle_frame)}")
    print(f"previous_cast_frame_0={alpha_bounds(previous_frame)}")
    print(f"candidate_frame_0={compiled_bounds[0]}")


if __name__ == "__main__":
    main()
