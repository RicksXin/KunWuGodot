extends SceneTree

const SCENE_PATH := "res://scenes/maps/map_01_d1_landmark_preview.tscn"
const OUTPUT_PATH := "res://art/candidates/map01_mountain_ridge/review/map01_d1_landmark_no_ridge_base.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#11161b"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/candidates/map01_mountain_ridge/review"))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(2352, 3120)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var holder := Node2D.new()
	holder.position = Vector2(24.0, 24.0)
	viewport.add_child(holder)
	var preview := (load(SCENE_PATH) as PackedScene).instantiate()
	holder.add_child(preview)
	var ridge := preview.get_node_or_null("Environment/MountainRidge") as CanvasItem
	if ridge != null:
		ridge.visible = false
	var mountain_body := preview.get_node_or_null("Environment/MountainBody") as CanvasItem
	if mountain_body != null:
		mountain_body.visible = false
	var ui := preview.get_node_or_null("UI") as CanvasLayer
	if ui != null:
		ui.visible = false
	var camera := preview.get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = false
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture no-ridge Map01 D1 base")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save no-ridge Map01 D1 base: %s" % error_string(error))
		quit(1)
		return
	print("MAP01_D1_NO_RIDGE_BASE_CAPTURE_OK path=%s" % OUTPUT_PATH)
	quit(0)
