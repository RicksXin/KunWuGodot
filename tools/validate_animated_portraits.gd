extends Node

const CAMP_SCENE = preload("res://scenes/camp.tscn")
const COMBAT_SCENE = preload("res://scenes/combat.tscn")
const SHI_YAN_IDLE_STANDARD_FPS := 8.0
const SHI_YAN_IDLE_STANDARD_FRAME_COUNT := 16
const SHI_YAN_CAST_A_WIDE_PRESENTATION_SCALE := 0.98
const SHI_YAN_CAST_A_WIDE_VERTICAL_OFFSET := 0.0

var errors: Array[String] = []
var cast_a_candidate_path := ""
var expected_cast_frame_size := Vector2(240, 410)

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
	# 石岩 HD2x Idle 为标准 8 FPS × 16 帧；多运行 0.1 秒覆盖一个完整循环。
	await get_tree().create_timer(float(SHI_YAN_IDLE_STANDARD_FRAME_COUNT) / SHI_YAN_IDLE_STANDARD_FPS + 0.1).timeout
	_validate_animation_list(camp.get("animated_portraits"), 3, "camp")
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("animated_portraits_camp.png"))
	camp.queue_free()
	await get_tree().process_frame

	game.set("profile", defaults.duplicate(true))
	game.get("profile")["expedition"] = {
		"mapId": "map_01",
		"partyPresetId": "party_01",
		"partyMemberIds": ["hero_wu_xiu_01", "hero_fa_xiu_01", "hero_yi_xiu_01", "hero_qian_xiu_01"],
		"encounterId": "can_jin_shi_kui",
		"mapObjectId": "m1_enemy_stone",
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
	# 结算循环暂停，但 Combat._process() 仍会推进人物表现，便于隔离验证完整动画周期。
	combat.set("finished", true)
	cast_a_candidate_path = _argument_value("--cast-a-candidate=")
	if not cast_a_candidate_path.is_empty():
		_inject_cast_a_candidate(combat, cast_a_candidate_path)
	await get_tree().create_timer(float(SHI_YAN_IDLE_STANDARD_FRAME_COUNT) / SHI_YAN_IDLE_STANDARD_FPS + 0.1).timeout
	_validate_animation_list(combat.get("animated_portraits"), 3, "combat")
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("animated_portraits_combat.png"))
	await _validate_shi_yan_cast_a(combat, capture_dir)
	combat.queue_free()
	await get_tree().process_frame
	_finish()

