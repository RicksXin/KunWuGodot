@tool
extends Node2D
## Shared camp/editor ambience. Navigation is authored cells, never image pixels.
const Collision = preload("res://scripts/prototypes/camp_collision.gd")
const CONFIG = "res://data/prototypes/camp_npcs.json"
var graph := AStar2D.new()
var ids: Dictionary = {}
var people: Array[Dictionary] = []
var explicit_depth := false
var signature := ""
var rng := RandomNumberGenerator.new()

func configure(definition: Dictionary) -> void:
	var obstacles: Array = []
	for b in definition.get("buildings",[]):
		obstacles.append([b.origin,b.get("footprint_size",[2,2])])
	var next_signature := JSON.stringify([definition.cells,definition.stairs,definition.buildings])
	if signature == next_signature: return
	signature = next_signature
	for child in get_children():
		remove_child(child)
		child.queue_free()
	people.clear()
	graph.clear()
	ids.clear()
	y_sort_enabled = true
	rng.seed = 24092026
	var heights := {}
	var blocked := {}
	var stairs := {}
	for c in definition.cells: heights[Vector2i(c[0],c[1])] = c[2]
	for st in definition.stairs: stairs[Vector2i(st.cell[0],st.cell[1])] = st
	var footprints := Collision.polygons(definition)
	for c: Vector2i in heights:
		var point := Vector2((c.x-c.y)*64,(c.x+c.y)*32-heights[c])
		if Collision.contains(point,footprints): blocked[c] = true
	for c: Vector2i in heights:
		if blocked.has(c): continue
		var id := ids.size()
		ids[c] = id
		graph.add_point(id,Vector2((c.x-c.y)*64,(c.x+c.y)*32-heights[c]))
	for c: Vector2i in ids:
		for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
			var other: Vector2i = c+axis
			if not ids.has(other): continue
			var allowed: bool = heights[c] == heights[other]
			for check in [c,other]:
				if stairs.has(check):
					var st: Dictionary = stairs[check]
					var neighbor: Vector2i = other if check == c else c
					allowed = neighbor == Vector2i(st.from[0],st.from[1]) or neighbor == Vector2i(st.to[0],st.to[1])
					break
			if allowed and not Collision.crosses(graph.get_point_position(ids[c]),graph.get_point_position(ids[other]),footprints): graph.connect_points(ids[c],ids[other])
	if ids.is_empty(): return
	var config: Array = JSON.parse_string(FileAccess.get_file_as_string(CONFIG))
	for item in config:
		var cell := Vector2i(item.spawn[0],item.spawn[1])
		var current: int = ids.get(cell,-1)
		if current < 0:
			current = graph.get_closest_point(Vector2((cell.x-cell.y)*64,(cell.x+cell.y)*32-float(heights.get(cell,0))))
		var sprite := Sprite2D.new()
		sprite.name = item.id
		sprite.texture = load(item.texture)
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.hframes = 6
		sprite.vframes = 13
		sprite.frame = 60
		sprite.offset = Vector2(0,-19)
		sprite.scale = Vector2.ONE*1.5
		sprite.position = graph.get_point_position(current)
		add_child(sprite)
		people.append({"sprite":sprite,"current":current,"home":current,"route":PackedInt64Array(),"wait":0.5+people.size()*0.7,"phase":0.0,"row":7,"speed":float(item.speed)})
		if explicit_depth: sprite.z_index = roundi(sprite.position.y)

func _process(delta: float) -> void:
	for person in people:
		var sprite: Sprite2D = person.sprite
		if person.route.is_empty():
			person.wait -= delta
			sprite.frame = (int(person.row)+3)*6
			if person.wait <= 0: choose_route(person)
			continue
		var target: Vector2 = graph.get_point_position(person.route[0])
		var direction := target-sprite.position
		sprite.position = sprite.position.move_toward(target,person.speed*delta)
		sprite.flip_h = false
		if absf(direction.x) > absf(direction.y):
			person.row = 8
			sprite.flip_h = direction.x > 0
		else: person.row = 9 if direction.y < 0 else 7
		person.phase += delta*7.0
		sprite.frame = int(person.row)*6+int(person.phase)%6
		if explicit_depth: sprite.z_index = roundi(sprite.position.y)
		if sprite.position.is_equal_approx(target):
			person.current = person.route[0]
			person.route.remove_at(0)
			if person.route.is_empty(): person.wait = rng.randf_range(1.5,4.0)

func choose_route(person: Dictionary) -> void:
	var candidates := graph.get_point_ids()
	for attempt in range(40):
		var target: int = candidates[rng.randi_range(0,candidates.size()-1)]
		if target == person.current: continue
		if graph.get_point_position(target).distance_to(graph.get_point_position(person.home)) > 350: continue
		var taken := false
		for other in people:
			if other == person: continue
			if target == other.current or (not other.route.is_empty() and target == other.route[-1]): taken = true
		if taken: continue
		var path := graph.get_id_path(person.current,target)
		if path.size() < 2 or path.size() > 12: continue
		path.remove_at(0)
		person.route = path
		return
	person.wait = 2.0
