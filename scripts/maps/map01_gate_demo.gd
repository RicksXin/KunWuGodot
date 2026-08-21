extends Node2D

const STAGE_RECT := Rect2(0.0, 128.0, 375.0, 558.0)
const PLAYER_START := Vector2(187.5, 626.0)
const PLAYER_END := Vector2(187.5, 246.0)
const FADE_ZONE := Rect2(135.5, 312.0, 104.0, 154.0)

const STATES := [
	{
		"id": "GATE_LOCKED",
		"label": "封闭 · 三灯条件未完成",
	},
	{
		"id": "GATE_BOSS_READY",
		"label": "整备 · 三灯完成，敌对红阵激活",
	},
	{
		"id": "GATE_OPEN",
		"label": "开启 · 中央通道放行",
	},
]

@onready var gate: KWWanxiuGate = $WanxiuGate
@onready var player: CharacterBody2D = $Player
@onready var player_marker: Polygon2D = $Player/Marker
@onready var state_label: Label = $UI/StateLabel
@onready var status_label: Label = $UI/StatusLabel
@onready var auto_button: Button = $UI/AutoButton

var state_index := 0
var auto_motion := true
var auto_elapsed := 0.0


func _ready() -> void:
	$UI/PreviousButton.pressed.connect(_show_previous)
	$UI/NextButton.pressed.connect(_show_next)
	auto_button.pressed.connect(_toggle_auto)
	$UI/ResetButton.pressed.connect(_reset_player)
	_apply_cli_state()
	set_gate_state(state_index)
	_reset_player()
	if "--demo-inside" in OS.get_cmdline_user_args():
		auto_motion = false
		auto_button.text = "自动：关"
		player.position = Vector2(187.5, 420.0)
		gate.set_occluder_faded(true, true)
	queue_redraw()


func _physics_process(delta: float) -> void:
	_update_player_velocity(delta)
	player.move_and_slide()
	var inside := FADE_ZONE.has_point(player.position)
	gate.set_occluder_faded(inside)
	var foreground_alpha := gate.get_foreground_alpha()
	player_marker.color = Color("#f1d88d") if inside else Color("#eee8da")
	var passage := "中央碰撞：放行" if gate.is_center_passage_open() else "中央碰撞：封闭"
	status_label.text = "%s　·　前景 Alpha %.2f\n门基碰撞始终保留　·　标题/刻痕/Marker 始终在前景上方" % [passage, foreground_alpha]
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_Q:
				_show_previous()
			KEY_E:
				_show_next()
			KEY_SPACE:
				_toggle_auto()
			KEY_R:
				_reset_player()


func set_gate_state(index: int) -> void:
	state_index = wrapi(index, 0, STATES.size())
	var state: Dictionary = STATES[state_index]
	gate.set_gate_state(state_index)
	state_label.text = "%d / %d　%s" % [state_index + 1, STATES.size(), str(state["label"])]
	gate.set_occluder_faded(false, true)
	_reset_player()
	queue_redraw()


func is_center_passage_open() -> bool:
	return gate.is_center_passage_open()


func _update_player_velocity(delta: float) -> void:
	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not input_direction.is_zero_approx():
		auto_motion = false
		auto_button.text = "自动：关"
		player.velocity = input_direction * 116.0
		return
	if not auto_motion:
		player.velocity = Vector2.ZERO
		return
	auto_elapsed = fmod(auto_elapsed + delta, 8.0)
	var target := PLAYER_END if auto_elapsed < 4.0 else PLAYER_START
	if player.position.distance_to(target) <= 3.0:
		player.velocity = Vector2.ZERO
	else:
		player.velocity = player.position.direction_to(target) * 94.0


func _apply_cli_state() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--gate-state="):
			var value := argument.trim_prefix("--gate-state=")
			match value:
				"locked": state_index = 0
				"boss_ready": state_index = 1
				"open": state_index = 2


func _show_previous() -> void:
	set_gate_state(state_index - 1)


func _show_next() -> void:
	set_gate_state(state_index + 1)


func _toggle_auto() -> void:
	auto_motion = not auto_motion
	auto_button.text = "自动：开" if auto_motion else "自动：关"
	if auto_motion:
		auto_elapsed = 0.0


func _reset_player() -> void:
	player.position = PLAYER_START
	player.velocity = Vector2.ZERO
	auto_elapsed = 0.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(375.0, 817.0)), Color("#0e1217"))
	draw_rect(STAGE_RECT, Color("#858b91"))
	draw_circle(Vector2(187.5, 448.0), 150.0, Color("#7d8388"))
	draw_rect(Rect2(139.5, 128.0, 96.0, 558.0), Color("#aaa187"))
	for x in range(0, 9):
		var line_x := STAGE_RECT.position.x + float(x) * 48.0
		draw_line(Vector2(line_x, STAGE_RECT.position.y), Vector2(line_x, STAGE_RECT.end.y), Color(0.18, 0.22, 0.26, 0.18), 1.0)
	for y in range(0, 13):
		var line_y := STAGE_RECT.position.y + float(y) * 48.0
		draw_line(Vector2(STAGE_RECT.position.x, line_y), Vector2(STAGE_RECT.end.x, line_y), Color(0.18, 0.22, 0.26, 0.18), 1.0)
	draw_rect(FADE_ZONE, Color(0.28, 0.63, 0.72, 0.06))
	draw_dashed_line(FADE_ZONE.position, Vector2(FADE_ZONE.end.x, FADE_ZONE.position.y), Color("#78a6b8"), 1.0, 6.0)
	draw_dashed_line(Vector2(FADE_ZONE.end.x, FADE_ZONE.position.y), FADE_ZONE.end, Color("#78a6b8"), 1.0, 6.0)
	draw_dashed_line(FADE_ZONE.end, Vector2(FADE_ZONE.position.x, FADE_ZONE.end.y), Color("#78a6b8"), 1.0, 6.0)
	draw_dashed_line(Vector2(FADE_ZONE.position.x, FADE_ZONE.end.y), FADE_ZONE.position, Color("#78a6b8"), 1.0, 6.0)
