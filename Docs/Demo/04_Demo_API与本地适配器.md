# 《昆吾禁地》Demo 本地服务边界与未来 API

适用产品版本：0.1 Demo  
文档修订：Godot-1.1  
日期：2026-08-11  
状态：当前 Godot 单机实现说明；联网 API 仅为未来预留

## 1. 当前结论

D0/D1 不运行 HTTP 服务，也没有独立 Port/Adapter 类。当前业务状态集中在
`res://scripts/autoload/game.gd` 的 `Game` autoload，持久化到
`user://kunwu_profile.json`。场景脚本通过 `Game` 的领域方法提交动作，不直接改写存档文件。

```text
Godot 场景输入
  → Game 领域方法 / KWCombatResolver
  → profile 或 expedition 快照
  → 原子临时文件替换
  → state_changed / feedback
  → 场景刷新表现
```

未来联网时可以在 `Game` 与远端之间增加适配层，但这不是当前 Demo 门槛，也不得为了预留网络而
破坏已经工作的本地闭环。

## 2. 当前本地能力

| 模块 | 当前入口 | 持久化/结果 |
|---|---|---|
| Camp/HUD | `Game.profile`、资源显示方法 | `profile.wallet`、`profile.camp` |
| 灵源院 | `settle_production`、调岗、招募、储量升级方法 | 营地快照与结算锚点 |
| 入山整备 | `start_expedition` 及装载校验 | 唯一 `profile.expedition` |
| Map | 移动、迷雾、对象和休整方法 | expedition 地图快照 |
| Combat | `KWCombatResolver` + `scripts/scenes/combat.gd` | `CombatEvent` 与战斗结果 |
| 归营 | `return_to_camp` 结算路径 | 临时战利品入账后清除 expedition |

场景层只调用公开方法并读取返回结果；结算公式不得复制到按钮回调或纯 UI 节点。

## 3. 本地事务与失败处理

- 消费、奖励、状态切换和存档必须同成同败；失败时返回明确原因。
- `save_profile()` 先写 `user://kunwu_profile.tmp`，再替换正式文件。
- 重复进入场景从同一 profile/expedition 快照恢复，不创建第二份远征或重复发奖。
- 战斗保持 `CombatCommand → KWCombatResolver → CombatEvent → 表现层`。
- 测试和无界面验证不得覆盖用户的正式 `user://kunwu_profile.json`。

## 4. 未来联网边界

若正式项目需要联网，再按业务边界增加传输中立的请求/响应 DTO：

- 请求携带期望状态版本和幂等键；
- 服务端返回完整权威快照，客户端以响应覆盖本地镜像；
- HTTP 状态码、请求头和 Token 只存在于网络适配器；
- 表现层继续消费现有领域结果，不直接解析 HTTP；
- 离线单机存档迁移与在线账号同步必须分别设计。

大厅/灵源院的历史 API 契约保存在
[`API/P1_CAMP_HUD_LING_PU_API.md`](API/P1_CAMP_HUD_LING_PU_API.md)，仅用于未来设计参考；
它不证明当前 Godot 工程实现了对应端点。

## 5. 当前验收

1. 从 `res://scenes/boot.tscn` 进入并完成营地—整备—地图—战斗—归营闭环。
2. 退出并重新运行项目后从唯一存档恢复，不重复消费或发奖。
3. 资源不足、非法移动、会话无效和保存失败均产生可理解反馈。
4. 场景脚本不直接写 `user://`，表现层不重算领域结果。
5. `res://tools/validate_project_data.gd` 与 Godot 无界面项目加载均通过。
