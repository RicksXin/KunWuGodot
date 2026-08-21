#!/usr/bin/env python3
"""Compile one generated Map01 marker master into review-only pixel candidates.

The script never writes into runtime ``assets/``. It hardens generated alpha,
normalizes the subject to a logical pixel canvas, creates the 3x nearest-neighbor
delivery candidate, and builds the Map01/dark/grayscale visual Gate board.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
MAP_REFERENCE = ROOT / "art/candidates/map01_markers/reference/screenshot_map01_marker_scale.png"
DARK_REFERENCE = ROOT / "art/candidates/map01_markers/reference/screenshot_marker_dark_contrast_board.png"


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Arial Unicode.ttf",
    )
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size)
    return ImageFont.load_default()


def _alpha_audit(image: Image.Image) -> dict[str, object]:
    alpha = image.getchannel("A")
    histogram = alpha.histogram()
    return {
        "extrema": list(alpha.getextrema()),
        "bbox": list(alpha.getbbox() or (0, 0, 0, 0)),
        "transparent_pixels": histogram[0],
        "opaque_pixels": histogram[255],
        "partial_alpha_pixels": sum(histogram[1:255]),
        "total_pixels": image.width * image.height,
    }


def _hard_alpha(image: Image.Image, threshold: int) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    rgba.putalpha(alpha)
    transparent = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    transparent.paste(rgba, (0, 0), alpha)
    return transparent


def _quantize_opaque(image: Image.Image, colors: int) -> Image.Image:
    alpha = image.getchannel("A")
    rgb = Image.new("RGB", image.size, (0, 0, 0))
    rgb.paste(image.convert("RGB"), mask=alpha)
    indexed = rgb.quantize(colors=colors, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    rgba = indexed.convert("RGBA")
    rgba.putalpha(alpha)
    transparent = Image.new("RGBA", rgba.size, (0, 0, 0, 0))
    transparent.paste(rgba, (0, 0), alpha)
    return transparent


def _compile_logical(
    source: Image.Image,
    logical_size: int,
    subject_fill: float,
    alpha_threshold: int,
    palette_colors: int,
    source_resampling: Image.Resampling,
) -> tuple[Image.Image, dict[str, object]]:
    hardened = _hard_alpha(source, alpha_threshold)
    bbox = hardened.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit("Generated marker has no opaque subject after alpha cleanup")

    subject = hardened.crop(bbox)
    target_extent = max(1, round(logical_size * subject_fill))
    scale = min(target_extent / subject.width, target_extent / subject.height)
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    subject = _hard_alpha(subject.resize(target_size, source_resampling), alpha_threshold)
    subject = _hard_alpha(_quantize_opaque(subject, palette_colors), alpha_threshold)

    logical = Image.new("RGBA", (logical_size, logical_size), (0, 0, 0, 0))
    offset = ((logical_size - subject.width) // 2, (logical_size - subject.height) // 2)
    logical.alpha_composite(subject, offset)
    return logical, {
        "source_subject_bbox": list(bbox),
        "logical_subject_size": list(target_size),
        "logical_subject_offset": list(offset),
    }


def _solidify(image: Image.Image, radius: int, color: str) -> Image.Image:
    if radius <= 0:
        return image
    alpha = image.getchannel("A")
    expanded_alpha = alpha.filter(ImageFilter.MaxFilter(radius * 2 + 1))
    expanded_alpha = expanded_alpha.point(lambda value: 255 if value else 0)
    solid = Image.new("RGBA", image.size, color)
    solid.putalpha(expanded_alpha)
    solid.alpha_composite(image)
    transparent = Image.new("RGBA", image.size, (0, 0, 0, 0))
    transparent.paste(solid, (0, 0), solid.getchannel("A"))
    return transparent


def _crop_reference(reference: Image.Image, center: tuple[int, int], side: int = 176) -> Image.Image:
    half = side // 2
    return reference.crop((center[0] - half, center[1] - half, center[0] + half, center[1] + half))


def _composite_panel(background: Image.Image, marker: Image.Image, scale: float, grayscale: bool) -> Image.Image:
    panel = background.convert("RGBA")
    display_size = max(1, round(marker.width * 2 * scale))
    displayed = marker.resize((display_size, display_size), Image.Resampling.NEAREST)
    position = ((panel.width - display_size) // 2, (panel.height - display_size) // 2)
    panel.alpha_composite(displayed, position)
    if grayscale:
        panel = ImageOps.grayscale(panel.convert("RGB")).convert("RGBA")
    return panel


def _build_review_board(marker: Image.Image) -> Image.Image:
    map_reference = Image.open(MAP_REFERENCE).convert("RGBA")
    dark_reference = Image.open(DARK_REFERENCE).convert("RGBA")
    map_crop = _crop_reference(map_reference, (336, 144))
    dark_crop = _crop_reference(dark_reference, (336, 200))

    scales = (1.0, 0.75, 0.5)
    panel_side = 176
    gap = 24
    margin = 32
    label_height = 34
    header_height = 72
    board_width = margin * 2 + panel_side * 3 + gap * 2
    board_height = header_height + (panel_side + label_height) * 3 + gap * 2 + margin
    board = Image.new("RGBA", (board_width, board_height), "#151b22")
    draw = ImageDraw.Draw(board)
    title_font = _font(22)
    label_font = _font(15)
    draw.text((margin, 18), "MAP01 PARTY MARKER · CANDIDATE VISUAL GATE", fill="#eef2f5", font=title_font)
    draw.text((margin, 45), "Map01 / dark contrast / grayscale · 100% / 75% / 50%", fill="#9eabb6", font=label_font)

    rows = (
        ("MAP01", map_crop, False),
        ("DARK", dark_crop, False),
        ("GRAYSCALE", map_crop, True),
    )
    for row_index, (row_label, background, grayscale) in enumerate(rows):
        top = header_height + row_index * (panel_side + label_height + gap)
        for column_index, scale in enumerate(scales):
            left = margin + column_index * (panel_side + gap)
            panel = _composite_panel(background, marker, scale, grayscale)
            board.alpha_composite(panel, (left, top))
            draw.rectangle((left, top, left + panel_side - 1, top + panel_side - 1), outline="#52606c", width=1)
            draw.text(
                (left, top + panel_side + 7),
                f"{row_label} · {round(scale * 100)}%",
                fill="#c8d0d7",
                font=label_font,
            )
    return board


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--asset-id", default="PARTY")
    parser.add_argument("--filename", default="marker_explore_party.png")
    parser.add_argument("--logical-size", type=int, default=32)
    parser.add_argument("--delivery-scale", type=int, default=3)
    parser.add_argument("--subject-fill", type=float, default=0.80)
    parser.add_argument("--alpha-threshold", type=int, default=128)
    parser.add_argument("--palette-colors", type=int, default=20)
    parser.add_argument("--source-resampling", choices=("nearest", "box"), default="box")
    parser.add_argument("--solidify-radius", type=int, default=0)
    parser.add_argument("--solidify-color", default="#263957")
    parser.add_argument("--initial-prompt", type=Path)
    parser.add_argument("--revision-prompt", type=Path)
    parser.add_argument("--chat-url")
    args = parser.parse_args()

    source_path = args.input.resolve()
    output_dir = args.output_dir.resolve()
    output_dir.mkdir(parents=True, exist_ok=True)
    source = Image.open(source_path).convert("RGBA")
    source_audit = _alpha_audit(source)
    source_resampling = {
        "nearest": Image.Resampling.NEAREST,
        "box": Image.Resampling.BOX,
    }[args.source_resampling]
    logical, compile_info = _compile_logical(
        source,
        args.logical_size,
        args.subject_fill,
        args.alpha_threshold,
        args.palette_colors,
        source_resampling,
    )
    logical = _solidify(logical, args.solidify_radius, args.solidify_color)
    runtime_size = args.logical_size * args.delivery_scale
    runtime = logical.resize((runtime_size, runtime_size), Image.Resampling.NEAREST)
    review = _build_review_board(logical)

    stem = Path(args.filename).stem
    logical_path = output_dir / f"{stem}_logical_{args.logical_size}.png"
    runtime_path = output_dir / args.filename
    review_path = output_dir / f"{stem}_visual_gate.png"
    manifest_path = output_dir / f"{stem}_candidate_manifest.json"
    logical.save(logical_path)
    runtime.save(runtime_path)
    review.save(review_path)

    manifest = {
        "schema_version": 1,
        "status": "candidate_pending_visual_approval",
        "provider": "ChatGPT Plus web",
        "meowa_used": False,
        "formal_map_scene_modified": False,
        "asset_id": args.asset_id,
        "filename": args.filename,
        "source": {
            "path": str(source_path.relative_to(ROOT)),
            "size": list(source.size),
            "sha256": _sha256(source_path),
            "alpha_audit": source_audit,
        },
        "generation": {
            "date": "2026-08-21",
            "chat_url": args.chat_url,
            "initial_prompt": str(args.initial_prompt.resolve().relative_to(ROOT)) if args.initial_prompt else None,
            "revision_prompt": str(args.revision_prompt.resolve().relative_to(ROOT)) if args.revision_prompt else None,
        },
        "compile": {
            "logical_size": [args.logical_size, args.logical_size],
            "delivery_size": [runtime_size, runtime_size],
            "delivery_scale": args.delivery_scale,
            "subject_fill": args.subject_fill,
            "alpha_threshold": args.alpha_threshold,
            "palette_colors": args.palette_colors,
            "source_resampling": args.source_resampling,
            "delivery_resampling": "nearest",
            "solidify_radius": args.solidify_radius,
            "solidify_color": args.solidify_color,
            **compile_info,
        },
        "outputs": {
            "logical": str(logical_path.relative_to(ROOT)),
            "delivery_candidate": str(runtime_path.relative_to(ROOT)),
            "visual_gate": str(review_path.relative_to(ROOT)),
        },
    }
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