func _validate_animation_list(value: Variant, expected_count: int, context: String) -> void:
	if not value is Array:
		_fail("%s animated portrait list is missing" % context)
		return
	var animations: Array = value
	var hd2x_count := 0
	var legacy_count := 0
	if animations.size() != expected_count:
		_fail("%s expected %d animated portraits, got %d" % [context, expected_count, animations.size()])
	for animation in animations:
		var portrait := animation.get("node") as TextureRect
		var frames: Array = animation.get("frames", [])
		if portrait == null or not is_instance_valid(portrait):
			_fail("%s animated portrait node is invalid" % context)
			continue
		var first_frame_size: Vector2 = frames[0].get_size() if not frames.is_empty() else Vector2.ZERO
		var expected_portrait_size := Vector2.ZERO
		var expected_filter := CanvasItem.TEXTURE_FILTER_NEAREST
		var expected_duration := 1.0 / 6.0
		var expected_frame_count := 8
		if first_frame_size.is_equal_approx(Vector2(172, 410)):
			hd2x_count += 1
			expected_portrait_size = Vector2(86, 205)
			expected_filter = CanvasItem.TEXTURE_FILTER_LINEAR
			expected_duration = 1.0 / SHI_YAN_IDLE_STANDARD_FPS
			expected_frame_count = SHI_YAN_IDLE_STANDARD_FRAME_COUNT
		elif first_frame_size.is_equal_approx(Vector2(86, 149)):
			legacy_count += 1
			expected_portrait_size = Vector2(86, 149)
		else:
			_fail("%s unsupported frame size: %s" % [context, first_frame_size])
		if frames.size() != expected_frame_count:
			_fail("%s expected %d frames for %s cells, got %d" % [context, expected_frame_count, first_frame_size, frames.size()])
		if not portrait.size.is_equal_approx(expected_portrait_size):
			_fail("%s portrait size mismatch for %s frame: %s" % [context, first_frame_size, portrait.size])
		if portrait.texture_filter != expected_filter:
			_fail("%s texture filter mismatch for %s frame: %s" % [context, first_frame_size, portrait.texture_filter])
		if not is_equal_approx(float(animation.get("frame_duration", 0.0)), expected_duration):
			_fail("%s frame duration mismatch for %s frame: %s" % [context, first_frame_size, animation.get("frame_duration")])
		for frame in frames:
			if not frame.get_size().is_equal_approx(first_frame_size):
				_fail("%s inconsistent frame size: %s" % [context, frame.get_size()])
	if hd2x_count != 1 or legacy_count != 2:
		_fail("%s expected 1 HD2x and 2 legacy portraits, got %d HD2x and %d legacy" % [context, hd2x_count, legacy_count])

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
		_fail("combat Cast A validation could not find Shi Yan and one enemy")
		return
	var animation := _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	var cast_frames: Array = animation.get("cast_a_frames", [])
	if cast_frames.size() != 8:
		_fail("Shi Yan Cast A expected 8 frames, got %d" % cast_frames.size())
		return
	for frame in cast_frames:
		if not frame.get_size().is_equal_approx(expected_cast_frame_size):
			_fail("Shi Yan Cast A frame size mismatch: %s" % frame.get_size())
	var portrait := animation.get("node") as TextureRect
	if portrait == null or portrait.texture_filter != CanvasItem.TEXTURE_FILTER_LINEAR:
		_fail("Shi Yan Cast A portrait must use Linear texture filtering")
	var portrait_mask := portrait.get_parent() as Control if portrait != null else null
	if portrait_mask == null or not portrait_mask.clip_contents:
		_fail("Shi Yan Cast A must be clipped by its 86x205 cultivator frame")
	elif not portrait_mask.position.is_equal_approx(Vector2(1, 1)) or not portrait_mask.size.is_equal_approx(Vector2(84, 203)):
		_fail("Shi Yan Cast A portrait mask must stay inside the frame border")
	var cultivator_host := portrait_mask.get_parent() as Control if portrait_mask != null else null
	var frame_overlay := cultivator_host.get_node_or_null("FrameOverlay") as Panel if cultivator_host != null else null
	if frame_overlay == null or frame_overlay.z_index <= portrait.z_index:
		_fail("Shi Yan Cast A cultivator frame overlay must render above the portrait")

	var enemy_hp_before := int(enemy.get("hp", 0))
	var enemy_host := combat.get("unit_hosts").get(int(enemy.get("unit_id", -1))) as Control
	var enemy_base_position := enemy_host.position if enemy_host != null else Vector2.ZERO
	combat.call("_resolve_command", shi_yan, "zhan_ji")
	if int(enemy.get("hp", 0)) >= enemy_hp_before:
		_fail("Shi Yan damage was not settled synchronously before Cast A playback")
	animation = _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	if str(animation.get("mode", "")) != "shi_yan_cast_a":
		_fail("Shi Yan did not enter Cast A after a resolved damage skill")
	if bool(animation.get("loop", true)):
		_fail("Shi Yan Cast A must be one-shot")
	if int(animation.get("hit_frame", -1)) != 4:
		_fail("Shi Yan Cast A hit frame must be 4")
	if not is_equal_approx(float(animation.get("frame_duration", 0.0)), 0.1):
		_fail("Shi Yan Cast A must run at 10 FPS")
	var presentation_scale := SHI_YAN_CAST_A_WIDE_PRESENTATION_SCALE if expected_cast_frame_size.x > 172.0 else 1.0
	var expected_display_size := expected_cast_frame_size / 2.0 * presentation_scale
	if portrait == null or not portrait.size.is_equal_approx(expected_display_size):
		_fail("Shi Yan Cast A display size mismatch: %s" % (portrait.size if portrait != null else Vector2.ZERO))
	var mask_origin := portrait_mask.position if portrait_mask != null else Vector2.ZERO
	var vertical_offset := SHI_YAN_CAST_A_WIDE_VERTICAL_OFFSET if expected_cast_frame_size.x > 172.0 else 0.0
	var expected_display_position := Vector2((86.0 - expected_display_size.x) * 0.5, vertical_offset) - mask_origin
	if portrait != null and not portrait.position.is_equal_approx(expected_display_position):
		_fail("Shi Yan Cast A display position mismatch: %s" % portrait.position)
	var idle_frames: Array = animation.get("idle_frames", [])
	if portrait != null and not idle_frames.is_empty():
		var idle_visible_rect := _texture_visible_rect(
			idle_frames[0] as Texture2D,
			animation.get("idle_display_position", Vector2(-1, -1)),
			animation.get("idle_display_size", Vector2(86, 205))
		)
		var cast_visible_rect := _texture_visible_rect(
			cast_frames[0] as Texture2D,
			portrait.position,
			portrait.size
		)
		if absf(idle_visible_rect.size.x - cast_visible_rect.size.x) > 0.51 or absf(idle_visible_rect.size.y - cast_visible_rect.size.y) > 0.51:
			_fail("Shi Yan Cast A first-frame visible size must match Idle: idle=%s cast=%s" % [idle_visible_rect, cast_visible_rect])
		if absf(idle_visible_rect.position.x - cast_visible_rect.position.x) > 0.51 or absf(idle_visible_rect.position.y - cast_visible_rect.position.y) > 0.51:
			_fail("Shi Yan Cast A first-frame visible anchor must match Idle: idle=%s cast=%s" % [idle_visible_rect, cast_visible_rect])
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("shi_yan_cast_a_first_frame_combat.png"))

	await get_tree().create_timer(0.43).timeout
	animation = _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	if int(animation.get("frame_index", -1)) != 4:
		_fail("Shi Yan Cast A expected frame 4 at hit timing, got %s" % animation.get("frame_index"))
	if int(combat.get("shi_yan_cast_a_hit_count")) != 1:
		_fail("Shi Yan Cast A must create exactly one target hit VFX at frame 4")
	var active_vfx: Dictionary = combat.get("active_target_hit_vfx")
	if not active_vfx.has(int(enemy.get("unit_id", -1))):
		_fail("Shi Yan Cast A target hit VFX is missing at frame 4")
	if not capture_dir.is_empty():
		await _capture(capture_dir.path_join("shi_yan_cast_a_hit_frame_combat.png"))

	await get_tree().create_timer(0.45).timeout
	animation = _animation_for_unit(combat.get("animated_portraits"), int(shi_yan.get("unit_id", -1)))
	if str(animation.get("mode", "")) != "idle":
		_fail("Shi Yan Cast A did not restore Idle after one complete cycle")
	if not is_equal_approx(float(animation.get("frame_duration", 0.0)), 1.0 / SHI_YAN_IDLE_STANDARD_FPS):
		_fail("Shi Yan Cast A did not restore the standard 8 FPS Idle")
	active_vfx = combat.get("active_target_hit_vfx")
	if not active_vfx.is_empty():
		_fail("Shi Yan Cast A target hit VFX was not released")
	if enemy_host != null and not enemy_host.position.is_equal_approx(enemy_base_position):
		_fail("Shi Yan Cast A target shake did not restore the target position")
	if portrait != null and (not portrait.size.is_equal_approx(Vector2(86, 205)) or not portrait.position.is_equal_approx(Vector2(-1, -1))):
		_fail("Shi Yan Cast A did not restore the Idle display transform")

func _inject_cast_a_candidate(combat: Node, path: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path) if path.begins_with("res://") else path
	var image := Image.new()
	var load_error := image.load(absolute_path)
	if load_error != OK:
		_fail("could not load Cast A candidate: %s" % error_string(load_error))
		return
	if image.get_width() % 4 != 0 or image.get_height() % 2 != 0:
		_fail("Cast A candidate is not a 4x2 fixed grid: %s" % image.get_size())
		return
	expected_cast_frame_size = Vector2(image.get_width() / 4.0, image.get_height() / 2.0)
	var texture := ImageTexture.create_from_image(image)
	var candidate_frames: Array = combat.call("_sheet_frames", texture, 4, 2)
	var animations: Array = combat.get("animated_portraits")
	for index in animations.size():
		var animation: Dictionary = animations[index]
		if int(animation.get("unit_id", -1)) == 1:
			animation["cast_a_frames"] = candidate_frames
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
