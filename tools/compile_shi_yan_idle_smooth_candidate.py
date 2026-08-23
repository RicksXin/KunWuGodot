#!/usr/bin/env python3
"""Build a local 16-frame Shi Yan Idle smoothing candidate.

The approved eight HD2x poses stay byte-for-byte unchanged at even frame
indices.  FFmpeg motion interpolation supplies one compensated midpoint between
every adjacent pair, including frame 7 -> frame 0, so 16 frames at 8 FPS
preserve the approved two-second breathing cycle.  Outputs remain candidates
and are never promoted to runtime by this tool.
"""

from __future__ import annotations

from datetime import date
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_SHEET = ROOT / "assets/camp/ui/expedition/animations/shi_yan/shi_yan_idle_sheet.png"
OUTPUT_DIR = ROOT / "art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/smooth_16f_local"
FRAME_SIZE = (172, 410)
LOGICAL_FRAME_SIZE = (86, 205)
SOURCE_GRID = (4, 2)
OUTPUT_GRID = (4, 4)
SOURCE_FPS = 4
OUTPUT_FPS = 8


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def frame_from_sheet(sheet: Image.Image, index: int) -> Image.Image:
    column = index % SOURCE_GRID[0]
    row = index // SOURCE_GRID[0]
    return sheet.crop(
        (
            column * FRAME_SIZE[0],
            row * FRAME_SIZE[1],
            (column + 1) * FRAME_SIZE[0],
            (row + 1) * FRAME_SIZE[1],
        )
    )


