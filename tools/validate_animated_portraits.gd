extends Node

const CAMP_SCENE = preload("res://scenes/camp.tscn")
const COMBAT_SCENE = preload("res://scenes/combat.tscn")
const HERO_ANIMATION_FRAME_SIZE := Vector2(172, 298)
const CAMP_ANIMATION_DISPLAY_SIZE := Vector2(86, 149)
const COMBAT_CANVAS_WIDTH := 375.0 / 4.0
const COMBAT_CARD_SIZE := Vector2(COMBAT_CANVAS_WIDTH, 205)
const COMBAT_INFO_SIZE := Vector2(COMBAT_CANVAS_WIDTH, 56)
const COMBAT_PORTRAIT_VISUAL_BOTTOM := 190.0
const HERO_ANIMATION_DISPLAY_SIZE := Vector2(COMBAT_CANVAS_WIDTH, 149)
const HERO_PORTRAIT_SCALES := {3: 1.08}
const HERO_ANIMATION_FPS := 8.0
const HERO_ANIMATION_FRAME_COUNT := 16
const HERO_ANIMATION_ACTION_HIT_FRAME := 8

var errors: Array[String] = []
var cast_a_candidate_path := ""

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		_fail("validation requires --no-profile-write")
		_finish()
		return
	var game: Node = get_tree().root.get_node_or_null("Game")
	if game == null:
		_fail("Game autoload is missing")
		_finish()
		return
	var defaults: Variant = _read_json("res://data/config/default_profile.json")
	if not defaults is Dictionary:
		_fail("default profile could not be read")
		_finish()
		return
	game.set("profile", defaults.duplicate(true))

	var capture_dir: String = _capture_output_dir()
	var camp: Node = CAMP_SCENE.instantiate()
	add_child(camp)
	await get_tree().process_frame
	camp.call("_open_expedition")
	# 四名修士的统一 172×298 @2x Idle 为标准 8 FPS × 16 帧。
	await get_tree().create_timer(float(HERO_ANIMATION_FRAME_COUNT) / HERO_ANIMATION_FPS + 0.1).timeout
	_validate_animation_list(camp.get("animated_portraits"), 4, "camp")
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("animated_portraits_camp.png"))
	camp.queue_free()
	await get_tree().process_frame

	game.set("profile", defaults.duplicate(true))
	game.get("profile")["expedition"] = {
		"mapId": "map_01",
		"partyPresetId": "party_01",
		"partyMemberIds": ["hero_wu_xiu_01", "hero_fa_xiu_01", "hero_yi_xiu_01", "hero_qian_xiu_01"],
		"encounterId": "m1_g01",
		"mapObjectId": "m1_enemy_g01",
		"position": {"x": 2, "y": 2},
		"remainingGrain": 60,
		"grainCapacity": 60,
		"grainDepletionSteps": 0,
		"carriedItems": {"pickaxe": 0, "lens": 0},
		"restUsesRemaining": 1,
		"isResting": false,
		"restHealingUsed": false,
		"revealedTiles": ["2:2"],
		"temporaryLoot": {},
	}
	var combat: Node = COMBAT_SCENE.instantiate()
	add_child(combat)
	_validate_combat_ally_info_ui(combat)
	_validate_combat_enemy_info_ui(combat)
	_validate_combat_skill_picker(combat)
	_validate_combat_skill_picker_content(combat)
	_validate_combat_action_assets(combat)
	_validate_combat_hero_canvas_bottom_alignment(combat)
	# 结算循环暂停，但 Combat._process() 仍会推进人物表现，便于隔离验证完整动画周期。
	combat.set("finished", true)
	cast_a_candidate_path = _argument_value("--cast-a-candidate=")
	if not cast_a_candidate_path.is_empty():
		_inject_cast_a_candidate(combat, cast_a_candidate_path)
	await get_tree().create_timer(float(HERO_ANIMATION_FRAME_COUNT) / HERO_ANIMATION_FPS + 0.1).timeout
	_validate_animation_list(combat.get("animated_portraits"), 4, "combat")
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("animated_portraits_combat.png"))
	await _validate_shi_yan_cast_a(combat, capture_dir)
	combat.queue_free()
	await get_tree().process_frame
	_finish()

