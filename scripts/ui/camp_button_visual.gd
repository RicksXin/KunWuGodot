class_name KWCampButtonVisual
extends Control

## Godot port of the original CampResizableButtonStyle.
## The Button keeps the full touch target; only this visual child scales on press.

var button: Button
var kind := "footer"
var selected := false
var visual_size := Vector2.ZERO
var _last_state := ""
var _last_size := Vector2.ZERO
var _last_button_size := Vector2.ZERO
var _press_tween: Tween

func configure(owner: Button, button_kind: String, is_selected: bool, requested_visual_size: Vector2) -> void:
	button = owner
	kind = "inline" if button_kind == "inline" else "footer"
	selected = is_selected
	visual_size = requested_visual_size
	name = "NativeVisual"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	for state_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	button.button_down.connect(_on_button_down)
	button.button_up.connect(_on_button_up)
	_sync_layout()
	set_process(true)
	queue_redraw()

func _process(_delta: float) -> void:
	if not is_instance_valid(button):
		return
	var next_state := "disabled" if button.disabled else ("selected" if selected else "default")
	if button.size != _last_button_size:
		_sync_layout()
	if next_state != _last_state or size != _last_size:
		_last_state = next_state
		_last_size = size
		_sync_pivot()
		queue_redraw()

func _draw() -> void:
	if not is_instance_valid(button) or size.x < 6.0 or size.y < 6.0:
		return
	var state := "disabled" if button.disabled else ("selected" if selected else "default")
	var colors := _palette(kind, state)
	var radius := 4 if kind == "footer" else 3
	var full_rect := Rect2(Vector2.ZERO, size)
	draw_style_box(_fill_box(colors["base"], radius), full_rect)

	# The original Cocos Graphics layer darkened the lower half while leaving
	# the warm/teal upper plane and its one-pixel highlight visible.
	var depth_height := maxf(1.0, size.y / 2.0 - 2.0)
	var depth_rect := Rect2(2.0, size.y / 2.0, maxf(1.0, size.x - 4.0), depth_height)
	draw_style_box(_fill_box(colors["depth"], maxi(0, radius - 1)), depth_rect)

	draw_style_box(_outline_box(colors["outer"], radius), full_rect.grow(-0.5))
	var inner_rect := full_rect.grow(-2.5)
	if inner_rect.size.x > 1.0 and inner_rect.size.y > 1.0:
		draw_style_box(_outline_box(colors["inner"], maxi(0, radius - 1)), inner_rect)
	if size.x > 12.0:
		draw_line(Vector2(6.0, 4.0), Vector2(size.x - 6.0, 4.0), colors["highlight"], 1.0, false)

func _on_button_down() -> void:
	_scale_to(Vector2(0.96, 0.96), 0.1)

func _on_button_up() -> void:
	_scale_to(Vector2.ONE, 0.1)

func _scale_to(target: Vector2, duration: float) -> void:
	if is_instance_valid(_press_tween):
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_QUAD)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_property(self, "scale", target, duration)

func _sync_pivot() -> void:
	pivot_offset = size / 2.0

func _sync_layout() -> void:
	if not is_instance_valid(button):
		return
	_last_button_size = button.size
	size = visual_size
	position = (button.size - visual_size) / 2.0
	_sync_pivot()

func _fill_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	box.corner_detail = 1
	return box

func _outline_box(color: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color.TRANSPARENT
	box.draw_center = false
	box.border_color = color
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.anti_aliasing = false
	box.corner_detail = 1
	return box

func _palette(button_kind: String, state: String) -> Dictionary:
	if button_kind == "inline":
		match state:
			"selected":
				return _colors(44, 38, 28, 181, 138, 66, 128, 98, 58, 18, 12, 8, 219, 168, 82)
			"disabled":
				return _colors(17, 25, 23, 94, 106, 102, 67, 73, 69, 4, 6, 6, 122, 133, 125)
			_:
				return _colors(32, 42, 39, 111, 143, 133, 63, 95, 89, 4, 9, 8, 117, 184, 163)
	match state:
		"selected":
			return _colors(50, 37, 24, 205, 158, 74, 181, 138, 66, 7, 5, 4, 238, 190, 100)
		"disabled":
			return _colors(24, 24, 22, 94, 106, 102, 74, 75, 70, 5, 5, 5, 122, 133, 125)
		_:
			return _colors(36, 29, 24, 181, 138, 66, 128, 98, 58, 5, 5, 5, 219, 168, 82)

func _colors(
	br: int, bg: int, bb: int,
	or_: int, og: int, ob: int,
	ir: int, ig: int, ib: int,
	dr: int, dg: int, db: int,
	hr: int, hg: int, hb: int,
) -> Dictionary:
	return {
		"base": Color8(br, bg, bb, 255),
		"outer": Color8(or_, og, ob, 255),
		"inner": Color8(ir, ig, ib, 255),
		"depth": Color8(dr, dg, db, 78),
		"highlight": Color8(hr, hg, hb, 92),
	}
