# P1-HALL / P1-ECO Godot 客户端技术设计

版本：Godot-1.0  
范围：营地 HUD、建筑、灵源院生产、杂役招募与储量升级

## 1. 目标与边界

- 当前是本地单机 Godot 实现，不依赖 HTTP、Token、账号服务或远程数据库。
- `Game` autoload 是客户端权威状态和事务边界；`camp.gd` 只编排页面和输入。
- 当前不改已确认的全景尺寸、HUD 层级和 Figma Approved 资产。
- 1.0 生产数值升级必须以 PRD-03 为准，不把 D0 兼容常数当正式规则。

## 2. 当前结构

```text
res://scenes/camp.tscn
└─ res://scripts/scenes/camp.gd
   ├─ 构建 ScrollContainer 全景、顶部 HUD 和底部 HUD
   ├─ 打开灵源院/招募/升级面板
   ├─ 调用 Game 查询与命令
   └─ 响应 state_changed / feedback

res://scripts/autoload/game.gd
├─ settle_production()
├─ adjust_workers(job, delta)
├─ recruit_workers()
├─ upgrade_storage(job)
├─ save_profile()
└─ resource_capacity(job)
```

## 3. 顶部与底部 HUD

- 顶部 HUD 从 `Game.profile.wallet` 读取五资源，显示名由本地化表解析。
- 建筑开放、锁定与关注标记从 profile 和当前状态派生，不读图片像素判定。
- 底部入口是 Godot `Button` 热区加 `TextureRect` 视觉子节点，热区不受图标尺寸影响。
- `state_changed` 后统一刷新，不让每个按钮单独修改显示数字。

## 4. 灵源院命令流

```text
打开面板
→ Game.settle_production()
→ 从 profile + ling_pu_config.json 构建页面
→ 用户点击调岗/招募/升级
→ Game 再次结算到当前时刻
→ 校验人数、余额、容量与等级
→ 同一事务修改 profile
→ save_profile()
→ state_changed
```

- 不允许分配人数为负数或超过杂役总数。
- 扣除资源、人数/等级变化、结算锚点和存档同成同败。
- 失败只通过 `feedback` 显示原因，不留下半成功 UI 状态。

## 5. 时间与离线结算

- 业务时间来自 `Time.get_unix_time_from_system()`，存档保存结算锚点。
- 进入营地、打开灵源院、改岗、招募和升级前都使用同一结算入口。
- UI 倒计时可逐帧刷新，但产出入库只由 `settle_production()` 确认。
- 时间回拨、超长离线和满仓必须有可预测的钳制或溢出处理。

## 6. 远程端口预留

如未来明确启用账号与服务端，应在 `Game` 与场景之间新建独立 Port/Adapter，而不让 `camp.gd`
直接发 HTTP。网络适配层必须保留同样的查询结果、错误码、幂等键和事务语义。该预留不代表当前
项目已授权或需要联网。

## 7. 验收

- [ ] 新档顶部 HUD 与存档资源一致。
- [ ] 调岗不产生负人数或超分配。
- [ ] 招募、升级在资源不足时不扣除。
- [ ] 重复打开面板不重复发放同一时段产出。
- [ ] 退出并重启项目后，人数、分配、容量等级和资源一致。
