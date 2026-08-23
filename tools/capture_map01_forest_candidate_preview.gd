extends SceneTree

const SCENE_PATH := "res://scenes/maps/map_01_d1_environment.tscn"
const CANDIDATE_TEXTURE_PATH := "res://art/candidates/map01_forest_boundary/compiled/map01_d1_forest_gpt_v1_composite.png"
const REVIEW_DIR := "res://art/review/map01/map01_forest_candidate"
const FULL_PATH := REVIEW_DIR + "/map01_d1_forest_gpt_v1_overview.png"
const VIEWPORT_PATH := REVIEW_DIR + "/map01_d1_forest_gpt_v1_viewport_375x817.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var full_error := await _capture(Vector2i(2352, 3120), Vector2(24.0, 24.0), FULL_PATH)
	if full_error != OK:
		push_error("Could not capture full forest candidate: %s" % error_string(full_error))
		quit(1)
		return
	var viewport_error := await _capture(Vector2i(375, 817), Vector2(-4.0, -24.0), VIEWPORT_PATH)
	if viewport_error != OK:
		push_error("Could not capture Map01-size forest candidate: %s" % error_string(viewport_error))
		quit(1)
		return
	print("MAP01_FOREST_CANDIDATE_CAPTURE_OK full=%s viewport=%s" % [FULL_PATH, VIEWPORT_PATH])
	quit(0)


func _capture(size: Vector2i, world_offset: Vector2, output_path: String) -> Error:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = world_offset
	viewport.add_child(holder)
	var packed := load(SCENE_PATH) as PackedScene
	var candidate_image := Image.load_from_file(ProjectSettings.globalize_path(CANDIDATE_TEXTURE_PATH))
	var candidate := ImageTexture.create_from_image(candidate_image) if candidate_image != null and not candidate_image.is_empty() else null
	if packed == null or candidate == null:
		await _dispose_viewport(viewport)
		return ERR_FILE_NOT_FOUND
	var scene := packed.instantiate()
	var forest := scene.get_node_or_null("ForestBoundary") as Sprite2D
	if forest == null:
		await _dispose_viewport(viewport)
		return ERR_DOES_NOT_EXIST
	forest.texture = candidate
	forest.visible = true
	holder.add_child(scene)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		await _dispose_viewport(viewport)
		return ERR_CANT_CREATE
	var error := image.save_png(ProjectSettings.globalize_path(output_path))
	await _dispose_viewport(viewport)
	return error


func _dispose_viewport(viewport: SubViewport) -> void:
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	if viewport.get_parent() != null:
		viewport.get_parent().remove_child(viewport)
	viewport.free()
	await process_frame
	await process_frame
	await process_frame
	await process_frame
