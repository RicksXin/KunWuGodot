# Cocos Creator → Godot 迁移说明

## 迁移边界

源项目是冻结输入，本目录没有保留 Cocos 的 `.meta`、`library`、`temp`、`local`、
`profiles` 或 `build` 产物。迁移后的运行资源路径全部以 `res://` 为根，日常开发和运行不依赖
上级源工程。

| Cocos 概念 | Godot 对应 | 说明 |
|---|---|---|
| `Boot.scene` / `AppRoot` | `scenes/boot.tscn` + `Game` autoload | 启动页、配置加载、场景切换 |
| `Camp.scene` + Camp Prefab | `scenes/camp.tscn` + `scripts/scenes/camp.gd` | 三层营地 UI；中央 `ScrollContainer` 保持横滑 |
| `Map.scene` / `TiledMap` | `scenes/map.tscn` + `map_canvas.gd` | 领域数据沿用 `map_01_demo.json`；D0 地图用 Godot 绘制像素灰盒，保留 CC0 TMX/tileset 供后续 TileMapLayer 替换 |
| `Combat.scene` / Presenter | `scenes/combat.tscn` + `combat.gd` | 固定时间步、技能目标、伤害/治疗、手动/自动、撤离和胜负结算 |
| Cocos 程序化按钮组件 | `KWUI.camp_button/map_button/combat_button` + `camp_button_visual.gd` | 迁入营地 Inline/Footer 三态、地图与战斗配色及 0.96 按压反馈；营地可见层与至少 48px 触控层分离 |
| `GameState` / `SaveService` | `scripts/autoload/game.gd` | 资源、营地、修士、远征状态聚合；原子临时文件写入 `user://kunwu_profile.json` |
| 后台发布配置 | `ConfigRepository` autoload + `Game` 查询接口 | manifest/六模块下载、schema/字节数/SHA-256 校验、`user://kunwu_config_cache` 缓存与 `res://data` 回退；玩家存档仍只由 `Game` 写入 |
| TS 领域函数 | `scripts/domain/*.gd` 与 `Game` 领域方法 | `KWCombatResolver` 独立处理技能解析；迷雾、四方向移动、生产结算保持源规则 |
| Cocos Asset Bundle | `assets/` + `data/` | Godot 首次导入后按 `res://` 加载；地图/营地资源目录仍按 bundle 语义分组 |
| `db://` 脚本导入 | GDScript `preload`/`load` | 不保留 Cocos UUID 引用 |

## 已迁移的冻结输入

- 完整 `Docs/` 文档快照，包括 1.0 策划、PRD、美术资产、Demo、Figma、API 与技术资料；
  Godot 项目内的代理与人工开发以该快照为文档事实源。
- `art/source_archive/` 美术源文件、`third_party/` 第三方原始包与许可链，以及
  `Docs/Artifacts/` 迁移前评审产物；这些目录通过 `.gdignore` 排除在运行时导入之外。
- 营地背景、七座建筑的开放/锁定图、HUD 图标、灵源院/入山整备面板素材。
- 四名初始修士肖像与两组帧动画、Ark Pixel 字体及 OFL 许可文件。
- `default_profile.json`、`expedition_preparation.json`、`ling_pu_config.json`、
  `combat_d0.json`、`map_01_demo.json`、中文本地化、职业/技能/平衡数据。
- Puny Dungeon CC0 来源快照、TMX、TSX 和 tileset；Godot 版当前以领域数据绘制可读灰盒，
  不会损坏或改写第三方源文件。
- 当前文档入口为 `Docs/README.md`；迁移前执行级技术文档集中在 `Docs/LegacyCocos/`，只作审计。
- 项目数据结构由 `tools/validate_project_data.gd` 校验；面板按钮由
  `tools/validate_button_styles.gd` 校验；营地建筑布局由
  `tools/validate_camp_layout.tscn -- --no-profile-write` 校验；灵源院布局通过隔离工程运行
  `tools/validate_ling_pu_layout.tscn -- --no-profile-write` 校验；Dual Grid 笔刷由
  `tools/validate_tilemapdual_brush.gd` 校验。`Game` 会自动禁止编辑器与 `--script` 工具写入
  `user://kunwu_profile.json`；所有测试场景仍必须显式传入 `--no-profile-write`。

## 可运行闭环

启动后可依次操作：

1. 营地中央全景横向拖动，点击灵源院调度杂役、升级储量、招募杂役；点击议事殿查看岑守一。
2. 点击传送阵或底部“入山整备”，选择四人队伍和灵粮后进入 map_01。
3. 地图以 48×48 逻辑格显示，保留 `UNKNOWN → DISCOVERED → VISIBLE` 迷雾、地形成本、
   四方向移动、宝箱/故事对象和固定残禁石傀。
4. 战斗按照 `CombatCommand → 结算器 → CombatEvent` 的职责划分执行自动技能，支持技能按钮、
   自动/手动切换、生命条、日志、撤离和胜负结算；胜利奖励写入临时战利品并可归营入库。
5. 刷新或退出后，从 `user://kunwu_profile.json` 恢复状态；设置页可立即保存或重置新档。

Godot 项目基准视口为 `375×817`，Compatibility 渲染器、nearest 像素过滤；桌面或移动窗口
缩放由 Godot Canvas Items 拉伸处理。

## 有意保留的后续扩展点

- `map_02_manifest.json` 只保留占位状态；当前没有 `map_02`–`map_04` 可玩场景，
  不伪造不存在的关卡。
- 原 Cocos 的 IndexedDB、浏览器 Bundle 预载、Figma/Cocos 编辑器契约没有一一照搬；Godot 版
  以本地 JSON 存档与资源路径完成同等单机行为。
- 后续接入完整 TileMapLayer、帧动画、音频或新的页面时，应从现有 `Game` 状态接口和
  `KWUI` 工厂扩展，不要把业务规则重新写回节点表现层。
- 地图、队伍、遭遇和地图对象通过稳定 ID 传递；出征状态保存 `mapId`、`partyPresetId`、
  `encounterId`、`mapObjectId`，禁止依赖配置数组顺序或固定 `map_01` 完成键。

## 有意不迁入运行工程的旧文件

- `package.json`、`pnpm-lock.yaml`、`tsconfig*`、旧 TypeScript 测试与 Node 工具链不复制；
  Godot 工程不需要 Node.js。当前替代验证入口是 `tools/validate_project_data.gd`、
  `tools/validate_tilemapdual_brush.gd` 和 Godot headless 编辑器扫描。
- 旧场景/Prefab 生成器、Bundle 配置器、Web 构建/本地服务器工具不转换；当前 `project.godot`、
  `.tscn`、`res://` 和 Godot 导出流程已经取代这些职责。
- `library/`、`temp/`、`local/`、`profiles/`、`build/` 等旧编辑器缓存和构建产物不迁移。
- 旧实现不按“一份 TypeScript 对应一份 GDScript”机械复制。已迁移行为以本文件上方概念映射、
  当前可玩闭环和验收结果为准；尚未进入 1.0 的功能按 PRD 重新实现，不把旧引擎结构带回来。