func _validate_combat_ally_info_ui(combat: Node) -> void:
	for index in 4:
		var host := combat.get_node_or_null("HeroCard_%d" % (index + 1)) as Control
		if host == null:
			_fail("combat hero card %d is missing" % (index + 1))
			continue
		if host.get_node_or_null("SelectedGlow") != null:
			_fail("combat hero %d must not contain the obsolete blue selection frame" % (index + 1))
		var expected_position := Vector2(index * COMBAT_CANVAS_WIDTH, 492)
		_check_control_rect(host, expected_position, COMBAT_CARD_SIZE, "combat hero card %d" % (index + 1))
		var debug_background := host.get_node_or_null("PortraitMask/PortraitCanvasDebug") as ColorRect
		if debug_background == null:
			_fail("combat hero %d is missing the green portrait canvas background" % (index + 1))
		else:
			var expected_display_size := HERO_ANIMATION_DISPLAY_SIZE * float(HERO_PORTRAIT_SCALES.get(index + 1, 1.0))
			var expected_display_position := _expected_combat_display_position(index + 1, expected_display_size)
			_check_control_rect(debug_background, expected_display_position, expected_display_size, "combat hero %d portrait canvas background" % (index + 1))
			if not is_equal_approx(debug_background.position.y + debug_background.size.y, COMBAT_PORTRAIT_VISUAL_BOTTOM):
				_fail("combat hero %d portrait canvas background bottom does not align with the info panel bottom" % (index + 1))
			if not debug_background.color.is_equal_approx(Color("#32b76866")):
				_fail("combat hero %d portrait canvas background color mismatch" % (index + 1))
		var info := host.get_node_or_null("InfoOverlay") as Control
		if info == null:
			_fail("combat hero info %d is missing" % (index + 1))
			continue
		_check_control_rect(info, Vector2(0, 149), COMBAT_INFO_SIZE, "combat hero info %d" % (index + 1))
		_check_named_control_rect(info, "HpFrame", Vector2(0, 15), Vector2(COMBAT_CANVAS_WIDTH, 10), index)
		_check_named_control_rect(info, "Hp", Vector2(3, 18), Vector2(COMBAT_CANVAS_WIDTH - 6, 5), index)
		_check_named_control_rect(info, "HpValue", Vector2(3, 14), Vector2(COMBAT_CANVAS_WIDTH - 6, 10), index)
		_check_named_control_rect(info, "ActionFrame", Vector2(0, 28), Vector2(COMBAT_CANVAS_WIDTH, 6), index)
		_check_named_control_rect(info, "Action", Vector2(3, 30), Vector2(COMBAT_CANVAS_WIDTH - 6, 3), index)
		_check_named_control_rect(info, "Name", Vector2(0, 32), Vector2(COMBAT_CANVAS_WIDTH, 18), index)
		_check_named_control_rect(info, "RaceFrame", Vector2(0, 14), Vector2(12, 12), index)
		_check_named_control_rect(info, "StatusContainer", Vector2(0, 0), Vector2(31, 14), index)
		var name_button := info.get_node_or_null("Name") as Button
		if name_button != null and name_button.text.contains("·"):
			_fail("combat hero name %d must not include auto/manual suffix text" % (index + 1))

func _validate_combat_skill_picker(combat: Node) -> void:
	var picker := combat.get_node_or_null("SkillPicker") as Control
	if picker == null:
		_fail("combat skill picker is missing")
		return
	_check_control_rect(picker, Vector2(117.5, 491), Vector2(140, 46), "combat skill picker")
	if picker is Panel:
		_fail("combat skill picker must be transparent without the obsolete modal panel")
	for index in 3:
		var item := picker.get_node_or_null("SkillItem%d" % (index + 1)) as Button
		if item == null:
			_fail("combat skill item %d is missing" % (index + 1))
			continue
		_check_control_rect(item, Vector2(index * 50.0, 0), Vector2(40, 46), "combat skill item %d" % (index + 1))
		if item.focus_mode != Control.FOCUS_NONE:
			_fail("combat skill item %d must not draw a focus frame" % (index + 1))
		_check_named_control_rect(item, "Name", Vector2(0, 0), Vector2(40, 10), index)
		_check_named_control_rect(item, "Icon", Vector2(8, 11), Vector2(24, 24), index)
		_check_named_control_rect(item, "Effect", Vector2(0, 37), Vector2(40, 9), index)

