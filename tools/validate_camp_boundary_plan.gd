extends SceneTree
const Planner = preload("res://scripts/prototypes/camp_boundary_plan.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var results := {}
	for name in ["rectangle","L","hole","diagonal","corridor"]:
		var cells := {}
		for y in range(3):
			for x in range(3):
				var include: bool = name=="rectangle" or (name=="L" and (x==0 or y==0)) or (name=="hole" and Vector2i(x,y)!=Vector2i.ONE) or (name=="diagonal" and x==y and x<2) or (name=="corridor" and y==0)
				if include: cells[Vector2i(x,y)] = 48
		var plan: Dictionary = Planner.build(cells,[],0)
		for edge in plan.edges: assert(not cells.has(edge.neighbor))
		results[name] = Planner.summary(plan)
	assert(results.rectangle.boundary_edges==12 and results.rectangle.convex==4 and results.rectangle.concave==0)
	assert(results.L.boundary_edges==12 and results.L.convex==5 and results.L.concave==1)
	assert(results.hole.boundary_edges==16 and results.hole.concave==4)
	assert(results.diagonal.boundary_edges==8 and results.diagonal.convex==8)
	assert(results.corridor.boundary_edges==8 and results.corridor.convex==4)
	var sample = load("res://scenes/prototypes/camp_terrain_sample.tscn").instantiate()
	root.add_child(sample)
	await process_frame
	sample.load_fixture(11)
	var full = sample.full_camp
	var heights := {}
	for y in full.full_size.y:
		for x in full.full_size.x: heights[Vector2i(x,y)] = int(full.base_height(Vector2i(x,y)))
	var links: Array = []
	for info in full.definition.stairs:
		links.append({"id":info.id,"from":Vector2i(info.from[0],info.from[1]),"to":Vector2i(info.cell[0],info.cell[1])})
	var plan: Dictionary = Planner.build(heights,links)
	results.full_camp = Planner.summary(plan)
	assert(results.full_camp.stair_openings==4)
	for edge in plan.edges:
		assert(edge.high>edge.low)
		if edge.stair!="": assert(edge.drop==48 and edge.visible_face)
	# Multi-height geometry keeps exact drops, including the 22px display base.
	assert(results.full_camp.drops.has("22") and results.full_camp.drops.has("48"))
	var export_plan := {"checks":results,"full_camp":{"edges":[],"corners":[]},"note":"Topology only; no generated collision or approved artwork implied."}
	for edge in plan.edges:
		var item: Dictionary = edge.duplicate()
		for key in ["cell","neighbor","direction"]: item[key] = [edge[key].x,edge[key].y]
		export_plan.full_camp.edges.append(item)
	for corner in plan.corners:
		var item: Dictionary = corner.duplicate()
		item.vertex = [corner.vertex.x,corner.vertex.y]
		export_plan.full_camp.corners.append(item)
	var out := FileAccess.open("/tmp/kunwu-camp-boundary-plan.json",FileAccess.WRITE)
	out.store_string(JSON.stringify(export_plan,"  "))
	print("PASS boundary topology: ",JSON.stringify(results))
	sample.queue_free()
	await process_frame
	quit()
