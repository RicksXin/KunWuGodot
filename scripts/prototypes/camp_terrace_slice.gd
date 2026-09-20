extends Node2D
## Authored grid topology controls both movement and elevation. No runtime art API.
signal feedback(text: String)
const Terrain = preload("res://scripts/prototypes/camp_dual_terrain.gd")
const CliffCandidate = preload("res://scripts/prototypes/camp_cliff_candidate.gd")
const Stonework = preload("res://scripts/prototypes/camp_stonework.gd")
var stonework_preview := false
var surface_style := 0 # 0 graybox, 1 masonry, 2 rock, 3 optional unapproved tile review
var stairs_node: Node2D
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
var definition: Dictionary
var upper: Terrain
var lower: Terrain
var cliff: Node2D
var entities: Node2D
var hall: Node2D
var actor: Node2D
var door_anchor: Marker2D
var smoke_anchor: Marker2D
var light_anchor: Marker2D
var lamp: Polygon2D
var highlight: Line2D
var route_line: Line2D
var destination_marker: Line2D
var grid_position := Vector2(2,5)
var current_cell := Vector2i(2,5)
var route: Array[Vector2i] = []
var selected := false
var effects_enabled := true
var clock := 0.0
var hall_hit := PackedVector2Array()
var blocked: Dictionary = {}

func _ready() -> void:
	definition = JSON.parse_string(FileAccess.get_file_as_string("res://data/prototypes/camp_terrace.json"))
	for pair in definition.building_cells: blocked[Vector2i(pair[0],pair[1])] = true
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lower = Terrain.new()
	add_child(lower)
	cliff = Node2D.new()
	add_child(cliff)
	upper = Terrain.new()
	upper.position.y = -float(definition.rise)
	add_child(upper)
	# A shared mask field keeps material scale and the stair landings consistent.
	for y in range(6):
		for x in range(6):
			if x == 2 or (y == 2 and x >= 1 and x <= 4) or (y == 5 and x >= 1 and x <= 4):
				upper.stone[Vector2i(x,y)] = true
	lower.stone = upper.stone.duplicate()
	for y in range(6):
		for x in range(6):
			var cell := Vector2i(x,y)
			var layer := upper if y <= int(definition.upper_last_row) else lower
			layer.set_cell(cell,0,layer.ATLAS[layer.mask_at(cell)])
	surface_style = 2 if OS.get_cmdline_user_args().has("--rockwork-preview") else (1 if OS.get_cmdline_user_args().has("--stonework-preview") else 0)
	stonework_preview = surface_style > 0
	_build_cliffs()
	_build_stairs()
	route_line = Line2D.new()
	route_line.width = 2
	route_line.default_color = Color(0.95,0.78,0.4,0.7)
	add_child(route_line)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	_build_hall()
	_build_actor()
	reset_walk()

func flat(p: Vector2) -> Vector2:
	return lower.map_to_local(Vector2i.ZERO) + Vector2((p.x-p.y)*64,(p.x+p.y)*32)

func height_at(p: Vector2) -> float:
	if p.y <= 2.5: return float(definition.rise)
	if p.y < 3.5 and absf(p.x-2.0) <= 0.5: return (3.5-p.y)*float(definition.rise)
	return 0.0

func project(p: Vector2) -> Vector2:
	return flat(p) - Vector2(0,height_at(p))

func polygon(parent: Node2D, points: Array, color: String) -> Polygon2D:
	var shape := Polygon2D.new()
	shape.polygon = PackedVector2Array(points)
	shape.color = Color(color)
	parent.add_child(shape)
	return shape

func set_stonework_preview(enabled: bool) -> void:
	set_surface_style(1 if enabled else 0)

func set_surface_style(style: int) -> void:
	surface_style = clampi(style,0,4)
	if surface_style == 3 and not CliffCandidate.available():
		surface_style = 0
		feedback.emit("候选文件不可用，已回退到灰盒")
	stonework_preview = surface_style > 0
	for child in cliff.get_children():
		cliff.remove_child(child)
		child.queue_free()
	if is_instance_valid(stairs_node):
		remove_child(stairs_node)
		stairs_node.queue_free()
	_build_cliffs()
	_build_stairs()

