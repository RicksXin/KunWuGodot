# 《昆吾禁地》Godot Demo 开发进度与待办

更新日期：2026-08-25
引擎：Godot 4.7.1

> 迁移前历史日志保留在 `Docs/LegacyCocos/`。当前工程不再保留旧 Map01 Demo、Preview、候选场景、
> TileMap 版本或对应生产废稿。

## 1. 当前可玩流程

```text
Boot → Camp → 灵源院/还魂/入山整备
→ map_01 迷雾探索、拖动与缩放、对象互动
→ 正式遭遇与战斗 → 战利品 → 归营结算
```

## 2. 当前完成状态

| 模块 | 状态 | Godot 事实源 | 说明 |
|---|---|---|---|
| 工程与启动 | 🟢 | `project.godot`、`scenes/boot.tscn` | Godot 4.7.1、`375×817` |
| 营地、生产与还魂 | 🟢 | `scenes/camp.tscn`、`camp.gd`、`game.gd` | 横滑、建筑、整备、死亡修士恢复 |
| Map01 共用页面 | 🟢 | `scenes/map.tscn`、`map_scene.gd` | 迷雾、移动、休整、背包、拖动、捏合/滑轨缩放 |
| Map01 唯一正式版 | 🟢 | `map_01_formal.json`、`map_01.tscn`、`map01_background.png` | `28×64`、31 对象、14 遭遇、7 动态阻挡 |
| 战斗 | 🟢 | `combat_map01_formal.json`、`combat_resolver.gd`、`combat.gd` | 自动/手动、撤离、胜负与战利品 |
| 正式 Marker | 🟡 | `assets/maps/map_01/markers/`、`map_overlay.gd` | 当前可用；下一轮统一为跨地图通用视觉语言 |
| 音频/VFX | 🟡 | 待建立 | 不影响当前地图闭环 |

## 3. Map01 正式契约

- 边界 `28×64`，逻辑格 `48×48`，背景 `1344×3072`。
- 入口 `(13,6)`；基础可走格 `834`；阻挡格 `958`。
- `terrainRows` 是基础移动事实源；`dynamicBlockers` 是状态阻挡事实源。
- `objects` 是 31 个对象坐标、互动、奖励和状态效果事实源。
- 背景图只负责视觉；运行时 Overlay 负责迷雾、淡纹网格、玩家与对象 Marker。
- 项目内不存在“方案1/方案2”、候选/正式双轨、D0 兼容地图或 TileMap 回退。

## 4. 验证入口

所有自动验证显式传入：

```text
-- --no-profile-write --ignore-config-cache
```

| 验证 | 入口 |
|---|---|
| 工程导入与脚本解析 | Godot `--headless --editor --path <project> --quit` |
| 数据与资源路径 | `tools/validate_project_data.gd` |
| 内置正式配置 | `tools/validate_config_repository.gd` |
| Map01 布局与运行 | `tools/validate_map01_formal.gd` |
| Map01 战斗 | `tools/validate_map01_formal_combat_runtime.gd` |
| 还魂流程 | `tools/validate_revival_flow.tscn` |
| 完整体验 | Godot 编辑器 `F5` |

## 5. 下一步

1. 将出生点、出口、资源、普通怪、精英、Boss、副本和队伍 Marker 统一为跨地图复用的一套风格。
2. 在 Map01 高清背景、深色测试板和灰度下检查 `100% / 75% / 50%` 可读性。
3. 保持状态高亮、锁定、已处理、选中和文字由 Godot 节点表达，不复制状态 PNG。
4. Marker 通过用户视觉 Gate 后再开始 Map02 灰盒，不恢复 Map01 旧生产链。
