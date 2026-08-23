#!/usr/bin/env python3
"""Prepare deterministic ChatGPT inputs for the Map01 HD derelict-camp trial.

This tool does not generate art. It packages the approved camp's structural
language, the new layered-board palette, and an explicit 5x3 candidate
placement contract for the user's ChatGPT member workflow.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


CELL_SIZE = 48
MAP_SIZE = (48, 64)
ANCHOR_CELL = (31, 49)
VISUAL_CELLS = tuple((x, y) for y in range(47, 50) for x in range(29, 34))
BLOCKED_CELLS = VISUAL_CELLS
INTERACTION_CELLS = ((31, 50),)
CONTEXT_ORIGIN = (25, 43)
CONTEXT_CELLS = (12, 12)
RUNTIME_SIZE = (240, 144)


PROMPT = """# Map01 高清废营静态底座：ChatGPT 生成任务

请在同一次对话中按以下顺序上传三张图片：

1. `map01_derelict_camp_hd_style_context.png`
   - 只用于匹配 Map01 新底图的灰青、枯黄、低饱和色盘、俯视角和细节密度。
   - 不要复制其中的地面、道路、网格或地图轮廓。
2. `map01_derelict_camp_hd_structure_reference.png`
   - 这是旧版 Approved 废营底座，只参考“两座塌帐、倒伏暗红营旗、破损补给架”的构成关系。
   - 不要复制它的低分辨率像素、锯齿或旧色盘。
3. `map01_derelict_camp_hd_placement_contract.png`
   - 青色/红色覆盖区表示建筑严格限制在 5×3 格的视觉与阻挡范围；金色单格是建筑下方交互格。
   - 这些色块、线框和网格只是尺寸说明，绝不能出现在生成结果中。

复制下面整段提示词提交：

```text
为 Godot 俯视地图 Map01“破禁山麓·万修之门”生成一个独立高清建筑候选：CAMP_STAY_BASE_HD（废弃营地静态底座）。本次只生成一张单独素材，不生成状态表、联系表、地图或多版本拼图。

参考图职责：
- 图片1只定义地图的灰青石地、枯黄旧路、低饱和光照和高清纹理密度；不要复制任何地面。
- 图片2只定义废营的主体构成：两座低矮塌陷的灰褐帆布帐篷顶、一面完全倒伏在地的暗红旧营旗与低矮断木横杆、一个破损补给木架；不要复制旧版像素锯齿。
- 图片3只定义5×3格外接尺寸和下方单格交互位置；不要把彩色覆盖、网格或线框画进素材。

主体要求：
- 严格接近90度正上方俯视，所有物体都像平铺在地图平面上。
- 两座帐篷已经坍塌，只表现帆布顶部褶皱、断裂支杆顶部和压低的轮廓；不能出现帐篷正面、入口立面或侧墙。
- 暗红营旗必须完全倒伏，贴地横放在断木旁；没有可读徽记、文字或直立旗杆。
- 补给架低矮、破损、体量克制。右侧保留约一格安静空间，供未来叠加“尸首证据”状态，但不能画成规则插槽或空白UI区。
- 主体整体外接比例严格接近5:3，构图紧凑，四周保留少量真实透明留白；底部中央作为未来锚点，不能有越界长杆或阴影。

美术风格：
- 高清手绘2D游戏地图素材，不是像素画，也不是照片写实。
- 轮廓清楚、材质可信但纹理克制，缩小到240×144像素后仍能一眼识别。
- 色盘限制为灰蓝、旧帆布灰褐、风化木色、少量枯金与非常克制的暗红；光照平、柔和、无方向性投影。
- 与图片1的背景融合，但建筑轮廓需比地面略深、略清晰，不能靠白边、黑色粗描边或外发光分离。

输出要求：
- 只输出一张完整的 CAMP_STAY_BASE_HD。
- 真实透明 RGBA 背景，主体外没有地面、道路、网格、底盘或环境贴图。
- 主体完整，不裁边；优先横向3:2画布，如果只能生成方图，也要让主体在中央保持5:3外接比例和充足透明边距。
- 必须下载原始PNG，不要截图、JPG或网页缩略图。

禁止：
人物、尸体、尸布、血迹、粮册、书页、宝箱、资源、敌人、Marker、篝火、烟、发光、粒子、法阵、文字、数字、徽标、道路、石地、森林、山体、建筑底盘、棋盘格、绿色键色、白色贴纸边、黑色厚描边、等距视角、2.5D视角、帐篷侧面、帐篷正门、竖直旗帜、长投影、水印、logo、多版本排版。
```

生成数量：1 张。

