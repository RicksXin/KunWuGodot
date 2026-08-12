#!/usr/bin/env python3

from __future__ import annotations

import math
from collections import deque
from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
ANIMATION_ROOT = ROOT / "assets/camp/ui/expedition/animations"
SOURCE_ROOT = ROOT / "art/source_archive/cobat/utils/allies"
FRAME_SIZE = (86, 149)
GRID_SIZE = (4, 2)
WORK_SCALE = 4
RESAMPLING = Image.Resampling.LANCZOS
TARGET_SUBJECT_HEIGHT = 130
SAFE_MARGIN_X = 4
SAFE_MARGIN_TOP = 4


def _first_frame(sheet_path: Path) -> Image.Image:
    sheet = Image.open(sheet_path).convert("RGBA")
    frame_width = sheet.width // GRID_SIZE[0]
    frame_height = sheet.height // GRID_SIZE[1]
    return sheet.crop((0, 0, frame_width, frame_height))


def _component_mask(alpha: Image.Image, seed: tuple[int, int], threshold: int = 64) -> Image.Image:
    width, height = alpha.size
    pixels = alpha.load()
    visited: set[tuple[int, int]] = set()
    pending: deque[tuple[int, int]] = deque([seed])

    while pending:
        x, y = pending.popleft()
        if (x, y) in visited or not (0 <= x < width and 0 <= y < height):
            continue
        if pixels[x, y] < threshold:
            continue
        visited.add((x, y))
        pending.extend(((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)))

    mask = Image.new("L", alpha.size, 0)
    mask_pixels = mask.load()
    for x, y in visited:
        mask_pixels[x, y] = 255
    return mask.filter(ImageFilter.MaxFilter(7))


def _extract_layer(image: Image.Image, mask: Image.Image) -> tuple[Image.Image, Image.Image]:
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    layer.paste(image, mask=mask)

    body = image.copy()
    body_alpha = body.getchannel("A")
    body_alpha.paste(0, mask=mask)
    body.putalpha(body_alpha)
    return body, layer


def _remove_light_background(image: Image.Image) -> Image.Image:
    """Remove Meowa's opaque light export background without touching dark art."""
    image = image.convert("RGBA")
    width, height = image.size
    pixels = image.load()
    candidate = bytearray(width * height)
    background = bytearray(width * height)
    pending: deque[tuple[int, int]] = deque()

    for y in range(height):
        for x in range(width):
            red, green, blue, alpha = pixels[x, y]
            minimum = min(red, green, blue)
            maximum = max(red, green, blue)
            if alpha > 0 and minimum >= 185 and maximum - minimum <= 24:
                candidate[y * width + x] = 1

    def enqueue(x: int, y: int) -> None:
        index = y * width + x
        if candidate[index] and not background[index]:
            background[index] = 1
            pending.append((x, y))

    for x in range(width):
        enqueue(x, 0)
        enqueue(x, height - 1)
    for y in range(height):
        enqueue(0, y)
        enqueue(width - 1, y)

    while pending:
        x, y = pending.popleft()
        if x > 0:
            enqueue(x - 1, y)
        if x + 1 < width:
            enqueue(x + 1, y)
        if y > 0:
            enqueue(x, y - 1)
        if y + 1 < height:
            enqueue(x, y + 1)

    output = image.copy()
    output_pixels = output.load()
    for y in range(height):
        for x in range(width):
            index = y * width + x
            if background[index]:
                red, green, blue, _alpha = output_pixels[x, y]
                output_pixels[x, y] = (red, green, blue, 0)
                continue
            red, green, blue, alpha = output_pixels[x, y]
            minimum = min(red, green, blue)
            maximum = max(red, green, blue)
            if minimum > 175 and maximum - minimum <= 30:
                matte_alpha = round(max(0.0, min(1.0, (245 - minimum) / 65.0)) * 255)
                output_pixels[x, y] = (red, green, blue, min(alpha, matte_alpha))
    return output


def _content_bounds(image: Image.Image) -> tuple[int, int, int, int]:
    bounds = image.getchannel("A").getbbox()
    if bounds is None:
        raise ValueError("idle portrait source has no visible pixels")
    return bounds


def _fit_work(
    image: Image.Image,
    bounds: tuple[int, int, int, int],
    target_subject_height: int = TARGET_SUBJECT_HEIGHT,
) -> Image.Image:
    """Fit a shared source-space crop without changing its aspect ratio."""
    left, top, right, bottom = bounds
    crop_width = right - left
    crop_height = bottom - top
    safe_width = FRAME_SIZE[0] - SAFE_MARGIN_X * 2
    safe_height = FRAME_SIZE[1] - SAFE_MARGIN_TOP
    requested_height = min(target_subject_height, safe_height)
    scale = min(safe_width / crop_width, requested_height / crop_height)
    output_width = max(1, round(crop_width * scale * WORK_SCALE))
    output_height = max(1, round(crop_height * scale * WORK_SCALE))
    crop = image.crop(bounds).resize((output_width, output_height), RESAMPLING)

    work_size = (FRAME_SIZE[0] * WORK_SCALE, FRAME_SIZE[1] * WORK_SCALE)
    result = Image.new("RGBA", work_size, (0, 0, 0, 0))
    x = (work_size[0] - output_width) // 2
    y = work_size[1] - output_height
    result.alpha_composite(crop, (x, y))
    return result