func _build_cliffs() -> void:
	if surface_style == 3:
		CliffCandidate.wall(cliff,flat(Vector2(-0.5,2.5))-Vector2(0,48),flat(Vector2(5.5,2.5))-Vector2(0,48),48)
		CliffCandidate.wall(cliff,flat(Vector2(5.5,-0.5))-Vector2(0,48),flat(Vector2(5.5,2.5))-Vector2(0,48),70)
		CliffCandidate.wall(cliff,flat(Vector2(5.5,2.5)),flat(Vector2(5.5,5.5)),22)
		CliffCandidate.wall(cliff,flat(Vector2(-0.5,5.5)),flat(Vector2(5.5,5.5)),22)
		return
	if stonework_preview:
		Stonework.wall(cliff,flat(Vector2(-0.5,2.5))-Vector2(0,48),flat(Vector2(5.5,2.5))-Vector2(0,48),48,42)
		if surface_style == 2:
			Stonework.rock_wall(cliff,flat(Vector2(5.5,-0.5))-Vector2(0,48),flat(Vector2(5.5,2.5))-Vector2(0,48),70,71,0.8)
			Stonework.rock_wall(cliff,flat(Vector2(5.5,2.5)),flat(Vector2(5.5,5.5)),22,82,0.8)
			Stonework.rock_wall(cliff,flat(Vector2(-0.5,5.5)),flat(Vector2(5.5,5.5)),22,93,0.87)
		else:
			Stonework.wall(cliff,flat(Vector2(5.5,-0.5))-Vector2(0,48),flat(Vector2(5.5,2.5))-Vector2(0,48),70,71,0.8)
			Stonework.wall(cliff,flat(Vector2(5.5,2.5)),flat(Vector2(5.5,5.5)),22,82,0.8)
			Stonework.wall(cliff,flat(Vector2(-0.5,5.5)),flat(Vector2(5.5,5.5)),22,93,0.87)
		return
	# Continuous solid supporting wall on the shared upper/lower boundary.
	for x in range(6):
		var a := flat(Vector2(x-0.5,2.5))
		var b := flat(Vector2(x+0.5,2.5))
		polygon(cliff,[a-Vector2(0,48),b-Vector2(0,48),b,a],"504c43" if x%2==0 else "575247")
		var seam := Line2D.new()
		seam.points = PackedVector2Array([a-Vector2(0,48),b-Vector2(0,48)])
		seam.default_color = Color("aaa08b")
		seam.width = 2
		cliff.add_child(seam)
	# Exposed outer sides have a continuous base, rather than floating tiles.
	for y in range(6):
		var a := flat(Vector2(5.5,y-0.5))
		var b := flat(Vector2(5.5,y+0.5))
		var rise := 48.0 if y<=2 else 0.0
		polygon(cliff,[a-Vector2(0,rise),b-Vector2(0,rise),b+Vector2(0,22),a+Vector2(0,22)],"45463f")
	var left := flat(Vector2(-0.5,5.5))
	var right := flat(Vector2(5.5,5.5))
	polygon(cliff,[left,right,right+Vector2(0,22),left+Vector2(0,22)],"393e39")

func _build_stairs() -> void:
	var stairs := Node2D.new()
	stairs_node = stairs
	stairs.name = "SolidStairs"
	add_child(stairs)
	move_child(stairs,upper.get_index()+1)
	var a := flat(Vector2(1.5,2.5))-Vector2(0,48)
	var b := flat(Vector2(2.5,2.5))-Vector2(0,48)
	var c := flat(Vector2(2.5,3.5))
	var d := flat(Vector2(1.5,3.5))
	if stonework_preview:
		Stonework.stairs(stairs,a,b,c,d)
		return
	polygon(stairs,[a,b,c,d],"8c8370")
	polygon(stairs,[b,c,c+Vector2(0,8),flat(Vector2(2.5,2.5))],"625c50")
	for i in range(9):
		var t := i/8.0
		var line := Line2D.new()
		line.points = PackedVector2Array([a.lerp(d,t),b.lerp(c,t)])
		line.width = 2
		line.default_color = Color("c1b69e")
		stairs.add_child(line)

func _build_hall() -> void:
	hall = Node2D.new()
	hall.name = "CouncilHall"
	hall.position = project(Vector2(2.5,1.5))
	entities.add_child(hall)
	var sprite := Sprite2D.new()
	sprite.name = "BuildingArt"
	sprite.texture = preload("res://assets/prototypes/camp_council/council.png")
	sprite.centered = false
	sprite.position = Vector2(-182,-216)
	hall.add_child(sprite)
	hall_hit = PackedVector2Array([Vector2(-144,-56),Vector2(-137,-130),Vector2(-67,-202),Vector2(15,-211),Vector2(117,-126),Vector2(119,-45),Vector2.ZERO])
	highlight = Line2D.new()
	highlight.points = hall_hit
	highlight.closed = true
	highlight.width = 3
	highlight.default_color = Color("efd28e")
	highlight.visible = false
	hall.add_child(highlight)
	for info in [["DoorAnchor",Vector2(-83,-31)],["SmokeAnchor",Vector2(0,-190)],["LightAnchor",Vector2(-111,-50)]]:
		var anchor := Marker2D.new()
		anchor.name = info[0]
		anchor.position = info[1]
		hall.add_child(anchor)
	door_anchor = hall.get_node("DoorAnchor")
	smoke_anchor = hall.get_node("SmokeAnchor")
	light_anchor = hall.get_node("LightAnchor")
	lamp = polygon(light_anchor,[Vector2(-4,-5),Vector2(4,-5),Vector2(4,5),Vector2(-4,5)],"ffd482")

