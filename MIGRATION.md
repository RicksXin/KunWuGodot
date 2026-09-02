# Cocos Creator → Godot 迁移说明

## 迁移边界

源项目是冻结输入。本工程不保留 Cocos 的 `.meta`、缓存、构建产物或运行依赖；所有运行资源使用
`res://`，玩家存档只通过 `Game` 写入 `user://kunwu_profile.json`。

| Cocos 概念 | Godot 对应 | 当前事实 |
|---|---|---|
| `Boot.scene` / `AppRoot` | `scenes/boot.tscn` + `Game` | 启动、配置加载、场景切换 |
| `Camp.scene` | `scenes/camp.tscn` + `camp.gd` | 营地横滑、建筑与固定 HUD |
| `Map.scene` / `TiledMap` | `scenes/map.tscn` + `map_canvas.gd` + `map_overlay.gd` | `817×375` 横屏探索页、迷雾、Marker、拖动与缩放；离开时恢复竖屏 |
| Map01 布局与内容 | `data/maps/map_01_formal.json` | 唯一移动、阻挡、对象坐标、互动与地图文案事实源 |
| Map01 视觉 | `scenes/maps/map_01.tscn` + `assets/maps/map_01/map01_background.png` | 唯一正式高清背景；不承载碰撞或对象坐标 |
| 战斗 | `scenes/combat.tscn` + `combat.gd` + `combat_resolver.gd` | `CombatCommand → 结算器 → CombatEvent → 表现层` |
| 后台发布配置 | `ConfigRepository` | 远端整批校验、缓存与内置正式配置回退 |

## 当前唯一正式 Map01

- ID：`map_01`；显示名：破禁山麓·万修之门。
- 边界：`28×64`；逻辑格：`48×48`；背景：`1344×3072`。
- 入口：`(13,6)`；基础可走格 `834`；阻挡格 `958`。
- 正式对象 `31`；地图战斗 Marker `13`；遭遇定义 `14`；动态阻挡 `7`。
- 三灯、暗道、双向阶梯、Boss 门禁和出口继续由正式 JSON 与 `Game.mapStates` 表达。
- 高清背景只负责画面，`terrainRows` 负责基础可走/困难/阻挡，`dynamicBlockers` 负责状态碰撞，
  `objects` 负责对象坐标与互动。
- `Game.get_map_definition()` 不再从场景 TileMap 反推路线或坐标。

旧 `48×64` TileMap、V1.3 分层图、Puny Dungeon 回退、Map01 Dual Grid 笔刷、独立地标组件、
方案编号、候选快照、Demo、Preview、评审图和生成工具均不属于当前工程事实源，也不保留在项目内。
TileMapDual `v5.0.2` 插件仅作为后续地图可能使用的通用扩展工具保留。

## 可运行闭环

1. 启动后进入营地，完成生产、招募、还魂和入山整备。
2. 进入 `map_01`，使用四方向移动、迷雾、灵粮、休整、背包、对象互动、拖动、捏合/滑轨缩放。
3. 缩放尽量以玩家格为中心；地图边缘夹紧但保持玩家可见。
4. 固定遭遇进入正式战斗配置，胜利奖励先进入临时背包，归营后结算。
5. 正常运行通过 `Game` 自动保存；验证必须带 `-- --no-profile-write --ignore-config-cache`。

## 已迁移与保留

- `Docs/` 是产品与技术资料事实源；`Docs/LegacyCocos/` 只作历史审计。
- `third_party/` 保留第三方来源与许可链，不作为 Map01 运行路径。
- 营地、角色、字体、HUD、战斗、美术与配置资源继续从 `assets/` 和 `data/` 读取。
- `data/maps/map_02_manifest.json` 只是未来地图占位；当前唯一可玩地图仍是 Map01。
- 地图、队伍、遭遇和对象通过稳定 ID 传递，不依赖配置数组顺序。

## 验证入口

- `tools/validate_project_data.gd`
- `tools/validate_config_repository.gd`
- `tools/validate_map01_formal.gd`
- `tools/validate_map01_formal_combat_runtime.gd`
- `tools/validate_revival_flow.tscn`
- Godot 4.7.1 headless editor导入与短时主场景运行

自动验证不能替代视觉验收。地图背景、网格、Marker、迷雾、拖动和缩放仍需在 `375×817` 逻辑视口
与目标设备上人工确认。
