@tool
extends Control
signal view_changed
signal edited
signal play_status(message: String)
var play_mode := false
var actor_position := Vector2(10,27)
var route: Array[Vector2] = []
var keys: Dictionary = {}
var show_grid := false
var show_landmarks := true
var content_filter := "all"
var all_labels := false
const Lamp = preload("res://scripts/prototypes/map01_formation_lamp.gd")
var lamp_preview_states: Dictionary = {}
var lamp_times: Dictionary = {}
var lamp_tick := 0.0
var lamp_repairs: Dictionary = {}
const DECOR = preload("res://resources/prototypes/camp_decor/atlas-v2.png")
var decor_props: Dictionary = {}
const PAVING = preload("res://resources/prototypes/camp_natural_materials/paving.png")
const CLIFF = preload("res://resources/prototypes/camp_natural_materials/cliff.png")
const SOIL = preload("res://resources/prototypes/camp_ground_candidate/surface.png")
var model: RefCounted
var flat_view := false
var height := 0
var kind := "ground"
var zoom := 0.65
var pan := Vector2(650,80)
var painting := false
var erasing := false
var panning := false
var space_held := false
var initial_fit_done := false
var auto_fit := true
var hover := Vector2i(-1,-1)
const COLORS := {"ground": Color("69796d"), "road": Color("a2987b"), "rock": Color("535e65"), "stairs": Color("b3b6ad")}

func _ready() -> void:
	decor_props = JSON.parse_string(FileAccess.get_file_as_string("res://resources/prototypes/camp_decor/atlas.json")).get("props",{})
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	resized.connect(_fit_when_ready)
	visibility_changed.connect(_fit_when_ready)
	_fit_when_ready()

func _fit_when_ready() -> void:
	# The editor gives temporary tiny sizes during startup and tab layout.
	# Refit when the final container size arrives, rather than freezing that view.
	if auto_fit and is_visible_in_tree():
		_apply_auto_fit.call_deferred()

func _apply_auto_fit() -> void:
	if auto_fit: fit()

func fit() -> void:
	if play_mode or not is_visible_in_tree(): return
	if size.x <= 96 or size.y <= 96 or model == null or model.cells.is_empty(): return
	var bounds := Rect2()
	var first := true
	for cell in model.cells:
		for vertex in model.surface_polygon(cell,flat_view):
			if first:
				bounds = Rect2(vertex,Vector2.ZERO)
				first = false
			bounds = bounds.expand(vertex)
			bounds = bounds.expand(vertex+Vector2(0,20))
	if first: return
	zoom = minf((size.x-80)/maxf(bounds.size.x,1),(size.y-80)/maxf(bounds.size.y,1))
	pan = size*0.5-bounds.get_center()*zoom
	initial_fit_done = true
	auto_fit = true
	view_changed.emit()
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size), Color("171e24"))
	if model == null: return
	draw_set_transform(pan, 0, Vector2.ONE*zoom)
	if show_grid and not play_mode:
		for y in range(model.extent.y):
			for x in range(model.extent.x):
				var polygon: PackedVector2Array = model.diamond(Vector2i(x,y),0)
				polygon.append(polygon[0])
				draw_polyline(polygon, Color(0.4,0.5,0.55,0.16),1)
	var actor_drawn := false
	var actor_depth := actor_position.x+actor_position.y
	for cell in model.ordered_cells():
		if play_mode and not actor_drawn and cell.x+cell.y > actor_depth+0.5:
			_draw_actor()
			actor_drawn = true
		var item: Dictionary = model.cells[cell]
		var top: PackedVector2Array = model.surface_polygon(cell,flat_view)
		var base: PackedVector2Array = model.diamond(cell,0)
		if not flat_view:
			for side in [1,2]:
				var wall := PackedVector2Array([top[side],top[side+1],base[side+1]+Vector2(0,20),base[side]+Vector2(0,20)])
				var wall_uv := PackedVector2Array()
				for vertex in wall: wall_uv.append(vertex/256.0)
				draw_polygon(wall,PackedColorArray([Color(0.7,0.77,0.78) if side==1 else Color(0.53,0.59,0.62)]),wall_uv,CLIFF)
		var uv := PackedVector2Array()
		for offset in [Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)]:
			uv.append((Vector2(cell)+offset)/4.0)
		var texture: Texture2D = SOIL
		var tint := Color(0.65,0.76,0.7)
		if item.kind in ["road","stairs"]:
			texture = PAVING
			tint = Color(0.9,0.99,1.0)
		elif item.kind == "rock":
			texture = CLIFF
			tint = Color(0.68,0.78,0.8)
		draw_polygon(top,PackedColorArray([tint]),uv,texture)
		if show_grid and not play_mode:
			var outline := top.duplicate()
			outline.append(top[0])
			draw_polyline(outline,Color(0.15,0.2,0.22,0.45),1)
		if item.kind == "stairs":
			for step in range(1,7):
				var t := step/7.0
				draw_line(top[0].lerp(top[3],t),top[1].lerp(top[2],t),Color("37494b"),2)
				draw_line(top[0].lerp(top[3],t)+Vector2(0,-1),top[1].lerp(top[2],t)+Vector2(0,-1),Color(0.75,0.8,0.77,0.7),1)
		_draw_cell_prop(cell)
	if play_mode and not actor_drawn: _draw_actor()
	if show_landmarks:
		_draw_rest_areas()
		_draw_landmarks()
	if not play_mode and hover.x >= 0 and hover.y >= 0 and hover.x < model.extent.x and hover.y < model.extent.y:
		var outline: PackedVector2Array = model.surface_polygon(hover,flat_view) if model.cells.has(hover) else model.diamond(hover,0 if flat_view else height)
		outline.append(outline[0])
		draw_polyline(outline,Color("f0d18b"),3)
	draw_set_transform(Vector2.ZERO)

