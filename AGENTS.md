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

- Map01 绘制、图层修改、Marker 调整或地图一致性验证，先阅读
  `.agents/skills/kunwu-map01-authoring/SKILL.md`。
- Dual Grid、TileMapDual、15-piece、风车母图或自动地形笔刷任务，先阅读
  `.agents/skills/dual-grid-windmill-creation/SKILL.md`。
- 插件安装、修复或版本问题，先阅读
  `.agents/skills/godot-tilemapdual-deployment/SKILL.md`。
- 固定使用 TileMapDual `v5.0.2`；插件目录为 `addons/TileMapDual`。
- Dual Grid 是四角掩码 `0x1–0xF`，不是 47-piece Blob Autotile。不要把 1024×1024 风车母图
  当成可直接绘制的最终图集。
- TileMapDual 插件仅作为后续地图可能使用的通用工具保留；当前正式 Map01 不使用 TileMap、
  Dual Grid、15-piece、风车母图或 `resources/tilemapdual_*.tres`，也不存在 Map01 Dual Grid Demo。
- 不得把已归档的 Map01 TileSet、笔刷、组件或预览场景恢复为运行事实源。

## 地图生成式美术工作流

- 任何地图图片生成、提示词、母图检查、清稿、Tile、阻挡、前景、地标、Marker 或地图操作图标任务，
  开始前必须阅读 `Docs/ArtAssets/18_地图生成式美术生产与模型分工规范.md`。
- 固定优先级为“复用现有 Approved 素材 → 本地确定性处理 → ChatGPT 会员网页生成 → 经逐次批准的
  Meowa 升级 → 用户视觉批准”。ChatGPT 是默认生成供应方；Meowa 不是默认供应方。
- ChatGPT 初稿和一次针对性修正仍无法解决严格俯视、状态对齐或高价值大型地标结构问题时，才可提出
  Meowa 方案；提出方案不等于获得扣分授权，仍须遵守下方 Meowa 积分红线。
- 生成模型只产出候选母图，不直接生成碰撞、对象坐标、迷雾或 Godot 场景。当前 Map01 经用户视觉
  批准后采用一张高清整图作为纯视觉背景；可走格、阻挡、对象坐标和互动仍必须由正式 JSON 与运行时
  Overlay 独立表达，不得从背景像素反推。
- Alpha、裁切、硬边、最近邻缩放、有限色盘、分层、Tile 编译、联系表、Godot 组件和自动验证由本地
  确定性流程完成，不消耗 Meowa 积分。任何候选只有在用户视觉确认后才能晋升为 Approved 运行素材。

## Meowa API 积分红线

- 使用 Meowa Skill、CLI 或 API 前先阅读 `Docs/Tech/Meowa_API调用规范.md`。Meowa 只作为开发期
  素材生产工具，不得成为 Godot 运行时依赖。
- 默认禁止调用任何可能消耗积分的接口。缺少素材、用户说“继续/开始做/可以”或已配置 API Key，
  都不构成扣分授权。
- 每次扣分提交前必须向用户说明用途、命令/能力、生成数量、输出契约、预计积分和最高积分；只有用户
  对该次提交明确批准最高积分后才能执行。授权不跨批次、不跨命令、不自动延续。
- 扣分命令只能通过 `tools/run_meowa_guarded.py` 执行；不得用 `curl`、直接运行
  `meowart_api.py`、网页自动化或其他方式绕过门禁。未知价格、无法计算上限或被门禁列为阻止的能力
  一律暂停并请求用户决定。
- 任务失败、超时或结果不合格时不得自动重新提交。优先轮询、恢复或下载原 Job；任何重新生成、增加
  变体、追加抠图或升级质量都需要新的单次授权。
- 查余额、查公开模板/参考、轮询与下载已有 Job 可作为只读操作执行，但不得借此提交新任务。取消已有
  Job 仍应符合用户当前意图。
- 调用前先检查项目现有素材、用户提供素材、缓存结果和本地确定性处理是否能完成；生成结果先进入
  `art/source_archive/meowa/` 或 `art/candidates/`，通过技术与视觉验收后才能晋升到 `assets/`。
- API Key 只允许存在于本机环境变量或被 Git 忽略且权限受限的 `.env`；不得输出、记录、提交、截图
  或写入命令参数。门禁日志只记录命令、批准上限、预估积分和最终状态；Job ID 与服务端返回的实际
  积分保留在对应任务的安全结果清单中（如果服务端提供），不得伪造。
- Spine 当前没有项目运行时且公开 API 定价/契约不完整，默认阻止；只有在用户单独批准试验、明确
  Godot 运行时与许可证方案后，才能修改门禁策略。

## 验证与交付

- 代码、场景、资源或项目设置发生变更后，执行与风险相称的 Godot headless 导入、加载或运行验证。
- Dual Grid 笔刷必须覆盖实心块、横竖走廊、L 角、凹角、单格、单格洞及两种对角格，并确认
  `0x1–0xF` 全部掩码可达。
- 自动验证不能替代视觉验收；涉及画面、像素接缝、布局或交互时，明确给出用户在 Godot 编辑器中的
  复核入口。
- 交付时列出新增或修改的关键文件、验证结果和仍需用户确认的视觉事项。
