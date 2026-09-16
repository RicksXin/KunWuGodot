# 炼器坊首屏还原

来源：[Figma 382:2124](https://www.figma.com/design/9uaK9zzfEzxGYZsCC1Njix/?node-id=382-2124)。

- 营地横滑至炼器坊并点击打开；独立对照场景为`scenes/forge_preview.tscn`，Godot按F6运行。
- 支持选择配方、切换当前配方说明、查看未开放提示、关闭；材料不足与未解锁按钮禁用。
- 六个配方、等级、数量与材料状态均来自旧稿示例，未接实际材料判定和打造结算。
- 当前PRD不支持重铸，且品质由铁胚决定；稿中的旧说明仅作视觉还原。
- 主脚本：`scripts/ui/forge_panel.gd`。验证：`tools/validate_forge.gd`。实际截图：`preview.png`。
- 验证需带`-- --no-profile-write --ignore-config-cache`，不得覆盖玩家存档。
