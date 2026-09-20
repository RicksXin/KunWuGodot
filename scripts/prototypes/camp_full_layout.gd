extends "res://scripts/prototypes/camp_terrace_slice.gd"
## Full-camp structural experiment; shared local movement, no camp business commands.
var buildings: Dictionary = {}
var stairs_by_cell: Dictionary = {}
var use_stair_art := true
var rim_node: Node2D
var building_selection: Line2D
var portal: Node2D
var stream: Line2D
var stream_dashes: Array[Line2D] = []
var selected_id := "council"
var name_labels: Array[Label] = []
var full_size := Vector2i(12,12)

func _ready() -> void:
	definition = JSON.parse_string(FileAccess.get_file_as_string("res://data/prototypes/camp_full_layout.json"))
	full_size = Vector2i(definition.size[0],definition.size[1])
	for info in definition.buildings:
		for y in range(2):
			for x in range(2): blocked[Vector2i(info.origin[0]+x,info.origin[1]+y)] = true
	for info in definition.stairs: stairs_by_cell[Vector2i(info.cell[0],info.cell[1])] = info
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lower = Terrain.new()
	add_child(lower)
	cliff = Node2D.new()
	add_child(cliff)
	var middle := Terrain.new()
	middle.position.y = -48
	add_child(middle)
	upper = Terrain.new()
	upper.position.y = -96
	add_child(upper)
	for y in range(full_size.y):
		for x in range(full_size.x):
			if y in [2,4,7,9,10] or x in [2,9]: lower.stone[Vector2i(x,y)] = true
	for info in definition.buildings: lower.stone[Vector2i(info.door[0],info.door[1])] = true
	middle.stone = lower.stone.duplicate()
	upper.stone = lower.stone.duplicate()
	for y in range(full_size.y):
		for x in range(full_size.x):
			var cell := Vector2i(x,y)
			var level := base_height(cell)
			var layer: TileMapLayer = upper if level == 96 else (middle if level == 48 else lower)
			# Use the approved complete terrace's ground, with global UV phase.
			# Walls remain on exposed boundaries only; never tile the full L sprite.
			var surface := Polygon2D.new()
			surface.name = "Ground_%d_%d" % [x,y]
			surface.texture = preload("res://resources/prototypes/camp_ground_candidate/surface.png")
			surface.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			surface.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
			var corners := PackedVector2Array()
			for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
				corners.append(flat(Vector2(cell)+offset))
			surface.polygon = corners
			surface.uv = corners
			layer.add_child(surface)
	surface_style = 4
	_build_cliffs()
	_build_stairs()
	route_line = Line2D.new()
	route_line.width = 3
	route_line.default_color = Color("dfba65")
	add_child(route_line)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	_build_hall()
	for info in definition.buildings:
		if info.id != "council": _placeholder(info)
		else: buildings[info.id] = {"node":hall,"info":info}
	for item in buildings.values():
		var door := project(Vector2(item.info.door[0],item.info.door[1]))
		var ring := Line2D.new()
		ring.name = str(item.info.id)+"_door"
		ring.points = PackedVector2Array([door+Vector2(-12,0),door+Vector2(0,-6),door+Vector2(12,0),door+Vector2(0,6),door+Vector2(-12,0)])
		ring.width = 2
		ring.default_color = Color("d7bd78")
		add_child(ring)
		move_child(ring,entities.get_index())
	building_selection = Line2D.new()
	building_selection.width = 3
	building_selection.default_color = Color("f4d382")
	add_child(building_selection)
	move_child(building_selection,entities.get_index())
	_build_portal()
	_build_stream()
	_build_actor()
	reset_walk()

func base_height(cell: Vector2i) -> float:
	if cell.x <= 5 and cell.y <= 2: return 96
	if cell.y <= 7: return 48
	return 0

func height_at(p: Vector2) -> float:
	for info in definition.stairs:
		var center := Vector2(info.cell[0],info.cell[1])
		var along: float = p.x-center.x if info.axis == "x" else p.y-center.y
		var across: float = p.y-center.y if info.axis == "x" else p.x-center.x
		if absf(across) <= 0.5 and absf(along) <= 0.5:
			return float(info.high)-(along+0.5)*48
	return base_height(Vector2i(floori(p.x+0.5),floori(p.y+0.5)))

