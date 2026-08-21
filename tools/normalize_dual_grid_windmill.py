"""Normalize a generated windmill master onto the fixed Dual Grid geometry.

The source may have the correct topology but uneven AI-generated cell widths.
This tool performs a deterministic piecewise-nearest warp from five measured
source anchors onto a 4x4 grid, then applies the canonical occupancy mask and
hardens alpha for nearest-filtered pixel art.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw


DEFAULT_LOGIC_GRID = [
    [0, 1, 0, 0],
    [0, 1, 1, 1],
    [1, 1, 1, 0],
    [0, 0, 1, 0],
]


def parse_anchors(value: str) -> list[int]:
    try:
        anchors = [int(part.strip()) for part in value.split(",")]
    except ValueError as error:
        raise argparse.ArgumentTypeError("anchors must be comma-separated integers") from error
    if len(anchors) != 5:
        raise argparse.ArgumentTypeError("exactly five anchors are required")
    if any(left >= right for left, right in zip(anchors, anchors[1:])):
        raise argparse.ArgumentTypeError("anchors must be strictly increasing")
    return anchors


def validate_anchors(anchors: list[int], extent: int, axis: str) -> None:
    if anchors[0] != 0 or anchors[-1] != extent:
        raise SystemExit(f"{axis} anchors must start at 0 and end at {extent}: {anchors}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--x-anchors", type=parse_anchors, required=True)
    parser.add_argument("--y-anchors", type=parse_anchors, required=True)
    parser.add_argument("--tile-size", type=int, default=256)
    parser.add_argument("--alpha-threshold", type=int, default=128)
    args = parser.parse_args()

    source = Image.open(args.source).convert("RGBA")
    validate_anchors(args.x_anchors, source.width, "x")
    validate_anchors(args.y_anchors, source.height, "y")
    if not 0 <= args.alpha_threshold <= 255:
        raise SystemExit("alpha threshold must be between 0 and 255")

    size = args.tile_size * 4
    warped = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    for row in range(4):
        for col in range(4):
            source_box = (
                args.x_anchors[col],
                args.y_anchors[row],
                args.x_anchors[col + 1],
                args.y_anchors[row + 1],
            )
            tile = source.crop(source_box).resize(
                (args.tile_size, args.tile_size),
                Image.Resampling.NEAREST,
            )
            warped.alpha_composite(tile, (col * args.tile_size, row * args.tile_size))

    topology = Image.new("L", (size, size), 0)
    draw = ImageDraw.Draw(topology)
    for row, values in enumerate(DEFAULT_LOGIC_GRID):
        for col, occupied in enumerate(values):
            if occupied:
                left = col * args.tile_size
                top = row * args.tile_size
                draw.rectangle(
                    (left, top, left + args.tile_size - 1, top + args.tile_size - 1),
                    fill=255,
                )

    source_alpha = warped.getchannel("A").point(
        lambda value: 255 if value >= args.alpha_threshold else 0
    )
    final_alpha = ImageChops.multiply(source_alpha, topology)

    red, green, blue, _ = warped.split()
    output = Image.merge("RGBA", (red, green, blue, final_alpha))
    transparent = Image.new("RGBA", output.size, (0, 0, 0, 0))
    transparent.paste(output, (0, 0), final_alpha)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    transparent.save(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
