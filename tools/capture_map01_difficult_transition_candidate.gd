extends SceneTree

const ENVIRONMENT_SCENE_PATH := "res://scenes/maps/map_01_d1_environment.tscn"
const GROUND_TILESET_PATH := "res://resources/tilemapdual_standard.tres"
const ROAD_TILESET_PATH := "res://resources/tilemapdual_map01_road.tres"
const DIFFICULT_TILESET_PATH := "res://resources/tilemapdual_map01_difficult.tres"
const TILEMAP_DUAL_SCRIPT_PATH := "res://addons/TileMapDual/tile_map_dual.gd"
const REVIEW_DIR := "res://art/review/map01/map01_no_difficult_candidate"
const CURRENT_PATH := REVIEW_DIR + "/map01_current_with_difficult_viewport_375x817.png"
const CANDIDATE_PATH := REVIEW_DIR + "/map01_no_difficult_viewport_375x817.png"
const COMPARISON_PATH := REVIEW_DIR + "/map01_current_vs_no_difficult.png"
const OVERVIEW_PATH := REVIEW_DIR + "/map01_no_difficult_overview.png"
const PATTERNS_PATH := REVIEW_DIR + "/map01_no_difficult_patterns.png"
const MANIFEST_PATH := REVIEW_DIR + "/review_manifest.json"

