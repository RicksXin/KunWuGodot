extends Control

## Isolated visual review for the Meowa Shi Yan Cast A candidate.
##
## This scene deliberately loads the candidate from art/ via Image.load_from_file
## so it never promotes the file into res://assets or changes the formal Combat
## presenter. It demonstrates the intended presentation contract only:
## attacker one-shot on the spot, target-local hit VFX at frame 4, and no
## gameplay damage calculation.

const VIEW_SIZE := Vector2(375, 817)
const FRAME_SIZE := Vector2i(86, 205)
const FPS := 10.0
const HIT_FRAME := 4
const HIT_DURATION := 0.18
const LOOP_HOLD := 0.8
const CANDIDATE_RELATIVE_PATH := "art/candidates/combat_animation_pilot_shi_yan/compiled/shi_yan_cast_a_sheet.png"
const CRISP_FALLBACK_RELATIVE_PATH := "art/candidates/combat_animation_pilot_shi_yan/compiled/shi_yan_cast_a_crisp_fallback_sheet.png"
const HIGH_DETAIL_RELATIVE_PATH := "art/candidates/combat_animation_pilot_shi_yan/compiled/shi_yan_cast_a_high_detail_sheet.png"
const HD2X_CRISP_RELATIVE_PATH := "art/candidates/combat_animation_pilot_shi_yan/cast_a_hd2x/compiled_crisp/shi_yan_cast_a_hd2x_crisp_sheet_688x820.png"

var actor_frame: TextureRect
var actor_texture: Texture2D
var source_relative_path := CANDIDATE_RELATIVE_PATH
var texture_frame_size := FRAME_SIZE
var actor_texture_filter := CanvasItem.TEXTURE_FILTER_NEAREST
var show_palm_vfx := true
var light_vfx_layer: Control
var light_ring: Line2D
var light_glow: Line2D
var light_rays: Array[Line2D] = []
var frame_index := 0
var frame_clock := 0.0
var loop_hold_clock := 0.0
var playing := true
var hit_clock := -1.0
var target_shake := 0.0
var capture_path := ""
var frozen := false
var validate_cycle := false

func _ready() -> void:
	custom_minimum_size = VIEW_SIZE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_parse_preview_args()
	_load_candidate()
	_build_actor()
	_build_light_vfx()
	_set_actor_frame(frame_index)
	_update_light_vfx()
	queue_redraw()
	if not capture_path.is_empty():
		call_deferred("_capture_preview")
	elif validate_cycle:
		call_deferred("_validate_one_shot_cycle")

func _load_candidate() -> void:
	var path := ProjectSettings.globalize_path("res://" + source_relative_path)
	var image := Image.load_from_file(path)
	if image == null or image.is_empty():
		push_error("Could not load candidate animation: %s" % path)
		return
	var expected_sheet_size := texture_frame_size * Vector2i(4, 2)
	if image.get_size() != expected_sheet_size:
		push_error("Candidate sheet size mismatch: %s" % image.get_size())
		return
	image.convert(Image.FORMAT_RGBA8)
	actor_texture = ImageTexture.create_from_image(image)

func _build_actor() -> void:
	actor_frame = TextureRect.new()
	actor_frame.name = "ShiYanCastAFrame"
	actor_frame.position = Vector2(56, 150)
	actor_frame.size = Vector2(FRAME_SIZE)
	actor_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	actor_frame.stretch_mode = TextureRect.STRETCH_SCALE
	actor_frame.texture_filter = actor_texture_filter
	actor_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	actor_frame.z_index = 1
	add_child(actor_frame)
	_set_actor_frame(0)

func _build_light_vfx() -> void:
	# This is a separate skill-VFX layer. It is deliberately not painted into
	# the character sheet and can later be replaced by an authored Sprite2D.
	light_vfx_layer = Control.new()
	light_vfx_layer.name = "ShiYanCastALightVfx"
	light_vfx_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	light_vfx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light_vfx_layer.z_index = 2
	add_child(light_vfx_layer)
	light_glow = Line2D.new()
	light_glow.width = 7.0
	light_glow.default_color = Color("#f6b44755")
	light_glow.joint_mode = Line2D.LINE_JOINT_SHARP
	light_glow.begin_cap_mode = Line2D.LINE_CAP_BOX
	light_glow.end_cap_mode = Line2D.LINE_CAP_BOX
	light_vfx_layer.add_child(light_glow)
	light_ring = Line2D.new()
	light_ring.width = 2.0
	light_ring.default_color = Color("#f8d36d")
	light_ring.joint_mode = Line2D.LINE_JOINT_SHARP
	light_ring.closed = true
	light_vfx_layer.add_child(light_ring)
	for _index in 6:
		var ray := Line2D.new()
		ray.width = 2.0
		ray.default_color = Color("#f5c95b")
		ray.joint_mode = Line2D.LINE_JOINT_SHARP
		light_vfx_layer.add_child(ray)
		light_rays.append(ray)
	_update_light_vfx()

