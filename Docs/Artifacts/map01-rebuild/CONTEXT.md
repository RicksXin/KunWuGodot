# Map01 重做任务状态

更新：2026-09-24。

## 最新用户决定
- 参考 `Docs/Tech/营地制作复盘与野外地图参考.md` 制作模块地形和独立地标。
- 用户已调整并验证路线：只有右侧主路可进入终点；左路是暗道小型副本与资源支路，暗道提供装备。三灯、残碑等主线物件沿主路放置。
- 以用户保存的1097个地形单元为准，本轮未改 terrainAuthoring.cells；原先“两路北端汇合”的设计已废弃，不能恢复。

## 当前实现与范围
- 唯一作者数据：`data/maps/map_01.json:terrainAuthoring`；44×76作者格，96×48菱形，层高32，出生(16,67)。原218格入口平移(+6,+40)后扩展；试玩角色尺度/速度不变。
- `addons/map01_terrain_editor/`：绘制/高度/阶梯/撤销保存、平面编辑、全图适应、试玩WASD/点击寻路、有限缩放。已修复编辑器Container中零高度问题。
- model.gd共享surface/elevation/can_stand/move_actor，岩石/缺地/不相容高差阻挡，阶梯沿Y轴连接相邻高度；0.12格脚底半径、0.04格分步检测。
- 当前正式探索仍是2488×5692底图、连续世界897×1938.541、36碰撞和17调节区域、31对象。作者地形 `runtimeEnabled=false`，尚未迁移正式探索、战斗入口或存档坐标。技能里的28×64旧格子契约已过时，不可回退。
- 已复用营地铺石/岩壁/土面纹理，未新生图、未扣费；本地图材质视觉尚待确认。试走角色为比例占位。

## 本轮地标与奖励
- placements只保存稳定objectId、作者cell和主/支路标识，文案从现有objects读取；首批9个位置（后续已补齐31个）：第一灯(16,45)、残碑(24,40)、第二灯(26,32)、第三灯(19,20)、暗道(12,27)、灵木(12,34)、玄铁(7,29)、Boss(19,9)、出口(19,3)。
- 金色=主路，青色=支路。试玩靠近按E仅查看描述；地标为不占碰撞的占位标记，尚非有地基碰撞的实体美术，试玩不发奖励。
- `data/config/combat_map01_formal.json:m1_dungeon_rockfall.equipmentRewards` 增加首通1件fa_qi（法器），沿用现有Game装备结算与战利品流程。数量/品质是本轮基础实现选择，用户只明确“能获取装备”，未要求重复掉装。
- `tools/validate_map01_tunnel_reward.gd`：首通生成、品质、重复结算幂等、领取进入临时装备包通过。

## 验证与入口
- 二次空白显示修复：初次fit可能在非零但不足80px的临时布局中计算负缩放，并锁定initial_fit_done。canvas.gd改为有效尺寸/可见/非空数据才fit；自动全图模式在resize和显示后重新适应，手动拖拽/缩放后保留手动视角。新增900×40→1200×650→隐藏/缩到950×450→显示的回归，检查缩放及所有地形顶点在视口内。本次未改地形或地标数据。
- `tools/validate_map01_terrain_editor.gd`：原地形编辑/保存/碰撞/台阶测试，全部31个稳定引用、可站立/可达/接近识别；验证一律带 `-- --no-profile-write --ignore-config-cache`。
- 本轮正式Map01回归、正式战斗和项目数据验证通过；headless导入无脚本错误。
- `terrain-editor.png`为本轮实际Godot绘制占位全貌，已查看。原terrain-walk.png可能是上一轮图，不作为本轮占位验收凭据。
- 用户复核：重新加载工程 → 顶部“Map01 地形”；“试玩地形”靠近标记按E查看。

## 边界与下一步
- 保留用户营地和其它未提交改动；不恢复归档Dual Grid，不从图片推碰撞，不生成第二份运行地图，不写玩家档案。
- 下一步按主支路占位制作独立地标（先暗道入口或阵灯），同步地基、遮挡、门口/互动锚点；再规划正式玩法迁移。

