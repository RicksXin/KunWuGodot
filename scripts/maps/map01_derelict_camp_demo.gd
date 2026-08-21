extends Node2D

const CAMP_X := 187.5
const CAMP_BASELINES := [348.0, 590.0]
const STATE_LABELS := ["尸首未处理", "尸首已处理"]

@onready var camps: Array[KWMap01DerelictCamp] = [
	$CampDefault,
	$CampProcessed,
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
	_select_camp(selected_index)
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
	return camps[selected_index].get_state_id()


func _apply_cli_selection() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--camp-state="):
			continue
		match argument.trim_prefix("--camp-state="):
			"default": selected_index = 0
			"processed": selected_index = 1


func _select_camp(index: int) -> void:
	selected_index = wrapi(index, 0, camps.size())
	marker.position = Vector2(CAMP_X, CAMP_BASELINES[selected_index] - 166.0)
	state_label.text = "%d / %d　%s　·　%s" % [
		selected_index + 1,
		camps.size(),
		STATE_LABELS[selected_index],
		camps[selected_index].get_state_id(),
	]
	queue_redraw()


func _show_previous() -> void:
	_select_camp(selected_index - 1)


func _show_next() -> void:
	_select_camp(selected_index + 1)


func _toggle_marker() -> void:
	marker.visible = not marker.visible
	marker_button.text = "Marker：开" if marker.visible else "Marker：关"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(375.0, 817.0)), Color("#0e1217"))
	draw_rect(Rect2(19.5, 112.0, 336.0, 578.0), Color("#858b91"))
	for x in range(0, 8):
		var line_x := 19.5 + float(x) * 48.0
		draw_line(Vector2(line_x, 112.0), Vector2(line_x, 690.0), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for y in range(0, 14):
		var line_y := 112.0 + float(y) * 48.0
		draw_line(Vector2(19.5, line_y), Vector2(355.5, line_y), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for index in camps.size():
		var center := Vector2(CAMP_X, CAMP_BASELINES[index])
		var footprint := Rect2(center + Vector2(-96.0, -144.0), Vector2(240.0, 144.0))
		draw_rect(footprint, Color(0.28, 0.63, 0.72, 0.05), true)
		_draw_collision(center, Vector2(-15.0, -21.0), Vector2(20.0, 14.0))
		_draw_collision(center, Vector2(14.0, -14.0), Vector2(22.0, 16.0))
		if index == selected_index:
			draw_rect(footprint.grow(4.0), Color("#c5a35b"), false, 2.0)


func _draw_collision(center: Vector2, source_center: Vector2, source_size: Vector2) -> void:
	var scaled_size := source_size * 3.0
	var scaled_center := center + source_center * 3.0
	draw_rect(Rect2(scaled_center - scaled_size * 0.5, scaled_size), Color(0.71, 0.28, 0.27, 0.55), false, 1.0)