func _set_actor_frame(index: int) -> void:
	if actor_frame == null or actor_texture == null:
		return
	var frame := AtlasTexture.new()
	frame.atlas = actor_texture
	frame.region = Rect2(Vector2(index % 4, floori(index / 4)) * Vector2(texture_frame_size), Vector2(texture_frame_size))
	actor_frame.texture = frame

func _parse_preview_args() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--pilot-source=crisp":
			source_relative_path = CRISP_FALLBACK_RELATIVE_PATH
		if argument == "--pilot-source=high-detail":
			source_relative_path = HIGH_DETAIL_RELATIVE_PATH
		if argument == "--pilot-source=hd2x-crisp":
			source_relative_path = HD2X_CRISP_RELATIVE_PATH
			texture_frame_size = Vector2i(172, 410)
			actor_texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		if argument == "--pilot-vfx=off":
			show_palm_vfx = false
		if argument.begins_with("--pilot-frame="):
			var requested := clampi(int(argument.trim_prefix("--pilot-frame=")), 0, 7)
			frame_index = requested
			frozen = true
			playing = false
			_set_actor_frame(frame_index)
			if frame_index == HIT_FRAME:
				hit_clock = 0.0
		if argument.begins_with("--pilot-capture="):
			capture_path = argument.trim_prefix("--pilot-capture=")
		if argument == "--pilot-validate-cycle":
			validate_cycle = true
	_update_light_vfx()

func _process(delta: float) -> void:
	if not frozen and playing:
		frame_clock += delta
		while frame_clock >= 1.0 / FPS:
			frame_clock -= 1.0 / FPS
			_advance_frame()
	if hit_clock >= 0.0:
		if not frozen:
			hit_clock += delta
		if hit_clock > HIT_DURATION:
			hit_clock = -1.0
			target_shake = 0.0
		else:
			target_shake = sin(hit_clock * 72.0) * 2.0
	_update_light_vfx()
	queue_redraw()

func _advance_frame() -> void:
	if frame_index < 7:
		frame_index += 1
		_set_actor_frame(frame_index)
		_update_light_vfx()
		if frame_index == HIT_FRAME:
			hit_clock = 0.0
		return
	loop_hold_clock += 1.0 / FPS
	if loop_hold_clock >= LOOP_HOLD:
		loop_hold_clock = 0.0
		frame_index = 0
		_set_actor_frame(frame_index)
		_update_light_vfx()

func _update_light_vfx() -> void:
	if light_ring == null or actor_frame == null:
		return
	if not show_palm_vfx:
		light_ring.visible = false
		light_glow.visible = false
		for ray in light_rays:
			ray.visible = false
		return
	var active := frame_index >= 3 and frame_index <= 6
	light_ring.visible = active
	light_glow.visible = active
	for ray in light_rays:
		ray.visible = active
	if not active:
		return
	# Palm anchors are local to the fixed 86×205 frame. They follow the hand,
	# while the torso remains owned entirely by the animation sheet.
	var palm_local: Vector2 = {
		3: Vector2(73, 54),
		4: Vector2(72, 61),
		5: Vector2(67, 66),
		6: Vector2(55, 70),
	}.get(frame_index, Vector2(70, 60))
	var center: Vector2 = actor_frame.position + palm_local
	var radius := 8.0 if frame_index < 4 else (13.0 if frame_index == 4 else 10.0)
	var points := PackedVector2Array()
	for index in 12:
		var angle := TAU * float(index) / 12.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	light_ring.points = points
	light_glow.points = points
	for index in light_rays.size():
		var angle := -PI * 0.85 + PI * 1.7 * float(index) / float(light_rays.size() - 1)
		var inner: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + 3.0)
		var outer: Vector2 = center + Vector2(cos(angle), sin(angle)) * (radius + 8.0 + (2.0 if frame_index == 4 else 0.0))
		light_rays[index].points = PackedVector2Array([inner, outer])

func _draw() -> void:
	_draw_background()
	_draw_header()
	_draw_stage()
	_draw_timeline()
	_draw_footer()

func _draw_background() -> void:
	draw_rect(Rect2(Vector2.ZERO, VIEW_SIZE), Color("#08151b"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 336), Vector2(68, 228), Vector2(140, 315), Vector2(214, 188),
		Vector2(284, 292), Vector2(375, 211), Vector2(375, 817), Vector2(0, 817)
	]), Color("#13272c"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, 496), Vector2(108, 439), Vector2(262, 554), Vector2(375, 481),
		Vector2(375, 817), Vector2(0, 817)
	]), Color("#1d2f2f"))
	for index in 7:
		draw_line(Vector2(0, 539 + index * 38), Vector2(375, 559 + index * 38), Color("#73503869"), 2.0)

