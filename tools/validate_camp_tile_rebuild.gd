extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	sample._process(0)
	assert(sample.current_pattern == 15)
	var camp = sample.rebuild
	assert(camp.layers.size() == 3)
	# Removed southwest staircase must be a real cliff boundary, not an invisible route.
	assert(camp.stair_cells.size() == 4)
	assert(not camp.stair_cells.has(Vector2i(4,11)))
	assert(camp.heights[Vector2i(4,11)] == 0)
	assert(not camp.can_step(Vector2i(4,10),Vector2i(4,11)))
	assert(not camp.graph.are_points_connected(camp.ids[Vector2i(4,10)],camp.ids[Vector2i(4,11)]))
	var authored_footprints := {}
	for item in camp.data.buildings:
		var extent: Array = item.get("footprint_size",[2,2])
		for y in range(extent[1]):
			for x in range(extent[0]):
				var cell := Vector2i(item.origin[0]+x,item.origin[1]+y)
				assert(camp.heights.has(cell) and not authored_footprints.has(cell))
				assert(camp.blocked.has(cell) and not camp.ids.has(cell))
				authored_footprints[cell] = item.id
		assert(not camp.blocked.has(Vector2i(item.door[0],item.door[1])))

	for coordinate in camp.data.west_courtyard.reserved_cells:
		var cell := Vector2i(coordinate[0],coordinate[1])
		assert(camp.ids.has(cell) and not camp.blocked.has(cell))
	for item in camp.data.buildings:
		if not item.has("approach"): continue
		var arrival := Vector2i(item.approach[0],item.approach[1])
		var door := Vector2i(item.door[0],item.door[1])
		assert(camp.ids.has(arrival) and camp.can_step(arrival,door))
		if item.has("facing"):
			assert(arrival-door == Vector2i(item.facing[0],item.facing[1]))

	var descending: Node = camp.get_node("RearDescendingSlopes")
	assert(descending.get_child_count() == camp.data.get("rear_slopes", []).size())
	for face in descending.get_children():
		assert(face.get_meta("toe_height") < camp.heights[face.get_meta("crest_cell")])
	assert(not camp.get_node("RearDecor_back").has_node("west_pines"))

	var rear_back: Node = camp.get_node("RearDecor_back")
	var rear_front: Node = camp.get_node("RearDecor_front")
	var solid_feet := 0
	for placement in camp.data.rear_decor:
		if placement.get("solid_foot",false): solid_feet += 1
	assert(rear_back.get_child_count()+rear_front.get_child_count() == camp.data.rear_decor.size()+solid_feet)
	assert(rear_back.get_index() < camp.layers[0].get_parent().get_index())
	assert(rear_front.get_index() > camp.layers[2].get_parent().get_index())
	assert(rear_front.get_index() < camp.depth_sorted.get_index())

	var council: Sprite2D = camp.buildings.get_node("council")
	assert(council.is_visible_in_tree())
	for target in camp.targets:
		assert(target.visual.visible) # All seven buildings are ready for manual placement.
	assert((council.transform*(Vector2(110,181)+council.offset)).is_equal_approx(camp.point(Vector2i(5,2))))
	for item in camp.data.buildings:
		if not item.get("preview_visible",false): continue
		var visual: Sprite2D = camp.buildings.get_node(item.id)
		assert((visual.scale.x < 0) == item.get("mirror_x",false))
		var anchor := Vector2(item.door_anchor[0],item.door_anchor[1])
		var offset: Array = item.get("visual_offset",[0,0])
		assert((visual.transform*(anchor+visual.offset)).is_equal_approx(camp.point(Vector2i(item.door[0],item.door[1]))+Vector2(offset[0],offset[1])))

	camp.buildings.hide()
	assert(camp.actor.is_visible_in_tree())
	camp.buildings.show()
	assert(camp.depth_sorted.y_sort_enabled and camp.buildings.y_sort_enabled)

	var stream: Node = camp.get_node("ExteriorStream")
	assert(stream.waterfall_count == 3)
	assert(stream.get_child_count() == 5)
	assert(stream.get_node("SourceRidge").get_child_count() == 2)
	for layer_name in ["Riverbed","WaterSurface"]:
		var pieces = stream.get_node(layer_name).get_children()
		for i in range(pieces.size()-1):
			assert(pieces[i].polygon[8].is_equal_approx(pieces[i+1].polygon[0]))
			assert(pieces[i].polygon[9].is_equal_approx(pieces[i+1].polygon[17]))
	for knot in camp.data.stream.knots:
		assert(knot[3] > 0)
		assert(not camp.ids.has(Vector2i(roundi(knot[0]),roundi(knot[1]))))

	var rail_groups = camp.find_children("Railings","Node2D",true,false)
	assert(rail_groups.size() == 3)
	var railing_segments := 0
	for group in rail_groups:
		for segment in group.get_children():
			if not segment.has_meta("cell"): continue
			var cell: Vector2i = segment.get_meta("cell")
			var neighbor: Vector2i = segment.get_meta("neighbor")
			assert(not camp.stair_cells.has(cell) and not camp.stair_cells.has(neighbor))
			assert(camp.heights[cell] > camp.heights.get(neighbor,-48))
			railing_segments += 1
	assert(railing_segments > 0)

	var landings: Node = camp.get_node("StairLandings")
	for stair in camp.data.stairs:
		var lower_layer = landings.get_node("LandingHeight%d" % (stair.high-48))
		var cell := Vector2i(stair.cell[0],stair.cell[1])
		assert(lower_layer.get_cell_source_id(cell) == 0)
		assert((lower_layer.position+lower_layer.map_to_local(cell)).is_equal_approx(camp.flat(cell)-Vector2(0,stair.high-48)))
	for cell in [Vector2i(8,0),Vector2i(8,1),Vector2i(8,3)]:
		assert(camp.heights[cell] == 48)

	assert(camp.edge_overlays.get_child_count() == camp.data.edge_overlays.size())
	assert(camp.edge_overlays.get_index() < camp.depth_sorted.get_index())
	for child in camp.get_children():
		if child is Sprite2D:
			assert(child.get_index() > camp.edge_overlays.get_index()) # Stairways stay above decorative rock.
	var drawn := 0
	for layer in camp.layers:
		assert(layer is TileMapLayer)
		var cell: Vector2i = layer.get_used_cells()[0]
		assert((layer.position+layer.map_to_local(cell)).is_equal_approx(camp.point(cell)))
		drawn += layer.get_used_cells().size()
	assert(camp.foundation.get_used_cells().size() >= drawn)
	for cell in camp.ids: assert(camp.heights.has(cell))
	assert(drawn == camp.heights.size()-camp.stair_cells.size())
	var expanded = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	expanded.definition_override = camp.data.duplicate(true)
	expanded.definition_override.cells.append([15,12,0])
	root.add_child(expanded)
	expanded.hide()
	assert(expanded.tiles_count == camp.tiles_count+1)
	assert(expanded.ids.has(Vector2i(15,12)))
	assert(not expanded.graph.get_id_path(expanded.current,expanded.ids[Vector2i(15,12)]).is_empty())
	var ground_material: ShaderMaterial = expanded.layers[0].material
	var origin: Vector2 = ground_material.get_shader_parameter("grid_origin")
	var mask: Image = ground_material.get_shader_parameter("occupancy").get_image()
	assert(mask.get_pixel(15-int(origin.x),12-int(origin.y)).r > 0.9)
	assert(sample.mountain_mist.visible)
	assert(sample.mountain_mist.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	expanded.queue_free()
	for stair in camp.data.stairs:
		var upper := Vector2i(stair.from[0],stair.from[1])
		var lower := Vector2i(stair.to[0],stair.to[1])
		assert(camp.heights[upper] == stair.high)
		assert(camp.heights[lower] == stair.high-48)
	for node in camp.ids.values():
		assert(not camp.graph.get_id_path(camp.current,node).is_empty())
	assert(camp.visible and camp.targets.size() == 7)
	assert(not sample.terrain.visible and sample.exterior.visible)
	for target in camp.targets:
		assert(camp.move_to_node(target.node))
		for frame in range(2000): camp._process(0.02)
		assert(camp.route.is_empty() and camp.current == target.node)
	assert(camp.move_to_node(camp.ids[Vector2i(10,12)]))
	for frame in range(2000): camp._process(0.02)
	assert(camp.current == camp.ids[Vector2i(10,12)])
	assert(not camp.move_to_node(999))
	camp.move_to_node(camp.targets[0].node)
	camp._process(0.1)
	var before: Vector2 = camp.actor.position
	var next: int = camp.route[0]
	assert(camp.move_to_node(camp.targets[4].node))
	assert(camp.actor.position == before and camp.route[0] == next)
	camp.reset_walk()
	if OS.get_cmdline_user_args().has("--capture"):
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/camp-tile-rebuild.png")
		if OS.get_cmdline_user_args().has("--capture-west-buildings"):
			var old_position: Vector2 = sample.world.position
			var old_scale: Vector2 = sample.world.scale
			sample.world.position = Vector2(1030,100)
			sample.world.scale = Vector2.ONE*1.15
			if OS.get_cmdline_user_args().has("--placement-audit"): camp.overlay.show()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/camp-west-buildings-detail.png")
			sample.world.position = old_position
			sample.world.scale = old_scale

		if OS.get_cmdline_user_args().has("--capture-rear-detail"):
			var saved_position: Vector2 = sample.world.position
			var saved_scale: Vector2 = sample.world.scale
			sample.world.position = Vector2(900,0)
			sample.world.scale = Vector2.ONE*2.0
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/camp-rear-detail.png")
			sample.world.position = saved_position
			sample.world.scale = saved_scale

		camp.buildings.hide()
		camp.overlay.show()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/camp-tile-rebuild-routes.png")
	sample.load_fixture(12)
	assert(not camp.visible and sample.corner_sample.visible)
	assert(not sample.mountain_mist.visible)
	sample.load_fixture(15)
	assert(camp.visible and camp.current == camp.ids[Vector2i(10,12)])
	sample.queue_free()
	await process_frame
	print("PASS rebuild: seven reachable doors, portal return, safe redirect, invalid target, scene switching; no pixel-derived navigation")
	quit()
