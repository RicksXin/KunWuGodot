# 百宝库首屏还原

Figma：[372:1396](https://www.figma.com/design/9uaK9zzfEzxGYZsCC1Njix/?node-id=372-1396)。

- 正式入口：运行项目，在营地横向拖动到百宝库并点击；读取现有库存数量。
- 设计对照：Godot打开`scenes/treasury_preview.tscn`，按F6；样例只供展示。
- 分类支持全部、装备、材料、关键；点击筛选依次选择全部/凡品/精制/上品。
- 本次是首屏还原，分解与完整装备库存业务未接入。
- 按PRD正式容量为装备0/100，生产资源不占装备仓位；稿中的12/40仅用于设计对照。

验证命令：

```sh
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/treasury-test.log --script res://tools/validate_treasury.gd -- --no-profile-write --ignore-config-cache
```

Noto Sans SC 来自Google Fonts官方仓库，采用SIL OFL，许可证随字体保存。
