extends SceneTree
func _initialize() -> void:
	call_deferred("validate")

func validate() -> void:
	var lab = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(lab)
	await process_frame
	lab.load_fixture(13)
	await process_frame
	var sample = lab.connected_sample
	assert(sample.modules.size()==2 and sample.road.get_used_cells().size()==9)
	assert(sample.graph.get_point_count()==39)
	assert(sample.graph.get_point_position(14)==sample.graph.get_point_position(1000))
	assert(sample.graph.get_point_position(114)==sample.graph.get_point_position(1008))
	var path: PackedInt64Array = sample.graph.get_id_path(0,100)
	for i in range(5,14):
		assert(i in path and (100+i) in path)
	for i in range(9): assert((1000+i) in path)
	sample.graph.disconnect_points(14,1000)
	assert(sample.graph.get_id_path(0,100).is_empty())
	sample.graph.connect_points(14,1000)
	sample.move_to(100)
	sample._process(0.4)
	var before: Vector2 = sample.actor.position
	var next_id: int = sample.route_ids[0]
	sample.move_to(1004)
	assert(sample.actor.position == before and sample.route_ids[0] == next_id)
	for i in range(500): sample._process(0.05)
	assert(sample.route_ids.is_empty() and sample.current_id==1004)
	sample.click_at(sample.to_global(sample.graph.get_point_position(100)))
	for i in range(500): sample._process(0.05)
	assert(sample.current_id==100 and sample.actor.position == sample.graph.get_point_position(100))
	sample.move_to(0)
	for i in range(500): sample._process(0.05)
	assert(sample.current_id==0 and sample.route_ids.is_empty())
	sample.click_at(sample.to_global(Vector2(256,-100)))
	assert(sample.route_ids.is_empty())
	lab.load_fixture(12)
	assert(not sample.visible and not sample.is_processing())
	lab.load_fixture(13)
	assert(sample.visible and sample.current_id==0)
	if OS.get_cmdline_user_args().has("--capture-connected"):
		sample.move_to(100)
		sample._process(5)
		sample.set_process(false)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/kunwu-connected-terraces.png")
	lab.queue_free()
	await process_frame
	print("PASS: 2 terraces, 9 road cells, 39 graph nodes; stair-only cross-module routes; safe redirects; clicks, reset and visibility")
	quit()
