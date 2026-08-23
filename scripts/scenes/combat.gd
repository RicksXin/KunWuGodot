extends Control

const SHI_YAN_IDLE_HD2X_SHEET_SIZE := Vector2i(688, 1640)
const SHI_YAN_IDLE_STANDARD_FPS := 8.0
const SHI_YAN_CAST_A_SHEET_PATH := "res://assets/camp/ui/expedition/animations/shi_yan/shi_yan_punch_sheet.png"
const SHI_YAN_CAST_A_SHEET_SIZE := Vector2i(688, 820)
const SHI_YAN_CAST_A_WIDE_SHEET_SIZE := Vector2i(960, 820)
const SHI_YAN_HD_TEXTURE_SCALE := 2.0
const SHI_YAN_CAST_A_WIDE_PRESENTATION_SCALE := 0.98
const SHI_YAN_CAST_A_WIDE_VERTICAL_OFFSET := 0.0
const SHI_YAN_CAST_A_FPS := 10.0
const SHI_YAN_CAST_A_HIT_FRAME := 4
const SHI_YAN_CAST_A_MODE := "shi_yan_cast_a"
const PORTRAIT_IDLE_MODE := "idle"
const TARGET_HIT_VFX_DURATION := 0.22

var units: Array = []
var log_lines: Array[String] = []
var log_label: Label
var tick_label: Label
var unit_hosts: Dictionary = {}
var timer_accum := 0.0
var combat_ticks := 0
var finished := false
var skill_panel: Panel
var skill_buttons: Array[Button] = []
var outcome_overlay: Control
var outcome_panel: Panel
var loot_overlay: Control
var loot_burden_label: Label
var loot_status_label: Label
var loot_backpack_buttons: Array[Button] = []
var loot_reward_labels: Array[Label] = []
var loot_take_all_button: Button
var escape_button: Button
var animated_portraits: Array[Dictionary] = []
var active_target_hit_vfx: Dictionary = {}
var shi_yan_cast_a_hit_count := 0
var current_encounter: Dictionary = {}

func _ready() -> void:
	if Game.profile.get("expedition") == null:
		call_deferred("_go_camp")
		return
	current_encounter = Game.get_encounter()
	if current_encounter.is_empty():
		call_deferred("_go_map")
		return
	_build_units()
	if units.filter(func(unit): return unit.get("side") == "enemy").is_empty():
		call_deferred("_go_map")
		return
	_build_scene()
	_refresh()
	set_process(true)

func _go_camp() -> void:
	get_tree().change_scene_to_file("res://scenes/camp.tscn")

