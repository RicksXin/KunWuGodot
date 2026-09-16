# 还魂殿 Figma 设计
- 当前范围：用户批准免费救急878:2674与无人待还魂878:2798两版Godot还原；普通付费列表保留已有实现。
- 事实源：Docs/PRD/05_修士成长突破与还魂_PRD.md 页面revive_hall。
- 设计：375×817营地木纹铜框，同库实例/Noto Sans SC Medium/本地Theme变量；三状态：待还魂、无存活且魂晶不足的免费救急、无人待还魂。
- 规则：固定成功、只消耗魂晶、不损失等级境界职业技能装备成长；救急只恢复一人。
- 组件检查：无Code Connect；现有屏幕已解析Panel/Decoration、PanelItemV2、Button Footer/Inline、头像与魂晶。颜色使用既有变量；无本地间距变量和文本/效果样式。
- 待办：完成内容与视觉检查，记录新节点链接。
- 已完成：Figma Page1新建三稿，未改既有稿。主稿878:2550；免费救急878:2674；无人待还魂878:2798；坐标从x8015起横向排列。
- 内容：主稿两名炼气Lv10（各100魂晶），余额280/合计200/剩余80；救急四人阵亡余额20，免费恢复石岩一人；空状态通往整备。
- 验证：三稿均375×817，内容高度440/416/343，底部操作y718；正文Noto Sans SC字体断言无错误；已检查三张截图并修正主稿姓名换行和墨言隐藏头像。
- 使用现有组件实例（营地主界面、Panel/装饰、PanelItemV2、按钮），主题色绑定原有变量，内容区域Auto Layout；未新增设计系统组件。
- 交付：main.png/emergency.png/empty.png为Figma截图。静态可编辑设计稿，尚未制作点击原型或Godot还原；用户视觉确认后再实现。

- 最新用户修订：三版正文相对面板主体左右各24px，页面x44/宽287；底部按钮同列对齐。删除氛围句、重复规则和冗余状态；救急仅保留必要条件/单人免费限制，空状态仅保留标题及前往整备提示。三稿截图已更新并复核，旧x32/宽311及原内容高度作废。

- Godot已完成：scripts/ui/revive_panel.gd；camp.gd按实际阵亡/魂晶状态路由两版，空状态可由营地直接进入；assets/camp/ui/revive/四名头像为确认稿原始导出。左右24px，正文x44/宽287。
- 交互：选择救急对象→Game.emergency_revive_cultivator→重新展示实际状态；保存失败原流程回滚；空状态按钮打开整备。姓名/职业/境界/等级/费用来自Game，石岩现有职业文本为剑修而非稿中示例武修。
- 验证：Godot4.7.1导入无脚本错误；validate_revive_design.gd输出REVIVE_DESIGN_OK（换选、免费恢复恰好一人、不扣魂晶、不可重复救急、空状态打开整备）；原validate_revival_flow.tscn回归REVIVAL_FLOW_VALIDATION_OK。测试均使用--no-profile-write --ignore-config-cache，未覆盖玩家存档。
- 视觉：emergency_godot.png/empty_godot.png为实际运行截图，已核对；复核入口F5→营地还魂殿。
