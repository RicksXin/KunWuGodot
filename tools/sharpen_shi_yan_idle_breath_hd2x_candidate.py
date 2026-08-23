#!/usr/bin/env python3
"""Create a restrained crisp variant of the 2x HD Shi Yan idle candidate.

Only premultiplied RGB detail is sharpened.  Alpha, frame dimensions, anchor,
timing, and layout are preserved exactly from the reviewed smooth 2x compile.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
SOURCE_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/compiled_hd2x"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/compiled_hd2x_crisp"
FRAME_SIZE = (172, 410)
GRID = (4, 2)
FPS = 8
UNSHARP_RADIUS = 0.8
UNSHARP_PERCENT = 130
UNSHARP_THRESHOLD = 2


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


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


def main() -> None:
    source_paths = [SOURCE_DIR / f"shi_yan_idle_breath_{index:02d}_172x410.png" for index in range(8)]
    missing = [str(path) for path in source_paths if not path.is_file()]
    if missing:
        raise SystemExit("missing smooth HD2x frame(s): " + ", ".join(missing))

    smooth_frames = [Image.open(path).convert("RGBA") for path in source_paths]
    if any(frame.size != FRAME_SIZE for frame in smooth_frames):
        raise SystemExit("unexpected smooth HD2x frame size")
    crisp_frames = [sharpen_premultiplied_rgb(frame) for frame in smooth_frames]

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    frame_outputs: list[str] = []
    for index, frame in enumerate(crisp_frames):
        filename = f"shi_yan_idle_breath_crisp_{index:02d}_172x410.png"
        frame.save(OUTPUT_DIR / filename, optimize=True)
        frame_outputs.append(filename)

    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID[0], FRAME_SIZE[1] * GRID[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(crisp_frames):
        sheet.alpha_composite(
            frame,
            ((index % GRID[0]) * FRAME_SIZE[0], (index // GRID[0]) * FRAME_SIZE[1]),
        )
    sheet_path = OUTPUT_DIR / "shi_yan_idle_breath_hd2x_crisp_sheet_688x820.png"
    sheet.save(sheet_path, optimize=True)

    preview_path = OUTPUT_DIR / "shi_yan_idle_breath_hd2x_crisp_preview_8fps.png"
    save_animation(crisp_frames, preview_path)

    comparison_frames: list[Image.Image] = []
    for smooth, crisp in zip(smooth_frames, crisp_frames, strict=True):
        canvas = Image.new("RGBA", (364, 410), (10, 23, 29, 255))
        canvas.alpha_composite(smooth, (5, 0))
        canvas.alpha_composite(crisp, (187, 0))
        comparison_frames.append(canvas)
    comparison_path = OUTPUT_DIR / "shi_yan_idle_breath_hd2x_smooth_vs_crisp_8fps.png"
    save_animation(comparison_frames, comparison_path)

    source_manifest_path = SOURCE_DIR / "manifest.json"
    source_manifest = json.loads(source_manifest_path.read_text(encoding="utf-8"))
    manifest = {
        "asset_id": "combat_ally_shi_yan_idle_breath_hd2x_crisp_candidate",
        "stage": "candidate_refined",
        "representation": "HD dynamic portrait",
        "source_manifest": str(source_manifest_path.relative_to(ROOT)),
        "source_sheet_sha256": source_manifest.get("sheet_sha256"),
        "logical_frame_size": [86, 205],
        "texture_frame_size": list(FRAME_SIZE),
        "grid": list(GRID),
        "sheet_size": [sheet.width, sheet.height],
        "alpha_policy": "preserve source alpha exactly; sharpen premultiplied RGB only",
        "sharpening": {
            "method": "UnsharpMask",
            "radius": UNSHARP_RADIUS,
            "percent": UNSHARP_PERCENT,
            "threshold": UNSHARP_THRESHOLD,
        },
        "godot_texture_filter": "linear",
        "mipmaps": False,
        "fps": FPS,
        "loop": True,
        "frame_outputs": frame_outputs,
        "sheet_output": sheet_path.name,
        "sheet_sha256": sha256(sheet_path),
        "review_preview": {
            "output": preview_path.name,
            "format": "animated lossless PNG (APNG)",
            "frame_count": len(crisp_frames),
            "frame_duration_ms": round(1000 / FPS),
            "sha256": sha256(preview_path),
        },
        "comparison_preview": {
            "output": comparison_path.name,
            "layout": "left=smooth HD2x; right=crisp HD2x",
            "format": "animated lossless PNG (APNG)",
            "frame_count": len(comparison_frames),
            "frame_duration_ms": round(1000 / FPS),
            "sha256": sha256(comparison_path),
        },
        "approved_for_runtime": False,
        "compiled_on": date.today().isoformat(),
    }
    (OUTPUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"compiled={sheet_path}")
    print(f"preview={preview_path}")
    print(f"comparison={comparison_path}")
    print(f"manifest={OUTPUT_DIR / 'manifest.json'}")


if __name__ == "__main__":
    main()
