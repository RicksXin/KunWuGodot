# 昆吾禁地 · Godot 迁移版

这是从冻结的 Cocos Creator 源项目重建的独立 Godot 4 项目。它不读取上级目录中的 Cocos
工程，也不需要安装 Node.js、pnpm 或 Cocos Creator。

当前覆盖的可玩流程为：

```text
启动 → 营地横滑 → 灵源院生产 → 入山整备
→ map_01 迷雾探索、宝箱和固定遭遇 → 战斗 → 归营结算
```

制作经验：[营地制作复盘与野外地图参考](Docs/Tech/营地制作复盘与野外地图参考.md)。

## 正式营地（2026-09-24）

启动和归营现在进入已确认的横版营地（1280×720），包括七座建筑、传送阵、三位漫游 NPC、溪流瀑布和底部流雾。
鼠标/触屏拖动查看营地局部，滚轮/捏合缩放；默认 1.1 倍，限定 1.0～1.35 倍，无法缩小到营地全貌。WASD 控制棕发青衣角色行走，也可点击空地寻路，镜头平滑跟随；靠近建筑或 NPC 时显示 E 提示，按 E 打开建筑面板或与 NPC 对话。手动拖动暂停跟随，再次点击行走恢复。下方拖动极限为传送阵可见底部以下 15px。点击建筑打开原有业务面板。头像、资源、任务和底部图标沿用原 UI，仅适配横版位置与等比显示。
顶部资源和底部入口固定，业务面板在横屏中居中适配，关闭后保留营地视角。启动页和其他旧面板继续使用各自原有基准。
编辑器选中建筑可设置「建筑碰撞」「前后遮挡」及碰撞宽度/深度倍率，橙色轮廓表示脚底阻挡范围；保存后重新进入营地生效。
布局编辑器与正式营地共用 `data/prototypes/camp_tile_rebuild.json`，目录名为历史沿用，不再代表另一个运行布局。
验证入口：`tools/validate_formal_camp.gd`（必须带 `-- --no-profile-write --ignore-config-cache`）。

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

启动页与旧面板保留 `375×817` 基准；进入正式营地会切换 `1280×720` 横版窗口。启动窗口默认放大为约 2 倍（`750×1634`），这样像素画面不会
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

如果在 Godot 编辑器里按 `F5`，编辑器可能把游戏嵌入固定的竖屏预览框，地图的设备横向切换不会改变这个外层框。要验收地图的真实横屏窗口，请双击项目根目录的 `run_kunwu_game.command`，或使用上面的“直接启动游戏”命令；也可以在编辑器游戏视图右上角菜单中关闭“嵌入游戏”。

## 三、游戏怎么操作

### 营地

- 按住营地画面的非按钮区域拖动，可在限定范围内查看不同局部；原 HUD 固定显示，玩家不能缩小到营地全貌。
- 点击“灵源院”可以分配杂役、招募杂役和升级资源储量。
- 点击中央发光的“传送阵”建筑，可以打开入山整备。
- 点击底部最左侧的齿轮图标可以立即保存或重置新档。
- 其他未开放建筑会显示明确提示。

### 地图

- 正式 Map01 使用用户确认的高清底图与外部 JSON 碰撞/调节层，地图入口为营地的“设置 → map01 · 出征”。支持 WASD、方向键、长按寻路（约0.45秒；短按和拖动不触发）、迷雾、灵粮消耗、休整、宝箱、遭遇、战斗和归营；Debug 可查看碰撞层与编辑临时禁行区域。
- 进入野外探索页后会切换为 `817×375` 横屏画布，离开地图进入营地或战斗时自动恢复 `375×817` 竖屏。
- 按住地图区域拖动，可以查看当前位置之外的区域；拖动不会误触背后的地图格。
- 使用双指捏合或触控板捏合缩放地图；桌面端也可按住 `Command/Ctrl` 滚动鼠标滚轮。
- 界面右下角的“缩放”滑轨可以在 `100%–150%`（Debug 为 `14%–220%`） 之间精确调整。每次缩放都会尽量以玩家位置重新居中，
  玩家靠近地图边缘时按边界夹紧，但不会离开视野。拖动和缩放是正式地图的共用功能。
