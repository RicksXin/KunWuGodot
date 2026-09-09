# 正式 Map01 高清出征：当前状态

## 范围
2026-09-09 最新用户授权：将已确认高清古道定稿为唯一正式 map01，接入营地出征、战斗返回与归营，删除旧地图资源代码及Demo入口。此前“不改变正式Map01”的任务边界已废弃。保留玩法语义与其他模块改动；迁移旧格子对象/状态到新的连续坐标需要验证，不能只更换入口。

## 迁移进度
已核对出征入口均指向 scenes/map.tscn，旧map_scene.gd承担休整/背包/事件/战斗入口；Game持有格子消耗与存档。已完成正式迁移：连续地图控制器成为 `scenes/map.tscn` 的运行入口，Game 通过 `map_01.json` 与 `map_01_regions.json` 处理移动、灵粮、迷雾、对象、战斗和归营；旧 Demo/旧格子渲染资源已删除。

## 当前事实与实现
- 配套素材：`assets/maps/map_01/hd_annotations_source/`，来源为用户的 `Frame_5_20260908_193310_358` 导出。
- Demo 背景改为包内 `images/overall/source.png`（2488×5692），替代上一张1421×3071图；使用现有897×1938.541世界矩形，导航已迁移到配套JSON的36个碰撞多边形。
- `scripts/maps/map_annotations_overlay.gd` 直接读取 `map01_hd_annotations_godot.json` 的 canvas 与 annotations.layers：36碰撞、17调节。原始点不缩写、不滤除大区域。
- 标注通过背景 Sprite2D 的变换及纹理尺寸映射到世界坐标，再共享相机变换，修复遗漏背景缩放导致约1.58倍的错误。
- 用顶点和交点划分的奇偶规则梯形填充处理自交轮廓，保留原始边线，避免 Godot 多边形三角剖分报错。
- **实际导航已接入36个红色碰撞多边形**：地图边界内、碰撞区域外可走，角色足底半径5参与边缘距离检测。紫色调节层不当作阻挡。键盘、触屏移动与点击寻路共用 can_walk；原手绘走廊/圆形障碍数据已移除。
- Debug“路线”显示真实寻路网格；Shift编辑可增加禁行，普通编辑恢复原始可走状态，不允许覆盖源JSON阻挡。保存仅写既有Debug文件，不修改源JSON。
- 默认缩放120%，普通100%–150%，Debug目前14%–220%（尚非无限）。

## 关键文件
`data/demos/mountain_walk.json`、`scripts/scenes/mountain_walk.gd`、`scripts/maps/map_annotations_overlay.gd`、`scripts/maps/map_navigation.gd`、`tools/validate_map01_formal.gd`、`tools/validate_map01_formal.gd`。

## 验证
- Godot 4.7.1 headless编辑器导入退出0，无脚本/资源错误。
- `validate_mountain_walk.gd` PASS：五地标寻路并逐步实际移动、全部碰撞顶点阻挡、非法点击、大步移动不穿越、Debug禁行/恢复、键盘移动、缩放、设置往返及档案不变。
- 图形运行 `validate_mountain_walk_annotation_alignment.gd` PASS：53区域原始顶点保留、全部碰撞顶点的视觉/移动世界坐标一致、14/50/120/220%对齐，无渲染错误。
- 实机截图 `/private/tmp/kunwu_annotation_aligned.png`；用户复核入口 F5 → 设置 → 正式 Map01 高清出征 → 碰撞层 / 路线。

## 已完成
用户确认的高清地图已正式成为 map01；旧 Demo、旧格子地图渲染器、旧候选预览和旧地图数据已清理。营地出征使用 `scenes/map.tscn` 连续地图，Game 对象、迷雾、灵粮、休整、战斗、条件机关和归营链路已迁移并通过回归。后续地图参照 `Docs/Tech/高清地图与外部标注接入规范.md`。外部复杂轮廓按奇偶规则处理；不从图像像素推断地形。

## 安全与续接
所有验证带 `--no-profile-write --ignore-config-cache`，日志放临时目录；保留其他营地、战斗、头像和文档改动。无需调用美术生成服务。
