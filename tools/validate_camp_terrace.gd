extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	sample.load_fixture(10)
	assert(sample.current_pattern == 10)
	var slice = sample.terrace
	assert(slice.visible and not sample.terrain.visible)
	assert(slice.entities.y_sort_enabled)
	# Rebuilding preview art must preserve layering, topology, and a single staircase.
	var initial_style: int = slice.surface_style
	for style in [1,2,3,0,3,2,1,0]:
		slice.set_surface_style(style)
		assert(slice.stairs_node.get_index() < slice.entities.get_index())
	slice.set_surface_style(initial_style)
	assert(slice.stairs_node.get_index() < slice.entities.get_index())
	var stair_count := 0
	for child in slice.get_children():
		if child.name == "SolidStairs": stair_count += 1
	assert(stair_count == 1)
	# All authored free cells are reachable; no building cell is reachable.
	var count := 0
	for y in range(6):
		for x in range(6):
			var target := Vector2i(x,y)
			if slice.walkable(target):
				count += 1
				assert(target == slice.current_cell or not slice.find_route(slice.current_cell,target).is_empty())
			else: assert(slice.find_route(slice.current_cell,target).is_empty())
	assert(count == 32)
	for x in range(6):
		assert(slice.can_step(Vector2i(x,2),Vector2i(x,3)) == (x == 2))
	assert(not slice.can_step(Vector2i(2,3),Vector2i(3,3)))
	assert(not slice.can_step(Vector2i(2,3),Vector2i(1,3)))
	assert(slice.can_step(Vector2i(2,3),Vector2i(2,4)))
	assert(not slice.walkable(Vector2i(-1,0)))
	assert(not slice.walkable(Vector2i(6,0)))
	assert(slice.height_at(Vector2(2,2.5)) == 48)
	assert(slice.height_at(Vector2(2,3)) == 24)
	assert(slice.height_at(Vector2(2,3.5)) == 0)
	# A full ascent and descent uses the actual motion loop without teleporting.
	assert(slice.move_to(Vector2i(2,2)))
	assert(slice.move_to(Vector2i(3,5)))
	assert(slice.move_to(Vector2i(2,2)))
	var previous: Vector2 = slice.actor.position
	for frame in range(250):
		slice._process(0.016)
		assert(slice.actor.position.distance_to(previous) < 5)
		previous = slice.actor.position
	assert(slice.current_cell == Vector2i(2,2) and slice.route.is_empty())
	assert(slice.move_to(Vector2i(2,5)))
	for frame in range(250): slice._process(0.016)
	assert(slice.current_cell == Vector2i(2,5))
	assert(slice.actor.position.is_equal_approx(slice.project(Vector2(2,5))))
	# Building feedback and effect anchors are independent of the terrain images.
	slice.click_at(slice.hall.to_global(Vector2(0,-100)))
	assert(slice.selected and slice.highlight.visible)
	assert(slice.door_anchor is Marker2D and slice.smoke_anchor is Marker2D and slice.light_anchor is Marker2D)
	slice.effects_enabled = false
	slice._process(0.02)
	assert(slice.lamp.modulate.a == 1)
	slice.reset_walk()
	assert(not slice.selected and not slice.highlight.visible)
	if OS.get_cmdline_user_args().has("--capture-terrace"):
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-terrace.png")
		# Capture halfway along the actual stair interpolation and behind the hall.
		slice.grid_position = Vector2(2,3)
		slice.actor.position = slice.project(slice.grid_position)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-terrace-stairs.png")
		slice.grid_position = Vector2(0,0)
		slice.actor.position = slice.project(slice.grid_position)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-terrace-behind.png")
	sample.queue_free()
	await process_frame
	print("PASS: 32 reachable cells, building/cliff blockers, stair-only connection, continuous ascent/descent, click highlight, Y-sort, effect anchors, reset")
	quit()