const COMPLETE_TILE := Vector2i(2, 1)
const MAP_SCALE := Vector2(0.1875, 0.1875)
const CANDIDATE_MODULATE := Color(1.0, 1.0, 1.0, 0.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var viewport_size := Vector2i(375, 817)
	var center := Vector2(24.0 * 48.0, 37.0 * 48.0)
	var world_offset := Vector2(viewport_size) * 0.5 - center

	var current := await _capture_environment(viewport_size, world_offset, Color.WHITE)
	var candidate := await _capture_environment(viewport_size, world_offset, CANDIDATE_MODULATE)
	var overview := await _capture_environment(
		Vector2i(2352, 3120),
		Vector2(24.0, 24.0),
		CANDIDATE_MODULATE
	)
	var patterns := await _capture_patterns()
	assert(not current.is_empty(), "Could not capture current difficult-terrain viewport")
	assert(not candidate.is_empty(), "Could not capture candidate difficult-terrain viewport")
	assert(not overview.is_empty(), "Could not capture candidate difficult-terrain overview")
	assert(not patterns.is_empty(), "Could not capture candidate difficult-terrain patterns")
	assert(current.save_png(ProjectSettings.globalize_path(CURRENT_PATH)) == OK)
	assert(candidate.save_png(ProjectSettings.globalize_path(CANDIDATE_PATH)) == OK)
	assert(overview.save_png(ProjectSettings.globalize_path(OVERVIEW_PATH)) == OK)
	assert(patterns.save_png(ProjectSettings.globalize_path(PATTERNS_PATH)) == OK)

	var comparison := Image.create(viewport_size.x * 2, viewport_size.y, false, Image.FORMAT_RGBA8)
	comparison.blit_rect(current, Rect2i(Vector2i.ZERO, viewport_size), Vector2i.ZERO)
	comparison.blit_rect(candidate, Rect2i(Vector2i.ZERO, viewport_size), Vector2i(viewport_size.x, 0))
	assert(comparison.save_png(ProjectSettings.globalize_path(COMPARISON_PATH)) == OK)
	_write_manifest()
	print("MAP01_DIFFICULT_TRANSITION_CANDIDATE_CAPTURE_OK comparison=%s" % COMPARISON_PATH)
	quit(0)


func _capture_environment(size: Vector2i, world_offset: Vector2, difficult_modulate: Color) -> Image:
	var viewport := _make_viewport(size)
	var holder := Node2D.new()
	holder.position = world_offset
	viewport.add_child(holder)
	var packed := load(ENVIRONMENT_SCENE_PATH) as PackedScene
	assert(packed != null, "Map01 D1 environment scene is missing")
	var environment := packed.instantiate()
	var difficult_visual := environment.get_node("DifficultVisual") as TileMapLayer
	assert(difficult_visual != null, "DifficultVisual layer is missing")
	difficult_visual.modulate = difficult_modulate
	holder.add_child(environment)
	var image := await _read_viewport(viewport)
	await _dispose_viewport(viewport)
	return image


func _capture_patterns() -> Image:
	var viewport := _make_viewport(Vector2i(816, 624))
	var root_node := Node2D.new()
	root_node.position = Vector2(24.0, 24.0)
	root_node.scale = MAP_SCALE
	viewport.add_child(root_node)

	var ground := _make_dual_layer("Ground", load(GROUND_TILESET_PATH) as TileSet, 0, Color.WHITE)
	for y in range(12):
		for x in range(16):
			ground.set_cell(Vector2i(x, y), 0, COMPLETE_TILE)
	root_node.add_child(ground)

	var road := _make_dual_layer("Road", load(ROAD_TILESET_PATH) as TileSet, 1, Color.WHITE)
	for y in range(12):
		for x in range(6, 10):
			road.set_cell(Vector2i(x, y), 0, COMPLETE_TILE)
	root_node.add_child(road)

	var difficult := _make_dual_layer(
		"DifficultCandidate",
		load(DIFFICULT_TILESET_PATH) as TileSet,
		2,
		CANDIDATE_MODULATE
	)
	for cell in _pattern_cells():
		difficult.set_cell(cell, 0, COMPLETE_TILE)
	root_node.add_child(difficult)

	var image := await _read_viewport(viewport)
	await _dispose_viewport(viewport)
	return image


func _make_dual_layer(node_name: String, tile_set: TileSet, layer_z: int, layer_modulate: Color) -> TileMapLayer:
	assert(tile_set != null, "%s TileSet is missing" % node_name)
	var layer := TileMapLayer.new()
	layer.name = node_name
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.z_index = layer_z
	layer.tile_set = tile_set
	layer.modulate = layer_modulate
	layer.set_script(load(TILEMAP_DUAL_SCRIPT_PATH))
	return layer


func _pattern_cells() -> Array[Vector2i]:
	return [
		# Ring with a one-cell hole.
		Vector2i(1, 1), Vector2i(2, 1), Vector2i(3, 1),
		Vector2i(1, 2), Vector2i(3, 2),
		Vector2i(1, 3), Vector2i(2, 3), Vector2i(3, 3),
		# L bend crossing the road background.
		Vector2i(6, 1), Vector2i(7, 1), Vector2i(8, 1),
		Vector2i(8, 2), Vector2i(8, 3),
		# One-cell island, corridors and both diagonal contacts.
		Vector2i(2, 7),
		Vector2i(5, 7), Vector2i(6, 7), Vector2i(7, 7), Vector2i(8, 7),
		Vector2i(11, 6), Vector2i(11, 7), Vector2i(11, 8), Vector2i(11, 9),
		Vector2i(14, 6), Vector2i(15, 7),
		Vector2i(15, 9), Vector2i(14, 10),
	]


func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport


func _read_viewport(viewport: SubViewport) -> Image:
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	assert(image != null and not image.is_empty(), "SubViewport returned an empty image")
	return image


func _dispose_viewport(viewport: SubViewport) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if viewport.get_parent() != null:
		viewport.get_parent().remove_child(viewport)
	viewport.free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame


func _write_manifest() -> void:
	var manifest := {
		"schema_version": 1,
		"status": "candidate_pending_user_visual_gate",
		"purpose": "Preview Map01 with no difficult terrain",
		"source_scene": ENVIRONMENT_SCENE_PATH,
		"source_tileset": DIFFICULT_TILESET_PATH,
		"candidate_change": "Preview hides DifficultVisual; promotion must remove both D1 semantic and visual difficult-terrain layers",
		"candidate_modulate_rgba": [
			CANDIDATE_MODULATE.r,
			CANDIDATE_MODULATE.g,
			CANDIDATE_MODULATE.b,
			CANDIDATE_MODULATE.a,
		],
		"difficult_cell_count": 121,
		"preview_semantic_cells_changed": false,
		"promotion_semantic_cells_changed": true,
		"meowa_points_spent": 0,
		"review_outputs": [CURRENT_PATH, CANDIDATE_PATH, COMPARISON_PATH, OVERVIEW_PATH, PATTERNS_PATH],
	}
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.WRITE)
	assert(file != null, "Could not create difficult-terrain candidate manifest")
	file.store_string(JSON.stringify(manifest, "  ") + "\n")
