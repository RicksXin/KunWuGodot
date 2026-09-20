extends Node2D
signal feedback(text: String)
## Approved artwork shown at its original anchor, never repeated across the floor.
const ART = preload("res://assets/prototypes/camp_cliff_corner/terrace_continuous.png")
const ORIGINAL_ART = preload("res://assets/prototypes/camp_cliff_corner/terrace_L.png")
var use_original := false
const ANCHOR := Vector2(220,64)
const CELLS := [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,1),Vector2i(0,2)]
var show_grid := false
var show_height := false
var extended := false
var sprite: Sprite2D
var stairs: Node2D
var procedural_stairs: Node2D
var stair_art: Sprite2D
var lower_ground: TileMapLayer
var extended_texture: ImageTexture
var navigation := AStar2D.new()
var actor: Polygon2D
var route_display: Line2D
var route := PackedVector2Array()
var destination_id := 0
const EXTRA_HEIGHT := 14
const STAIR_DROP := 48
const STAIR_A := Vector2(-92,78)
const STAIR_B := Vector2(-52,58)
const STAIR_RUN := Vector2(56,28)

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite = Sprite2D.new()
	sprite.texture = ART
	sprite.centered = false
	sprite.show_behind_parent = true
	sprite.position = -ANCHOR
	add_child(sprite)
	stairs = Node2D.new()
	add_child(stairs)
	var a := STAIR_A + STAIR_RUN + Vector2(0,STAIR_DROP)
	var b := STAIR_B + STAIR_RUN + Vector2(0,STAIR_DROP)
	# Reuse the approved ground atlas at its original scale for the lower landing.
	lower_ground = preload("res://scripts/prototypes/camp_dual_terrain.gd").new()
	lower_ground.set_cell(Vector2i.ZERO,0,lower_ground.ATLAS[0])
	lower_ground.position = (a+b)*0.5 + Vector2(16,8) - lower_ground.map_to_local(Vector2i.ZERO)
	stairs.add_child(lower_ground)
	procedural_stairs = Node2D.new()
	stairs.add_child(procedural_stairs)
	preload("res://scripts/prototypes/camp_stonework.gd").stairs(procedural_stairs,STAIR_A,STAIR_B,b,a)
	procedural_stairs.visible = false
	stair_art = Sprite2D.new()
	stair_art.texture = preload("res://assets/prototypes/camp_stairs/stairs.png")
	stair_art.centered = false
	stair_art.position = Vector2(-108,42)
	stairs.add_child(stair_art)
	stairs.visible = false
	_build_navigation()
	route_display = Line2D.new()
	route_display.width = 1
	route_display.default_color = Color(0.89,0.74,0.4,0.7)
	route_display.z_index = 2
	add_child(route_display)
	actor = Polygon2D.new()
	actor.polygon = PackedVector2Array([Vector2(-5,0),Vector2(0,-9),Vector2(5,0),Vector2(0,3)])
	actor.color = Color("f0c76c")
	actor.z_index = 3
	actor.visible = false
	add_child(actor)

func _build_navigation() -> void:
	for i in CELLS.size(): navigation.add_point(i,center(CELLS[i]))
	for i in CELLS.size():
		for j in range(i+1,CELLS.size()):
			var delta: Vector2i = CELLS[i]-CELLS[j]
			if absi(delta.x)+absi(delta.y)==1: navigation.connect_points(i,j)
	var top := (STAIR_A+STAIR_B)*0.5
	for i in range(9):
		navigation.add_point(5+i,top+(STAIR_RUN+Vector2(0,STAIR_DROP))*float(i)/8.0)
		if i>0: navigation.connect_points(4+i,5+i)
	navigation.connect_points(4,5)
	navigation.add_point(14,navigation.get_point_position(13)+Vector2(16,8))
	navigation.connect_points(13,14)

