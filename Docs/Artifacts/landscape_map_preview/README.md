# 横版地图视觉预览

这是与现有竖版运行链隔离的 16:9 视觉方向版本。它只新增独立场景、脚本和项目配置，
不会替换 `project.godot`、`scenes/boot.tscn`、`scenes/camp.tscn`、`scenes/map.tscn` 或
`scenes/combat.tscn`。

任务续接和上下文压缩请只读取同目录的 [`CONTEXT.md`](CONTEXT.md)，不要重放完整对话或大体积美术产物。

## 运行

不要在 KunWuGodot 项目根目录直接执行（Godot 会自动发现竖版 `project.godot`）。最简单的方式是双击项目根目录的 `run_landscape_preview.command`。如果使用 Godot 项目管理器，请导入 `landscape_preview_project/project.godot`，不要导入根目录的 `project.godot`。

```bash
cd /private/tmp
/Applications/Godot.app/Contents/MacOS/Godot \
  --path "/Users/zhangxiaoen/Desktop/Game/KunWuGodot/landscape_preview_project" \
  --rendering-method gl_compatibility \
  --rendering-driver opengl3 \
  -- \
  --no-profile-write \
  --ignore-config-cache
```

注意：必须把 `project_landscape.godot` 作为命令行入口或单独项目打开；在竖版项目里按 `F6` 会继续使用 `375×817` 视口，看起来仍是竖版。

也可以用 Godot 编辑器打开 `project_landscape.godot`，再运行默认场景。直接在竖版项目编辑器里
按 F6 会继续使用竖版项目的视口设置，不代表横版运行尺寸。

## 当前范围

- 16:9 横版地图信息层级和固定 HUD 试作；
- 整张高清 Map01 作为可平移地图内容，支持鼠标/触控板拖动和右侧滚动条查看上下区域；
- 中式水墨玄幻的暗色地图、金色路径、区域详情和任务面板；
- 地标点击、休整/背包/归营提示等轻量交互；
- 视觉预览不写入 `user://kunwu_profile.json`，不接管正式 Map01 逻辑。

正式地图数据、移动、阻挡、对象、Marker 与战斗流仍以现有 Godot 工程事实源为准。
