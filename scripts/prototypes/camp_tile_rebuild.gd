extends Node2D
signal feedback(text: String)
const Terrain = preload("res://scripts/prototypes/camp_dual_terrain.gd")
var heights: Dictionary = {}
const Collision = preload("res://scripts/prototypes/camp_collision.gd")
var footprints: Array[PackedVector2Array] = []
var blocked: Dictionary = {}
var stair_cells: Dictionary = {}
var graph := AStar2D.new()
var ids: Dictionary = {}
var data: Dictionary
var definition_override: Dictionary = {}
var layers: Array[TileMapLayer] = []
var buildings: Node2D
var mountain_mist: Node2D
var npcs: Node2D
var decorations: Node2D
var ground_decorations: Node2D
var portal: Sprite2D
var depth_sorted: Node2D
var overlay: Node2D
var actor: Polygon2D
var route := PackedInt64Array()
var route_line: Line2D
var current := 0
var targets: Array[Dictionary] = []
var tiles_count := 0
var mountain_cells: Dictionary = {}
var foundation: TileMapLayer
var edge_overlays: Node2D

func flat(cell: Vector2) -> Vector2:
	return Vector2((cell.x-cell.y)*64,(cell.x+cell.y)*32)
func point(cell: Vector2i) -> Vector2:
	return flat(Vector2(cell))-Vector2(0,float(heights.get(cell,0)))
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	data = definition_override.duplicate(true) if not definition_override.is_empty() else JSON.parse_string(FileAccess.get_file_as_string("res://data/prototypes/camp_tile_rebuild.json"))
	for item in data.cells: heights[Vector2i(item[0],item[1])] = item[2]
	for item in data.stairs: stair_cells[Vector2i(item.cell[0],item.cell[1])] = item
	var stream = preload("res://scripts/prototypes/camp_stream.gd").new()
	stream.definition = data.get("stream",{})
	add_child(stream)
	_build_mountain_support()
	_build_stair_landings()
	_build_rear_slopes()
	_build_rear_decor("back")
	footprints = Collision.polygons(data)
	for cell: Vector2i in heights:
		if Collision.contains(point(cell),footprints): blocked[cell] = true
	for h in [0,48,96]:
		var level := Node2D.new()
		add_child(level)
		var walls := Node2D.new()
		level.add_child(walls)
		var layer = Terrain.new()
		layer.name = "GroundHeight%d" % h
		var ground_material := ShaderMaterial.new()
		ground_material.shader = preload("res://scripts/prototypes/camp_natural_ground.gdshader")
		ground_material.set_shader_parameter("paving",preload("res://resources/prototypes/camp_natural_materials/paving.png"))
		_configure_ground_boundary(ground_material,h)
		layer.material = ground_material
		# Godot's DIAMOND_DOWN origin is (64,32), not (0,0).
		# All art, stairs and navigation use the mathematical cell centre.
		layer.position = -layer.map_to_local(Vector2i.ZERO)-Vector2(0,h)
		level.add_child(layer)
		layers.append(layer)
		var rims := Node2D.new()
		level.add_child(rims)
		var edges: Array[Dictionary] = []
		for cell: Vector2i in heights:
			if heights[cell] != h: continue
			var interior := true
			for corner in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
				if heights.get(cell+corner,-999) != h: interior = false
			if interior: layer.stone[cell] = true
		for cell: Vector2i in heights:
			if heights[cell] != h: continue
			var boundary := false
			for axis in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				if not heights.has(cell+axis): boundary = true
			layer.set_cell(cell,0,layer.ATLAS[layer.mask_at(cell)])
			tiles_count += 1
			for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
				var n: Vector2i = cell+axis
				if stair_cells.has(n): continue
				var next_h := float(heights.get(n,-48))
				if h <= next_h: continue
				var a := flat(Vector2(cell)+ (Vector2(0.5,-0.5) if axis==Vector2i.RIGHT else Vector2(-0.5,0.5)))-Vector2(0,h)
				var b := flat(Vector2(cell)+Vector2(0.5,0.5))-Vector2(0,h)
				edges.append({"a":a,"b":b,"height":h-next_h})
		preload("res://scripts/prototypes/camp_mountain_cliff.gd").build(walls,edges,rims)
		preload("res://scripts/prototypes/camp_railings.gd").build(rims,heights,stair_cells,h)
	_build_rear_decor("front")
	_build_rock_slopes()
	for cell: Vector2i in stair_cells:
		var st: Dictionary = stair_cells[cell]
		var a := flat(Vector2(cell)-Vector2(0.5,0.5))-Vector2(0,st.high)
		var sprite := Sprite2D.new()
		sprite.texture = preload("res://assets/prototypes/camp_stairs/stairs_fullcamp_x.png") if st.axis=="x" else preload("res://assets/prototypes/camp_stairs/stairs_fullcamp_y.png")
		sprite.centered = false
		sprite.position = a-Vector2(72,8)
		var stone_material := ShaderMaterial.new()
		stone_material.shader = preload("res://scripts/prototypes/camp_stair_stone.gdshader")
		stone_material.set_shader_parameter("paving",preload("res://resources/prototypes/camp_natural_materials/paving.png"))
		sprite.material = stone_material
		add_child(sprite)
	var id := 0
	for cell: Vector2i in heights:
		if blocked.has(cell): continue
		ids[cell] = id
		graph.add_point(id,point(cell))
		id += 1
	for cell: Vector2i in ids:
		for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
			var neighbor: Vector2i = cell+axis
			if ids.has(neighbor) and can_step(cell,neighbor) and not Collision.crosses(point(cell),point(neighbor),footprints): graph.connect_points(ids[cell],ids[neighbor])
	ground_decorations = Node2D.new()
	ground_decorations.name = "GroundDecorations"
	add_child(ground_decorations)
	depth_sorted = Node2D.new()
	depth_sorted.name = "DepthSortedActors"
	depth_sorted.y_sort_enabled = true
	add_child(depth_sorted)
	buildings = Node2D.new()
	buildings.y_sort_enabled = true
	depth_sorted.add_child(buildings)
	for item in data.buildings:
		var origin := Vector2i(item.origin[0],item.origin[1])
		var sprite: Sprite2D = preload("res://scripts/prototypes/camp_building_3d_sprite.gd").new() if item.has("model_3d") else (preload("res://scripts/prototypes/camp_building_sequence.gd").new() if item.has("sprite_frames") else Sprite2D.new())
		sprite.texture = load(item.texture)
		sprite.scale = Vector2.ONE*220.0/sprite.texture.get_width()
		sprite.offset.y = -sprite.texture.get_height()*0.5
		sprite.position = flat(Vector2(origin)+Vector2(1,1))-Vector2(0,heights.get(origin,0))
		var door := Vector2i(item.door[0],item.door[1])
		sprite.rotation_degrees = float(item.get("rotation_degrees",0.0))
		sprite.name = item.id
		sprite.visible = item.get("preview_visible",false)
		if item.has("door_anchor"):
			# Authored image doorway anchors meet the navigation door on every building.
			sprite.centered = false
			sprite.offset = -Vector2(item.door_anchor[0],item.door_anchor[1])
			sprite.scale = Vector2.ONE*float(item.display_width)/sprite.texture.get_width()
			var visual_offset: Array = item.get("visual_offset",[0,0])
			sprite.position = point(door)+Vector2(visual_offset[0],visual_offset[1])
			# Mirror around the authored threshold so the doorway stays on its navigation cell.
			if item.get("mirror_x",false): sprite.scale.x = -sprite.scale.x
			if not item.has("sprite_frames"):
				var shader := Shader.new()
				shader.code = """shader_type canvas_item;
				uniform float alpha_cut = 0.0;
				void fragment() {
				 vec4 c = texture(TEXTURE,UV);
				 if (c.a < alpha_cut) discard;
				 float timber = smoothstep(0.04,0.16,c.r-c.b)*smoothstep(0.42,0.60,UV.y);
				 vec3 cold = c.rgb*vec3(0.69,0.77,0.85);
				 vec3 warm = c.rgb*vec3(1.12,0.94,0.70);
				 COLOR = vec4(mix(cold,warm,timber*0.70),c.a);
				}"""
				var material := ShaderMaterial.new()
				material.shader = shader
				material.set_shader_parameter("alpha_cut",float(item.get("alpha_cut",0.0)))
				sprite.material = material
		if item.has("sprite_frames"):
			sprite.configure(item)
		sprite.z_index = 0 if item.get("occlusion_enabled",true) else -1
		buildings.add_child(sprite)
		if item.has("model_3d"): sprite.configure(item)
		targets.append({"node":ids.get(door,-1),"position":sprite.position,"name":item.name,"visual":sprite})
		var label := Label.new()
		label.text = item.name
		label.z_index = 20
		var label_offset: Array = item.get("label_offset",[-35,18])
		label.position = sprite.position+Vector2(label_offset[0],label_offset[1])
		label.visible = sprite.visible
		label.add_theme_constant_override("outline_size",5)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		buildings.add_child(label)
	decorations = Node2D.new()
	decorations.name = "Decorations"
	decorations.y_sort_enabled = true
	depth_sorted.add_child(decorations)
	for item in data.get("decorations",[]):
		var prop = preload("res://scripts/prototypes/camp_decoration.gd").new()
		prop.configure(item)
		prop.place(item,point(Vector2i(item.origin[0],item.origin[1])))
		if item.get("ground_decal",false):
			ground_decorations.add_child(prop)
		else:
			decorations.add_child(prop)
	overlay = Node2D.new()
	add_child(overlay)
	for cell: Vector2i in ids:
		var dot := Polygon2D.new()
		dot.polygon = PackedVector2Array([Vector2(-3,0),Vector2(0,-2),Vector2(3,0),Vector2(0,2)])
		dot.position = point(cell)
		dot.color = Color(0.2,0.9,0.9,0.6)
		overlay.add_child(dot)
	# Placement audit shares the route toggle: red footprints, green arrival line.
	for item in data.buildings:
		if not item.get("preview_visible",false): continue
		var extent: Array = item.get("footprint_size",[2,2])
		for y in range(extent[1]):
			for x in range(extent[0]):
				var footprint := Polygon2D.new()
				footprint.polygon = PackedVector2Array([Vector2(0,-32),Vector2(64,0),Vector2(0,32),Vector2(-64,0)])
				footprint.position = point(Vector2i(item.origin[0]+x,item.origin[1]+y))
				footprint.color = Color(0.9,0.30,0.20,0.23)
				overlay.add_child(footprint)
		if item.has("approach"):
			var arrival := Line2D.new()
			arrival.points = PackedVector2Array([point(Vector2i(item.approach[0],item.approach[1])),point(Vector2i(item.door[0],item.door[1]))])
			arrival.width = 3
			arrival.default_color = Color(0.5,1.0,0.45,0.9)
			overlay.add_child(arrival)
	overlay.hide()
	if data.has("portal"):
		var item: Dictionary = data.portal
		portal = preload("res://scripts/prototypes/camp_building_sequence.gd").new()
		portal.configure(item)
		portal.centered = false
		portal.offset = -Vector2(item.door_anchor[0],item.door_anchor[1])
		portal.scale = Vector2.ONE*float(item.display_width)/portal.texture.get_width()
		if item.get("mirror_x",false): portal.scale.x *= -1.0
		portal.rotation_degrees = float(item.get("rotation_degrees",0.0))
		var shift: Array = item.get("visual_offset",[0,0])
		portal.position = point(Vector2i(item.door[0],item.door[1]))+Vector2(shift[0],shift[1])
		portal.visible = item.get("preview_visible",true)
	else:
		portal = Sprite2D.new()
		portal.texture = preload("res://assets/camp/buildings/env_camp_portal.png")
		portal.scale = Vector2.ONE*220.0/portal.texture.get_width()
		portal.position = point(Vector2i(data.spawn[0],data.spawn[1]))
	portal.name = "Portal"
	ground_decorations.add_child(portal)
	route_line = Line2D.new()
	route_line.width = 3
	route_line.default_color = Color("e5c575")
	add_child(route_line)
	actor = Polygon2D.new()
	actor.polygon = PackedVector2Array([Vector2(0,-12),Vector2(6,-3),Vector2(0,0),Vector2(-6,-3)])
	actor.color = Color("f2d883")
	depth_sorted.add_child(actor)
	npcs = preload("res://scripts/prototypes/camp_npcs.gd").new()
	npcs.name = "CampNPCs"
	depth_sorted.add_child(npcs)
	npcs.configure(data)
	mountain_mist = preload("res://scripts/prototypes/camp_mist.gd").new()
	mountain_mist.z_index = 2
	add_child(mountain_mist)
	reset_walk()

