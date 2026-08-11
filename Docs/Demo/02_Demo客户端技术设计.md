# 《昆吾禁地》Demo Godot 客户端技术设计

版本：Godot-1.0  
技术基线：Godot 4.7.1 + GDScript + GL Compatibility

## 1. 客户端目标

- 以独立 Godot 工程完成新档到归营的 D0 闭环。
- 产品状态与页面表现分离，规则不依赖 UI 节点存活。
- 无网络和无上级工程时仍可运行。

## 2. 场景流程

```text
res://scenes/boot.tscn
→ res://scenes/camp.tscn
→ 入山整备（camp.gd 内嵌面板）
→ res://scenes/map.tscn
→ res://scenes/combat.tscn
→ res://scenes/map.tscn
→ res://scenes/camp.tscn
```

场景切换由 `Game.goto_scene()` 执行。`Game` autoload 保留 profile、远征状态、数据表、反馈事件和存档入口。

## 3. 数据流

```text
res://data/**/*.json
        ↓
Game._load_json_tables()
        ↓
Game 事务方法 / KWCombatResolver
        ↓
state_changed + feedback
        ↓
camp.gd / map_scene.gd / combat.gd
```

- 场景脚本不直接写存档文件。
- 场景节点不是业务状态事实源。
- 战斗伤害与治疗走 `KWCombatResolver`，表现只消费结果。

## 4. 页面模块

| 模块 | 场景/脚本 | 职责 |
|---|---|---|
| Boot | `boot.tscn` / `boot.gd` | 启动表现、数据初始化后进入营地 |
| Camp | `camp.tscn` / `camp.gd` | 全景横滑、HUD、灵源院、议事殿、入山整备 |
| Map | `map.tscn` / `map_scene.gd` / `map_canvas.gd` | 四向移动、迷雾、对象、休整、归营 |
| Combat | `combat.tscn` / `combat.gd` | 固定时间步、自动/手动、撤离、结算与战利品 |
| UI 工厂 | `scripts/ui/ui.gd` | 通用 Label、TextureRect、Panel 和按钮样式 |

## 5. 输入与防误触

- 营地横滑只在非弹窗、非按钮区响应；超过拖动阈值后抑制建筑点击。
- 地图同时支持方向按钮、WASD/方向键和相邻可见格点击。
- 弹窗存在时停止背景拖动与世界点击。
- 所有提交按钮在事务返回前不允许并发重复扣除。

## 6. 状态与持久化

- 主存档：`user://kunwu_profile.json`。
- 写入：先写 `user://kunwu_profile.tmp`，再替换主文件。
- 保存时机：生产调整、入山、地图移动、休整、战斗结算和归营。
- 读档：与 `default_profile.json` 合并缺失字段，保留向前兼容。

## 7. 资源与性能

- 只从 `res://assets/` 加载运行资源；美术原始档和第三方原始包由 `.gdignore` 排除。
- 2D 像素素材使用 nearest filtering。
- 当前 Demo 尺寸下可以动态创建 UI；扩展大量页面时应拆成独立 `.tscn` 子场景，避免单脚本无界增长。

## 8. 验证

- Godot 无界面导入和场景解析。
- `tools/validate_project_data.gd` 校验 JSON 和 `res://` 路径。
- `tools/validate_tilemapdual_brush.gd` 校验 Dual Grid 全掩码可达。
- 编辑器内人工完成启动至归营全链路。
