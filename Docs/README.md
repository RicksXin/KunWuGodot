# 《昆吾禁地》Godot 文档入口

本目录是 `KunWuGodot` 的本地文档事实源。运行时不读取文档，也不依赖迁移源工程。

## 事实源顺序

1. [`1.0策划案/`](1.0策划案/)：1.0 产品规则与内容源头。
2. [`PRD/`](PRD/)：面向实现、异常恢复和验收的冻结需求。
3. 当前 Godot 场景、脚本、数据和人工验收结果。

D0/D1 Demo 的范围、进度和验收独立读取 [`Demo/`](Demo/README.md)，不得与 1.0 正式范围混用。

## 当前 Godot 技术与制作入口

| 主题 | 当前入口 |
|---|---|
| 工程架构、资源、存档、验证 | [`01_技术实现方案.md`](01_技术实现方案.md) |
| 美术基准与像素纪律 | [`02_美术设计规范.md`](02_美术设计规范.md) |
| 动画与视觉特效 | [`04_动画制作规范.md`](04_动画制作规范.md)、[`03_视觉特效方案.md`](03_视觉特效方案.md) |
| 地图与 TileMap/Dual Grid | [`05_地图与关卡编辑方案.md`](05_地图与关卡编辑方案.md) |
| Godot 编辑器操作 | [`09_编辑器操作清单.md`](09_编辑器操作清单.md) |
| 数值表与运行时边界 | [`13_数值设计方案.md`](13_数值设计方案.md) |
| Figma 到 Godot 资源映射 | [`Figma/README.md`](Figma/README.md) |
| 正式美术素材清单 | [`ArtAssets/README.md`](ArtAssets/README.md) |
| 当前迁移状态 | [`../MIGRATION.md`](../MIGRATION.md) |

## `map_01` 美术与实现入口

- 世界视觉、Tile、对象、迷雾和四图共用标准：
  [`ArtAssets/15_野外探索资源副本与四图内容.md`](ArtAssets/15_野外探索资源副本与四图内容.md)。
- D0 `map_01` 状态流与验收：
  [`Demo/Tech/D0_MAP_客户端技术设计.md`](Demo/Tech/D0_MAP_客户端技术设计.md)。
- 当前地图数据：`res://data/maps/map_01_demo.json`。
- 当前地图场景：`res://scenes/map.tscn`。
- 当前 CC0 tileset 来源与许可：
  `res://assets/maps/map_01/puny_dungeon/PROVENANCE.md`。

当前 D0 地图仍是可玩的像素灰盒，不等于 `map_01` 正式美术已经完成。正式替换时必须保持
`16×16` 源 Tile、`48×48` 逻辑显示、nearest filtering、四方向移动、迷雾状态和固定对象语义。

## 历史与归档

- [`LegacyCocos/`](LegacyCocos/)：迁移前技术文档快照，只用于审计，不可作为当前实施步骤。
- [`Artifacts/`](Artifacts/)：迁移前表格和视觉评审产物，只读参考。
- `art/source_archive/`：美术高清源文件，不进入 Godot 导入。
- `third_party/`：第三方原始包与许可链，不作为运行时资源路径。

当前文档中的场景、脚本、资源和数据路径应使用 `res://`；不要新增 `.meta`、Asset Bundle、
TypeScript、pnpm、IndexedDB 或浏览器运行时依赖。Godot 自动生成的 `.import` 与 `.godot/` 缓存
不得手写或作为业务事实源。
