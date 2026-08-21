# D0 `map_01` Godot 客户端技术设计

范围：`map_01` 「破禁山麓」可玩灰盒  
引擎：Godot 4.7.1

## 1. 目标与裁剪

- 保留四方向移动、迷雾、灵粮消耗、宝箱、故事、固定遭遇、休整与归营。
- 当前 `15×15` 活动区是 D0 裁剪，不代表 1.0 `48×64` 正式地图。
- Puny Dungeon 是 CC0 灰盒地形，不是 `map_01` 正式美术。

## 2. 场景与资源

| 内容 | 路径 |
|---|---|
| 地图场景 | `res://scenes/map.tscn` |
| 页面与事务编排 | `res://scripts/scenes/map_scene.gd` |
| 可编辑 Map01 布局 | `res://scenes/maps/map_01.tscn` |
| 地图布局读取 | `res://scripts/maps/map_scene_layout.gd` |
| 地图承载与点击 | `res://scripts/scenes/map_canvas.gd` |
| 迷雾与运行标记 | `res://scripts/scenes/map_overlay.gd` |
| 地图数据 | `res://data/maps/map_01_demo.json` |
| 地图清单 | `res://data/maps/map_01_manifest.json` |
| Dual Grid TileSet | `res://resources/tilemapdual_standard.tres` |
| D0 兼容 tileset | `res://assets/maps/map_01/puny_dungeon/` |

## 3. 进入流程

```text
营地选择 map_01
→ Game.start_expedition(loadout)
→ 原子扣除灵粮/工具并建立 profile.expedition
→ Game.goto_scene("res://scenes/map.tscn")
→ map_scene.gd 从 Game 恢复位置、迷雾和对象状态
```

任何开始失败都不得留下半完成的远征或重复扣除资源。

## 4. 运行状态

`profile.expedition` 至少包含：

- 当前 `mapId` 与格坐标；
- 剩余灵粮、携带物、临时战利品和负重；
- 已探索/当前可见格；
- 休整状态与战斗前位置；
- 已处理对象由 `profile.completedMapObjects` 以 `map_01.<object_id>` 记录。

## 5. 移动、迷雾与画布

- `map_canvas.gd` 以 `48×48` 逻辑格承载当前活动区并处理格子点击，`map_overlay.gd` 绘制迷雾和运行标记。
- `map_01.tscn` 的 `Ground` 保存可走格，`DifficultTerrain` 保存难行格，Marker 保存入口和对象坐标。
- `Game.get_map_definition()` 缓存场景布局并与 JSON 产品配置合并，移动时不会反复实例化场景。
- 域坐标 Y 向上，屏幕 Y 向下；翻转只在画布层处理。
- 移动前检查越界、曼哈顿距离和阻挡。
- 移动成功后更新位置、灵粮、迷雾和存档，再检查当前格对象。

## 6. 对象、战斗与归营

- 宝箱和故事在当前格弹出操作面板。
- 敌人遭遇写入 pending combat 上下文后进入 `res://scenes/combat.tscn`。
- 战斗结束返回地图，保留战前位置和临时背包。
- 正常归营需回到入口，或消耗已携带的归营符。
- 归营成功时把临时战利品并入永久库存，清理远征状态并返回营地。

## 7. 验收

- [ ] 四种输入方式不能绕过同一移动校验。
- [ ] 阻挡、迷雾、灵粮与对象显示在重进地图后一致。
- [ ] 战斗返回不重生已击败敌人。
- [ ] 正常归营与战败结算不重复发放战利品。
- [ ] D0 灰盒不被误标为 `map_01` 正式美术。
- [ ] `Ground` 只使用完整块 `0xF`，难行格和所有 Marker 都落在可走格。