func _build_rear_slopes() -> void:
	var root := Node2D.new()
	root.name = "RearDescendingSlopes"
	add_child(root)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	varying vec4 tint;
	void vertex() { tint = COLOR; }
	void fragment() { COLOR = texture(TEXTURE,1.0-abs(mod(UV,2.0)-1.0))*tint; }
	"""
	var material := ShaderMaterial.new()
	material.shader = shader
	for placement in data.get("rear_slopes",[]):
		var direction := Vector2(placement.direction[0],placement.direction[1])
		var tangent := Vector2(-direction.y,direction.x)*0.5
		var displacement := flat(direction*float(placement.run))+Vector2(0,placement.drop)
		for coordinate in placement.cells:
			var cell := Vector2i(coordinate[0],coordinate[1])
			if not heights.has(cell): continue
			var outward := cell+Vector2i(direction)
			if heights.has(outward) and heights[outward]>=heights[cell]: continue
			var centre := Vector2(cell)+direction*0.5
			var a := flat(centre-tangent)-Vector2(0,heights[cell])
			var b := flat(centre+tangent)-Vector2(0,heights[cell])
			var slope := Polygon2D.new()
			slope.set_meta("crest_cell",cell)
			slope.set_meta("toe_height",heights[cell]-float(placement.drop))
			slope.texture = preload("res://resources/prototypes/camp_natural_materials/cliff.png")
			slope.material = material
			var toe_a := a+displacement+Vector2(0,sin(a.x*0.071)*9)
			var toe_b := b+displacement+Vector2(0,sin(b.x*0.071)*9)
			slope.polygon = PackedVector2Array([a,b,toe_b,toe_a])
			slope.uv = PackedVector2Array([Vector2(a.x*4,0),Vector2(b.x*4,0),Vector2(b.x*4,512),Vector2(a.x*4,512)])
			slope.vertex_colors = PackedColorArray([Color(0.56,0.65,0.67,1),Color(0.56,0.65,0.67,1),Color(0.28,0.39,0.45,0.08),Color(0.28,0.39,0.45,0.08)])
			root.add_child(slope)

func _build_rear_decor(layer_name: String) -> void:
	var root := Node2D.new()
	root.name = "RearDecor_"+layer_name
	add_child(root)
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	void fragment() {
	 vec4 c = texture(TEXTURE,UV);
	 if(c.a < 0.65) discard;
	 COLOR = vec4(c.rgb*vec3(0.57,0.65,0.69),1.0);
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	for placement in data.get("rear_decor",[]):
		if placement.layer != layer_name: continue
		var sprite := Sprite2D.new()
		sprite.name = placement.id
		sprite.texture = preload("res://resources/prototypes/camp_rock_slope/slope.png")
		sprite.centered = false
		sprite.offset = Vector2(-768,-920)
		if placement.kind == "shoulder":
			sprite.texture = load("res://resources/prototypes/camp_rear_shoulder/shoulder.png")
			sprite.offset = Vector2(-768,-700)
		if placement.kind == "rubble":
			sprite.region_enabled = true
			sprite.region_rect = Rect2(750,600,750,400)
			sprite.offset = Vector2(-375,-360)
		sprite.position = flat(Vector2(placement.cell[0],placement.cell[1]))-Vector2(0,placement.height)+Vector2(0,placement.get("offset_y",0))
		sprite.scale = Vector2(-1 if placement.get("mirror",false) else 1,1)*float(placement.scale)
		sprite.material = material
		if placement.get("solid_foot",false):
			# Opaque rock bed closes transparent holes beneath the rubble cutout.
			# It stays behind terrain and does not create walkable cells.
			var bed := Polygon2D.new()
			bed.name = placement.id+"_bed"
			bed.position = sprite.position
			bed.polygon = PackedVector2Array([Vector2(-90,-95),Vector2(70,-90),Vector2(80,5),Vector2(-70,20)])
			bed.texture = preload("res://resources/prototypes/camp_natural_materials/cliff.png")
			bed.uv = PackedVector2Array([Vector2(200,200),Vector2(680,215),Vector2(710,500),Vector2(260,545)])
			bed.color = Color(0.43,0.49,0.45)
			root.add_child(bed)
		root.add_child(sprite)

func _build_stair_landings() -> void:
	# Intermediate walking height is not a missing tile: the stair has a lower bed.
	var support := Node2D.new()
	support.name = "StairLandings"
	add_child(support)
	for height in [0,48]:
		var layer = Terrain.new()
		layer.name = "LandingHeight%d" % height
		layer.position = -layer.map_to_local(Vector2i.ZERO)-Vector2(0,height)
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/prototypes/camp_natural_ground.gdshader")
		material.set_shader_parameter("paving",preload("res://resources/prototypes/camp_natural_materials/paving.png"))
		_configure_ground_boundary(material,height)
		layer.material = material
		for cell: Vector2i in stair_cells:
			if stair_cells[cell].high-48 == height:
				layer.set_cell(cell,0,layer.ATLAS[15])
		support.add_child(layer)

func _configure_ground_boundary(material: ShaderMaterial, height: int) -> void:
	# A data mask, not sampled artwork: it expands with the logical tile coordinates.
	var minimum := Vector2i(100000,100000)
	var maximum := Vector2i(-100000,-100000)
	for cell: Vector2i in heights:
		minimum = minimum.min(cell)
		maximum = maximum.max(cell)
	minimum -= Vector2i(2,2)
	maximum += Vector2i(2,2)
	var dimensions := maximum-minimum+Vector2i.ONE
	var mask := Image.create(dimensions.x,dimensions.y,false,Image.FORMAT_R8)
	mask.fill(Color.BLACK)
	for cell: Vector2i in heights:
		var covered: bool = heights[cell] == height
		if stair_cells.has(cell):
			covered = stair_cells[cell].high == height or stair_cells[cell].high-48 == height
		if covered:
			mask.set_pixel(cell.x-minimum.x,cell.y-minimum.y,Color.WHITE)
	material.set_shader_parameter("occupancy",ImageTexture.create_from_image(mask))
	material.set_shader_parameter("grid_origin",Vector2(minimum))
	material.set_shader_parameter("grid_size",Vector2(dimensions))
	material.set_shader_parameter("soil",preload("res://resources/prototypes/camp_ground_candidate/surface.png"))

func _build_mountain_support() -> void:
	# Non-walkable foundation joins the platforms into one land mass.
	# Derive it from occupied rows so map expansion also extends the mountain.
	var rows: Dictionary = {}
	for cell: Vector2i in heights:
		if not rows.has(cell.y): rows[cell.y] = Vector2i(cell.x,cell.x)
		rows[cell.y] = Vector2i(mini(rows[cell.y].x,cell.x),maxi(rows[cell.y].y,cell.x))
	for y in rows:
		for x in range(rows[y].x,rows[y].y+1): mountain_cells[Vector2i(x,y)] = true
	var walls := Node2D.new()
	add_child(walls)
	foundation = Terrain.new()
	foundation.name = "NonWalkableMountainFoot"
	foundation.position = -foundation.map_to_local(Vector2i.ZERO)+Vector2(0,48)
	foundation.modulate = Color(0.68,0.73,0.66)
	add_child(foundation)
	var rims := Node2D.new()
	add_child(rims)
	var edges: Array[Dictionary] = []
	for cell: Vector2i in mountain_cells:
		foundation.set_cell(cell,0,foundation.ATLAS[0])
		for axis in [Vector2i.RIGHT,Vector2i.DOWN]:
			if mountain_cells.has(cell+axis): continue
			var a := flat(Vector2(cell)+(Vector2(0.5,-0.5) if axis==Vector2i.RIGHT else Vector2(-0.5,0.5)))+Vector2(0,48)
			var b := flat(Vector2(cell)+Vector2(0.5,0.5))+Vector2(0,48)
			edges.append({"a":a,"b":b,"height":48})
	preload("res://scripts/prototypes/camp_mountain_cliff.gd").build(walls,edges,rims)
	walls.modulate = Color(0.7,0.75,0.68)
	rims.modulate = walls.modulate

func _build_rock_slopes() -> void:
	var shader := Shader.new()
	shader.code = """shader_type canvas_item;
	void fragment() {
		vec4 c = texture(TEXTURE, UV);
		if (c.a < 0.65) discard;
		COLOR = vec4(c.rgb*vec3(0.64,0.73,0.76), 1.0);
	}"""
	var material := ShaderMaterial.new()
	material.shader = shader
	edge_overlays = Node2D.new()
	edge_overlays.name = "EdgeOverlays"
	add_child(edge_overlays)
	for placement in data.get("edge_overlays",[]):
		var sprite := Sprite2D.new()
		sprite.name = placement.id
		sprite.texture = preload("res://resources/prototypes/camp_rock_slope/slope.png")
		sprite.centered = false
		if placement.kind == "rubble":
			sprite.region_enabled = true
			sprite.region_rect = Rect2(750,600,750,400)
			sprite.offset = Vector2(-375,-360)
		else:
			sprite.offset = Vector2(-768,-920)
		sprite.scale = Vector2.ONE*float(placement.scale)
		sprite.position = flat(Vector2(placement.cell[0],placement.cell[1]))-Vector2(0,placement.height)
		sprite.material = material
		# Foreground rock silhouettes cover nearby buildings without moving either asset.
		sprite.z_index = 1 if placement.get("occludes_buildings",false) else 0
		edge_overlays.add_child(sprite)

func can_step(a: Vector2i,b: Vector2i) -> bool:
	for cell in [a,b]:
		if stair_cells.has(cell):
			var st: Dictionary = stair_cells[cell]
			var other: Vector2i = b if cell==a else a
			return other==Vector2i(st.from[0],st.from[1]) or other==Vector2i(st.to[0],st.to[1])
	return heights[a]==heights[b]
func reset_walk() -> void:
	current = ids.get(Vector2i(data.spawn[0],data.spawn[1]),-1)
	if current<0 and not ids.is_empty(): current = ids.values()[0]
	route = PackedInt64Array()
	actor.position = graph.get_point_position(current) if current>=0 else Vector2.ZERO
func move_to_node(id: int) -> bool:
	if not graph.has_point(id) or current<0: return false
	var start := int(route[0]) if not route.is_empty() else current
	var path := graph.get_id_path(start,id)
	if path.is_empty(): return false
	if route.is_empty(): path.remove_at(0)
	route = path
	return true
func click_at(global_point: Vector2) -> void:
	var p := to_local(global_point)
	for target in targets:
		if target.visual.is_visible_in_tree() and target.visual.get_rect().has_point(target.visual.transform.affine_inverse()*p):
			var reached := move_to_node(target.node)
			feedback.emit(("前往" if reached else "当前摆放没有可达入口：")+str(target.name))
			return
	if graph.get_point_count()==0: return
	var id := graph.get_closest_point(p)
	if p.distance_to(graph.get_point_position(id))<48: move_to_node(id)
func _process(delta: float) -> void:
	if not visible: return
	if not route.is_empty():
		actor.position = actor.position.move_toward(graph.get_point_position(route[0]),110*delta)
		if actor.position.is_equal_approx(graph.get_point_position(route[0])):
			current = route[0]
			route.remove_at(0)
	route_line.clear_points()
	if not route.is_empty():
		route_line.add_point(actor.position)
		for id in route: route_line.add_point(graph.get_point_position(id))
