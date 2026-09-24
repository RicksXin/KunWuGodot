# 营地 TileMap 探索 · 唯一续接状态包

更新：2026-09-20；Blender 建模已续接到“优化百宝箱 Blender 建模”任务，严格控制上下文。

## Blender MCP 接入（2026-09-20）
- 用户已授权安装。PyPI `mcp-for-blender` 2.0.0 已安装，Blender 5.2 插件路径 `~/Library/Application Support/Blender/5.2/scripts/addons/blender_mcp.py`，已启用并保存用户首选项。
- Codex 全局 `~/.codex/config.toml` 新增 `mcp_servers.blender`：`/usr/local/bin/uvx --with 'cryptography<46' mcp-for-blender`；本机 x86 Python 默认 cryptography 50 源码构建受阻，改用兼容 wheel。`DISABLE_TELEMETRY=true`、`BLENDER_HOST=127.0.0.1`、`BLENDER_PORT=9876`；插件遥测 consent=false。
- 原百宝库窗口有未保存修改且 CUA 点击报 noWindowsAvailable，保留未动。另开 `art/candidates/camp-revival-3d-v1/revival.blend` GUI 实例，监听 localhost:9876；没有保存/覆盖模型。
- 完成真实 stdio MCP initialize/list_tools/get_addon_status/get_scene_info：31 工具、协议7匹配、Blender5.2.1、2413对象、23材质、遥测关闭；日志 `/tmp/kunwu-blender-mcp-test.log`。测试客户端已退出，Blender 服务仍运行。
- 当前 Blender MCP 工具已加载并实际完成 V3 几何修改、另存和导出。后续仅连接一个 Blender 服务端，勿重复启动争抢9876。未启用云端生成服务，未调用任何付费接口。

## 当前目标与边界
- 2026-09-23 后续完成：营地摆放默认1像素拖动，支持0.1像素X/Y输入、微调归零及整格搬移切换。微调保存visual_offset，逻辑占地/入口仍按格；整格模式同步搬移逻辑坐标。保留用户正在调整的JSON。
- 精细摆放验证：tools/validate_camp_fine_placement.gd通过不同缩放拖动、撤销、数值输入、临时保存回读、预览一致性与归零；原整格拖动回归通过，headless导入无脚本错误。既有集成测试空材质退出提示仍存在。
- 2026-09-23 最新范围：用户提供 Downloads/spritesheet 炼器坊序列帧，要求应用到营地编辑器，替换该建筑3D展示。
- 仅替换实验营地炼器坊视觉；其他建筑、地形、占地/入口/接近格、正式营地业务、Map01与存档保持原状。既往建模任务不属于本次范围。
- 资源：resources/prototypes/camp_forge_sequence/，原图8160×6080，22帧1632×1216，8FPS循环，保留原始颜色及透明度。
- 实现：Sprite2D共享适配器 camp_building_sequence.gd 使用隐藏AnimatedSprite2D驱动当前帧，兼容既有透明拾取、拖动、缩放、镜像、旋转与预览。
- JSON炼器坊去除model_3d，接入sprite_frames；门口图像锚点(920,1020)。未调用生成接口。
- 验证：Godot4.7.1二次headless导入无错误；tools/validate_camp_forge_sequence.gd图形及headless通过22帧播放/循环、锚点、镜像/旋转、透明拾取、拖动/撤销、编辑器与运行一致性。截图forge-sequence-editor.png。
- 既存问题：原布局校验在首个“无警告”断言失败；与HEAD原JSON比较，所有占地/通路警告完全相同。同时实例化编辑器与预览的集成测试输出空材质引擎错误；在HEAD原六座3D布局的同类测试中亦复现，功能断言通过。独立编辑器场景headless短跑无错误。
- 待用户视觉复核：炼器坊大小、门口落位及动画节奏；入口run_camp_layout_editor.command，选择炼器坊。

