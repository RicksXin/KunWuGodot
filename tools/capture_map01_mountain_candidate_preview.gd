extends SceneTree

const SCENE_PATH := "res://art/review/map01/map01_mountain_candidate/map01_mountain_candidate_preview.tscn"
const REVIEW_DIR := "res://art/review/map01/map01_mountain_candidate"
const FULL_PATH := REVIEW_DIR + "/map01_mountain_candidate_full_384x864.png"
const VIEWPORT_PATH := REVIEW_DIR + "/map01_mountain_candidate_375x817.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var full_error := await _capture(Vector2i(384, 864), Vector2.ZERO, FULL_PATH)
	if full_error != OK:
		push_error("Could not capture full mountain candidate: %s" % error_string(full_error))
		quit(1)
		return
	var viewport_error := await _capture(Vector2i(375, 817), Vector2(-4.0, -24.0), VIEWPORT_PATH)
	if viewport_error != OK:
		push_error("Could not capture Map01-size mountain candidate: %s" % error_string(viewport_error))
		quit(1)
		return
	print("MAP01_MOUNTAIN_CANDIDATE_CAPTURE_OK full=%s viewport=%s" % [FULL_PATH, VIEWPORT_PATH])
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
	if packed == null:
		await _dispose_viewport(viewport)
		return ERR_FILE_NOT_FOUND
	var scene := packed.instantiate()
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
