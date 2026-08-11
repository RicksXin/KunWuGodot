# 《昆吾禁地》Godot 项目代理入口

本文件适用于整个 `KunWuGodot` 项目。开始任务前，先阅读本文件，并按任务继续阅读根目录
`README.md`、`MIGRATION.md`、相关场景、脚本和数据文件。本项目是独立 Godot 工程；运行时不得
依赖或修改上级 Cocos 工程。

## 事实源与迁移边界

- 产品规则按本项目内迁移后的事实链派生：`Docs/1.0策划案/` →
  `Docs/PRD/` → 当前 Godot 实现与验收。
- D0/D1 Demo 的范围、进度和验收从 `Docs/Demo/` 进入；不要与 1.0 正式版本混用。
- 当前 Godot 已迁移内容、概念映射和有意保留的扩展点以 `MIGRATION.md` 为准。
- 当前工程的启动方式、目录、操作和存档位置以 `README.md` 与 `project.godot` 为准。
- `Docs/` 是迁入当前 Godot 工程的产品资料快照和文档事实源；运行时仍不得读取其中内容。
- 迁移源工程只用于必要的历史审计；日常开发、文档查阅、资源追溯和运行都不得要求
  上级工程存在。
- 文档与实现冲突时，产品语义以策划/PRD 为准；Godot 路径、节点、资源和运行行为以本项目为准。
  不得为了复刻旧 Cocos 结构而破坏已经工作的 Godot 闭环。

## Godot 工程红线

- 使用 Godot `4.7.1` 兼容 API、GDScript 和 `res://` 资源路径；不要重新引入 Cocos、Node.js、
  pnpm 或浏览器运行时依赖。
- `.godot/`、`*.import` 和导入缓存由 Godot 管理，不手写、不批量复制、不作为业务事实源。
- 移动场景、脚本或资源时保留对应 `.uid`，并同步修复所有 `res://` 引用。
- 不用生成器整体覆盖正式 `scenes/camp.tscn`、`scenes/map.tscn` 或其他已迁移场景；修改前先阅读
  对应场景脚本和数据入口。
- 战斗数据流保持 `CombatCommand → 结算器 → CombatEvent → 表现层`，业务规则不得回写到纯 UI
  节点。
- 七维内部字段名冻结：`strength magic technique speed constitution armor resistance`。
- UI 设计基准保持 `375×817`；营地全景与固定 HUD 的层级、横滑关系不得破坏。
- 像素素材使用 nearest filtering；除非素材明确需要，不启用 mipmaps 或线性过滤。
- 存档只通过现有 `Game` autoload 和 `user://kunwu_profile.json` 流程读写；测试不得无提示覆盖用户存档。
- 保留与当前任务无关的用户或其他代理改动，不顺带重构。

## Dual Grid 地形约束

- Dual Grid、TileMapDual、15-piece、风车母图或自动地形笔刷任务，先阅读
  `.agents/skills/dual-grid-windmill-creation/SKILL.md`。
- 插件安装、修复或版本问题，先阅读
  `.agents/skills/godot-tilemapdual-deployment/SKILL.md`。
- 固定使用 TileMapDual `v5.0.2`；插件目录为 `addons/TileMapDual`。
- Dual Grid 是四角掩码 `0x1–0xF`，不是 47-piece Blob Autotile。不要把 1024×1024 风车母图
  当成可直接绘制的最终图集。
- 当前笔刷事实源为 `art/windmill_master.png`；编译产物在 `assets/compiled/`，TileSet 在
  `resources/tilemapdual_standard.tres`，演示场景在 `scenes/tilemapdual_demo.tscn`。
- 在编辑器中选中 `TileMapDual` 节点，从 TileMap 面板的 `Tiles` 标签选择完整块 `0xF` 绘制。
  普通 `Terrains` 标签为空不代表插件失效。

## 验证与交付

- 代码、场景、资源或项目设置发生变更后，执行与风险相称的 Godot headless 导入、加载或运行验证。
- Dual Grid 笔刷必须覆盖实心块、横竖走廊、L 角、凹角、单格、单格洞及两种对角格，并确认
  `0x1–0xF` 全部掩码可达。
- 自动验证不能替代视觉验收；涉及画面、像素接缝、布局或交互时，明确给出用户在 Godot 编辑器中的
  复核入口。
- 交付时列出新增或修改的关键文件、验证结果和仍需用户确认的视觉事项。
