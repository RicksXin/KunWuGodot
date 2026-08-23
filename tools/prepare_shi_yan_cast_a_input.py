#!/usr/bin/env python3
"""Prepare a crisp, transparent Meowa input for Shi Yan's Cast A pilot.

This is a deterministic candidate-input step. It does not call Meowa and does not
write into the runtime assets directory. The existing Shi Yan cast sheet already
contains an action-ready first frame, so use that frame as the animation source
without shrinking it to the runtime slot before sending it to the service.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source_archive/cultivators/shi_yan/shi_yan_cast_a_source_sheet.png"
OUTPUT = ROOT / (
    "art/candidates/combat_animation_pilot_shi_yan/input/"
    "shi_yan_cast_a_start_128x256_crisp.png"
)

CANVAS = (128, 256)
CELL_X = (0, 154, 307, 461, 615)
CELL_Y = (0, 231, 462)
SAFE_MARGIN_X = 4
TOP_OFFSET = 4


def _harden_alpha(image: Image.Image, threshold: int = 128) -> Image.Image:
    """Remove semi-transparent edge pixels from the pixel-art source."""
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)
    image.putalpha(alpha)
    return image


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing candidate source: {SOURCE}")

    sheet = Image.open(SOURCE).convert("RGBA")
    if sheet.size != (615, 462):
        raise SystemExit(f"unexpected punch sheet size: {sheet.size}")

    # The source is a fixed 4×2 candidate sheet with a one-pixel rounding
    # distribution across columns. Frame 0 is an action-ready palm stance and
    # contains no large impact effect.
    frame = _harden_alpha(sheet.crop((CELL_X[0], CELL_Y[0], CELL_X[1], CELL_Y[1])))
    bounds = frame.getchannel("A").getbbox()
    if bounds is None:
        raise SystemExit("frame 0 has no visible alpha")
    subject = frame.crop(bounds)

    safe_width = CANVAS[0] - SAFE_MARGIN_X * 2
    safe_height = CANVAS[1] - TOP_OFFSET
    if subject.width > safe_width or subject.height > safe_height:
        raise SystemExit(
            "native subject does not fit the service canvas; choose a larger "
            "approved canvas instead of applying a smoothing resize"
        )

    output = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    x = (CANVAS[0] - subject.width) // 2
    y = TOP_OFFSET
    output.alpha_composite(subject, (x, y))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT, optimize=True)

    print(f"prepared={OUTPUT}")
    print(f"source_frame={frame.size} subject_bbox={bounds} subject_size={subject.size} output={output.size}")


if __name__ == "__main__":
    main()
