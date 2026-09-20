extends Node2D
signal feedback(text: String)
var graph := AStar2D.new()
var data: Dictionary
var route := PackedInt64Array()
var current := 0
var actor: Polygon2D
var route_line: Line2D
var buildings: Node2D
var targets: Array[Dictionary] = []
var overlay: Node2D
var portal: Sprite2D
var phase := 0.0

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/prototypes/camp_rebuild.json"))
	var base := Sprite2D.new()
	base.texture = preload("res://resources/prototypes/camp_rebuild/terrain.png")
	base.centered = false
	add_child(base)
	for i in data.points.size(): graph.add_point(i,Vector2(data.points[i][0],data.points[i][1]))
	for pair in data.edges: graph.connect_points(pair[0],pair[1])
	overlay = Node2D.new()
	add_child(overlay)
	for pair in data.edges:
		var line := Line2D.new()
		line.points = PackedVector2Array([graph.get_point_position(pair[0]),graph.get_point_position(pair[1])])
		line.width = 3
		line.default_color = Color(0.3,0.9,0.9,0.7)
		overlay.add_child(line)
	overlay.hide()
	buildings = Node2D.new()
	buildings.y_sort_enabled = true
	add_child(buildings)
	for item in data.buildings:
		var sprite := Sprite2D.new()
		sprite.texture = load(item[5])
		var dimensions: Vector2 = sprite.texture.get_size()
		sprite.scale = Vector2.ONE*float(item[4])/dimensions.x
		sprite.offset = Vector2(0,-dimensions.y*0.5)
		sprite.position = Vector2(item[3][0],item[3][1])
		buildings.add_child(sprite)
		targets.append({"node":item[2],"name":item[1],"position":sprite.position,"size":Vector2(item[4],dimensions.y*sprite.scale.y)})
		var label := Label.new()
		label.text = item[1]
		label.position = sprite.position+Vector2(-55,5)
		label.size = Vector2(110,28)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",21)
		label.add_theme_constant_override("outline_size",5)
		label.add_theme_color_override("font_outline_color",Color("172023"))
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buildings.add_child(label)
	portal = Sprite2D.new()
	portal.texture = preload("res://assets/camp/buildings/env_camp_portal.png")
	portal.scale = Vector2.ONE*210.0/portal.texture.get_width()
	portal.position = graph.get_point_position(0)
	add_child(portal)
	route_line = Line2D.new()
	route_line.width = 3
	route_line.default_color = Color("dfbe73")
	add_child(route_line)
	actor = Polygon2D.new()
	actor.polygon = PackedVector2Array([Vector2(0,-15),Vector2(7,-4),Vector2(0,1),Vector2(-7,-4)])
	actor.color = Color("f0cd80")
	add_child(actor)
	reset_walk()

func reset_walk() -> void:
	current = 0
	route = PackedInt64Array()
	if is_instance_valid(actor): actor.position = graph.get_point_position(0)
	if is_instance_valid(route_line): route_line.clear_points()

func move_to_node(id: int) -> bool:
	if not graph.has_point(id): return false
	var start := int(route[0]) if not route.is_empty() else current
	var next := graph.get_id_path(start,id)
	if next.is_empty(): return false
	if route.is_empty(): next.remove_at(0)
	route = next
	return true

func click_at(global_point: Vector2) -> void:
	var point := to_local(global_point)
	for target in targets:
		if Rect2(target.position-Vector2(target.size.x*0.5,target.size.y),target.size).has_point(point):
			move_to_node(target.node)
			feedback.emit("前往"+str(target.name)+" · 候选路线验证")
			return
	var id := graph.get_closest_point(point)
	if point.distance_to(graph.get_point_position(id)) < 60:
		move_to_node(id)
	else: feedback.emit("此处不在已标注路线内；候选暂支持门口及路线节点行走")

func _process(delta: float) -> void:
	if not visible: return
	phase += delta
	portal.modulate = Color(1,1,1,0.9+sin(phase*2)*0.1)
	if not route.is_empty():
		var goal := graph.get_point_position(route[0])
		actor.position = actor.position.move_toward(goal,110*delta)
		if actor.position.is_equal_approx(goal):
			current = route[0]
			route.remove_at(0)
	route_line.clear_points()
	if not route.is_empty():
		route_line.add_point(actor.position)
		for id in route: route_line.add_point(graph.get_point_position(id))
