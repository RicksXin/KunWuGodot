extends Control

signal cell_clicked(x: int, y: int)

const TILE := 48.0
const TILESET = preload("res://assets/maps/map_01/puny_dungeon/punyworld-dungeon-tileset.png")

func _ready() -> void:
	custom_minimum_size = Vector2(720, 720)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var cell_x := floori(event.position.x / TILE)
		var screen_y := floori(event.position.y / TILE)
		var cell_y := int(Game.map_definition.get("activeHeight", 15)) - 1 - screen_y
		if Game.is_visible(cell_x, cell_y):
			emit_signal("cell_clicked", cell_x, cell_y)

func _draw() -> void:
	var width := int(Game.map_definition.get("activeWidth", 15))
	var height := int(Game.map_definition.get("activeHeight", 15))
	var expedition: Variant = Game.profile.get("expedition")
	if expedition == null: return
	var position: Dictionary = expedition.get("position", {"x": 2, "y": 2})
	for y in range(height):
		for x in range(width):
			var screen_y := height - 1 - y
			var rect := Rect2(x * TILE, screen_y * TILE, TILE, TILE)
			var tile: Dictionary = Game.tile_at(x, y)
			var symbol := str(tile.get("symbol", "#"))
			var color := Color("#2b3436") if symbol == "#" else Color("#596052")
			if symbol == "~": color = Color("#6e5f48")
			if symbol == "E": color = Color("#176c6a")
			if Game.is_revealed(x, y):
				draw_rect(rect, color)
				draw_texture_rect_region(TILESET, rect, _tile_region(symbol))
			else:
				draw_rect(rect, Color("#03070a"))
			draw_rect(rect, Color("#172426"), false, 1.0)
			if not Game.is_visible(x, y) and Game.is_revealed(x, y):
				draw_rect(rect, Color(0.02, 0.04, 0.05, 0.48))
			if Game.is_visible(x, y) and symbol == "#":
				draw_rect(Rect2(rect.position + Vector2(7, 7), rect.size - Vector2(14, 14)), Color("#394549"))
			elif Game.is_visible(x, y) and symbol == "~":
				for stripe in range(3):
					draw_line(rect.position + Vector2(8, 15 + stripe * 9), rect.position + Vector2(40, 7 + stripe * 9), Color("#9d885d"), 2.0)
	# Entry marker.
	var entry_x := int(Game.map_definition.get("entryX", 2))
	var entry_y := int(Game.map_definition.get("entryY", 2))
	_draw_diamond(Vector2((entry_x + 0.5) * TILE, (height - entry_y - 0.5) * TILE), 14.0, Color("#4dd5c0"))
	for object in Game.map_definition.get("objects", []):
		var ox := int(object.get("x", 0))
		var oy := int(object.get("y", 0))
		if not Game.is_revealed(ox, oy): continue
		if Game.profile.get("completedMapObjects", {}).get("map_01." + str(object.get("id", "")), false): continue
		if object.get("kind") == "enemy_group" and not Game.is_visible(ox, oy): continue
		var marker := Vector2((ox + 0.5) * TILE, (height - oy - 0.5) * TILE)
		if object.get("kind") == "enemy_group": _draw_diamond(marker, 15.0, Color("#e45e54"))
		elif object.get("kind") == "treasure_chest":
			draw_rect(Rect2(marker - Vector2(14, 8), Vector2(28, 18)), Color("#d6a344"))
			draw_line(marker - Vector2(14, -1), marker + Vector2(14, -1), Color("#ffe09a"), 2.0)
		else: _draw_diamond(marker, 13.0, Color("#ae69d6"))
	# Player marker.
	var player := Vector2((int(position.get("x", 2)) + 0.5) * TILE, (height - int(position.get("y", 2)) - 0.5) * TILE)
	draw_circle(player, 14.0, Color("#5dc1eb"))
	draw_arc(player, 14.0, 0, TAU, 24, Color("#e1f5ee"), 2.0)

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	draw_colored_polygon(points, color)

func _tile_region(symbol: String) -> Rect2:
	# 与冻结源 TMX 相同的三个 tile GID：墙 27、地面 5、碎石/水迹 79。
	var gid := 27 if symbol == "#" else 79 if symbol == "~" else 5
	var index := gid - 1
	return Rect2((index % 26) * 16, floori(index / 26.0) * 16, 16, 16)