- 点击界面下方的 `↑ ↓ ← →` 按钮按连续距离移动。
- 键盘也可以使用方向键或 `W/A/S/D`。
- 只能上下左右移动，不能斜走，也不能穿过墙壁。
- 点击相邻的可见格也可以移动。
- 移动会消耗灵粮；灵粮耗尽后继续移动会进入断粮衰竭。
- 走到宝箱、故事事件或红色敌人标记上，会弹出对应操作。
- 右上角“休整”会打开野外休整层，可消耗野外食材补灵粮或恢复队伍生命；点击“结束休整”后才能继续移动。
- 右上角“背包”查看本次入山所得；战斗胜利后的战利品也会先进入这个临时背包。
- 必须回到入口传送阵并确认才能正常归营；有归营符时可以点击右上角“归营”直接返回。

三盏阵灯已接入正式探索：靠近后按 **E** 或点击互动按钮，选择现有修复方案。
第一灯可用队伍最高法力≥18校正，或携带开山镐拆壳；第二、第三灯按剧情直接修复。
修复成功播放2秒过渡并保留激活灯体，状态随原有存档保存；地图左上显示阵灯进度。
地形编辑器中的E仍是无存档预览；作者地形尚未替换正式高清地图。

### 战斗

- 四名修士默认自动战斗。
- 点击右上角“暂停”会同时冻结战斗计时、人物动画和受击特效；点击“继续”恢复战斗。
- 点击修士卡片底部的姓名可以切换自动/手动状态。
- 手动状态下，行动就绪后会出现三技能面板；冷却中的技能会显示“冷却”。
- 手动单体技能先点击技能，再点击标有“点击选择”的敌人或队友确认目标；确认后才消耗行动与冷却。可点击“取消选择”或改选技能；群体、自身技能直接释放。
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
├── assets/              图片、字体、正式地图背景和许可证
├── resources/           其他 Godot Resource 文件
├── addons/              TileMapDual v5.0.2 插件
├── tools/               数据、场景和 Dual Grid 无界面校验工具
├── art/                 本地美术制作、候选与来源归档（除说明外不提交）
├── third_party/         第三方原始包和许可证归档，不进入运行时导入
├── Docs/                Godot 文档事实源、历史审计与评审产物
├── MIGRATION.md         Cocos 到 Godot 的技术迁移映射
└── .godot/              Godot 自动生成的缓存，不需要手工修改
```

内部字段和资源 ID 保持源项目兼容。例如 `spiritStone` 的显示名仍为“灵晶”，
`immortalCoin` 显示为“灵石”。项目基准视口为 `375×817`，使用 Compatibility 渲染器；
像素角色和 UI 使用 nearest，Map01 高清背景在场景节点上明确使用 linear filtering。

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

## 九、Codex Godot MCP

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

本机可以安装 TileMap 编辑辅助工具，但当前正式 Map01 不使用 TileMapLayer 或 TileSet。Map01 的
移动与阻挡直接编辑 `data/maps/map_01.json`，不得通过旧 TileMap 配置回写。

## 十、在 Godot 中编辑 Map01

Map01 已经是可直接编辑的 Godot 场景：

```text
res://scenes/maps/map_01.tscn
```

当前运行中的 Map01 是用户确认的高清连续坐标版本：

1. 在左下角“文件系统”面板依次展开 `scenes` → `maps`，双击 `map_01.tscn`。
2. 场景中的 `HDBackground` 使用 `2488×5692` 配套底图；区域数据在 `data/maps/map_01_regions.json`。
3. `data/maps/map_01.json` 保存31个对象的连续世界坐标、文案、奖励和状态条件。
4. 红色 collision 区域约束键盘、点击寻路和连续移动；紫色 adjust 区域用于独立调节语义。
5. 按 `F5` 从营地“设置 → map01 · 出征”验证休整、迷雾、灵粮、事件、战斗和归营。


坐标使用游戏领域坐标：X 向右增大、Y 向上增大；JSON 行则从屏幕顶部向下排列，换算为
正式对象文案、奖励和事件语义位于 `data/maps/map_01.json`，遭遇定义位于
`data/config/combat_map01_formal.json`；不要把业务内容复制进背景或纯表现节点。

Map01 包含36个用户编辑碰撞区域、17个调节区域、31个正式对象、13个地图战斗 Marker、14个遭遇和动态状态阻挡；入口为世界坐标 `(450,1890)`。三灯、暗道、双向阶梯、Boss 门禁和出口继续由 JSON 状态与运行时
Overlay 表达。项目内没有第二套 Map01、候选场景、Demo 或 Preview。

### Map01 重做：地形编辑阶段（2026-09-24）

重新打开工程，在编辑器顶部选择 **Map01 地形**。已扩展为1096个地形单元，包含入口、废营平台、东西双路、侧向支路、北坡汇合与山门前庭；左键绘制、右键擦除、中键平移、滚轮缩放，可选择材质类别和高度层。第二行提供放大/缩小、100%和5–400%缩放滑条；Mac触控板支持捏合缩放、双指平移，也可空格＋左键拖动画布。被高处遮挡的格子可打开“平面编辑”修改；支持撤销、重做和保存。

地形草稿保存在 `data/maps/map_01.json` 的 `terrainAuthoring` 字段，已按确认布局复用营地土面、旧石路和岩壁材质。点击“试玩地形”可用 WASD/方向键行走、点击寻路，检查阶梯高差和山体碰撞；滚轮有限缩放，点击“返回编辑”恢复全图。试玩不写玩家存档，尚未替换现有正式探索地图。 已补齐31个对象占位：资源绿色、敌人红色、剧情金/青色，并预留2处蓝色休整区；可按类别筛选或打开全部名称，靠近按E查看说明。休整区仅为布局预留，试玩不触发正式战斗。暗道正式首通奖励已配置1件法器，编辑器试玩不发奖。进展和验证见 [重做状态](Docs/Artifacts/map01-rebuild/CONTEXT.md)。

## 在线灵源院资源模块

独立在线入口：双击根目录 `run_resource_online_test.command`。它读取相邻 KunWuAdmin 的本机开发身份，连接 `http://127.0.0.1:3100`。先在后台执行 `pnpm resources:setup`、`pnpm resources:dev`（或构建后 `pnpm resources:start`）。Godot 游戏运行时仍只依赖 Godot 与 HTTP。

