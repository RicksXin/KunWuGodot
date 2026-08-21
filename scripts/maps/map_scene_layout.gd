class_name KWMapSceneLayout
extends RefCounted

const GROUND_SOURCE_ID := 0
const COMPLETE_TILE := Vector2i(2, 1)

static func load_layout(scene_path: String) -> Dictionary:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return {}
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return {}
	var instance := packed.instantiate()
	var ground := instance.get_node_or_null("Ground") as TileMapLayer
	var difficult := instance.get_node_or_null("DifficultTerrain") as TileMapLayer
	var markers := instance.get_node_or_null("Markers")
	if ground == null or difficult == null or markers == null:
		instance.free()
		return {}
	var width := int(instance.get("active_width"))
	var height := int(instance.get("active_height"))
	if width <= 0 or height <= 0:
		instance.free()
		return {}
	var ground_cells: Dictionary = {}
	for cell in ground.get_used_cells():
		ground_cells[cell] = true
	var difficult_cells: Dictionary = {}
	for cell in difficult.get_used_cells():
		difficult_cells[cell] = true
	var entry := Vector2i(-1, -1)
	var object_positions: Dictionary = {}
	for marker in markers.get_children():
		var marker_id := str(marker.get("marker_id"))
		var marker_kind := str(marker.get("marker_kind"))
		var domain_cell: Vector2i = marker.get("domain_cell")
		if marker_kind == "entry":
			entry = domain_cell
		elif not marker_id.is_empty():
			object_positions[marker_id] = {
				"x": domain_cell.x,
				"y": domain_cell.y,
				"kind": marker_kind,
			}
	var rows: Array[String] = []
	for screen_y in height:
		var row := ""
		for x in width:
			var scene_cell := Vector2i(x, screen_y)
			var domain_y := height - 1 - screen_y
			if not ground_cells.has(scene_cell):
				row += "#"
			elif entry == Vector2i(x, domain_y):
				row += "E"
			elif difficult_cells.has(scene_cell):
				row += "~"
			else:
				row += "."
		rows.append(row)
	var result := {
		"activeWidth": width,
		"activeHeight": height,
		"entryX": entry.x,
		"entryY": entry.y,
		"terrainRows": rows,
		"groundCells": ground_cells.keys(),
		"difficultCells": difficult_cells.keys(),
		"objectPositions": object_positions,
		"scenePath": scene_path,
	}
	instance.free()
	return result

static func ground_uses_complete_tiles(scene_path: String) -> bool:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		return false
	var instance := packed.instantiate()
	var ground := instance.get_node_or_null("Ground") as TileMapLayer
	if ground == null:
		instance.free()
		return false
	for cell in ground.get_used_cells():
		if ground.get_cell_source_id(cell) != GROUND_SOURCE_ID \
			or ground.get_cell_atlas_coords(cell) != COMPLETE_TILE \
			or ground.get_cell_alternative_tile(cell) != 0:
			instance.free()
			return false
	instance.free()
	return true
