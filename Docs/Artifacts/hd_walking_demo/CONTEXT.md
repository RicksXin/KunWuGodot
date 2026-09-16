# Map01 任务状态包
更新：2026-09-14。只作为续接摘要，不覆盖正式数据或产品文档。恢复时读取最新用户指令、本文件和相关强制技能，不重放历史。

## 当前范围
- 最新工程任务：角色经过紫色 adjust 区域时半透明，已实现，待用户实机复核。
- 用户明确暂停资源点特效；不自动继续资源或宝箱制作。
- 最新请求是压缩上下文，未授权额外功能。

## 已确认地图契约
- 唯一正式 Map01 为高清连续坐标地图，旧Demo已迁入出征；用户明确授权替代旧28×64约束。技能及部分README/MIGRATION中的格子描述有残留，不能据此还原旧图。
- 入口：营地入山整备/出征、继续探索 → `scenes/map.tscn`，不是设置中的Demo入口。
- `data/maps/map_01.json`：世界897×1938.5411681914145，出生(450,1890)，31对象及互动规则。
- `data/maps/map_01_regions.json`：原始画布2488×5692，36 collision、17 adjust；`map_01_manifest.json`为配套清单。
- 正式底图 `assets/maps/map_01/map01_background.png`，场景 `scenes/maps/map_01.tscn`。背景仅视觉，不从像素反推道路。
- 红色原始多边形直接参与移动和寻路，显示与判定共用坐标转换；紫色不阻挡通行。不得重画、过滤大区或恢复旧手绘路线。
- 默认缩放120%，正常100%–150%，Debug当前14%–220%（不能称任意）。寻路需长按0.45秒，允许12屏幕像素抖动，单击不触发。
- 同类地图规范：`Docs/Tech/高清地图与外部标注接入规范.md`。

## 紫色区域遮挡：已实装
- `scripts/maps/map_navigation.gd`：从同批JSON加载`external_adjust_polygons`，沿用source_to_world；`is_in_adjust_region()`按世界坐标判定，完全不参与can_walk。
- `scripts/scenes/map_scene.gd`：每帧`_update_actor_occlusion()`按角色足点判断；进入降到42%不透明度，离开恢复100%，约0.15秒平滑过渡；独立于Debug标注开关。
- 角色当前绘制入口 `scripts/maps/map_actor.gd`；这是整个人物透明处理，并非按身体像素局部遮挡。
- `tools/validate_adjust_occlusion.gd`验证17/36数量及进入/离开透明度通过；headless有本机证书警告，无脚本失败。未写真实存档。待用户确认实际遮挡强度。

## 回城阵盘：已实装并获批准
- `assets/maps/map_01/points/return_platform.png`为高清底座；`return_rune.png`为批准的生成纹样。
- `scripts/maps/return_platform.gd`、`return_platform_fx.gd`：底座和光纹固定位置/尺寸，固定UV、3秒环向亮度流动；确认归营时仅增强原纹路亮度。禁止恢复上下漂移粒子、收缩波或直接播放漂移的生成帧。
- `map_01.json.returnPoint`：位置(450,1890)，互动半径28，宽68。靠近归营、确认动画、取消和正常结算已接通`expedition_ui.gd`/Game。
- `tools/validate_return_platform.gd`图形验证PASS（取消/确认/动画/结算），未写真实存档。
- 原始16帧生成序列因纹样漂移已废弃，仅保留为候选记录；不能认为仍待正式接入。

## 资源点：候选预览，用户已暂停
- 现有8点：灵木3、玄铁2、灵粮2、灵晶1；灵粮是粮袋/石仓，不是植物。
- 正式游戏仍使用旧resource Marker，采集后隐藏；新高清资源、描边和菱形尚未实装，不得报告完成。
- 候选目录 `art/candidates/map01_resource_points/`：wood/iron/grain/crystal.png（1254×1254真实RGBA）、sources.json、contact_sheet.png。
- 地图预览map_south.png、map_north.png：按原对象坐标放置，木宽52、其他44，足点偏移高度1/4；120%缩放，临时关闭迷雾，仅隔离运行。
- 用户反馈过于融入背景。已制作`interaction_glow.gdshader`和`interaction_preview.gif`：淡金Alpha外缘呼吸描边、固定菱形、靠近28单位显示采集文字并增强亮度。仅图形演示通过，演员靠近为预览脚本模拟，不代表寻路/采集验证。
- 资源特效没有最终批准；宝箱尚未制作。

## 关键入口与验证边界
- 地图控制`map_scene.gd`、业务面板`expedition_ui.gd`；导航/标注/角色/迷雾在`scripts/maps/`。
- `scripts/autoload/game.gd`负责连续位置、距离扣粮、状态、存档和归营；`config_repository.gd`加载正式数据。
- `tools/validate_map01_formal.gd`历史验证PASS，涵盖碰撞、对象可达、状态和迁移；不能冒充本轮重新跑过全项目测试。
- 正式地图未按本轮特效变更碰撞或资源奖励。

