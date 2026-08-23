#!/usr/bin/env python3
"""Build deterministic review images for a generated Map01 visual mother.

The generated picture is treated only as visual reference. This tool resizes it
to the formal 768x1024 Map01 board, overlays the true 48x64 grid, and draws four
one-cell marker placeholders for readability review. It does not produce a
runtime asset or modify layout, collision, scenes, or product data.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps


BOARD_SIZE = (768, 1024)
BOARD_CELLS = (48, 64)
CELL_SIZE = 16
VIEWPORT_SIZE = (375, 817)

# Greybox candidate anchors in top-left scene coordinates. They are review
# samples only and remain UNVERIFIED for the future 1.0 object table.
MARKERS = (
    ("E", (24, 61), "#d9c26c"),
    ("!", (31, 49), "#d26863"),
    ("?", (24, 36), "#b797d8"),
    ("C", (38, 23), "#e0b75c"),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def review_background(source: Image.Image, size: tuple[int, int] = BOARD_SIZE) -> Image.Image:
    """Quiet the concept art slightly so overlay legibility is measurable."""
    image = source.convert("RGB").resize(size, Image.Resampling.LANCZOS)
    image = ImageEnhance.Contrast(image).enhance(0.88)
    image = ImageEnhance.Color(image).enhance(0.82)
    return image.convert("RGBA")


def font(size: int) -> ImageFont.ImageFont:
    candidates = (
        "/System/Library/Fonts/SFNS.ttf",
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf",
    )
    for candidate in candidates:
        try:
            return ImageFont.truetype(candidate, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


def draw_grid(image: Image.Image, cell_size: int = CELL_SIZE) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    minor = (226, 234, 232, 58)
    major = (232, 239, 235, 102)
    for x in range(BOARD_CELLS[0] + 1):
        px = min(x * cell_size, image.size[0] - 1)
        fill = major if x % 4 == 0 else minor
        draw.line((px, 0, px, image.size[1] - 1), fill=fill, width=1)
    for y in range(BOARD_CELLS[1] + 1):
        py = min(y * cell_size, image.size[1] - 1)
        fill = major if y % 4 == 0 else minor
        draw.line((0, py, image.size[0] - 1, py), fill=fill, width=1)
    draw.rectangle((0, 0, image.size[0] - 1, image.size[1] - 1), outline=(241, 245, 240, 155), width=2)


def draw_markers(image: Image.Image, cell_size: int = CELL_SIZE) -> None:
    draw = ImageDraw.Draw(image, "RGBA")
    marker_font = font(max(10, round(cell_size * 0.62)))
    for symbol, (cell_x, cell_y), color in MARKERS:
        left = cell_x * cell_size
        top = cell_y * cell_size
        right = left + cell_size - 1
        bottom = top + cell_size - 1
        rgb = tuple(int(color[i : i + 2], 16) for i in (1, 3, 5))
        inset = max(1, round(cell_size * 0.06))
        circle_inset = max(4, round(cell_size * 0.25))
        draw.rectangle((left + inset, top + inset, right - inset, bottom - inset), fill=(*rgb, 78), outline=(*rgb, 255), width=max(2, round(cell_size / 16)))
        draw.ellipse((left + circle_inset, top + circle_inset, right - circle_inset, bottom - circle_inset), fill=(*rgb, 255), outline=(18, 25, 29, 255), width=max(1, round(cell_size / 24)))
        bbox = draw.textbbox((0, 0), symbol, font=marker_font)
        width = bbox[2] - bbox[0]
        height = bbox[3] - bbox[1]
        draw.text(
            (left + (cell_size - width) / 2, top + (cell_size - height) / 2 - bbox[1]),
            symbol,
            font=marker_font,
            fill=(20, 27, 31, 255),
        )


def overview_fit_preview(board: Image.Image) -> Image.Image:
    """Show the complete 3:4 map inside a 375x817 mobile canvas."""
    canvas = Image.new("RGBA", VIEWPORT_SIZE, "#182126")
    fit_width = 360
    fit_height = round(BOARD_SIZE[1] * fit_width / BOARD_SIZE[0])
    fitted = board.resize((fit_width, fit_height), Image.Resampling.LANCZOS)
    canvas.alpha_composite(fitted, ((VIEWPORT_SIZE[0] - fit_width) // 2, 112))
    return canvas


def runtime_viewport_preview(source: Image.Image) -> Image.Image:
    """Crop the board at the project's real 48px logical-cell scale."""
    world = review_background(source, (BOARD_SIZE[0] * 3, BOARD_SIZE[1] * 3))
    draw_grid(world, 48)
    draw_markers(world, 48)
    focus_cell = (24, 36)
    focus = ((focus_cell[0] + 0.5) * 48, (focus_cell[1] + 0.5) * 48)
    left = round(focus[0] - VIEWPORT_SIZE[0] / 2)
    top = round(focus[1] - VIEWPORT_SIZE[1] / 2)
    return world.crop((left, top, left + VIEWPORT_SIZE[0], top + VIEWPORT_SIZE[1]))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source)
    board = review_background(source)
    draw_grid(board)
    draw_markers(board)

    args.output_dir.mkdir(parents=True, exist_ok=True)
    board_path = args.output_dir / "map01_visual_plane_gpt_v1_grid_marker_review.png"
    gray_path = args.output_dir / "map01_visual_plane_gpt_v1_grid_marker_review_gray.png"
    overview_fit_path = args.output_dir / "map01_visual_plane_gpt_v1_overview_fit_375x817.png"
    viewport_path = args.output_dir / "map01_visual_plane_gpt_v1_runtime_viewport_375x817.png"
    manifest_path = args.output_dir / "map01_visual_plane_gpt_v1_review_manifest.json"

    board.save(board_path, format="PNG", optimize=False)
    ImageOps.grayscale(board).convert("RGBA").save(gray_path, format="PNG", optimize=False)
    overview_fit_preview(board).save(overview_fit_path, format="PNG", optimize=False)
    runtime_viewport_preview(source).save(viewport_path, format="PNG", optimize=False)
    manifest_path.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "status": "candidate_visual_review_only",
                "supplier": "ChatGPT, user-executed",
                "source": str(args.source),
                "source_sha256": sha256(args.source),
                "source_size": list(source.size),
                "source_mode": source.mode,
                "review_board": "48x64 cells at 16px, 768x1024",
                "processing": "Lanczos resize, contrast 0.88, saturation 0.82, deterministic grid and placeholder markers",
                "marker_coordinates": "greybox candidate anchors; UNVERIFIED; review only",
                "runtime_asset": False,
                "formal_scene_modified": False,
                "meowa_points_spent": 0,
                "outputs": [str(board_path), str(gray_path), str(overview_fit_path), str(viewport_path)],
            },
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    print(f"MAP01_VISUAL_PLANE_REVIEW_OK board={board_path} viewport={viewport_path}")


if __name__ == "__main__":
    main()
