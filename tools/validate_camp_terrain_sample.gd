extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var old_size := root.content_scale_size
	var old_guard: bool = root.get_node("Game").suppress_profile_writes
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	assert(root.content_scale_size == Vector2i(1280,720))
	assert(root.get_node("Game").suppress_profile_writes)
	var layer = sample.terrain
	# Verify native projection agrees with source diamond axes and picking.
	var origin: Vector2 = layer.map_to_local(Vector2i.ZERO)
	print("Projection: ", layer.map_to_local(Vector2i(1,0))-origin, " / ", layer.map_to_local(Vector2i(0,1))-origin)
	assert(layer.map_to_local(Vector2i(1,0))-origin == Vector2(64,32))
	assert(layer.map_to_local(Vector2i(0,1))-origin == Vector2(-64,32))
	var seen := {}
	for fixture in range(10):
		sample.load_fixture(fixture)
		for cell in layer.get_used_cells():
			seen[layer.mask_at(cell)] = true
			assert(layer.local_to_map(layer.map_to_local(cell)) == cell)
	# All corners in the source order, including the empty backing, are reachable.
	for mask in range(16):
		layer.stone.clear()
		var corners := [Vector2i(1,1),Vector2i(1,2),Vector2i(2,1),Vector2i(2,2)]
		for bit in range(4):
			if mask & (1 << bit): layer.stone[corners[bit]] = true
		layer.rebuild()
		assert(layer.mask_at(Vector2i(2,2)) == mask)
		assert(layer.get_cell_atlas_coords(Vector2i(2,2)) == layer.ATLAS[mask])
	# Edit then erase must restore all four adjacent atlas cells exactly.
	sample.load_fixture(6)
	var before := {}
	for cell in layer.get_used_cells(): before[cell] = layer.get_cell_atlas_coords(cell)
	assert(layer.paint(Vector2i(0,0), true))
	assert(layer.paint(Vector2i(0,0), false))
	for cell in before: assert(layer.get_cell_atlas_coords(cell) == before[cell])
	assert(not layer.paint(Vector2i(-1,0), true))
	# Route screen-space brush actions through the same input entry as the UI.
	sample.mode = 1
	var point: Vector2 = layer.to_global(layer.map_to_local(Vector2i(0,0)))
	sample.paint_at(point)
	assert(layer.stone.has(Vector2i(0,0)))
	sample.mode = 2
	sample.paint_at(point)
	assert(not layer.stone.has(Vector2i(0,0)))
	sample.show_structure = false
	sample.load_fixture(0)
	assert(not sample.structure.visible)
	sample.show_structure = true
	sample.load_fixture(0)
	if OS.get_cmdline_user_args().has("--capture-sample"):
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-terrain-sample.png")
	# The approved corner is a single visual module: no hidden terrain painting or walking.
	sample.load_fixture(12)
	await process_frame
	assert(sample.corner_sample.visible and not sample.terrain.visible and not sample.terrace.visible)
	assert(sample.corner_controls.visible and sample.mode == 0)
	assert(sample.corner_sample.ART.get_size() == Vector2(440,300))
	assert(sample.corner_sample.center(Vector2i(1,0)) == Vector2(64,32))
	assert(sample.corner_sample.center(Vector2i(0,1)) == Vector2(-64,32))
	for check in sample.corner_controls.get_children(): check.button_pressed = true
	assert(sample.corner_sample.show_grid and sample.corner_sample.show_height)
	var corner = sample.corner_sample
	assert(corner.extended and corner.stairs.visible)
	assert(corner.stair_art.texture.get_size() == Vector2(128,128))
	assert(corner.stair_art.position == Vector2(-108,42))
	assert(corner.stair_art.visible and not corner.procedural_stairs.visible)
	var before_path: PackedInt64Array = corner.navigation.get_id_path(0,14)
	sample.stair_style_toggle.button_pressed = true
	assert(corner.procedural_stairs.visible and not corner.stair_art.visible)
	assert(corner.navigation.get_id_path(0,14) == before_path)
	sample.stair_style_toggle.button_pressed = false
	var original: Image = corner.ORIGINAL_ART.get_image()
	var taller: Image = corner.extended_texture.get_image()
	assert(original.get_size() == taller.get_size())
	# Native upper pixels must remain identical. No scaling or re-anchoring.
	for x in original.get_width():
		var cut: int = corner.cut_row(x)
		for y in cut:
			assert(original.get_pixel(x,y) == taller.get_pixel(x,y))
		for y in range(cut,original.get_height()-14):
			assert(original.get_pixel(x,y) == taller.get_pixel(x,y+14))
	assert(corner.STAIR_DROP == 48 and corner.STAIR_RUN == Vector2(56,28))
	assert(corner.lower_ground.get_used_cells().size() == 1)
	assert(corner.lower_ground.position + corner.lower_ground.map_to_local(Vector2i.ZERO) == corner.navigation.get_point_position(14))
	var ids: PackedInt64Array = corner.navigation.get_id_path(0,14)
	for i in range(5,14): assert(i in ids)
	assert(not corner.navigation.are_points_connected(0,14))
	corner.click_at(corner.to_global(Vector2(0,110)))
	assert(corner.route.is_empty())
	corner.move_to(14)
	corner._process(0.1)
	var before_redirect: Vector2 = corner.actor.position
	var active_waypoint: Vector2 = corner.route[0]
	corner.move_to(0)
	assert(corner.actor.position == before_redirect and corner.route[0] == active_waypoint)
	corner.move_to(14)
	for i in range(500): corner._process(0.05)
	assert(corner.route.is_empty())
	assert(corner.actor.position.is_equal_approx(corner.navigation.get_point_position(14)))
	corner.move_to(0)
	for i in range(500): corner._process(0.05)
	assert(corner.route.is_empty() and corner.actor.position == Vector2.ZERO)
	corner.set_original(false)
	assert(corner.sprite.texture == corner.ART and corner.stairs.visible)
	assert(corner.route.is_empty() and corner.actor.position == Vector2.ZERO)
	corner.set_extended(false)
	assert(not corner.stairs.visible and corner.sprite.texture == corner.ART)
	corner.set_extended(true)
	assert(corner.sprite.texture == corner.ART) # Already tall: never apply another 14px.
	corner.click_at(corner.to_global(corner.navigation.get_point_position(14)+Vector2(48,0)))
	assert(corner.destination_id == 14 and not corner.route.is_empty())
	for i in range(500): corner._process(0.05)
	assert(corner.actor.position.is_equal_approx(corner.navigation.get_point_position(14)))
	corner.set_extended(true)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(640,300)
	click.pressed = true
	sample._unhandled_input(click)
	click.pressed = false
	sample._unhandled_input(click)
	assert(not sample.dragging)
	sample.load_fixture(10)
	assert(not sample.corner_sample.visible and sample.terrace.visible)
	assert(not sample.edit_buttons[1].disabled)
	sample.load_fixture(12)
	if OS.get_cmdline_user_args().has("--capture-corner"):
		for check in sample.corner_controls.get_children(): check.button_pressed = false
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-corner-sample.png")
		sample.corner_controls.get_child(2).button_pressed = true
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-camp-corner-stairs.png")
		corner.extended_texture.get_image().save_png("/tmp/kunwu-camp-corner-height48.png")
	sample.queue_free()
	await process_frame
	assert(root.content_scale_size == old_size)
	assert(root.get_node("Game").suppress_profile_writes == old_guard)
	print("PASS: 16 masks, 10 fixtures, isometric picking, incremental edit/erase, bounds, viewport and profile restoration. Fixture coverage: ", seen.size())
	quit()