## 已确认事实与现有实现
- 入口：根目录 run_camp_tilemap_lab.command；场景 scenes/prototypes/camp_terrain_sample.tscn，默认15“瓦片营地重做”。
- 主文件：data/prototypes/camp_tile_rebuild.json、scripts/prototypes/camp_tile_rebuild.gd、tools/validate_camp_tile_rebuild.gd。
- 三层 TileMap、连续地面/岩壁、四处台阶、独立建筑、JSON占地/寻路、溪流/后沿松石/稀疏护栏。暗冷修仙色调，门窗保留暖色。
- 议事殿既有Approved素材，origin[5,0]、door[5,2]、door_anchor[110,181]、width336。当前代码/JSON锚点优先，旧历史锚点不再适用。
- 用户认可V4结构：百宝库平顶石堡、还魂殿六角攒尖祭殿、招贤馆主楼+侧亭连廊。V2/V3屋顶同质化方案已废弃，不恢复。
- V4候选来源 art/candidates/camp-west-buildings-v4，实验引用 resources/prototypes/camp_west_buildings_v4；透明稿已接入，摆放最终视觉仍待确认。

## 当前摆放与通道
| 建筑 | origin / 占地 | door / approach | 图像门槛anchor / 显示宽 |
|---|---|---|---|
| 百宝库 | [2,6] / 2×1 | [2,7] / [2,8] | [580,900] / 210 |
| 还魂殿 | [0,7] / 1×2 | [1,8] / [2,8] | [600,1180] / 180，mirror_x |
| 招贤馆 | [3,9] / 2×1 | [2,9] / [1,9] | [1395,530]遮挡侧入口 / 235，mirror_x |
- 门槛像素映射到逻辑door；等比缩小约29%～33%；还魂殿镜像朝院内；百宝库面向画面左下；招贤馆使用新后视角并镜像，入口朝画面左上，前景为后墙。三座alpha_cut0.88裁软晕，议事殿不裁。
- 招贤馆新源：art/candidates/camp-west-inward-v1/recruit-rear.png，PROMPT.md及SOURCE.json记录内置imagegen提示词/哈希；运行候选resources/prototypes/camp_west_inward_v1/recruit-rear.png。入口被主体遮挡，door_anchor为远侧逻辑锚点，不是可见前门。
- 三座facing分别treasury[0,1]、revival[1,0]、recruit[-1,0]；新增approach-door=facing回归。标签支持label_offset，百宝库标签置于自身屋顶上方避免误标招贤馆。
- west_courtyard.reserved_cells在JSON保留中央院路及两处台阶落脚通道，不可追加建筑阻挡。
- 共享Y排序处理角色/建筑；标签z_index20。显示路线叠加红色逻辑占地、青色可走节点、绿色门前接近线，便于人工复核。
- 注意：逻辑占地检查不证明图片底座完全吻合；仍需目视复核边缘、屋檐遮挡、行走时穿帮，不可称已最终批准。

## 本次续接验证与证据
- 删除stairs[4,11]，对应格由24降到0；岩壁/护栏自动闭合，新增断言禁止[4,10]直通[4,11]。新占地和保留院路同步，七门口仍可达。
- 修改：data/prototypes/camp_tile_rebuild.json、scripts/prototypes/camp_tile_rebuild.gd（锚点镜像）、tools/validate_camp_tile_rebuild.gd（删除台阶/镜像回归）。
- Godot 4.7.1 图形及headless验证均通过：占地存在且互不重叠/禁行、院路保留、入口邻接、门槛锚点、全可走格连通、七门口往返、途中改道、扩格、切场景。
- 当前截图：west-buildings-inward.png、west-buildings-inward-overview.png（本目录）；旧smaller/placement截图为废弃朝向版本，不作当前验收依据。
- 本轮Godot headless导入和图形导航/镜像/面向/删除台阶回归通过。仅候选视角替换，尚未用户视觉批准。
- 所有运行验证必须带 --no-profile-write --ignore-config-cache；Godot路径 /Applications/Godot.app/Contents/MacOS/Godot。