func _paint() -> void:
	model.paint(hover,height,kind,erasing)
	edited.emit()
	queue_redraw()

func set_zoom(value: float, anchor: Vector2) -> void:
	var world := (anchor-pan)/maxf(zoom,0.001)
	auto_fit = false
	zoom = clampf(value,1.0,1.6) if play_mode else clampf(value,0.05,4.0)
	pan = anchor-world*zoom
	view_changed.emit()
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMagnifyGesture:
		set_zoom(zoom*event.factor,event.position)
		accept_event()
		return
	if event is InputEventPanGesture:
		if event.ctrl_pressed or event.meta_pressed:
			set_zoom(zoom*exp(-event.delta.y*0.08),event.position)
		elif not play_mode:
			auto_fit = false
			pan -= event.delta*24.0
			queue_redraw()
		accept_event()
		return
	if not play_mode and event is InputEventKey and event.physical_keycode == KEY_SPACE:
		space_held = event.pressed
		if not space_held: panning = false
		accept_event()
		return
	if play_mode:
		if event is InputEventKey:
			var code: int = event.physical_keycode
			if code == KEY_E and event.pressed and not event.echo:
				var placement: Dictionary = model.nearby_placement(actor_position)
				if not placement.is_empty():
					var object: Dictionary = model.objects.get(placement.objectId,{})
					if str(placement.objectId).begins_with("m1_event_lamp_"):
						var id: String = placement.objectId
						lamp_preview_states[id] = "" if lamp_preview_states.get(id,"") == "LAMP_REPAIRED" else "LAMP_REPAIRED"
						lamp_times[id] = 0.0
						if lamp_preview_states[id] == "LAMP_REPAIRED": lamp_repairs[id] = 0.0
						else: lamp_repairs.erase(id)
						play_status.emit("阵灯候选预览："+("激活" if lamp_preview_states[id] == "LAMP_REPAIRED" else "残破")+"；仅切换此灯，不写游戏状态")
						queue_redraw()
						accept_event()
						return
					var note := "（占位查看，未执行正式互动）"
					if object.get("kind","") == "dungeon": note = "暗道副本 · 首通1件法器；装备结算已配置，试玩不发奖"
					play_status.emit(str(object.get("title",placement.objectId))+"："+str(object.get("description",""))+" · "+note)
				accept_event()
				return
			if event.pressed: keys[code] = true
			else: keys.erase(code)
			accept_event()
		if event is InputEventMouseButton and event.pressed:
			grab_focus()
			if event.button_index == MOUSE_BUTTON_LEFT:
				var target: Vector2i = model.pick((event.position-pan)/zoom)
				route = model.route_between(model.cell_at(actor_position),target)
				if not route.is_empty(): route.push_front(Vector2(model.cell_at(actor_position)))
				play_status.emit("正在寻路" if not route.is_empty() else "目标不可达")
			if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
				set_zoom(zoom*(1.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.1),event.position)
			accept_event()
		return
	if event is InputEventMouseButton:
		grab_focus()
		if event.button_index == MOUSE_BUTTON_MIDDLE: panning = event.pressed
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			set_zoom(zoom*(1.12 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 1.0/1.12),event.position)
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if event.button_index == MOUSE_BUTTON_LEFT and (space_held or panning):
				panning = event.pressed
				painting = false
				accept_event()
				return
			painting = event.pressed
			erasing = event.button_index == MOUSE_BUTTON_RIGHT
			if painting:
				model.checkpoint()
				hover = model.pick((event.position-pan)/zoom,flat_view)
				_paint()
		accept_event()
	if event is InputEventMouseMotion:
		if panning:
			auto_fit = false
			pan += event.relative
		var next: Vector2i = model.pick((event.position-pan)/zoom,flat_view)
		if next != hover:
			hover = next
			if painting: _paint()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		painting = false
		panning = false
		keys.clear()
		space_held = false

