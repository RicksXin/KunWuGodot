extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	sample.load_fixture(14)
	sample._process(0)
	assert(sample.current_pattern == 14)
	var camp = sample.rebuild
	assert(camp.visible and camp.targets.size() == 7)
	assert(not sample.terrain.visible and not sample.exterior.visible)
	for target in camp.targets:
		assert(camp.move_to_node(target.node))
		for frame in range(2000): camp._process(0.02)
		assert(camp.route.is_empty() and camp.current == target.node)
	assert(camp.move_to_node(0))
	for frame in range(2000): camp._process(0.02)
	assert(camp.current == 0)
	assert(not camp.move_to_node(999))
	camp.move_to_node(16)
	camp._process(0.1)
	var before: Vector2 = camp.actor.position
	var next: int = camp.route[0]
	assert(camp.move_to_node(18))
	assert(camp.actor.position == before and camp.route[0] == next)
	camp.reset_walk()
	if OS.get_cmdline_user_args().has("--capture"):
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/camp-rebuild.png")
		camp.buildings.hide()
		camp.overlay.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/camp-rebuild-routes.png")
	sample.load_fixture(12)
	assert(not camp.visible and sample.corner_sample.visible)
	sample.load_fixture(14)
	assert(camp.visible and camp.current == 0)
	sample.queue_free()
	await process_frame
	print("PASS rebuild: seven reachable doors, portal return, safe redirect, invalid target, scene switching; no pixel-derived navigation")
	quit()
