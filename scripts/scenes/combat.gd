extends Control

const HERO_ANIMATION_FRAME_SIZE := Vector2i(172, 298)
const HERO_ANIMATION_SHEET_SIZE := Vector2i(688, 1192)
const HERO_ANIMATION_COLUMNS := 4
const HERO_ANIMATION_ROWS := 4
const HERO_ANIMATION_FRAME_COUNT := HERO_ANIMATION_COLUMNS * HERO_ANIMATION_ROWS
const HERO_ANIMATION_FPS := 8.0
const HERO_ANIMATION_ACTION_HIT_FRAME := 8
const HERO_ANIMATION_MODE := "hero_action"
const HERO_ANIMATION_SHEETS := {
	"shi_yan": {"idle": "shi_yan_idle_sheet.png", "attack": "shi_yan_attack_sheet.png", "defense": "shi_yan_defense_sheet.png"},
	"lu_qing": {"idle": "lu_qing_idle_sheet.png", "attack": "lu_qing_attack_sheet.png", "heal": "lu_qing_heal_sheet.png", "lei_ji": "lu_qing_lei_ji_sheet.png"},
	"bai_ling": {"idle": "bai_ling_idle_sheet.png", "attack": "bai_ling_attack_sheet.png", "heal": "bai_ling_heal_sheet.png"},
	"mo_yan": {"idle": "mo_yan_idle_sheet.png", "fei_jian": "mo_yan_fei_jian_sheet.png", "hui_jian": "mo_yan_hui_jian_sheet.png"},
}
const PORTRAIT_IDLE_MODE := "idle"
const TARGET_HIT_VFX_DURATION := 0.22
const HERO_CANVAS_WIDTH := 375.0 / 4.0
const HERO_CARD_SIZE := Vector2(HERO_CANVAS_WIDTH, 205)
const HERO_CARD_START := Vector2(0, 492)
const HERO_CARD_STEP_X := HERO_CANVAS_WIDTH
const HERO_INFO_POSITION := Vector2(0, 149)
const HERO_INFO_SIZE := Vector2(HERO_CANVAS_WIDTH, 56)
# 信息层控件到 y=205；人物画布视觉底边按当前战斗页微调到 y=190，
# 避免绿色调试底压住姓名栏下沿。
const HERO_PORTRAIT_VISUAL_BOTTOM := HERO_INFO_POSITION.y + 41.0
# 四张人物画布横向铺满 375px；纵向统一以人物画布底边对齐卡片与
# 信息面板的可见底边，不再把下方透明留白当作面板内容。
const HERO_ANIMATION_DISPLAY_SIZE := Vector2(HERO_CANVAS_WIDTH, 149)
# 白灵序列帧的透明留白较多，保持同一画布后视觉主体会偏小；仅放大主体，
# 不改变四列画布的宽度和位置契约。
const HERO_PORTRAIT_SCALES := {"bai_ling": 1.08}
const HERO_NAME_AUTO_COLOR := Color("#be883a")
const HERO_NAME_MANUAL_COLOR := Color("#e8dcbb")
const SKILL_PICKER_POSITION := Vector2(117.5, 491)
const SKILL_PICKER_SIZE := Vector2(140, 46)
const SKILL_ITEM_SIZE := Vector2(40, 46)
const SKILL_ITEM_STEP_X := 50.0
const SKILL_ICON_SIZE := Vector2(24, 24)
const SKILL_ICON_POSITION := Vector2(8, 11)
const SKILL_COLOR_PRIMARY := Color("#e8dcbb")
const SKILL_COLOR_SECONDARY := Color("#91a49e")
const SKILL_COLOR_DAMAGE := Color("#b94a3e")
const SKILL_COLOR_SELECTED := Color("#be883a")
const SKILL_COLOR_SURFACE := Color("#202a27")
const SKILL_COLOR_BORDER := Color("#80623a")
const FIGMA_ENEMY_PORTRAIT_PATH := "res://assets/units/enemies/portrait_can_jin_shi_kui.png"
const FIGMA_ENEMY_PORTRAIT_POSITION := Vector2(-12, 34)
const FIGMA_ENEMY_PORTRAIT_SIZE := Vector2(110, 165)
const FIGMA_ENEMY_CARD_Y := 180.0

var units: Array = []
var log_lines: Array[String] = []
var log_label: Label
var tick_label: Label
var unit_hosts: Dictionary = {}
var timer_accum := 0.0
var combat_ticks := 0
var finished := false
var skill_panel: Control
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
var pause_button: Button
var pause_overlay: Control
var combat_paused := false
var active_presentation_tweens: Array[Tween] = []
var animated_portraits: Array[Dictionary] = []
var active_target_hit_vfx: Dictionary = {}
var shi_yan_cast_a_hit_count := 0
var current_encounter: Dictionary = {}
var victory_result: Dictionary = {}

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
	_change_scene_after_combat("res://scenes/map.tscn")

func _build_units() -> void:
	var heroes: Array = Game.party_heroes()
	var timers: Array = Game.combat_config.get("partyInitialActionTimers", [30, 40, 50, 60])
	for index in heroes.size():
		var hero: Dictionary = heroes[index]
		var initial_timer := int(timers[index] if index < timers.size() else 30)
		var hero_hp := int(hero.get("currentHp", hero.get("maxHp", 1)))
		var hero_dead := bool(hero.get("isDead", false)) or hero_hp <= 0
		units.append({"unit_id": index + 1, "name": Game.text(str(hero.get("nameKey", "")), str(hero.get("name", "修士"))), "side": "ally", "hero": hero, "hp": maxi(0, hero_hp), "max_hp": int(hero.get("maxHp", 1)), "attrs": hero.get("attributes", {}), "skills": hero.get("skillIds", []), "timer": initial_timer, "action_max": initial_timer, "auto": true, "dead": hero_dead, "shield": 0, "cooldowns": {}, "statuses": []})
	for enemy_index in current_encounter.get("enemies", []).size():
		var enemy: Dictionary = current_encounter.get("enemies", [])[enemy_index]
		var enemy_timer := int(enemy.get("initialActionTimer", 45))
		units.append({
			"unit_id": 100 + enemy_index,
			"name": Game.text(str(enemy.get("nameKey", "")), str(enemy.get("name", "敌人"))),
			"side": "enemy", "enemy": enemy,
			"hp": int(enemy.get("maxHp", 1)), "max_hp": int(enemy.get("maxHp", 1)),
			"attrs": enemy.get("attributes", {}).duplicate(true), "skills": enemy.get("skillIds", []).duplicate(),
			"timer": enemy_timer, "action_max": enemy_timer, "auto": true, "dead": false,
			"shield": 0, "cooldowns": {}, "statuses": [], "ai_index": 0,
			"mechanics": enemy.get("mechanics", {}).duplicate(true), "physical_hit_count": 0,
			"forced_shields_used": [], "next_periodic_tick": int(enemy.get("mechanics", {}).get("periodicShield", {}).get("intervalTicks", 0)),
		})

