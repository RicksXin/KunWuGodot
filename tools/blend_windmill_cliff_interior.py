"""Replace repetitive windmill interiors while preserving generated cliff edges."""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image, ImageChops, ImageFilter, ImageOps


def parse_rgb(value: str) -> tuple[int, int, int]:
    channels = tuple(int(part.strip()) for part in value.split(","))
    if len(channels) != 3 or any(channel < 0 or channel > 255 for channel in channels):
        raise argparse.ArgumentTypeError("base color must contain three channels from 0 to 255")
    return channels


def build_material_tile(
    source: Image.Image,
    tile_size: int,
    base_color: tuple[int, int, int],
    contrast: float,
    delta_limit: int,
    quantize_step: int,
) -> Image.Image:
    material = source.convert("RGB").resize((tile_size, tile_size), Image.Resampling.NEAREST)
    pixels = np.asarray(material, dtype=np.float32)
    luma = pixels[:, :, 0] * 0.2126 + pixels[:, :, 1] * 0.7152 + pixels[:, :, 2] * 0.0722
    delta = (luma - float(luma.mean())) * contrast
    delta = np.round(delta / quantize_step) * quantize_step
    delta = np.clip(delta, -delta_limit, delta_limit)
    base = np.asarray(base_color, dtype=np.float32)[None, None, :]
    output = np.clip(base + delta[:, :, None], 0, 255).astype(np.uint8)
    return Image.fromarray(output, "RGB").convert("RGBA")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("material", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--tile-size", type=int, default=256)
    parser.add_argument("--edge-depth", type=int, default=56)
    parser.add_argument("--edge-feather", type=float, default=10.0)
    parser.add_argument("--base-color", type=parse_rgb, default=(128, 140, 146))
    parser.add_argument("--material-contrast", type=float, default=0.28)
    parser.add_argument("--delta-limit", type=int, default=14)
    parser.add_argument("--quantize-step", type=int, default=4)
    args = parser.parse_args()

    master = Image.open(args.source).convert("RGBA")
    if master.width % args.tile_size or master.height % args.tile_size:
        raise SystemExit("master dimensions must be multiples of tile-size")
    if args.edge_depth < 0 or args.edge_depth > 127:
        raise SystemExit("edge-depth must be between 0 and 127")
    if args.quantize_step <= 0:
        raise SystemExit("quantize-step must be positive")

    alpha = master.getchannel("A").point(lambda value: 255 if value >= 128 else 0)
    material_tile = build_material_tile(
        Image.open(args.material),
        args.tile_size,
        args.base_color,
        args.material_contrast,
        args.delta_limit,
        args.quantize_step,
    )
    replacement = Image.new("RGBA", master.size, (0, 0, 0, 0))
    for y in range(0, master.height, args.tile_size):
        for x in range(0, master.width, args.tile_size):
            replacement.alpha_composite(material_tile, (x, y))

    outside = ImageOps.invert(alpha)
    kernel_size = args.edge_depth * 2 + 1
    edge_weight = outside.filter(ImageFilter.MaxFilter(kernel_size))
    if args.edge_feather > 0:
        edge_weight = edge_weight.filter(ImageFilter.GaussianBlur(args.edge_feather))
    edge_weight = ImageChops.multiply(edge_weight, alpha)

    blended = Image.composite(master, replacement, edge_weight)
    red, green, blue, _ = blended.split()
    output = Image.merge("RGBA", (red, green, blue, alpha))
    transparent = Image.new("RGBA", output.size, (0, 0, 0, 0))
    transparent.paste(output, (0, 0), alpha)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    transparent.save(args.output)
    print(args.output)


if __name__ == "__main__":
    main()