下载文件建议命名：`map01_derelict_camp_hd_base_gpt_v1.png`。
"""


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_cells(rows: list[str]) -> None:
    for name, cells in {
        "visual": VISUAL_CELLS,
        "blocked": BLOCKED_CELLS,
        "interaction": INTERACTION_CELLS,
    }.items():
        for x, y in cells:
            if not (0 <= x < MAP_SIZE[0] and 0 <= y < MAP_SIZE[1]):
                raise ValueError(f"{name} cell out of bounds: {(x, y)}")
            if rows[y][x] not in ".=~":
                raise ValueError(f"{name} cell is not walkable greybox ground: {(x, y)}={rows[y][x]}")


def board_composite(base_path: Path, grid_path: Path) -> Image.Image:
    base = Image.open(base_path).convert("RGBA")
    grid = Image.open(grid_path).convert("RGBA")
    if base.size != (MAP_SIZE[0] * CELL_SIZE, MAP_SIZE[1] * CELL_SIZE):
        raise ValueError(f"Unexpected Map01 base size: {base.size}")
    if grid.size != base.size:
        raise ValueError(f"Grid/base size mismatch: grid={grid.size} base={base.size}")
    return Image.alpha_composite(base, grid)


def crop_context(board: Image.Image) -> Image.Image:
    left = CONTEXT_ORIGIN[0] * CELL_SIZE
    top = CONTEXT_ORIGIN[1] * CELL_SIZE
    width = CONTEXT_CELLS[0] * CELL_SIZE
    height = CONTEXT_CELLS[1] * CELL_SIZE
    return board.crop((left, top, left + width, top + height))


def placement_guide(context: Image.Image) -> Image.Image:
    overlay = Image.new("RGBA", context.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay, "RGBA")
    origin_x, origin_y = CONTEXT_ORIGIN

    for x, y in BLOCKED_CELLS:
        left = (x - origin_x) * CELL_SIZE
        top = (y - origin_y) * CELL_SIZE
        draw.rectangle(
            (left, top, left + CELL_SIZE - 1, top + CELL_SIZE - 1),
            fill=(209, 68, 63, 54),
            outline=(236, 104, 91, 150),
            width=1,
        )

    visual_left = (29 - origin_x) * CELL_SIZE
    visual_top = (47 - origin_y) * CELL_SIZE
    visual_right = visual_left + RUNTIME_SIZE[0] - 1
    visual_bottom = visual_top + RUNTIME_SIZE[1] - 1
    draw.rectangle(
        (visual_left, visual_top, visual_right, visual_bottom),
        outline=(89, 213, 224, 255),
        width=3,
    )

    for x, y in INTERACTION_CELLS:
        left = (x - origin_x) * CELL_SIZE
        top = (y - origin_y) * CELL_SIZE
        draw.rectangle(
            (left + 2, top + 2, left + CELL_SIZE - 3, top + CELL_SIZE - 3),
            fill=(219, 181, 84, 42),
            outline=(240, 201, 103, 255),
            width=3,
        )

    anchor_x = (ANCHOR_CELL[0] + 0.5 - origin_x) * CELL_SIZE
    anchor_y = (ANCHOR_CELL[1] + 1.0 - origin_y) * CELL_SIZE
    draw.ellipse(
        (anchor_x - 6, anchor_y - 6, anchor_x + 6, anchor_y + 6),
        fill=(242, 245, 239, 255),
        outline=(23, 31, 36, 255),
        width=2,
    )
    return Image.alpha_composite(context, overlay)


def structure_reference(camp_base_path: Path) -> Image.Image:
    source = Image.open(camp_base_path).convert("RGBA")
    if source.size != (96, 56):
        raise ValueError(f"Unexpected Approved camp base size: {source.size}")
    enlarged = source.resize((768, 448), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    canvas.alpha_composite(enlarged, ((1024 - enlarged.width) // 2, (1024 - enlarged.height) // 2))
    return canvas


def existing_reuse_viewport(
    board: Image.Image,
    camp_base_path: Path,
    camp_overlay_path: Path,
) -> Image.Image:
    viewport_size = (375, 817)
    anchor_world = (
        (ANCHOR_CELL[0] + 0.5) * CELL_SIZE,
        (ANCHOR_CELL[1] + 1.0) * CELL_SIZE,
    )
    left = round(anchor_world[0] - viewport_size[0] / 2)
    top = round(anchor_world[1] - viewport_size[1] / 2)
    viewport = board.crop((left, top, left + viewport_size[0], top + viewport_size[1]))

    approved = Image.alpha_composite(
        Image.open(camp_base_path).convert("RGBA"),
        Image.open(camp_overlay_path).convert("RGBA"),
    ).resize((288, 168), Image.Resampling.NEAREST)
    sprite_left = round(anchor_world[0] - 48 * 3 - left)
    sprite_top = round(anchor_world[1] - 52 * 3 - top)
    viewport.alpha_composite(approved, (sprite_left, sprite_top))
    return viewport


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--board-base", type=Path, required=True)
    parser.add_argument("--grid", type=Path, required=True)
    parser.add_argument("--mask", type=Path, required=True)
    parser.add_argument("--approved-base", type=Path, required=True)
    parser.add_argument("--approved-default-overlay", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    mask = json.loads(args.mask.read_text(encoding="utf-8"))
    rows = mask.get("rows")
    if not isinstance(rows, list) or len(rows) != MAP_SIZE[1]:
        raise ValueError("Map01 mask does not contain 64 rows")
    validate_cells(rows)

    output_dir = args.output_dir
    reference_dir = output_dir / "reference"
    review_dir = output_dir / "review"
    reference_dir.mkdir(parents=True, exist_ok=True)
    review_dir.mkdir(parents=True, exist_ok=True)

    board = board_composite(args.board_base, args.grid)
    context = crop_context(board)
    style_path = reference_dir / "map01_derelict_camp_hd_style_context.png"
    placement_path = reference_dir / "map01_derelict_camp_hd_placement_contract.png"
    structure_path = reference_dir / "map01_derelict_camp_hd_structure_reference.png"
    reuse_path = review_dir / "map01_derelict_camp_existing_approved_reuse_375x817.png"
    prompt_path = output_dir / "map01_derelict_camp_hd_gpt_prompt.md"
    contract_path = output_dir / "map01_derelict_camp_hd_asset_contract.json"

    context.resize((1024, 1024), Image.Resampling.LANCZOS).save(style_path)
    placement_guide(context).resize((1024, 1024), Image.Resampling.LANCZOS).save(placement_path)
    structure_reference(args.approved_base).save(structure_path)
    existing_reuse_viewport(board, args.approved_base, args.approved_default_overlay).save(reuse_path)
    prompt_path.write_text(PROMPT, encoding="utf-8")

    contract = {
        "schema_version": 1,
        "status": "candidate_generation_input_only",
        "asset_id": "map01_derelict_camp_hd_base",
        "purpose": "HD visual trial over the new layered Map01 board; preserves the Approved camp's subject and state architecture",
        "coordinate_contract": "top-left scene cells; x grows right; y grows down",
        "logical_size_cells": [5, 3],
        "runtime_delivery_size_px": list(RUNTIME_SIZE),
        "alpha": "true RGBA; no baked ground, grid, marker, shadow, or environment",
        "anchor_cell": list(ANCHOR_CELL),
        "anchor_px": [120, 144],
        "anchor_rule": "bottom-center boundary of the 5x3 visual footprint",
        "visual_cells": [list(cell) for cell in VISUAL_CELLS],
        "blocked_cells": [list(cell) for cell in BLOCKED_CELLS],
        "interaction_cells": [list(cell) for cell in INTERACTION_CELLS],
        "states_this_generation": ["CAMP_STAY_BASE_HD"],
        "future_layers_not_generated": [
            "CAMP_CORPSES_DEFAULT_HD_OVERLAY",
            "CAMP_CORPSES_PROCESSED_HD_OVERLAY",
            "one-cell runtime marker",
        ],
        "approved_structure_source": {
            "path": str(args.approved_base),
            "sha256": sha256(args.approved_base),
            "reuse_decision": "Reuse its subject/state contract; evaluate an HD visual replacement only because it visibly mismatches the new HD plane.",
        },
        "generation": {
            "supplier": "ChatGPT member webpage, user-executed",
            "count": 1,
            "suggested_download_name": "map01_derelict_camp_hd_base_gpt_v1.png",
            "prompt_path": str(prompt_path),
            "upload_order": [str(style_path), str(structure_path), str(placement_path)],
        },
        "formal_status": "UNVERIFIED",
        "known_coordinate_conflict": "Candidate cell (31,49) was also used by an ordinary encounter in the historical object table; this trial keeps the camp and modifies no formal object coordinates.",
        "runtime_asset": False,
        "formal_scene_modified": False,
        "meowa_points_spent": 0,
        "outputs": [
            {"path": str(path), "sha256": sha256(path)}
            for path in (style_path, structure_path, placement_path, reuse_path, prompt_path)
        ],
    }
    contract_path.write_text(json.dumps(contract, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(
        "MAP01_DERELICT_CAMP_HD_INPUT_OK "
        f"visual={len(VISUAL_CELLS)} blocked={len(BLOCKED_CELLS)} interaction={len(INTERACTION_CELLS)}"
    )


if __name__ == "__main__":
    main()
