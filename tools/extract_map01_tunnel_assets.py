#!/usr/bin/env python3
"""Compile the approved Map01 mountain-tunnel master into layered runtime sprites."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_landmarks" / "map01_tunnel_three_state_master_20260821.png"
OUTPUT_DIR = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "mountain_tunnel"
QA_DIR = ROOT / "art" / "candidates" / "map01_tunnel" / "compiled"
FONT_PATH = ROOT / "assets" / "fonts" / "ark-pixel-12px-proportional-zh_cn.ttf"

APPROVED_SOURCE_SHA256 = "a3b98ec88961971b31e2aae0ccbb6bdb6ad101246c13fbec3ff79176bb4608c8"
EXPECTED_SOURCE_SIZE = (1254, 1254)
SOURCE_BBOXES = {
    "TUNNEL_DEFAULT": (316, 40, 930, 411),
    "TUNNEL_DISCOVERED": (316, 440, 930, 811),
    "TUNNEL_CLEARED": (316, 833, 930, 1205),
}
CANVAS_SIZE = (72, 56)
SUBJECT_SIZE = (64, 39)
SUBJECT_POSITION = (4, 13)
ANCHOR_PX = (36, 52)
ALPHA_THRESHOLD = 128
PALETTE_SIZE = 28

# The upper row is the single fadeable cap. State changes are constrained to the
# center slot below it, so the flanking stone shoulders remain invariant.
ROOF_MAX_Y = 32
BASE_MIN_Y = 29
CENTER_MIN_X = 27
CENTER_MAX_X = 45

DULL_EMBER = (181, 76, 50)
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
    colors.update((DULL_EMBER, WARM_IVORY))
    return sorted(colors, key=_luma)


def _functional_color(source: tuple[int, int, int], state_id: str) -> tuple[int, int, int] | None:
    red, green, blue = source
    if (
        state_id == "TUNNEL_DISCOVERED"
        and red >= 105
        and red > green * 1.18
        and red > blue * 1.12
        and red - max(green, blue) >= 12
    ):
        return DULL_EMBER
    if (
        state_id == "TUNNEL_CLEARED"
        and red >= 190
        and green >= 175
        and blue >= 135
        and red - blue <= 90
    ):
        return WARM_IVORY
    return None


def _map_to_palette(
    image: Image.Image,
    palette: list[tuple[int, int, int]],
    state_id: str,
) -> Image.Image:
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


def _layer_from_region(image: Image.Image, keep_pixel) -> Image.Image:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    source = image.load()
    target = layer.load()
    for y in range(image.height):
        for x in range(image.width):
            if source[x, y][3] and keep_pixel(x, y):
                target[x, y] = source[x, y]
    return layer


def _compose(base: Image.Image, state: Image.Image, roof: Image.Image, roof_alpha: float = 1.0) -> Image.Image:
    result = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    result.alpha_composite(base)
    result.alpha_composite(state)
    if roof_alpha < 1.0:
        faded = roof.copy()
        faded.putalpha(faded.getchannel("A").point(lambda value: round(value * roof_alpha)))
        result.alpha_composite(faded)
    else:
        result.alpha_composite(roof)
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


def _write_contact_sheet(
    base: Image.Image,
    roof: Image.Image,
    states: dict[str, Image.Image],
) -> None:
    sheet = Image.new("RGB", (750, 970), "#0e1217")
    draw = ImageDraw.Draw(sheet)
    title_font = ImageFont.truetype(FONT_PATH, size=24)
    label_font = ImageFont.truetype(FONT_PATH, size=15)
    note_font = ImageFont.truetype(FONT_PATH, size=11)
    draw.text((24, 18), "Map01 · 山腹暗道 · 三态分层验收", fill="#eee8da", font=title_font)
    draw.text((24, 50), "左：顶石正常　右：顶石淡出至 22%", fill="#aeb6be", font=note_font)
    for index, state_id in enumerate(SOURCE_BBOXES):
        top = 78 + index * 286
        draw.rounded_rectangle((20, top, 730, top + 266), radius=8, fill="#1b2026", outline="#4a535c", width=2)
        draw.text((40, top + 16), state_id, fill="#eee8da", font=label_font)
        for column, roof_alpha in enumerate((1.0, 0.22)):
            left = 86 + column * 346
            ground_box = (left, top + 54, left + 216, top + 222)
            draw.rectangle(ground_box, fill="#5c696e")
            preview = _compose(base, states[state_id], roof, roof_alpha).resize((216, 168), Image.Resampling.NEAREST)
            sheet.paste(preview, (left, top + 54), preview)
            anchor_x = left + ANCHOR_PX[0] * 3
            anchor_y = top + 54 + ANCHOR_PX[1] * 3
            draw.line((anchor_x - 7, anchor_y, anchor_x + 7, anchor_y), fill="#c5a35b", width=1)
            draw.line((anchor_x, anchor_y - 7, anchor_x, anchor_y + 7), fill="#c5a35b", width=1)
        draw.text((40, top + 238), "72×56 · 锚点[36,52] · 3× nearest · 两侧碰撞常驻", fill="#aeb6be", font=note_font)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "map01_tunnel_three_state_contact_sheet.png", optimize=True)


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing approved tunnel master: {SOURCE}")
    source_sha256 = _sha256(SOURCE)
    if source_sha256 != APPROVED_SOURCE_SHA256:
        raise SystemExit(f"Tunnel source SHA-256 changed: {source_sha256}")
    master = Image.open(SOURCE).convert("RGBA")
    if master.size != EXPECTED_SOURCE_SIZE:
        raise SystemExit(f"Unexpected tunnel source size: {master.size}")

    resized: dict[str, Image.Image] = {}
    for state_id, source_bbox in SOURCE_BBOXES.items():
        crop = _hard_alpha(master.crop(source_bbox))
        subject = crop.resize(SUBJECT_SIZE, Image.Resampling.NEAREST)
        subject = _hard_alpha(subject)
        canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
        canvas.alpha_composite(subject, SUBJECT_POSITION)
        resized[state_id] = canvas
    palette = _build_palette(resized.values())
    compiled = {
        state_id: _map_to_palette(image, palette, state_id)
        for state_id, image in resized.items()
    }

    default = compiled["TUNNEL_DEFAULT"]
    roof = _layer_from_region(default, lambda _x, y: y <= ROOF_MAX_Y)
    base = _layer_from_region(
        default,
        lambda x, y: y >= BASE_MIN_Y and not (CENTER_MIN_X <= x < CENTER_MAX_X),
    )
    state_layers = {
        state_id: _layer_from_region(
            image,
            lambda x, y: y >= BASE_MIN_Y and CENTER_MIN_X <= x < CENTER_MAX_X,
        )
        for state_id, image in compiled.items()
    }
    composites = {
        state_id: _compose(base, state_layer, roof)
        for state_id, state_layer in state_layers.items()
    }
    pair_ious = {
        "default_discovered": _silhouette_iou(composites["TUNNEL_DEFAULT"], composites["TUNNEL_DISCOVERED"]),
        "default_cleared": _silhouette_iou(composites["TUNNEL_DEFAULT"], composites["TUNNEL_CLEARED"]),
        "discovered_cleared": _silhouette_iou(composites["TUNNEL_DISCOVERED"], composites["TUNNEL_CLEARED"]),
    }
    minimum_iou = min(pair_ious.values())
    if minimum_iou < 0.98:
        raise SystemExit(f"Tunnel state silhouettes diverged after layering: {minimum_iou:.4f}")
    if _count_color(state_layers["TUNNEL_DISCOVERED"], DULL_EMBER) < 1:
        raise SystemExit("TUNNEL_DISCOVERED lost its restrained ember")
    if _count_color(state_layers["TUNNEL_CLEARED"], WARM_IVORY) < 1:
        raise SystemExit("TUNNEL_CLEARED lost its warm-ivory trace")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    layer_paths = {
        "TUNNEL_STAY_BASE": OUTPUT_DIR / "tunnel_stay_base.png",
        "TUNNEL_ROOF_FOREGROUND": OUTPUT_DIR / "tunnel_roof_foreground.png",
        "TUNNEL_DEFAULT": OUTPUT_DIR / "tunnel_default_state.png",
        "TUNNEL_DISCOVERED": OUTPUT_DIR / "tunnel_discovered_state.png",
        "TUNNEL_CLEARED": OUTPUT_DIR / "tunnel_cleared_state.png",
    }
    base.save(layer_paths["TUNNEL_STAY_BASE"], optimize=True)
    roof.save(layer_paths["TUNNEL_ROOF_FOREGROUND"], optimize=True)
    for state_id, image in state_layers.items():
        image.save(layer_paths[state_id], optimize=True)

    QA_DIR.mkdir(parents=True, exist_ok=True)
    for state_id, image in composites.items():
        image.save(QA_DIR / (state_id.lower() + "_composite.png"), optimize=True)
    _write_contact_sheet(base, roof, state_layers)

    manifest = {
        "version": 1,
        "approved_date": "2026-08-21",
        "source_master": "res://art/source_archive/map01_landmarks/map01_tunnel_three_state_master_20260821.png",
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
        "candidate_document_cell": [8, 28],
        "component_scene": "res://scenes/maps/components/map01_mountain_tunnel.tscn",
        "state_owner": "external Map01 runtime/save adapter; presentation never writes save data",
        "foreground_faded_alpha": 0.22,
        "layer_contract": {
            "TUNNEL_STAY_BASE": "always visible; owns the invariant left/right shoulder geometry",
            "TUNNEL_ROOF_FOREGROUND": "visual-only top cap; fades independently and never owns collision",
            "state_layers": "center-slot visuals only; selected by external tunnel state",
        },
        "palette": ["#%02x%02x%02x" % color for color in palette],
        "functional_palette": {
            "discovered_dull_ember": "#b54c32",
            "cleared_warm_ivory": "#eee0b5",
        },
        "silhouette_iou": {key: round(value, 6) for key, value in pair_ious.items()},
        "minimum_silhouette_iou": round(minimum_iou, 6),
        "static_collision_rects": [
            {"id": "left_rock_shoulder", "size_source_px": [20, 18], "center_source_px": [-20, -10]},
            {"id": "right_rock_shoulder", "size_source_px": [20, 18], "center_source_px": [20, -10]},
        ],
        "center_barrier_collision": {
            "size_source_px": [16, 18],
            "center_source_px": [0, -10],
            "enabled_in": ["TUNNEL_DEFAULT", "TUNNEL_DISCOVERED"],
            "disabled_in": ["TUNNEL_CLEARED"],
        },
        "layers": {
            layer_id: {
                "path": "res://" + str(path.relative_to(ROOT)),
                "used_rect_px": list(
                    (
                        base if layer_id == "TUNNEL_STAY_BASE"
                        else roof if layer_id == "TUNNEL_ROOF_FOREGROUND"
                        else state_layers[layer_id]
                    ).getbbox()
                ),
            }
            for layer_id, path in layer_paths.items()
        },
        "states": {
            state_id: {
                "source_bbox": list(SOURCE_BBOXES[state_id]),
                "passage_walkable": state_id == "TUNNEL_CLEARED",
                "dull_ember_pixels": _count_color(state_layers[state_id], DULL_EMBER),
                "warm_ivory_pixels": _count_color(state_layers[state_id], WARM_IVORY),
                "composite_used_rect_px": list(composites[state_id].getbbox()),
            }
            for state_id in SOURCE_BBOXES
        },
    }
    manifest_path = OUTPUT_DIR / "map01_mountain_tunnel_manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("Map01 mountain-tunnel extraction OK; layered roof/base and three-state center contract preserved")
    print(f"Source SHA-256: {source_sha256}")
    print(f"Runtime silhouette IoU minimum: {minimum_iou:.6f}")
    print(f"Manifest: {manifest_path}")
    print(f"QA: {QA_DIR / 'map01_tunnel_three_state_contact_sheet.png'}")


if __name__ == "__main__":
    main()
