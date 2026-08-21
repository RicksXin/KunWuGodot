extends Node2D

const STAIRS_X := 187.5
const STAIRS_BASELINES := [360.0, 620.0]
const STATE_LABELS := ["封闭 · 中心横石阻挡", "开启 · 中心通路开放"]

@onready var stairs: Array[KWMap01EastWallStairs] = [
	$StairsClosed,
	$StairsOpen,
]
@onready var marker: Polygon2D = $Marker
@onready var state_label: Label = $UI/StateLabel
@onready var marker_button: Button = $UI/MarkerButton

var selected_index := 0


func _ready() -> void:
	$UI/PreviousButton.pressed.connect(_show_previous)
	$UI/NextButton.pressed.connect(_show_next)
	marker_button.pressed.connect(_toggle_marker)
	_apply_cli_selection()
	_select_stairs(selected_index)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_show_previous()
			KEY_E:
				_show_next()
			KEY_SPACE:
				_toggle_marker()


func get_selected_state_id() -> String:
	return stairs[selected_index].get_state_id()


func _apply_cli_selection() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--stairs-state="):
			continue
		match argument.trim_prefix("--stairs-state="):
			"closed": selected_index = 0
			"open": selected_index = 1


func _select_stairs(index: int) -> void:
	selected_index = wrapi(index, 0, stairs.size())
	marker.position = Vector2(STAIRS_X, STAIRS_BASELINES[selected_index] - 104.0)
	state_label.text = "%d / %d　%s　·　%s" % [
		selected_index + 1,
		stairs.size(),
		STATE_LABELS[selected_index],
		stairs[selected_index].get_state_id(),
	]
	queue_redraw()


func _show_previous() -> void:
	_select_stairs(selected_index - 1)


func _show_next() -> void:
	_select_stairs(selected_index + 1)


func _toggle_marker() -> void:
	marker.visible = not marker.visible
	marker_button.text = "Marker：开" if marker.visible else "Marker：关"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(375.0, 817.0)), Color("#0e1217"))
	draw_rect(Rect2(19.5, 108.0, 336.0, 588.0), Color("#5c696e"))
	draw_rect(Rect2(139.5, 108.0, 96.0, 588.0), Color("#8b8069"))
	for x in range(0, 8):
		var line_x := 19.5 + float(x) * 48.0
		draw_line(Vector2(line_x, 108.0), Vector2(line_x, 696.0), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for y in range(0, 14):
		var line_y := 108.0 + float(y) * 48.0
		draw_line(Vector2(19.5, line_y), Vector2(355.5, line_y), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for index in stairs.size():
		var center := Vector2(STAIRS_X, STAIRS_BASELINES[index])
		var footprint := Rect2(center + Vector2(-96.0, -144.0), Vector2(192.0, 144.0))
		draw_rect(footprint, Color(0.28, 0.63, 0.72, 0.05), true)
		_draw_collision(center, Vector2(-20.0, -12.0), Vector2(18.0, 24.0), Color(0.76, 0.60, 0.41, 0.75))
		_draw_collision(center, Vector2(20.0, -12.0), Vector2(18.0, 24.0), Color(0.76, 0.60, 0.41, 0.75))
		if index == 0:
			_draw_collision(center, Vector2(0.0, -24.0), Vector2(32.0, 10.0), Color(0.71, 0.28, 0.27, 0.75))
		if index == selected_index:
			draw_rect(footprint.grow(4.0), Color("#c5a35b"), false, 2.0)


func _draw_collision(center: Vector2, source_center: Vector2, source_size: Vector2, color: Color) -> void:
	var scaled_size := source_size * 3.0
	var scaled_center := center + source_center * 3.0
	draw_rect(Rect2(scaled_center - scaled_size * 0.5, scaled_size), color, false, 1.0)
