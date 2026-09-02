# 横版地图任务状态包（已废弃）

> 2026-09-02 用户确认：本方案是旧版俯视 Map01 预览，与本次“鬼谷八荒风格”新作无关。除非用户明确要求回溯旧方案，否则不得将本状态包或其入口当作新作事实源。

## 当前目标（暂停）

修正横版地图预览的启动入口与可视性，确保独立横版窗口不会误落到竖版 375×817；范围仅限独立横版视觉预览，不改正式竖版运行链、Map01 JSON、玩家存档或上级 Cocos 工程。

## 已确认事实

- 413 返回自 Codex 服务端 `http://api-ai-coding.bilibili.co/api/v1/codex/responses`，是请求体超限，不是 Godot 游戏逻辑错误。
- 横版预览是隔离入口：`project_landscape.godot` → `scenes/landscape_map_preview.tscn` → `scripts/scenes/landscape_map_preview.gd`，装饰层为 `scripts/scenes/landscape_map_art.gd`。
- 预览复用 `assets/maps/map_01/map01_background.png` 的视觉裁切，不改变 `data/maps/map_01_formal.json` 或正式 `scenes/maps/map_01.tscn`。
- 当前横版预览 README 已明确“未接入正式运行链”，交互只显示提示，不写 `user://kunwu_profile.json`。
- 横版预览现已使用完整背景作为可平移 `MapWorld`，鼠标/触控板拖动与垂直滚动条只改变视觉偏移。
- 横版配置必须从项目外目录启动；在项目根目录运行时 Godot 会优先自动发现竖版 `project.godot`。
- 已新增标准项目目录 `landscape_preview_project/`（含 `project.godot` 和同仓库资源软链接）；项目管理器应导入该目录内的 `project.godot`。
- `run_landscape_preview.command` 现在使用 `--path landscape_preview_project` 启动并强制 `gl_compatibility/opengl3`，可在 Finder 双击运行。
- 横版场景新增误启动保护：若从竖版 F6 打开且检测到高于宽的视口，会尝试将窗口调整为 1280×720；独立横版项目仍是首选入口。

## 已完成阶段

- 阅读 `AGENTS.md`、`README.md`、`MIGRATION.md`、Map01 authoring skill、地图美术规范及横版预览 README。
- 检查横版脚本、场景和项目配置；未发现 413 的项目内网络调用。
- Godot 4.7.1 headless 运行（强制 `gl_compatibility/opengl3`、`--no-profile-write --ignore-config-cache`）通过，退出码 0。
- 两个横版脚本 `--check-only` 解析通过，`git diff --check` 无输出。
- 2026-09-02 续接复核：横版入口和状态包仍完整；工作树已有的其他用户改动未触碰。
- 2026-09-02 横版交互修正：移除固定上方裁切，加入地图拖动、触控拖动和垂直滚动条；正式地图与存档边界不变。
- 2026-09-02 启动修正：README 改为先切到项目外目录再启动 `project_landscape.godot`，避免误进竖版视口。
- 2026-09-02 启动器修正：新增根目录双击启动脚本，避免误按主项目 F6 进入竖版视口。
- 2026-09-02 项目入口修正：增加标准 `landscape_preview_project` 项目目录，项目管理器可直接导入并运行横版主场景。
- 2026-09-02 用户截图确认项目管理器只显示根目录竖版项目；正确入口为 `landscape_preview_project/project.godot`，不是根目录 `project.godot`。
- 2026-09-02 可视性修正：横版场景加入误启动窗口保护，README 和启动器均强制兼容渲染器。

## 关键文件

- `project_landscape.godot`
- `scenes/landscape_map_preview.tscn`
- `scripts/scenes/landscape_map_preview.gd`
- `scripts/scenes/landscape_map_art.gd`
- `Docs/Artifacts/landscape_map_preview/README.md`
- 正式事实源：`data/maps/map_01_formal.json`、`scenes/maps/map_01.tscn`

## 压缩策略

- 后续续接只加载本文件、横版 README、上述 4 个横版入口文件，以及需要核对时的正式 Map01 事实源；不要把 `art/`、`third_party/`、`.godot/`、整份 Docs 或大图像素内容放进对话。
- 图片仅报告尺寸/哈希/必要预览，不输出 Base64 或整页 HTML。
- 413 无法通过修改 Godot 代码修复；若再次出现，应开启新续接并只粘贴“当前目标 + 已确认事实 + 待办”，不要重放完整历史和原始工具输出。

## 待办（暂停，等待新作入口）

- 如需继续改横版 UI，先由用户确认视觉方向，再只改独立横版文件。
- 首次用项目管理器导入标准横版目录后，等待资源扫描完成，再运行横版项目主场景。
- 若要把横版接入正式运行链，必须另行评审视口、输入、存档和 Map01 数据边界；本状态包不授权该迁移。

## 新作阻塞

- 当前仓库搜索到的仅是旧版《昆吾禁地》项目及其横版预览；未找到“鬼谷八荒风格”新作的 `project.godot`、场景、素材或设计文档。
- 继续工作前必须取得新作项目目录/`project.godot` 路径，或对应设计文档与参考图。

## 禁止事项

- 不删除或覆盖现有 `art/`、`.godot/`、正式 Map01、`project.godot` 或用户存档来“解决” 413。
- 不把 413 当作地图碰撞、Marker 或渲染错误处理。