func _build_actor() -> void:
	actor = Node2D.new()
	actor.name = "Walker"
	entities.add_child(actor)
	polygon(actor,[Vector2(-10,0),Vector2(0,-5),Vector2(10,0),Vector2(0,5)],"252c2a")
	polygon(actor,[Vector2(-7,-4),Vector2(-6,-21),Vector2(6,-21),Vector2(8,-4)],"659fbc")
	polygon(actor,[Vector2(-5,-23),Vector2(-5,-32),Vector2(5,-32),Vector2(5,-23)],"dfbd91")

func walkable(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.y>=0 and cell.x<6 and cell.y<6 and not blocked.has(cell)

func can_step(a: Vector2i, b: Vector2i) -> bool:
	if not walkable(a) or not walkable(b) or absi(a.x-b.x)+absi(a.y-b.y)!=1: return false
	var stairs := Vector2i(2,3)
	if a == stairs or b == stairs:
		return a.x == 2 and b.x == 2
	if (a.y<=2) != (b.y<=2): return false
	return true

func find_route(start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not walkable(start) or not walkable(goal): return result
	var queue: Array[Vector2i] = [start]
	var visited := {start:start}
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		if cell == goal:
			while cell != start:
				result.push_front(cell)
				cell = visited[cell]
			return result
		for delta in DIRECTIONS:
			var next: Vector2i = cell+delta
			if not visited.has(next) and can_step(cell,next):
				visited[next] = cell
				queue.append(next)
	return result

func move_to(cell: Vector2i) -> bool:
	# Finish only the active edge before redirecting, preserving continuous stair travel.
	var moving := not route.is_empty()
	var start: Vector2i = route[0] if moving else current_cell
	if not moving and cell == current_cell: return true
	var path := find_route(start,cell)
	if path.is_empty() and cell != start:
		feedback.emit("此处不可到达：建筑占地与崖边均有阻挡")
		return false
	if moving: path.push_front(start)
	route = path
	if not is_instance_valid(destination_marker):
		destination_marker = Line2D.new()
		destination_marker.points = PackedVector2Array([Vector2(0,-6),Vector2(12,0),Vector2(0,6),Vector2(-12,0),Vector2(0,-6)])
		destination_marker.width = 2
		destination_marker.default_color = Color("e4c26a")
		destination_marker.z_index = 5
		add_child(destination_marker)
	destination_marker.position = project(Vector2(cell))
	destination_marker.show()
	_update_route_display()
	feedback.emit("沿道路与石阶前往目标 · 途中可改选目的地")
	return true

func _update_route_display() -> void:
	route_line.clear_points()
	if route.is_empty(): return
	route_line.add_point(project(grid_position))
	for step in route: route_line.add_point(project(Vector2(step)))

func click_at(global_point: Vector2) -> void:
	if hall.visible and Geometry2D.is_point_in_polygon(hall.to_local(global_point),hall_hit):
		selected = not selected
		highlight.visible = selected
		feedback.emit("议事殿已选中 · 可点「前往门前」验证道路" if selected else "已取消建筑选择")
		return
	var point := to_local(global_point)
	var closest := Vector2i(-1,-1)
	var distance := 100000.0
	for y in range(6):
		for x in range(6):
			var cell := Vector2i(x,y)
			var delta: Vector2 = point-project(Vector2(cell))
			var metric := absf(delta.x)/64+absf(delta.y)/32
			if metric<=1 and metric<distance:
				distance = metric
				closest = cell
	if closest.x>=0: move_to(closest)

func reset_walk() -> void:
	route.clear()
	current_cell = Vector2i(definition.spawn[0],definition.spawn[1])
	grid_position = Vector2(current_cell)
	actor.position = project(grid_position)
	route_line.clear_points()
	if is_instance_valid(destination_marker): destination_marker.hide()
	selected = false
	highlight.visible = false
	feedback.emit("已复位到下层道路 · 点击地面行走或选择建筑")

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	lamp.modulate.a = 0.8+sin(clock*3)*0.2 if effects_enabled else 1.0
	if route.is_empty(): return
	grid_position = grid_position.move_toward(Vector2(route[0]),delta*1.7)
	actor.position = project(grid_position)
	_update_route_display()
	if grid_position.is_equal_approx(Vector2(route[0])):
		current_cell = route.pop_front()
		if route.is_empty():
			route_line.clear_points()
			feedback.emit("已到达 (%d, %d) · 高度 %d" % [current_cell.x,current_cell.y,height_at(grid_position)])