## 右侧三座（最新交付）
- 候选：art/candidates/camp-east-buildings-v1/{market,forge,garden}.png；PROMPTS.md/SOURCE.json保存内置imagegen提示词/哈希。RGBA1536×1024，运行副本resources/prototypes/camp_east_buildings_v1。
- 交易行：origin[10,0]，door[11,2]，approach[11,3]，anchor[540,850]，width220；低檐柜台/卷轴货棚。
- 炼器坊：origin[12,2]，door[13,4]，approach[13,5]，anchor[610,860]，width240；矮炉房/方烟囱，无烘焙烟雾。
- 灵源院：origin[9,3]，door[10,5]，approach[10,6]，anchor[440,820]，width245；院舍/晾药棚/双药圃，不带整块山体水车。
- 三者占地2×2、alpha_cut0.88、facing[0,1]朝左下入口；仅静态候选，尚未Approved或动效拆层。当前初始位置通路有效，用户后续自行调整。
- 全七座显示/门槛/入口/导航回归、编辑器模型及鼠标交互验证通过。首次导入新PNG时插件使用Image后备读取，避免空贴图调用。
- 当前全景：all-seven-buildings.png。在已打开的摆放页点击“重新读取”；若有未保存调整先处理它们。

## Godot编辑器摆放（当前交付）
- addons/camp_layout_editor/plugin.gd、panel.gd、canvas.gd、model.gd；project.godot已启用。顶部“营地摆放”页签，不是运行时菜单。
- 拖动/数值移动同步origin、door、approach；显示宽可调，橙色占地/绿色入口/蓝色保留院路；支持撤销和重新读取。
- 重叠/越界/高差/阶梯/院路/门口/连通检查只提示，不再禁存；使用临时文件替换并拒绝覆盖磁盘并发改动。仅显式“保存JSON”写回。
- ground_preview.png为专用编辑器地形辅助图，不是运行事实源。地形变更后用tools/capture_camp_editor_ground.gd刷新，重开插件；建筑改动无需刷新。
- tools/validate_camp_layout_editor.gd、tools/preview_camp_layout_editor.gd（含鼠标拖动）、现有运行验证通过；测试仅写临时文件，不改生产JSON或存档。
- 操作入口与限制：本目录EDITOR_PLACEMENT.md；界面截图editor-placement.png。当前用户编辑器有外部文件更改提示，未擅自处理其未保存场景。

## 最新编辑器修复验证
- 旋转验证：17.5°镜像组合、锚点不漂移、运行时与编辑器Transform一致、招贤馆带旋转正背切换往返、归零/撤销、-23.7°临时JSON保存回读均通过。
- canvas.gd：10%～600%缩放，Magnify/Pan手势及按钮；panel.gd：镜像和招贤馆正背切换；model.gd：取消地形禁存。
- runtime camp_tile_rebuild.gd支持visual_offset、越界门口node=-1、出生点被占时选可走格、点击不可达建筑反馈；不从图片创建可走地形。
- 独立场景scenes/prototypes/camp_layout_editor.tscn；无需找编辑器页签即可双击根目录run_camp_layout_editor.command。摆放与游戏预览入口明确分开。
- 模型保存/并发保护、实际鼠标拖动、捏合/按钮、镜像/视角往返、越界与出生点被挡运行安全测试通过。当前JSON摆放未修改。

