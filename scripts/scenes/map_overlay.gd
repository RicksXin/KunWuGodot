extends Control

var tile_size := 48.0
var scene_terrain_active := false
var marker_textures: Dictionary = {}
var marker_sizes: Dictionary = {}

func setup(use_scene_terrain: bool) -> void:
	scene_terrain_active = use_scene_terrain
	var active_map := Game.get_map_definition()
	var visual: Dictionary = active_map.get("visual", {})
	tile_size = float(visual.get("logicalTileSize", 48))
	_load_marker_textures(visual)
	queue_redraw()

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	var active_map := Game.get_map_definition()
	var visual: Dictionary = active_map.get("visual", {})
	var subtle_grid := str(visual.get("gridStyle", "full")) == "subtle_corners"
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
				_draw_missing_background_fallback(rect, symbol)
			if not revealed:
				draw_rect(rect, Color("#03070a"))
			elif not visible_now:
				draw_rect(rect, Color(0.02, 0.04, 0.05, 0.60))
			elif symbol == "~":
				for stripe in range(3):
					draw_line(rect.position + Vector2(8, 15 + stripe * 9), rect.position + Vector2(40, 7 + stripe * 9), Color("#b69a65"), 2.0)
			if subtle_grid:
				_draw_subtle_grid_cell(rect, symbol, visible_now, Vector2i(x, y), Vector2i(int(position.get("x", 0)), int(position.get("y", 0))))
			else:
				draw_rect(rect, Color("#172426"), false, 1.0)
	_draw_markers(active_map, height, position)

func _draw_subtle_grid_cell(rect: Rect2, symbol: String, visible_now: bool, cell: Vector2i, player_cell: Vector2i) -> void:
	if symbol == "#" or not visible_now:
		return
	var distance := maxi(absi(cell.x - player_cell.x), absi(cell.y - player_cell.y))
	var color := Color(0.46, 0.76, 0.73, 0.14)
	var tick_length := 5.0
	var line_width := 1.0
	if distance <= 1:
		color = Color(0.42, 0.86, 0.82, 0.30)
		tick_length = 10.0
		line_width = 1.4
	elif distance <= 3:
		color = Color(0.46, 0.76, 0.73, 0.20)
		tick_length = 7.0
	var left := rect.position.x + 3.0
	var top := rect.position.y + 3.0
	var right := rect.end.x - 3.0
	var bottom := rect.end.y - 3.0
	draw_line(Vector2(left, top), Vector2(left + tick_length, top), color, line_width)
	draw_line(Vector2(left, top), Vector2(left, top + tick_length), color, line_width)
	draw_line(Vector2(right, top), Vector2(right - tick_length, top), color, line_width)
	draw_line(Vector2(right, top), Vector2(right, top + tick_length), color, line_width)
	draw_line(Vector2(left, bottom), Vector2(left + tick_length, bottom), color, line_width)
	draw_line(Vector2(left, bottom), Vector2(left, bottom - tick_length), color, line_width)
	draw_line(Vector2(right, bottom), Vector2(right - tick_length, bottom), color, line_width)
	draw_line(Vector2(right, bottom), Vector2(right, bottom - tick_length), color, line_width)

func _draw_missing_background_fallback(rect: Rect2, symbol: String) -> void:
	var color := Color("#2b3436") if symbol == "#" else Color("#596052")
	if symbol == "~": color = Color("#6e5f48")
	if symbol == "E": color = Color("#176c6a")
	draw_rect(rect, color)
	if symbol == "#":
		draw_rect(Rect2(rect.position + Vector2(7, 7), rect.size - Vector2(14, 14)), Color("#394549"))