func move_to(id: int) -> void:
	if not extended or not navigation.has_point(id): return
	# Redirect through the next graph point, never directly from a stair midpoint.
	var start := navigation.get_closest_point(route[0]) if not route.is_empty() else destination_id
	route = navigation.get_point_path(start,id)
	destination_id = id
	feedback.emit("经台阶前往下层落脚点" if id==14 else "沿台地与台阶行走")

func click_at(screen_point: Vector2) -> void:
	if not extended:
		feedback.emit("先开启接台阶，再点击台地或下层落脚点行走")
		return
	var p := to_local(screen_point)
	var landing := navigation.get_point_position(14)
	if absf(p.x-landing.x)/64.0+absf(p.y-landing.y)/32.0<=1.0:
		move_to(14)
		return
	for i in CELLS.size():
		var delta := p-center(CELLS[i])
		if absf(delta.x)/64.0+absf(delta.y)/32.0<=1.0:
			move_to(i)
			return
	feedback.emit("此处是岩壁或空地；请点台地顶面或台阶下的落脚点")

func _process(delta: float) -> void:
	if route.is_empty(): return
	actor.position = actor.position.move_toward(route[0],delta*75.0)
	if actor.position.is_equal_approx(route[0]): route.remove_at(0)
	route_display.clear_points()
	if not route.is_empty():
		route_display.add_point(actor.position)
		for point in route: route_display.add_point(point)

static func cut_row(x: int) -> int:
	# Nominal front boundary of the L, from authored cell geometry.
	var top: float
	if x < 92: top = 128.0 + (x-28)*0.5
	elif x < 220: top = 160.0 - (x-92)*0.5
	elif x < 348: top = 96.0 + (x-220)*0.5
	else: top = 160.0 - (x-348)*0.5
	return int(round(top))+24

static func extend_wall(source: Image) -> Image:
	# Insert a native-pixel rock band. Upper art is unchanged; the foot moves down.
	var result := Image.create(source.get_width(),source.get_height(),false,Image.FORMAT_RGBA8)
	for x in source.get_width():
		var cut := cut_row(x)
		for y in source.get_height():
			var source_y := y
			if y >= cut: source_y = y-EXTRA_HEIGHT
			result.set_pixel(x,y,source.get_pixel(x,source_y))
	return result

func set_extended(on: bool) -> void:
	if on and use_original and extended_texture == null:
		extended_texture = ImageTexture.create_from_image(extend_wall(ORIGINAL_ART.get_image()))
	extended = on
	sprite.texture = (extended_texture if on else ORIGINAL_ART) if use_original else ART
	stairs.visible = on
	actor.visible = on
	route.clear()
	route_display.clear_points()
	destination_id = 0
	actor.position = center(CELLS[0])
	queue_redraw()

func set_original(on: bool) -> void:
	use_original = on
	set_extended(extended)

func set_procedural_stairs(on: bool) -> void:
	procedural_stairs.visible = on
	stair_art.visible = not on

func center(cell: Vector2i) -> Vector2:
	return Vector2((cell.x-cell.y)*64,(cell.x+cell.y)*32)

func _draw() -> void:
	if show_grid:
		for cell in CELLS:
			var c := center(cell)
			draw_polyline(PackedVector2Array([c+Vector2(0,-32),c+Vector2(64,0),c+Vector2(0,32),c+Vector2(-64,0),c+Vector2(0,-32)]),Color(0.6,0.85,1,0.65),1.0)
			draw_circle(c,2,Color("e9bc65"))
	if show_height:
		# Nominal top edge and a 48-pixel lower level, not inferred collision.
		var edge := PackedVector2Array([Vector2(-192,64),Vector2(-128,96),Vector2(0,32),Vector2(128,96),Vector2(192,64)])
		draw_polyline(edge,Color("e9bc65"),1.0)
		for i in edge.size(): edge[i] += Vector2(0,48)
		draw_polyline(edge,Color("6cc5dc"),1.0)
		for c in [Vector2(-128,96),Vector2(128,96)]:
			draw_line(c,c+Vector2(0,48),Color("6cc5dc"),1.0)
