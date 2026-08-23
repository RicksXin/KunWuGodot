extends Control

const SOURCE_ATLAS := "res://art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/compiled/shi_yan_idle_breath_sheet_344x410.png"
const HEADLESS_CAPTURE := "res://art/candidates/combat_animation_pilot_shi_yan/idle_breathing_3.0/review/shi_yan_idle_candidate_godot_preview.png"
const FRAME_SIZE := Vector2i(86, 205)
const COLUMNS := 4
const ROWS := 2
const FPS := 8.0

var _frames: Array[Texture2D] = []
var _portraits: Array[TextureRect] = []
var _elapsed := 0.0
var _frame_index := 0


func _ready() -> void:
	_build_background()
	var load_error := _load_candidate_frames()
	if load_error != OK:
		_add_label(self, "无法读取候选图集：%s" % error_string(load_error), Rect2(20, 380, 335, 40), 14, Color("#f28f74"), HORIZONTAL_ALIGNMENT_CENTER)
		set_process(false)
		return
	_add_label(self, "石岩 · Idle 呼吸态候选", Rect2(20, 18, 335, 30), 19, Color("#edddad"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(self, "1× 战斗槽实际尺寸 · 86×205", Rect2(20, 52, 335, 22), 12, Color("#9eb3ad"), HORIZONTAL_ALIGNMENT_CENTER)
	_build_unit_slot(Vector2(144.5, 78), 1)
	_add_label(self, "2× 最近邻检查 · 仅供观察像素与循环", Rect2(20, 300, 335, 22), 12, Color("#9eb3ad"), HORIZONTAL_ALIGNMENT_CENTER)
	_build_unit_slot(Vector2(101.5, 328), 2)
	_add_label(self, "8 FPS · 空格暂停/继续 · 候选未进入 assets/", Rect2(20, 760, 335, 22), 11, Color("#738c88"), HORIZONTAL_ALIGNMENT_CENTER)
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
		_frame_index = (_frame_index + 1) % _frames.size()
		_show_frame(_frame_index)


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		set_process(not is_processing())
		get_viewport().set_input_as_handled()


func _finish_headless_validation() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	print("shi_yan_idle_candidate_preview_ok frames=%d frame_size=%s fps=%.1f" % [_frames.size(), FRAME_SIZE, FPS])
	get_tree().quit()


func _finish_visual_capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	var capture_path := ProjectSettings.globalize_path(HEADLESS_CAPTURE)
	DirAccess.make_dir_recursive_absolute(capture_path.get_base_dir())
	var capture_error := get_viewport().get_texture().get_image().save_png(capture_path)
	print("shi_yan_idle_candidate_capture frames=%d frame_size=%s fps=%.1f capture=%s error=%s" % [_frames.size(), FRAME_SIZE, FPS, HEADLESS_CAPTURE, error_string(capture_error)])
	get_tree().quit()


func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("#0a171d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var upper := ColorRect.new()
	upper.color = Color("#13272c")
	upper.position = Vector2(0, 250)
	upper.size = Vector2(375, 567)
	upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(upper)


func _load_candidate_frames() -> Error:
	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(SOURCE_ATLAS))
	if error != OK:
		return error
	if image.get_size() != FRAME_SIZE * Vector2i(COLUMNS, ROWS):
		return ERR_INVALID_DATA
	var atlas := ImageTexture.create_from_image(image)
	for index in COLUMNS * ROWS:
		var frame := AtlasTexture.new()
		frame.atlas = atlas
		frame.region = Rect2(Vector2(index % COLUMNS, index / COLUMNS) * Vector2(FRAME_SIZE), Vector2(FRAME_SIZE))
		_frames.append(frame)
	return OK


func _build_unit_slot(position: Vector2, scale_factor: int) -> void:
	var scale_value := float(scale_factor)
	var host := Panel.new()
	host.position = position
	host.size = Vector2(FRAME_SIZE) * scale_value
	host.add_theme_stylebox_override("panel", _style_box(Color("#2a3a41eb"), Color("#537a7d"), 2 * scale_factor))
	add_child(host)

	var portrait := TextureRect.new()
	portrait.position = Vector2.ZERO
	portrait.size = Vector2(FRAME_SIZE) * scale_value
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(portrait)
	_portraits.append(portrait)

	var info := Panel.new()
	info.position = Vector2(1, 149) * scale_value
	info.size = Vector2(84, 56) * scale_value
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.add_theme_stylebox_override("panel", _style_box(Color("#070a0ddc"), Color.TRANSPARENT, 0))
	host.add_child(info)

	_add_label(host, "石岩", _scaled_rect(Rect2(4, 145, 78, 18), scale_value), 10 * scale_factor, Color("#ebe6cf"), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(host, "人", _scaled_rect(Rect2(2, 164, 12, 12), scale_value), 8 * scale_factor, Color("#b7d8cf"), HORIZONTAL_ALIGNMENT_CENTER)
	var hp_background := ColorRect.new()
	hp_background.color = Color("#101719")
	hp_background.position = Vector2(18, 169) * scale_value
	hp_background.size = Vector2(62, 8) * scale_value
	hp_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(hp_background)
	var hp_fill := ColorRect.new()
	hp_fill.color = Color("#4b9f7e")
	hp_fill.position = Vector2(19, 170) * scale_value
	hp_fill.size = Vector2(53, 6) * scale_value
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(hp_fill)
	_add_label(host, "100/100", _scaled_rect(Rect2(18, 167, 62, 10), scale_value), 7 * scale_factor, Color("#f5efd8"), HORIZONTAL_ALIGNMENT_CENTER)
	var action := ColorRect.new()
	action.color = Color("#4bccd0")
	action.position = Vector2(18, 180) * scale_value
	action.size = Vector2(45, 5) * scale_value
	action.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(action)
	_add_label(host, "自动", _scaled_rect(Rect2(4, 186, 78, 14), scale_value), 8 * scale_factor, Color("#dbc482"), HORIZONTAL_ALIGNMENT_CENTER)


func _show_frame(index: int) -> void:
	if index < 0 or index >= _frames.size():
		return
	for portrait in _portraits:
		portrait.texture = _frames[index]


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
