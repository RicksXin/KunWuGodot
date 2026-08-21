extends SceneTree

const SCENE_PATH := "res://scenes/maps/map_01_d1_environment.tscn"
const OVERVIEW_PATH := "res://art/review/map01/map01_d1_environment_overview.png"
const VIEWPORT_PATH := "res://art/review/map01/map01_d1_environment_viewport_375x817.png"
const MAP_DISPLAY_SIZE := Vector2(2304.0, 3072.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/review/map01"))
	var overview_error := await _capture(
		Vector2i(2352, 3120),
		Vector2(24.0, 24.0),
		OVERVIEW_PATH
	)
	if overview_error != OK:
		push_error("Could not capture Map01 D1 overview: %s" % error_string(overview_error))
		quit(1)
		return
	var viewport_size := Vector2i(375, 817)
	var center := Vector2(24.0 * 48.0, 37.0 * 48.0)
	var viewport_error := await _capture(
		viewport_size,
		Vector2(viewport_size) * 0.5 - center,
		VIEWPORT_PATH
	)
	if viewport_error != OK:
		push_error("Could not capture Map01 D1 exploration viewport: %s" % error_string(viewport_error))
		quit(1)
		return
	print("MAP01_D1_CAPTURE_OK overview=%s viewport=%s" % [OVERVIEW_PATH, VIEWPORT_PATH])
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
	var environment := (load(SCENE_PATH) as PackedScene).instantiate()
	holder.add_child(environment)
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