- 编辑缩放改进：第二行增加缩小/放大/100%按钮、5–400%滑条和倍率文本；canvas统一set_zoom保持鼠标锚点，支持MagnifyGesture捏合、PanGesture双指平移、Command/Ctrl+双指缩放、空格+左键平移。试玩仍限制100–160%。已验证捏合倍率/锚点、滑条300%、手动缩放不被自动fit覆盖、平移不改地形。

- 内容占位已补齐31个现有正式对象：8资源、10普通敌群、2精英、1Boss，以及三灯/残碑/粮册/尸首/暗道/宝匣/阶梯/出口。保留原9点与用户1097格，不改对象奖励和正式坐标。
- 新增 `terrainAuthoring.restAreas`：岔路(16,41)，半径2；Boss前(19,13)，半径1.5（作者格）。这是地形布局预留，不是运行无敌/回血区；试玩没有自动战斗触发。
- 显示：资源绿、敌人红、剧情金/青、休整蓝；筛选全部/资源/敌人/剧情入口/休整，另有全部名称开关。小倍率默认隐藏资源和敌人文字保留图标，放大或筛选可查看。
- 本轮验证：31个ID唯一且覆盖全部objects，均可站立/寻路到达；2休整区与所有敌人距离大于区域半径+1.5格；编辑器全回归、正式地图回归、Godot导入通过；terrain-editor.png已重新渲染检查。正式游戏仍未切换新地形。

- 阵灯美术第一步：三处阵灯placements.visual引用营地图集formation_lamp，显示宽54px、源锚点读取atlas.json，按格子深度排序；不复制纹理，不修改营地资源。状态candidate_reuse，碰撞尚未启用，待视觉确认后配置实体地基与修复状态。已移除阵灯上方重叠的几何占位符并抬高名称。
- 暗道素材缺口：无现成洞口；已完成 `art/candidates/map01-tunnel/PROMPT.md`（输入图、上传顺序、单张1024RGBA提示词、显示宽180px、门槛/碰撞/遮挡契约、原PNG交付要求）。按地图美术规范用户执行ChatGPT网页生成；未代理操作网页或提交付费任务。等待用户返回 tunnel_source.png。
- 阵灯预览：`lamp-candidate.png`，Godot实际渲染；编辑器验证PASS、headless导入无脚本错误。没有新增地图场景或正式素材晋升，用户1097地形保持。

- 用户最新阵灯要求：残破/激活两种样式，都要序列动画，合成同一张图集；SpriteFrames两段broken/active，三灯共用资源但独立按LAMP_REPAIRED状态选择。已制定 `art/candidates/map01-formation-lamp/ANIMATION_CONTRACT.md`：暂定每段8帧、8FPS，同帧尺寸/锚点，0–7与8–15分段，绝不整图连播。现有静态青色阵灯仅占位，不算完成此动画需求。
- 激活按现有剧情暖白灯芯，用户最新要求修复完整石材与灯罩；残破要真实结构缺损，不能仅调暗。本句制作计划已完成，见下方候选交付；未调用Meowa。


## 阵灯双状态动画制作记录
- 内置imagegen生成同构残破/暖白激活双状态母图，归档 `art/candidates/map01-formation-lamp/source_states.png`；实际RGBA，局部透明正常。
- `tools/build_map01_lamp_sequence.py`：统一锚点(128,350)，每帧256×384，两行各8帧，8FPS；本地局部位移和亮度波实现灯芯/符纹循环，石材与Alpha固定。输出单张2048×768图集。
- Godot可加载候选：`resources/prototypes/map01_lamp_sequence/formation_lamp_states.png`及`formation_lamp_frames.tres`。source候选目录有.gdignore，因此运行预览资源不能直接引用art目录。没有晋升assets正式素材。
- `scripts/prototypes/map01_formation_lamp.gd`：共享SpriteFrames，LAMP_REPAIRED→active，其他→broken；configure先选状态后显示，同状态不重播。正式Game状态的调用接线仍待新地图正式迁移，不宣称已接入正式游戏。
- 地形编辑器三灯改为此候选，各自独立计时；试玩靠近E只切换该灯本地候选状态，不写Game或存档。用户1097格和placements不变。
- `tools/validate_map01_lamp_sequence.gd` PASS；地形编辑器回归和实际图形截图PASS，lamp-candidate.png已更新并查看。双状态动画预览 `art/candidates/map01-formation-lamp/states_preview.gif`（左残破/右激活）。
- 下一步：用户视觉复核造型、循环和54px地图尺度；批准后再晋升素材、接入正式修灯状态及地基碰撞。

