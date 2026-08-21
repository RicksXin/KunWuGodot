@tool
class_name KWMapMarker
extends Node2D

@export var marker_id := ""
@export_enum("entry", "enemy_group", "story_event", "treasure_chest") var marker_kind := "entry":
	set(value):
		marker_kind = value
		queue_redraw()
@export var active_height := 15:
	set(value):
		active_height = maxi(1, value)
		_sync_position()
@export var source_tile_size := 256:
	set(value):
		source_tile_size = maxi(1, value)
		_sync_position()
@export var domain_cell := Vector2i.ZERO:
	set(value):
		domain_cell = value
		_sync_position()

func _ready() -> void:
	_sync_position()
	set_process(Engine.is_editor_hint())
	queue_redraw()

func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and not position.is_equal_approx(_expected_position()):
		_sync_position()

func _sync_position() -> void:
	position = _expected_position()
	queue_redraw()

func _expected_position() -> Vector2:
	return Vector2(
		(float(domain_cell.x) + 0.5) * float(source_tile_size),
		(float(active_height - 1 - domain_cell.y) + 0.5) * float(source_tile_size)
	)

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := _marker_color()
	var radius := float(source_tile_size) * 0.28
	var points := PackedVector2Array([
		Vector2(0, -radius), Vector2(radius, 0),
		Vector2(0, radius), Vector2(-radius, 0),
	])
	draw_colored_polygon(points, Color(color, 0.82))
	draw_polyline(PackedVector2Array([points[0], points[1], points[2], points[3], points[0]]), Color.WHITE, 8.0, true)
	var label: String = str(name) if marker_id.is_empty() else "%s\n%s" % [name, marker_id]
	draw_multiline_string(ThemeDB.fallback_font, Vector2(-radius, radius + 68.0), label, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 52, 2, Color.WHITE)

func _marker_color() -> Color:
	match marker_kind:
		"enemy_group": return Color("#e45e54")
		"story_event": return Color("#ae69d6")
		"treasure_chest": return Color("#d6a344")
		_: return Color("#4dd5c0")