func _go_map() -> void:
	Game.clear_active_encounter()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _build_units() -> void:
	var heroes: Array = Game.party_heroes()
	var timers: Array = Game.combat_config.get("partyInitialActionTimers", [30, 40, 50, 60])
	for index in heroes.size():
		var hero: Dictionary = heroes[index]
		var initial_timer := int(timers[index] if index < timers.size() else 30)
		units.append({"unit_id": index + 1, "name": Game.text(hero.get("nameKey", "修士")), "side": "ally", "hero": hero, "hp": int(hero.get("currentHp", hero.get("maxHp", 1))), "max_hp": int(hero.get("maxHp", 1)), "attrs": hero.get("attributes", {}), "skills": hero.get("skillIds", []), "timer": initial_timer, "action_max": initial_timer, "auto": true, "dead": false, "shield": 0, "cooldowns": {}, "statuses": []})
	for enemy_index in current_encounter.get("enemies", []).size():
		var enemy: Dictionary = current_encounter.get("enemies", [])[enemy_index]
		var enemy_timer := int(enemy.get("initialActionTimer", 45))
		units.append({"unit_id": 100 + enemy_index, "name": Game.text(enemy.get("nameKey", "敌人")), "side": "enemy", "enemy": enemy, "hp": int(enemy.get("maxHp", 1)), "max_hp": int(enemy.get("maxHp", 1)), "attrs": enemy.get("attributes", {}), "skills": enemy.get("skillIds", []), "timer": enemy_timer, "action_max": enemy_timer, "auto": true, "dead": false, "shield": 0, "cooldowns": {}, "statuses": []})

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0a171d")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_add_combat_polygon(PackedVector2Array([
		Vector2(0, 338.5), Vector2(67.5, 228.5), Vector2(139.5, 314.5),
		Vector2(212.5, 188.5), Vector2(282.5, 292.5), Vector2(375, 210.5),
		Vector2(375, 817), Vector2(0, 817),
	]), Color("#13272c"))
	_add_combat_polygon(PackedVector2Array([
		Vector2(0, 496.5), Vector2(107.5, 438.5), Vector2(261.5, 553.5),
		Vector2(375, 480.5), Vector2(375, 817), Vector2(0, 817),
	]), Color("#1d2f2f"))
	for index in 7:
		var line := Line2D.new()
		line.width = 2.0
		line.default_color = Color("#73503869")
		line.points = PackedVector2Array([Vector2(0, 538.5 + index * 38), Vector2(375, 558.5 + index * 38)])
		add_child(line)
	KWUI.label(self, "破禁山麓 · 遭遇战", Rect2(72.5, 22.5, 230, 24), 13, Color("#c6cdb9"), HORIZONTAL_ALIGNMENT_CENTER)
	tick_label = KWUI.label(self, "战斗 0.0 秒", Rect2(5.5, 53.5, 90, 20), 10, Color("#849d9c"))
	var flee := KWUI.combat_button(self, "逃生", Rect2(282.5, 22.5, 86, 44), 13)
	flee.pressed.connect(_escape)
	flee.visible = false
	escape_button = flee
	var enemy_host := KWUI.panel(self, Rect2(144.5, 156, 86, 205), Color("#3a312ef5"), Color("#895344"))
	unit_hosts[100] = enemy_host
	_add_enemy_silhouette(enemy_host)
	KWUI.panel(enemy_host, Rect2(1, 149, 84, 56), Color("#070a0ddc"), Color.TRANSPARENT).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var enemy_name := KWUI.combat_button(enemy_host, "残禁石傀", Rect2(4, 145, 78, 18), 11)
	enemy_name.name = "Name"
	enemy_name.disabled = true
	enemy_name.add_theme_stylebox_override("normal", KWUI.style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	enemy_name.add_theme_stylebox_override("disabled", KWUI.style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
	enemy_name.add_theme_color_override("font_disabled_color", Color8(235, 230, 207))
	KWUI.label(enemy_host, "傀", Rect2(2, 164, 12, 12), 8, Color("#dbb57a"), HORIZONTAL_ALIGNMENT_CENTER).name = "Race"
	var enemy_bar := ProgressBar.new()
	enemy_bar.name = "Hp"
	enemy_bar.position = Vector2(18, 169)
	enemy_bar.size = Vector2(62, 8)
	enemy_bar.show_percentage = false
	enemy_bar.add_theme_stylebox_override("background", KWUI.style_box(Color("#151012"), Color("#7d4949"), 2, 1))
	enemy_bar.add_theme_stylebox_override("fill", KWUI.style_box(Color("#be4636"), Color("#ef9b72"), 2, 0))
	enemy_host.add_child(enemy_bar)
	KWUI.label(enemy_host, "", Rect2(18, 168, 62, 10), 7, Color("#f5efd8"), HORIZONTAL_ALIGNMENT_CENTER).name = "HpValue"
	_combat_progress(enemy_host, "Action", Vector2(18, 180), Color("#0c1113"), Color("#4bccd0"), Vector2(62, 5))
	KWUI.label(enemy_host, "", Rect2(4, 186, 78, 14), 8, Color("#dbc482"), HORIZONTAL_ALIGNMENT_CENTER).name = "Status"
	for index in 4:
		var x := 15.5 + index * 86
		var host := KWUI.panel(self, Rect2(x, 541, 86, 205), Color("#2a3a41eb"), Color("#537a7d"))
		# 人物可使用更宽的攻击运动画布，但最终画面必须由自己的修士框裁切。
		host.clip_contents = true
		unit_hosts[index + 1] = host
		var portrait_path: String = str(["shi_yan", "lu_qing", "bai_ling", "mo_yan"][index])
		var portrait_mask := Control.new()
		portrait_mask.name = "PortraitMask"
		portrait_mask.position = Vector2(1, 1)
		portrait_mask.size = Vector2(84, 203)
		portrait_mask.clip_contents = true
		portrait_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(portrait_mask)
		var portrait := KWUI.texture(portrait_mask, "res://assets/camp/ui/expedition/portrait_hero_%s_expedition.png" % portrait_path, Rect2(-1, -1, 86, 205))
		var idle_sheet_path := "res://assets/camp/ui/expedition/animations/%s/%s_idle_sheet.png" % [portrait_path, portrait_path]
		var idle_sheet: Texture2D = load(idle_sheet_path) if ResourceLoader.exists(idle_sheet_path) else null
		if idle_sheet:
			var use_hd2x_idle := portrait_path == "shi_yan" and Vector2i(idle_sheet.get_width(), idle_sheet.get_height()) == SHI_YAN_IDLE_HD2X_SHEET_SIZE
			var idle_rows := 4 if use_hd2x_idle else 2
			var frames := _sheet_frames(idle_sheet, 4, idle_rows)
			portrait.texture = frames[0]
			portrait.size = Vector2(86, 205) if use_hd2x_idle else Vector2(86, 149)
			if use_hd2x_idle:
				portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var portrait_animation := {
				"node": portrait,
				"unit_id": index + 1,
				"frames": frames,
				"idle_frames": frames,
				"idle_frame_duration": 1.0 / SHI_YAN_IDLE_STANDARD_FPS if use_hd2x_idle else 1.0 / 6.0,
				"frame_duration": 1.0 / SHI_YAN_IDLE_STANDARD_FPS if use_hd2x_idle else 1.0 / 6.0,
				"elapsed": 0.0,
				"frame_index": 0,
				"loop": true,
				"mode": PORTRAIT_IDLE_MODE,
			}
			if portrait_path == "shi_yan" and ResourceLoader.exists(SHI_YAN_CAST_A_SHEET_PATH):
				var cast_a_sheet := load(SHI_YAN_CAST_A_SHEET_PATH) as Texture2D
				var cast_a_sheet_size := Vector2i(cast_a_sheet.get_width(), cast_a_sheet.get_height()) if cast_a_sheet != null else Vector2i.ZERO
				if cast_a_sheet != null and cast_a_sheet_size in [SHI_YAN_CAST_A_SHEET_SIZE, SHI_YAN_CAST_A_WIDE_SHEET_SIZE]:
					portrait_animation["cast_a_frames"] = _sheet_frames(cast_a_sheet, 4, 2)
			animated_portraits.append(portrait_animation)
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		KWUI.panel(host, Rect2(1, 149, 84, 56), Color("#070a0ddc"), Color.TRANSPARENT).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var name_button := KWUI.combat_button(host, "", Rect2(4, 145, 78, 18), 10)
		name_button.name = "Name"
		name_button.add_theme_stylebox_override("normal", KWUI.style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		name_button.add_theme_stylebox_override("hover", KWUI.style_box(Color("#1f3936aa"), Color("#4dd5c088"), 2, 1))
		name_button.pressed.connect(_toggle_auto.bind(index + 1))
		KWUI.label(host, "人", Rect2(2, 164, 12, 12), 8, Color("#b7d8cf"), HORIZONTAL_ALIGNMENT_CENTER).name = "Race"
		var bar := ProgressBar.new()
		bar.name = "Hp"
		bar.position = Vector2(18, 168)
		bar.size = Vector2(62, 8)
		bar.show_percentage = false
		bar.add_theme_stylebox_override("background", KWUI.style_box(Color("#101719"), Color("#3d6259"), 2, 1))
		bar.add_theme_stylebox_override("fill", KWUI.style_box(Color("#4b9f7e"), Color("#8ee2aa"), 2, 0))
		host.add_child(bar)
		KWUI.label(host, "", Rect2(18, 167, 62, 10), 7, Color("#f5efd8"), HORIZONTAL_ALIGNMENT_CENTER).name = "HpValue"
		_combat_progress(host, "Action", Vector2(18, 179), Color("#0c1113"), Color("#4bccd0"), Vector2(62, 5))
		KWUI.label(host, "", Rect2(4, 186, 78, 14), 8, Color("#dbc482"), HORIZONTAL_ALIGNMENT_CENTER).name = "Status"
		# Panel 自身的边框绘制在子节点之后不可控，因此再叠一层透明前景边框，
		# 确保人物像素永远位于修士框边线之下。
		var frame_overlay := Panel.new()
		frame_overlay.name = "FrameOverlay"
		frame_overlay.position = Vector2.ZERO
		frame_overlay.size = Vector2(86, 205)
		frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_overlay.z_index = 100
		frame_overlay.add_theme_stylebox_override("panel", KWUI.style_box(Color.TRANSPARENT, Color("#537a7d"), 6, 1))
		host.add_child(frame_overlay)
	var skill_card := KWUI.panel(self, Rect2(54, 424.5, 267, 78), Color("#0a0f12eb"), Color("#657762"))
	skill_card.mouse_filter = Control.MOUSE_FILTER_STOP
	KWUI.label(skill_card, "行动就绪 · 请选择技能", Rect2(13.5, 4, 240, 18), 10, Color("#abb8a6"), HORIZONTAL_ALIGNMENT_CENTER)
	for index in 3:
		var skill_button := KWUI.combat_button(skill_card, "技能", Rect2(14.5 + index * 82, 28, 74, 42), 11)
		skill_button.pressed.connect(_choose_skill.bind(index))
		skill_buttons.append(skill_button)
	skill_panel = skill_card
	skill_panel.visible = false
	log_label = KWUI.label(self, "", Rect2(62.5, 362.5, 250, 28), 11, Color("#abb8a6"), HORIZONTAL_ALIGNMENT_CENTER)
	outcome_overlay = Control.new()
	outcome_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	outcome_overlay.visible = false
	add_child(outcome_overlay)
	var outcome_shade := ColorRect.new()
	outcome_shade.color = Color("#030609cd")
	outcome_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outcome_overlay.add_child(outcome_shade)
	outcome_panel = KWUI.panel(outcome_overlay, Rect2(30, 272.5, 315, 236), Color("#181d1eff"), Color("#9a7e48"))
	outcome_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_build_loot_overlay()

func _build_loot_overlay() -> void:
	loot_overlay = Control.new()
	loot_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loot_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	loot_overlay.visible = false
	add_child(loot_overlay)
	var shade := ColorRect.new()
	shade.color = Color("#030609da")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	loot_overlay.add_child(shade)
	var panel := KWUI.panel(loot_overlay, Rect2(20, 135.5, 335, 530), Color("#181d1eff"), Color("#9a7e48"))
	KWUI.label(panel, "战利品", Rect2(22.5, 15, 290, 34), 23, Color("#edddad"), HORIZONTAL_ALIGNMENT_CENTER)
	loot_burden_label = KWUI.label(panel, "当前负重 --/--", Rect2(22.5, 45, 290, 24), 13, Color("#cdd5c1"), HORIZONTAL_ALIGNMENT_CENTER)
	var backpack := KWUI.panel(panel, Rect2(16, 78, 303, 190), Color("#111718"), Color("#52655b"))
	KWUI.label(backpack, "当前野外背包", Rect2(10, 10, 125, 22), 13, Color("#d5cdaa"))
	KWUI.label(backpack, "点击物品可丢弃 1 个并释放负重", Rect2(130, 10, 160, 20), 10, Color("#8f9a8f"), HORIZONTAL_ALIGNMENT_RIGHT)
	for index in 5:
		var row := KWUI.combat_button(backpack, "空", Rect2(13, 43 + index * 29, 277, 25), 11)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.visible = false
		row.pressed.connect(_drop_loot_item.bind(index))
		loot_backpack_buttons.append(row)
	var rewards := KWUI.panel(panel, Rect2(16, 283, 303, 150), Color("#111718"), Color("#52655b"))
	KWUI.label(rewards, "本场战利品", Rect2(10, 10, 125, 22), 13, Color("#d5cdaa"))
	for index in 4:
		loot_reward_labels.append(KWUI.label(rewards, "", Rect2(15, 38 + index * 25, 273, 22), 11, Color("#d5cdaa")))
	loot_status_label = KWUI.label(panel, "", Rect2(20, 440, 295, 34), 11, Color("#a8c2a6"), HORIZONTAL_ALIGNMENT_CENTER)
	loot_take_all_button = KWUI.combat_button(panel, "全部拾取", Rect2(24, 478, 134, 44), 13)
	loot_take_all_button.pressed.connect(_take_all_loot)
	var leave := KWUI.combat_button(panel, "离开", Rect2(177, 478, 134, 44), 13)
	leave.pressed.connect(_leave_loot)

func _process(delta: float) -> void:
	_update_animated_portraits(delta)
	if finished: return
	timer_accum += delta
	while timer_accum >= 0.2:
		timer_accum -= 0.2
		_step(4)

func _update_animated_portraits(delta: float) -> void:
	for index in range(animated_portraits.size() - 1, -1, -1):
		var animation: Dictionary = animated_portraits[index]
		var portrait_reference: Variant = animation.get("node")
		if not is_instance_valid(portrait_reference):
			animated_portraits.remove_at(index)
			continue
		var portrait := portrait_reference as TextureRect
		var frames: Array = animation.get("frames", [])
		if portrait == null or frames.is_empty():
			animated_portraits.remove_at(index)
			continue
		var elapsed := float(animation.get("elapsed", 0.0)) + delta
		var frame_duration := maxf(float(animation.get("frame_duration", 1.0 / 6.0)), 0.001)
		var frame_index := int(animation.get("frame_index", 0))
		while elapsed >= frame_duration:
			elapsed -= frame_duration
			if frame_index + 1 < frames.size():
				frame_index += 1
				if str(animation.get("mode", PORTRAIT_IDLE_MODE)) == SHI_YAN_CAST_A_MODE \
						and frame_index == int(animation.get("hit_frame", SHI_YAN_CAST_A_HIT_FRAME)) \
						and not bool(animation.get("hit_fired", false)):
					animation["hit_fired"] = true
					_spawn_target_hit_vfx(int(animation.get("target_unit_id", -1)))
			elif bool(animation.get("loop", true)):
				frame_index = 0
			else:
				animation = _restore_portrait_idle(animation)
				frames = animation.get("frames", [])
				frame_duration = float(animation.get("frame_duration", 1.0 / 6.0))
				frame_index = int(animation.get("frame_index", 0))
				elapsed = float(animation.get("elapsed", 0.0))
				break
		portrait.texture = frames[frame_index]
		animation["elapsed"] = elapsed
		animation["frame_index"] = frame_index
		animated_portraits[index] = animation

func _sheet_frames(sheet: Texture2D, columns: int, rows: int) -> Array[Texture2D]:
	var frame_count := maxi(1, columns * rows)
	var frame_size := Vector2(floori(sheet.get_width() / float(columns)), floori(sheet.get_height() / float(rows)))
	var frames: Array[Texture2D] = []
	for index in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(index % columns, floori(index / columns)) * frame_size, frame_size)
		frames.append(frame)
	return frames

func _step(ticks: int) -> void:
	combat_ticks += ticks
	for unit in units:
		if unit["dead"]: continue
		var cooldowns: Dictionary = unit.get("cooldowns", {})
		for cooldown_id in cooldowns:
			cooldowns[cooldown_id] = maxi(0, int(cooldowns[cooldown_id]) - ticks)
		unit["cooldowns"] = cooldowns
		var active_statuses: Array = []
		for status in unit.get("statuses", []):
			var status_copy: Dictionary = status
			status_copy["ticks"] = int(status_copy.get("ticks", 0)) - ticks
			if int(status_copy["ticks"]) > 0: active_statuses.append(status_copy)
		unit["statuses"] = active_statuses
		unit["timer"] = int(unit["timer"]) - ticks
		if unit["timer"] > 0: continue
		if unit["side"] == "enemy": _enemy_action(unit)
		elif unit["auto"]: _auto_action(unit)
		else: unit["timer"] = 0
		if finished: return
	_refresh()

func _auto_action(unit: Dictionary) -> void:
	var skill_id := str(unit["skills"][0]) if unit["skills"].size() > 0 else ""
	var hp_ratio := float(unit["hp"]) / float(unit["max_hp"])
	if unit["name"] == "白灵" and hp_ratio < 0.72 and unit["skills"].size() > 0: skill_id = "hui_chun_shu"
	if unit["name"] == "石岩" and hp_ratio > 0.8 and unit["skills"].size() > 1: skill_id = "tiao_xin"
	_resolve_command(unit, skill_id)

func _choose_skill(skill_index: int) -> void:
	if finished: return
	var ready_unit: Dictionary = {}
	for unit in units:
		if unit["side"] == "ally" and not unit["dead"] and not unit["auto"] and int(unit["timer"]) <= 0:
			ready_unit = unit
			break
	if ready_unit.is_empty(): return
	var skills: Array = ready_unit.get("skills", [])
	if skill_index < 0 or skill_index >= skills.size(): return
	var skill_id := str(skills[skill_index])
	var cooldowns: Dictionary = ready_unit.get("cooldowns", {})
	if int(cooldowns.get(skill_id, 0)) > 0:
		_show_log("%s 尚在冷却" % Game.text(KWCombatResolver.skill_by_id(Game.combat_config, skill_id).get("nameKey", skill_id)))
		return
	_resolve_command(ready_unit, skill_id)

func _toggle_auto(unit_id: int) -> void:
	for unit in units:
		if int(unit["unit_id"]) == unit_id:
			unit["auto"] = not unit["auto"]
	_refresh()

func _enemy_action(enemy: Dictionary) -> void:
	var targets := units.filter(func(u): return u["side"] == "ally" and not u["dead"])
	if targets.is_empty(): _finish_defeat(); return
	var target: Dictionary = targets[0]
	var skill := KWCombatResolver.skill_by_id(Game.combat_config, str(enemy["skills"][0]))
	var damage := KWCombatResolver.physical_damage(enemy, target, skill, int(Game.combat_config.get("defenseLevelConstant", 100)))
	_apply_damage(target, damage)
	enemy["timer"] = int(skill.get("baseIntervalTicks", 40))
	_show_log("石傀施放 %s，对 %s 造成 %d 点伤害" % [Game.text(skill.get("nameKey", "石拳")), target["name"], damage])

func _resolve_command(actor: Dictionary, skill_id: String) -> void:
	var skill := KWCombatResolver.skill_by_id(Game.combat_config, skill_id)
	if skill.is_empty(): actor["timer"] = 20; return
	var cooldowns: Dictionary = actor.get("cooldowns", {})
	if int(cooldowns.get(skill_id, 0)) > 0:
		_show_log("%s 尚在冷却" % Game.text(skill.get("nameKey", skill_id)))
		return
	actor["timer"] = int(skill.get("baseIntervalTicks", 20))
	var cooldown_ticks := int(skill.get("cooldownTicks", 0))
	if cooldown_ticks > 0:
		cooldowns[skill_id] = cooldown_ticks
	actor["cooldowns"] = cooldowns
	if skill_id == "hui_chun_shu":
		var allies := units.filter(func(u): return u["side"] == "ally" and not u["dead"])
		if allies.is_empty(): return
		var target: Dictionary = allies[0]
		for candidate in allies:
			if float(candidate["hp"]) / candidate["max_hp"] < float(target["hp"]) / target["max_hp"]: target = candidate
		var amount := KWCombatResolver.heal_amount(actor, target, skill)
		target["hp"] = mini(int(target["max_hp"]), int(target["hp"]) + amount)
		_show_log("%s 使用回春术，%s 恢复 %d 点生命" % [actor["name"], target["name"], amount])
		return
	if skill.get("damageKind", "none") == "none":
		_apply_skill_status(actor, actor, skill)
		_show_log("%s 使用 %s" % [actor["name"], Game.text(skill.get("nameKey", skill_id))])
		return
	var enemies := units.filter(func(u): return u["side"] == "enemy" and not u["dead"])
	if enemies.is_empty(): _finish_victory(); return
	var target: Dictionary = enemies.front()
	if str(skill.get("targetType", "")).contains("LOWEST"):
		for candidate in enemies:
			if candidate["hp"] < target["hp"]: target = candidate
	var damage := KWCombatResolver.physical_damage(actor, target, skill, int(Game.combat_config.get("defenseLevelConstant", 100)))
	_apply_damage(target, damage)
	_apply_skill_status(actor, target, skill)
	# 战斗数值已经结算；Cast A 和命中特效只消费这次结果，不参与判伤或重算。
	_play_shi_yan_cast_a(actor, target)
	_show_log("%s 使用 %s，对 %s 造成 %d 点伤害" % [actor["name"], Game.text(skill.get("nameKey", skill_id)), target["name"], damage])

func _play_shi_yan_cast_a(actor: Dictionary, target: Dictionary) -> void:
	var hero: Dictionary = actor.get("hero", {})
	if str(hero.get("definitionId", "")) != "hero_wu_xiu_01":
		return
	for index in animated_portraits.size():
		var animation: Dictionary = animated_portraits[index]
		if int(animation.get("unit_id", -1)) != int(actor.get("unit_id", -1)):
			continue
		var cast_a_frames: Array = animation.get("cast_a_frames", [])
		var portrait := animation.get("node") as TextureRect
		if portrait == null or cast_a_frames.size() != 8:
			return
		animation["frames"] = cast_a_frames
		animation["frame_duration"] = 1.0 / SHI_YAN_CAST_A_FPS
		animation["elapsed"] = 0.0
		animation["frame_index"] = 0
		animation["loop"] = false
		animation["mode"] = SHI_YAN_CAST_A_MODE
		animation["target_unit_id"] = int(target.get("unit_id", -1))
		animation["hit_frame"] = SHI_YAN_CAST_A_HIT_FRAME
		animation["hit_fired"] = false
		animation["idle_display_position"] = portrait.position
		animation["idle_display_size"] = portrait.size
		var cast_texture_size: Vector2 = cast_a_frames[0].get_size()
		var cast_presentation_scale := SHI_YAN_CAST_A_WIDE_PRESENTATION_SCALE if cast_texture_size.x > 172.0 else 1.0
		var cast_display_size := cast_texture_size / SHI_YAN_HD_TEXTURE_SCALE * cast_presentation_scale
		var portrait_mask := portrait.get_parent() as Control
		var mask_origin := portrait_mask.position if portrait_mask != null else Vector2.ZERO
		var vertical_offset := SHI_YAN_CAST_A_WIDE_VERTICAL_OFFSET if cast_texture_size.x > 172.0 else 0.0
		portrait.position = Vector2((86.0 - cast_display_size.x) * 0.5, vertical_offset) - mask_origin
		portrait.size = cast_display_size
		portrait.texture = cast_a_frames[0]
		portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		animated_portraits[index] = animation
		return

func _restore_portrait_idle(animation: Dictionary) -> Dictionary:
	var idle_frames: Array = animation.get("idle_frames", [])
	if idle_frames.is_empty():
		return animation
	animation["frames"] = idle_frames
	animation["frame_duration"] = float(animation.get("idle_frame_duration", 1.0 / 6.0))
	animation["elapsed"] = 0.0
	animation["frame_index"] = 0
	animation["loop"] = true
	animation["mode"] = PORTRAIT_IDLE_MODE
	var portrait := animation.get("node") as TextureRect
	if portrait != null:
		portrait.position = animation.get("idle_display_position", portrait.position)
		portrait.size = animation.get("idle_display_size", portrait.size)
	animation.erase("idle_display_position")
	animation.erase("idle_display_size")
	animation.erase("target_unit_id")
	animation.erase("hit_frame")
	animation.erase("hit_fired")
	return animation

func _spawn_target_hit_vfx(target_unit_id: int) -> void:
	var host := unit_hosts.get(target_unit_id) as Control
	if host == null or not is_instance_valid(host):
		return
	_clear_target_hit_vfx(target_unit_id)
	var base_position := host.position
	var layer := Control.new()
	layer.name = "CastAHitVfx"
	layer.position = Vector2.ZERO
	layer.size = host.size
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.z_index = 50
	host.add_child(layer)

	# 受击白闪只覆盖敌人剪影，不改血条、名字或战斗状态节点的颜色。
	var flash_body := ColorRect.new()
	flash_body.position = Vector2(12, 41.5)
	flash_body.size = Vector2(62, 84)
	flash_body.color = Color(1.0, 0.98, 0.84, 0.82)
	flash_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(flash_body)
	var flash_head := Polygon2D.new()
	var head_points := PackedVector2Array()
	for point_index in 16:
		var angle := TAU * float(point_index) / 16.0
		head_points.append(Vector2(43, 31.5) + Vector2(cos(angle), sin(angle)) * 22.0)
	flash_head.polygon = head_points
	flash_head.color = Color(1.0, 0.98, 0.84, 0.9)
	layer.add_child(flash_head)

	var burst := Node2D.new()
	burst.position = Vector2(43, 68)
	burst.scale = Vector2(0.68, 0.68)
	layer.add_child(burst)
	var diamond_fill := Polygon2D.new()
	diamond_fill.polygon = PackedVector2Array([
		Vector2(0, -18), Vector2(18, 0), Vector2(0, 18), Vector2(-18, 0),
	])
	diamond_fill.color = Color(1.0, 0.72, 0.22, 0.3)
	burst.add_child(diamond_fill)
	var diamond_line := Line2D.new()
	diamond_line.width = 2.0
	diamond_line.default_color = Color("#ffe295")
	diamond_line.closed = true
	diamond_line.joint_mode = Line2D.LINE_JOINT_SHARP
	diamond_line.points = PackedVector2Array([
		Vector2(0, -18), Vector2(18, 0), Vector2(0, 18), Vector2(-18, 0),
	])
	burst.add_child(diamond_line)
	for ray_index in 8:
		var angle := TAU * float(ray_index) / 8.0
		var ray := Line2D.new()
		ray.width = 2.0
		ray.default_color = Color("#f3bd4d")
		ray.points = PackedVector2Array([
			Vector2(cos(angle), sin(angle)) * 24.0,
			Vector2(cos(angle), sin(angle)) * 37.0,
		])
		burst.add_child(ray)

	active_target_hit_vfx[target_unit_id] = {
		"node": layer,
		"host": host,
		"base_position": base_position,
	}
	shi_yan_cast_a_hit_count += 1

	var shake := create_tween()
	shake.tween_property(host, "position:x", base_position.x + 2.0, 0.03)
	shake.tween_property(host, "position:x", base_position.x - 2.0, 0.04)
	shake.tween_property(host, "position:x", base_position.x + 1.0, 0.03)
	shake.tween_property(host, "position:x", base_position.x, 0.04)
	var effect_tween := create_tween().set_parallel(true)
	effect_tween.tween_property(burst, "scale", Vector2(1.22, 1.22), TARGET_HIT_VFX_DURATION)
	effect_tween.tween_property(layer, "modulate:a", 0.0, TARGET_HIT_VFX_DURATION).set_delay(0.04)
	effect_tween.finished.connect(_finish_target_hit_vfx.bind(target_unit_id, layer))

func _finish_target_hit_vfx(target_unit_id: int, expected_layer: Control) -> void:
	var active: Dictionary = active_target_hit_vfx.get(target_unit_id, {})
	if active.get("node") != expected_layer:
		return
	_clear_target_hit_vfx(target_unit_id)

func _clear_target_hit_vfx(target_unit_id: int) -> void:
	var active: Dictionary = active_target_hit_vfx.get(target_unit_id, {})
	if active.is_empty():
		return
	var host := active.get("host") as Control
	if host != null and is_instance_valid(host):
		host.position = active.get("base_position", host.position)
	var layer := active.get("node") as Control
	if layer != null and is_instance_valid(layer):
		layer.queue_free()
	active_target_hit_vfx.erase(target_unit_id)

func _apply_skill_status(actor: Dictionary, target: Dictionary, skill: Dictionary) -> void:
	var status_definition: Dictionary = skill.get("appliesStatus", {})
	if status_definition.is_empty(): return
	var status_kind := str(status_definition.get("kind", ""))
	var recipient := actor
	if str(skill.get("targetType", "")).contains("ALLY_LOWEST"):
		var allies := units.filter(func(u): return u["side"] == "ally" and not u["dead"])
		if not allies.is_empty():
			recipient = allies[0]
			for candidate in allies:
				if float(candidate["hp"]) / candidate["max_hp"] < float(recipient["hp"]) / recipient["max_hp"]: recipient = candidate
	elif str(skill.get("targetType", "")).contains("ENEMY"):
		recipient = target
	if status_kind == "shield": recipient["shield"] = int(recipient.get("shield", 0)) + int(status_definition.get("magnitude", 0))
	var status_label: String = str({"gather_spirit": "引", "shield": "护", "stun": "晕", "haste": "迅", "purify": "净"}.get(status_kind, status_kind))
	var statuses: Array = recipient.get("statuses", [])
	statuses.append({"kind": str(status_label), "ticks": int(status_definition.get("durationTicks", 20))})
	recipient["statuses"] = statuses

func _apply_damage(target: Dictionary, damage: int) -> void:
	var absorbed := mini(int(target.get("shield", 0)), damage)
	target["shield"] = int(target.get("shield", 0)) - absorbed
	target["hp"] = maxi(0, int(target["hp"]) - damage + absorbed)
	if target["hp"] <= 0:
		target["dead"] = true
		_show_log("%s 倒下了" % target["name"])
		if target["side"] == "enemy": _finish_victory()
		elif units.filter(func(u): return u["side"] == "ally" and not u["dead"]).is_empty(): _finish_defeat()

func _refresh() -> void:
	escape_button.visible = not finished and _escape_available()
	KWUI.set_combat_button_disabled(escape_button, finished)
	if is_instance_valid(tick_label): tick_label.text = "战斗 %.1f 秒" % (float(combat_ticks) / 20.0)
	for unit in units:
		var host: Panel = unit_hosts.get(int(unit["unit_id"]))
		if not is_instance_valid(host): continue
		var bar: ProgressBar = host.get_node_or_null("Hp")
		var hp_value: Label = host.get_node_or_null("HpValue")
		var action: ProgressBar = host.get_node_or_null("Action")
		var status: Label = host.get_node_or_null("Status")
		if bar: bar.value = float(unit["hp"]) / float(unit["max_hp"]) * 100.0
		if hp_value: hp_value.text = "%d/%d" % [int(unit["hp"]), int(unit["max_hp"])]
		if action:
			var action_max := maxi(1, int(unit.get("action_max", unit["timer"])))
			action.value = clampf(float(action_max - int(unit["timer"])) / float(action_max) * 100.0, 0.0, 100.0)
		if status:
			var status_parts: Array[String] = []
			for active_status in unit.get("statuses", []).slice(0, 3): status_parts.append("[%s]" % str(active_status.get("kind", "")))
			status.text = "".join(status_parts)
		host.modulate = Color(1, 1, 1, 0.34) if bool(unit.get("dead", false)) else Color.WHITE
		if unit["side"] == "ally":
			var name_label: Button = host.get_node_or_null("Name")
			if name_label:
				name_label.text = "%s · 阵亡" % unit["name"] if bool(unit.get("dead", false)) else "%s · %s" % [unit["name"], "自" if unit["auto"] else "手"]
	if is_instance_valid(log_label): log_label.text = log_lines.back() if not log_lines.is_empty() else ""
	_refresh_skill_panel()
	var enemy_unit: Dictionary = {}
	for candidate in units:
		if candidate["side"] == "enemy":
			enemy_unit = candidate
			break
	var enemy_host: Panel = unit_hosts.get(100)
	if enemy_host and not enemy_unit.is_empty():
		var enemy_bar: ProgressBar = enemy_host.get_node_or_null("Hp")
		var enemy_hp_value: Label = enemy_host.get_node_or_null("HpValue")
		var enemy_action: ProgressBar = enemy_host.get_node_or_null("Action")
		if enemy_bar: enemy_bar.value = float(enemy_unit["hp"]) / float(enemy_unit["max_hp"]) * 100.0
		if enemy_hp_value: enemy_hp_value.text = "%d/%d" % [int(enemy_unit["hp"]), int(enemy_unit["max_hp"])]
		if enemy_action:
			var enemy_max := maxi(1, int(enemy_unit.get("action_max", enemy_unit["timer"])))
			enemy_action.value = clampf(float(enemy_max - int(enemy_unit["timer"])) / float(enemy_max) * 100.0, 0.0, 100.0)

func _refresh_skill_panel() -> void:
	if not is_instance_valid(skill_panel): return
	var ready: Dictionary = {}
	for unit in units:
		if unit["side"] == "ally" and not unit["dead"] and not unit["auto"] and int(unit["timer"]) <= 0:
			ready = unit
			break
	if ready.is_empty() or finished:
		skill_panel.visible = false
		return
	skill_panel.visible = true
	var skills: Array = ready.get("skills", [])
	var cooldowns: Dictionary = ready.get("cooldowns", {})
	for index in skill_buttons.size():
		var button: Button = skill_buttons[index]
		if index >= skills.size():
			button.visible = false
			continue
		button.visible = true
		var skill_id := str(skills[index])
		var definition := KWCombatResolver.skill_by_id(Game.combat_config, skill_id)
		var cooldown := int(cooldowns.get(skill_id, 0))
		button.text = "%s\n冷却" % Game.text(definition.get("nameKey", skill_id)) if cooldown > 0 else Game.text(definition.get("nameKey", skill_id))
		KWUI.set_combat_button_disabled(button, cooldown > 0)

func _escape_available() -> bool:
	var escape_percent := int(current_encounter.get("escapeEnemyHpPercent", 35))
	for unit in units:
		if unit["side"] == "enemy":
			return int(unit["hp"]) * 100 <= int(unit["max_hp"]) * escape_percent
	return false

func _finish_victory() -> void:
	if finished: return
	finished = true
	for unit in units:
		if unit["side"] == "ally":
			unit["hero"]["currentHp"] = int(unit["hp"])
	var completion_key := Game.map_object_key(Game.get_active_map_id(), Game.get_active_map_object_id())
	var already: bool = bool(Game.profile.get("completedMapObjects", {}).get(completion_key, false))
	if not already:
		Game.profile["completedMapObjects"][completion_key] = true
		var soul_reward := int(current_encounter.get("soulCrystalReward", 0))
		Game.profile["wallet"]["soulCrystal"] = int(Game.profile["wallet"].get("soulCrystal", 0)) + soul_reward
	Game.save_profile()
	_show_loot_overlay()

func _finish_defeat() -> void:
	if finished: return
	finished = true
	Game._finish_expedition(true)
	_show_outcome(false)

func _show_outcome(victory: bool) -> void:
	_refresh()
	KWUI.label(outcome_panel, "战斗胜利" if victory else "全队阵亡", Rect2(15, 29, 295, 38), 24, KWUI.GOLD if victory else KWUI.RED, HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(outcome_panel, "战斗已结束，战利品正在结算" if victory else "本次入山队伍失去战斗能力。\n修士将进入还魂殿待处理。", Rect2(25, 75, 275, 60), 13, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var next := KWUI.combat_button(outcome_panel, "返回地图" if victory else "返回营地", Rect2(53, 166, 219, 48), 15)
	next.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map.tscn" if victory else "res://scenes/camp.tscn"))
	outcome_overlay.visible = true

func _show_loot_overlay() -> void:
	if not is_instance_valid(loot_overlay): return
	loot_overlay.visible = true
	var burden := _current_expedition_burden()
	var limit := _burden_limit()
	loot_burden_label.text = "当前负重 %d/%d" % [burden, limit]
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var entries: Array = []
	for item_id in expedition.get("temporaryLoot", {}):
		var amount := int(expedition["temporaryLoot"][item_id])
		if amount > 0: entries.append([str(item_id), amount])
	for index in loot_backpack_buttons.size():
		var button: Button = loot_backpack_buttons[index]
		button.visible = index < entries.size()
		if index < entries.size():
			var entry: Array = entries[index]
			button.text = "  %s ×%d    单重 %d" % [Game.text("item." + str(entry[0]), str(entry[0])), int(entry[1]), _loot_weight(str(entry[0]))]
	for label in loot_reward_labels:
		label.visible = false
	var reward_index := 0
	var soul_reward := int(current_encounter.get("soulCrystalReward", 0))
	if reward_index < loot_reward_labels.size():
		loot_reward_labels[reward_index].text = "魂晶 +%d（已获得）" % soul_reward
		loot_reward_labels[reward_index].visible = true
		reward_index += 1
	for reward in current_encounter.get("loot", []):
		if reward_index >= loot_reward_labels.size(): break
		loot_reward_labels[reward_index].text = "%s ×%d    重量 %d" % [Game.text(str(reward.get("nameKey", reward.get("itemId", "战利品"))), str(reward.get("itemId", "战利品"))), int(reward.get("amount", 1)), int(reward.get("amount", 1)) * _loot_weight(str(reward.get("itemId", "")))]
		loot_reward_labels[reward_index].visible = true
		reward_index += 1
	var reward_weight := 0
	for reward in current_encounter.get("loot", []): reward_weight += int(reward.get("amount", 1)) * _loot_weight(str(reward.get("itemId", "")))
	loot_status_label.text = "全部拾取后：%d/%d" % [burden + reward_weight, limit]
	loot_status_label.add_theme_color_override("font_color", Color("#a8c2a6") if burden + reward_weight <= limit else Color("#eb8b6f"))
	KWUI.set_combat_button_disabled(loot_take_all_button, burden + reward_weight > limit)

func _take_all_loot() -> void:
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var loot: Dictionary = expedition.get("temporaryLoot", {})
	for reward in current_encounter.get("loot", []):
		var item_id := str(reward.get("itemId", ""))
		loot[item_id] = int(loot.get(item_id, 0)) + int(reward.get("amount", 1))
	expedition["temporaryLoot"] = loot
	Game.save_profile()
	_leave_loot()

func _leave_loot() -> void:
	loot_overlay.visible = false
	Game.clear_active_encounter()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _drop_loot_item(index: int) -> void:
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var entries: Array = []
	for item_id in expedition.get("temporaryLoot", {}):
		var amount := int(expedition["temporaryLoot"][item_id])
		if amount > 0: entries.append([str(item_id), amount])
	if index < 0 or index >= entries.size(): return
	var item_id := str(entries[index][0])
	var loot: Dictionary = expedition.get("temporaryLoot", {})
	if int(loot.get(item_id, 0)) <= 1: loot.erase(item_id)
	else: loot[item_id] = int(loot[item_id]) - 1
	expedition["temporaryLoot"] = loot
	Game.save_profile()
	_show_loot_overlay()

func _loot_weight(item_id: String) -> int:
	return Game.item_weight(item_id)

func _current_expedition_burden() -> int:
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var burden := int(expedition.get("remainingGrain", 0))
	for item_id in expedition.get("carriedItems", {}): burden += int(expedition["carriedItems"][item_id]) * _loot_weight(str(item_id))
	for item_id in expedition.get("temporaryLoot", {}): burden += int(expedition["temporaryLoot"][item_id]) * _loot_weight(str(item_id))
	return burden

func _burden_limit() -> int:
	return Game.expedition_burden_limit(Game.party_heroes())

func _escape() -> void:
	if finished: return
	if not _escape_available():
		_show_log("敌方生命未低于 %d%%，暂时无法撤离" % int(current_encounter.get("escapeEnemyHpPercent", 35)))
		return
	for unit in units:
		if unit["side"] == "ally": unit["hero"]["currentHp"] = int(unit["hp"])
	Game.clear_active_encounter()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _give_up() -> void:
	if finished: return
	for unit in units:
		if unit["side"] == "ally": unit["hero"]["currentHp"] = int(unit["hp"])
	Game.clear_active_encounter()
	get_tree().change_scene_to_file("res://scenes/map.tscn")

func _show_log(message: String) -> void:
	log_lines.append(message)
	if log_lines.size() > 12: log_lines.pop_front()
	if is_instance_valid(log_label): log_label.text = message

func _add_combat_polygon(points: PackedVector2Array, color: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.polygon = points
	polygon.color = color
	add_child(polygon)
	move_child(polygon, 1)

func _add_enemy_silhouette(parent: Control) -> void:
	# 对应 CombatUnitView.drawEnemySilhouette：头部圆形、厚重躯干和一条残禁刻线。
	var head := Polygon2D.new()
	var head_points := PackedVector2Array()
	for index in 16:
		var angle := TAU * float(index) / 16.0
		head_points.append(Vector2(43, 31.5) + Vector2(cos(angle), sin(angle)) * 22.0)
	head.polygon = head_points
	head.color = Color("#4a4f4d")
	parent.add_child(head)
	var body := Panel.new()
	body.position = Vector2(12, 41.5)
	body.size = Vector2(62, 84)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_stylebox_override("panel", KWUI.style_box(Color("#4a4f4d"), Color.TRANSPARENT, 10, 0))
	parent.add_child(body)
	var seal := Line2D.new()
	seal.width = 2.0
	seal.default_color = Color("#ae523c")
	seal.points = PackedVector2Array([Vector2(25, 50), Vector2(61, 40)])
	parent.add_child(seal)

func _combat_progress(parent: Control, node_name: String, position: Vector2, track_color: Color, fill_color: Color, size: Vector2) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.name = node_name
	progress.position = position
	progress.size = size
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_theme_stylebox_override("background", KWUI.style_box(track_color, Color("#7d7a62"), 1, 1))
	progress.add_theme_stylebox_override("fill", KWUI.style_box(fill_color, Color.TRANSPARENT, 1, 0))
	parent.add_child(progress)
	return progress
