#!/usr/bin/env python3
"""Prepare a compact, transparent Meowa input for Shi Yan's Cast A pilot.

This is a deterministic candidate-input step. It does not call Meowa and does not
write into the runtime assets directory. The existing Shi Yan punch sheet already
contains an action-ready first frame, so use that frame as the animation source
instead of sending the large整备立绘 directly to the animation service.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/source_archive/cultivators/shi_yan/shi_yan_cast_a_source_sheet.png"
OUTPUT = ROOT / (
    "art/candidates/combat_animation_pilot_shi_yan/input/"
    "shi_yan_cast_a_start_86x205.png"
)
PADDED_OUTPUT = ROOT / (
    "art/candidates/combat_animation_pilot_shi_yan/input/"
    "shi_yan_cast_a_start_128x256.png"
)

CANVAS = (86, 205)
CELL_X = (0, 154, 307, 461, 615)
CELL_Y = (0, 231, 462)
TARGET_CONTENT_HEIGHT = 145
SAFE_MARGIN_X = 4
TOP_OFFSET = 4


def main() -> None:
    if not SOURCE.is_file():
        raise SystemExit(f"missing candidate source: {SOURCE}")

    sheet = Image.open(SOURCE).convert("RGBA")
    if sheet.size != (615, 462):
        raise SystemExit(f"unexpected punch sheet size: {sheet.size}")

    # The source is a fixed 4×2 candidate sheet with a one-pixel rounding
    # distribution across columns. Frame 0 is an action-ready palm stance and
    # contains no large impact effect.
    frame = sheet.crop((CELL_X[0], CELL_Y[0], CELL_X[1], CELL_Y[1]))
    bounds = frame.getchannel("A").getbbox()
    if bounds is None:
        raise SystemExit("frame 0 has no visible alpha")
    subject = frame.crop(bounds)

    safe_width = CANVAS[0] - SAFE_MARGIN_X * 2
    scale = min(safe_width / subject.width, TARGET_CONTENT_HEIGHT / subject.height)
    target_size = (
        max(1, round(subject.width * scale)),
        max(1, round(subject.height * scale)),
    )
    # This is a prepared high-resolution identity input, not a runtime sprite.
    # Keep the source's anti-aliased edges for Meowa's animation model; runtime
    # nearest filtering is applied only after a candidate is approved and compiled.
    subject = subject.resize(target_size, Image.Resampling.LANCZOS)

    output = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    x = (CANVAS[0] - subject.width) // 2
    y = TOP_OFFSET
    output.alpha_composite(subject, (x, y))
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    output.save(OUTPUT, optimize=True)

    # Keep the Godot-sized source intact, but also prepare a padded pixel-mode
    # candidate for services that require a minimum short edge. No resampling
    # occurs in this step; the visible 86px subject is copied byte-for-byte.
    padded = Image.new("RGBA", (128, 256), (0, 0, 0, 0))
    padded.alpha_composite(output, ((128 - CANVAS[0]) // 2, 4))
    padded.save(PADDED_OUTPUT, optimize=True)

    print(f"prepared={OUTPUT}")
    print(f"prepared_padded={PADDED_OUTPUT}")
    print(f"source_frame={frame.size} subject={bounds} output={output.size}")


if __name__ == "__main__":
    main()
