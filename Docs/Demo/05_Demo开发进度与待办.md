# 《昆吾禁地》Godot Demo 开发进度与待办

更新日期：2026-08-11  
引擎：Godot 4.7.1  
当前目标：维持 D0 可玩闭环，逐步用正式 Godot 场景、地形和美术替换灰盒

> 迁移前的完整开发日志保留在
> [`../LegacyCocos/Demo/05_Demo开发进度与待办.md`](../LegacyCocos/Demo/05_Demo开发进度与待办.md)。

## 1. 当前可玩流程

```text
Boot
→ Camp 营地横滑
→ 灵源院生产/招募/储量升级
→ 入山整备
→ map_01 迷雾探索、宝箱和故事
→ 残禁石傀固定遭遇
→ 胜负/撤离、战利品
→ 回入口归营结算
```

## 2. 迁移完成状态

| 模块 | 状态 | Godot 事实源 | 说明 |
|---|---|---|---|
| 工程与启动 | 🟢 | `project.godot`、`scenes/boot.tscn` | Godot 4.7.1、GL Compatibility、`375×817` |
| 全局状态/存档 | 🟢 | `scripts/autoload/game.gd` | `user://kunwu_profile.json` |
| 营地全景/HUD | 🟢 | `scenes/camp.tscn`、`camp.gd` | 横滑、建筑、顶底 HUD 已接线 |
| 灵源院 D0 | 🟢 | `camp.gd`、`ling_pu_config.json` | 生产、调岗、招募、升级、存档 |
| 入山整备 | 🟢 | `camp.gd`、`expedition_preparation.json` | 四人队、灵息、负重和装载 |
| `map_01` D0 | 🟢 | `scenes/map.tscn`、`map_01_demo.json` | `15×15` 可玩灰盒，非正式地图 |
| 战斗 D0 | 🟢 | `scenes/combat.tscn`、`combat_resolver.gd` | 20 Hz、手动/自动、撤离、结算 |
| Dual Grid 工具 | 🟢 | `addons/TileMapDual`、`resources/tilemapdual_standard.tres` | v5.0.2，15 掩码可达 |
| 策划/PRD/美术文档 | 🟢 | `Docs/` | 已迁入，Godot 执行指南已更新 |
| 美术源文件 | 🟢 | `art/source_archive/` | `.gdignore` 归档 |
| 第三方原始包/许可 | 🟢 | `third_party/` | `.gdignore` 归档 |

## 3. 正式化进度

| 内容 | 状态 | 下一个可验收结果 |
|---|---|---|
| `map_01` Figma 灰盒 | 🟡 | `48×64` 规则网格、碰撞、对象静区与 `375×817` 视窗 |
| `map_01` 视觉母版 | 🟡 | 低饱和灰青山岩、枯黄旧路、三阵灯和万修之门纯俯视母版 |
| `map_01` 正式 Tile Set | 🟡 | 基础地面、道路连接、山体阻挡、阵灯三状态试制视窗 |
| 地图正式 `TileMapLayer` | 🟡 | 用 Godot TileSet/TileMapDual 替换 Puny Dungeon D0 绘制 |
| 战斗正式美术 | 🟡 | 单位、技能、状态、背景和战利品逐项替换灰盒 |
| 音频/VFX | 🟡 | 建立 Audio Bus、一组技能序列帧与命中反馈 |
| `map_02` 预览 | ⚪ | `map_01` 首轮试制验收后再开始独立灰盒 |

## 4. 已知的产品差距

- D0 灵源院生产常数仍是兼容口径，尚未升级为 PRD-03 的 1.0 产出、维护、灵液周期和五资源容量。
- `map_01` 玩法灰盒小于 1.0 `48×64` 正式边界，对象数量也是 D0 裁剪。
- 当前战斗只覆盖一组固定遭遇，不表示四图敌人、Boss 和 36 技能均已完成。
- 当前没有账号、服务端、跨设备同步或远程配置发布。

## 5. 开发验证

| 验证 | 命令/入口 |
|---|---|
| 数据与 `res://` 路径 | `Godot --headless --script res://tools/validate_project_data.gd` |
| 工程导入/脚本解析 | `Godot --headless --editor --path <project> --quit` |
| Dual Grid | `Godot --headless --script res://tools/validate_tilemapdual_brush.gd` |
| 整体流程 | Godot 编辑器 `F5` |
| 视觉与触控 | `375×817` 逻辑视口与实际目标设备 |

## 6. 近期顺序

1. 先完成 `map_01` 灰盒、视觉母版和最小 Tile Set 试制。
2. 把试制 Tile 导入 `TileMapLayer`/TileMapDual，完成一个典型视窗。
3. 完成 `map_01` 正式地形与关键地标后，再开始 `map_02`。
4. 生产、成长和战斗数值按对应 PRD 分别升级，不与引擎迁移混为一次无法验证的大改。