func _validate_combat_skill_picker_content(combat: Node) -> void:
	var combat_units: Array = combat.get("units")
	var ready_ally: Dictionary = {}
	for unit in combat_units:
		if str(unit.get("side", "")) == "ally":
			ready_ally = unit
			break
	if ready_ally.is_empty():
		_fail("combat skill picker content validation could not find an ally")
		return
	var previous_auto := bool(ready_ally.get("auto", true))
	var previous_timer := int(ready_ally.get("timer", 0))
	var previous_cooldowns: Dictionary = ready_ally.get("cooldowns", {}).duplicate(true)
	ready_ally["auto"] = false
	ready_ally["timer"] = 0
	ready_ally["cooldowns"] = {}
	combat.call("_refresh_skill_panel")
	var picker := combat.get_node_or_null("SkillPicker") as Control
	if picker == null or not picker.visible:
		_fail("combat skill picker must appear for a ready manual ally")
	else:
		var expected_names := ["斩击", "挑衅", "冲撞"]
		var expected_glyphs := ["斩", "引", "撞"]
		var expected_effects := ["110%", "引敌", "90%"]
		for index in 3:
			var item := picker.get_node_or_null("SkillItem%d" % (index + 1)) as Button
			if item == null:
				continue
			var name_text := item.get_node_or_null("Name/Text") as Label
			var glyph_text := item.get_node_or_null("Icon/Glyph/Text") as Label
			var effect_text := item.get_node_or_null("Effect/Text") as Label
			if name_text == null or name_text.text != expected_names[index]:
				_fail("combat skill item %d name content mismatch" % (index + 1))
			if glyph_text == null or glyph_text.text != expected_glyphs[index]:
				_fail("combat skill item %d glyph content mismatch" % (index + 1))
			if effect_text == null or effect_text.text != expected_effects[index]:
				_fail("combat skill item %d effect content mismatch" % (index + 1))
			var glow := item.get_node_or_null("Glow") as Panel
			if glow == null or glow.visible != (index == 0):
				_fail("combat skill item %d selected glow state mismatch" % (index + 1))
	ready_ally["auto"] = previous_auto
	ready_ally["timer"] = previous_timer
	ready_ally["cooldowns"] = previous_cooldowns
	combat.call("_refresh_skill_panel")

func _validate_combat_enemy_info_ui(combat: Node) -> void:
	var enemy_units: Array = combat.get("units").filter(func(unit): return str(unit.get("side", "")) == "enemy")
	var total_width := enemy_units.size() * 86.0 + maxi(0, enemy_units.size() - 1) * 8.0
	var start_x := (375.0 - total_width) * 0.5
	for index in enemy_units.size():
		var unit: Dictionary = enemy_units[index]
		var host := combat.get("unit_hosts").get(int(unit.get("unit_id", -1))) as Control
		if host == null:
			_fail("combat enemy card %d is missing" % (index + 1))
			continue
		_check_control_rect(host, Vector2(start_x + index * 94.0, 180), Vector2(86, 205), "combat enemy card %d" % (index + 1))
		var portrait := host.get_node_or_null("Portrait") as TextureRect
		if portrait == null:
			_fail("combat enemy portrait %d is missing" % (index + 1))
		else:
			_check_control_rect(portrait, Vector2(-12, 34), Vector2(110, 165), "combat enemy portrait %d" % (index + 1))
			if portrait.texture == null or portrait.texture.get_size() != Vector2(110, 165):
				_fail("combat enemy portrait %d must use the 110x165 Figma export" % (index + 1))
		var info := host.get_node_or_null("InfoOverlay") as Control
		if info == null:
			_fail("combat enemy info %d is missing" % (index + 1))
			continue
		_check_control_rect(info, Vector2(0, 149), Vector2(86, COMBAT_INFO_SIZE.y), "combat enemy info %d" % (index + 1))
		_check_named_control_rect(info, "HpFrame", Vector2(0, 15), Vector2(86, 10), index)
		_check_named_control_rect(info, "Hp", Vector2(3, 18), Vector2(80, 5), index)
		_check_named_control_rect(info, "ActionFrame", Vector2(0, 28), Vector2(86, 6), index)
		_check_named_control_rect(info, "Action", Vector2(3, 30), Vector2(80, 3), index)
		_check_named_control_rect(info, "Name", Vector2(0, 32), Vector2(86, 18), index)
		_check_named_control_rect(info, "RaceFrame", Vector2(0, 14), Vector2(12, 12), index)
		_check_named_control_rect(info, "StatusContainer", Vector2(0, 0), Vector2(31, 14), index)
		var name_button := info.get_node_or_null("Name") as Button
		if name_button != null and (not name_button.disabled or name_button.text != str(unit.get("name", ""))):
			_fail("combat enemy name %d must be read-only and data-driven" % (index + 1))

