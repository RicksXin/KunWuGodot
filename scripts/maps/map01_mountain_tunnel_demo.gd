extends Node2D

const TUNNEL_X := 187.5
const TUNNEL_BASELINES := [300.0, 500.0, 700.0]
const STATE_LABELS := ["默认 · 碎石封堵", "发现 · 暗缝与炉火", "清除 · 通路持续开放"]

@onready var tunnels: Array[KWMap01MountainTunnel] = [
	$TunnelDefault,
	$TunnelDiscovered,
	$TunnelCleared,
]
@onready var marker: Polygon2D = $Marker
@onready var state_label: Label = $UI/StateLabel
@onready var roof_button: Button = $UI/RoofButton

var selected_index := 0
var roof_faded := false


func _ready() -> void:
	$UI/PreviousButton.pressed.connect(_show_previous)
	$UI/NextButton.pressed.connect(_show_next)
	roof_button.pressed.connect(_toggle_roof)
	_apply_cli_selection()
	_select_tunnel(selected_index)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q:
			_show_previous()
		KEY_E:
			_show_next()
		KEY_F:
			_toggle_roof()
		KEY_SPACE:
			_toggle_marker()


func get_selected_state_id() -> String:
	return tunnels[selected_index].get_state_id()


func get_selected_foreground_alpha() -> float:
	return tunnels[selected_index].get_foreground_alpha()


func set_selected_roof_faded(value: bool) -> void:
	roof_faded = value
	for index in tunnels.size():
		tunnels[index].set_occluder_faded(index == selected_index and roof_faded, true)
	roof_button.text = "顶石：淡出" if roof_faded else "顶石：正常"


func _apply_cli_selection() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--tunnel-state="):
			continue
		match argument.trim_prefix("--tunnel-state="):
			"default": selected_index = 0
			"discovered": selected_index = 1
			"cleared": selected_index = 2


func _select_tunnel(index: int) -> void:
	selected_index = wrapi(index, 0, tunnels.size())
	marker.position = Vector2(TUNNEL_X, TUNNEL_BASELINES[selected_index] - 66.0)
	state_label.text = "%d / %d　%s　·　%s" % [
		selected_index + 1,
		tunnels.size(),
		STATE_LABELS[selected_index],
		tunnels[selected_index].get_state_id(),
	]
	set_selected_roof_faded(roof_faded)
	queue_redraw()


func _show_previous() -> void:
	_select_tunnel(selected_index - 1)


func _show_next() -> void:
	_select_tunnel(selected_index + 1)


func _toggle_roof() -> void:
	set_selected_roof_faded(not roof_faded)


func _toggle_marker() -> void:
	marker.visible = not marker.visible


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(375.0, 817.0)), Color("#0e1217"))
	draw_rect(Rect2(19.5, 108.0, 336.0, 614.0), Color("#5c696e"))
	draw_rect(Rect2(163.5, 108.0, 48.0, 614.0), Color("#8b8069"))
	for x in range(0, 8):
		var line_x := 19.5 + float(x) * 48.0
		draw_line(Vector2(line_x, 108.0), Vector2(line_x, 722.0), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for y in range(0, 14):
		var line_y := 108.0 + float(y) * 48.0
		draw_line(Vector2(19.5, line_y), Vector2(355.5, line_y), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for index in tunnels.size():
		var center := Vector2(TUNNEL_X, TUNNEL_BASELINES[index])
		var footprint := Rect2(center + Vector2(-96.0, -144.0), Vector2(192.0, 144.0))
		draw_rect(footprint, Color(0.28, 0.63, 0.72, 0.04), true)
		_draw_collision(center, Vector2(-20.0, -10.0), Vector2(20.0, 18.0), Color(0.76, 0.60, 0.41, 0.75))
		_draw_collision(center, Vector2(20.0, -10.0), Vector2(20.0, 18.0), Color(0.76, 0.60, 0.41, 0.75))
		if index < 2:
			_draw_collision(center, Vector2(0.0, -10.0), Vector2(16.0, 18.0), Color(0.71, 0.28, 0.27, 0.75))
		if index == selected_index:
			draw_rect(footprint.grow(4.0), Color("#c5a35b"), false, 2.0)


func _draw_collision(center: Vector2, source_center: Vector2, source_size: Vector2, color: Color) -> void:
	var scaled_size := source_size * 3.0
	var scaled_center := center + source_center * 3.0
	draw_rect(Rect2(scaled_center - scaled_size * 0.5, scaled_size), color, false, 1.0)