func _draw_header() -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(63, 33), "石岩 · Cast A 试点", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("#c6cdb9"))
	draw_string(font, Vector2(64, 57), "隔离预览｜原地施法 + 目标命中特效", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#91a8a0"))
	draw_string(font, Vector2(13, 83), "8 帧 · 10 FPS · one-shot", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#849d9c"))
	draw_string(font, Vector2(261, 83), "hit_frame = 4", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e2c57f"))

func _draw_stage() -> void:
	var font := ThemeDB.fallback_font
	# Two independent stage cards. The actor TextureRect is drawn above the left card.
	draw_rect(Rect2(36, 138, 126, 239), Color("#263a3e"), true)
	draw_rect(Rect2(36, 138, 126, 239), Color("#537a7d"), false, 2.0)
	draw_rect(Rect2(214, 138, 126, 239), Color("#3a312e"), true)
	draw_rect(Rect2(214, 138, 126, 239), Color("#895344"), false, 2.0)
	draw_string(font, Vector2(52, 394), "攻击者 · 石岩", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d5d7c5"))
	draw_string(font, Vector2(236, 394), "受击方 · 残禁石傀", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#d5d7c5"))

	# The target is intentionally a placeholder silhouette; VFX is drawn on this card only.
	var offset := Vector2(target_shake, 0)
	var target_center := Vector2(277, 245) + offset
	var target_color := Color("#f0f0dd") if hit_clock >= 0.0 else Color("#4a4f4d")
	draw_circle(target_center + Vector2(0, -47), 27, target_color)
	draw_rect(Rect2(target_center + Vector2(-36, -28), Vector2(72, 101)), target_color, true)
	draw_line(target_center + Vector2(-26, -6), target_center + Vector2(27, -22), Color("#ae523c"), 3.0)
	if hit_clock >= 0.0:
		_draw_hit_vfx(target_center)

func _draw_hit_vfx(center: Vector2) -> void:
	var progress := clampf(hit_clock / HIT_DURATION, 0.0, 1.0)
	var alpha := 1.0 - progress
	var burst_color := Color(1.0, 0.85, 0.42, 0.95 * alpha)
	for index in 8:
		var angle := TAU * float(index) / 8.0
		var inner := center + Vector2(cos(angle), sin(angle)) * 28.0
		var outer := center + Vector2(cos(angle), sin(angle)) * (42.0 + progress * 9.0)
		draw_line(inner, outer, burst_color, 2.0)
	var diamond := PackedVector2Array([
		center + Vector2(0, -17), center + Vector2(17, 0),
		center + Vector2(0, 17), center + Vector2(-17, 0)
	])
	draw_polyline(diamond, Color(1.0, 0.95, 0.70, 0.9 * alpha), 2.0, true)
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(29, -28), "-18", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(1.0, 0.86, 0.47, alpha))

func _draw_timeline() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(36, 432, 304, 106), Color("#0a1114dc"), true)
	draw_rect(Rect2(36, 432, 304, 106), Color("#657762"), false, 2.0)
	draw_string(font, Vector2(51, 457), "表现时间线", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#abb8a6"))
	for index in 8:
		var rect := Rect2(51 + index * 34, 470, 28, 30)
		var fill := Color("#6a5133") if index == HIT_FRAME else Color("#1d302f")
		if index == frame_index:
			fill = Color("#4b9f7e") if index != HIT_FRAME else Color("#b47c3a")
		draw_rect(rect, fill, true)
		draw_rect(rect, Color("#d5d6b7") if index == frame_index else Color("#52655b"), false, 1.0)
		draw_string(font, rect.position + Vector2(10, 20), str(index), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f5efd8"))
	draw_string(font, Vector2(51, 523), "第 4 帧触发目标闪白 / 轻震 / 独立命中特效", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#e2c57f"))

func _draw_footer() -> void:
	var font := ThemeDB.fallback_font
	var state := "命中特效播放中" if hit_clock >= 0.0 else ("施法帧 %d" % frame_index)
	draw_string(font, Vector2(50, 582), state, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("#d8dec7"))
	draw_string(font, Vector2(50, 607), "动画只负责表现；伤害仍由 CombatEvent 决定。", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#91a8a0"))
	draw_string(font, Vector2(50, 640), "候选阶段：未晋升 assets/，未改正式 Combat 场景。", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#91a8a0"))
	draw_string(font, Vector2(50, 698), "视觉复核重点：身体锚点、掌击姿态、第 4 帧命中节奏。", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#d5d6b7"))

func _capture_preview() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Pilot preview capture returned an empty image")
		get_tree().quit(1)
		return
	var error := image.save_png(capture_path)
	if error != OK:
		push_error("Could not save pilot preview capture: %s" % error_string(error))
		get_tree().quit(1)
		return
	print("COMBAT_ANIMATION_PILOT_CAPTURE=%s" % capture_path)
	get_tree().quit(0)

func _validate_one_shot_cycle() -> void:
	# Frame 7 is reached after 0.7 seconds and then held before the review loop restarts.
	await get_tree().create_timer(1.0).timeout
	if actor_texture == null or frame_index != 7:
		push_error("Cast A one-shot validation failed: frame=%d texture=%s" % [frame_index, actor_texture])
		get_tree().quit(1)
		return
	print("COMBAT_ANIMATION_PILOT_CYCLE_OK source=%s texture_frame=%s fps=%.1f hit_frame=%d" % [source_relative_path, texture_frame_size, FPS, HIT_FRAME])
	get_tree().quit(0)