func _check_named_control_rect(parent: Node, node_name: String, expected_position: Vector2, expected_size: Vector2, hero_index: int) -> void:
	var control := parent.get_node_or_null(node_name) as Control
	if control == null:
		_fail("combat hero %d %s is missing" % [hero_index + 1, node_name])
		return
	_check_control_rect(control, expected_position, expected_size, "combat hero %d %s" % [hero_index + 1, node_name])

func _check_control_rect(control: Control, expected_position: Vector2, expected_size: Vector2, context: String) -> void:
	if not control.position.is_equal_approx(expected_position):
		_fail("%s position mismatch: %s" % [context, control.position])
	if not control.size.is_equal_approx(expected_size):
		_fail("%s size mismatch: %s" % [context, control.size])

func _validate_animation_list(value: Variant, expected_count: int, context: String) -> void:
	if not value is Array:
		_fail("%s animated portrait list is missing" % context)
		return
	var animations: Array = value
	if animations.size() != expected_count:
		_fail("%s expected %d animated portraits, got %d" % [context, expected_count, animations.size()])
	for animation in animations:
		var portrait := animation.get("node") as TextureRect
		var frames: Array = animation.get("frames", [])
		if portrait == null or not is_instance_valid(portrait):
			_fail("%s animated portrait node is invalid" % context)
			continue
		var first_frame_size: Vector2 = frames[0].get_size() if not frames.is_empty() else Vector2.ZERO
		if not first_frame_size.is_equal_approx(HERO_ANIMATION_FRAME_SIZE):
			_fail("%s expected 172x298 frames, got %s" % [context, first_frame_size])
		if frames.size() != HERO_ANIMATION_FRAME_COUNT:
			_fail("%s expected %d frames, got %d" % [context, HERO_ANIMATION_FRAME_COUNT, frames.size()])
		var expected_display_size := CAMP_ANIMATION_DISPLAY_SIZE
		if context == "combat":
			var unit_id := int(animation.get("unit_id", -1))
			expected_display_size = HERO_ANIMATION_DISPLAY_SIZE * float(HERO_PORTRAIT_SCALES.get(unit_id, 1.0))
		if not portrait.size.is_equal_approx(expected_display_size):
			_fail("%s portrait display size mismatch: %s" % [context, portrait.size])
		if portrait.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR:
			_fail("%s portrait must use Linear texture filtering" % context)
		if not is_equal_approx(float(animation.get("frame_duration", 0.0)), 1.0 / HERO_ANIMATION_FPS):
			_fail("%s frame duration mismatch: %s" % [context, animation.get("frame_duration")])
		for frame in frames:
			if not frame.get_size().is_equal_approx(first_frame_size):
				_fail("%s inconsistent frame size: %s" % [context, frame.get_size()])

func _validate_combat_action_assets(combat: Node) -> void:
	var expected := {
		1: ["attack", "defense"],
		2: ["attack", "heal", "lei_ji"],
		3: ["attack", "heal"],
		4: ["fei_jian", "hui_jian"],
	}
	for unit_id in expected.keys():
		var animation := _animation_for_unit(combat.get("animated_portraits"), int(unit_id))
		var action_frames: Dictionary = animation.get("action_frames", {})
		for action_name in expected[unit_id]:
			var frames: Array = action_frames.get(action_name, [])
			if frames.size() != HERO_ANIMATION_FRAME_COUNT:
				_fail("hero %d %s expected %d action frames, got %d" % [unit_id, action_name, HERO_ANIMATION_FRAME_COUNT, frames.size()])
			for frame in frames:
				if not frame.get_size().is_equal_approx(HERO_ANIMATION_FRAME_SIZE):
					_fail("hero %d %s frame size mismatch: %s" % [unit_id, action_name, frame.get_size()])