## 百宝库3D样件
- 入口run_camp_treasury_3d.command；scenes/prototypes/camp_treasury_3d_demo.tscn、scripts/prototypes/camp_treasury_3d_demo.gd。
- Blender 5.2.1本地脚本建模：art/candidates/camp-treasury-3d-v1/build.py及treasury.blend；Godot运行模型resources/prototypes/camp_treasury_3d/treasury.glb。无生成API/Meowa。
- 第三版当前内容：宽矮石堡、分块压顶/角柱、铜环、带厚度的分片弧面筒瓦、门板包铜/铆钉/门环、灯笼骨架、褶皱挂旗、三足香炉、侧后铁窗、屋顶封印/双排水栅、包铜木箱。修正屋顶木箱遮挡排水栅；瓦片重叠处错层避免共面闪烁。
- `.blend` 八个部件集合保留1173个可编辑网格；GLB按材质合并22网格（两盏灯罩独立材质）、114376三角面、7447520字节，内嵌23张贴图（含9张法线），不依赖外部贴图。详见候选目录 build-report.json / README.md。
- Godot保持固定30°正交俯角和仅Y轴转向；模型视口960×960，校准中性环境光与暖主光，保留金属/陶瓦各自粗糙度。左近景/右营地融合；不保存试验角度，不承诺各朝向门口导航。
- 第三版验证通过：Blender 5.2.1 导出、Godot 4.7.1 headless导入、实际图形0/90/180/270°截图与竖直轴断言；GLB嵌入贴图/有限边界/材质法线检查通过。无脚本或导入错误；仅项目原有嵌套 landscape_preview_project 忽略警告。
- 当前截图：本目录 treasury-3d-{0,90,180,270}.png；模型近景：art/candidates/camp-treasury-3d-v1/preview-{0,90,180,270}.png。原同名0/90/180证据已由V3替代，不能当成V2截图。
- 第一版已被用户否决；第二版已归档于候选 revisions/v2，仅用于回退。第三版仍为待视觉批准候选，与二维原画仍有风格和精细度差距；下一步按用户对比例、门面、材质及营地融合的反馈优化。

## 守卫已取消；保留建筑与灯火
- 用户看过V4全身后仍明确否决并要求删人，V1～V4均废弃，不属于待确认候选，不得继续优化或自动恢复。
- camp_treasury_3d_demo.gd移除双守卫加载、守卫待机开关和人物捕获流程；保留建筑转向、营地对照、独立灯笼明暗和常亮切换。人物源文件/历史图仅存档，不被该预览加载。
- Blender由assemble_treasury_preview.py从treasury.blend重建为treasury-lanterns.blend；旧已分享treasury-guards.blend同步清除人物，旧assemble_guard_preview.py仅转发到无人物装配入口。两个文件都只含建筑和两盏动态灯，无Armature。
- 当前复核入口run_camp_treasury_3d.command；最新截图treasury-3d-{0,90,180,270}.png。所有guard相关旧图/视频都为已否决历史，不能当当前证据。
- 验证完成：Godot导入通过；实际预览确认无Guards/Skeleton3D/AnimationPlayer及守卫待机按钮，建筑存在、两盏灯明暗/常亮切换通过；Blender两份组合文件无骨架，保留两盏动态灯。四方向实渲染完成，正面图人工检查无人物。

## 还魂殿3D V3（当前交付，待视觉确认）
- 当前源：`art/candidates/camp-revival-3d-v3/revival-refined.blend`；原 V2 `camp-revival-3d-v1/revival.blend` 保留。MCP 对 V2 执行 V3 `refine.py` → `finish.py` → `export.py`，另存源与独立 `resources/prototypes/camp_revival_3d/revival.glb`。
- 六道连续铜包屋脊+细金线+少量接箍；5整块石阶、低对比石纹。原 box helper 面序朝内导致三角斜纹，已对365个同类8顶点6面静态部件重算法线；原版 build.py 不作为最新构建入口。
- 源2169对象，GLB24静态材质批次+8幡+3火，145924三角面、8615376字节。此轮是画质优化而非减面，未宣称性能提升。
- 幡/火保留4形态键、固定根部和8秒循环；导出必须合并11条动画轨为 `SoulBannerAndFire`，不能退回逐对象独立播放。
- Blender火焰为渐变+透明材质。Godot `shaders/prototypes/revival_soul_fire.gdshader` 提供白蓝核心、深蓝外焰、侧缘与尖端渐隐；glTF V轴翻转已修正。`camp_revival_banners.gd` 同一动画时钟驱动7上升火星/蓝色局部光/材质，暂停及循环一致。
- 入口 `run_camp_revival_3d.command`，独立 `scenes/prototypes/camp_revival_3d_demo.tscn`；右侧营地对照仅临时隐藏旧revival图，无正式地图/JSON/存档变更。
- 验证：MCP确认石阶顶面法线朝外、8幡顶边固定；GLB11形态轨/无骨架；Godot headless导入与变形/灯光/火星移动、共同暂停、首尾复位、转向通过；4角度图形及64全景+64近景捕获通过。
- 最新媒体：V3 `revival-refined.gif`、`soul-fire-refined.gif`，各64帧8秒；`preview-{0,90,180,270}.png`。V1目录的媒体为历史V2证据。视觉未Approved，不晋升正式素材。

