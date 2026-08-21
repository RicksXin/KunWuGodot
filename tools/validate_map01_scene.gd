extends SceneTree

const MAP_ID := "map_01"
const SCENE_PATH := "res://scenes/maps/map_01.tscn"
const COMPLETE_TILE := Vector2i(2, 1)
const GROUND_TILESET_PATH := "res://resources/tilemapdual_standard.tres"
const MOUNTAIN_TILESET_PATH := "res://resources/tilemapdual_map01_mountain.tres"

var errors: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var layout := KWMapSceneLayout.load_layout(SCENE_PATH)
	_check(not layout.is_empty(), "Map01 layout could not be loaded")
	if layout.is_empty():
		_finish()
		return
	var game := root.get_node_or_null("Game")
	_check(game != null, "Game autoload is missing")
	if game == null:
		_finish()
		return
	var original_profile: Dictionary = game.get("profile").duplicate(true)
	var ground_cells: Array = layout.get("groundCells", [])
	var difficult_cells: Array = layout.get("difficultCells", [])
	_check(not ground_cells.is_empty(), "Ground must contain walkable cells")
	for cell in difficult_cells:
		_check(cell in ground_cells, "DifficultTerrain cell %s is outside Ground" % [cell])
	_check(KWMapSceneLayout.ground_uses_complete_tiles(SCENE_PATH), "Ground contains a tile other than complete 0xF")

	var configured: Dictionary = game.call("get_map_definition", MAP_ID)
	_check(str(configured.get("layoutSource", "")) == "godot_scene", "Game did not merge the Godot scene layout")
	_check(str(configured.get("visual", {}).get("scenePath", "")) == SCENE_PATH, "Map01 visual.scenePath is incorrect")
	_check(int(configured.get("activeWidth", 0)) == int(layout.get("activeWidth", -1)), "activeWidth differs from scene")
	_check(int(configured.get("activeHeight", 0)) == int(layout.get("activeHeight", -1)), "activeHeight differs from scene")
	var width := int(layout.get("activeWidth", 0))
	var height := int(layout.get("activeHeight", 0))
	var entry := Vector2i(int(layout.get("entryX", -1)), int(layout.get("entryY", -1)))
	var entry_scene_cell := Vector2i(entry.x, height - 1 - entry.y)
	_check(entry_scene_cell in ground_cells, "Entry marker is not on Ground")

	var positions: Dictionary = layout.get("objectPositions", {})
	var configured_ids: Array[String] = []
	for object in configured.get("objects", []):
		var object_id := str(object.get("id", ""))
		configured_ids.append(object_id)
		_check(positions.has(object_id), "Scene marker is missing for object %s" % object_id)
		var domain_cell := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		var scene_cell := Vector2i(domain_cell.x, height - 1 - domain_cell.y)
		_check(scene_cell in ground_cells, "Object %s is not on Ground" % object_id)
	for marker_id in positions:
		_check(str(marker_id) in configured_ids, "Marker %s has no product configuration" % marker_id)

	var profile: Dictionary = game.get("profile")
	var original_expedition: Variant = profile.get("expedition")
	profile["expedition"] = {"mapId": MAP_ID}
	game.set("profile", profile)
	var rows: Array = layout.get("terrainRows", [])
	for screen_y in rows.size():
		var row: String = rows[screen_y]
		for x in row.length():
			var domain_y := height - 1 - screen_y
			var expected := row.substr(x, 1)
			var actual_tile: Dictionary = game.call("tile_at", x, domain_y)
			var actual := str(actual_tile.get("symbol", "#"))
			_check(actual == expected, "Game.tile_at differs at (%d,%d): %s != %s" % [x, domain_y, actual, expected])
	profile["expedition"] = original_expedition
	game.set("profile", profile)

	var packed := load(SCENE_PATH) as PackedScene
	var instance := packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var ground_underlay := instance.get_node_or_null("GroundUnderlay") as TileMapLayer
	var ground := instance.get_node_or_null("Ground") as TileMapLayer
	var mountain := instance.get_node_or_null("Mountain") as TileMapLayer
	_check(ground_underlay != null, "GroundUnderlay node is missing")
	if ground_underlay != null:
		_check(ground_underlay.get_script() != null and ground_underlay.get_script().resource_path == "res://addons/TileMapDual/tile_map_dual.gd", "GroundUnderlay is not a TileMapDual layer")
		_check(ground_underlay.tile_set != null and ground_underlay.tile_set.resource_path == GROUND_TILESET_PATH, "GroundUnderlay uses the wrong TileSet")
		_check(ground_underlay.z_index == -1, "GroundUnderlay is not below the logical Ground layer")
		_check(ground_underlay.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "GroundUnderlay does not use nearest filtering")
		var underlay_cells := ground_underlay.get_used_cells()
		_check(underlay_cells.size() == width * height, "GroundUnderlay does not cover the full active area")
		for screen_y in height:
			for x in width:
				var cell := Vector2i(x, screen_y)
				_check(cell in underlay_cells, "GroundUnderlay is missing active cell %s" % [cell])
				_check(ground_underlay.get_cell_source_id(cell) == 0 and ground_underlay.get_cell_atlas_coords(cell) == COMPLETE_TILE and ground_underlay.get_cell_alternative_tile(cell) == 0, "GroundUnderlay cell %s is not complete 0xF" % [cell])
		for cell in underlay_cells:
			_check(cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height, "GroundUnderlay cell %s is outside the active area" % [cell])
		_check(ground_underlay.get_child_count() == 1, "GroundUnderlay TileMapDual runtime display was not created")
		if ground_underlay.get_child_count() == 1:
			var underlay_display := ground_underlay.get_child(0)
			_check(underlay_display.get_child_count() == 1, "GroundUnderlay TileMapDual square display layer was not created")
			if underlay_display.get_child_count() == 1:
				var underlay_display_layer := underlay_display.get_child(0) as TileMapLayer
				_check(underlay_display_layer != null, "GroundUnderlay display child is not a TileMapLayer")
				if underlay_display_layer != null:
					_check(underlay_display_layer.position == Vector2(-128, -128), "GroundUnderlay TileMapDual display is not half-cell offset")
	_check(ground != null, "Ground node is missing")
	if ground != null:
		_check(ground.get_used_cells().size() == ground_cells.size(), "GroundUnderlay leaked into logical Ground walkability")
		_check(ground.get_script() != null and ground.get_script().resource_path == "res://addons/TileMapDual/tile_map_dual.gd", "Ground is not a TileMapDual layer")
		_check(ground.get_child_count() == 1, "TileMapDual runtime display was not created")
		if ground.get_child_count() == 1:
			var display := ground.get_child(0)
			_check(display.get_child_count() == 1, "TileMapDual square display layer was not created")
			if display.get_child_count() == 1:
				var display_layer := display.get_child(0) as TileMapLayer
				_check(display_layer != null, "TileMapDual display child is not a TileMapLayer")
				if display_layer != null:
					_check(display_layer.position == Vector2(-128, -128), "TileMapDual display is not half-cell offset")
	_check(mountain != null, "Mountain node is missing")
	if mountain != null:
		_check(mountain.get_script() != null and mountain.get_script().resource_path == "res://addons/TileMapDual/tile_map_dual.gd", "Mountain is not a TileMapDual layer")
		_check(mountain.tile_set != null and mountain.tile_set.resource_path == MOUNTAIN_TILESET_PATH, "Mountain uses the wrong TileSet")
		var mountain_cells := mountain.get_used_cells()
		_check(mountain_cells.size() == width * height - ground_cells.size(), "Mountain cell count does not match the non-Ground complement")
		for screen_y in height:
			for x in width:
				var cell := Vector2i(x, screen_y)
				_check((cell in mountain_cells) != (cell in ground_cells), "Mountain/Ground complement differs at %s" % [cell])
		for cell in mountain_cells:
			_check(cell.x >= 0 and cell.x < width and cell.y >= 0 and cell.y < height, "Mountain cell %s is outside the active area" % [cell])
			_check(mountain.get_cell_source_id(cell) == 0 and mountain.get_cell_atlas_coords(cell) == COMPLETE_TILE and mountain.get_cell_alternative_tile(cell) == 0, "Mountain cell %s is not complete 0xF" % [cell])
		_check(mountain.get_child_count() == 1, "Mountain TileMapDual runtime display was not created")
		if mountain.get_child_count() == 1:
			var mountain_display := mountain.get_child(0)
			_check(mountain_display.get_child_count() == 1, "Mountain TileMapDual square display layer was not created")
			if mountain_display.get_child_count() == 1:
				var mountain_display_layer := mountain_display.get_child(0) as TileMapLayer
				_check(mountain_display_layer != null, "Mountain TileMapDual display child is not a TileMapLayer")
				if mountain_display_layer != null:
					_check(mountain_display_layer.position == Vector2(-128, -128), "Mountain TileMapDual display is not half-cell offset")
	instance.free()
	await process_frame
	await process_frame

	var validation_profile: Dictionary = game.get("default_profile").duplicate(true)
	game.set("profile", validation_profile)
	game.call("_normalise_profile")
	var prepared_heroes: Array = game.call("party_heroes")
	_check(prepared_heroes.size() == 4, "Null expedition did not resolve the active preparation party")
	var camp_page := (load("res://scenes/camp.tscn") as PackedScene).instantiate()
	root.add_child(camp_page)
	await process_frame
	await process_frame
	camp_page.call("_open_expedition")
	await process_frame
	_check(camp_page.get("modal") != null, "Portal did not create the expedition preparation modal")
	var preparation_animations: Array = camp_page.get("animated_portraits")
	_check(preparation_animations.size() == 3, "Expedition preparation stopped before all hero cards were built")
	camp_page.free()
	await process_frame
	await process_frame
	var start_result: Dictionary = game.call("start_expedition", {"spiritGrain": 60, "pickaxe": 0, "lens": 0}, MAP_ID)
	_check(bool(start_result.get("ok", false)), "Could not create isolated Map01 expedition: %s" % start_result.get("message", "unknown"))
	if start_result.get("ok", false):
		var map_page := (load("res://scenes/map.tscn") as PackedScene).instantiate()
		root.add_child(map_page)
		await process_frame
		await process_frame
		await process_frame
		var map_canvas := map_page.get("map_canvas") as Control
		_check(map_canvas != null, "Map runtime did not create MapCanvas")
		if map_canvas != null:
			_check(map_canvas.get("terrain_instance") != null, "MapCanvas did not instantiate Map01 terrain")
			_check(map_canvas.get("overlay") != null, "MapCanvas did not create the fog/marker overlay")
		var move_result: Dictionary = game.call("move_expedition", 1, 0)
		_check(bool(move_result.get("ok", false)), "Scene-derived movement from Entry to (3,2) failed")
		if move_result.get("ok", false):
			var moved_to: Dictionary = move_result.get("position", {})
			_check(int(moved_to.get("x", -1)) == 3 and int(moved_to.get("y", -1)) == 2, "Scene-derived movement reached the wrong cell")
		map_page.free()
		await process_frame
		await process_frame
	game.set("profile", original_profile)
	_finish()

func _check(condition: bool, message: String) -> void:
	if not condition and not errors.has(message):
		errors.append(message)

func _finish() -> void:
	if errors.is_empty():
		print("MAP01_SCENE_VALIDATION_OK")
		quit(0)
		return
	for message in errors:
		push_error(message)
	print("MAP01_SCENE_VALIDATION_FAILED: %d error(s)" % errors.size())
	quit(1)