func _validate_combat_hero_canvas_bottom_alignment(combat: Node) -> void:
	for animation in combat.get("animated_portraits"):
		var unit_id := int(animation.get("unit_id", -1))
		var portrait := animation.get("node") as TextureRect
		if portrait == null:
			_fail("hero %d is missing its portrait for canvas bottom alignment" % unit_id)
			continue
		if not is_equal_approx(portrait.position.y + portrait.size.y, COMBAT_PORTRAIT_VISUAL_BOTTOM):
			_fail("hero %d portrait canvas bottom mismatch: got %.2f expected %.2f" % [unit_id, portrait.position.y + portrait.size.y, COMBAT_PORTRAIT_VISUAL_BOTTOM])

func _validate_shi_yan_cast_a(combat: Node, capture_dir: String) -> void:
	var shi_yan: Dictionary = {}
	var enemy: Dictionary = {}
	for unit in combat.get("units"):
		var hero: Dictionary = unit.get("hero", {})
		if str(hero.get("definitionId", "")) == "hero_wu_xiu_01":
			shi_yan = unit
		elif str(unit.get("side", "")) == "enemy" and enemy.is_empty():
			enemy = unit
	if shi_yan.is_empty() or enemy.is_empty():
		_fail("combat Shi Yan attack validation could not find Shi Yan and one enemy")
		return
	var animation := _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	var action_frames: Dictionary = animation.get("action_frames", {})
	var cast_frames: Array = action_frames.get("attack", [])
	if cast_frames.size() != HERO_ANIMATION_FRAME_COUNT:
		_fail("Shi Yan attack expected %d frames, got %d" % [HERO_ANIMATION_FRAME_COUNT, cast_frames.size()])
		return
	for frame in cast_frames:
		if not frame.get_size().is_equal_approx(HERO_ANIMATION_FRAME_SIZE):
			_fail("Shi Yan Cast A frame size mismatch: %s" % frame.get_size())
	var portrait := animation.get("node") as TextureRect
	if portrait == null or portrait.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR:
		_fail("Shi Yan attack portrait must use Linear texture filtering")
	var portrait_mask := portrait.get_parent() as Control if portrait != null else null
	if portrait_mask == null or not portrait_mask.clip_contents:
		_fail("Shi Yan attack must be clipped by its 86x205 cultivator frame")
	elif not portrait_mask.position.is_equal_approx(Vector2.ZERO) or not portrait_mask.size.is_equal_approx(COMBAT_CARD_SIZE):
		_fail("Shi Yan attack portrait mask must stay inside the frame border")
	var cultivator_host := portrait_mask.get_parent() as Control if portrait_mask != null else null
	var frame_overlay := cultivator_host.get_node_or_null("FrameOverlay") as Panel if cultivator_host != null else null
	if frame_overlay == null or frame_overlay.z_index <= portrait.z_index:
		_fail("Shi Yan attack cultivator frame overlay must render above the portrait")

	var enemy_hp_before := int(enemy.get("hp", 0))
	var enemy_host := combat.get("unit_hosts").get(int(enemy.get("unit_id", -1))) as Control
	var enemy_base_position := enemy_host.position if enemy_host != null else Vector2.ZERO
	combat.call("_resolve_command", shi_yan, "zhan_ji")
	if int(enemy.get("hp", 0)) >= enemy_hp_before:
		_fail("Shi Yan damage was not settled synchronously before Cast A playback")
	animation = _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	if str(animation.get("mode", "")) != "hero_action" or str(animation.get("action_name", "")) != "attack":
		_fail("Shi Yan did not enter attack animation after a resolved damage skill")
	if bool(animation.get("loop", true)):
		_fail("Shi Yan attack must be one-shot")
	if int(animation.get("hit_frame", -1)) != HERO_ANIMATION_ACTION_HIT_FRAME:
		_fail("Shi Yan attack hit frame must be %d" % HERO_ANIMATION_ACTION_HIT_FRAME)
	if not is_equal_approx(float(animation.get("frame_duration", 0.0)), 1.0 / HERO_ANIMATION_FPS):
		_fail("Shi Yan attack must run at %d FPS" % HERO_ANIMATION_FPS)
	var expected_display_size := HERO_ANIMATION_DISPLAY_SIZE * float(HERO_PORTRAIT_SCALES.get(int(shi_yan.get("unit_id", -1)), 1.0))
	if portrait == null or not portrait.size.is_equal_approx(expected_display_size):
		_fail("Shi Yan attack display size mismatch: %s" % (portrait.size if portrait != null else Vector2.ZERO))
	var expected_display_position := _expected_combat_display_position(int(shi_yan.get("unit_id", -1)), expected_display_size)
	if portrait != null and not portrait.position.is_equal_approx(expected_display_position):
		_fail("Shi Yan attack display position mismatch: %s" % portrait.position)
	var idle_frames: Array = animation.get("idle_frames", [])
	if portrait != null and not idle_frames.is_empty():
		var idle_visible_rect := _texture_visible_rect(
			idle_frames[0] as Texture2D,
			animation.get("idle_display_position", expected_display_position),
			animation.get("idle_display_size", expected_display_size)
		)
		var cast_visible_rect := _texture_visible_rect(
			cast_frames[0] as Texture2D,
			portrait.position,
			portrait.size
		)
		# 93.75px 宽的运行时缩放会把源图 1px 的透明边界差异折算成约
		# 0.5px；允许这一确定性采样误差，但仍拦截明显的二次缩放。
		if absf(idle_visible_rect.size.x - cast_visible_rect.size.x) > 1.01 or absf(idle_visible_rect.size.y - cast_visible_rect.size.y) > 1.01:
			_fail("Shi Yan attack first-frame visible size must match Idle: idle=%s attack=%s" % [idle_visible_rect, cast_visible_rect])
		if absf(idle_visible_rect.position.x - cast_visible_rect.position.x) > 1.01 or absf(idle_visible_rect.position.y - cast_visible_rect.position.y) > 1.01:
			_fail("Shi Yan attack first-frame visible anchor must match Idle: idle=%s attack=%s" % [idle_visible_rect, cast_visible_rect])
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("shi_yan_cast_a_first_frame_combat.png"))

	await get_tree().create_timer(1.01).timeout
	animation = _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	if int(animation.get("frame_index", -1)) != HERO_ANIMATION_ACTION_HIT_FRAME:
		_fail("Shi Yan attack expected frame %d at hit timing, got %s" % [HERO_ANIMATION_ACTION_HIT_FRAME, animation.get("frame_index")])
	if int(combat.get("shi_yan_cast_a_hit_count")) != 1:
		_fail("Shi Yan attack must create exactly one target hit VFX at frame %d" % HERO_ANIMATION_ACTION_HIT_FRAME)
	var active_vfx: Dictionary = combat.get("active_target_hit_vfx")
	if not active_vfx.has(int(enemy.get("unit_id", -1))):
		_fail("Shi Yan attack target hit VFX is missing at frame %d" % HERO_ANIMATION_ACTION_HIT_FRAME)
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("shi_yan_cast_a_hit_frame_combat.png"))

	await get_tree().create_timer(1.1).timeout
	animation = _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	if str(animation.get("mode", "")) != "idle":
		_fail("Shi Yan attack did not restore Idle after one complete cycle")
	if not is_equal_approx(float(animation.get("frame_duration", 0.0)), 1.0 / HERO_ANIMATION_FPS):
		_fail("Shi Yan attack did not restore the standard 8 FPS Idle")
	active_vfx = combat.get("active_target_hit_vfx")
	if not active_vfx.is_empty():
		_fail("Shi Yan attack target hit VFX was not released")
	if enemy_host != null and not enemy_host.position.is_equal_approx(enemy_base_position):
		_fail("Shi Yan attack target shake did not restore the target position")
	if portrait != null and (not portrait.size.is_equal_approx(expected_display_size) or not portrait.position.is_equal_approx(expected_display_position)):
		_fail("Shi Yan attack did not restore the Idle display transform")