## 最新：两座3D建筑接入摆放编辑器
- 用户要求将做好的还魂殿与“百宝箱”（现有百宝库）放入编辑器。范围仅营地摆放工具与同一候选营地预览，不晋升正式营地素材。
- JSON两座增加model_3d/yaw_degrees；已有坐标/占地/导航不变，显示宽换算为对应3D视口尺寸。忽略旧二维镜像/旋转/裁切，保留旧贴图作为来源记录。
- scripts/prototypes/camp_building_3d_sprite.gd共享SubViewport、原预览材质灯光、最新GLB及动态；canvas缓存两模型，隐藏停止渲染，panel同一角度控件写yaw_degrees（0.1°），禁用3D水平镜像。运行camp_tile_rebuild.gd读取同一数据。
- 动态脚本camp_revival_banners.gd、camp_treasury_lanterns.gd增加@tool，保留魂幡/魂火与灯笼，不恢复守卫。
- Godot导入、live_buildings图形验证、原2D面板交互、布局数据保存/冲突保护与营地通路回归通过；测试仅写临时JSON。截图editor-live-buildings.png。操作见EDITOR_PLACEMENT.md。
- 入口run_camp_layout_editor.command或Godot顶部“营地摆放”；选建筑→拖动/显示宽/朝向→保存JSON。旋转不自动调整导航门口，仍需用户检查实际摆放。

## 招贤馆3D V1（静态建筑基底，已保留）
- 用户要求继续招贤馆并保持现有贴图风格。参考 `resources/prototypes/camp_west_buildings_v4/recruit.png` 与 `camp_west_inward_v1/recruit-rear.png`，复用百宝库材质库；双层木楼、前后交叉山墙、侧亭/连廊、外廊、桌凳、旗架、盆景/陶罐；深蓝灰瓦、旧木、灰石、暗灰屋脊、米色红边旗布、暖琥珀灯。
- 当前 Blender MCP 打开 `art/candidates/camp-recruit-3d-v1/recruit.blend`（已转普通可打开工作文件，不再是仅场景库）；保留还魂殿/百宝库。此目录 build/detail/polish/complete_sides/export.py 为制作步骤，顺序与注意见README，不重复叠加polish/complete_sides。
- `resources/prototypes/camp_recruit_3d/recruit.glb`：3087源对象，29导出网格（9独立灯芯），161880三角面、9334320字节；未做LOD，不宣称最终性能验收。
- 新独立 `scenes/prototypes/camp_recruit_3d_demo.tscn`、`scripts/prototypes/camp_recruit_3d_demo.gd`、`camp_recruit_lanterns.gd`；`run_camp_recruit_3d.command` 可旋转0.1°、暂停九灯明暗。侧窗与背窗向外偏移，左右两侧都有窗；盒状面序朝外，修正沿用工具的法线错误。
- 验证：Godot headless导入/模型加载，九灯正值/错相变化/暂停/8秒循环，四向竖直转向、无人物；四向实机截图与64帧灯光捕获。最新图 `art/candidates/camp-recruit-3d-v1/preview-{0,90,180,270}.png`，完整界面 `Docs/Artifacts/camp-tilemap-exploration/recruit-3d-*.png`。
- 独立候选尚未视觉批准；未改现有营地摆放JSON、正式场景或存档。

