extends Control

var tile_size := 48.0
var tile_source_size := 16
var scene_terrain_active := false
var legacy_tileset: Texture2D

func setup(use_scene_terrain: bool) -> void:
	scene_terrain_active = use_scene_terrain
	var active_map := Game.get_map_definition()
	var visual: Dictionary = active_map.get("visual", {})
	tile_size = float(visual.get("logicalTileSize", 48))
	tile_source_size = int(visual.get("tileSourceSize", 16))
	if not scene_terrain_active:
		var tileset_path := str(visual.get("tileSetPath", "res://assets/maps/map_01/puny_dungeon/punyworld-dungeon-tileset.png"))
		if not tileset_path.is_empty() and ResourceLoader.exists(tileset_path):
			legacy_tileset = load(tileset_path) as Texture2D
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	var active_map := Game.get_map_definition()
	var width := int(active_map.get("activeWidth", 15))
	var height := int(active_map.get("activeHeight", 15))
	var expedition: Variant = Game.profile.get("expedition")
	if expedition == null:
		return
	var position: Dictionary = expedition.get("position", {"x": 2, "y": 2})
	for y in range(height):
		for x in range(width):
			var screen_y := height - 1 - y
			var rect := Rect2(x * tile_size, screen_y * tile_size, tile_size, tile_size)
			var tile: Dictionary = Game.tile_at(x, y)
			var symbol := str(tile.get("symbol", "#"))
			var revealed := Game.is_revealed(x, y)
			var visible_now := Game.is_visible(x, y)
			if not scene_terrain_active and revealed:
				_draw_legacy_terrain(rect, symbol)
			if not revealed:
				draw_rect(rect, Color("#03070a"))
			elif not visible_now:
				draw_rect(rect, Color(0.02, 0.04, 0.05, 0.60))
			elif symbol == "~":
				for stripe in range(3):
					draw_line(rect.position + Vector2(8, 15 + stripe * 9), rect.position + Vector2(40, 7 + stripe * 9), Color("#b69a65"), 2.0)
			draw_rect(rect, Color("#172426"), false, 1.0)
	_draw_markers(active_map, height, position)

func _draw_legacy_terrain(rect: Rect2, symbol: String) -> void:
	var color := Color("#2b3436") if symbol == "#" else Color("#596052")
	if symbol == "~": color = Color("#6e5f48")
	if symbol == "E": color = Color("#176c6a")
	draw_rect(rect, color)
	if legacy_tileset:
		draw_texture_rect_region(legacy_tileset, rect, _legacy_tile_region(symbol))
	if symbol == "#":
		draw_rect(Rect2(rect.position + Vector2(7, 7), rect.size - Vector2(14, 14)), Color("#394549"))

func _draw_markers(active_map: Dictionary, height: int, position: Dictionary) -> void:
	var entry_x := int(active_map.get("entryX", 2))
	var entry_y := int(active_map.get("entryY", 2))
	if Game.is_revealed(entry_x, entry_y):
		_draw_diamond(Vector2((entry_x + 0.5) * tile_size, (height - entry_y - 0.5) * tile_size), tile_size * 0.29, Color("#4dd5c0"))
	for object in active_map.get("objects", []):
		var ox := int(object.get("x", 0))
		var oy := int(object.get("y", 0))
		if not Game.is_revealed(ox, oy): continue
		if Game.profile.get("completedMapObjects", {}).get(Game.map_object_key(Game.get_active_map_id(), str(object.get("id", ""))), false): continue
		if object.get("kind") == "enemy_group" and not Game.is_visible(ox, oy): continue
		var marker := Vector2((ox + 0.5) * tile_size, (height - oy - 0.5) * tile_size)
		if object.get("kind") == "enemy_group":
			_draw_diamond(marker, tile_size * 0.31, Color("#e45e54"))
		elif object.get("kind") == "treasure_chest":
			draw_rect(Rect2(marker - Vector2(14, 8), Vector2(28, 18)), Color("#d6a344"))
			draw_line(marker - Vector2(14, -1), marker + Vector2(14, -1), Color("#ffe09a"), 2.0)
		else:
			_draw_diamond(marker, tile_size * 0.27, Color("#ae69d6"))
	var player := Vector2((int(position.get("x", 2)) + 0.5) * tile_size, (height - int(position.get("y", 2)) - 0.5) * tile_size)
	draw_circle(player, 14.0, Color("#5dc1eb"))
	draw_arc(player, 14.0, 0, TAU, 24, Color("#e1f5ee"), 2.0)

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	draw_colored_polygon(points, color)

func _legacy_tile_region(symbol: String) -> Rect2:
	var gid := 27 if symbol == "#" else 79 if symbol == "~" else 5
	var index := gid - 1
	var columns := maxi(1, floori(float(legacy_tileset.get_width()) / float(tile_source_size))) if legacy_tileset else 1
	return Rect2((index % columns) * tile_source_size, floori(float(index) / float(columns)) * tile_source_size, tile_source_size, tile_source_size)