func _build_scene() -> void:
	# Figma 战斗主稿是 375×817 的竖屏画布：背景图铺满，所有战斗信息
	# 作为覆盖层压在立绘底部。背景与 HD 修士动效使用 linear，几何 UI
	# 保持无纹理缩放，避免改变文字、边框和血条的像素对齐。
	var bg := ColorRect.new()
	bg.color = Color("#071016")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var background := TextureRect.new()
	background.name = "CombatBackground"
	background.position = Vector2.ZERO
	background.size = Vector2(375, 817)
	background.texture = load("res://assets/maps/map_01/map01_background.png")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.modulate = Color(0.88, 0.93, 0.92, 1.0)
	add_child(background)
	var background_shade := ColorRect.new()
	background_shade.color = Color("#07101626")
	background_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background_shade)
	_add_status_bar()
	# 逃生只在敌方生命低于阈值后出现；默认态保持 Figma 的干净顶部。
	var flee := KWUI.combat_button(self, "撤离", Rect2(230, 27, 64, 32), 11)
	flee.pressed.connect(_escape)
	flee.visible = false
	escape_button = flee
	var pause := KWUI.combat_button(self, "暂停", Rect2(300, 27, 64, 32), 11)
	pause.name = "PauseButton"
	pause.process_mode = Node.PROCESS_MODE_ALWAYS
	pause.z_index = 230
	pause.pressed.connect(_toggle_combat_pause)
	pause_button = pause
	var enemy_units := units.filter(func(unit): return unit.get("side") == "enemy")
	var enemy_card_width := 86.0
	var enemy_gap := 8.0
	var enemy_total_width := enemy_units.size() * enemy_card_width + maxi(0, enemy_units.size() - 1) * enemy_gap
	var enemy_start_x := (375.0 - enemy_total_width) * 0.5
	for enemy_index in enemy_units.size():
		_build_enemy_card(enemy_units[enemy_index], Vector2(enemy_start_x + enemy_index * (enemy_card_width + enemy_gap), FIGMA_ENEMY_CARD_Y), enemy_card_width)
	# 四张修士卡片横向铺满 375px，每张宽度为 375 / 4 = 93.75px。
	for index in 4:
		var host := Panel.new()
		host.name = "HeroCard_%d" % (index + 1)
		host.position = HERO_CARD_START + Vector2(index * HERO_CARD_STEP_X, 0)
		host.size = HERO_CARD_SIZE
		host.add_theme_stylebox_override("panel", KWUI.style_box(Color("#11191700"), Color.TRANSPARENT, 0, 0))
		add_child(host)
		# 三种动作共用一张固定 172×298 @2x 画布，运行时显示为 93.75×149；
		# 卡牌式战斗只允许原地表演，不通过扩大画布制造位移。
		host.clip_contents = true
		unit_hosts[index + 1] = host
		var portrait_path: String = str(["shi_yan", "lu_qing", "bai_ling", "mo_yan"][index])
		var portrait_mask := Control.new()
		portrait_mask.name = "PortraitMask"
		# 立绘裁切区覆盖整张卡片；人物画布位于信息面板后方，信息层负责
		# 覆盖人物底部的重叠部分。
		portrait_mask.position = Vector2.ZERO
		portrait_mask.size = HERO_CARD_SIZE
		portrait_mask.clip_contents = true
		portrait_mask.mouse_filter = Control.MOUSE_FILTER_IGNORE
		host.add_child(portrait_mask)
		var portrait_display_position := _hero_portrait_display_position(portrait_path)
		var portrait_display_size := _hero_portrait_display_size(portrait_path)
		# 临时视觉标记：绿色区域表示人物序列帧的实际显示画布，
		# 用于确认人物位置、裁切边界和脚底对齐。
		var canvas_debug_background := ColorRect.new()
		canvas_debug_background.name = "PortraitCanvasDebug"
		canvas_debug_background.position = portrait_display_position
		canvas_debug_background.size = portrait_display_size
		canvas_debug_background.color = Color("#32b76866")
		canvas_debug_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait_mask.add_child(canvas_debug_background)
		var portrait := KWUI.texture(portrait_mask, "res://assets/camp/ui/expedition/portrait_hero_%s_expedition.png" % portrait_path, Rect2(portrait_display_position, portrait_display_size))
		var idle_frames := _load_hero_animation_frames(portrait_path, "idle")
		if not idle_frames.is_empty():
			portrait.texture = idle_frames[0]
			portrait.position = portrait_display_position
			portrait.size = portrait_display_size
			portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			var action_frames: Dictionary = {}
			for action_name in _hero_action_names(portrait_path):
				var frames := _load_hero_animation_frames(portrait_path, action_name)
				if not frames.is_empty():
					action_frames[action_name] = frames
			animated_portraits.append({
				"node": portrait,
				"unit_id": index + 1,
				"frames": idle_frames,
				"idle_frames": idle_frames,
				"action_frames": action_frames,
				"idle_frame_duration": 1.0 / HERO_ANIMATION_FPS,
				"frame_duration": 1.0 / HERO_ANIMATION_FPS,
				"elapsed": 0.0,
				"frame_index": 0,
				"loop": true,
				"mode": PORTRAIT_IDLE_MODE,
			})
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_build_unit_info(host, units[index].get("hero", {}), index + 1, true)
		# 保留前景层级，使序列帧始终位于修士框内容之下；同时兼容现有动画验证。
		var frame_overlay := Panel.new()
		frame_overlay.name = "FrameOverlay"
		frame_overlay.position = Vector2.ZERO
		frame_overlay.size = HERO_CARD_SIZE
		frame_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame_overlay.z_index = 130
		frame_overlay.add_theme_stylebox_override("panel", KWUI.style_box(Color.TRANSPARENT, Color.TRANSPARENT, 0, 0))
		host.add_child(frame_overlay)
	_build_skill_picker()
	log_label = KWUI.label(self, "", Rect2(35, 395, 305, 28), 11, Color("#d4d9c6"), HORIZONTAL_ALIGNMENT_CENTER)
	# 安全区位于所有卡片之上，主页指示条也与 Figma 手机稿一致。
	var safe_area := ColorRect.new()
	safe_area.name = "BottomSafeArea"
	safe_area.position = Vector2(0, 763)
	safe_area.size = Vector2(375, 54)
	safe_area.color = Color("#071016f2")
	safe_area.mouse_filter = Control.MOUSE_FILTER_STOP
	safe_area.z_index = 240
	add_child(safe_area)
	var home_indicator := ColorRect.new()
	home_indicator.position = Vector2(127, 795)
	home_indicator.size = Vector2(121, 4)
	home_indicator.color = Color("#d1d2c5b8")
	home_indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	safe_area.add_child(home_indicator)
	_build_pause_overlay()
	outcome_overlay = Control.new()
	outcome_overlay.z_index = 300
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
	# Godot 的 Control 命中顺序还受场景树顺序影响。暂停遮罩覆盖全屏，
	# 因此把暂停按钮移到最后，确保暂停后“继续”不会被遮罩抢走点击。
	move_child(pause_button, get_child_count() - 1)

func _build_skill_picker() -> void:
	# Figma 358:1393：技能选择是一条 140×46 的透明浮层，不使用旧版
	# 大面板、标题或人物选中框。三个技能项各 40×46，水平间隔 10px。
	skill_panel = Control.new()
	skill_panel.name = "SkillPicker"
	skill_panel.position = SKILL_PICKER_POSITION
	skill_panel.size = SKILL_PICKER_SIZE
	skill_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	skill_panel.z_index = 160
	skill_panel.visible = false
	add_child(skill_panel)

	var empty_style := StyleBoxEmpty.new()
	for index in 3:
		var item := Button.new()
		item.name = "SkillItem%d" % (index + 1)
		item.position = Vector2(index * SKILL_ITEM_STEP_X, 0)
		item.size = SKILL_ITEM_SIZE
		item.text = ""
		item.focus_mode = Control.FOCUS_NONE
		item.clip_contents = false
		for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			item.add_theme_stylebox_override(state, empty_style)
		item.pressed.connect(_choose_skill.bind(index))
		skill_panel.add_child(item)
		skill_buttons.append(item)

		var skill_name := _skill_picker_label(item, "Name", Rect2(0, 0, 40, 10), 7)
		skill_name.add_theme_color_override("font_color", SKILL_COLOR_PRIMARY)

		# StyleBoxFlat 没有模糊滤镜，用比图标外扩 2px 的半透明描边表达
		# Figma 的 3px 金色辉光；仅当前可用的默认技能显示。
		var glow := Panel.new()
		glow.name = "Glow"
		glow.position = SKILL_ICON_POSITION - Vector2(2, 2)
		glow.size = SKILL_ICON_SIZE + Vector2(4, 4)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.add_theme_stylebox_override("panel", _micro_style_box(Color.TRANSPARENT, Color("#be883a9e"), 1, 3))
		glow.visible = false
		item.add_child(glow)

		var icon := Panel.new()
		icon.name = "Icon"
		icon.position = SKILL_ICON_POSITION
		icon.size = SKILL_ICON_SIZE
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.add_theme_stylebox_override("panel", _micro_style_box(SKILL_COLOR_SURFACE, SKILL_COLOR_BORDER, 1, 2))
		item.add_child(icon)
		var glyph := _skill_picker_label(icon, "Glyph", Rect2(Vector2.ZERO, SKILL_ICON_SIZE), 11)
		glyph.add_theme_color_override("font_color", SKILL_COLOR_PRIMARY)

		var effect := _skill_picker_label(item, "Effect", Rect2(0, 37, 40, 9), 7)
		effect.add_theme_color_override("font_color", SKILL_COLOR_SECONDARY)

