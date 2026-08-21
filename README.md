# 昆吾禁地 · Godot 迁移版

这是从冻结的 Cocos Creator 源项目重建的独立 Godot 4 项目。它不读取上级目录中的 Cocos
工程，也不需要安装 Node.js、pnpm 或 Cocos Creator。

当前覆盖的可玩流程为：

```text
启动 → 营地横滑 → 灵源院生产 → 入山整备
→ map_01 迷雾探索、宝箱和固定遭遇 → 战斗 → 归营结算
```

## 一、第一次运行

### 1. 确认 Godot 已安装

本项目需要 Godot 4.7 或更新版本。当前这台 Mac 已经安装在：

```text
/Applications/Godot.app
```

如果以后需要重新安装，请从 [Godot 官方网站](https://godotengine.org/download/) 下载普通版
Godot 4，不需要下载 .NET/C# 版本。

### 2. 导入项目

1. 在 Finder 中打开“应用程序”，双击 `Godot.app`。
2. 出现“项目管理器”后，点击左上角的“导入”或“Import”。
3. 选择下面这个文件：

   ```text
   /Users/zhangxiaoen/Desktop/Game/KunWuGodot/project.godot
   ```

4. 点击“导入并编辑”或“Import & Edit”。
5. 第一次打开时，Godot 会自动导入运行图片和字体。等待右下角导入进度结束后再运行。

以后再次打开 Godot 时，项目管理器会直接显示“昆吾禁地”，双击项目即可进入。

### 3. 启动游戏

进入 Godot 编辑器后：

1. 点击编辑器右上角的三角形“运行项目”按钮。
2. 或直接按键盘 `F5`。Mac 如果把 F5 当作系统功能键，需要按 `Fn + F5`。
3. 项目已经配置好主场景，不需要再选择场景。
4. 等待启动画面结束，会自动进入营地。

项目内部仍按 `375×817` 设计，但桌面启动窗口默认放大为约 2 倍（`750×1634`），这样像素画面不会
缩在一个很小的手机尺寸窗口里。窗口可以直接拖拽右下角调整大小。如果 Godot 把游戏嵌入编辑器，
游戏视图顶部会出现 `1.0×`：点开后选择 `2.0×` 或“适应/Fit”即可放大；也可以点游戏视图右上角
的三点菜单，切换为独立游戏窗口。

要停止游戏，关闭游戏窗口，或点击编辑器右上角的方形“停止”按钮；快捷键是 `F8`。

> `F5` 是从启动页运行整个游戏。`F6` 只运行编辑器当前打开的单个场景，第一次使用时请优先用
> `F5`。

## 二、直接从终端运行

不想操作 Godot 项目管理器时，可以打开 Mac 的“终端”，执行：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --path "/Users/zhangxiaoen/Desktop/Game/KunWuGodot"
```

打开 Godot 编辑器而不是直接启动游戏：

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --editor \
  --path "/Users/zhangxiaoen/Desktop/Game/KunWuGodot"
```

## 三、游戏怎么操作

### 营地

- 按住营地画面的非按钮区域左右拖动，可以查看完整横向全景；全景会一直延伸到透明 HUD 后方。
- 点击“灵源院”可以分配杂役、招募杂役和升级资源储量。
- 点击中央发光的“传送阵”建筑，可以打开入山整备。
- 点击底部最左侧的齿轮图标可以立即保存或重置新档。
- 其他未开放建筑会显示明确提示。

### 地图

- 点击界面下方的 `↑ ↓ ← →` 按钮逐格移动。
- 键盘也可以使用方向键或 `W/A/S/D`。
- 只能上下左右移动，不能斜走，也不能穿过墙壁。
- 点击相邻的可见格也可以移动。
- 移动会消耗灵粮；灵粮耗尽后继续移动会进入断粮衰竭。
- 走到宝箱、故事事件或红色敌人标记上，会弹出对应操作。
- 右上角“休整”会打开野外休整层，可消耗野外食材补灵粮或恢复队伍生命；点击“结束休整”后才能继续移动。
- 右上角“背包”查看本次入山所得；战斗胜利后的战利品也会先进入这个临时背包。
- 必须回到入口传送阵并确认才能正常归营；有归营符时可以点击右上角“归营”直接返回。

### 战斗

- 四名修士默认自动战斗。
- 点击修士卡片底部的姓名可以切换自动/手动状态。
- 手动状态下，行动就绪后会出现三技能面板；冷却中的技能会显示“冷却”。
- 敌人生命降到 35% 以下后，可以点击右上角“撤离”。
- 胜利后会先进入战利品面板，可丢弃临时背包物品释放负重，再选择全部拾取或离开；返回地图后再回到入口归营，临时战利品才会正式入库。

## 四、存档在哪里

游戏会在生产调整、地图移动、战斗结算和归营时自动保存。Godot 脚本中使用的路径是：

```text
user://kunwu_profile.json
```

在这台 Mac 上，实际文件通常位于：

```text
~/Library/Application Support/Godot/app_userdata/昆吾禁地/kunwu_profile.json
```

`Library` 默认是隐藏目录。在 Finder 中可以按 `Command + Shift + G`，粘贴上面的目录路径前往。
也可以直接在游戏的“设置”页面点击“重置新档”。

## 五、后台配置

游戏启动时会优先读取上次完整校验通过的配置缓存；配置了后台地址后，再从配置中心获取当前渠道
的 manifest 与六个发布模块。全部模块的 schema、字节数和 SHA-256 都通过后才会整批切换；下载失败、
模块缺失或校验失败时继续使用缓存，首次运行则回退到 `res://data` 内置配置。

本地联调 KunWuAdmin development 渠道：

```bash
KUNWU_CONFIG_BASE_URL=http://127.0.0.1:3100 \
KUNWU_CONFIG_CHANNEL=development \
/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/zhangxiaoen/Desktop/Game/KunWuGodot"
```

不设置 `KUNWU_CONFIG_BASE_URL` 时不会发起网络请求，单机流程保持可用。生产导出可在项目设置的
`kunwu/config_base_url` 与 `kunwu/config_channel` 中写入部署环境地址。

## 六、项目目录说明

```text
KunWuGodot/
├── project.godot        Godot 项目入口和分辨率、渲染器配置
├── scenes/              启动、营地、地图、战斗场景
├── scripts/             GDScript 游戏逻辑和界面代码
├── data/                角色、职业、地图、战斗和本地化 JSON
├── assets/              图片、字体、地图 tileset 和许可证
├── resources/           TileSet 等 Godot Resource 文件
├── addons/              TileMapDual v5.0.2 插件
├── tools/               数据、场景和 Dual Grid 无界面校验工具
├── art/                 本地美术制作、候选与来源归档（除说明外不提交）
├── third_party/         第三方原始包和许可证归档，不进入运行时导入
├── Docs/                Godot 文档事实源、历史审计与评审产物
├── MIGRATION.md         Cocos 到 Godot 的技术迁移映射
└── .godot/              Godot 自动生成的缓存，不需要手工修改
```

内部字段和资源 ID 保持源项目兼容。例如 `spiritStone` 的显示名仍为“灵晶”，
`immortalCoin` 显示为“灵石”。项目基准视口为 `375×817`，使用 Compatibility 渲染器和
nearest 像素过滤。

`art/` 是本地制作工作区，不是运行时依赖。用户视觉确认后的正式素材晋升到 `assets/` 才进入主仓库；
制作原图、候选、联系表和评审截图应另行备份，不随主仓库推送。

## 七、常见问题

### 打开后图片暂时不显示

第一次打开项目时先等待右下角资源导入结束。不要在导入过程中运行游戏。如果仍未显示，可以在
Godot 的“文件系统”面板中右键 `assets`，选择“重新扫描”或重新打开项目。

### 点击运行后进入的不是启动页

请使用右上角“运行项目”按钮或 `F5`，不要使用“运行当前场景”的 `F6`。

### 项目提示缺少文件

确认导入的是 `KunWuGodot/project.godot`，而不是上一级 Cocos 项目的文件。不要移动 `assets`、
`data`、`scenes` 或 `scripts` 目录中的单个文件。

### 想恢复最初状态

在营地点击“设置”→“重置新档”。也可以关闭游戏后删除
`kunwu_profile.json`，下次启动时会自动建立新档。

## 八、Codex Godot MCP

本机已为 Codex 注册 `godot-mcp`（`@coding-solo/godot-mcp@0.1.1`）。它通过 MCP 让 AI
读取项目结构、获取 Godot 版本、启动编辑器、运行项目和读取调试输出；它不是放在
`addons/` 中的游戏运行插件。

配置使用本机 Godot 4.7.1：

```text
GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot
工作目录=/Users/zhangxiaoen/Desktop/Game/KunWuGodot
```

配置文件位于 `~/.codex/config.toml`。重新启动 Codex 后，在 MCP 工具列表中应看到
`godot`。调用工具时项目路径使用：

```text
/Users/zhangxiaoen/Desktop/Game/KunWuGodot
```

如果需要移除或重新注册：

```bash
/Applications/ChatGPT.app/Contents/Resources/codex mcp remove godot
/Applications/ChatGPT.app/Contents/Resources/codex mcp add godot \
  --env GODOT_PATH=/Applications/Godot.app/Contents/MacOS/Godot \
  --env DEBUG=true \
  -- npx -y @coding-solo/godot-mcp@0.1.1
```

本机还安装了专门处理 Godot TileMapLayer 的 `godot-tilemap-mcp 2.0.0`。它可以读取隐藏在
`.tscn` 中的 `tile_map_data`、识别 TileSet、渲染图层预览，并通过可审查事务修改地图。项目语义
配置位于 `.godot-tilemap-mcp.json`；重新启动 Codex 后，MCP 工具列表中应同时看到
`godot` 和 `godot-tilemap`。

地图写入固定使用“检查 → 生成预览 → 检查差异 → 应用”的流程。不要启用
`--legacy-direct-writes`。TileMapDual 的最终半格拼接由 Godot 插件在编辑器和运行时生成，MCP 的
静态图片只能辅助检查，不能代替 Godot 中的接缝确认。

## 九、在 Godot 中编辑 Map01

Map01 已经是可直接编辑的 Godot 场景：

```text
res://scenes/maps/map_01.tscn
```

第一次绘制地面：

1. 在左下角“文件系统”面板依次展开 `scenes` → `maps`，双击 `map_01.tscn`。
2. 切换到编辑器上方的“2D”视图。
3. 在左上角“场景”树选中 `Ground` 节点。
4. 打开编辑器底部的 `TileMap` 面板，再选择 `Tiles` 标签。普通 `Terrains` 标签为空是正常的，
   本项目使用 TileMapDual，不从该标签绘制。
5. 在 4×4 图集中选择完整地面块 `0xF`，它位于图集坐标 `(2,1)`，然后在 2D 视图左键绘制。
   右键可擦除。`Ground` 中只能使用这个完整块，边角由 TileMapDual 自动计算。
6. 选中 `DifficultTerrain` 可以绘制会消耗更多灵粮的难行格；难行格必须同时存在于
   `Ground` 中。
7. 按 `Command + S` 保存，再用 `F5` 从完整启动流程测试移动、迷雾和事件。不要用 `F6` 把
   `map_01.tscn` 当成完整游戏页面运行，它只是地图布局场景。

入口、敌人、剧情点和宝箱位于 `Markers` 节点下。选中具体 Marker 后，在右侧“检查器”修改
`domain_cell`；这里使用游戏领域坐标，X 向右增大，Y 向上增大。不要直接拖动 Marker 的
`position`，脚本会根据领域坐标自动换算屏幕位置。事件文案、奖励和遭遇 ID 仍在
`data/maps/map_01_demo.json` 中配置。

当前地面使用已通过视觉 Gate 的灰蓝色荒土地面素材，已经规范化为 1024×1024 透明风车母图，
并编译为可自动衔接的 Dual Grid 笔刷用于 Map01；仍需在 Godot 编辑器中完成最终地图尺度的视觉验收。
枯黄旧路已经作为独立的 `resources/tilemapdual_map01_road.tres` Dual Grid 笔刷完成编译和验证，
演示入口是 `scenes/tilemapdual_road_demo.tscn`；它尚未绘入 Map01，灰盒仍是正式道路结构的事实源。
灰白山体已经作为 `resources/tilemapdual_map01_mountain.tres` Dual Grid 笔刷接入 Map01 的独立
`Mountain` 图层；94 个山体格严格取自当前 `15×15` 灰盒中 `Ground` 的补集，不改变碰撞或产品数据。
`GroundUnderlay` 是覆盖当前 `15×15` 活跃区的纯视觉地面底衬，位于山体下方用于消除透明边缘黑缝；
它不参与可行走格、碰撞、寻路或事件判定，地图逻辑仍只读取 `Ground`。
正式还缺水面/难行地形表现、地面装饰、树木岩石废墟，以及入口、宝箱、敌人、剧情点的地图图标。
补齐这些素材后可以继续增加专用图层和组件，不需要推翻现有地图逻辑。
