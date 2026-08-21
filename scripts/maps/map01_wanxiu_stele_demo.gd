extends Node2D

const STELE_X := 187.5
const STELE_BASELINES := [300.0, 480.0, 660.0]
const STATE_LABELS := ["默认 · 未读取", "已交互 · 总印响应", "C07 · 替换面预留"]

@onready var steles: Array[KWMap01WanxiuStele] = [
	$SteleDefault,
	$SteleInteracted,
	$SteleC07Reserved,
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
	_select_stele(selected_index)
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
	return steles[selected_index].get_state_id()


func _apply_cli_selection() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--stele-state="):
			continue
		match argument.trim_prefix("--stele-state="):
			"default": selected_index = 0
			"interacted": selected_index = 1
			"c07": selected_index = 2


func _select_stele(index: int) -> void:
	selected_index = wrapi(index, 0, steles.size())
	marker.position = Vector2(STELE_X, STELE_BASELINES[selected_index] - 160.0)
	state_label.text = "%d / %d　%s　·　%s" % [
		selected_index + 1,
		steles.size(),
		STATE_LABELS[selected_index],
		steles[selected_index].get_state_id(),
	]
	queue_redraw()


func _show_previous() -> void:
	_select_stele(selected_index - 1)


func _show_next() -> void:
	_select_stele(selected_index + 1)


func _toggle_marker() -> void:
	marker.visible = not marker.visible
	marker_button.text = "Marker：开" if marker.visible else "Marker：关"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(375.0, 817.0)), Color("#0e1217"))
	draw_rect(Rect2(19.5, 126.0, 336.0, 564.0), Color("#858b91"))
	for x in range(0, 8):
		var line_x := 19.5 + float(x) * 48.0
		draw_line(Vector2(line_x, 126.0), Vector2(line_x, 690.0), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for y in range(0, 13):
		var line_y := 126.0 + float(y) * 48.0
		draw_line(Vector2(19.5, line_y), Vector2(355.5, line_y), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for index in steles.size():
		var center := Vector2(STELE_X, STELE_BASELINES[index])
		var footprint := Rect2(center + Vector2(-72.0, -144.0), Vector2(144.0, 144.0))
		var collision := Rect2(center + Vector2(-48.0, -60.0), Vector2(96.0, 60.0))
		draw_rect(footprint, Color(0.28, 0.63, 0.72, 0.05), true)
		draw_rect(collision, Color(0.71, 0.28, 0.27, 0.55), false, 1.0)
		if index == selected_index:
			draw_rect(footprint.grow(4.0), Color("#c5a35b"), false, 2.0)