func _skill_picker_label(parent: Control, node_name: String, rect: Rect2, font_size: int) -> Label:
	# 当前像素字体的固有行高为 23px。用固定 Figma 尺寸的裁切容器承载
	# 文本，避免 Label 最小尺寸把 9–10px 的名称/效果区域撑大。
	var clip := Control.new()
	clip.name = node_name
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(clip)
	var label_height := maxf(23.0, rect.size.y)
	var label := KWUI.label(clip, "", Rect2(0, (rect.size.y - label_height) * 0.5, rect.size.x, label_height), font_size, SKILL_COLOR_PRIMARY, HORIZONTAL_ALIGNMENT_CENTER)
	label.name = "Text"
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	label.add_theme_constant_override("shadow_offset_x", 0)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label

func _skill_glyph(skill_id: String, skill_name: String) -> String:
	var glyphs := {
		"zhan_ji": "斩", "tiao_xin": "引", "chong_zhuang": "撞",
		"ling_huo_dan": "火", "ning_shuang_hu": "护", "ling_neng_zhen_dang": "雷",
		"hui_chun_shu": "愈", "qing_xin_jue": "净", "ling_guang_ji": "光",
		"ying_xi": "影", "tou_ren": "刃", "yan_dun": "遁",
	}
	if glyphs.has(skill_id):
		return str(glyphs[skill_id])
	return skill_name.substr(0, 1) if not skill_name.is_empty() else "技"

func _skill_effect_text(definition: Dictionary) -> String:
	var percent := int(definition.get("primaryPercent", 0))
	if percent > 0:
		return "%d%%" % percent
	var status_kind := str(definition.get("appliesStatus", {}).get("kind", ""))
	var status_labels := {
		"gather_spirit": "引敌",
		"shield": "护盾",
		"purify": "净化",
		"haste": "加速",
		"stun": "眩晕",
	}
	return str(status_labels.get(status_kind, "辅助"))

func _skill_effect_color(definition: Dictionary) -> Color:
	return SKILL_COLOR_DAMAGE if str(definition.get("damageKind", "none")) != "none" else SKILL_COLOR_SECONDARY

func _apply_skill_item_state(item: Button, selected: bool, disabled: bool) -> void:
	item.modulate = Color(1, 1, 1, 0.48) if disabled else Color.WHITE
	var glow := item.get_node_or_null("Glow") as Panel
	if glow != null:
		glow.visible = selected and not disabled
	var icon := item.get_node_or_null("Icon") as Panel
	if icon == null:
		return
	var border_color := SKILL_COLOR_SELECTED if selected and not disabled else SKILL_COLOR_BORDER
	var border_width := 2 if selected and not disabled else 1
	icon.add_theme_stylebox_override("panel", _micro_style_box(SKILL_COLOR_SURFACE, border_color, border_width, 2))
	var glyph := icon.get_node_or_null("Glyph/Text") as Label
	if glyph != null:
		glyph.add_theme_color_override("font_color", SKILL_COLOR_SELECTED if selected and not disabled else SKILL_COLOR_PRIMARY)