func _inject_cast_a_candidate(combat: Node, path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var image := Image.new()
	var load_error := image.load(absolute_path)
	if load_error != OK:
		_fail("could not load Cast A candidate: %s" % error_string(load_error))
		return
	if image.get_width() % 4 != 0 or image.get_height() % 4 != 0:
		_fail("attack candidate is not a 4x4 fixed grid: %s" % image.get_size())
		return
	var candidate_frame_size := Vector2(image.get_width() / 4.0, image.get_height() / 4.0)
	if not candidate_frame_size.is_equal_approx(HERO_ANIMATION_FRAME_SIZE):
		_fail("attack candidate must use 172x298 cells: %s" % candidate_frame_size)
		return
	var texture := ImageTexture.create_from_image(image)
	var candidate_frames: Array = combat.call("_sheet_frames", texture, 4, 4)
	var animations: Array = combat.get("animated_portraits")
	for index in animations.size():
		var animation: Dictionary = animations[index]
		if int(animation.get("unit_id", -1)) == 1:
			var action_frames: Dictionary = animation.get("action_frames", {})
			action_frames["attack"] = candidate_frames
			animation["action_frames"] = action_frames
			animations[index] = animation
			combat.set("animated_portraits", animations)
			return
	_fail("could not inject Cast A candidate into Shi Yan portrait")

func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _animation_for_unit(value: Variant, unit_id: int) -> Dictionary:
	if not value is Array:
		return {}
	for animation in value:
		if int(animation.get("unit_id", -1)) == unit_id:
			return animation
	return {}

func _expected_combat_display_position(unit_id: int, display_size: Vector2) -> Vector2:
	return Vector2(
		(HERO_ANIMATION_DISPLAY_SIZE.x - display_size.x) * 0.5,
		COMBAT_PORTRAIT_VISUAL_BOTTOM - display_size.y
	)

func _texture_visible_rect(texture: Texture2D, display_position: Vector2, display_size: Vector2) -> Rect2:
	if texture == null:
		return Rect2()
	var image := texture.get_image()
	if image == null or image.is_empty():
		return Rect2()
	# 用完整非透明外沿验证视觉尺寸，避免 Cast 的抗锯齿边缘造成肉眼可见的二次放大。
	var bounds := _image_alpha_bounds(image, 1.0 / 255.0)
	if bounds.size == Vector2i.ZERO:
		return Rect2()
	var texture_size := Vector2(texture.get_width(), texture.get_height())
	var display_scale := display_size / texture_size
	return Rect2(
		display_position + Vector2(bounds.position) * display_scale,
		Vector2(bounds.size) * display_scale
	)

func _image_alpha_bounds(image: Image, minimum_alpha: float) -> Rect2i:
	var min_x := image.get_width()
	var min_y := image.get_height()
	var max_x := -1
	var max_y := -1
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a < minimum_alpha:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _capture_output_dir() -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-portraits="):
			return argument.trim_prefix("--capture-portraits=")
	return ""

func _capture(path: String) -> void:
	await get_tree().process_frame
	var preview: Image = get_viewport().get_texture().get_image()
	if preview == null or preview.is_empty():
		_fail("capture returned an empty image: %s" % path)
		return
	if preview.get_size() != Vector2i(375, 817):
		preview.resize(375, 817, Image.INTERPOLATE_NEAREST)
	var save_error := preview.save_png(path)
	if save_error != OK:
		_fail("could not save preview %s: %s" % [path, error_string(save_error)])
	else:
		print("ANIMATED_PORTRAIT_PREVIEW=%s" % path)

func _read_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	return JSON.parse_string(file.get_as_text()) if file else null

func _finish() -> void:
	if errors.is_empty():
		print("ANIMATED_PORTRAIT_VALIDATION_OK")
		get_tree().quit(0)
		return
	for message in errors:
		push_error(message)
	print("ANIMATED_PORTRAIT_VALIDATION_FAILED: %d error(s)" % errors.size())
	get_tree().quit(1)

func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