func set_play_mode(enabled: bool) -> void:
	play_mode = enabled
	painting = false
	keys.clear()
	route.clear()
	if enabled:
		flat_view = false
		actor_position = model.spawn
		if not model.can_stand(actor_position):
			play_mode = false
			play_status.emit("出生位置被删除或阻挡，请恢复入口")
			return
		zoom = 1.25
		view_changed.emit()
		grab_focus()
		play_status.emit("试玩：WASD / 方向键行走，点击寻路；滚轮有限缩放")
	else:
		fit()
		play_status.emit("已返回地形编辑")
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	for id in lamp_times: lamp_times[id] = fmod(float(lamp_times[id])+delta,1.0)
	for id in lamp_repairs.keys():
		lamp_repairs[id] = float(lamp_repairs[id])+delta
		if float(lamp_repairs[id]) >= Lamp.REPAIR_SECONDS:
			lamp_times[id] = fmod(float(lamp_repairs[id])-Lamp.REPAIR_SECONDS,1.0)
			lamp_repairs.erase(id)
	lamp_tick += delta
	if lamp_tick >= 0.125:
		lamp_tick = fmod(lamp_tick,0.125)
		queue_redraw()
	if not play_mode: return
	if not has_focus(): keys.clear()
	var direction := Vector2(float(keys.has(KEY_D) or keys.has(KEY_RIGHT))-float(keys.has(KEY_A) or keys.has(KEY_LEFT)),float(keys.has(KEY_S) or keys.has(KEY_DOWN))-float(keys.has(KEY_W) or keys.has(KEY_UP)))
	var movement := Vector2.ZERO
	if direction != Vector2.ZERO:
		route.clear()
		direction = direction.normalized()*150.0*minf(delta,0.05)
		movement = Vector2(direction.x/96.0+direction.y/48.0,direction.y/48.0-direction.x/96.0)
	elif not route.is_empty():
		var difference: Vector2 = route[0]-actor_position
		movement = difference.limit_length(2.0*minf(delta,0.05))
		if difference.length() < 0.02: route.pop_front()
	var next: Vector2 = model.move_actor(actor_position,movement)
	if movement.length()>0.001 and next.distance_to(actor_position)<0.0001: route.clear()
	actor_position = next
	var foot: Vector2 = model.surface(actor_position,model.cell_at(actor_position))
	pan = size*0.5-foot*zoom
	queue_redraw()

func _draw_actor() -> void:
	var foot: Vector2 = model.surface(actor_position,model.cell_at(actor_position))
	# Neutral scale/footprint marker; character art is deliberately not approved here.
	draw_circle(foot,9,Color(0.05,0.09,0.1,0.5))
	draw_circle(foot,4,Color("b6d1ac"))
	draw_colored_polygon(PackedVector2Array([foot+Vector2(-7,-7),foot+Vector2(-5,-25),foot+Vector2(5,-25),foot+Vector2(8,-7)]),Color("748d91"))
	draw_circle(foot+Vector2(0,-30),5,Color("c5b99e"))
	draw_line(foot+Vector2(-6,-8),foot+Vector2(7,-34),Color("d0ccae"),2)