func _build_unit_info(host: Control, unit_data: Dictionary, unit_id: int, is_ally: bool) -> void:
	# Figma 333:1382 / 334:1384：敌我使用同一组透明信息覆盖层，
	# 仅通过名称颜色和运行时数据表达阵营差异。
	var info := Control.new()
	info.name = "InfoOverlay"
	info.position = HERO_INFO_POSITION
	var info_width := host.size.x
	info.size = Vector2(info_width, HERO_INFO_SIZE.y)
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var progress_width := info_width - 6.0
	host.add_child(info)

	_add_gradient_frame(
		info,
		"Hp",
		Rect2(0, 15, info_width, 10),
		PackedColorArray([Color("#242117"), Color("#10120e"), Color("#070907")]),
		PackedFloat32Array([0.0, 0.42, 1.0]),
		Color("#9a7542")
	)
	var hp := _micro_progress(info, "Hp", Rect2(3, 18, progress_width, 5), Color("#b94a3e"))
	hp.z_index = 1
	var hp_value := Control.new()
	hp_value.name = "HpValue"
	hp_value.position = Vector2(3, 14)
	hp_value.size = Vector2(progress_width, 10)
	hp_value.clip_contents = true
	hp_value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_value.z_index = 3
	info.add_child(hp_value)
	var hp_text := KWUI.label(hp_value, "", Rect2(0, -6, progress_width, 23), 7, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	hp_text.name = "Text"
	hp_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	hp_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_text.add_theme_color_override("font_shadow_color", Color("#000000e6"))
	hp_text.add_theme_constant_override("shadow_offset_x", 0)
	hp_text.add_theme_constant_override("shadow_offset_y", 1)
	hp_text.add_theme_constant_override("shadow_outline_size", 1)

	_add_gradient_frame(
		info,
		"Action",
		Rect2(0, 28, info_width, 6),
		PackedColorArray([Color("#182522"), Color("#0c1514"), Color("#060a0a")]),
		PackedFloat32Array([0.0, 0.46, 1.0]),
		Color("#5d877d")
	)
	var action := _micro_progress(info, "Action", Rect2(3, 30, progress_width, 3), Color("#58b9b4"))
	action.z_index = 1

	var race_frame := Panel.new()
	race_frame.name = "RaceFrame"
	race_frame.position = Vector2(0, 14)
	race_frame.size = Vector2(12, 12)
	race_frame.clip_contents = true
	race_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	race_frame.z_index = 5
	race_frame.add_theme_stylebox_override("panel", _micro_style_box(Color("#202a27"), Color("#3f5f59"), 1, 0))
	info.add_child(race_frame)
	var race_fallback := "人" if is_ally else "傀"
	var race_key_fallback := "race.human" if is_ally else "race.puppet"
	var race_text := Game.text(str(unit_data.get("raceKey", race_key_fallback)), race_fallback)
	var race := KWUI.label(race_frame, race_text, Rect2(0, -5.5, 12, 23), 8, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	race.name = "Race"
	race.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var statuses := Control.new()
	statuses.name = "StatusContainer"
	statuses.position = Vector2.ZERO
	statuses.size = Vector2(31, 14)
	statuses.mouse_filter = Control.MOUSE_FILTER_IGNORE
	statuses.z_index = 5
	info.add_child(statuses)
	for index in 2:
		var badge := Panel.new()
		badge.name = "Badge%d" % (index + 1)
		badge.position = Vector2(index * 17, 0)
		badge.size = Vector2(14, 14)
		badge.clip_contents = true
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.visible = false
		badge.add_theme_stylebox_override("panel", _micro_style_box(Color("#202a27"), Color("#3f5f59"), 1, 1))
		statuses.add_child(badge)
		var badge_text := KWUI.label(badge, "", Rect2(0, -4.5, 14, 23), 8, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
		badge_text.name = "Text"
		badge_text.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# 姓名热区覆盖行动条底部 2px，与 Figma 节点坐标一致。它使用原生
	# Button，避免 combat_button 的按压缩放改变四张卡片的视觉对齐。
	var name_button := Button.new()
	name_button.name = "Name"
	name_button.position = Vector2(0, 32)
	name_button.size = Vector2(info_width, 18)
	name_button.text = ""
	name_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_button.focus_mode = Control.FOCUS_NONE
	name_button.tooltip_text = "点击切换自动/手动" if is_ally else ""
	name_button.add_theme_font_override("font", KWUI.FONT)
	name_button.add_theme_font_size_override("font_size", 10)
	var initial_name_color := HERO_NAME_AUTO_COLOR if is_ally else HERO_NAME_MANUAL_COLOR
	name_button.add_theme_color_override("font_color", initial_name_color)
	name_button.add_theme_color_override("font_hover_color", initial_name_color)
	name_button.add_theme_color_override("font_pressed_color", initial_name_color)
	name_button.add_theme_color_override("font_disabled_color", initial_name_color)
	var empty_style := StyleBoxEmpty.new()
	for state in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
		name_button.add_theme_stylebox_override(state, empty_style)
	name_button.z_index = 6
	if is_ally:
		name_button.pressed.connect(_toggle_auto.bind(unit_id))
	else:
		name_button.disabled = true
		name_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		name_button.add_theme_stylebox_override("disabled", empty_style)
	info.add_child(name_button)

func _add_gradient_frame(parent: Control, prefix: String, rect: Rect2, colors: PackedColorArray, offsets: PackedFloat32Array, border_color: Color) -> void:
	var gradient := Gradient.new()
	gradient.colors = colors
	gradient.offsets = offsets
	var texture := GradientTexture1D.new()
	texture.gradient = gradient
	texture.width = maxi(2, int(rect.size.x))
	var track := TextureRect.new()
	track.name = "%sTrack" % prefix
	track.position = rect.position
	track.size = rect.size
	track.texture = texture
	track.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	track.stretch_mode = TextureRect.STRETCH_SCALE
	track.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(track)
	var frame := Panel.new()
	frame.name = "%sFrame" % prefix
	frame.position = rect.position
	frame.size = rect.size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 2
	frame.add_theme_stylebox_override("panel", _micro_style_box(Color.TRANSPARENT, border_color, 1, 1))
	parent.add_child(frame)

func _micro_progress(parent: Control, node_name: String, rect: Rect2, fill_color: Color) -> Control:
	var progress := Control.new()
	progress.name = node_name
	progress.position = rect.position
	progress.size = rect.size
	progress.clip_contents = true
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(progress)
	var fill := ColorRect.new()
	fill.name = "Fill"
	fill.position = Vector2.ZERO
	fill.size = rect.size
	fill.color = fill_color
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	progress.add_child(fill)
	return progress

func _set_micro_progress(progress: Control, ratio: float) -> void:
	var fill := progress.get_node_or_null("Fill") as ColorRect
	if fill != null:
		fill.size.x = roundf(progress.size.x * clampf(ratio, 0.0, 1.0))

func _micro_style_box(fill_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.anti_aliasing = false
	style.corner_detail = 1
	style.content_margin_left = 0
	style.content_margin_right = 0
	style.content_margin_top = 0
	style.content_margin_bottom = 0
	return style

func _build_enemy_card(enemy_unit: Dictionary, position: Vector2, width: float) -> void:
	var enemy_host := Panel.new()
	enemy_host.name = "EnemyCard_%d" % int(enemy_unit.get("unit_id", -1))
	enemy_host.position = position
	enemy_host.size = Vector2(width, 205)
	enemy_host.add_theme_stylebox_override("panel", KWUI.style_box(Color("#11191700"), Color.TRANSPARENT, 0, 0))
	# Figma 333:1383：立绘在 86×205 卡片内以 (-12,34)、110×165 显示。
	unit_hosts[int(enemy_unit.get("unit_id", -1))] = enemy_host
	enemy_host.clip_contents = true
	add_child(enemy_host)
	if ResourceLoader.exists(FIGMA_ENEMY_PORTRAIT_PATH):
		var portrait := KWUI.texture(enemy_host, FIGMA_ENEMY_PORTRAIT_PATH, Rect2(FIGMA_ENEMY_PORTRAIT_POSITION, FIGMA_ENEMY_PORTRAIT_SIZE))
		portrait.name = "Portrait"
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
	else:
		_add_enemy_silhouette(enemy_host)
	_build_unit_info(enemy_host, enemy_unit, int(enemy_unit.get("unit_id", -1)), false)

func _add_status_bar() -> void:
	# Figma 使用系统状态栏而非游戏 HUD；用轻量几何图形复刻信号、Wi‑Fi 和电池。
	KWUI.label(self, "9:41", Rect2(16, 4, 45, 22), 13, Color("#e5e8da"))
	var signal_group := Node2D.new()
	signal_group.position = Vector2(292, 11)
	add_child(signal_group)
	for index in 4:
		var bar := ColorRect.new()
		bar.position = Vector2(index * 4, 7 - index * 2)
		bar.size = Vector2(2.5, 4 + index * 2)
		bar.color = Color("#d7ded1")
		signal_group.add_child(bar)
	var wifi := Line2D.new()
	wifi.width = 1.5
	wifi.default_color = Color("#d7ded1")
	wifi.points = PackedVector2Array([Vector2(309, 12), Vector2(314, 9), Vector2(319, 12)])
	add_child(wifi)
	var wifi_dot := ColorRect.new()
	wifi_dot.position = Vector2(313, 15)
	wifi_dot.size = Vector2(2.5, 2.5)
	wifi_dot.color = Color("#d7ded1")
	add_child(wifi_dot)
	var battery := Panel.new()
	battery.position = Vector2(332, 8)
	battery.size = Vector2(26, 14)
	battery.mouse_filter = Control.MOUSE_FILTER_IGNORE
	battery.add_theme_stylebox_override("panel", KWUI.style_box(Color.TRANSPARENT, Color("#d7ded1"), 2, 1))
	add_child(battery)
	var battery_fill := ColorRect.new()
	battery_fill.position = Vector2(335, 11)
	battery_fill.size = Vector2(19, 8)
	battery_fill.color = Color("#d7ded1")
	battery_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(battery_fill)

func _build_pause_overlay() -> void:
	pause_overlay = Control.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_overlay.z_index = 220
	pause_overlay.visible = false
	add_child(pause_overlay)
	var shade := ColorRect.new()
	shade.color = Color("#030609a6")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.add_child(shade)
	var panel := KWUI.panel(pause_overlay, Rect2(74, 333, 227, 118), Color("#111917f5"), Color("#80623a"))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	KWUI.label(panel, "战斗已暂停", Rect2(14, 20, 199, 34), 20, Color("#edddad"), HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(panel, "点击右上角“继续”恢复战斗", Rect2(14, 62, 199, 25), 11, Color("#abb8a6"), HORIZONTAL_ALIGNMENT_CENTER)

func _toggle_combat_pause() -> void:
	if finished:
		return
	_set_combat_paused(not combat_paused)

func _set_combat_paused(paused: bool) -> void:
	combat_paused = paused and not finished
	if is_instance_valid(pause_overlay):
		pause_overlay.visible = combat_paused
	if is_instance_valid(pause_button):
		pause_button.text = "继续" if combat_paused else "暂停"
	_set_presentation_tweens_paused(combat_paused)

func _set_presentation_tweens_paused(paused: bool) -> void:
	for index in range(active_presentation_tweens.size() - 1, -1, -1):
		var tween := active_presentation_tweens[index]
		if not tween.is_valid():
			active_presentation_tweens.remove_at(index)
		elif paused:
			tween.pause()
		else:
			tween.play()

func _register_presentation_tween(tween: Tween) -> void:
	for index in range(active_presentation_tweens.size() - 1, -1, -1):
		if not active_presentation_tweens[index].is_valid():
			active_presentation_tweens.remove_at(index)
	active_presentation_tweens.append(tween)
	if combat_paused:
		tween.pause()

func _build_loot_overlay() -> void:
	loot_overlay = Control.new()
	loot_overlay.z_index = 300
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
	var leave := KWUI.combat_button(panel, "返回设置" if Game.debug_combat_return_to_settings else "离开", Rect2(177, 478, 134, 44), 13)
	leave.pressed.connect(_leave_loot)

func _process(delta: float) -> void:
	if combat_paused:
		return
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
				if bool(animation.get("hit_enabled", false)) \
						and frame_index == int(animation.get("hit_frame", HERO_ANIMATION_ACTION_HIT_FRAME)) \
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

func _hero_action_names(hero_id: String) -> Array[String]:
	var sheet_map: Dictionary = HERO_ANIMATION_SHEETS.get(hero_id, {})
	var names: Array[String] = []
	for action_name in sheet_map.keys():
		if str(action_name) != "idle":
			names.append(str(action_name))
	return names

func _load_hero_animation_frames(hero_id: String, action_name: String) -> Array[Texture2D]:
	var sheet_map: Dictionary = HERO_ANIMATION_SHEETS.get(hero_id, {})
	var file_name := str(sheet_map.get(action_name, ""))
	if file_name.is_empty():
		return []
	var path := "res://assets/camp/ui/expedition/animations/%s/%s" % [hero_id, file_name]
	if not ResourceLoader.exists(path):
		return []
	var sheet := load(path) as Texture2D
	if sheet == null or Vector2i(sheet.get_width(), sheet.get_height()) != HERO_ANIMATION_SHEET_SIZE:
		return []
	return _sheet_frames(sheet, HERO_ANIMATION_COLUMNS, HERO_ANIMATION_ROWS)

func _hero_portrait_scale(hero_id: String) -> float:
	return float(HERO_PORTRAIT_SCALES.get(hero_id, 1.0))

func _hero_portrait_display_size(hero_id: String) -> Vector2:
	return HERO_ANIMATION_DISPLAY_SIZE * _hero_portrait_scale(hero_id)

func _hero_portrait_display_position(hero_id: String) -> Vector2:
	var display_size := _hero_portrait_display_size(hero_id)
	# 水平居中，纵向按当前确认的视觉底边对齐。
	return Vector2(
		(HERO_ANIMATION_DISPLAY_SIZE.x - display_size.x) * 0.5,
		HERO_PORTRAIT_VISUAL_BOTTOM - display_size.y
	)

func _hero_action_for_skill(hero_id: String, skill_id: String, healing: bool) -> String:
	if hero_id == "shi_yan":
		return "defense" if skill_id == "tiao_xin" else "attack"
	if hero_id == "lu_qing":
		if skill_id == "ling_neng_zhen_dang":
			return "lei_ji"
		if healing or skill_id == "ning_shuang_hu":
			return "heal"
		return "attack"
	if hero_id == "bai_ling":
		return "heal" if healing or skill_id == "qing_xin_jue" else "attack"
	if hero_id == "mo_yan":
		return "hui_jian" if skill_id == "tou_ren" else "fei_jian"
	return ""

func _step(ticks: int) -> void:
	combat_ticks += ticks
	for unit in units:
		if unit["dead"]: continue
		_apply_periodic_mechanics(unit)
		_apply_status_ticks(unit)
		if finished: return
		var cooldowns: Dictionary = unit.get("cooldowns", {})
		for cooldown_id in cooldowns:
			cooldowns[cooldown_id] = maxi(0, int(cooldowns[cooldown_id]) - ticks)
		unit["cooldowns"] = cooldowns
		var active_statuses: Array = []
		for status in unit.get("statuses", []):
			var status_copy: Dictionary = status.duplicate(true)
			status_copy["ticks"] = int(status_copy.get("ticks", 0)) - ticks
			if int(status_copy["ticks"]) > 0: active_statuses.append(status_copy)
		unit["statuses"] = active_statuses
		unit["timer"] = int(unit["timer"]) - ticks
		if unit["timer"] > 0: continue
		if _has_status(unit, "stun"):
			unit["timer"] = 1
			continue
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
	if _has_status(unit, "silence"):
		for candidate_id in unit.get("skills", []):
			var candidate := KWCombatResolver.skill_by_id(Game.combat_config, str(candidate_id))
			if str(candidate.get("damageKind", "none")) == "physical":
				skill_id = str(candidate_id)
				break
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
	var living_targets := _living_units("ally")
	if living_targets.is_empty():
		_finish_defeat()
		return
	var available_skills: Array[String] = []
	var cooldowns: Dictionary = enemy.get("cooldowns", {})
	for skill_id in enemy.get("skills", []):
		if int(cooldowns.get(str(skill_id), 0)) <= 0:
			available_skills.append(str(skill_id))
	if available_skills.is_empty():
		enemy["timer"] = 1
		return
	var chosen_index := int(enemy.get("ai_index", 0)) % available_skills.size()
	var chosen_id := available_skills[chosen_index]
	for candidate_id in available_skills:
		var candidate := KWCombatResolver.skill_by_id(Game.combat_config, candidate_id)
		var use_below := int(candidate.get("useBelowHpPercent", -1))
		if use_below >= 0 and int(enemy["hp"]) * 100 <= int(enemy["max_hp"]) * use_below:
			chosen_id = candidate_id
			break
	enemy["ai_index"] = int(enemy.get("ai_index", 0)) + 1
	_resolve_command(enemy, chosen_id)

func _resolve_command(actor: Dictionary, skill_id: String) -> void:
	var skill := KWCombatResolver.skill_by_id(Game.combat_config, skill_id)
	if skill.is_empty(): actor["timer"] = 20; return
	if _has_status(actor, "silence") and str(skill.get("damageKind", "none")) in ["magical", "none"]:
		actor["timer"] = 8
		_show_log("%s 被封灵，无法施放 %s" % [actor["name"], _skill_name(skill, skill_id)])
		return
	var cooldowns: Dictionary = actor.get("cooldowns", {})
	if int(cooldowns.get(skill_id, 0)) > 0:
		_show_log("%s 尚在冷却" % Game.text(skill.get("nameKey", skill_id)))
		return
	var interval_percent := 80 if actor.get("side") == "enemy" and _is_low_phase_boss(actor) else 100
	actor["timer"] = KWCombatResolver.action_interval(int(skill.get("baseIntervalTicks", 20)), actor.get("statuses", []), interval_percent)
	actor["action_max"] = actor["timer"]
	var cooldown_ticks := int(skill.get("cooldownTicks", 0))
	if cooldown_ticks > 0:
		cooldowns[skill_id] = cooldown_ticks
	actor["cooldowns"] = cooldowns
	if bool(skill.get("healing", false)) or skill_id == "hui_chun_shu":
		var allies := _living_units(str(actor.get("side", "ally")))
		if allies.is_empty(): return
		var target: Dictionary = allies[0]
		for candidate in allies:
			if float(candidate["hp"]) / candidate["max_hp"] < float(target["hp"]) / target["max_hp"]: target = candidate
		var amount := KWCombatResolver.heal_amount(actor, target, skill)
		target["hp"] = mini(int(target["max_hp"]), int(target["hp"]) + amount)
		_show_log("%s 使用回春术，%s 恢复 %d 点生命" % [actor["name"], target["name"], amount])
		_play_unit_action(actor, skill_id, target, false)
		return
	var targets := _targets_for_skill(actor, skill)
	if skill.get("damageKind", "none") == "none":
		if targets.is_empty(): targets = [actor]
		for target in targets:
			_apply_skill_status(actor, target, skill)
		_show_log("%s 使用 %s" % [actor["name"], _skill_name(skill, skill_id)])
		_play_unit_action(actor, skill_id, targets.front() if not targets.is_empty() else actor, false)
		return
	if targets.is_empty():
		if actor.get("side") == "ally": _finish_victory()
		else: _finish_defeat()
		return
	var total_damage := 0
	var first_target: Dictionary = targets.front()
	for target in targets:
		var defender := _effective_defender(target)
		var incoming_percent := 125 if _has_status(target, "core_exposed") else 100
		var damage := KWCombatResolver.damage_amount(actor, defender, skill, int(Game.combat_config.get("defenseLevelConstant", 100)), _outgoing_damage_percent(actor), incoming_percent)
		total_damage += damage
		_apply_damage(target, damage, actor, str(skill.get("damageKind", "physical")), true)
		if not target.get("dead", false):
			_apply_skill_status(actor, target, skill)
	# 战斗数值已经结算；人物动作和命中特效只消费这次结果，不参与判伤或重算。
	if actor.get("side") == "ally" and not first_target.is_empty():
		_play_unit_action(actor, skill_id, first_target, true)
	_show_log("%s 使用 %s，造成 %d 点伤害" % [actor["name"], _skill_name(skill, skill_id), total_damage])

func _living_units(side: String) -> Array:
	return units.filter(func(unit): return str(unit.get("side", "")) == side and not bool(unit.get("dead", false)))

func _targets_for_skill(actor: Dictionary, skill: Dictionary) -> Array:
	var target_type := str(skill.get("targetType", "ENEMY_SINGLE"))
	if target_type == "SELF":
		return [actor]
	var target_side := str(actor.get("side", "ally")) if target_type.begins_with("ALLY") else ("enemy" if actor.get("side") == "ally" else "ally")
	var candidates := _living_units(target_side)
	if candidates.is_empty():
		return []
	if target_type.ends_with("_ALL"):
		return candidates
	var selected: Dictionary = candidates.front()
	if target_type.contains("LOWEST_HP"):
		for candidate in candidates:
			if float(candidate["hp"]) / float(candidate["max_hp"]) < float(selected["hp"]) / float(selected["max_hp"]): selected = candidate
	elif target_type.contains("HIGHEST_HP"):
		for candidate in candidates:
			if int(candidate["hp"]) > int(selected["hp"]): selected = candidate
	elif target_type.contains("RANDOM"):
		selected = candidates[combat_ticks % candidates.size()]
	return [selected]

func _skill_name(skill: Dictionary, skill_id: String) -> String:
	return Game.text(str(skill.get("nameKey", "")), str(skill.get("name", skill_id)))

func _has_status(unit: Dictionary, kind: String) -> bool:
	for status in unit.get("statuses", []):
		if str(status.get("kind", "")) == kind:
			return true
	return false

func _is_low_phase_boss(unit: Dictionary) -> bool:
	return bool(unit.get("mechanics", {}).get("bossGoldBody", false)) and int(unit.get("hp", 0)) * 100 <= int(unit.get("max_hp", 1)) * 35

func _effective_defender(target: Dictionary) -> Dictionary:
	var defender := target.duplicate(true)
	var attrs: Dictionary = target.get("attrs", {}).duplicate(true)
	if int(target.get("shield", 0)) > 0:
		attrs["armor"] = int(attrs.get("armor", 0)) + int(target.get("mechanics", {}).get("shieldArmorBonus", 0))
	defender["attrs"] = attrs
	return defender

func _outgoing_damage_percent(actor: Dictionary) -> int:
	var percent := 100
	if actor.get("side") == "enemy":
		for ally in _living_units("enemy"):
			percent += int(ally.get("mechanics", {}).get("allyDamageAuraPercent", 0))
	return percent

func _hero_id_for_actor(actor: Dictionary) -> String:
	var definition_id := str(actor.get("hero", {}).get("definitionId", ""))
	if definition_id == "hero_wu_xiu_01": return "shi_yan"
	if definition_id == "hero_fa_xiu_01": return "lu_qing"
	if definition_id == "hero_yi_xiu_01": return "bai_ling"
	if definition_id == "hero_qian_xiu_01": return "mo_yan"
	return ""

func _play_unit_action(actor: Dictionary, skill_id: String, target: Dictionary, hit_enabled: bool) -> void:
	var hero_id := _hero_id_for_actor(actor)
	if hero_id.is_empty():
		return
	var healing := bool(KWCombatResolver.skill_by_id(Game.combat_config, skill_id).get("healing", false)) or skill_id == "hui_chun_shu"
	var action_name := _hero_action_for_skill(hero_id, skill_id, healing)
	if action_name.is_empty():
		return
	for index in animated_portraits.size():
		var animation: Dictionary = animated_portraits[index]
		if int(animation.get("unit_id", -1)) != int(actor.get("unit_id", -1)):
			continue
		var action_frames: Array = animation.get("action_frames", {}).get(action_name, [])
		var portrait := animation.get("node") as TextureRect
		if portrait == null or action_frames.size() != HERO_ANIMATION_FRAME_COUNT:
			return
		animation["frames"] = action_frames
		animation["frame_duration"] = 1.0 / HERO_ANIMATION_FPS
		animation["elapsed"] = 0.0
		animation["frame_index"] = 0
		animation["loop"] = false
		animation["mode"] = HERO_ANIMATION_MODE
		animation["action_name"] = action_name
		animation["hit_enabled"] = hit_enabled and not target.is_empty()
		animation["target_unit_id"] = int(target.get("unit_id", -1))
		animation["hit_frame"] = HERO_ANIMATION_ACTION_HIT_FRAME
		animation["hit_fired"] = false
		animation["idle_display_position"] = portrait.position
		animation["idle_display_size"] = portrait.size
		portrait.position = _hero_portrait_display_position(hero_id)
		portrait.size = _hero_portrait_display_size(hero_id)
		portrait.texture = action_frames[0]
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
	_register_presentation_tween(shake)
	shake.tween_property(host, "position:x", base_position.x + 2.0, 0.03)
	shake.tween_property(host, "position:x", base_position.x - 2.0, 0.04)
	shake.tween_property(host, "position:x", base_position.x + 1.0, 0.03)
	shake.tween_property(host, "position:x", base_position.x, 0.04)
	var effect_tween := create_tween().set_parallel(true)
	_register_presentation_tween(effect_tween)
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

func _apply_periodic_mechanics(unit: Dictionary) -> void:
	var periodic: Dictionary = unit.get("mechanics", {}).get("periodicShield", {})
	if periodic.is_empty():
		return
	var interval := int(periodic.get("intervalTicks", 0))
	if interval <= 0 or combat_ticks < int(unit.get("next_periodic_tick", interval)):
		return
	unit["shield"] = int(unit.get("shield", 0)) + int(periodic.get("amount", 0))
	unit["next_periodic_tick"] = combat_ticks + interval
	_show_log("%s 获得 %d 点石盾" % [unit["name"], int(periodic.get("amount", 0))])

func _apply_status_ticks(unit: Dictionary) -> void:
	if combat_ticks % 20 != 0:
		return
	var total_damage := 0
	for status in unit.get("statuses", []):
		total_damage += int(status.get("perSecondDamage", 0))
	if total_damage > 0:
		_apply_damage(unit, total_damage, {}, "status", false)
		if not unit.get("dead", false):
			_show_log("%s 受到 %d 点持续伤害" % [unit["name"], total_damage])

func _apply_skill_status(actor: Dictionary, target: Dictionary, skill: Dictionary) -> void:
	var status_definition: Dictionary = skill.get("appliesStatus", {})
	if status_definition.is_empty(): return
	var chance := int(status_definition.get("chancePercent", 100))
	if chance < 100 and int((combat_ticks + int(actor.get("unit_id", 0)) * 17 + int(target.get("unit_id", 0)) * 31) % 100) >= chance:
		return
	var status_kind := str(status_definition.get("kind", ""))
	if status_kind == "shield":
		target["shield"] = int(target.get("shield", 0)) + int(status_definition.get("magnitude", 0))
		return
	if status_kind == "purify":
		target["statuses"] = target.get("statuses", []).filter(func(status): return str(status.get("kind", "")) not in ["slow", "stun", "silence", "poison", "bleed"])
		return
	var statuses: Array = target.get("statuses", [])
	for index in statuses.size():
		if str(statuses[index].get("kind", "")) == status_kind:
			statuses.remove_at(index)
			break
	statuses.append({
		"kind": status_kind,
		"ticks": int(status_definition.get("durationTicks", 20)),
		"magnitude": int(status_definition.get("magnitude", 0)),
		"perSecondDamage": int(status_definition.get("perSecondDamage", 0)),
		"sourceUnitId": int(actor.get("unit_id", -1)),
	})
	target["statuses"] = statuses

func _apply_damage(target: Dictionary, damage: int, attacker: Dictionary = {}, damage_kind: String = "physical", direct_hit: bool = false) -> void:
	if bool(target.get("dead", false)):
		return
	var previous_hp := int(target.get("hp", 0))
	var previous_shield := int(target.get("shield", 0))
	var absorbed := mini(int(target.get("shield", 0)), damage)
	target["shield"] = int(target.get("shield", 0)) - absorbed
	target["hp"] = maxi(0, int(target["hp"]) - damage + absorbed)
	if direct_hit and target.get("side") == "enemy" and attacker.get("side") == "ally":
		_apply_reactive_mechanics(target, attacker, damage_kind)
	if previous_shield > 0 and int(target.get("shield", 0)) == 0 and bool(target.get("mechanics", {}).get("coreExposedOnShieldBreak", false)):
		var statuses: Array = target.get("statuses", [])
		statuses.append({"kind": "core_exposed", "ticks": int(target.get("mechanics", {}).get("coreExposedTicks", 80)), "magnitude": 25})
		target["statuses"] = statuses
		_show_log("%s 金身破碎，核心外露" % target["name"])
	_apply_forced_boss_shields(target, previous_hp)
	if target["hp"] <= 0:
		target["dead"] = true
		_show_log("%s 倒下了" % target["name"])
		if target["side"] == "enemy" and _living_units("enemy").is_empty(): _finish_victory()
		elif units.filter(func(u): return u["side"] == "ally" and not u["dead"]).is_empty(): _finish_defeat()

func _apply_reactive_mechanics(target: Dictionary, attacker: Dictionary, damage_kind: String) -> void:
	var counter: Dictionary = target.get("mechanics", {}).get("physicalHitCounter", {})
	if counter.is_empty():
		return
	if damage_kind == "magical" and bool(counter.get("clearOnMagical", true)):
		target["physical_hit_count"] = maxi(0, int(target.get("physical_hit_count", 0)) - int(counter.get("magicalClearAmount", 99)))
		return
	if damage_kind != "physical":
		return
	target["physical_hit_count"] = int(target.get("physical_hit_count", 0)) + 1
	var threshold := maxi(1, int(counter.get("threshold", 3)))
	if int(target["physical_hit_count"]) < threshold:
		return
	target["physical_hit_count"] = 0
	var counter_damage := KWCombatResolver.counter_damage(int(target.get("attrs", {}).get("strength", 0)), int(counter.get("counterPercent", 35)), attacker, int(Game.combat_config.get("defenseLevelConstant", 100)))
	_apply_damage(attacker, counter_damage, target, "counter", false)
	_show_log("%s 触发反震，%s 受到 %d 点伤害" % [target["name"], attacker["name"], counter_damage])

func _apply_forced_boss_shields(target: Dictionary, previous_hp: int) -> void:
	var mechanics: Dictionary = target.get("mechanics", {})
	if not bool(mechanics.get("bossGoldBody", false)) or int(target.get("hp", 0)) <= 0:
		return
	var used: Array = target.get("forced_shields_used", [])
	for threshold in mechanics.get("forcedShieldThresholds", [75, 35]):
		var threshold_value := int(threshold)
		if used.has(threshold_value):
			continue
		if previous_hp * 100 > int(target["max_hp"]) * threshold_value and int(target["hp"]) * 100 <= int(target["max_hp"]) * threshold_value:
			target["shield"] = int(target.get("shield", 0)) + int(mechanics.get("forcedShieldAmount", 900))
			used.append(threshold_value)
			_show_log("%s 在 %d%% 生命激活石灵金身" % [target["name"], threshold_value])
	target["forced_shields_used"] = used

func _refresh() -> void:
	escape_button.visible = not finished and _escape_available()
	KWUI.set_combat_button_disabled(escape_button, finished)
	if is_instance_valid(pause_button):
		pause_button.visible = not finished
	if is_instance_valid(tick_label): tick_label.text = "战斗 %.1f 秒" % (float(combat_ticks) / 20.0)
	for unit in units:
		var host: Panel = unit_hosts.get(int(unit["unit_id"]))
		if not is_instance_valid(host): continue
		var info := host.get_node_or_null("InfoOverlay") as Control
		var ui_root: Node = info if info != null else host
		var bar: Control = ui_root.get_node_or_null("Hp")
		var hp_value: Control = ui_root.get_node_or_null("HpValue")
		var action: Control = ui_root.get_node_or_null("Action")
		if bar is ProgressBar:
			bar.value = float(unit["hp"]) / float(unit["max_hp"]) * 100.0
		elif bar:
			_set_micro_progress(bar, float(unit["hp"]) / float(unit["max_hp"]))
		if hp_value is Label:
			hp_value.text = "%d/%d" % [int(unit["hp"]), int(unit["max_hp"])]
		elif hp_value:
			var hp_text := hp_value.get_node_or_null("Text") as Label
			if hp_text:
				hp_text.text = "%d/%d" % [int(unit["hp"]), int(unit["max_hp"])]
		if action:
			var action_max := maxi(1, int(unit.get("action_max", unit["timer"])))
			var action_ratio := clampf(float(action_max - int(unit["timer"])) / float(action_max), 0.0, 1.0)
			if action is ProgressBar:
				action.value = action_ratio * 100.0
			else:
				_set_micro_progress(action, action_ratio)
		_refresh_unit_status_badges(info, unit)
		host.modulate = Color(1, 1, 1, 0.34) if bool(unit.get("dead", false)) else Color.WHITE
		var name_label: Button = ui_root.get_node_or_null("Name")
		if name_label:
			name_label.text = str(unit["name"])
			var name_color := HERO_NAME_AUTO_COLOR if unit["side"] == "ally" and bool(unit.get("auto", true)) else HERO_NAME_MANUAL_COLOR
			name_label.add_theme_color_override("font_color", name_color)
			name_label.add_theme_color_override("font_hover_color", name_color)
			name_label.add_theme_color_override("font_pressed_color", name_color)
			name_label.add_theme_color_override("font_disabled_color", name_color)
	if is_instance_valid(log_label): log_label.text = log_lines.back() if not log_lines.is_empty() else ""
	_refresh_skill_panel()

func _refresh_unit_status_badges(info: Control, unit: Dictionary) -> void:
	if info == null:
		return
	var container := info.get_node_or_null("StatusContainer") as Control
	if container == null:
		return
	var tokens: Array[String] = []
	if int(unit.get("shield", 0)) > 0:
		tokens.append("盾")
	var status_labels := {
		"gather_spirit": "聚",
		"haste": "速",
		"slow": "缓",
		"stun": "晕",
		"silence": "封",
		"poison": "毒",
		"bleed": "血",
		"core_exposed": "裂",
	}
	for active_status in unit.get("statuses", []):
		var label_text := str(status_labels.get(str(active_status.get("kind", "")), ""))
		if label_text.is_empty() or tokens.has(label_text):
			continue
		tokens.append(label_text)
		if tokens.size() >= 2:
			break
	for index in 2:
		var badge := container.get_node_or_null("Badge%d" % (index + 1)) as Panel
		if badge == null:
			continue
		badge.visible = index < tokens.size()
		var badge_text := badge.get_node_or_null("Text") as Label
		if badge_text != null:
			badge_text.text = tokens[index] if index < tokens.size() else ""

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
	var selected_index := -1
	for index in mini(skill_buttons.size(), skills.size()):
		if int(cooldowns.get(str(skills[index]), 0)) <= 0:
			selected_index = index
			break
	for index in skill_buttons.size():
		var button: Button = skill_buttons[index]
		if index >= skills.size():
			button.visible = false
			continue
		button.visible = true
		var skill_id := str(skills[index])
		var definition := KWCombatResolver.skill_by_id(Game.combat_config, skill_id)
		var cooldown := int(cooldowns.get(skill_id, 0))
		var skill_name := Game.text(definition.get("nameKey", skill_id))
		var name_label := button.get_node_or_null("Name/Text") as Label
		var glyph_label := button.get_node_or_null("Icon/Glyph/Text") as Label
		var effect_label := button.get_node_or_null("Effect/Text") as Label
		if name_label != null:
			name_label.text = skill_name
		if glyph_label != null:
			glyph_label.text = _skill_glyph(skill_id, skill_name)
		if effect_label != null:
			effect_label.text = "冷却" if cooldown > 0 else _skill_effect_text(definition)
			effect_label.add_theme_color_override("font_color", SKILL_COLOR_SECONDARY if cooldown > 0 else _skill_effect_color(definition))
		button.disabled = cooldown > 0
		_apply_skill_item_state(button, index == selected_index, cooldown > 0)

func _escape_available() -> bool:
	var escape_percent := int(current_encounter.get("escapeEnemyHpPercent", 35))
	var current_hp := 0
	var maximum_hp := 0
	for unit in units:
		if unit["side"] == "enemy":
			current_hp += int(unit["hp"])
			maximum_hp += int(unit["max_hp"])
	return maximum_hp > 0 and current_hp * 100 <= maximum_hp * escape_percent

func _finish_victory() -> void:
	if finished: return
	_set_combat_paused(false)
	finished = true
	_persist_ally_unit_states()
	victory_result = Game.finish_encounter_victory(current_encounter)
	if not bool(victory_result.get("ok", false)):
		finished = false
		_show_log(str(victory_result.get("message", "战斗结算失败")))
		return
	for message in victory_result.get("progressMessages", []):
		_show_log(str(message))
	_refresh()
	_show_loot_overlay()

func _finish_defeat() -> void:
	if finished: return
	_set_combat_paused(false)
	finished = true
	Game._finish_expedition(true)
	_show_outcome(false)

func _show_outcome(victory: bool) -> void:
	_refresh()
	KWUI.label(outcome_panel, "战斗胜利" if victory else "全队阵亡", Rect2(15, 29, 295, 38), 24, KWUI.GOLD if victory else KWUI.RED, HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(outcome_panel, "战斗已结束，战利品正在结算" if victory else "本次入山队伍失去战斗能力。\n修士将进入还魂殿待处理。", Rect2(25, 75, 275, 60), 13, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var next_label := "返回设置" if Game.debug_combat_return_to_settings else ("返回地图" if victory else "返回营地")
	var next := KWUI.combat_button(outcome_panel, next_label, Rect2(53, 166, 219, 48), 15)
	next.pressed.connect(_change_scene_after_combat.bind("res://scenes/map.tscn" if victory else "res://scenes/camp.tscn"))
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
	var soul_reward := int(expedition.get("pendingEncounterSoulCrystal", victory_result.get("soulCrystal", 0)))
	if reward_index < loot_reward_labels.size():
		loot_reward_labels[reward_index].text = "魂晶 +%d（已获得）" % soul_reward
		loot_reward_labels[reward_index].visible = true
		reward_index += 1
	var pending_loot: Array = expedition.get("pendingEncounterLoot", [])
	for reward in pending_loot:
		if reward_index >= loot_reward_labels.size(): break
		loot_reward_labels[reward_index].text = "%s ×%d    重量 %d" % [Game.text(str(reward.get("nameKey", reward.get("itemId", "战利品"))), str(reward.get("itemId", "战利品"))), int(reward.get("amount", 1)), int(reward.get("amount", 1)) * _loot_weight(str(reward.get("itemId", "")))]
		loot_reward_labels[reward_index].visible = true
		reward_index += 1
	var reward_weight := 0
	for reward in pending_loot: reward_weight += int(reward.get("amount", 1)) * _loot_weight(str(reward.get("itemId", "")))
	loot_status_label.text = "全部拾取后：%d/%d" % [burden + reward_weight, limit]
	loot_status_label.add_theme_color_override("font_color", Color("#a8c2a6") if burden + reward_weight <= limit else Color("#eb8b6f"))
	KWUI.set_combat_button_disabled(loot_take_all_button, burden + reward_weight > limit)

func _take_all_loot() -> void:
	if not Game.take_pending_encounter_loot():
		_show_log("战利品保存失败，请重试")
		return
	_leave_loot()

func _leave_loot() -> void:
	loot_overlay.visible = false
	if not Game.profile.get("expedition", {}).get("pendingEncounterLoot", []).is_empty():
		Game.discard_pending_encounter_loot()
	Game.clear_active_encounter()
	_change_scene_after_combat("res://scenes/map.tscn")

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
	_persist_ally_unit_states()
	Game.clear_active_encounter()
	_change_scene_after_combat("res://scenes/map.tscn")

func _give_up() -> void:
	if finished: return
	_persist_ally_unit_states()
	Game.clear_active_encounter()
	_change_scene_after_combat("res://scenes/map.tscn")

func _change_scene_after_combat(normal_scene_path: String) -> void:
	if Game.debug_combat_return_to_settings:
		# Direct Debug battles do not belong to the map exploration loop.  Close
		# the temporary expedition after victory/escape so the camp can open the
		# settings panel without showing a stale "continue expedition" prompt.
		if Game.profile.get("expedition") is Dictionary:
			Game._finish_expedition(false)
		get_tree().change_scene_to_file("res://scenes/camp.tscn")
		return
	get_tree().change_scene_to_file(normal_scene_path)

func _persist_ally_unit_states() -> void:
	for unit in units:
		if unit["side"] != "ally":
			continue
		var hp := maxi(0, int(unit.get("hp", 0)))
		unit["hero"]["currentHp"] = hp
		unit["hero"]["isDead"] = bool(unit.get("dead", false)) or hp <= 0

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
