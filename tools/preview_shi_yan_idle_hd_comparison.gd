extends Control

const PIXEL_SHEET := "res://art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/compiled/shi_yan_idle_breath_sheet_344x410.png"
const HD2X_SHEET := "res://art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/compiled_hd2x/shi_yan_idle_breath_hd2x_sheet_688x820.png"
const HD2X_CRISP_SHEET := "res://art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/compiled_hd2x_crisp/shi_yan_idle_breath_hd2x_crisp_sheet_688x820.png"
const CAPTURE_PATH := "res://art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/review/shi_yan_idle_hd2x_crisp_comparison_godot.png"
const LOGICAL_FRAME_SIZE := Vector2i(86, 205)
const HD2X_FRAME_SIZE := Vector2i(172, 410)
const COLUMNS := 4
const ROWS := 2
const FPS := 8.0

var _pixel_frames: Array[Texture2D] = []
var _hd2x_frames: Array[Texture2D] = []
var _crisp_frames: Array[Texture2D] = []
var _targets: Array[Dictionary] = []
var _elapsed := 0.0
var _frame_index := 0


func _ready() -> void:
	_build_background()
	_pixel_frames = _load_frames(PIXEL_SHEET, LOGICAL_FRAME_SIZE)
	_hd2x_frames = _load_frames(HD2X_SHEET, HD2X_FRAME_SIZE)
	_crisp_frames = _load_frames(HD2X_CRISP_SHEET, HD2X_FRAME_SIZE)
	if _pixel_frames.size() != 8 or _hd2x_frames.size() != 8 or _crisp_frames.size() != 8:
		_add_label(self, "候选图集读取失败", Rect2(20, 380, 335, 40), 16, Color("#f28f74"), HORIZONTAL_ALIGNMENT_CENTER)
		set_process(false)
		return

	_add_label(self, "石岩呼吸态 · 清晰度对比", Rect2(12, 14, 351, 30), 18, Color("#edddad"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(self, "实际 86×205 逻辑槽", Rect2(12, 44, 351, 20), 11, Color("#9eb3ad"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(self, "1×", Rect2(21, 66, 100, 18), 10, Color("#d0a884"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(self, "2×", Rect2(137, 66, 100, 18), 10, Color("#9fd0c4"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(self, "2× 锐化", Rect2(253, 66, 100, 18), 10, Color("#e5c778"), HORIZONTAL_ALIGNMENT_CENTER)
	_build_unit_slot(Vector2(28, 88), 1, _pixel_frames, CanvasItem.TEXTURE_FILTER_NEAREST)
	_build_unit_slot(Vector2(144, 88), 1, _hd2x_frames, CanvasItem.TEXTURE_FILTER_LINEAR)
	_build_unit_slot(Vector2(260, 88), 1, _crisp_frames, CanvasItem.TEXTURE_FILTER_LINEAR)

	_add_label(self, "2× 观察尺寸：左侧平滑，右侧轻锐化", Rect2(10, 304, 355, 22), 10, Color("#9eb3ad"), HORIZONTAL_ALIGNMENT_CENTER)
	_build_unit_slot(Vector2(10, 332), 2, _hd2x_frames, CanvasItem.TEXTURE_FILTER_LINEAR)
	_build_unit_slot(Vector2(193, 332), 2, _crisp_frames, CanvasItem.TEXTURE_FILTER_LINEAR)
	_add_label(self, "8 FPS · 空格暂停/继续 · 两版均为候选", Rect2(20, 764, 335, 20), 10, Color("#738c88"), HORIZONTAL_ALIGNMENT_CENTER)
	_show_frame(0)

	if DisplayServer.get_name() == "headless":
		call_deferred("_finish_headless_validation")
	elif "--candidate-capture" in OS.get_cmdline_user_args():
		call_deferred("_finish_visual_capture")


func _process(delta: float) -> void:
	_elapsed += delta
	var frame_duration := 1.0 / FPS
	while _elapsed >= frame_duration:
		_elapsed -= frame_duration
		_frame_index = (_frame_index + 1) % 8
		_show_frame(_frame_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		set_process(not is_processing())
		get_viewport().set_input_as_handled()


func _finish_headless_validation() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("shi_yan_idle_hd_comparison_ok pixel_frames=%d hd_frames=%d crisp_frames=%d logical=%s hd2x=%s fps=%.1f" % [_pixel_frames.size(), _hd2x_frames.size(), _crisp_frames.size(), LOGICAL_FRAME_SIZE, HD2X_FRAME_SIZE, FPS])
	get_tree().quit()


func _finish_visual_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var capture_path := ProjectSettings.globalize_path(CAPTURE_PATH)
	DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
	var capture_error := get_viewport().get_texture().get_image().save_png(capture_path)
	print("shi_yan_idle_hd_comparison_capture path=%s error=%s" % [CAPTURE_PATH, error_string(capture_error)])
	get_tree().quit()


func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("#0a171d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var lower := ColorRect.new()
	lower.color = Color("#13272c")
	lower.position = Vector2(0, 292)
	lower.size = Vector2(375, 525)
	lower.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lower)


func _load_frames(path: String, frame_size: Vector2i) -> Array[Texture2D]:
	var output: Array[Texture2D] = []
	var image := Image.new()
	if image.load(ProjectSettings.globalize_path(path)) != OK:
		return output
	if image.get_size() != frame_size * Vector2i(COLUMNS, ROWS):
		return output
	var atlas := ImageTexture.create_from_image(image)
	for index in COLUMNS * ROWS:
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		var atlas_position := Vector2(index % COLUMNS, floori(index / float(COLUMNS))) * Vector2(frame_size)
		frame.region = Rect2(atlas_position, Vector2(frame_size))
		output.append(frame)
	return output


func _build_unit_slot(position: Vector2, ui_scale: int, frames: Array[Texture2D], filter: TextureFilter) -> void:
	var scale_value := float(ui_scale)
	var host := Panel.new()
	host.position = position
	host.size = Vector2(LOGICAL_FRAME_SIZE) * scale_value
	host.add_theme_stylebox_override("panel", _style_box(Color("#2a3a41eb"), Color("#537a7d"), maxi(1, ui_scale)))
	add_child(host)

	var portrait := TextureRect.new()
	portrait.size = Vector2(LOGICAL_FRAME_SIZE) * scale_value
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = filter
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(portrait)
	_targets.append({"node": portrait, "frames": frames})

	var info := Panel.new()
	info.position = Vector2(1, 149) * scale_value
	info.size = Vector2(84, 56) * scale_value
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_stylebox_override("panel", _style_box(Color("#070a0ddc"), Color.TRANSPARENT, 0))
	host.add_child(info)
	_add_label(host, "石岩", _scaled_rect(Rect2(4, 145, 78, 18), scale_value), 10 * ui_scale, Color("#ebe6cf"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(host, "人", _scaled_rect(Rect2(2, 164, 12, 12), scale_value), 8 * ui_scale, Color("#b7d8cf"), HORIZONTAL_ALIGNMENT_CENTER)

	var hp_background := ColorRect.new()
	hp_background.color = Color("#101719")
	hp_background.position = Vector2(18, 169) * scale_value
	hp_background.size = Vector2(62, 8) * scale_value
	host.add_child(hp_background)
	var hp_fill := ColorRect.new()
	hp_fill.color = Color("#4b9f7e")
	hp_fill.position = Vector2(19, 170) * scale_value
	hp_fill.size = Vector2(53, 6) * scale_value
	host.add_child(hp_fill)
	_add_label(host, "100/100", _scaled_rect(Rect2(18, 167, 62, 10), scale_value), 7 * ui_scale, Color("#f5efd8"), HORIZONTAL_ALIGNMENT_CENTER)

	var action := ColorRect.new()
	action.color = Color("#4bccd0")
	action.position = Vector2(18, 180) * scale_value
	action.size = Vector2(45, 5) * scale_value
	host.add_child(action)
	_add_label(host, "自动", _scaled_rect(Rect2(4, 186, 78, 14), scale_value), 8 * ui_scale, Color("#dbc482"), HORIZONTAL_ALIGNMENT_CENTER)


func _show_frame(index: int) -> void:
	for target in _targets:
		var portrait := target.get("node") as TextureRect
		var frames: Array[Texture2D] = target.get("frames", [])
		if portrait != null and index >= 0 and index < frames.size():
			portrait.texture = frames[index]


func _style_box(background: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	return style


func _scaled_rect(rect: Rect2, scale_value: float) -> Rect2:
	return Rect2(rect.position * scale_value, rect.size * scale_value)


func _add_label(parent: Control, text: String, rect: Rect2, font_size: int, color: Color, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label
