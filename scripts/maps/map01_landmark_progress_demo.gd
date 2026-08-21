extends Node2D

@onready var progress: KWMap01LandmarkProgress = $LandmarkProgress
@onready var status_label: Label = $UI/StatusLabel
@onready var boss_button: Button = $UI/BossButton
@onready var boss_marker: Polygon2D = $BossMarker


func _ready() -> void:
	$UI/RepairButton.pressed.connect(_repair_next_lamp)
	boss_button.pressed.connect(_toggle_boss)
	$UI/ResetButton.pressed.connect(_reset_progress)
	progress.progress_changed.connect(_update_ui)
	_apply_cli_stage()
	_update_ui(progress.get_repaired_count(), progress.get_gate_state_id(), progress.is_boss_defeated())
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_repair_next_lamp()
			KEY_B:
				_toggle_boss()
			KEY_BACKSPACE:
				_reset_progress()


func _repair_next_lamp() -> void:
	for lamp_id in KWMap01LandmarkProgress.LAMP_IDS:
		if progress.get_lamp_state(lamp_id) != "LAMP_REPAIRED":
			progress.set_lamp_state(lamp_id, "LAMP_REPAIRED")
			return


func _toggle_boss() -> void:
	if not progress.are_all_lamps_repaired():
		return
	progress.set_boss_defeated(not progress.is_boss_defeated())


func _reset_progress() -> void:
	progress.reset_default_state()


func _apply_cli_stage() -> void:
	for argument in OS.get_cmdline_user_args():
		if not argument.begins_with("--progress-stage="):
			continue
		match argument.trim_prefix("--progress-stage="):
			"all_repaired":
				progress.apply_external_state({
					"m1_event_lamp_01": "LAMP_REPAIRED",
					"m1_event_lamp_02": "LAMP_REPAIRED",
					"m1_event_lamp_03": "LAMP_REPAIRED",
				}, false)
			"open":
				progress.apply_external_state({
					"m1_event_lamp_01": "LAMP_REPAIRED",
					"m1_event_lamp_02": "LAMP_REPAIRED",
					"m1_event_lamp_03": "LAMP_REPAIRED",
				}, true)


func _update_ui(repaired_count: int, gate_state_id: String, boss_defeated: bool) -> void:
	var lamp_states := progress.get_lamp_states()
	status_label.text = "三灯：%d / 3 修复　·　门：%s\n① %s　② %s　③ %s" % [
		repaired_count,
		gate_state_id,
		_short_state(str(lamp_states["m1_event_lamp_01"])),
		_short_state(str(lamp_states["m1_event_lamp_02"])),
		_short_state(str(lamp_states["m1_event_lamp_03"])),
	]
	boss_button.disabled = repaired_count < 3
	boss_button.text = "Boss：已击败" if boss_defeated else "Boss：未击败"
	boss_marker.visible = gate_state_id == "GATE_BOSS_READY"
	queue_redraw()


func _short_state(state_id: String) -> String:
	match state_id:
		"LAMP_REVERSED": return "逆转"
		"LAMP_REPAIRED": return "修复"
		_: return "破损"


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(375.0, 817.0)), Color("#0e1217"))
	draw_rect(Rect2(0.0, 118.0, 375.0, 564.0), Color("#858b91"))
	draw_rect(Rect2(139.5, 118.0, 96.0, 564.0), Color("#aaa187"))
	for x in range(0, 9):
		var line_x := float(x) * 48.0
		draw_line(Vector2(line_x, 118.0), Vector2(line_x, 682.0), Color(0.18, 0.22, 0.26, 0.18), 1.0)
	for y in range(0, 13):
		var line_y := 118.0 + float(y) * 48.0
		draw_line(Vector2(0.0, line_y), Vector2(375.0, line_y), Color(0.18, 0.22, 0.26, 0.18), 1.0)
