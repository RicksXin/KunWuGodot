extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var lab = load("res://scenes/prototypes/camp_tilemap_lab.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	assert(root.content_scale_size == Vector2i(817, 375))
	var point: Vector2 = lab.ground.to_global(lab.ground.map_to_local(Vector2i(14, 6)))
	var cell: Vector2i = lab.ground.local_to_map(lab.ground.to_local(point))
	var original_paths: int = lab.paths.get_used_cells().size()
	var original_water: int = lab.water.get_used_cells().size()
	lab.mode = "water"
	lab.paint_at(point)
	assert(lab.water.get_cell_source_id(cell) == 0)
	assert(lab.paths.get_cell_source_id(cell) == -1)
	lab.mode = "stone"
	lab.paint_at(point)
	assert(lab.paths.get_cell_atlas_coords(cell) == Vector2i(1, 0))
	assert(lab.water.get_cell_source_id(cell) == -1)
	lab.mode = "grass"
	lab.paint_at(point)
	assert(lab.paths.get_cell_source_id(cell) == -1)
	assert(lab.water.get_cell_source_id(cell) == -1)
	assert(lab.ground.get_cell_source_id(cell) == 0)
	# Exercise event-driven panning and building placement, including release.
	lab.mode = "building"
	var portal: Sprite2D = lab.buildings.get_node("Portal")
	var before := portal.position
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = portal.global_position
	lab._unhandled_input(press)
	assert(lab.selected == portal)
	var motion := InputEventMouseMotion.new()
	motion.position = press.position + Vector2(30, 0)
	motion.relative = Vector2(30, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	lab._unhandled_input(motion)
	assert(portal.position.is_equal_approx(before + Vector2(30, 0) / lab.world.scale))
	press.pressed = false
	lab._unhandled_input(press)
	assert(not lab.dragging)
	lab.mode = "pan"
	press.pressed = true
	lab._unhandled_input(press)
	lab._unhandled_input(motion)
	assert(is_equal_approx(lab.world.position.x, -lab.INITIAL_SCROLL + 30))
	lab.reset_layout()
	assert(lab.paths.get_used_cells().size() == original_paths)
	assert(lab.water.get_used_cells().size() == original_water)
	assert(portal.position == before)
	assert(is_equal_approx(lab.world.position.x, -lab.INITIAL_SCROLL))
	assert(root.get_node("Game").suppress_profile_writes)
	print("PASS: terrain replacement/erase, building drag, pan, reset, profile guard")
	if OS.get_cmdline_user_args().has("--capture-lab"):
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-tilemap-lab.png")
		print("Screenshot: /tmp/kunwu-camp-tilemap-lab.png")
	quit()
