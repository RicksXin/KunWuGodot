# Figma 战斗页还原状态包

- 当前目标：按 Figma `331:1371` 还原 375×817 战斗页，并接入用户提供的四名修士动效；当前阶段已完成我方信息层 `334:1384`、敌方单位 `333:1382`、技能条 `358:1393` 和 13 张统一运行时图集的接入，等待用户视觉确认。
- 已确认事实：修士与敌人卡片均为 `86×205`，信息层均位于卡片内 `(0,149)`、大小 `86×56`；单敌位于 `(144.5,180)`，敌方立绘在卡片内 `(-12,34)`、显示 `110×165`。Figma `358:1393` 的技能条位于 `(117.5,491)`、大小 `140×46`，无外层弹窗；三项各 `40×46`、间隔 `10px`，名称、`24×24` 图标和效果值纵向排列。
- 动画契约：用户已确认四名修士的 idle、attack、恢复/防御等原地动效统一使用 `172×298` 单帧透明画布；16 帧 `4×4` 图集为 `688×1192`，运行时仍按卡牌内 `86×205` 视觉框缩放与裁切。旧的 `172×258` 与 `172×410` 结论废弃。
- 已完成阶段：背景、状态栏、敌我信息层、四名修士和底部安全区已重排，暂停/继续已实现。敌我共用透明信息层、血条、行动条、种族框和两个动态状态槽；我方姓名按自动/手动显示金色/米白，敌方姓名只读。敌方灰色剪影已替换为 Figma“残禁石傀”透明立绘。四名修士的 idle、攻击、恢复/防御/雷击/飞剑动作均从 `assets/camp/ui/expedition/animations/` 加载；战斗动作使用 16 帧 one-shot，命中时序保持在第 8 帧，结束后恢复 idle。四名修士卡片整体位于 `y=492`；按人物透明边界分别校准脚底的旧纵向锚点已废弃。每张完整人物画布及半透明绿色调试底 `PortraitCanvasDebug` 的底边统一位于卡片内 `y=190`；不再按 InfoOverlay 含透明留白的控件底边 `y=205` 对齐。旧的手动技能大弹窗及人物青蓝色 `SelectedGlow` 选中框已删除，替换为 Figma `358:1393` 的透明三项技能条。未修改人物动作数据流。
- 关键文件：`scripts/scenes/combat.gd`、`scripts/scenes/camp.gd`、`tools/compile_cultivator_animation_runtime.py`、`tools/validate_animated_portraits.gd`、`assets/units/enemies/portrait_can_jin_shi_kui.png`；最新 GUI 预览位于 `/private/tmp/kunwu_enemy_ui_capture/animated_portraits_combat.png`。
- 验证结果：运行时图集编译输出 `CULTIVATOR_ANIMATION_RUNTIME_OK count=13 frame=(172, 298) sheet=(688, 1192)`；Godot 4.7.1 headless 专项回归输出 `ANIMATED_PORTRAIT_VALIDATION_OK`，已覆盖技能条几何、石岩三技能内容、默认选中态及旧蓝框不存在；暂停真实点击回归此前输出 `RESUME_CLICK_VALIDATION_OK`；Godot 编辑器导入/脚本扫描和主场景短启动通过；`git diff --check` 通过。截图确认两敌布局无卡片互压，信息层覆盖在立绘底部。
- 禁止事项：不修改上级 Cocos 工程；不把 Figma/Meowa 作为运行时依赖；不改变 375×817 基准、人物显示尺寸、序列帧遮罩或 `CombatCommand → 结算器 → CombatEvent → 表现层`。
- 阻塞项：当前 Figma 导出是节点显示尺寸 `110×165`；尝试获取 `3×` 源图时，Figma API 不可用且登录态 Chrome 标签被用户侧接管，因此未强行重试。若实机仍显模糊，后续只从 Figma 重新导出高倍率源图，不做本地插值伪高清。
- 待办：用户从营地“设置 → Debug → 直接进入战斗”复核四名修士 idle 与技能动作的实机观感；后续仅按反馈微调局部 UI，或在 Figma 可用时把敌方立绘替换为 `3×` 导出，不回退人物尺寸或动画契约。
