extends SceneTree

const SCENE_PATH := "res://scenes/map01_east_wall_stairs_demo.tscn"
const OUTPUT_PATH := "res://art/review/map01/map01_east_wall_stairs_demo_375x817.png"


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	RenderingServer.set_default_clear_color(Color("#0e1217"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(375, 817)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	var demo := (load(SCENE_PATH) as PackedScene).instantiate()
	viewport.add_child(demo)
	await process_frame
	await process_frame
	await process_frame
	await process_frame
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("Could not capture Map01 east-wall stair demo")
		quit(1)
		return
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save Map01 east-wall stair demo: %s" % error_string(error))
		quit(1)
		return
	print("MAP01_EAST_WALL_STAIRS_CAPTURE_OK")
	quit(0)