## 招贤馆V2招募动效（当前交付，待视觉确认）
- 用户明确要求通过MCP增加动效和人物进出。本次仅新建招贤馆访客；旧百宝库守卫仍不恢复。当前源 `art/candidates/camp-recruit-3d-v2/recruit-living.blend`，原V1保留。
- `animate.py`在V1上切出真实入口通道、将内堂暗面后移、制作两面带纹样一起变形的招募幡；新建3个成人比例袍服人物与关节层级：青衣修士进出、蓝衣侧亭落座候招、赭衣持册接待。不是旧人物素材；本轮人物为营地远景模型。
- 24秒循环：0～7秒沿四级台阶进馆，7～12秒内堂停留转身，12～19秒离馆，19～24秒门外短暂停留转向。腿部双段关节求解，根高度沿台阶平滑过渡；头/手臂/袍摆有小幅动作。接待者位置(-.22,-1.58,.535)，避免被旗布挡住。
- `export.py`仅合并静态建筑，保留人物父子关节与2面幡形态键；GLB唯一动画 `RecruitmentLife`，25轨、24秒、3人物根、2形态轨，无重复目标轨；28静态导出网格，118动态对象，10153108字节。仍为独立候选，不是真实NPC招募业务。
- `camp_recruit_lanterns.gd`统一时钟控制人物、幡与9灯；暂停/继续和seek24秒首尾一致。`camp_recruit_3d_demo.gd`已显示“招募场景动效”，原启动入口 `run_camp_recruit_3d.command` 保持。
- 验证：MCP确认幡顶固定、人物阶高与内外位置；GLB单动画/3根/2形态轨/唯一目标；Godot headless导入及 `tools/validate_camp_recruit_3d.gd`通过入馆/内堂/出馆、台阶升高、幡变化、共同暂停/继续、24秒复位与4向旋转。
- 最新媒体进入V2目录：192全景+192近景帧，24秒8FPS；`recruitment-life.gif/mp4`与`recruitment-detail.gif`；原V1灯笼动图仅历史。待用户视觉确认。

## 招贤馆V2接入营地地图（2026-09-20）
- 按用户“放到地图上”接入候选营地运行预览与摆放编辑器，共享 `camp_building_3d_sprite.gd`。JSON招贤馆新增model_3d、yaw_degrees=-90、model_anchor=[1.06,0,2.78]；保留当前origin=[7,12]、door=[6,12]、approach=[5,12]、display_width=235及其他用户布局。
- 模型石阶入口锚点随3D朝向旋转并对齐地图门口；24秒人物进出、候招/接待动作、两幡与九灯已随地图播放。编辑器禁用旧二维正背面选择，使用0.1°立轴朝向。
- 验证：headless导入无错误；三建筑live_buildings图形测试通过模型、旋转、入口锚点、缓存、撤销、临时JSON往返、像素拾取与运行一致性。实际地图截图 `recruit-on-map.png`。
- 原全图连通回归在line148失败；对比接入前的二维招贤馆与接入后，均有相同5个孤立格(8,3)/(5,4)/(6,4)/(7,4)/(8,4)，7座建筑入口均可达。是现有布局问题，本次未改导航或用户摆放。诊断日志 /tmp/kunwu-recruit-map-check.log。
- 仍只属于候选营地，非正式Map01/正式营地；不改玩家存档。入口 `run_camp_layout_editor.command`，选择招贤馆可调整。

## 三座建筑暗黑色调修正（2026-09-20，用户已认可）
- 用户反馈墙体泛白、整体偏亮。新增 `scripts/prototypes/camp_building_palette.gd`，按石材、切边、木构、瓦、铜、布分别调色；降低环境补光及主光，冷灰建筑保留暖灯/魂火局部亮点。第一轮过暗后已回调木构和石材，保留结构层次。
- `camp_building_3d_sprite.gd`与treasury/revival/recruit三份独立3D预览共用调色。仅Godot表现层材质副本与灯光变更，Blender源、GLB、模型结构、动画与摆放JSON不变；后续源文件重导出仍通过此表现层统一。
- Godot导入无错误；实际地图渲染检查通过，招贤馆完整动作回归通过；导航保持既有状态。截图 `dark-buildings-on-map.png`。重新打开 `run_camp_layout_editor.command` 查看；旧窗口不会自动刷新脚本。