def _warp_breath(image: Image.Image, phase: float, amplitude_px: float) -> Image.Image:
    width, height = image.size
    amplitude = phase * amplitude_px * WORK_SCALE
    transition_start = height * 0.42
    transition_end = height * 0.69
    rows = 32
    mesh = []

    def weight(y: float) -> float:
        if y <= transition_start:
            return 1.0
        if y >= transition_end:
            return 0.0
        t = (y - transition_start) / (transition_end - transition_start)
        return 1.0 - (t * t * (3.0 - 2.0 * t))

    for row in range(rows):
        y0 = round(row * height / rows)
        y1 = round((row + 1) * height / rows)
        source_y0 = y0 + amplitude * weight(y0)
        source_y1 = y1 + amplitude * weight(y1)
        mesh.append(
            (
                (0, y0, width, y1),
                (0, source_y0, 0, source_y1, width, source_y1, width, source_y0),
            )
        )

    return image.transform(
        image.size,
        Image.Transform.MESH,
        mesh,
        resample=Image.Resampling.BICUBIC,
    )


def _offset_layer(layer: Image.Image, x_px: float, y_px: float) -> Image.Image:
    canvas = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    canvas.alpha_composite(
        layer,
        (round(x_px * WORK_SCALE), round(y_px * WORK_SCALE)),
    )
    return canvas


def _make_sheet(frames: list[Image.Image]) -> Image.Image:
    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * GRID_SIZE[0], FRAME_SIZE[1] * GRID_SIZE[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(frames):
        sheet.alpha_composite(
            frame,
            ((index % GRID_SIZE[0]) * FRAME_SIZE[0], (index // GRID_SIZE[0]) * FRAME_SIZE[1]),
        )
    return sheet


def _compile_shi_yan() -> None:
    output = ANIMATION_ROOT / "shi_yan/shi_yan_idle_sheet.png"
    source = SOURCE_ROOT / "shi_yan/shi_yan_idle_sheet.png"
    body_source = _first_frame(source)
    body = _fit_work(body_source, _content_bounds(body_source))
    frames = []
    for index in range(8):
        phase = math.sin(index * math.tau / 8.0)
        frame = _warp_breath(body, phase, 1.05)
        frames.append(frame.resize(FRAME_SIZE, RESAMPLING))
    _make_sheet(frames).save(output, optimize=True)


def _compile_lu_qing() -> None:
    output = ANIMATION_ROOT / "lu_qing/lu_qing_idle_sheet.png"
    source = _first_frame(SOURCE_ROOT / "lu_qing/法修 2.0.png")
    bounds = _content_bounds(source)
    body, left_disc = _extract_layer(source, _component_mask(source.getchannel("A"), (60, 110)))
    body, right_disc = _extract_layer(body, _component_mask(source.getchannel("A"), (275, 245)))
    body = _fit_work(body, bounds)
    left_disc = _fit_work(left_disc, bounds)
    right_disc = _fit_work(right_disc, bounds)

    frames = []
    for index in range(8):
        phase = math.sin(index * math.tau / 8.0)
        left_phase = math.sin(index * math.tau / 8.0 + math.pi / 3.0)
        right_phase = math.sin(index * math.tau / 8.0 + math.pi * 4.0 / 3.0)
        frame = _warp_breath(body, phase, 0.9)
        frame = Image.alpha_composite(frame, _offset_layer(left_disc, left_phase * 0.35, left_phase * 0.8))
        frame = Image.alpha_composite(frame, _offset_layer(right_disc, -right_phase * 0.3, right_phase * 0.65))
        frames.append(frame.resize(FRAME_SIZE, RESAMPLING))
    _make_sheet(frames).save(output, optimize=True)


def _compile_mo_yan() -> None:
    source_path = SOURCE_ROOT / "mo_yan/mo_yan_idle_source_sheet.png"
    output = ANIMATION_ROOT / "mo_yan/mo_yan_idle_sheet.png"
    output.parent.mkdir(parents=True, exist_ok=True)
    source = Image.open(source_path).convert("RGBA")
    source_frame_size = (368, 640)
    source_frames = []
    for index in range(10):
        x = (index % 4) * source_frame_size[0]
        y = (index // 4) * source_frame_size[1]
        frame = source.crop((x, y, x + source_frame_size[0], y + source_frame_size[1]))
        source_frames.append(_remove_light_background(frame))

    bounds = [_content_bounds(frame) for frame in source_frames]
    shared_bounds = (
        min(bound[0] for bound in bounds),
        min(bound[1] for bound in bounds),
        max(bound[2] for bound in bounds),
        max(bound[3] for bound in bounds),
    )
    # The source has 10 evenly timed frames. Keep the full motion arc while
    # sampling it down to the project's fixed 8-frame idle contract.
    selected_indices = (0, 1, 3, 4, 5, 6, 8, 9)
    frames = []
    for index in selected_indices:
        fitted = _fit_work(source_frames[index], shared_bounds)
        frames.append(fitted.resize(FRAME_SIZE, RESAMPLING))
    _make_sheet(frames).save(output, optimize=True)


def main() -> None:
    _compile_shi_yan()
    _compile_lu_qing()
    _compile_mo_yan()


if __name__ == "__main__":
    main()