在线页面支持五岗位生产、分配、招募、储量升级、生产进度与断线恢复；余额由服务端结算。后台 `/resources` 支持资源目录、生产配置审核发布、模拟、余额调整和流水。满仓停止生产且不再耗粮。

此入口使用独立测试身份，并禁用真实 `kunwu_profile.json` 写入；在线缓存位于 `user://resource_tests/`。默认营地仍使用原单机流程。正式账号与旧档迁移、其他玩法统一账本属于后续上线接入，不能混用两份余额。

- [已确认 PRD](Docs/PRD/07_资源管理与灵源院前后端分离_PRD.md)
- [实装技术方案、接口与验收命令](Docs/Tech/资源管理与灵源院前后端分离技术方案.md)
- Godot 编辑器复核入口：`scenes/resource_online_test.tscn`；需要启动器提供联调身份，推荐先用上述启动器运行。

### 正式营地招募费用接入（2026-09-16）

正式灵源院的招募弹窗与扣款已接入资源后台的**已发布**费用表。后台入口 `/resources` → 生产配置 → 第7–12人招募费用；编辑后须保存、审核、发布。游戏启动营地后同步，每30秒检查新配置；地址在 `project.godot` 的 `kunwu/resource_config_base_url`（本机默认 `http://127.0.0.1:3100`）。可用 `KUNWU_RESOURCE_API_URL` 覆盖，渠道沿用 `KUNWU_CONFIG_CHANNEL`。

每次招1人，上限12人；旧档超上限人数保留，停止继续招募，不自动裁减人数。首次无法取得配置时禁用招募；有已发布缓存时使用缓存，绝不回退到旧“50粮招5人”。价格在确认期间变化时，旧确认不能按新价扣款。

这次接入的是招募配置，扣款仍走当前本地 `Game` 存档；不等于资源余额已整体迁移到服务器。验证入口：`tools/validate_recruitment_config.tscn`，测试带 `--no-profile-write --ignore-config-cache --recruitment-http-check`。
