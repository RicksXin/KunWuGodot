extends Node2D

const DISPLAY_SCALE := 3.0
const ASSET_ANCHOR := Vector2(187.5, 515.0)
const PLAYER_START := Vector2(187.5, 630.0)
const PLAYER_END := Vector2(187.5, 395.0)
const STAGE_RECT := Rect2(19.5, 132.0, 336.0, 552.0)
const FADED_ALPHA := 0.22

const PAIRS := [
	{
		"label": "斜山脊 · 西北—东南",
		"base": "res://assets/maps/map_01/blockers/ridge_nw_se_base.png",
		"foreground": "res://assets/maps/map_01/blockers/ridge_nw_se_foreground.png",
		"trigger": Rect2(-78.0, -118.0, 156.0, 128.0),
	},
	{
		"label": "斜山脊 · 东北—西南",
		"base": "res://assets/maps/map_01/blockers/ridge_ne_sw_base.png",
		"foreground": "res://assets/maps/map_01/blockers/ridge_ne_sw_foreground.png",
		"trigger": Rect2(-78.0, -118.0, 156.0, 128.0),
	},
	{
		"label": "山腹暗道 · 顶石",
		"base": "res://assets/maps/map_01/blockers/tunnel_stay_base.png",
		"foreground": "res://assets/maps/map_01/blockers/tunnel_roof_foreground.png",
		"trigger": Rect2(-52.0, -116.0, 104.0, 128.0),
	},
	{
		"label": "万修之门 · 顶部",
		"base": "res://assets/maps/map_01/blockers/gate_stay_base.png",
		"foreground": "res://assets/maps/map_01/blockers/gate_top_foreground.png",
		"trigger": Rect2(-56.0, -108.0, 112.0, 120.0),
	},
]

@onready var base_sprite: Sprite2D = $BaseSprite
@onready var foreground_sprite: Sprite2D = $ForegroundSprite
@onready var player: Polygon2D = $Player
@onready var player_marker: Polygon2D = $Player/Marker
@onready var pair_label: Label = $UI/PairLabel
@onready var state_label: Label = $UI/StateLabel
@onready var auto_button: Button = $UI/AutoButton

var pair_index := 0
var auto_motion := true
var auto_elapsed := 0.0


func _ready() -> void:
	$UI/PreviousButton.pressed.connect(_show_previous)
	$UI/NextButton.pressed.connect(_show_next)
	auto_button.pressed.connect(_toggle_auto)
	player.position = PLAYER_START
	_load_pair()
	queue_redraw()
	if "--demo-inside" in OS.get_cmdline_user_args():
		auto_motion = false
		auto_button.text = "自动演示：关"
		player.position = ASSET_ANCHOR + Vector2(0.0, -62.0)
		foreground_sprite.modulate = Color(1.0, 1.0, 1.0, FADED_ALPHA)


func _process(delta: float) -> void:
	_update_player(delta)
	var inside := _trigger_rect().has_point(player.position)
	var target_alpha := FADED_ALPHA if inside else 1.0
	var color := foreground_sprite.modulate
	color.a = move_toward(color.a, target_alpha, delta * 2.8)
	foreground_sprite.modulate = color
	state_label.text = "前景 Alpha %.2f  ·  底座 Alpha 1.00\n碰撞语义保持不变  ·  队伍标记始终在前景上方" % color.a
	player_marker.color = Color("#f1d88d") if inside else Color("#eee8da")
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


func _update_player(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if not direction.is_zero_approx():
		auto_motion = false
		auto_button.text = "自动演示：关"
		player.position += direction * delta * 112.0
		player.position.x = clampf(player.position.x, STAGE_RECT.position.x + 18.0, STAGE_RECT.end.x - 18.0)
		player.position.y = clampf(player.position.y, STAGE_RECT.position.y + 18.0, STAGE_RECT.end.y - 18.0)
		return
	if not auto_motion:
		return
	auto_elapsed = fmod(auto_elapsed + delta * 0.42, 2.0)
	var amount := auto_elapsed if auto_elapsed <= 1.0 else 2.0 - auto_elapsed
	amount = smoothstep(0.0, 1.0, amount)
	player.position = PLAYER_START.lerp(PLAYER_END, amount)


func _load_pair() -> void:
	var pair: Dictionary = PAIRS[pair_index]
	_set_anchored_texture(base_sprite, str(pair.base))
	_set_anchored_texture(foreground_sprite, str(pair.foreground))
	foreground_sprite.modulate = Color.WHITE
	pair_label.text = "%d / %d　%s" % [pair_index + 1, PAIRS.size(), pair.label]
	player.position = PLAYER_START
	auto_elapsed = 0.0
	queue_redraw()


func _set_anchored_texture(sprite: Sprite2D, path: String) -> void:
	var texture := load(path) as Texture2D
	assert(texture != null, "Missing Map01 foreground demo texture: %s" % path)
	sprite.texture = texture
	sprite.centered = false
	sprite.scale = Vector2.ONE * DISPLAY_SCALE
	var size := texture.get_size()
	var anchor_px := Vector2(floorf(size.x * 0.5), size.y - 2.0)
	sprite.position = ASSET_ANCHOR - anchor_px * DISPLAY_SCALE


func _trigger_rect() -> Rect2:
	var local_rect: Rect2 = PAIRS[pair_index].trigger
	return Rect2(ASSET_ANCHOR + local_rect.position, local_rect.size)


func _show_previous() -> void:
	pair_index = wrapi(pair_index - 1, 0, PAIRS.size())
	_load_pair()


func _show_next() -> void:
	pair_index = wrapi(pair_index + 1, 0, PAIRS.size())
	_load_pair()


func _toggle_auto() -> void:
	auto_motion = not auto_motion
	auto_button.text = "自动演示：开" if auto_motion else "自动演示：关"
	if auto_motion:
		auto_elapsed = 0.0


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(375.0, 817.0)), Color("#0e1217"))
	draw_rect(STAGE_RECT, Color("#858b91"))
	for x in range(0, 8):
		var line_x := STAGE_RECT.position.x + float(x) * 48.0
		draw_line(Vector2(line_x, STAGE_RECT.position.y), Vector2(line_x, STAGE_RECT.end.y), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	for y in range(0, 13):
		var line_y := STAGE_RECT.position.y + float(y) * 48.0
		draw_line(Vector2(STAGE_RECT.position.x, line_y), Vector2(STAGE_RECT.end.x, line_y), Color(0.18, 0.22, 0.26, 0.22), 1.0)
	draw_rect(_trigger_rect(), Color(0.28, 0.63, 0.72, 0.08))
	draw_dashed_line(_trigger_rect().position, Vector2(_trigger_rect().end.x, _trigger_rect().position.y), Color("#78a6b8"), 1.0, 6.0)
	draw_dashed_line(Vector2(_trigger_rect().end.x, _trigger_rect().position.y), _trigger_rect().end, Color("#78a6b8"), 1.0, 6.0)
	draw_dashed_line(_trigger_rect().end, Vector2(_trigger_rect().position.x, _trigger_rect().end.y), Color("#78a6b8"), 1.0, 6.0)
	draw_dashed_line(Vector2(_trigger_rect().position.x, _trigger_rect().end.y), _trigger_rect().position, Color("#78a6b8"), 1.0, 6.0)
	draw_circle(ASSET_ANCHOR, 3.0, Color("#c5a35b"))
