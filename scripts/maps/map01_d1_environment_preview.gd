extends Node2D

const MAP_DISPLAY_SIZE := Vector2(2304.0, 3072.0)
const OVERVIEW_ZOOM := Vector2(0.15, 0.15)
const EXPLORATION_ZOOM := Vector2.ONE
const EXPLORATION_CENTER := Vector2(24.0 * 48.0, 37.0 * 48.0)

@onready var camera: Camera2D = $Camera2D
@onready var mode_label: Label = $UI/ModeLabel

var overview := true


func _ready() -> void:
	_set_overview(true)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_set_overview(not overview)


func _set_overview(enabled: bool) -> void:
	overview = enabled
	if overview:
		camera.position = MAP_DISPLAY_SIZE * 0.5
		camera.zoom = OVERVIEW_ZOOM
		mode_label.text = "全图总览 · 无地标 / 无敌人 / 无资源"
	else:
		camera.position = EXPLORATION_CENTER
		camera.zoom = EXPLORATION_ZOOM
		mode_label.text = "375×817 探索视窗 · Space 返回总览"


func _draw() -> void:
	draw_rect(Rect2(Vector2(-4096.0, -4096.0), Vector2(12288.0, 12288.0)), Color("#11161b"))
	draw_rect(Rect2(Vector2.ZERO, MAP_DISPLAY_SIZE), Color("#1b2229"), false, 6.0)

