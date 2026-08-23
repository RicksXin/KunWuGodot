#!/usr/bin/env python3
"""Compile Shi Yan's archived Cast A source as a crisp HD2x review candidate.

The source atlas is sliced without changing frame order. All frames share one
content bound and scale, are resized in premultiplied-alpha space, and receive
the same restrained RGB sharpening used by the approved HD2x Idle workflow.
This tool only writes to art/candidates and never promotes runtime assets.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source_archive/cultivators/shi_yan/shi_yan_cast_a_source_sheet.png"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/cast_a_hd2x/compiled_crisp"
LOGICAL_FRAME_SIZE = (86, 205)
ASSET_SCALE = 2
FRAME_SIZE = tuple(value * ASSET_SCALE for value in LOGICAL_FRAME_SIZE)
GRID = (4, 2)
CELL_X = (0, 154, 307, 461, 615)
CELL_Y = (0, 231, 462)
SAFE_MARGIN_X = 4 * ASSET_SCALE
TOP_OFFSET = 2 * ASSET_SCALE
FPS = 10
HIT_FRAME = 4
UNSHARP_RADIUS = 0.8
UNSHARP_PERCENT = 130
UNSHARP_THRESHOLD = 2


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


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
        (
            red.filter(unsharp),
            green.filter(unsharp),
            blue.filter(unsharp),
            alpha,
        ),
    ).convert("RGBA")
    sharpened.putalpha(original_alpha)
    return sharpened


def save_preview(frames: list[Image.Image], path: Path) -> None:
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


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing archived Cast A source: {SOURCE}")
    source = Image.open(SOURCE).convert("RGBA")
    if source.size != (615, 462):
        raise SystemExit(f"unexpected source size: {source.size}")

    source_frames: list[Image.Image] = []
    bounds: list[tuple[int, int, int, int]] = []
    for index in range(GRID[0] * GRID[1]):
        column = index % GRID[0]
        row = index // GRID[0]
        frame = source.crop((CELL_X[column], CELL_Y[row], CELL_X[column + 1], CELL_Y[row + 1]))
        bound = frame.getchannel("A").getbbox()
        if bound is None:
            raise SystemExit(f"source frame {index} is empty")
        source_frames.append(frame)
        bounds.append(bound)

    shared_bounds = (
        min(bound[0] for bound in bounds),
        min(bound[1] for bound in bounds),
        max(bound[2] for bound in bounds),
        max(bound[3] for bound in bounds),
    )
    shared_size = (
        shared_bounds[2] - shared_bounds[0],
        shared_bounds[3] - shared_bounds[1],
    )
    scale = min(
        (FRAME_SIZE[0] - SAFE_MARGIN_X * 2) / shared_size[0],
        (FRAME_SIZE[1] - TOP_OFFSET * 2) / shared_size[1],
    )
    scaled_size = (
        max(1, round(shared_size[0] * scale)),
        max(1, round(shared_size[1] * scale)),
    )

    compiled_frames: list[Image.Image] = []
    for frame in source_frames:
        cropped = frame.crop(shared_bounds)
        resized = resize_premultiplied_rgba(cropped, scaled_size)
        crisp = sharpen_premultiplied_rgb(resized)
        canvas = Image.new("RGBA", FRAME_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(crisp, ((FRAME_SIZE[0] - scaled_size[0]) // 2, TOP_OFFSET))
        compiled_frames.append(canvas)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    frame_outputs: list[str] = []
    for index, frame in enumerate(compiled_frames):
        filename = f"shi_yan_cast_a_hd2x_crisp_{index:02d}_172x410.png"
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
    sheet_path = OUTPUT_DIR / "shi_yan_cast_a_hd2x_crisp_sheet_688x820.png"
    sheet.save(sheet_path, optimize=True)

    preview_path = OUTPUT_DIR / "shi_yan_cast_a_hd2x_crisp_preview_10fps.png"
    save_preview(compiled_frames, preview_path)

    manifest = {
        "asset_id": "combat_ally_shi_yan_cast_a_hd2x_crisp_candidate",
        "stage": "candidate_refined",
        "representation": "HD dynamic portrait",
        "provider": "archived Cast A source + local deterministic HD2x compile",
        "source_path": str(SOURCE.relative_to(ROOT)),
        "source_sha256": sha256(SOURCE),
        "source_sheet_size": list(source.size),
        "source_frame_count": len(source_frames),
        "shared_source_bounds": list(shared_bounds),
        "logical_frame_size": list(LOGICAL_FRAME_SIZE),
        "asset_scale": ASSET_SCALE,
        "texture_frame_size": list(FRAME_SIZE),
        "scaled_content_size": list(scaled_size),
        "grid": list(GRID),
        "sheet_size": [sheet.width, sheet.height],
        "alpha_policy": "premultiplied-alpha Lanczos resize; resized alpha preserved during RGB sharpening",
        "sharpening": {
            "method": "UnsharpMask",
            "radius": UNSHARP_RADIUS,
            "percent": UNSHARP_PERCENT,
            "threshold": UNSHARP_THRESHOLD,
        },
        "godot_texture_filter": "linear",
        "mipmaps": False,
        "fps": FPS,
        "loop": False,
        "hit_frame": HIT_FRAME,
        "embedded_palm_light": True,
        "target_hit_vfx_included": False,
        "frame_outputs": frame_outputs,
        "sheet_output": sheet_path.name,
        "sheet_sha256": sha256(sheet_path),
        "review_preview": {
            "output": preview_path.name,
            "format": "animated lossless PNG (APNG)",
            "frame_count": len(compiled_frames),
            "frame_duration_ms": round(1000 / FPS),
            "sha256": sha256(preview_path),
        },
        "approved_for_runtime": False,
        "compiled_on": date.today().isoformat(),
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"compiled={sheet_path}")
    print(f"preview={preview_path}")
    print(f"manifest={manifest_path}")
    print(f"shared_bounds={shared_bounds} scale={scale:.8f} scaled_size={scaled_size}")


if __name__ == "__main__":
    main()
