extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,1000)
	root.content_scale_size = Vector2i(1600,1000)
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	root.add_child(camp)
	camp.position = Vector2(900,80)
	camp.scale = Vector2.ONE*0.92
	for name in ["west_blend","central_slope"]:
		assert(camp.edge_overlays.get_node(name).z_index > camp.buildings.z_index)
	camp.actor.hide()
	camp.overlay.hide()
	for i in range(10): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://Docs/Artifacts/camp-tilemap-exploration/foreground-rocks.png")
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	assert(panel.canvas.world.has_node("ForegroundRocks"))
	var foreground: Sprite2D = panel.canvas.world.get_node("ForegroundRocks")
	for sprite in panel.canvas.sprites: assert(sprite.z_index < foreground.z_index)
	panel.canvas.refresh()
	assert(is_instance_valid(foreground))
	print("PASS foreground rocks: runtime layer above buildings; editor foreground survives refresh and stays above all building sprites")
	quit()
