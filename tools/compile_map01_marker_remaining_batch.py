#!/usr/bin/env python3
"""Compile the six user-generated Map01 marker masters into review candidates.

This is deterministic candidate processing only: hard alpha, crop, palette
quantization, nearest delivery scaling and a compact visual gate. It never
promotes files into assets/ or changes the formal map scene.
"""

from __future__ import annotations

import hashlib
import json
import shutil
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "art/candidates/map01_marker_batch_v1"
RAW_DIR = OUTPUT / "raw"
COMPILED_DIR = OUTPUT / "compiled"
REVIEW_DIR = OUTPUT / "review"

SOURCES = {
    "RESOURCE": (Path("/Users/zhangxiaoen/Downloads/ChatGPT Image 2026年8月23日 09_51_11.png"), "marker_explore_resource.png", 24, "bottom_center"),
    "ENEMY": (Path("/Users/zhangxiaoen/Downloads/ChatGPT Image 2026年8月23日 09_51_40.png"), "marker_explore_enemy.png", 24, "bottom_center"),
    "DUNGEON": (Path("/Users/zhangxiaoen/Downloads/ChatGPT Image 2026年8月23日 09_51_49.png"), "marker_explore_dungeon.png", 24, "bottom_center"),
    "MAP_EXIT": (Path("/Users/zhangxiaoen/Downloads/ChatGPT Image 2026年8月23日 09_52_05.png"), "marker_explore_map_exit.png", 24, "bottom_center"),
    "SPAWN": (Path("/Users/zhangxiaoen/Downloads/ChatGPT Image 2026年8月23日 09_52_16.png"), "marker_explore_spawn.png", 24, "bottom_center"),
    "BOSS": (Path("/Users/zhangxiaoen/Downloads/ChatGPT Image 2026年8月23日 09_52_31.png"), "marker_explore_boss.png", 32, "center"),
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def audit(image: Image.Image) -> dict[str, object]:
    alpha = image.getchannel("A")
    hist = alpha.histogram()
    return {
        "size": list(image.size),
        "mode": image.mode,
        "alpha_bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
        "alpha_extrema": list(alpha.getextrema()),
        "transparent_pixels": hist[0],
        "partial_alpha_pixels": sum(hist[1:255]),
        "opaque_pixels": hist[255],
    }


def hard_alpha(image: Image.Image, threshold: int = 128) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    image.putalpha(alpha)
    clean = Image.new("RGBA", image.size, (0, 0, 0, 0))
    clean.paste(image, (0, 0), alpha)
    return clean


def compile_one(source: Image.Image, logical_size: int) -> tuple[Image.Image, dict[str, object]]:
    hardened = hard_alpha(source)
    bbox = hardened.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("source has no alpha subject")
    subject = hardened.crop(bbox)
    target_extent = max(1, round(logical_size * 0.80))
    scale = min(target_extent / subject.width, target_extent / subject.height)
    target_size = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = hard_alpha(subject.resize(target_size, Image.Resampling.NEAREST))
    subject_alpha = subject.getchannel("A")
    rgb = Image.new("RGB", subject.size, (0, 0, 0))
    rgb.paste(subject.convert("RGB"), mask=subject_alpha)
    quantized = rgb.quantize(colors=14, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGBA")
    # Quantization produces an opaque RGB image; restore the original hard
    # alpha instead of accidentally turning the transparent matte black.
    quantized.putalpha(subject_alpha)
    subject = quantized
    logical = Image.new("RGBA", (logical_size, logical_size), (0, 0, 0, 0))
    offset = ((logical_size - subject.width) // 2, (logical_size - subject.height) // 2)
    logical.alpha_composite(subject, offset)
    return logical, {
        "source_subject_bbox_after_hard_alpha": list(bbox),
        "logical_subject_size": list(target_size),
        "logical_offset_for_visual_gate": list(offset),
        "alpha_threshold": 128,
        "palette_colors": 14,
        "resampling": "nearest",
    }


def font(size: int):
    for path in ("/System/Library/Fonts/Supplemental/Arial.ttf", "/System/Library/Fonts/SFNS.ttf"):
        if Path(path).exists():
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def make_panel(marker: Image.Image, background: tuple[int, int, int], display: int, grayscale: bool = False) -> Image.Image:
    panel = Image.new("RGBA", (display, display), (*background, 255))
    shown = marker.resize((display - 32, display - 32), Image.Resampling.NEAREST)
    panel.alpha_composite(shown, ((display - shown.width) // 2, (display - shown.height) // 2))
    if grayscale:
        return ImageOps.grayscale(panel.convert("RGB")).convert("RGBA")
    return panel


def make_review(results: dict[str, dict[str, object]]) -> Image.Image:
    panel = 192
    gap_x = 24
    gap_y = 44
    margin = 28
    header = 58
    cols = 3
    rows = len(results)
    width = margin * 2 + cols * panel + (cols - 1) * gap_x
    height = header + rows * panel + (rows - 1) * gap_y + margin
    board = Image.new("RGBA", (width, height), "#151b22")
    draw = ImageDraw.Draw(board)
    draw.text((margin, 14), "MAP01 REMAINING MARKERS · CANDIDATE GATE", fill="#eef2f5", font=font(22))
    draw.text((margin, 38), "left: Map01 · middle: dark board · right: grayscale · nearest 100%", fill="#aab5bf", font=font(13))
    for row, (asset_id, info) in enumerate(results.items()):
        top = header + row * (panel + gap_y)
        marker = info["logical"]
        views = (
            make_panel(marker, (116, 126, 135), panel),
            make_panel(marker, (29, 35, 43), panel),
            make_panel(marker, (116, 126, 135), panel, grayscale=True),
        )
        for col, view in enumerate(views):
            left = margin + col * (panel + gap_x)
            board.alpha_composite(view, (left, top))
            draw.rectangle((left, top, left + panel - 1, top + panel - 1), outline="#52606c", width=1)
        label = f"{asset_id} · {info['filename']}"
        draw.text((margin, top + panel + 10), label, fill="#d4dde4", font=font(14))
    return board


def main() -> None:
    for directory in (RAW_DIR, COMPILED_DIR, REVIEW_DIR):
        directory.mkdir(parents=True, exist_ok=True)
    results: dict[str, dict[str, object]] = {}
    manifest: dict[str, object] = {
        "schema_version": 1,
        "status": "candidate_pending_visual_approval",
        "supplier": "ChatGPT, user-executed",
        "formal_scene_modified": False,
        "meowa_points_spent": 0,
        "party_marker_regenerated": False,
        "outputs": [],
    }
    for asset_id, (source_path, filename, logical_size, anchor) in SOURCES.items():
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        archived = RAW_DIR / filename.replace(".png", "_gpt_master_raw.png")
        shutil.copy2(source_path, archived)
        source = Image.open(source_path).convert("RGBA")
        logical, compile_info = compile_one(source, logical_size)
        delivery = logical.resize((logical_size * 3, logical_size * 3), Image.Resampling.NEAREST)
        logical_path = COMPILED_DIR / f"{Path(filename).stem}_logical_{logical_size}.png"
        delivery_path = COMPILED_DIR / filename
        logical.save(logical_path, format="PNG", optimize=False)
        delivery.save(delivery_path, format="PNG", optimize=False)
        results[asset_id] = {"filename": filename, "logical": logical, "source_audit": audit(source), "compile": compile_info, "anchor": anchor}
        manifest["outputs"].append({
            "asset_id": asset_id,
            "filename": filename,
            "logical_size": [logical_size, logical_size],
            "delivery_size": [logical_size * 3, logical_size * 3],
            "anchor": anchor,
            "source": {"path": str(source_path), "sha256": sha256(source_path), "audit": audit(source)},
            "logical_path": str(logical_path),
            "delivery_path": str(delivery_path),
            "compile": compile_info,
        })
    review = make_review(results)
    review_path = REVIEW_DIR / "map01_marker_remaining_batch_v1_visual_gate.png"
    review.save(review_path, format="PNG", optimize=False)
    manifest["review_path"] = str(review_path)
    manifest["notes"] = [
        "All six source files have real RGBA alpha; black display areas are transparent.",
        "This batch uses hard-alpha threshold 128 and nearest scaling for candidate previews.",
        "Bottom-center anchor placement remains a Godot component concern; this sheet is a silhouette gate.",
        "Do not promote any file into assets/ before user visual approval.",
    ]
    manifest_path = COMPILED_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"MAP01_MARKER_BATCH_COMPILE_OK count={len(results)} review={review_path}")


if __name__ == "__main__":
    main()
