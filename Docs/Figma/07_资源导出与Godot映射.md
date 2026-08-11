# 资源导出与 Godot 映射

版本：Godot-1.0  
设计基准：`375×817` 逻辑视口，像素资产 nearest filtering

## 1. 交付原则

- 每张资源同时记录逻辑显示尺寸和 PNG 交付尺寸，例如 `逻辑 288×80，交付 864×240 (@3x)`。
- 动态文字、数字、价格、倒计时、境界、资质、锁定原因和按钮文案不进入 PNG。
- 能由 Godot `Label`、`Control.clip_contents`、`modulate`、`NinePatchRect`、`StyleBox`、
  `Tween` 或粒子表达的内容，不重复生成近似位图。
- Pixel Art 保持整数像素对齐，不使用抗锯齿缩放交付。
- Figma 导出只产生 PNG/SVG 与评审记录；Godot 自动生成 `.import` 缓存，不手写。

## 2. 命名与路径

```text
ui_<scope>_<component>_<state>.png
icon_<category>_<name>.png
portrait_<role>_<name>.png
vfx_<system>_<name>_<frame>.png
```

| 类别 | Godot 运行路径 |
|---|---|
| 营地建筑与传送阵 | `res://assets/camp/buildings/` |
| 营地顶部 HUD | `res://assets/camp/ui/top/` |
| 营地底部 HUD | `res://assets/camp/ui/bottom/` |
| 通用营地图标 | `res://assets/camp/ui/common/` |
| 灵源院 | `res://assets/camp/ui/ling_pu/` |
| 入山整备 | `res://assets/camp/ui/expedition/` |
| 议事殿 | `res://assets/camp/ui/council/` |
| `map_01` D0 地形 | `res://assets/maps/map_01/` |
| 通用 TileSet 与配置 | `res://resources/` |
| 未清稿源文件 | `art/source_archive/`（`.gdignore`） |

原始 Figma/GPT 导出保留在 `art/source_archive/figma_exports/` 和对应原始目录；仅将已审核、
已裁切或已压缩成品放入 `res://assets/`。

## 3. 导入与像素纪律

- 项目级 nearest 由 `project.godot` 统一设置。
- 非 Tile 像素图不开 mipmaps；不在 Control 上使用半像素位置。
- 需拉伸的面板使用 `NinePatchRect` 或 `StyleBoxTexture`，在 Inspector 记录 patch margin。
- 按钮视觉子节点可执行 `1.0 → 0.96 → 1.0 / 100ms` Tween，热区节点不缩放。
- 透明图必须检查边缘污染；不使用绿色键色或棋盘格伪透明。

## 4. 当前页面映射

当前主页面的 `.tscn` 只保留根 `Control`，具体 UI 由场景脚本和 `KWUI` 工厂创建。因此映射必须
精确到场景脚本的构建函数，不得虚构不存在的编辑器节点。

| 页面/流程 | Godot 场景 | 实现入口 | 主要资产 | 状态 |
|---|---|---|---|---|
| 启动页 | `res://scenes/boot.tscn` | `scripts/scenes/boot.gd` | 字体与纯 Godot UI | 已迁移 |
| 营地全景/HUD | `res://scenes/camp.tscn` | `camp.gd::_build_scene()` | `assets/camp/buildings/`、`ui/top/`、`ui/bottom/` | 已迁移，待持续人工验收 |
| 灵源院 | 同上 | `camp.gd::_open_ling_pu()` | `assets/camp/ui/ling_pu/` | 已迁移 |
| 入山整备 | 同上 | `camp.gd::_open_expedition()` | `assets/camp/ui/expedition/` | 已迁移 |
| 地图选择 | 同上 | `camp.gd::_open_map_selection()` | `ui_expedition_map_selection_panel.png` | D0 只开放 `map_01` |
| 编辑队伍 | 同上 | `camp.gd::_open_hero_selection()` | `ui_expedition_hero_selection_*` | Demo 固定四人 |
| 议事殿 | 同上 | `camp.gd::_open_council()` | `assets/camp/ui/council/` | 已迁移 |
| 地图探索 | `res://scenes/map.tscn` | `map_scene.gd` + `map_canvas.gd` | `assets/maps/map_01/` | D0 灰盒 |
| 战斗 | `res://scenes/combat.tscn` | `scripts/scenes/combat.gd` | 当前画布与角色资产 | D0 固定遭遇 |

## 5. Figma 映射表模板

| 页面 | Figma 精确节点 | 组件/Variant | Godot 场景 | 构建函数/节点 | `res://` 资产 | 状态/事件 | 评审状态 |
|---|---|---|---|---|---|---|---|
| 示例 | `fileKey:nodeId` | `PanelItem/V2:selected` | `res://scenes/camp.tscn` | `_build_example()` | `res://assets/camp/ui/common/example.png` | `default/selected/disabled` | Approved |

映射必须回答：

1. 哪个 Approved Figma 节点是视觉事实源。
2. 哪个 Godot 场景、脚本函数或已存在节点承载它。
3. 哪些层是 `TextureRect`、`Label`、裁切容器、粒子或代码动效。
4. Variant 如何映射到运行状态与 signal。
5. 逻辑尺寸、锚点、patch margin、裁切和触控热区如何设置。

## 6. 动效交付

PNG 序列帧补零命名：

```text
vfx_camp_smoke_01.png
vfx_camp_smoke_02.png
vfx_camp_smoke_03.png
```

交付表记录帧率、循环、锚点、混合方式和是否跟随节点缩放。固定网格序列使用
`SpriteFrames`；复杂节点动画使用 `AnimationPlayer`。不手写 Godot 导入缓存或逐帧 UID。

## 7. 交付前检查

- 只实现 Approved 节点，Draft/Review 必须保持状态标记。
- 文件名、Variant、逻辑尺寸和实际像素尺寸一致。
- 动态文案没有烘焙进 PNG。
- patch margin、锚点、裁切、混合和滤镜要求已登记。
- 映射能定位到真实 `res://` 路径和已存在的构建函数/节点。
- 导入后在 `100%`、`75%`、`50%` UI 缩放和 `375×817` 视口中人工检查。
