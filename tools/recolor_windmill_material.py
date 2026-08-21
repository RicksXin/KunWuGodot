"""Recolor a validated RGBA windmill while preserving its exact geometry.

This is intended for related Dual Grid terrain families that must share the
same topology and hard alpha edge. It remaps only occupied RGB pixels through
a low-contrast, quantized luminance ramp; alpha is copied as binary 0/255.
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def parse_rgb(value: str) -> tuple[int, int, int]:
    try:
        channels = tuple(int(part.strip()) for part in value.split(","))
    except ValueError as error:
        raise argparse.ArgumentTypeError("color must be R,G,B") from error
    if len(channels) != 3 or any(channel < 0 or channel > 255 for channel in channels):
        raise argparse.ArgumentTypeError("color must contain three channels from 0 to 255")
    return channels


def clamp(value: int, low: int, high: int) -> int:
    return max(low, min(high, value))


def luma(red: int, green: int, blue: int) -> float:
    return red * 0.2126 + green * 0.7152 + blue * 0.0722


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--base-color", type=parse_rgb, required=True)
    parser.add_argument("--contrast", type=float, default=0.52)
    parser.add_argument("--quantize-step", type=int, default=4)
    parser.add_argument("--delta-limit", type=int, default=20)
    parser.add_argument("--alpha-threshold", type=int, default=128)
    args = parser.parse_args()

    if args.quantize_step <= 0:
        raise SystemExit("quantize step must be positive")
    if args.delta_limit < 0:
        raise SystemExit("delta limit cannot be negative")
    if not 0 <= args.alpha_threshold <= 255:
        raise SystemExit("alpha threshold must be between 0 and 255")

    source = Image.open(args.source).convert("RGBA")
    occupied = [
        luma(red, green, blue)
        for red, green, blue, alpha in source.getdata()
        if alpha >= args.alpha_threshold
    ]
    if not occupied:
        raise SystemExit("source contains no occupied pixels")
    mean_luma = sum(occupied) / len(occupied)

    output = Image.new("RGBA", source.size, (0, 0, 0, 0))
    output_pixels = output.load()
    source_pixels = source.load()
    for y in range(source.height):
        for x in range(source.width):
            red, green, blue, alpha = source_pixels[x, y]
            if alpha < args.alpha_threshold:
                continue
            raw_delta = (luma(red, green, blue) - mean_luma) * args.contrast
            delta = round(raw_delta / args.quantize_step) * args.quantize_step
            delta = clamp(delta, -args.delta_limit, args.delta_limit)
            output_pixels[x, y] = (
                clamp(args.base_color[0] + delta, 0, 255),
                clamp(args.base_color[1] + delta, 0, 255),
                clamp(args.base_color[2] + delta, 0, 255),
                255,
            )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
