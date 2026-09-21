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
	var foreground := Node2D.new()
	foreground.position = camp.position
	for rock in camp.edge_overlays.get_children():
		if rock.z_index > 0:
			foreground.add_child(rock.duplicate())
			rock.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png("res://addons/camp_layout_editor/ground_preview.png")
	assert(error == OK)
	camp.hide()
	root.add_child(foreground)
	await process_frame
	await RenderingServer.frame_post_draw
	error = root.get_texture().get_image().save_png("res://addons/camp_layout_editor/foreground_preview.png")
	print("Camp editor ground/foreground capture: ",error)
	quit(error)