## 炼器坊 / 灵源院 / 交易行动效与编辑器接入（已实现，待视觉复核）
- 用户认可暗色调并授权制作后直接进入编辑器。Blender MCP以原东侧三张贴图为参考，独立源在 `art/candidates/camp-crafting-trio-v1/{forge,garden,market}.blend`；build.py、roof_helpers.py、actor_helpers.py、polish.py可复做。源已转普通可打开文件并打包纹理；当前Blender打开garden.blend。
- 炼器坊：敞口炉房、空心烟囱、煤炉、铁砧、锻工。锤头在t=1秒落到热铁，2秒一次；烟雾升腾消散、火星及局部炉光。前侧墙开放确保等轴视角看见炉火。
- 灵源院：扩大药房院落、晒药棚、双药圃、渠/引水槽/水车、药童挥锄。水车16秒一转，药童4秒耕作周期；落水和渠面流动。display_width由245改320，保留用户origin/door/approach与导航占地。只扩大视觉，未改玩法生产规则。
- 交易行：柜台、侧棚、卷轴/账簿/药罐/秤/货箱，两名交易人物、两面风幡、灯笼。
- 三GLB分别进入resources/prototypes/camp_{forge,garden,market}_3d；单个16秒合并动画，通道2/4/8，三角54339/78339/68630；静态按材质合批。导出必须use_active_scene=True，避免混入其他场景。Godot共享camp_crafting_motion.gd单时钟驱动动画和烟火/水流，复用已认可camp_building_palette.gd。
- JSON增加各自model_3d、yaw=0与入口锚点；camp_building_3d_sprite.gd支持三座，地图和摆放编辑器共用；原用户布局保留。六座3D均支持立轴0.1°旋转、拖放、撤销、JSON保存、像素拾取。
- 验证：最终headless导入无错误；tools/validate_camp_crafting.gd通过三模型16秒动画、暂停/复位、独立烟/火星/水流、药童/水车/交易人物及旗幡、旋转入口锚点。每座64帧/16秒4FPS实渲染，动图{forge,garden,market}-living.gif在候选目录；近景PNG及crafting-trio-on-map.png在本状态包目录。
- 六模型编辑器交互断言通过，但自动测试释放两个临时场景时GLES3仍报一组material null（非脚本错误）；独立动画捕获、实际地图运行无此错误。未把该清理问题标为已修复。日志 /tmp/kunwu-craft-editor-final.log。
- 三座切回二维与当前3D对比，导航完全相同：7建筑入口均可达；既有5孤立格仍在，未改位置去消除历史警告。正式Map01、正式营地场景与玩家存档不变。

## 屋顶差异化与百宝库中式改造（2026-09-20，已接入，待视觉复核）
- 用户要求百宝库统一风格、各屋顶形状/颜色/样式差异化。六座最新源统一在 `art/candidates/camp-roof-diversity-v1/{treasury,revival,recruit,forge,garden,market}.blend`；此前源保留，*-before.glb为改造前导出备份。remodel.py从前版源派生，不在新版重复叠加。六源已打包纹理并转普通工作文件。
- 百宝库：删除平屋面/女儿墙/屋面阵纹，增低矮宽檐四坡顶、木柱/横梁/斜撑和门额铜印；保留石库主体、重门、灯笼及原结构比例。屋顶灰橄榄色，降低石堡感。
- 还魂殿：六折屋顶上部高度伸展1.38倍、紫黑瓦、莲花尖顶与细环；魂幡/火不动。招贤馆：主楼屋顶上部伸展1.18倍、深青瓦；层叠主楼/侧亭保留。
- 炼器坊：炭黑错层低坡屋面、沿脊百叶烟楼/金属压顶，保留空心烟囱和烟源。灵源院：灰绿圆弧卷棚顶、弧形木山墙与编织晒药棚。交易行：暖褐四坡主顶、赭红弧垂布侧棚，保留两动态幡。
- 屋瓦复用原烘焙纹理并复制图像调色，法线保留；统一Godot暗色palette/照明不变。所有6个现有GLB已更新，编辑器和独立预览自动使用；摆放JSON、占地、朝向与入口未改。议事殿原多重檐贴图本已独特，保持主殿层级。
- 验证：Godot headless导入无错误；六建筑统一视角实渲染通过。招贤馆24秒进出/暂停/复位、还魂殿8幡3魂火/8秒循环、三工坊16秒动作/烟火/水流/暂停/入口锚点全部通过；百宝库两灯材质加载正常且无守卫。各动画合并/隔离场景导出机制保留。
- 最新图片 `roof-identities.png`（六座对照）、`roof-identities-on-map.png`（地图摆放）在本状态包目录。入口 `run_camp_layout_editor.command`，选百宝库可看背面改造，朝向0°看正面。当前3D源复核以新roof-diversity目录为准，旧动图为屋顶改造前历史。
- 地图7入口均可达，原5孤立格不变；正式Map01/正式营地/存档未改。本轮未处理上一轮测试退出的材质清理警告。

