extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var panel = load("res://addons/camp_layout_editor/panel.gd").new()
	root.add_child(panel)
	await process_frame
	var camp = load("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	root.add_child(camp)
	var npcs = panel.canvas.npcs
	assert(npcs.people.size() == 3 and camp.npcs.people.size() == 3)
	assert(npcs.ids == camp.ids and camp.npcs.ids == camp.ids)
	for id in camp.graph.get_point_ids():
		assert(npcs.graph.get_point_connections(id) == camp.graph.get_point_connections(id))
	var original: Dictionary = panel.model.data.duplicate(true)
	var nodes: Array = npcs.people.map(func(p): return p.sprite)
	panel.canvas.refresh()
	assert(npcs.people.map(func(p): return p.sprite) == nodes)
	npcs.set_process(false)
	var moves := [0,0,0]
	var frames := [{},{},{}]
	for step in range(3600):
		var positions: Array = npcs.people.map(func(p): return p.sprite.position)
		npcs._process(1.0/30.0)
		for i in range(3):
			var p: Dictionary = npcs.people[i]
			if positions[i] != p.sprite.position: moves[i] += 1
			frames[i][p.sprite.frame] = true
			assert(p.sprite.z_index == roundi(p.sprite.position.y))
			if not p.route.is_empty():
				var a: Vector2 = npcs.graph.get_point_position(p.current)
				var b: Vector2 = npcs.graph.get_point_position(p.route[0])
				assert(npcs.graph.are_points_connected(p.current,p.route[0]))
				assert(p.sprite.position.distance_to(Geometry2D.get_closest_point_to_segment(p.sprite.position,a,b)) < 0.01)
	for i in range(3): assert(moves[i] > 100 and frames[i].size() >= 7)
	assert(panel.model.data == original)
	print("PASS 3 NPCs: 120s simulation, legal paths, 3 walking/idle animations, foot-depth, refresh continuity, runtime/editor navigation parity, no layout writes; moves=",moves)
	quit()
