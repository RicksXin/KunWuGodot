# 交易行首屏

设计来源：[Figma 374:1538](https://www.figma.com/design/9uaK9zzfEzxGYZsCC1Njix/?node-id=374-1538)。

- 营地横滑到交易行并点击，显示当前灵石余额。
- 在Godot打开`scenes/market_preview.tscn`按F6，对照设计稿示例余额。
- 购买按钮打开未开放提示；出售/回购说明当前规则不支持；已购/未开放保持禁用；关闭返回营地。
- 这是旧Draft的视觉还原，商品、价格和状态均为示例。当前PRD只允许购买，不支持出售、回购或装备成品购买；本次不包含交易结算。
- 新增页面：`scripts/ui/market_panel.gd`；验证：`tools/validate_market.gd`；截图：`preview.png`。

验证需带`-- --no-profile-write --ignore-config-cache`，避免写入玩家存档。
