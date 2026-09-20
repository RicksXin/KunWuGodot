extends Node2D
## Integration fixture: approved local terraces share an explicit lower-road graph.
signal feedback(text: String)
const TERRACE = preload("res://scenes/prototypes/components/camp_continuous_terrace.tscn")
var road_cells: Array[Vector2i] = []
var definition: Dictionary
var modules: Array[Node2D] = []
var graph := AStar2D.new()
var road: TileMapLayer
var actor: Polygon2D
var target_marker: Line2D
var route_line: Line2D
var route_ids := PackedInt64Array()
var current_id := 0
var destination_id := 0

func _ready() -> void:
	definition = JSON.parse_string(FileAccess.get_file_as_string("res://data/prototypes/camp_connected_terraces.json"))
	for pair in definition.road_cells: road_cells.append(Vector2i(pair[0],pair[1]))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	road = preload("res://scripts/prototypes/camp_dual_terrain.gd").new()
	add_child(road)
	road.position = Vector2(definition.road_origin[0],definition.road_origin[1]) - road.map_to_local(Vector2i.ZERO)
	for i in road_cells.size():
		var cell: Vector2i = road_cells[i]
		road.set_cell(cell,0,road.ATLAS[0])
		graph.add_point(1000+i,road.position+road.map_to_local(cell))
		if i>0: graph.connect_points(999+i,1000+i)
	for index in definition.modules.size():
		var placement: Dictionary = definition.modules[index]
		var module: Node2D = TERRACE.instantiate()
		module.position = Vector2(placement.position[0],placement.position[1])
		add_child(module)
		module.set_extended(true)
		module.actor.hide()
		module.lower_ground.hide()
		modules.append(module)
		var base: int = index*100
		for id in module.navigation.get_point_ids():
			graph.add_point(base+id,module.position+module.navigation.get_point_position(id))
		for id in module.navigation.get_point_ids():
			for other in module.navigation.get_point_connections(id):
				if other>id: graph.connect_points(base+id,base+other)
		var road_id := 1000+int(placement.road_index)
		assert(graph.has_point(road_id))
		assert(graph.get_point_position(base+14).is_equal_approx(graph.get_point_position(road_id)),"Terrace lower port must meet authored road center")
		graph.connect_points(base+14,road_id)
		var label := Label.new()
		label.text = placement.name
		label.position = module.position+Vector2(-40,-66)
		label.add_theme_font_override("font",preload("res://assets/fonts/NotoSansSC.ttf"))
		label.add_theme_font_size_override("font_size",16)
		add_child(label)
	route_line = Line2D.new()
	route_line.width = 2
	route_line.default_color = Color(0.88,0.73,0.37,0.7)
	route_line.z_index = 4
	add_child(route_line)
	target_marker = Line2D.new()
	target_marker.points = PackedVector2Array([Vector2(0,-5),Vector2(10,0),Vector2(0,5),Vector2(-10,0),Vector2(0,-5)])
	target_marker.width = 2
	target_marker.default_color = Color("e4c26a")
	target_marker.z_index = 5
	add_child(target_marker)
	actor = Polygon2D.new()
	actor.polygon = PackedVector2Array([Vector2(-5,0),Vector2(0,-9),Vector2(5,0),Vector2(0,3)])
	actor.color = Color("f0c76c")
	actor.z_index = 6
	add_child(actor)
	reset_walk()

func reset_walk() -> void:
	route_ids.clear()
	current_id = 0
	destination_id = 0
	actor.position = graph.get_point_position(0)
	target_marker.hide()
	route_line.clear_points()

func move_to(id: int) -> void:
	if not graph.has_point(id): return
	# A mid-edge redirect finishes that edge before following the new graph path.
	var start: int = route_ids[0] if not route_ids.is_empty() else current_id
	var next := graph.get_id_path(start,id)
	if next.is_empty():
		feedback.emit("此处当前没有连通道路")
		return
	route_ids = next
	destination_id = id
	target_marker.position = graph.get_point_position(id)
	target_marker.show()
	_update_route()
	feedback.emit("沿台阶与下层道路前往目标；途中可以改选目的地")

func _process(delta: float) -> void:
	var distance := delta*95.0
	while not route_ids.is_empty() and distance>0:
		var next := graph.get_point_position(route_ids[0])
		var remaining := actor.position.distance_to(next)
		if remaining>distance:
			actor.position = actor.position.move_toward(next,distance)
			break
		actor.position = next
		distance -= remaining
		current_id = route_ids[0]
		route_ids.remove_at(0)
		if route_ids.is_empty(): feedback.emit("已到达 · 可点击另一块台地或下层道路继续行走")
	_update_route()

func _update_route() -> void:
	if not is_instance_valid(route_line): return
	route_line.clear_points()
	if route_ids.is_empty(): return
	route_line.add_point(actor.position)
	for id in route_ids: route_line.add_point(graph.get_point_position(id))

func click_at(point: Vector2) -> void:
	var p := to_local(point)
	# Top-surface cells take precedence over roads hidden behind the cliff.
	for index in modules.size():
		for id in range(5):
			var delta := p-graph.get_point_position(index*100+id)
			if absf(delta.x)/64.0+absf(delta.y)/32.0<=1.0:
				move_to(index*100+id)
				return
	for i in road_cells.size():
		var delta := p-graph.get_point_position(1000+i)
		if absf(delta.x)/64.0+absf(delta.y)/32.0<=1.0:
			move_to(1000+i)
			return
	feedback.emit("岩壁和空地不可行走，请点击台地或道路")
