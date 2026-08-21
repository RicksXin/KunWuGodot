extends Node2D

const MAP_DISPLAY_SIZE := Vector2(2304.0, 3072.0)
const REVIEW_MODES := [
	{
		"label": "全图总览 · 候选地标构图",
		"position": Vector2(1152.0, 1536.0),
		"zoom": Vector2(0.15, 0.15),
	},
	{
		"label": "G区 · 万修之门",
		"position": Vector2(1176.0, 360.0),
		"zoom": Vector2.ONE,
	},
	{
		"label": "C区 · 残碑与分流",
		"position": Vector2(1176.0, 2016.0),
		"zoom": Vector2.ONE,
	},
	{
		"label": "B区 · 废营与第一阵灯",
		"position": Vector2(1512.0, 2380.0),
		"zoom": Vector2.ONE,
	},
	{
		"label": "D区 · 山腹暗道",
		"position": Vector2(408.0, 1392.0),
		"zoom": Vector2.ONE,
	},
	{
		"label": "E区 · 东壁阶梯与精英同屏范围",
		"position": Vector2(1824.0, 1488.0),
		"zoom": Vector2.ONE,
	},
]

@onready var camera: Camera2D = $Camera2D
@onready var mode_label: Label = $UI/ModeLabel
@onready var tunnel: KWMap01MountainTunnel = $CandidateLandmarks/TunnelCandidate
@onready var stairs: KWMap01EastWallStairs = $CandidateLandmarks/StairsCandidate
@onready var stairs_button: Button = $UI/StairsButton

var review_mode := 0
var tunnel_state_index := 0


func _ready() -> void:
	$UI/PreviousButton.pressed.connect(_show_previous)
	$UI/NextButton.pressed.connect(_show_next)
	stairs_button.pressed.connect(_cycle_active_landmark_state)
	camera.make_current()
	_set_review_mode(0)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_Q:
			_show_previous()
		KEY_E, KEY_SPACE:
			_show_next()
		KEY_1:
			_set_review_mode(0)
		KEY_2:
			_set_review_mode(1)
		KEY_3:
			_set_review_mode(2)
		KEY_4:
			_set_review_mode(3)
		KEY_5:
			_set_review_mode(4)
		KEY_6:
			_set_review_mode(5)
		KEY_R:
			_toggle_stairs()
		KEY_T:
			_cycle_tunnel_state()


func get_review_mode() -> int:
	return review_mode


func get_stairs_preview_state_id() -> String:
	return stairs.get_state_id()


func get_tunnel_preview_state_id() -> String:
	return tunnel.get_state_id()


func set_stairs_preview_open(value: bool) -> void:
	stairs.set_state_id("STAIRS_OPEN" if value else "STAIRS_CLOSED")
	_refresh_state_button()


func set_tunnel_preview_state_id(state_id: String) -> bool:
	var index := KWMap01MountainTunnel.STATE_IDS.find(state_id)
	if index < 0 or not tunnel.set_state_id(state_id):
		return false
	tunnel_state_index = index
	_refresh_state_button()
	return true


func _set_review_mode(index: int) -> void:
	review_mode = wrapi(index, 0, REVIEW_MODES.size())
	var mode: Dictionary = REVIEW_MODES[review_mode]
	camera.position = mode.position
	camera.zoom = mode.zoom
	mode_label.text = "%d / %d　%s" % [review_mode + 1, REVIEW_MODES.size(), str(mode.label)]
	_refresh_state_button()


func _show_previous() -> void:
	_set_review_mode(review_mode - 1)


func _show_next() -> void:
	_set_review_mode(review_mode + 1)


func _toggle_stairs() -> void:
	set_stairs_preview_open(not stairs.is_passage_open())


func _cycle_tunnel_state() -> void:
	tunnel_state_index = wrapi(tunnel_state_index + 1, 0, KWMap01MountainTunnel.STATE_IDS.size())
	tunnel.set_state_id(KWMap01MountainTunnel.STATE_IDS[tunnel_state_index])
	_refresh_state_button()


func _cycle_active_landmark_state() -> void:
	if review_mode == 4:
		_cycle_tunnel_state()
	elif review_mode == 5:
		_toggle_stairs()


func _refresh_state_button() -> void:
	if not is_instance_valid(stairs_button):
		return
	match review_mode:
		4:
			stairs_button.disabled = false
			stairs_button.text = {
				"TUNNEL_DEFAULT": "暗道：默认",
				"TUNNEL_DISCOVERED": "暗道：发现",
				"TUNNEL_CLEARED": "暗道：清除",
			}.get(tunnel.get_state_id(), "暗道：未知")
		5:
			stairs_button.disabled = false
			stairs_button.text = "阶梯：开" if stairs.is_passage_open() else "阶梯：关"
		_:
			stairs_button.disabled = true
			stairs_button.text = "地标状态"


func _draw() -> void:
	draw_rect(Rect2(Vector2(-4096.0, -4096.0), Vector2(12288.0, 12288.0)), Color("#11161b"))
	draw_rect(Rect2(Vector2.ZERO, MAP_DISPLAY_SIZE), Color("#1b2229"), false, 6.0)
