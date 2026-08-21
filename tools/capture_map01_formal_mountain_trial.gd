extends SceneTree

const SCENE_PATH := "res://scenes/maps/map_01.tscn"
const REVIEW_DIR := "res://art/review/map01/map01_formal_mountain_trial"
const OVERVIEW_PATH := REVIEW_DIR + "/map01_formal_mountain_overview_768x768.png"
const MOBILE_PATH := REVIEW_DIR + "/map01_formal_mountain_fit_375x817.png"
const MAP_VISUAL_SIZE := Vector2(768.0, 768.0)


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_DIR))
	var overview_error := await _capture(Vector2i(768, 768), Vector2(24.0, 24.0), Vector2.ONE, OVERVIEW_PATH)
	if overview_error != OK:
		push_error("Could not capture Map01 formal mountain overview: %s" % error_string(overview_error))
		quit(1)
		return
	var mobile_scale := 351.0 / MAP_VISUAL_SIZE.x
	var mobile_origin := Vector2(12.0, (817.0 - 351.0) * 0.5) + Vector2(24.0, 24.0) * mobile_scale
	var mobile_error := await _capture(Vector2i(375, 817), mobile_origin, Vector2.ONE * mobile_scale, MOBILE_PATH)
	if mobile_error != OK:
		push_error("Could not capture Map01 formal mountain mobile fit: %s" % error_string(mobile_error))
		quit(1)
		return
	print("MAP01_FORMAL_MOUNTAIN_CAPTURE_OK overview=%s mobile=%s" % [OVERVIEW_PATH, MOBILE_PATH])
	quit(0)


func _capture(size: Vector2i, world_origin: Vector2, world_scale: Vector2, output_path: String) -> Error:
	var viewport := SubViewport.new()
	viewport.size = size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = world_origin
	holder.scale = world_scale
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
