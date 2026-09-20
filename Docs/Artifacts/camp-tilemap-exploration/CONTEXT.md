# 营地 TileMap 探索 · 唯一续接状态包

更新：2026-09-20；Blender 建模已续接到“优化百宝箱 Blender 建模”任务，严格控制上下文。

## 当前目标与边界
- 最新续接范围：用户认为守卫V2太呆，提供写实修仙武卫参考，要求按图调整。参考已归档候选reference/user-martial-guard.png；当前制作V3深青黑衣袍/分层鳞甲/兽纹肩甲/护腕高靴/束发散发/硬朗眉眼与有重心站姿。保留双人8秒错相待机和灯笼明暗；V2已备份revisions/guard-v2。当前只做独立3D预览候选，不改正式营地/布局JSON/存档，不调用生成API。
- 当前交付：用户明确要建筑绕竖直轴转身，旧2D旋转不是所需功能。已用本机Blender制作百宝库独立3D样件，Godot正交相机/SubViewport实时合入营地；Y轴0.1°控制，未替换现有二维布局，待视觉评审。
- 最新完成：用户要求精细自定义旋转；新增贴图旋转-360～360°、0.1°输入、±1°/归零/撤销，rotation_degrees保存到建筑JSON；编辑器和运行时变换一致。仅2D贴图旋转，不改变导航、不生成3D新视角，当前布局未改动。
- 当前修复：用户要求放大、建筑朝向控制、取消地形摆放限制。已支持按钮/滚轮/触控板缩放，左右翻转与招贤馆正背切换；地形/导航仅提示，允许保存。新增run_camp_layout_editor.command独立入口。
- 最新任务：用户要求补齐右侧交易行/炼器坊/灵源院，接入当前实验和摆放插件，由用户统一调整。已使用内置imagegen三张独立候选并接入，七座全部可见；大小可统一调整，无Meowa费用，待用户视觉反馈。
- 当前任务：用户已授权Godot编辑器可视化建筑摆放。新增独立“营地摆放”主屏插件，拖动吸附/数值位置与大小/占地门口预览/撤销/校验保存JSON；不改当前建筑摆放数据。已完成，Godot导入/面板渲染/鼠标拖动/保存与导航回归已通过。
- 最新确认：三座正门朝向中央空地形成围院。招贤馆须侧后视角，不能仅水平镜像；已接入同建筑背向候选并调整门口/接近格；图形回归通过，等待用户视觉反馈。
- 上一轮要求：缩小左三座，按截图三个黄圈重排并处理面向；删除红框西南阶梯[4,11]，同步岩壁和导航。已实现并完成图形验证，待用户视觉反馈。
- 仅独立营地实验 index15；最终必须原生 TileMap，可扩展；整图只作历史构图参考。横版斜俯视正交2:1，格128×64，层高0/48/96。
- 不改正式营地业务、Map01、存档、上级 Cocos 或其他任务改动；七座全部显示，未修改正式营地资源；不调用 Meowa。

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

## 修仙守卫V2与灯笼明暗（当前交付）
- 本地Blender构建：候选目录 build_guard.py → guard.blend；运行模型 resources/prototypes/camp_treasury_3d/guard.glb。单守卫52522三角面、18骨骼、单蒙皮网格、14材质，GLB2155784字节。V1方块甲片方案已废弃；V2为柔和人体、束发发冠/马尾、面部五官、交领、玉佩、连续曲面袖、褶皱长袍、圆头布靴。近景发现的肩部开口已收进衣身并封闭袖端。无生成API/Meowa。
- GuardIdle为8秒循环，胸肩呼吸/轻微重心变化、头部左右巡视、衣摆/发带/枪穗轻摆；Root和双脚固定。实例同速、错开3.25秒，不做同步齐动。
- 独立组件 scripts/prototypes/camp_treasury_guards.gd；台阶外侧Godot坐标(-1.62,0,3.14)/(1.62,0,3.14)，微转±5°，随建筑父节点Y轴转向。现有camp_treasury_3d_demo.gd已接入，顶部“守卫待机”可暂停/继续。
- assemble_guard_preview.py → treasury-guards.blend，源建筑和守卫分别保留；组合文件NLA错开97.5帧，30FPS、0～240帧；增加两盏灯发光材质和点光源关键帧，Blender中按空格播放。组合文件由两份源重新装配，不作为独立建模事实源。
- 验证：Blender导出与组合NLA头部运动/首尾一致通过；Godot4.7.1导入、tools/validate_camp_treasury_guards.gd检查双骨架/8秒循环/脚部不滑/头部运动与错相/暂停继续/随建筑转向均通过。GLB检查蒙皮与动画存在；实渲染帧差异非零。验证均带存档保护参数。
- 当前动态证据：候选 guards-v2-lanterns.gif（64帧、8.01秒）和 guards-v2-lanterns.mp4（64帧、8秒、960×960）；guard-v2-closeup.png为单独人物近景；实际营地截图本目录 treasury-guards-ingame.png已更新。旧guards-idle.*为废弃V1守卫；旧preview-0/90/180/270和treasury-3d-0/90/180/270仍为无守卫建筑V3证据。
- 独立灯光组件 scripts/prototypes/camp_treasury_lanterns.gd：LanternGlass_Left/Right独立灯罩材质与OmniLight3D，4秒基频叠加小幅变化，左右错相；窗户常亮。顶部“灯笼明暗”可切回恒定暖光。建筑几何未改，只拆分两个灯罩材质，备份revisions/treasury-v3-before-lights。
- V2最终验证：Godot4.7.1导入、守卫回归、灯罩/点光源独立性、正值明暗范围、8秒首尾连续、窗户不被改动、常亮开关均通过；Blender组合NLA验证通过。实渲染灯罩区域像素有变化，GIF/MP4均64帧，GLB骨骼与两份灯罩材质检查通过。
- 当前待用户确认更接近真人比例的修仙风格化模型、站位、动作与暖光幅度；不能宣称照片级真人。未添加靠近反应/行礼/让路、巡逻、碰撞或战斗，不自动扩展。

## 下一步与禁止事项
- 当前任务先复核修仙守卫V2与灯火动态预览；按用户反馈调整。不要自动扩展其他建筑或替换正式运行素材。营地三座摆放调整属于此前任务背景。
- 右侧三座已按用户要求补齐；不重做地形、不把实验候选自动晋升正式素材。当前未完成整套最终营地。
- 任何新生成先确认需求；历史Meowa单次授权均已用尽，不能续用。扣分必须遵守 Docs/Tech/Meowa_API调用规范.md 和 tools/run_meowa_guarded.py。
- 必读边界：AGENTS.md、Docs/ArtAssets/18_地图生成式美术生产与模型分工规范.md；需要Dual Grid/插件时再读相应技能。
- 只维护本状态包。历史细节见本目录专题文档/候选来源清单，非当前方案不得恢复。仅按任务需要读精确片段，工具输出控制在约200行/12000字符内。
