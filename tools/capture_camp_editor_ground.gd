extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_size = Vector2i(2048,1536)
	root.size = Vector2i(2048,1536)
	root.transparent_bg = true
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	root.add_child(camp)
	camp.position = Vector2(1024,256)
	camp.buildings.hide()
	camp.overlay.hide()
	camp.actor.hide()
	camp.route_line.hide()
	camp.set_process(false)
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://addons/camp_layout_editor/ground_preview.png")
	print("Camp editor ground capture: ",error)
	quit(error)