func _draw_landmarks() -> void:
	var font := ThemeDB.fallback_font
	var nearby: Dictionary = model.nearby_placement(actor_position) if play_mode else {}
	for placement in model.placements:
		var cell := Vector2i(placement.cell[0],placement.cell[1])
		if not model.cells.has(cell): continue
		var foot: Vector2 = model.surface(Vector2(cell),cell) if not flat_view else model.point(cell,0)
		var object: Dictionary = model.objects.get(placement.objectId,{})
		var kind_name: String = str(object.get("kind",""))
		var category := "story"
		if kind_name == "resource": category = "resource"
		elif kind_name in ["enemy_group","elite_enemy","boss"]: category = "enemy"
		if content_filter != "all" and content_filter != category: continue
		var tint := Color("ddc58a") if placement.route == "main" else Color("83beb1")
		if category == "resource": tint = Color("91c884")
		elif category == "enemy": tint = Color("e28f81")
		var name: String = str(object.get("title",placement.objectId))
		if placement.objectId == "m1_dungeon_tunnel": name = "暗道 · 装备副本"
		if not placement.has("visual"):
			draw_circle(foot,10,tint.darkened(0.55))
			draw_arc(foot,11,0,TAU,20,tint,2)
			draw_line(foot,foot+Vector2(0,-30),tint,3)
			draw_colored_polygon(PackedVector2Array([foot+Vector2(0,-34),foot+Vector2(7,-27),foot+Vector2(0,-20),foot+Vector2(-7,-27)]),tint)
		var is_near: bool = not nearby.is_empty() and nearby.objectId == placement.objectId
		if not all_labels and zoom < 0.75 and category != "story" and not is_near and content_filter == "all": continue
		var label_position := (foot+Vector2(0,-88 if placement.has("visual") else -42))*zoom+pan
		draw_set_transform(label_position)
		var width := font.get_string_size(name,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x
		draw_style_box(_label_box(),Rect2(Vector2(-width/2-5,-17),Vector2(width+10,22)))
		draw_string(font,Vector2(-width/2,0),name,HORIZONTAL_ALIGNMENT_LEFT,-1,14,tint)
		if not nearby.is_empty() and nearby.objectId == placement.objectId:
			draw_string(font,Vector2(-28,20),"E 查看",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color.WHITE)
		draw_set_transform(pan,0,Vector2.ONE*zoom)

func _label_box() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06,0.09,0.11,0.88)
	style.set_corner_radius_all(3)
	return style

func _draw_rest_areas() -> void:
	if content_filter not in ["all","rest"]: return
	for area in model.rest_areas:
		var center := Vector2(area.cell[0],area.cell[1])
		var cell: Vector2i = model.cell_at(center)
		if not model.walkable(cell): continue
		var polygon := PackedVector2Array()
		var level: float = model.elevation(center,cell)
		for index in range(33):
			var angle := index*TAU/32.0
			var uv := center+Vector2(cos(angle),sin(angle))*float(area.radius)
			polygon.append(Vector2((uv.x-uv.y)*48,(uv.x+uv.y)*24-(0 if flat_view else level)))
		draw_colored_polygon(polygon,Color(0.4,0.68,0.85,0.16))
		draw_polyline(polygon,Color("91c4d9"),2)
		var foot: Vector2 = model.surface(center,cell) if not flat_view else model.point(cell,0)
		draw_set_transform(foot*zoom+pan)
		draw_string(ThemeDB.fallback_font,Vector2(0,18),area.label,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("a5d6e8"))
		draw_set_transform(pan,0,Vector2.ONE*zoom)

func _draw_cell_prop(cell: Vector2i) -> void:
	for placement in model.placements:
		if Vector2i(placement.cell[0],placement.cell[1]) != cell: continue
		var visual: Dictionary = placement.get("visual",{})
		if visual.get("type","") != "camp_decor": continue
		if visual.get("prop","") == "formation_lamp":
			var id: String = placement.objectId
			if not lamp_times.has(id): lamp_times[id] = 0.0
			var animation_name := Lamp.animation_for_state(str(lamp_preview_states.get(id,"")))
			var frame_index := int(float(lamp_times[id])*8.0)%8
			if lamp_repairs.has(id):
				animation_name = &"repair"
				frame_index = mini(int(float(lamp_repairs[id])*8.0),15)
			var frame: Texture2D = Lamp.FRAMES.get_frame_texture(animation_name,frame_index)
			var factor := float(visual.get("displayWidth",54))/224.0
			var foot: Vector2 = model.surface(Vector2(cell),cell) if not flat_view else model.point(cell,0)
			draw_texture_rect(frame,Rect2(foot-Vector2(128,350)*factor,Vector2(256,384)*factor),false)
			continue
		var prop: Dictionary = decor_props.get(visual.get("prop",""),{})
		if prop.is_empty(): continue
		var region: Array = prop.region
		var anchor: Array = prop.anchor
		var scale_factor := float(visual.get("displayWidth",54))/float(region[2])
		var foot: Vector2 = model.surface(Vector2(cell),cell) if not flat_view else model.point(cell,0)
		var rect := Rect2(foot-Vector2(anchor[0],anchor[1])*scale_factor,Vector2(region[2],region[3])*scale_factor)
		draw_texture_rect_region(DECOR,rect,Rect2(region[0],region[1],region[2],region[3]),Color(0.9,0.95,0.92))
