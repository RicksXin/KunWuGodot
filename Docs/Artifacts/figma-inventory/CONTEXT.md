# 百宝库设计还原
- 范围：Figma 9uaK9zzfEzxGYZsCC1Njix / 372:1396 的首屏视觉还原，接营地百宝库入口。
- 事实源：Docs/PRD/06_百宝库与炼器坊_PRD.md；稿中容量40仅用于预览，正式显示装备100仓位。
- 已完成：原始PNG落地、铜木面板准确裁切、Noto Sans SC Medium、4列格子、分类/品质筛选、关闭；数量读Game存档。批量分解提示未开放。
- 关键文件：scripts/ui/treasury_panel.gd、scripts/scenes/camp.gd、assets/camp/ui/treasury/；字体来源google/fonts/ofl/notosanssc，许可证assets/fonts/NotoSansSC-OFL.txt。
- 预览入口：scenes/treasury_preview.tscn（F6）；正式入口：营地百宝库。preview.png为Godot实际渲染的设计示例。
- 验证：Godot 4.7.1 headless导入无脚本错误；tools/validate_treasury.gd在GUI和headless均输出TREASURY_OK；覆盖示例/实际库存、分类、品质、关闭。所有验证带--no-profile-write --ignore-config-cache。沙箱headless出现macOS系统证书读取提示，未影响验证；GUI无错误。
- 边界：当前仅映射稿中物品，装备业务尚未迁入，实际装备仓位显示0/100。不是完整1.0仓库/装备/分解实现；筛选当前只支持品质轮换。生产页无样例库存写入。
- 禁止：写样例入存档、覆盖已有其他改动、猜测装备结算规则。
- 待办：用户在Godot视觉复核面板、文字、图标位置；完整业务另行实现。

- 数量对齐修复：替换受字体最小行高影响的Label，使用格内34×13固定绘制区域和统一右下基线；GUI运行验证通过，截图确认1至4位数量均在边框内。

- 交易行复用时修正共用Noto Medium字体轴为Godot整数tag，500字重现已生效；百宝库回归TREASURY_OK。数量左移2px保持(17,24)。旧百宝库截图早于字体修正。