def motion_interpolated_frames(source_frames: list[Image.Image]) -> list[Image.Image]:
    """Insert motion-compensated midpoints while preserving source poses exactly."""
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("ffmpeg with the minterpolate filter is required")
    with tempfile.TemporaryDirectory(prefix="kunwu_shi_yan_idle_smooth_") as temp_name:
        temp_dir = Path(temp_name)
        for index, frame in enumerate(source_frames):
            frame.save(temp_dir / f"source_{index:02d}.png", optimize=True)
        output_pattern = temp_dir / "interpolated_%02d.png"
        filter_graph = (
            "[0:v][1:v][2:v]concat=n=3:v=1:a=0,"
            "minterpolate=fps=8:mi_mode=mci:mc_mode=aobmc:me_mode=bidir:vsbmc=1,"
            "setpts=PTS-STARTPTS"
        )
        command = [
            ffmpeg,
            "-hide_banner",
            "-loglevel",
            "error",
            "-framerate",
            str(SOURCE_FPS),
            "-start_number",
            "0",
            "-i",
            str(temp_dir / "source_%02d.png"),
            "-loop",
            "1",
            "-framerate",
            str(SOURCE_FPS),
            "-t",
            str(1.0 / SOURCE_FPS),
            "-i",
            str(temp_dir / "source_00.png"),
            "-loop",
            "1",
            "-framerate",
            str(SOURCE_FPS),
            "-t",
            str(1.0 / SOURCE_FPS),
            "-i",
            str(temp_dir / "source_01.png"),
            "-filter_complex",
            filter_graph,
            "-frames:v",
            "16",
            "-pix_fmt",
            "rgba",
            str(output_pattern),
        ]
        subprocess.run(command, check=True)
        interpolated_paths = [temp_dir / f"interpolated_{index:02d}.png" for index in range(1, 17)]
        if not all(path.is_file() for path in interpolated_paths):
            raise SystemExit("ffmpeg did not produce the expected 16 interpolation frames")
        interpolated = [Image.open(path).convert("RGBA").copy() for path in interpolated_paths]

    smooth_frames: list[Image.Image] = []
    for index, interpolated_frame in enumerate(interpolated):
        if index % 2 == 0:
            smooth_frames.append(source_frames[index // 2].copy())
        else:
            smooth_frames.append(interpolated_frame)
    return smooth_frames


def save_animation(frames: list[Image.Image], path: Path, fps: int) -> None:
    frames[0].save(
        path,
        save_all=True,
        append_images=frames[1:],
        duration=[round(1000 / fps)] * len(frames),
        loop=0,
        disposal=[0] * len(frames),
        blend=[0] * len(frames),
        optimize=True,
    )


def main() -> None:
    if not SOURCE_SHEET.is_file():
        raise SystemExit(f"missing approved Idle sheet: {SOURCE_SHEET}")
    source_sheet = Image.open(SOURCE_SHEET).convert("RGBA")
    expected_sheet_size = (
        FRAME_SIZE[0] * SOURCE_GRID[0],
        FRAME_SIZE[1] * SOURCE_GRID[1],
    )
    if source_sheet.size != expected_sheet_size:
        raise SystemExit(f"unexpected approved Idle sheet size: {source_sheet.size}")

    source_frames = [frame_from_sheet(source_sheet, index) for index in range(8)]
    smooth_frames = motion_interpolated_frames(source_frames)
    transition_sources: list[list[int]] = []
    for index in range(len(source_frames)):
        next_index = (index + 1) % len(source_frames)
        transition_sources.append([index])
        transition_sources.append([index, next_index])

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    frame_outputs: list[str] = []
    for index, frame in enumerate(smooth_frames):
        filename = f"shi_yan_idle_smooth_{index:02d}_172x410.png"
        frame.save(OUTPUT_DIR / filename, optimize=True)
        frame_outputs.append(filename)

    sheet = Image.new(
        "RGBA",
        (FRAME_SIZE[0] * OUTPUT_GRID[0], FRAME_SIZE[1] * OUTPUT_GRID[1]),
        (0, 0, 0, 0),
    )
    for index, frame in enumerate(smooth_frames):
        sheet.alpha_composite(
            frame,
            ((index % OUTPUT_GRID[0]) * FRAME_SIZE[0], (index // OUTPUT_GRID[0]) * FRAME_SIZE[1]),
        )
    sheet_path = OUTPUT_DIR / "shi_yan_idle_smooth_sheet_688x1640.png"
    sheet.save(sheet_path, optimize=True)

    preview_path = OUTPUT_DIR / "shi_yan_idle_smooth_preview_16f_8fps.png"
    save_animation(smooth_frames, preview_path, OUTPUT_FPS)

    comparison_frames: list[Image.Image] = []
    actual_scale_frames: list[Image.Image] = []
    for output_index, smooth_frame in enumerate(smooth_frames):
        source_frame = source_frames[output_index // 2]
        comparison = Image.new("RGBA", (364, 410), (10, 23, 29, 255))
        comparison.alpha_composite(source_frame, (5, 0))
        comparison.alpha_composite(smooth_frame, (187, 0))
        comparison_frames.append(comparison)

        actual_scale = Image.new("RGBA", (184, 205), (10, 23, 29, 255))
        actual_scale.alpha_composite(
            source_frame.resize(LOGICAL_FRAME_SIZE, Image.Resampling.LANCZOS),
            (4, 0),
        )
        actual_scale.alpha_composite(
            smooth_frame.resize(LOGICAL_FRAME_SIZE, Image.Resampling.LANCZOS),
            (94, 0),
        )
        actual_scale_frames.append(actual_scale)

    comparison_path = OUTPUT_DIR / "shi_yan_idle_current_4fps_vs_smooth_8fps.png"
    save_animation(comparison_frames, comparison_path, OUTPUT_FPS)
    actual_scale_path = OUTPUT_DIR / "shi_yan_idle_current_4fps_vs_smooth_8fps_actual_scale.png"
    save_animation(actual_scale_frames, actual_scale_path, OUTPUT_FPS)

    manifest = {
        "asset_id": "combat_ally_shi_yan_idle_breath_smooth_16f_local_candidate",
        "stage": "candidate_timing_refinement",
        "representation": "HD dynamic portrait",
        "provider": "approved runtime Idle + local FFmpeg motion-compensated interpolation",
        "source_path": str(SOURCE_SHEET.relative_to(ROOT)),
        "source_sha256": sha256(SOURCE_SHEET),
        "source_frame_count": len(source_frames),
        "source_fps": SOURCE_FPS,
        "source_cycle_seconds": len(source_frames) / SOURCE_FPS,
        "frame_count": len(smooth_frames),
        "fps": OUTPUT_FPS,
        "cycle_seconds": len(smooth_frames) / OUTPUT_FPS,
        "texture_frame_size": list(FRAME_SIZE),
        "logical_frame_size": list(LOGICAL_FRAME_SIZE),
        "grid": list(OUTPUT_GRID),
        "sheet_size": [sheet.width, sheet.height],
        "interpolation": {
            "method": "FFmpeg minterpolate at 8 FPS",
            "motion_interpolation": "mi_mode=mci, mc_mode=aobmc, me_mode=bidir, vsbmc=1",
            "original_poses_preserved_at_even_indices": True,
            "loop_transition_7_to_0_smoothed": True,
            "transition_sources": transition_sources,
        },
        "godot_texture_filter": "linear",
        "mipmaps": False,
        "loop": True,
        "frame_outputs": frame_outputs,
        "sheet_output": sheet_path.name,
        "sheet_sha256": sha256(sheet_path),
        "review_preview": {
            "output": preview_path.name,
            "format": "animated lossless PNG (APNG)",
            "frame_count": len(smooth_frames),
            "frame_duration_ms": round(1000 / OUTPUT_FPS),
            "sha256": sha256(preview_path),
        },
        "comparison_preview": {
            "output": comparison_path.name,
            "layout": "left=current 8 poses held at 4 FPS; right=16-frame local midpoint candidate at 8 FPS",
            "format": "animated lossless PNG (APNG)",
            "frame_count": len(comparison_frames),
            "frame_duration_ms": round(1000 / OUTPUT_FPS),
            "sha256": sha256(comparison_path),
        },
        "actual_scale_comparison_preview": {
            "output": actual_scale_path.name,
            "layout": "left=current 4 FPS; right=smooth 8 FPS; both at 86x205 logical runtime size",
            "format": "animated lossless PNG (APNG)",
            "frame_count": len(actual_scale_frames),
            "frame_duration_ms": round(1000 / OUTPUT_FPS),
            "sha256": sha256(actual_scale_path),
        },
        "approved_for_runtime": False,
        "compiled_on": date.today().isoformat(),
    }
    manifest_path = OUTPUT_DIR / "manifest.json"
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"sheet={sheet_path}")
    print(f"preview={preview_path}")
    print(f"comparison={comparison_path}")
    print(f"actual_scale_comparison={actual_scale_path}")
    print(f"manifest={manifest_path}")


if __name__ == "__main__":
    main()