func walkable(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < full_size.x and cell.y < full_size.y and not blocked.has(cell)

func can_step(a: Vector2i, b: Vector2i) -> bool:
	if not walkable(a) or not walkable(b) or absi(a.x-b.x)+absi(a.y-b.y) != 1: return false
	for stair in [a,b]:
		if stairs_by_cell.has(stair):
			var info: Dictionary = stairs_by_cell[stair]
			var other: Vector2i = b if stair == a else a
			return other == Vector2i(info.from[0],info.from[1]) or other == Vector2i(info.to[0],info.to[1])
	return base_height(a) == base_height(b)

func _build_cliffs() -> void:
	if is_instance_valid(rim_node):
		remove_child(rim_node)
		rim_node.queue_free()
	rim_node = Node2D.new()
	rim_node.name = "BoundaryRims"
	add_child(rim_node)
	move_child(rim_node,upper.get_index()+1)
	var continuous_edges: Array[Dictionary] = []
	for y in range(full_size.y):
		for x in range(full_size.x):
			var cell := Vector2i(x,y)
			var h := base_height(cell)
			for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
				var neighbor: Vector2i = cell+axis
				var outside: bool = neighbor.x == full_size.x or neighbor.y == full_size.y
				var next_h := -22.0 if outside else base_height(neighbor)
				if h <= next_h: continue
				var a := flat(Vector2(x+0.5,y-0.5) if axis == Vector2i.RIGHT else Vector2(x-0.5,y+0.5))-Vector2(0,h)
				var b := flat(Vector2(x+0.5,y+0.5))-Vector2(0,h)
				if surface_style == 4:
					continuous_edges.append({"a":a,"b":b,"height":h-next_h})
				elif surface_style == 0:
					polygon(cliff,[a,b,b+Vector2(0,h-next_h),a+Vector2(0,h-next_h)],"514f43" if axis == Vector2i.DOWN else "41463f")
				elif surface_style == 3:
					CliffCandidate.wall(cliff,a,b,h-next_h)
				elif outside and surface_style == 2:
					Stonework.rock_wall(cliff,a,b,h-next_h,x*91+y*17,0.85)
				else: Stonework.wall(cliff,a,b,h-next_h,x*91+y*17,0.9)
	if surface_style == 4:
		preload("res://scripts/prototypes/camp_continuous_cliff.gd").build(cliff,continuous_edges,rim_node)
		# Preserve natural rear soil/stone rims from the complete source, too.
		for y in range(full_size.y):
			for x in range(full_size.x):
				if x != 0 and y != 0: continue
				for axis in [Vector2i.LEFT,Vector2i.UP]:
					if (axis == Vector2i.LEFT and x != 0) or (axis == Vector2i.UP and y != 0): continue
					var p := flat(Vector2(x-0.5,y-0.5))-Vector2(0,base_height(Vector2i(x,y)))
					var q := flat(Vector2(x-0.5,y+0.5) if axis == Vector2i.LEFT else Vector2(x+0.5,y-0.5))-Vector2(0,base_height(Vector2i(x,y)))
					var start := p if p.x<q.x else q
					var finish := q if p.x<q.x else p
					var edge := Polygon2D.new()
					edge.texture = preload("res://resources/prototypes/camp_terrace_profiles/back-a.png") if finish.y>start.y else preload("res://resources/prototypes/camp_terrace_profiles/back-b.png")
					edge.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
					edge.polygon = PackedVector2Array([start-Vector2(0,12),finish-Vector2(0,12),finish+Vector2(0,20),start+Vector2(0,20)])
					edge.uv = PackedVector2Array([Vector2(start.x,0),Vector2(finish.x,0),Vector2(finish.x,32),Vector2(start.x,32)])
					edge.set_meta("rear_profile",true)
					rim_node.add_child(edge)

func _build_stairs() -> void:
	stairs_node = Node2D.new()
	stairs_node.name = "SolidStairs"
	add_child(stairs_node)
	move_child(stairs_node,rim_node.get_index()+1 if is_instance_valid(rim_node) else upper.get_index()+1)
	for info in definition.stairs:
		var center := Vector2(info.cell[0],info.cell[1])
		var along := Vector2.RIGHT if info.axis == "x" else Vector2.DOWN
		var across := Vector2.DOWN if info.axis == "x" else Vector2.RIGHT
		var a := flat(center-along*0.5-across*0.5)-Vector2(0,info.high)
		var b := flat(center-along*0.5+across*0.5)-Vector2(0,info.high)
		var c := flat(center+along*0.5+across*0.5)-Vector2(0,info.high-48)
		var d := flat(center+along*0.5-across*0.5)-Vector2(0,info.high-48)
		if use_stair_art:
			var art := Sprite2D.new()
			art.name = str(info.id)+"_art"
			art.texture = preload("res://assets/prototypes/camp_stairs/stairs_fullcamp_y.png") if info.axis == "y" else preload("res://assets/prototypes/camp_stairs/stairs_fullcamp_x.png")
			art.centered = false
			art.position = a-Vector2(72,8)
			stairs_node.add_child(art)
		elif surface_style > 0: Stonework.stairs(stairs_node,a,b,c,d)
		else:
			polygon(stairs_node,[a,b,c,d],"958b74")
			for i in range(9): Stonework.edge(stairs_node,[a.lerp(d,i/8.0),b.lerp(c,i/8.0)],Color("c6b99a"),2)
		for endpoint in ["from","to"]:
			var marker := Marker2D.new()
			marker.name = str(info.id)+"_"+endpoint
			marker.position = project(Vector2(info[endpoint][0],info[endpoint][1]))
			stairs_node.add_child(marker)

func set_stair_art(on: bool) -> void:
	use_stair_art = on
	if is_instance_valid(stairs_node):
		remove_child(stairs_node)
		stairs_node.queue_free()
	_build_stairs()

func _build_hall() -> void:
	super._build_hall()
	hall.position = project(Vector2(3.5,1.5))
	_name_label(hall,"议事殿",Vector2(-65,-215))
	door_anchor.position = project(Vector2(3,2))-hall.position

func _name_label(parent: Node2D, title: String, point: Vector2) -> void:
	var label := Label.new()
	label.text = title
	label.position = point
	label.add_theme_font_override("font",preload("res://assets/fonts/NotoSansSC.ttf"))
	label.add_theme_font_size_override("font_size",17)
	label.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	label.z_index = 20
	label.size = Vector2(130,26)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.set_meta("anchor",point+Vector2(65,0))
	name_labels.append(label)
	label.add_theme_color_override("font_color",Color("f0e5d0"))
	label.add_theme_color_override("font_outline_color",Color("172023"))
	label.add_theme_constant_override("outline_size",3)
	parent.add_child(label)

func _placeholder(info: Dictionary) -> void:
	var node := Node2D.new()
	node.name = info.id
	node.position = project(Vector2(info.origin[0]+1.5,info.origin[1]+1.5))
	entities.add_child(node)
	polygon(node,[Vector2(-128,-64),Vector2(0,0),Vector2(0,-88),Vector2(-128,-152)],"615e50")
	polygon(node,[Vector2(0,0),Vector2(128,-64),Vector2(128,-152),Vector2(0,-88)],"484d47")
	polygon(node,[Vector2(-128,-152),Vector2(0,-216),Vector2(128,-152),Vector2(0,-88)],"897b58")
	_name_label(node,info.name,Vector2(-65,-240))
	for anchor_name in ["DoorAnchor","StateAnchor","EffectAnchor"]:
		var anchor := Marker2D.new()
		anchor.name = anchor_name
		anchor.position = project(Vector2(info.door[0],info.door[1]))-node.position if anchor_name == "DoorAnchor" else Vector2(0,-185)
		node.add_child(anchor)
	buildings[info.id] = {"node":node,"info":info}

func _build_portal() -> void:
	portal = Node2D.new()
	portal.name = "PortalPreview"
	portal.position = project(Vector2(definition.portal.cell[0],definition.portal.cell[1]))
	# A ground effect must not Y-sort over a walking body.
	add_child(portal)
	move_child(portal,entities.get_index())
	for radius in [28,43]:
		var ring := Line2D.new()
		var points := PackedVector2Array()
		for i in range(33):
			var angle := TAU*i/32.0
			points.append(Vector2(cos(angle)*radius,sin(angle)*radius*0.5))
		ring.points = points
		ring.width = 3
		ring.default_color = Color("75c6bc")
		portal.add_child(ring)
	_name_label(portal,"传送阵",Vector2(-65,28))

func _build_stream() -> void:
	stream = Line2D.new()
	stream.width = 18
	stream.default_color = Color("426c7c")
	for y in range(13): stream.add_point(flat(Vector2(13.0,y-0.5))-Vector2(0,48 if y <= 7 else 0))
	add_child(stream)
	move_child(stream,0)
	for i in range(12):
		var dash := Line2D.new()
		dash.width = 3
		dash.default_color = Color("8ab5b9")
		stream.add_child(dash)
		stream_dashes.append(dash)
	_name_label(stream,"溪流 · 动效占位",flat(Vector2(13.0,5))-Vector2(45,48))

func move_to_building(id: String) -> bool:
	var cell := Vector2i(definition.portal.cell[0],definition.portal.cell[1])
	if buildings.has(id):
		var door: Array = buildings[id].info.door
		cell = Vector2i(door[0],door[1])
	var moved := move_to(cell)
	if moved:
		selected_id = id
		building_selection.clear_points()
		if buildings.has(id):
			var info: Dictionary = buildings[id].info
			var origin := Vector2(info.origin[0],info.origin[1])
			for offset in [Vector2(-0.5,-0.5),Vector2(1.5,-0.5),Vector2(1.5,1.5),Vector2(-0.5,1.5),Vector2(-0.5,-0.5)]:
				building_selection.add_point(flat(origin+offset)-Vector2(0,base_height(Vector2i(origin))))
	return moved

func click_at(global_point: Vector2) -> void:
	# Reverse painter order when two placeholder silhouettes overlap.
	var ordered: Array = buildings.values()
	ordered.sort_custom(func(a: Dictionary,b: Dictionary): return a.node.position.y > b.node.position.y)
	for item in ordered:
		var local_point: Vector2 = item.node.to_local(global_point)
		var bounds := hall_hit if item.node == hall else PackedVector2Array([Vector2(-128,-64),Vector2(-128,-152),Vector2(0,-216),Vector2(128,-152),Vector2(128,-64),Vector2.ZERO])
		if item.node.visible and Geometry2D.is_point_in_polygon(local_point,bounds):
			if move_to_building(item.info.id): feedback.emit("前往"+str(item.info.name)+"门前 · 仅验证移动，不触发营地业务")
			return
	var point := to_local(global_point)
	var closest := Vector2i(-1,-1)
	var distance := 10000.0
	for y in range(full_size.y):
		for x in range(full_size.x):
			var cell := Vector2i(x,y)
			var delta := point-project(Vector2(cell))
			var metric := absf(delta.x)/64+absf(delta.y)/32
			if metric <= 1 and metric < distance:
				distance = metric
				closest = cell
	if closest.x >= 0: move_to(closest)

func set_buildings_visible(enabled: bool) -> void:
	for item in buildings.values(): item.node.visible = enabled

func _process(delta: float) -> void:
	super._process(delta)
	if not visible or not is_instance_valid(portal): return
	var zoom := get_global_transform().get_scale().x
	for label in name_labels:
		label.scale = Vector2.ONE/zoom
		label.position = label.get_meta("anchor")-Vector2(65/zoom,0)
	portal.modulate.a = 0.85+0.15*sin(clock*2) if effects_enabled else 1.0
	for i in range(stream_dashes.size()):
		var t := fmod(i/12.0+(clock*0.045 if effects_enabled else 0.0),1.0)*12
		var segment := mini(11,floori(t))
		var a := stream.points[segment]
		var b := stream.points[segment+1]
		var start := a.lerp(b,t-segment)
		stream_dashes[i].points = PackedVector2Array([start,start+(b-a).normalized()*11])

func reset_walk() -> void:
	super.reset_walk()
	if is_instance_valid(building_selection): building_selection.clear_points()

func overview_bounds() -> Rect2:
	return Rect2(Vector2(-full_size.y*64,-160),Vector2((full_size.x+full_size.y)*64+128,(full_size.x+full_size.y)*32+240))
