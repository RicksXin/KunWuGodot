# 地图1配置闭环任务状态

当前范围：地图1新遭遇 → Boss真实装备 → 穿戴与归营/阵亡结算。用户确认Boss法器1件、真宝1件。未授权生成美术。

已完成：Admin v1_0修订211，13设计绑定14入口（含剧情战），6初始装备模板；数据库装配敌人/技能实际数值；Godot开发快照、稳定装备实例、背包装备管理、属性增减、首杀幂等、任务物保护、30%失败损失和存档失败回滚。坐标美术不变。完整说明见 ../KunWuAdmin/Docs/26_地图1遭遇装备与结算闭环.md。

验证：Admin遭遇5测、typecheck/lint/build；Godot地图闭环/实际战斗/正式地图/项目数据/后台适配通过。面板加载通过，视觉复核入口百宝库→装备管理。

发布：开发频道仍dev-r4-5，未发布v1_0。完整校验5阻断：敌人、遭遇、地图、出征配置及运行包引用停用敌人检查。不要绕过发布检查。

下一步：地图/出征规则入库与地图1启用策略，随后新档NPC解锁和玩家新版技能。装备初始倍率100/120与2属性槽是本轮初始数值尚未平衡验收；装备重量未接入，旧已首杀存档不自动补偿。

关键文件：Admin server/domain/encounters/loop.ts、map01-loop.json、server/services/map01-loop.ts、tools/sync-map01-loop.ts；Godot scripts/domain/equipment.gd、autoload/game.gd、config_repository.gd、ui/equipment_panel.gd、scenes/combat.gd。测试tools/validate_map01_loop.gd。

红线：所有Godot测试加 --no-profile-write --ignore-config-cache；不覆盖真实存档、不覆盖无关修改（尤其camp.gd）、不修改地图坐标美术、不发布未验证整版。
