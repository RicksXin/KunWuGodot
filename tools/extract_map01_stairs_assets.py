#!/usr/bin/env python3
"""Compile the approved Map01 east-wall stair master into two runtime sprites."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_landmarks" / "map01_stairs_two_state_master_20260821.png"
OUTPUT_DIR = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "east_wall_stairs"
QA_DIR = ROOT / "art" / "candidates" / "map01_stairs" / "compiled"
FONT_PATH = ROOT / "assets" / "fonts" / "ark-pixel-12px-proportional-zh_cn.ttf"

APPROVED_SOURCE_SHA256 = "889d3316c87f769ad43b0ebbef36fe77ea74cc9f05fb175f9738e58cef4530b6"
EXPECTED_SOURCE_SIZE = (1254, 1254)
SOURCE_BBOXES = {
    "STAIRS_CLOSED": (395, 110, 859, 554),
    "STAIRS_OPEN": (395, 698, 859, 1142),
}
CANVAS_SIZE = (72, 56)
SUBJECT_SIZE = (64, 48)
SUBJECT_POSITION = (4, 4)
ANCHOR_PX = (36, 52)
ALPHA_THRESHOLD = 128
PALETTE_SIZE = 28

DARK_RED = (111, 62, 69)
OLD_GOLD = (212, 184, 125)
WARM_IVORY = (238, 224, 181)


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _luma(rgb: tuple[int, int, int]) -> float:
    return rgb[0] * 0.2126 + rgb[1] * 0.7152 + rgb[2] * 0.0722


def _hard_alpha(image: Image.Image) -> Image.Image:
    result = image.convert("RGBA")
    result.putdata([
        (red, green, blue, 255) if alpha >= ALPHA_THRESHOLD else (0, 0, 0, 0)
        for red, green, blue, alpha in result.get_flattened_data()
    ])
    return result


def _build_palette(images: Iterable[Image.Image]) -> list[tuple[int, int, int]]:
    samples = [
        (red, green, blue)
        for image in images
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha
    ]
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    quantized = strip.quantize(
        colors=PALETTE_SIZE,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    raw_palette = quantized.getpalette()
    indexes = sorted(set(quantized.get_flattened_data()))
    colors = {tuple(raw_palette[index * 3:index * 3 + 3]) for index in indexes}
    colors.update((DARK_RED, OLD_GOLD, WARM_IVORY))
    return sorted(colors, key=_luma)


def _functional_color(source: tuple[int, int, int], state_id: str) -> tuple[int, int, int] | None:
    red, green, blue = source
    if (
        red >= 95
        and green < 105
        and blue < 105
        and red > green * 1.08
        and red > blue * 1.06
        and red - max(green, blue) >= 8
    ):
        return DARK_RED
    if red > 200 and green > 150 and blue < 190 and red - green < 70 and green - blue > 18:
        return WARM_IVORY if state_id == "STAIRS_OPEN" else OLD_GOLD
    if red > 155 and green > 105 and blue < 135 and red - green > 22 and green - blue > 18:
        return OLD_GOLD
    return None


def _map_to_palette(image: Image.Image, palette: list[tuple[int, int, int]], state_id: str) -> Image.Image:
    output: list[tuple[int, int, int, int]] = []
    for red, green, blue, alpha in image.get_flattened_data():
        if not alpha:
            output.append((0, 0, 0, 0))
            continue
        source = (red, green, blue)
        functional = _functional_color(source, state_id)
        nearest = functional if functional is not None else min(
            palette,
            key=lambda color: (
                (source[0] - color[0]) ** 2 * 2
                + (source[1] - color[1]) ** 2 * 4
                + (source[2] - color[2]) ** 2 * 3
            ),
        )
        output.append((*nearest, 255))
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    result.putdata(output)
    return result


def _silhouette_iou(first: Image.Image, second: Image.Image) -> float:
    intersection = 0
    union = 0
    for first_pixel, second_pixel in zip(
        first.getchannel("A").get_flattened_data(),
        second.getchannel("A").get_flattened_data(),
        strict=True,
    ):
        first_opaque = first_pixel > 0
        second_opaque = second_pixel > 0
        intersection += first_opaque and second_opaque
        union += first_opaque or second_opaque
    return float(intersection) / float(max(1, union))


def _count_color(image: Image.Image, color: tuple[int, int, int]) -> int:
    return sum(
        1
        for red, green, blue, alpha in image.get_flattened_data()
        if alpha and (red, green, blue) == color
    )


def _write_contact_sheet(states: dict[str, Image.Image]) -> None:
    sheet = Image.new("RGB", (750, 900), "#0e1217")
    draw = ImageDraw.Draw(sheet)
    title_font = ImageFont.truetype(FONT_PATH, size=24)
    label_font = ImageFont.truetype(FONT_PATH, size=16)
    note_font = ImageFont.truetype(FONT_PATH, size=12)
    draw.text((24, 18), "Map01 · 东壁永久阶梯 · 运行缩放验收", fill="#eee8da", font=title_font)
    for index, state_id in enumerate(("STAIRS_CLOSED", "STAIRS_OPEN")):
        top = 64 + index * 408
        draw.rounded_rectangle((20, top, 730, top + 380), radius=8, fill="#1b2026", outline="#4a535c", width=2)
        draw.text((40, top + 20), state_id, fill="#eee8da", font=label_font)
        draw.rectangle((40, top + 56, 710, top + 324), fill="#5c696e")
        draw.rectangle((266, top + 56, 482, top + 224), fill="#8b8069")
        preview = states[state_id].resize((216, 168), Image.Resampling.NEAREST)
        sheet.paste(preview, (266, top + 56), preview)
        anchor_x = 266 + ANCHOR_PX[0] * 3
        anchor_y = top + 56 + ANCHOR_PX[1] * 3
        draw.line((anchor_x - 7, anchor_y, anchor_x + 7, anchor_y), fill="#c5a35b", width=1)
        draw.line((anchor_x, anchor_y - 7, anchor_x, anchor_y + 7), fill="#c5a35b", width=1)
        draw.text((40, top + 340), "72×56 · 锚点[36,52] · 3× nearest · 4×3视觉占格", fill="#aeb6be", font=note_font)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "map01_east_wall_stairs_two_state_contact_sheet.png", optimize=True)


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing approved stair master: {SOURCE}")
    source_sha256 = _sha256(SOURCE)
    if source_sha256 != APPROVED_SOURCE_SHA256:
        raise SystemExit(f"Stair source SHA-256 changed: {source_sha256}")
    master = Image.open(SOURCE).convert("RGBA")
    if master.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Unexpected stair source size: {master.size}")

    resized: dict[str, Image.Image] = {}
    for state_id, source_bbox in SOURCE_BBOXES.items():
        crop = _hard_alpha(master.crop(source_bbox))
        resized[state_id] = crop.resize(SUBJECT_SIZE, Image.Resampling.NEAREST)
    palette = _build_palette(resized.values())

    states: dict[str, Image.Image] = {}
    for state_id, subject in resized.items():
        compiled_subject = _map_to_palette(subject, palette, state_id)
        canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(compiled_subject, SUBJECT_POSITION)
        states[state_id] = canvas

    silhouette_iou = _silhouette_iou(states["STAIRS_CLOSED"], states["STAIRS_OPEN"])
    if silhouette_iou < 0.98:
        raise SystemExit(f"Stair state silhouettes diverged: {silhouette_iou:.4f}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    state_paths = {
        "STAIRS_CLOSED": OUTPUT_DIR / "stairs_closed.png",
        "STAIRS_OPEN": OUTPUT_DIR / "stairs_open.png",
    }
    for state_id, path in state_paths.items():
        states[state_id].save(path, optimize=True)

    manifest = {
        "version": 1,
        "approved_date": "2026-08-21",
        "source_master": "res://art/source_archive/map01_landmarks/map01_stairs_two_state_master_20260821.png",
        "source_sha256": source_sha256,
        "source_size_px": list(master.size),
        "source_alpha_audit": {
            "true_transparency": True,
            "alpha_threshold": ALPHA_THRESHOLD,
            "transparent_rgb_hardened_to_black": True,
        },
        "canvas_px": list(CANVAS_SIZE),
        "subject_px": list(SUBJECT_SIZE),
        "subject_position_px": list(SUBJECT_POSITION),
        "anchor_px": list(ANCHOR_PX),
        "visual_footprint_cells": [4, 3],
        "runtime_display_scale": 3,
        "map_scene_root_scale": 0.1875,
        "map_scene_instance_scale": 16,
        "formal_map_coordinate_frozen": False,
        "candidate_document_cell": [39, 31],
        "paired_elite_candidate_document_cell": [36, 29],
        "same_view_feedback_required": True,
        "component_scene": "res://scenes/maps/components/map01_east_wall_stairs.tscn",
        "state_owner": "external Map01 runtime/save adapter; presentation never writes save data",
        "silhouette_iou": round(silhouette_iou, 6),
        "palette": ["#%02x%02x%02x" % color for color in palette],
        "functional_palette": {
            "closed_dark_red": "#6f3e45",
            "old_gold": "#d4b87d",
            "open_warm_ivory": "#eee0b5",
        },
        "static_collision_rects": [
            {"id": "left_stone_cheek", "size_source_px": [18, 24], "center_source_px": [-20, -12]},
            {"id": "right_stone_cheek", "size_source_px": [18, 24], "center_source_px": [20, -12]},
        ],
        "closed_barrier_collision": {
            "size_source_px": [32, 10],
            "center_source_px": [0, -24],
            "enabled_in": ["STAIRS_CLOSED"],
            "disabled_in": ["STAIRS_OPEN"],
        },
        "states": {
            state_id: {
                "path": "res://" + str(path.relative_to(ROOT)),
                "source_bbox": list(SOURCE_BBOXES[state_id]),
                "used_rect_px": list(states[state_id].getbbox()),
                "dark_red_pixels": _count_color(states[state_id], DARK_RED),
                "old_gold_pixels": _count_color(states[state_id], OLD_GOLD),
                "warm_ivory_pixels": _count_color(states[state_id], WARM_IVORY),
            }
            for state_id, path in state_paths.items()
        },
    }
    (OUTPUT_DIR / "map01_east_wall_stairs_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_contact_sheet(states)
    print("Map01 east-wall stair extraction OK; two aligned states and functional passage cues preserved")
    print(f"Source SHA-256: {source_sha256}")
    print(f"Runtime silhouette IoU: {silhouette_iou:.6f}")
    print(f"Manifest: {OUTPUT_DIR / 'map01_east_wall_stairs_manifest.json'}")
    print(f"QA: {QA_DIR / 'map01_east_wall_stairs_two_state_contact_sheet.png'}")


if __name__ == "__main__":
    main()
