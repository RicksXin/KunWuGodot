# D0 固定遭遇战 Godot 客户端技术设计

版本：Godot-1.0  
范围：`map_01` 残禁石傀固定遭遇

## 1. 目标与边界

- 四名修士对一名残禁石傀的固定时间步战斗。
- 支持自动/手动、三技能、冷却、状态、护盾、治疗、撤离、胜负和战利品。
- 不把动画、伤害文字或 UI 节点作为战斗真值。
- 序列帧特效后续使用 `AnimatedSprite2D`/`SpriteFrames` 或 `AnimationPlayer`。

## 2. 场景与资源

| 内容 | 路径 |
|---|---|
| 战斗场景 | `res://scenes/combat.tscn` |
| 战斗用例与表现 | `res://scripts/scenes/combat.gd` |
| 纯结算器 | `res://scripts/domain/combat_resolver.gd` |
| D0 配置 | `res://data/config/combat_d0.json` |
| 远征与存档事务 | `res://scripts/autoload/game.gd` |

## 3. 状态流

```text
map_scene.gd 触发敌人
→ Game 保存战前地图上下文
→ Game.goto_scene("res://scenes/combat.tscn")
→ combat.gd 从 profile + combat_d0.json 建立单位
→ 固定 20 tick/s 更新行动、冷却和状态
→ CombatCommand
→ KWCombatResolver
→ 伤害/治疗/状态结果
→ combat.gd 更新表现
→ 胜利/失败/撤离结算
```

## 4. 命令与结算

- 自动单位在 timer 到零时选择当前可用技能。
- 手动单位到零后显示技能面板，只接受未冷却技能。
- 目标选择、物理/法术防御、伤害与治疗公式在 `KWCombatResolver` 中完成。
- `combat.gd` 可安排日志、动画和音效，但不得修改规则顺序。
- D0 减伤常数从 `combat_d0.json` 读取，不在表现层另建一份。

## 5. 结算与存档

- 胜利：标记遭遇已处理，把掉落放入临时战利品，保存后回地图。
- 撤离：只在敌人生命低于配置阈值后允许，不发胜利奖励。
- 失败：执行远征失败结算，不覆盖用户其他存档槽或调试数据。
- 结算只允许进入一次；多个敌人在同一 tick 死亡不能重复发奖。

## 6. 表现约束

- 单位生命、行动、状态和自动/手动标识始终可读。
- 伤害闪光、粒子和震屏不得遮挡生命与危险信息。
- 动画卡顿或降级时，结算 tick 和事件顺序不变。

## 7. 验收

- [ ] 自动战斗可完成遭遇。
- [ ] 手动单位只在就绪时可点技能。
- [ ] 护盾、治疗、眩晕、冷却和状态剩余时间正确。
- [ ] 撤离阈值、胜利掉落和失败损失没有重复结算。
- [ ] 重新加载地图后遭遇和战利品状态一致。
- [ ] Godot 无界面加载无脚本解析和缺失资源错误。