## 禁止事项与下一步
- 保留其他任务的战斗、营地、配置等改动，先针对性核对工作树，不批量回滚/清理。
- 测试必须`-- --no-profile-write --ignore-config-cache`；不改用户真实存档，不依赖或修改上级Cocos工程。
- 不自动生成新素材、不使用Meowa扣分、不绕过Aseprite试用导出限制、不擅自创建新任务或提交。
- 生图返回不得text输出整个结果（含巨量Base64）；用generatedImage或仅输出output_hint/路径。
- 下一步等待用户反馈紫色区域半透明效果；只有用户恢复资源任务才继续候选实装。

## 2026-09-14 用户提供人物包试看
用户要求检查并把Downloads/wuxia-xianxia-free-pack中的20位像素角色放到地图看效果。20张384×832 RGBA，64×64帧，6列13行；示例行走第8/9/10行，下/左/上，右镜像。包内只写免费，未见商用/署名范围，未确认正式发布许可。已隔离Godot运行20人物5×4陈列于Map01山门广场，角色scale0.65、地图120%、关闭迷雾，原地循环三方向行走。`art/candidates/wuxia_pack_review/map_preview.gif`、map_preview.png与characters.txt编号对照。渲染PASS；未替换正式人物、未写存档。最新任务已完成预览，等待用户选型；资源仍暂停，紫色遮挡实现保留。

人物随机漫游预览已完成：`art/candidates/wuxia_pack_review/wander_preview.gd`及wander_preview.gif；20份原图复制到候选characters目录，预览不依赖Downloads。20人随机分散山门广场，复用正式nav.path/move/can_walk和is_in_adjust_region；足点Node2D与绘制偏移分离，进入紫区42%/退出100%平滑渐变。180帧15秒验证：3081移动样本、189次adjust命中、0碰撞违规。部分初始/目标点从可通行紫区抽样以覆盖遮挡。120%镜头，迷雾临时关闭，未改正式人物/存档。当前仅候选漫游脚本，不是正式地图NPC系统；下一步等用户反馈。

## 人物Demo正式入口（最新，替代“仅导出预览”状态）
用户要求在设置中进入实时Demo。已接入营地设置→人物漫游 Demo；`scenes/character_demo.tscn`、`scripts/scenes/character_demo.gd`运行20人随机漫游，复用正式Map01底图/红色JSON导航/紫区42%渐变。20张图位于`assets/debug/wuxia_characters/`，只用于Demo。camp.gd新增入口；Demo是根节点下独立显示，营地临时隐藏/暂停，返回按钮或Esc恢复原设置和窗口尺寸，不创建出征、不写Game.profile、不自动归营。提供碰撞/调节层开关；当前镜头在山门广场，漫游目标限制该片区。`tools/validate_character_demo.gd`图形验证PASS：从设置按钮进、20人300步无穿碰撞、档案内容不变、返回设置恢复。截图/private/tmp/character_demo_live.png。正式出征不自动加入这20人。用户明确要求此Demo，优先于旧禁止另建预览场景规范。

## Demo操控修正（最新）
用户纠正为自己控制1人，其余19人全地图活动，替代全部自动漫游/山门固定镜头。character_demo.gd中第一位为玩家，出生(450,1890)，WASD/方向键/屏幕方向按钮移动，镜头随行并限制地图边界；玩家不自动选路。其余19人分带随机分布在全图可通行坐标，目标从整张图可通行池随机选择，复用nav.path/move，无法到达则延迟重选；每帧最多1次NPC路径规划。所有人沿用紫区42%渐变。入口仍设置→人物漫游Demo，返回设置/存档隔离保留。validate_character_demo.gd图形PASS：玩家静止不自走、输入后移动、NPC南北分布跨度超过地图65%、全员碰撞合法、档案不变、退出恢复设置。截图/private/tmp/character_demo_live.png。

Demo待机修正：用户指出停下仍是跑步岔腿。已放大核对动作表，停止时由跑步行7/8/9首帧改用10/11/12首帧（均为0起算），作为朝下/左/上收腿站姿；向右沿用镜像，保持最后朝向，20人共用。不是声称存在已命名的完整四向呼吸动画。validate_character_demo.gd新增静止帧及方向/镜像检查；20份素材的3个站立帧均非空。资源特效继续暂停。

Demo人物碰撞与交互：character_demo.gd新增人物脚底圆分离（沿用actor_radius，两人最小距离10），<=2单位分步移动防穿透并沿轴滑动；全员出生去重。靠近32单位且nav.segment_clear时显示与修士编号交谈按钮/E；对话为Demo问候，无战斗交易，暂停所有人物，告辞/Esc关闭后恢复。Esc有对话先关对话，否则退出Demo。validate_character_demo.gd图形PASS：逐步两两无重叠、60单位移动防穿人、交互开启/关闭/暂停玩家、既有地形/存档/退出检查。截图/private/tmp/character_demo_dialogue.png。功能仅设置Demo，不扩展正式出征。
