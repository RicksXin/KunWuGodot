extends SceneTree

const SCENE_PATH := "res://scenes/maps/map_01_d1_environment.tscn"
const MASK_PATH := "res://art/candidates/map01_layout/map01_d1_environment_mask_20260820.json"
const DIFFICULT_TILESET_PATH := "res://resources/tilemapdual_map01_difficult.tres"
const COMPLETE_TILE := Vector2i(2, 1)

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var mask := _load_mask()
	if mask.is_empty():
		_finish()
		return
	_check(ResourceLoader.exists(SCENE_PATH, "PackedScene"), "D1 environment scene is missing")
	if not ResourceLoader.exists(SCENE_PATH, "PackedScene"):
		_finish()
		return
	var instance := (load(SCENE_PATH) as PackedScene).instantiate()
	_check(instance != null, "D1 environment scene could not instantiate")
	if instance == null:
		_finish()
		return
	_check(int(instance.get("active_width")) == 48, "D1 environment width must be 48")
	_check(int(instance.get("active_height")) == 64, "D1 environment height must be 64")
	_check(instance.get_node_or_null("Markers") == null, "No-object environment scene must not contain Markers")

	var ground := instance.get_node_or_null("Ground") as TileMapLayer
	var road := instance.get_node_or_null("RoadVisual") as TileMapLayer
	var difficult := instance.get_node_or_null("DifficultTerrain") as TileMapLayer
	var difficult_visual := instance.get_node_or_null("DifficultVisual") as TileMapLayer
	var rock := instance.get_node_or_null("RockBase") as Sprite2D
	var foreground := instance.get_node_or_null("ForegroundVisual") as Sprite2D
	_check(ground != null, "Ground layer is missing")
	_check(road != null, "RoadVisual layer is missing")
	_check(difficult != null, "DifficultTerrain layer is missing")
	_check(difficult_visual != null, "DifficultVisual layer is missing")
	_check(rock != null, "RockBase visual is missing")
	_check(foreground != null, "ForegroundVisual is missing")
	if ground == null or road == null or difficult == null or difficult_visual == null:
		instance.free()
		_finish()
		return

	var ground_cells := _cell_set(ground.get_used_cells())
	var road_cells := _cell_set(road.get_used_cells())
	var difficult_cells := _cell_set(difficult.get_used_cells())
	var difficult_visual_cells := _cell_set(difficult_visual.get_used_cells())
	_check(ground_cells == _json_cell_set(mask.get("groundCells", [])), "Ground cells differ from extracted mask")
	_check(road_cells == _json_cell_set(mask.get("roadCells", [])), "RoadVisual cells differ from extracted mask")
	_check(difficult_cells == _json_cell_set(mask.get("difficultCells", [])), "DifficultTerrain cells differ from extracted mask")
	_check(difficult_visual_cells == difficult_cells, "DifficultVisual cells differ from DifficultTerrain")
	for cell in road_cells:
		_check(ground_cells.has(cell), "RoadVisual cell %s is outside Ground" % [cell])
	for cell in difficult_cells:
		_check(ground_cells.has(cell), "DifficultTerrain cell %s is outside Ground" % [cell])
	_check(_uses_complete_tiles(ground), "Ground contains a tile other than complete 0xF")
	_check(_uses_complete_tiles(road), "RoadVisual contains a tile other than complete 0xF")
	_check(_uses_complete_tiles(difficult), "DifficultTerrain contains a tile other than complete 0xF")
	_check(_uses_complete_tiles(difficult_visual), "DifficultVisual contains a tile other than complete 0xF")
	_check(ground.get_script() != null and ground.get_script().resource_path == "res://addons/TileMapDual/tile_map_dual.gd", "Ground is not a TileMapDual layer")
	_check(road.get_script() != null and road.get_script().resource_path == "res://addons/TileMapDual/tile_map_dual.gd", "RoadVisual is not a TileMapDual layer")
	_check(difficult.get_script() == null, "DifficultTerrain must remain a semantic overlay, not a Dual Grid brush")
	_check(difficult_visual.get_script() != null and difficult_visual.get_script().resource_path == "res://addons/TileMapDual/tile_map_dual.gd", "DifficultVisual is not a TileMapDual layer")
	_check(difficult_visual.tile_set != null and difficult_visual.tile_set.resource_path == DIFFICULT_TILESET_PATH, "DifficultVisual must use the dedicated crushed-slate TileSet")
	if rock != null and rock.texture != null:
		_check(rock.texture.get_size() == Vector2(768.0, 1024.0), "RockBase source must be 768x1024")
	if foreground != null and foreground.texture != null:
		_check(foreground.texture.get_size() == Vector2(768.0, 1024.0), "Foreground source must be 768x1024")

	root.add_child(instance)
	await process_frame
	await process_frame
	await process_frame
	_check(ground.get_child_count() == 1, "Ground runtime Dual Grid display was not created")
	_check(road.get_child_count() == 1, "Road runtime Dual Grid display was not created")
	_check(difficult_visual.get_child_count() == 1, "DifficultVisual runtime Dual Grid display was not created")
	if foreground != null:
		instance.call("set_foreground_faded", true)
		_check(is_equal_approx(foreground.modulate.a, 0.22), "Foreground fade alpha is incorrect")
		instance.call("set_foreground_faded", false)
		_check(is_equal_approx(foreground.modulate.a, 1.0), "Foreground restore alpha is incorrect")
	root.remove_child(instance)
	instance.free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	_finish()


func _load_mask() -> Dictionary:
	if not FileAccess.file_exists(MASK_PATH):
		_check(false, "D1 environment mask JSON is missing")
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MASK_PATH))
	if not parsed is Dictionary:
		_check(false, "D1 environment mask JSON is invalid")
		return {}
	return parsed


func _cell_set(cells: Array[Vector2i]) -> Dictionary:
	var result: Dictionary = {}
	for cell in cells:
		result[cell] = true
	return result


func _json_cell_set(values: Array) -> Dictionary:
	var result: Dictionary = {}
	for value in values:
		result[Vector2i(int(value[0]), int(value[1]))] = true
	return result


func _uses_complete_tiles(layer: TileMapLayer) -> bool:
	for cell in layer.get_used_cells():
		if layer.get_cell_source_id(cell) != 0 \
			or layer.get_cell_atlas_coords(cell) != COMPLETE_TILE \
			or layer.get_cell_alternative_tile(cell) != 0:
			return false
	return true


func _check(condition: bool, message: String) -> void:
	if not condition and not failures.has(message):
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP01_D1_ENVIRONMENT_VALIDATION_OK")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("MAP01_D1_ENVIRONMENT_VALIDATION_FAILED: %d error(s)" % failures.size())
	quit(1)