## 当前：整景拖动与环境融合（2026-09-20）
- 用户已定建筑摆放，要求修复拖动主区域与背景分离、建筑孤立、地块/岩壁生硬。此轮不改JSON坐标、朝向、占地、导航或模型源。
- camp_exterior_preview.gd：所有山体层（rear/left/right/DistantRidge）共享world的完整平移/缩放，天空仍满屏；camp_terrain_sample.gd底部山雾跟随地图变换，避免固定屏幕雾线切开地形。
- camp_building_3d_sprite.gd：6座3D底座增加水平GroundContact软阴影/不规则土苔面，与模型yaw和model_anchor同一变换；保持既有模型、动画和用户摆放。属于轻量接地处理，未制作完整庭院。
- camp_mountain_cliff.gd：沿JSON边界添加不规则石土斜边与少量坡脚碎石；camp_natural_ground.gdshader加宽边缘土苔渐变。保留原高度/阶梯/通路，未把所有岩壁改成缓坡。
- tools/validate_camp_composition.gd验证两组平移/缩放极值下所有山体相对地图坐标恒定、山雾变换、六座接地面、JSON逐字未改变；通过。composition-default.png / composition-pan-{0.7,1.4}.png实渲染已检查。
- tools/capture_camp_editor_ground.gd已刷新addons/camp_layout_editor/ground_preview.png（无建筑烘入）；编辑器需重开加载新预览。视觉仍需用户复核。

## 当前：还魂殿/交易行前景岩石遮挡
- 用户红圈指定岩石应遮住建筑。JSON仅west_blend、central_slope新增occludes_buildings=true，未改建筑位置/朝向或岩石几何。
- camp_tile_rebuild.gd对应岩石z_index=1盖过建筑与角色，文字仍在上层。摆放编辑器独立foreground_preview.png置于建筑上层；capture_camp_editor_ground.gd分别输出不含前景的地形与透明前景，避免重复烘入。
- Godot导入通过；validate_camp_foreground.gd验证运行层级、编辑器层级与刷新保留，foreground-rocks.png实渲染检查通过。临时双场景退出仍出现此前已知GLES3 material null日志，未作为本次修复范围。
- 重开营地预览或摆放工具查看最新遮挡，建筑拖到岩石后方时由岩石真实透明轮廓遮盖。

## 下一步与禁止事项
- 六座3D模型已接入摆放工具与候选营地且用户已定摆放；下一步复核整景拖动与建筑/岩壁融合效果。旧百宝库守卫仍取消；招贤馆访客、锻工、药童与交易人物为已授权新工作。不得自动替换正式运行素材。
- 右侧三座已按用户要求补齐；不重做地形、不把实验候选自动晋升正式素材。当前未完成整套最终营地。
- 任何新生成先确认需求；历史Meowa单次授权均已用尽，不能续用。扣分必须遵守 Docs/Tech/Meowa_API调用规范.md 和 tools/run_meowa_guarded.py。
- 必读边界：AGENTS.md、Docs/ArtAssets/18_地图生成式美术生产与模型分工规范.md；需要Dual Grid/插件时再读相应技能。
- 只维护本状态包。历史细节见本目录专题文档/候选来源清单，非当前方案不得恢复。仅按任务需要读精确片段，工具输出控制在约200行/12000字符内。