func _draw_markers(active_map: Dictionary, height: int, position: Dictionary) -> void:
	var entry_x := int(active_map.get("entryX", 2))
	var entry_y := int(active_map.get("entryY", 2))
	if Game.is_revealed(entry_x, entry_y):
		var entry_marker := Vector2((entry_x + 0.5) * tile_size, (height - entry_y - 0.5) * tile_size)
		if not _draw_marker_texture("spawn", entry_marker, "bottom"):
			_draw_diamond(entry_marker, tile_size * 0.29, Color("#4dd5c0"))
	for object in active_map.get("objects", []):
		var ox := int(object.get("x", 0))
		var oy := int(object.get("y", 0))
		if Game.profile.get("completedMapObjects", {}).get(Game.map_object_key(Game.get_active_map_id(), str(object.get("id", ""))), false): continue
		var kind := str(object.get("kind", ""))
		var marker_cells: Array[Vector2i] = [Vector2i(ox, oy)]
		for raw_cell in object.get("additionalMarkerCells", []):
			if not raw_cell is Array or raw_cell.size() < 2:
				continue
			var extra_cell := Vector2i(int(raw_cell[0]), int(raw_cell[1]))
			if not marker_cells.has(extra_cell):
				marker_cells.append(extra_cell)
		for marker_cell in marker_cells:
			if not Game.is_revealed(marker_cell.x, marker_cell.y):
				continue
			if kind in ["enemy_group", "elite_enemy", "boss"] and not Game.is_visible(marker_cell.x, marker_cell.y):
				continue
			var marker := Vector2((marker_cell.x + 0.5) * tile_size, (height - marker_cell.y - 0.5) * tile_size)
			_draw_object_marker(kind, marker)
	var player := Vector2((int(position.get("x", 2)) + 0.5) * tile_size, (height - int(position.get("y", 2)) - 0.5) * tile_size)
	if not _draw_marker_texture("party", player, "center"):
		draw_circle(player, 14.0, Color("#5dc1eb"))
		draw_arc(player, 14.0, 0, TAU, 24, Color("#e1f5ee"), 2.0)

func _load_marker_textures(visual: Dictionary) -> void:
	marker_textures.clear()
	marker_sizes = visual.get("markerLogicalSizes", {}).duplicate(true) if visual.get("markerLogicalSizes") is Dictionary else {}
	var paths: Dictionary = visual.get("markerTextures", {}) if visual.get("markerTextures") is Dictionary else {}
	for marker_kind in paths:
		var path := str(paths[marker_kind])
		if path.is_empty() or not ResourceLoader.exists(path, "Texture2D"):
			continue
		var texture := load(path) as Texture2D
		if texture != null:
			marker_textures[str(marker_kind)] = texture

func _draw_object_marker(kind: String, marker: Vector2) -> void:
	var texture_kind := str({
		"enemy_group": "enemy_group",
		"elite_enemy": "enemy_group",
		"resource": "resource",
		"dungeon": "dungeon",
		"boss": "boss",
		"map_exit": "map_exit",
		# Optional high-definition interaction markers. They are intentionally
		# data-driven: until approved textures are added to visual.markerTextures,
		# the existing deterministic fallback symbols remain active.
		"treasure_chest": "treasure_chest",
		"landmark_event": "landmark_event",
		"story_event": "story_event",
		"shortcut": "shortcut",
	}.get(kind, ""))
	if not texture_kind.is_empty() and _draw_marker_texture(texture_kind, marker, "center" if kind == "boss" else "bottom"):
		if kind == "elite_enemy":
			draw_arc(marker, tile_size * 0.39, 0, TAU, 28, Color("#e7bd72"), 2.0)
		return
	match kind:
		"enemy_group":
			_draw_diamond(marker, tile_size * 0.31, Color("#e45e54"))
		"elite_enemy":
			_draw_diamond(marker, tile_size * 0.33, Color("#f08a58"))
			draw_arc(marker, tile_size * 0.39, 0, TAU, 28, Color("#e7bd72"), 2.0)
		"treasure_chest":
			draw_rect(Rect2(marker - Vector2(14, 8), Vector2(28, 18)), Color("#d6a344"))
			draw_line(marker - Vector2(14, -1), marker + Vector2(14, -1), Color("#ffe09a"), 2.0)
		"landmark_event":
			draw_arc(marker, tile_size * 0.30, 0, TAU, 24, Color("#d5b45b"), 3.0)
		"shortcut":
			draw_arc(marker, tile_size * 0.28, 0, TAU, 24, Color("#85a8bd"), 3.0)
			draw_line(marker + Vector2(-7, 3), marker + Vector2(7, -5), Color("#d6e5e8"), 2.0)
		"boss":
			_draw_diamond(marker, tile_size * 0.36, Color("#c74a3f"))
		"map_exit":
			_draw_diamond(marker, tile_size * 0.29, Color("#5bb7d9"))
		_:
			_draw_diamond(marker, tile_size * 0.27, Color("#ae69d6"))

func _draw_marker_texture(kind: String, marker: Vector2, anchor: String) -> bool:
	var texture := marker_textures.get(kind) as Texture2D
	if texture == null:
		return false
	var logical_size := float(marker_sizes.get(kind, 32 if kind in ["party", "boss"] else 24))
	var destination := Rect2(
		marker - Vector2(logical_size * 0.5, logical_size if anchor == "bottom" else logical_size * 0.5),
		Vector2(logical_size, logical_size)
	)
	draw_texture_rect(texture, destination, false)
	return true

func _draw_diamond(center: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)])
	draw_colored_polygon(points, color)
