extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	assert(sample.current_pattern in [11,14,15] or OS.get_cmdline_user_args().has("--corner-preview"))
	if sample.current_pattern == 12:
		assert(sample.corner_sample.extended and sample.corner_sample.stairs.visible)
	sample.load_fixture(11)
	assert(sample.full_camp.visible and sample.full_camp.surface_style == 4)
	var exterior = sample.exterior
	assert(exterior.layers.size() == 4 and exterior.clip_contents)
	for layer in exterior.layers:
		assert(layer.texture != null and layer.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	exterior.sync_camera(exterior.reference_camera+Vector2(100,40),true)
	assert(exterior.layers[0].position == Vector2.ZERO)
	assert(exterior.layers[1].position.is_equal_approx(Vector2(178,-57.8)))
	exterior.enabled = false
	exterior.sync_camera(exterior.reference_camera,true)
	assert(not exterior.visible)
	exterior.enabled = true
	exterior.sync_camera(exterior.reference_camera,false)
	assert(not exterior.visible)
	exterior.sync_camera(exterior.reference_camera,true)
	assert(exterior.visible)
	sample.load_fixture(11)
	var full = sample.full_camp
	assert(full.visible and not sample.terrace.visible and not sample.terrain.visible)
	assert(full.buildings.size() == 7 and full.stairs_by_cell.size() == 4)
	var ground_count := 0
	for layer in full.get_children():
		if layer is TileMapLayer:
			assert(layer.get_used_cells().is_empty()) # No old stone/dirt atlas underlay.
			for surface in layer.get_children():
				assert(surface is Polygon2D and surface.texture.get_size() == Vector2(48,24))
				assert(surface.uv == surface.polygon) # Shared world phase across cell edges.
				ground_count += 1
	assert(ground_count == 144)
	var origin := Vector2i(7,10)
	var count := 0
	for y in range(12):
		for x in range(12):
			var cell := Vector2i(x,y)
			if full.walkable(cell):
				count += 1
				assert(cell == origin or not full.find_route(origin,cell).is_empty())
			else: assert(full.find_route(origin,cell).is_empty())
	assert(count == 116)
	# No cliff crossing outside the four explicit stair connections.
	for y in range(12):
		for x in range(12):
			var a := Vector2i(x,y)
			for delta in [Vector2i.RIGHT,Vector2i.DOWN]:
				var b: Vector2i = a+delta
				if not full.stairs_by_cell.has(a) and not full.stairs_by_cell.has(b) and full.base_height(a) != full.base_height(b): assert(not full.can_step(a,b))
	for info in full.definition.stairs:
		var stair := Vector2i(info.cell[0],info.cell[1])
		var high := Vector2i(info.from[0],info.from[1])
		var low := Vector2i(info.to[0],info.to[1])
		assert(full.can_step(high,stair) and full.can_step(stair,low))
		assert(full.height_at(Vector2(stair)) == info.high-24)
		for delta in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if stair+delta != high and stair+delta != low: assert(not full.can_step(stair,stair+delta))
		# Each staircase can be closed individually without disconnecting building doors.
		full.blocked[stair] = true
		for item in full.buildings.values():
			var door := Vector2i(item.info.door[0],item.info.door[1])
			assert(not full.find_route(origin,door).is_empty())
		full.blocked.erase(stair)
	for style in [1,2,3,0,3,2,1,0]:
		full.set_surface_style(style)
		assert(full.stairs_node.get_index() < full.entities.get_index())
		assert(full.stairs_node.get_child_count() > 8)
		if style == 3:
			var clipped := false
			for piece in full.cliff.get_children():
				assert(piece is Polygon2D and piece.texture != null)
				var height: float = piece.get_meta("cliff_height")
				assert(height > 0 and height <= 48)
				# Clipped bases retain texture scale, unlike resizing the whole wall image.
				assert(is_equal_approx(piece.polygon[2].y-piece.polygon[1].y,piece.uv[2].y-piece.uv[1].y))
				if height == 22: clipped = true
			assert(clipped)
	full.set_surface_style(4)
	var longest := 0.0
	for face in full.cliff.get_children():
		assert(face is Polygon2D and face.texture != null)
		assert(face.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED)
		assert(face.uv[1].x-face.uv[0].x == face.polygon[1].x-face.polygon[0].x)
		assert(face.uv[2].y == face.get_meta("height"))
		longest = maxf(longest,float(face.get_meta("run_length")))
	assert(longest >= 256) # Actual merged long faces, not a per-cell texture restart.
	assert(full.rim_node.get_child_count() > 0)
	assert(full.rim_node.get_index() > full.upper.get_index())
	assert(full.rim_node.get_index() < full.stairs_node.get_index())
	for rim in full.rim_node.get_children():
		if rim.has_meta("rear_profile"):
			assert(rim.texture.get_size() == Vector2(80,32))
			continue
		if rim.has_meta("native_corner"):
			assert(rim.texture.get_size() == Vector2(64,88))
			assert(rim is Polygon2D and rim.polygon.size() == 5)
			assert(rim.polygon[3].y-rim.polygon[2].y == 16)
			continue
		if rim.has_meta("full_profile"):
			assert(rim.texture.get_size() == Vector2(80,88))
			assert(rim.polygon.size() == 6)
			assert(is_equal_approx(rim.uv[0].y,24) and is_equal_approx(rim.uv[3].y,24))
			assert(rim.polygon[1].x>rim.polygon[0].x and rim.polygon[2].x<rim.polygon[3].x)
			continue
		assert(rim.texture.get_size() == Vector2(80,8))
		assert(rim.uv[1].x-rim.uv[0].x == rim.get_meta("boundary_length"))
	var bounds: Rect2 = full.overview_bounds()
	var screen_bounds := Rect2(sample.world.position+bounds.position*sample.world.scale,bounds.size*sample.world.scale)
	assert(Rect2(27,147,1226,448).encloses(screen_bounds))
	full.set_stair_art(true)
	var art_count := 0
	for info in full.definition.stairs:
		var art = full.stairs_node.get_node_or_null(str(info.id)+"_art")
		assert(art is Sprite2D and art.texture.get_size()==Vector2(144,144))
		var center := Vector2(info.cell[0],info.cell[1])
		var a: Vector2 = full.flat(center-Vector2(0.5,0.5))-Vector2(0,info.high)
		assert(art.position+Vector2(72,8)==a)
		art_count += 1
	assert(art_count == 4)
	full.set_stair_art(false)
	for child in full.stairs_node.get_children(): assert(not child is Sprite2D)
	full.set_stair_art(true)
	# Redirect within a grid edge: retain position and the active edge, including stairs.
	full.reset_walk()
	assert(full.move_to(Vector2i(3,2)))
	full._process(0.1)
	var redirect_position: Vector2 = full.grid_position
	var active_edge: Vector2i = full.route[0]
	assert(full.move_to(origin))
	assert(full.grid_position == redirect_position and full.route[0] == active_edge)
	var previous_route: Array = full.route.duplicate()
	assert(not full.move_to(Vector2i(-1,-1)))
	assert(full.route == previous_route)
	for i in range(500): full._process(0.02)
	assert(full.current_cell == origin and full.route.is_empty())
	assert(full.destination_marker.position == full.project(Vector2(origin)))
	full.reset_walk()
	assert(not full.destination_marker.visible)
	# Visit every door through real motion, ensuring continuous stair projection.
	for id in ["council","treasury","revival","recruit","market","forge","garden","portal"]:
		assert(full.move_to_building(id))
		assert(full.building_selection.get_index() < full.entities.get_index())
		assert(full.building_selection.get_point_count() == (0 if id == "portal" else 5))
		if id != "portal":
			var points: PackedVector2Array = full.building_selection.points
			assert((points[0]+points[2]).is_equal_approx(points[1]+points[3]))
		var frames := 0
		while not full.route.is_empty() and frames < 4000:
			var previous: Vector2 = full.actor.position
			full._process(0.016)
			assert(previous.distance_to(full.actor.position) < 5)
			frames += 1
		assert(full.route.is_empty())
	assert(full.current_cell == origin)
	full.effects_enabled = false
	full._process(0.1)
	assert(full.portal.modulate.a == 1.0 and full.lamp.modulate.a == 1.0)
	full.set_buildings_visible(false)
	assert(not full.hall.visible and full.blocked.size() == 28)
	full.set_buildings_visible(true)
	full.reset_walk()
	assert(full.building_selection.get_point_count() == 0)
	if OS.get_cmdline_user_args().has("--capture-fullcamp"):
		var capture_style := 4 if OS.get_cmdline_user_args().has("--continuous-cliff-preview") else (3 if OS.get_cmdline_user_args().has("--cliff-candidate-preview") else 2)
		full.set_surface_style(capture_style)
		sample.full_style_selector.select(capture_style)
		assert(full.move_to_building("council"))
		full._process(0.5)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-fullcamp.png")
		sample.world.scale = Vector2.ONE
		sample.world.position = Vector2(640,-170)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-fullcamp-detail.png")
	sample.load_fixture(10)
	assert(not full.visible and sample.terrace.visible and sample.world.scale == Vector2.ONE)
	sample.load_fixture(0)
	assert(not full.visible and sample.terrain.visible)
	sample.queue_free()
	await process_frame
	print("PASS full camp: 116 reachable cells, 7 doors + portal, 4 continuous stairs, alternate routes, cliff blockers, styles, effects, scene switching")
	quit()
