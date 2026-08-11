# P1-HALL / P1-ECO Godot 本地实现与验收

版本：Godot-1.0

## 1. 当前本地实现

当前没有独立 HTTP 适配器。`Game` autoload 以 Godot 本地文件 API 实现单机权威状态：

- 配置来自 `res://data/config/ling_pu_config.json`。
- 用户状态来自 `user://kunwu_profile.json`。
- 结算、调岗、招募和升级在 `scripts/autoload/game.gd` 中集中完成。
- 页面只通过方法返回值、`state_changed` 和 `feedback` 与 `Game` 交互。

## 2. 本地事务模型

1. 读取当前 profile 与配置。
2. 在修改前结算到当前时刻。
3. 校验输入、余额、人数、等级与容量。
4. 在内存 profile 中完成同一命令的全部变更。
5. 写入临时存档，成功后替换主存档。
6. 发出 `state_changed`；失败时发出 `feedback` 并不保留部分结果。

## 3. 自动验证

### 3.1 数据校验

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --path "/Users/zhangxiaoen/Desktop/Game/KunWuGodot" \
  --script res://tools/validate_project_data.gd
```

### 3.2 项目导入与解析

```bash
/Applications/Godot.app/Contents/MacOS/Godot \
  --headless --editor --path "/Users/zhangxiaoen/Desktop/Game/KunWuGodot" --quit
```

两条命令都必须退出 `0`，且没有 JSON、GDScript、场景或 `res://` 资源加载错误。

## 4. 正常流程验收

### 4.1 顶部 HUD

- [ ] 五资源名称与数量来自本地化和 profile，不显示图片内烘焙假数据。
- [ ] 资源变化后 HUD 只刷新一次，不闪现旧值。

### 4.2 底部 HUD 和建筑

- [ ] 图标可点区与可见尺寸分离。
- [ ] 锁定建筑显示锁定贴图/标记且不执行开放命令。
- [ ] 开放建筑有待办时显示关注标记。

### 4.3 灵源院

- [ ] 调岗前先结算，调岗后人数总和不变。
- [ ] 招募成功时扣除资源并增加杂役；失败时两者都不变。
- [ ] 储量升级对应正确资源，满级或不足时禁用。
- [ ] 关闭再打开面板后显示已保存状态。

## 5. 异常与恢复验收

- [ ] 存档文件不存在时建立新档。
- [ ] 存档缺字段时合并默认值，不删除未知业务字段。
- [ ] 写入失败时显示错误，不声称命令已成功。
- [ ] 重复刷新或打开灵源院不会对同一时间区间重复结算。

## 6. 当前限制

- 没有账号、鉴权、远程数据库或跨设备同步。
- D0 生产数值与 1.0 PRD-03 仍需单独升级，不在引擎迁移中偷换数值口径。
- 当前项目只有单用户存档。
