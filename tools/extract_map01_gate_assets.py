#!/usr/bin/env python3
"""Compile the approved Wanxiu Gate concept master into layered pixel assets."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Callable, Iterable

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "art" / "source_archive" / "map01_landmarks" / "map01_gate_three_state_master_20260820.png"
OUTPUT_DIR = ROOT / "assets" / "maps" / "map_01" / "landmarks" / "wanxiu_gate"
QA_DIR = ROOT / "art" / "candidates" / "map01_landmarks" / "compiled"

STATE_BOXES = {
    "locked": (54, 85, 1200, 372),
    "boss_ready": (55, 462, 1200, 749),
    "open": (55, 847, 1200, 1135),
}

CANVAS_SIZE = (128, 40)
ART_SIZE = (120, 30)
ART_OFFSET = (4, 4)
ANCHOR_PX = (64, 36)
ALPHA_THRESHOLD = 128
PALETTE_SIZE = 20

FOREGROUND_BOX = (24, 4, 104, 23)
TITLE_BOX = (44, 7, 84, 24)
STATE_BOX = (45, 17, 84, 39)

STONE_DARK = (48, 61, 70, 255)
STONE_MID = (76, 91, 101, 255)
OLD_GOLD = (151, 126, 82, 255)
PLAQUE_FILL = (177, 157, 116, 255)
IVORY = (238, 224, 181, 255)
NEUTRAL_WHITE = (218, 210, 180, 255)


def _luma(pixel: tuple[int, int, int]) -> float:
    return pixel[0] * 0.2126 + pixel[1] * 0.7152 + pixel[2] * 0.0722


def _compress_luma(pixel: tuple[int, int, int]) -> tuple[int, int, int]:
    value = _luma(pixel)
    target = min(158.0, max(34.0, value))
    delta = target - value
    return tuple(max(0, min(255, round(channel + delta))) for channel in pixel)


def _prepare_state(master: Image.Image, box: tuple[int, int, int, int]) -> Image.Image:
    art = master.crop(box).resize(ART_SIZE, Image.Resampling.NEAREST).convert("RGBA")
    pixels = []
    for red, green, blue, alpha in art.get_flattened_data():
        if alpha < ALPHA_THRESHOLD:
            pixels.append((0, 0, 0, 0))
        else:
            pixels.append((*_compress_luma((red, green, blue)), 255))
    art.putdata(pixels)
    canvas = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    canvas.alpha_composite(art, ART_OFFSET)
    return canvas


def _build_palette(images: Iterable[Image.Image]) -> list[tuple[int, int, int]]:
    samples: list[tuple[int, int, int]] = []
    for image in images:
        samples.extend((r, g, b) for r, g, b, a in image.get_flattened_data() if a)
    strip = Image.new("RGB", (len(samples), 1))
    strip.putdata(samples)
    quantized = strip.quantize(
        colors=PALETTE_SIZE,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    raw = quantized.getpalette()
    used = sorted(set(quantized.get_flattened_data()))
    colors = [tuple(raw[index * 3:index * 3 + 3]) for index in used]
    return sorted(colors, key=_luma)


def _map_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    result = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pixels = []
    for red, green, blue, alpha in image.get_flattened_data():
        if not alpha:
            pixels.append((0, 0, 0, 0))
            continue
        source = (red, green, blue)
        color = min(
            palette,
            key=lambda target: (
                (source[0] - target[0]) ** 2 * 2
                + (source[1] - target[1]) ** 2 * 4
                + (source[2] - target[2]) ** 2 * 3
            ),
        )
        pixels.append((*color, 255))
    result.putdata(pixels)
    return result


def _inside(box: tuple[int, int, int, int], x: int, y: int) -> bool:
    return box[0] <= x < box[2] and box[1] <= y < box[3]


def _masked(source: Image.Image, keep: Callable[[int, int], bool]) -> Image.Image:
    result = Image.new("RGBA", source.size, (0, 0, 0, 0))
    source_pixels = source.load()
    output = result.load()
    for y in range(source.height):
        for x in range(source.width):
            if keep(x, y):
                output[x, y] = source_pixels[x, y]
    return result


def _build_title_marks() -> tuple[Image.Image, list[int]]:
    image = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rectangle((45, 8, 82, 15), fill=OLD_GOLD)
    draw.rectangle((47, 10, 80, 14), fill=STONE_MID)
    notch_positions = [48 + round(index * 32 / 12) for index in range(13)]
    for x in notch_positions:
        draw.rectangle((x, 11, x, 13), fill=IVORY)
    draw.rectangle((49, 16, 78, 23), fill=OLD_GOLD)
    draw.rectangle((51, 18, 76, 21), fill=PLAQUE_FILL)
    draw.line((52, 18, 75, 18), fill=IVORY)
    return image, notch_positions


def _build_open_array() -> Image.Image:
    image = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    for x, direction in ((51, 1), (77, -1)):
        draw.line((x, 23, x + direction * 4, 23), fill=IVORY, width=1)
        draw.line((x, 31, x + direction * 4, 31), fill=IVORY, width=1)
        draw.point((x, 27), fill=OLD_GOLD)
    draw.line((58, 21, 70, 21), fill=NEUTRAL_WHITE, width=1)
    draw.point((64, 22), fill=IVORY)
    draw.rectangle((62, 34, 66, 36), fill=OLD_GOLD)
    draw.rectangle((63, 33, 65, 37), fill=OLD_GOLD)
    draw.rectangle((63, 34, 65, 36), fill=IVORY)
    return image


def _alpha_scaled(image: Image.Image, alpha: float) -> Image.Image:
    result = image.copy()
    channel = result.getchannel("A").point(lambda value: round(value * alpha))
    result.putalpha(channel)
    return result


def _compose(layers: Iterable[Image.Image]) -> Image.Image:
    result = Image.new("RGBA", CANVAS_SIZE, (0, 0, 0, 0))
    for layer in layers:
        result.alpha_composite(layer)
    return result


def _write_contact_sheet(layers: dict[str, Image.Image]) -> None:
    scale = 3
    card_width = 384
    card_height = 188
    sheet = Image.new("RGB", (card_width * 3, card_height * 2), "#0e1217")
    draw = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=16)
    states = (
        ("LOCKED", "gate_locked_seal"),
        ("BOSS_READY", "gate_boss_ready_seal"),
        ("OPEN", "gate_open_array"),
    )
    for column, (label, state_id) in enumerate(states):
        for row, faded in enumerate((False, True)):
            foreground = _alpha_scaled(layers["gate_top_foreground"], 0.22) if faded else layers["gate_top_foreground"]
            preview = _compose((
                layers["gate_stay_base"],
                foreground,
                layers["gate_title_marks"],
                layers[state_id],
            )).resize((CANVAS_SIZE[0] * scale, CANVAS_SIZE[1] * scale), Image.Resampling.NEAREST)
            left = column * card_width
            top = row * card_height
            sheet.paste(preview, (left, top + 40), preview)
            suffix = " · FADE 0.22" if faded else " · FULL"
            draw.text((left + 14, top + 12), label + suffix, fill="#eee8da", font=font)
    QA_DIR.mkdir(parents=True, exist_ok=True)
    sheet.save(QA_DIR / "map01_wanxiu_gate_contact_sheet.png")


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"Missing approved gate master: {SOURCE}")
    master = Image.open(SOURCE).convert("RGBA")
    states = {state: _prepare_state(master, box) for state, box in STATE_BOXES.items()}
    palette = _build_palette(states.values())
    states = {state: _map_palette(image, palette) for state, image in states.items()}

    locked = states["locked"]
    layers = {
        "gate_stay_base": _masked(
            locked,
            lambda x, y: not _inside(FOREGROUND_BOX, x, y)
            and not _inside(TITLE_BOX, x, y)
            and not _inside(STATE_BOX, x, y),
        ),
        "gate_top_foreground": _masked(
            locked,
            lambda x, y: _inside(FOREGROUND_BOX, x, y) and not _inside(TITLE_BOX, x, y),
        ),
        "gate_locked_seal": _masked(states["locked"], lambda x, y: _inside(STATE_BOX, x, y)),
        "gate_boss_ready_seal": _masked(states["boss_ready"], lambda x, y: _inside(STATE_BOX, x, y)),
        "gate_open_array": _build_open_array(),
    }
    title_marks, notch_positions = _build_title_marks()
    layers["gate_title_marks"] = title_marks

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for asset_id, image in layers.items():
        image.save(OUTPUT_DIR / f"{asset_id}.png", optimize=True)

    manifest = {
        "version": 1,
        "approved_date": "2026-08-20",
        "source_master": "res://art/source_archive/map01_landmarks/map01_gate_three_state_master_20260820.png",
        "canvas_px": list(CANVAS_SIZE),
        "anchor_px": list(ANCHOR_PX),
        "source_pixel_per_logical_cell": 16,
        "runtime_display_scale": 3,
        "map_scene_root_scale": 0.1875,
        "map_scene_instance_scale": 16,
        "visual_footprint_cells": [7.5, 2.0],
        "component_scene": "res://scenes/maps/components/wanxiu_gate.tscn",
        "state_source_contract": "external product state; never inferred from artwork or collision",
        "notch_count": 13,
        "notch_positions_x": notch_positions,
        "notch_sample_y": 12,
        "palette": ["#%02x%02x%02x" % color for color in palette],
        "layers": {
            asset_id: f"res://assets/maps/map_01/landmarks/wanxiu_gate/{asset_id}.png"
            for asset_id in layers
        },
        "state_contract": {
            "GATE_LOCKED": {"state_layer": "gate_locked_seal", "center_passage_walkable": False},
            "GATE_BOSS_READY": {"state_layer": "gate_boss_ready_seal", "center_passage_walkable": False},
            "GATE_OPEN": {"state_layer": "gate_open_array", "center_passage_walkable": True},
        },
        "layer_contract": {
            "gate_stay_base": "always visible; outer foundation collision is invariant",
            "gate_top_foreground": "fadeable visual only; source alpha remains binary",
            "gate_title_marks": "always above foreground; Godot renders the real title text separately",
            "state_layers": "visual state only; collision state is configured independently",
        },
        "collision_contract_source_px": {
            "left_foundation": [4, 17, 46, 17],
            "right_foundation": [78, 17, 46, 17],
            "center_barrier": [50, 20, 28, 14],
        },
    }
    (OUTPUT_DIR / "wanxiu_gate_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    _write_contact_sheet(layers)
    print("Wanxiu Gate extraction OK; 6 layered sprites, 3 states, 13 notches")
    print(f"Manifest: {OUTPUT_DIR / 'wanxiu_gate_manifest.json'}")
    print(f"QA: {QA_DIR / 'map01_wanxiu_gate_contact_sheet.png'}")


if __name__ == "__main__":
    main()