- 用户视觉纠正已落实：激活态不应破损。内置imagegen修复右侧屋檐/灯罩/立柱/底座，母图 `source_repaired_states.png`；旧“保留破损”要求废弃。构建只替换active8帧，broken8帧字节一致，统一锚点和动画契约不变。仍为待视觉确认候选。


## 最新阶段：阵灯美术已获用户确认
- 用户“可以的”确认修复完整版本；残破/激活动画标记Approved。
- 唯一可导入图集和SpriteFrames晋升至 `assets/maps/map_01/formation_lamp/`，播放脚本与构建输出路径同步更新；原prototype图集/资源已移走。
- 保留原图和提示词用于追溯。正式地图修灯业务与地基碰撞仍待接入，作者地形仍未晋升运行地图。
- 下一步继续实体地标及正式玩法迁移，不重新请求本版阵灯视觉批准。


## 最新调整：修复过渡放慢
- 用户反馈破旧→修好转换太快。新增repair段16帧/8FPS，2秒单次暖光由下到上修复，再进入active循环；两种已确认造型保持。
- 同一图集扩展2048×1536，broken/active仍在前两行，repair在后两行；构建器使用已有端点做局部预乘Alpha融合和光带，无新生图/扣费。
- AnimatedSprite状态机与编辑器单灯预览均采用2秒过渡。相同状态刷新不重置，初始化已修复状态直接active；反向预览切回broken会取消过渡。
- Godot动画验证通过：2秒时长、不循环、结束进入active、刷新不重播、独立状态、载入跳过修复。导入无错误；修复联系表已查看。GIF `art/candidates/map01-formation-lamp/repair_preview.gif` 展示残破1秒/修复2秒/激活2秒，等待用户复核节奏。


## 最新阶段：三灯真实修复接入正式探索
- 用户批准继续接通真实修灯。`scripts/scenes/map_scene.gd` 三个正式对象位置显示Approved阵灯，初始化先读持久状态；实时刷新调用apply_state，成功repair→active，完成后灯体不消失，迷雾仍控制可见。
- 正式地图靠近E或互动按钮沿用 `expedition_ui.gd` 的现有选项/条件提示；第一灯法力18校正或带开山镐拆壳（原有3玄铁奖励），二/三灯原有repair。Game仍负责校验、状态/奖励写入和存档，主线三灯条件沿用原配置；HUD显示阵灯n/3。
- `Game.resolve_map_object_action` 对已修复三灯拒绝重复提交，防止重复剧情计数/玄铁奖励。对象完成状态不再隐藏灯体；按玩家Y设置灯体前后层级。
- `tools/validate_map01_lamp_interaction.gd`：正式场景E开选项、失败无修改、成功动画/完成可见、三灯独立、重复结算幂等、Boss三灯门禁、序列化后重建场景恢复active均PASS。使用禁写档模式，不碰真实玩家存档。
- 正式地图/战斗/数据/动画验证及短时启动通过；图形验证截图 `lamp-formal-interaction.png`。
- 明确边界：当前接入的是既有正式高清地图；作者1097格仍runtimeEnabled=false，编辑器E仍为本地预览，不暗中迁移坐标或地形。未新增灯基碰撞。
- 下一步用户复核正式探索的互动与显示，再继续暗道入口美术和副本。
