#!/usr/bin/env python3
"""Compile the user-provided cultivator animation candidates for runtime.

The candidate exports are Godot sprite sheets.  Runtime uses one fixed
172x298 frame contract and a 4x4, 16-frame sheet.  Most exports already have
that size; Mo Yan's flying-sword export is a 480x832-per-cell 4x4 sheet and is
downscaled deterministically without changing its composition.
"""

from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
CANDIDATE_ROOT = ROOT / "art/candidates/cultivator_animations"
RUNTIME_ROOT = ROOT / "assets/camp/ui/expedition/animations"
FRAME_SIZE = (172, 298)
GRID = (4, 4)
SHEET_SIZE = (FRAME_SIZE[0] * GRID[0], FRAME_SIZE[1] * GRID[1])


ANIMATIONS = {
    "shi_yan": {
        "idle": "shi_yan_idle",
        "attack": "shi_yan_attack",
        "defense": "shi_yan_defense",
    },
    "lu_qing": {
        "idle": "lu_qing_idle",
        "attack": "lu_qing_attack",
        "heal": "lu_qing_heal",
        "lei_ji": "lu_qing_lei_ji",
    },
    "bai_ling": {
        "idle": "bai_ling_idle",
        "attack": "bai_ling_attack",
        "heal": "bai_ling_heal",
    },
    "mo_yan": {
        "idle": "mo_yan_idle",
        "fei_jian": "mo_yan_fei_jian",
        "hui_jian": "mo_yan_hui_jian",
    },
}


def compile_sheet(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    source_cell = (image.width // GRID[0], image.height // GRID[1])
    if image.width % GRID[0] or image.height % GRID[1]:
        raise ValueError(f"{source}: sheet is not a 4x4 grid: {image.size}")
    if source_cell == FRAME_SIZE:
        if image.size != SHEET_SIZE:
            raise ValueError(f"{source}: unexpected fixed sheet size {image.size}")
        output = image
    else:
        output = Image.new("RGBA", SHEET_SIZE, (0, 0, 0, 0))
        for index in range(GRID[0] * GRID[1]):
            column = index % GRID[0]
            row = index // GRID[0]
            frame = image.crop(
                (
                    column * source_cell[0],
                    row * source_cell[1],
                    (column + 1) * source_cell[0],
                    (row + 1) * source_cell[1],
                )
            )
            frame = frame.resize(FRAME_SIZE, Image.Resampling.LANCZOS)
            output.alpha_composite(frame, (column * FRAME_SIZE[0], row * FRAME_SIZE[1]))
    destination.parent.mkdir(parents=True, exist_ok=True)
    output.save(destination, optimize=True)


def main() -> None:
    compiled = 0
    for hero_id, actions in ANIMATIONS.items():
        for action, candidate_name in actions.items():
            source = CANDIDATE_ROOT / hero_id / candidate_name / "textures"
            sheets = sorted(source.glob("*_spritesheet.png"))
            if len(sheets) != 1:
                raise FileNotFoundError(f"{source}: expected one spritesheet, found {len(sheets)}")
            destination = RUNTIME_ROOT / hero_id / f"{hero_id}_{action}_sheet.png"
            compile_sheet(sheets[0], destination)
            with Image.open(destination) as result:
                if result.size != SHEET_SIZE or result.mode != "RGBA":
                    raise ValueError(f"{destination}: invalid runtime output {result.size} {result.mode}")
            print(f"COMPILED {destination.relative_to(ROOT)}")
            compiled += 1
    print(f"CULTIVATOR_ANIMATION_RUNTIME_OK count={compiled} frame={FRAME_SIZE} sheet={SHEET_SIZE}")


if __name__ == "__main__":
    main()
