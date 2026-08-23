#!/usr/bin/env python3
"""Prepare the v2, larger HD derelict-camp GPT input package.

This is a generation-input and review package only. It does not generate art,
change the formal Map01 scene, or promote a candidate into assets/.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


MAP_SIZE = (48, 64)
CELL_SIZE = 48
ANCHOR_CELL = (31, 49)
VISUAL_ORIGIN = (28, 45)
VISUAL_SIZE_CELLS = (7, 5)
VISUAL_CELLS = tuple(
    (x, y)
    for y in range(VISUAL_ORIGIN[1], VISUAL_ORIGIN[1] + VISUAL_SIZE_CELLS[1])
    for x in range(VISUAL_ORIGIN[0], VISUAL_ORIGIN[0] + VISUAL_SIZE_CELLS[0])
)
BLOCKED_CELLS = VISUAL_CELLS
INTERACTION_CELLS = ((31, 50),)
CONTEXT_ORIGIN = (24, 41)
CONTEXT_CELLS = (15, 14)
DELIVERY_SIZE = (336, 240)

PROMPT = r'''# Map01 高清废营 v2：更大占格、非像素画、纯俯视

请在同一次对话中按以下顺序上传三张图片：

1. `map01_derelict_camp_hd_v2_style_context.png`
   - 只参考 Map01 底图的灰青石地、枯黄旧路、低饱和光照和高清纹理密度。
   - 不要复制其中的地面、道路、网格或地图轮廓。
2. `map01_derelict_camp_hd_v2_structure_reference.png`
   - 只参考旧版 Approved 废营的主体关系：两座塌帐、倒伏暗红营旗、破损补给架。
   - 不要复制它的像素锯齿、低分辨率或旧色盘。
3. `map01_derelict_camp_hd_v2_placement_contract.png`
   - 青色框是严格的 7×5 格视觉覆盖和阻挡范围，红色格是建筑占用格，金色格是下方 1×1 交互格。
   - 所有网格、色块、锚点都只是尺寸说明，绝不能画进最终素材。

请复制下面整段提示词提交：

```text
为 Godot 俯视地图 Map01“破禁山麓·万修之门”生成一个高清独立建筑候选：CAMP_STAY_BASE_HD_V2（废弃营地静态底座）。本次只生成一张单独透明 PNG，不生成状态表、联系表、完整地图、Sprite Sheet 或多版本拼图。

【参考图职责】
- 图片1只定义 Map01 新底图的材质、色盘、光照和高清细节密度；不要复制任何地面纹理块。
- 图片2只定义废营的主体构成：两座塌陷帆布帐篷顶、一面完全倒伏的暗红旧营旗与断木横杆、一个破损低矮补给架；不要复制像素画质感。
- 图片3只定义尺寸与位置：主体需要完整覆盖一个 7×5 逻辑格区域，下方留出一个 1×1 交互格；不要绘制任何红框、青框、金框、网格或锚点。

【核心尺寸与构图】
- 这是一个地图中的中型三级地标，视觉存在感要明显大于旧版废营，不能只占几格小图标的体量。
- 最终运行显示尺寸按 48 px/格计算，主体应适配约 336×240 px 的 7×5 格矩形；允许生成更大的透明画布，但主体必须清楚占满接近 7×5 的比例，不能缩在画布中央一小块。
- 主体横向展开、紧凑但有层次，左右两座帐篷之间有明确空间关系；不要把所有元素压成一条细横线。
- 底部中央是未来锚点，主体不能有越界长杆、漂浮小物或大面积空透明边。

【视角与高清风格】
- 严格接近 90 度正上方俯视，所有物体平铺在地图平面上；不要等距、透视、2.5D、侧墙或正面建筑。
- 高清手绘 2D 游戏地图资产：清楚的形体、稳定的材质边缘、细腻但可控的帆布褶皱和旧木纹理。不是像素画，不要方块化锯齿、8-bit边缘、低分辨率模糊或最近邻像素块。
- 画面可以有手绘笔触与轻微材质变化，但轮廓必须在 100% 和缩小到 336×240 后都清晰可读；不要照片写实、3D渲染或强烈镜头光影。
- 色盘与 Map01 底图统一：灰蓝、旧帆布灰褐、风化木、少量枯金和克制暗红。建筑轮廓比地面略深、略清晰，但不能用黑色粗描边、白边或外发光分离。
- 光照平、柔和、低对比，不要长投影；细节集中在帐篷破损、木架结构和倒伏旗面，不要满地碎屑。

【主体内容】
- 两座低矮、已坍塌的帆布帐篷，从顶部可见帆布褶皱、破口、断裂支杆顶部和压低的菱形/不规则轮廓；不能出现帐篷正面、门洞或侧墙。
- 一面暗红旧营旗完全倒伏贴地，横放在断木横杆旁；没有直立旗杆、可读徽记、文字或旗帜正面展示。
- 一个低矮破损的补给木架/木箱框，放在右侧或下侧，结构大而清楚，不变成小颗粒。
- 右侧保留一处自然、低对比的空隙，未来可以叠加尸首证据 Overlay；不要画成规则插槽、UI底盘或刻意空白方框。
- 周围保持真实透明背景，不附带地面、道路、森林、山体、围墙、石圈或环境贴图。

【输出】
- 只输出一张完整的 CAMP_STAY_BASE_HD_V2。
- 真实透明 RGBA 背景，主体完整不裁边；优先横向 7:5 比例的透明画布。
- 不要文字、数字、标签、图例、状态说明或第二个版本。
- 必须下载原始 PNG，不要截图、JPG、网页缩略图或带背景的图片。

【禁止】
人物、尸体、尸布、血迹、粮册、书页、宝箱、资源、敌人、Marker、篝火、烟、发光、粒子、法阵、道路、地面、森林、山体、墙、围栏、绿色键色、网格、红框、青框、金框、白色贴纸边、黑色粗描边、厚阴影、等距视角、2.5D视角、帐篷侧面、帐篷正门、竖直旗帜、长投影、水印、logo、拼图、多版本排版。
```

生成数量：1 张。
建议下载文件名：`map01_derelict_camp_hd_base_gpt_v2.png`。
'''


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def load_rows(mask_path: Path) -> list[str]:
    payload = json.loads(mask_path.read_text(encoding="utf-8"))
    if payload.get("mapSize") != list(MAP_SIZE):
        raise ValueError(f"Expected Map01 mask size {list(MAP_SIZE)}, got {payload.get('mapSize')}")
    rows = payload.get("rows")
    if not isinstance(rows, list) or len(rows) != MAP_SIZE[1] or any(len(row) != MAP_SIZE[0] for row in rows):
        raise ValueError("Map01 mask rows are not 48x64")
    for cell in VISUAL_CELLS + INTERACTION_CELLS:
        x, y = cell
        if rows[y][x] not in ".=~":
            raise ValueError(f"Camp contract cell is not walkable: {cell}={rows[y][x]}")
    return rows


def crop_board(base_path: Path) -> Image.Image:
    image = Image.open(base_path).convert("RGBA")
    expected = (MAP_SIZE[0] * CELL_SIZE, MAP_SIZE[1] * CELL_SIZE)
    if image.size != expected:
        raise ValueError(f"Unexpected board base size {image.size}; expected {expected}")
    left = CONTEXT_ORIGIN[0] * CELL_SIZE
    top = CONTEXT_ORIGIN[1] * CELL_SIZE
    right = left + CONTEXT_CELLS[0] * CELL_SIZE
    bottom = top + CONTEXT_CELLS[1] * CELL_SIZE
    return image.crop((left, top, right, bottom))


def draw_placement(board_context: Image.Image) -> Image.Image:
    guide = board_context.copy()
    draw = ImageDraw.Draw(guide, "RGBA")
    origin_x, origin_y = CONTEXT_ORIGIN
    for x, y in BLOCKED_CELLS:
        left = (x - origin_x) * CELL_SIZE
        top = (y - origin_y) * CELL_SIZE
        draw.rectangle(
            (left, top, left + CELL_SIZE - 1, top + CELL_SIZE - 1),
            fill=(214, 66, 62, 44),
            outline=(242, 115, 93, 150),
            width=1,
        )
    left = (VISUAL_ORIGIN[0] - origin_x) * CELL_SIZE
    top = (VISUAL_ORIGIN[1] - origin_y) * CELL_SIZE
    right = left + VISUAL_SIZE_CELLS[0] * CELL_SIZE - 1
    bottom = top + VISUAL_SIZE_CELLS[1] * CELL_SIZE - 1
    draw.rectangle((left, top, right, bottom), outline=(89, 216, 224, 255), width=3)
    for x, y in INTERACTION_CELLS:
        cell_left = (x - origin_x) * CELL_SIZE
        cell_top = (y - origin_y) * CELL_SIZE
        draw.rectangle(
            (cell_left + 2, cell_top + 2, cell_left + CELL_SIZE - 3, cell_top + CELL_SIZE - 3),
            fill=(226, 183, 75, 52),
            outline=(242, 201, 102, 255),
            width=3,
        )
    anchor_x = (ANCHOR_CELL[0] + 0.5 - origin_x) * CELL_SIZE
    anchor_y = (ANCHOR_CELL[1] + 1.0 - origin_y) * CELL_SIZE
    draw.ellipse((anchor_x - 6, anchor_y - 6, anchor_x + 6, anchor_y + 6), fill=(240, 244, 239, 255), outline=(20, 28, 33, 255), width=2)
    return guide


def structure_reference(path: Path) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    if image.size != (96, 56):
        raise ValueError(f"Unexpected approved camp base size: {image.size}")
    enlarged = image.resize((768, 448), Image.Resampling.NEAREST)
    canvas = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    canvas.alpha_composite(enlarged, ((1024 - enlarged.width) // 2, (1024 - enlarged.height) // 2))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--board-base", type=Path, required=True)
    parser.add_argument("--mask", type=Path, required=True)
    parser.add_argument("--approved-base", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()

    load_rows(args.mask)
    output = args.output_dir
    refs = output / "reference"
    refs.mkdir(parents=True, exist_ok=True)
    context = crop_board(args.board_base)
    style_path = refs / "map01_derelict_camp_hd_v2_style_context.png"
    structure_path = refs / "map01_derelict_camp_hd_v2_structure_reference.png"
    placement_path = refs / "map01_derelict_camp_hd_v2_placement_contract.png"
    prompt_path = output / "map01_derelict_camp_hd_v2_gpt_prompt.md"
    contract_path = output / "map01_derelict_camp_hd_v2_asset_contract.json"
    context.resize((1024, 1024), Image.Resampling.LANCZOS).save(style_path)
    structure_reference(args.approved_base).save(structure_path)
    draw_placement(context).resize((1024, 1024), Image.Resampling.LANCZOS).save(placement_path)
    prompt_path.write_text(PROMPT, encoding="utf-8")

    contract = {
        "schema_version": 2,
        "status": "candidate_generation_input_only",
        "asset_id": "map01_derelict_camp_hd_base_v2",
        "revision_reason": [
            "v1 5x3 footprint is visually undersized on the new 48px-per-cell board",
            "v1 prompt allowed a pixel-art reading instead of an HD map prop",
        ],
        "coordinate_contract": "top-left scene cells; x grows right; y grows down",
        "logical_size_cells": list(VISUAL_SIZE_CELLS),
        "delivery_size_px": list(DELIVERY_SIZE),
        "anchor_cell": list(ANCHOR_CELL),
        "anchor_px": [DELIVERY_SIZE[0] // 2, DELIVERY_SIZE[1]],
        "visual_origin_cell": list(VISUAL_ORIGIN),
        "visual_cells": [list(cell) for cell in VISUAL_CELLS],
        "blocked_cells": [list(cell) for cell in BLOCKED_CELLS],
        "interaction_cells": [list(cell) for cell in INTERACTION_CELLS],
        "state_contract": "Only static base is regenerated now; corpse overlays remain separate and must share the new anchor/footprint later.",
        "style_contract": [
            "HD hand-painted 2D game-map prop",
            "strict 90-degree overhead",
            "no pixel-art stair steps",
            "clear silhouette at 336x240 runtime size",
            "real transparent RGBA",
        ],
        "source_inputs": {
            "style_reference": str(style_path),
            "structure_reference": str(structure_path),
            "placement_reference": str(placement_path),
            "approved_structure_sha256": sha256(args.approved_base),
        },
        "generation": {
            "supplier": "ChatGPT member webpage, user-executed",
            "count": 1,
            "prompt_path": str(prompt_path),
            "download_name": "map01_derelict_camp_hd_base_gpt_v2.png",
        },
        "formal_status": "UNVERIFIED",
        "formal_scene_modified": False,
        "runtime_asset": False,
        "meowa_points_spent": 0,
    }
    contract_path.write_text(json.dumps(contract, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("MAP01_DERELICT_CAMP_HD_V2_INPUT_OK visual_cells=%d blocked_cells=%d interaction_cells=%d" % (len(VISUAL_CELLS), len(BLOCKED_CELLS), len(INTERACTION_CELLS)))


if __name__ == "__main__":
    main()
