extends SceneTree

const PATTERN_SCENE_PATH := "res://art/review/map01/map01_road_dual_transition_candidate/map01_road_dual_candidate_patterns.tscn"
const ENVIRONMENT_SCENE_PATH := "res://scenes/maps/map_01_d1_environment.tscn"
const TILESET_PATH := "res://art/review/map01/map01_road_dual_transition_candidate/tilemapdual_map01_road_dual_candidate.tres"
const REVIEW_DIR := "res://art/review/map01/map01_road_dual_transition_candidate"
const PATTERN_PATH := REVIEW_DIR + "/map01_road_dual_candidate_patterns.png"
const OVERVIEW_PATH := REVIEW_DIR + "/map01_road_dual_candidate_overview.png"
const VIEWPORT_PATH := REVIEW_DIR + "/map01_road_dual_candidate_viewport_375x817.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var pattern_error := await _capture_patterns()
	if pattern_error != OK:
		push_error("Could not capture road pattern candidate: %s" % error_string(pattern_error))
		quit(1)
		return
	var overview_error := await _capture_environment(
		Vector2i(2352, 3120),
		Vector2(24.0, 24.0),
		OVERVIEW_PATH
	)
	if overview_error != OK:
		push_error("Could not capture road candidate overview: %s" % error_string(overview_error))
		quit(1)
		return
	var viewport_size := Vector2i(375, 817)
	var center := Vector2(24.0 * 48.0, 37.0 * 48.0)
	var viewport_error := await _capture_environment(
		viewport_size,
		Vector2(viewport_size) * 0.5 - center,
		VIEWPORT_PATH
	)
	if viewport_error != OK:
		push_error("Could not capture road candidate viewport: %s" % error_string(viewport_error))
		quit(1)
		return
	print("MAP01_ROAD_DUAL_CANDIDATE_CAPTURE_OK overview=%s viewport=%s" % [OVERVIEW_PATH, VIEWPORT_PATH])
	quit(0)


func _capture_patterns() -> Error:
	var viewport := _make_viewport(Vector2i(816, 624))
	var packed := load(PATTERN_SCENE_PATH) as PackedScene
	if packed == null:
		await _dispose_viewport(viewport)
		return ERR_FILE_NOT_FOUND
	viewport.add_child(packed.instantiate())
	var error := await _save_viewport(viewport, PATTERN_PATH)
	await _dispose_viewport(viewport)
	return error


func _capture_environment(size: Vector2i, world_offset: Vector2, output_path: String) -> Error:
	var viewport := _make_viewport(size)
	var holder := Node2D.new()
	holder.position = world_offset
	viewport.add_child(holder)
	var packed := load(ENVIRONMENT_SCENE_PATH) as PackedScene
	var road_tile_set := load(TILESET_PATH) as TileSet
	if packed == null or road_tile_set == null:
		await _dispose_viewport(viewport)
		return ERR_FILE_NOT_FOUND
	var environment := packed.instantiate()
	var road := environment.get_node("RoadVisual") as TileMapLayer
	if road == null:
		environment.free()
		await _dispose_viewport(viewport)
		return ERR_INVALID_DATA
	road.tile_set = road_tile_set
	holder.add_child(environment)
	var error := await _save_viewport(viewport, output_path)
	await _dispose_viewport(viewport)
	return error


func _make_viewport(size: Vector2i) -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	return viewport


func _save_viewport(viewport: SubViewport, output_path: String) -> Error:
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return ERR_CANT_CREATE
	return image.save_png(ProjectSettings.globalize_path(output_path))


func _dispose_viewport(viewport: SubViewport) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if viewport.get_parent() != null:
		viewport.get_parent().remove_child(viewport)
	viewport.free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
