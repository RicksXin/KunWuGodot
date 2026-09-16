extends Node2D

const Navigation = preload("res://scripts/maps/map_navigation.gd")
const Actor = preload("res://scripts/maps/map_actor.gd")
const DATA_PATH := "res://data/maps/map_01.json"
const VIEW := Vector2i(817, 375)
const PATH_HOLD_SECONDS := 0.45
const PATH_HOLD_SLOP := 12.0
const DEFAULT_ZOOM := 1.2
const NORMAL_MIN_ZOOM := 1.0
const NORMAL_MAX_ZOOM := 1.5
const DEBUG_MIN_ZOOM := 0.14
const DEBUG_MAX_ZOOM := 2.2
const MAP_VISIBLE_SIZE := Vector2(817, 287)
const ACTOR_VISUAL_SCALE := 0.65

var navigation: RefCounted
var expedition_ui: Control
var return_platform: Sprite2D
var fog: Node2D
var object_nodes: Dictionary = {}
var proximity_object: Dictionary = {}
var interact_button: Button
var stats_label: Label
var definition: Dictionary
var actor: Node2D
var camera: Camera2D
var route := PackedVector2Array()
var path_hold_pointer := -2
var path_hold_elapsed := 0.0
var path_hold_screen := Vector2.ZERO
var path_hold_world := Vector2.ZERO
var path_touches: Dictionary = {}
var show_routes := false
var zoom_level := DEFAULT_ZOOM
var touch_direction := Vector2.ZERO
var held_directions: Dictionary = {}
var location_label: Label
var hint_label: Label
var zoom_label: Label
var hint_time := 0.0
var visited: Dictionary = {}
var previous_content := Vector2i.ZERO
var previous_size := Vector2i.ZERO
var previous_position := Vector2i.ZERO
var previous_orientation := DisplayServer.SCREEN_PORTRAIT
var returning := false
var edit_walkable := false
var edit_erase := false
var edit_radius := 28.0
var show_map_annotations := false
var annotation_overlay: Node2D

func _enter_tree() -> void:
	previous_content = get_window().content_scale_size
	get_window().content_scale_size = VIEW
	if OS.has_feature("mobile"):
		previous_orientation = DisplayServer.screen_get_orientation()
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	elif DisplayServer.get_name() != "headless":
		previous_size = DisplayServer.window_get_size()
		previous_position = DisplayServer.window_get_position()
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
			var usable := DisplayServer.screen_get_usable_rect()
			var scale_factor := minf(1.5, minf((usable.size.x - 40.0) / VIEW.x, (usable.size.y - 40.0) / VIEW.y))
			var target := Vector2i(Vector2(VIEW) * scale_factor)
			DisplayServer.window_set_size(target)
			DisplayServer.window_set_position(usable.position + (usable.size - target) / 2)

func _exit_tree() -> void:
	Game.save_profile()
	get_window().content_scale_size = previous_content
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(previous_orientation)
	elif DisplayServer.get_name() != "headless" and previous_size != Vector2i.ZERO:
		DisplayServer.window_set_size(previous_size)
		DisplayServer.window_set_position(previous_position)

func _ready() -> void:
	if Game.profile.get("expedition") == null:
		get_tree().change_scene_to_file("res://scenes/camp.tscn")
		return
	definition = Game.get_map_definition()
	navigation = Game.get_world_navigation()
	Game.ensure_world_position()
	var layout: Node2D = load("res://scenes/maps/map_01.tscn").instantiate()
	add_child(layout)
	var background: Sprite2D = layout.get_node("HDBackground")
	background.centered = false
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background.scale = navigation.world_size / background.texture.get_size()
	background.z_index = -10
	if OS.is_debug_build():
		annotation_overlay = Node2D.new()
		annotation_overlay.set_script(load("res://scripts/maps/map_annotations_overlay.gd"))
		annotation_overlay.call("setup", background)
		annotation_overlay.visible = false
		add_child(annotation_overlay)
	actor = Node2D.new()
	actor.name = "Traveler"
	actor.set_script(Actor)
	actor.scale = Vector2.ONE * ACTOR_VISUAL_SCALE
	actor.position = Game.expedition_world_position()
	actor.z_index = 2
	add_child(actor)
	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.position = actor.position
	camera.zoom = Vector2.ONE * zoom_level
	add_child(camera)
	_build_hud()
	_build_expedition()
	_follow_camera(1.0, true)
	set_process_unhandled_input(true)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)
	var hud := Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	var top := KWUI.panel(hud, Rect2(0,0,817,44), Color("#101c20e8"), Color("#56605b"))
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	location_label = KWUI.label(hud,"万修古道 · 山脚",Rect2(18,6,230,30),16,Color("#e2dcc7"))
	var routes_button := KWUI.button(hud,"路线",Rect2(544,6,62,30),12)
	routes_button.name = "ToggleRoutes"
	routes_button.pressed.connect(func(): show_routes = not show_routes; queue_redraw())
	if OS.is_debug_build():
		var edit := KWUI.button(hud,"编辑道路",Rect2(474,6,66,30),12)
		edit.name = "ToggleWalkableEditor"
		edit.pressed.connect(func(): edit_walkable = not edit_walkable; _hint("编辑模式：Shift 拖拽禁行，普通拖拽恢复；红区不可覆盖" if edit_walkable else "已退出道路编辑") ; queue_redraw())
		var annotations := KWUI.button(hud, "碰撞层", Rect2(334,6,66,30), 12)
		annotations.name = "ToggleMapAnnotations"
		annotations.pressed.connect(func(): show_map_annotations = not show_map_annotations; annotation_overlay.visible = show_map_annotations; _hint("已显示高清碰撞/调节层" if show_map_annotations else "已隐藏高清碰撞/调节层"))
		var save_edit := KWUI.button(hud,"保存",Rect2(404,6,66,30),12)
		save_edit.name = "SaveWalkableEditor"
		save_edit.pressed.connect(_save_walkable_edit)
	var rest := KWUI.button(hud,"休整",Rect2(615,6,90,30),12)
	rest.pressed.connect(func(): expedition_ui.call("_open_rest"))
	var back := KWUI.button(hud,"归营",Rect2(714,6,90,30),12)
	back.name = "ReturnToCamp"
	back.pressed.connect(func(): expedition_ui.call("request_return"))
	var bottom := KWUI.panel(hud,Rect2(0,331,817,44),Color("#101c20e8"),Color("#56605b"))
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label = KWUI.label(hud,"WASD / 方向键行走 · 长按古道寻路",Rect2(16,339,398,26),12,Color("#d4d6c5"))
	for index in 4:
		var direction: Vector2 = [Vector2.LEFT,Vector2.UP,Vector2.DOWN,Vector2.RIGHT][index]
		var button := KWUI.button(hud,["←","↑","↓","→"][index],Rect2(421 + index * 42,336,38,33),16)
		button.focus_mode = Control.FOCUS_NONE
		button.button_down.connect(func(): held_directions[index] = direction)
		button.button_up.connect(func(): held_directions.erase(index))
	var minus := KWUI.button(hud,"−",Rect2(623,337,32,30),16)
	minus.pressed.connect(func(): _set_zoom(zoom_level - 0.15))
	zoom_label = KWUI.label(hud,"%d%%" % roundi(zoom_level * 100),Rect2(660,339,58,26),12,Color("#d4d6c5"),HORIZONTAL_ALIGNMENT_CENTER)
	var plus := KWUI.button(hud,"+",Rect2(724,337,32,30),16)
	plus.pressed.connect(func(): _set_zoom(zoom_level + 0.15))
	var center := KWUI.button(hud,"◎",Rect2(764,337,38,30),16)
	center.pressed.connect(func(): _follow_camera(1.0,true))
	for label in [location_label,hint_label,zoom_label]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_cancel_path_hold()
		path_touches.clear()
		held_directions.clear()
		route.clear()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(actor):
		return
	if expedition_ui.call("_map_input_blocked") or Game.profile.get("expedition") == null:
		actor.set("walking", false)
		return
	var direction := Input.get_vector("move_left","move_right","move_up","move_down")
	for held in held_directions.values():
		direction += held
	direction = direction.limit_length()
	var old_position := actor.position
	var distance := float(definition["speed"]) * minf(delta,0.1)
	if direction.length_squared() > 0.01:
		route.clear()
		actor.position = navigation.move(actor.position,direction * distance)
	elif not route.is_empty():
		var target := route[0]
		var offset := (target - actor.position).limit_length(distance)
		actor.position = navigation.move(actor.position,offset)
		if actor.position.distance_to(target) < 1.0:
			route.remove_at(0)
		elif actor.position.distance_to(old_position) < 0.001:
			route.clear()
			_hint("前方无法通行，请选择其他古道。")
	var candidate := actor.position
	actor.position = old_position
	var result: Dictionary = Game.move_world(candidate - old_position)
	if result.get("wiped", false):
		Game._finish_expedition(true)
		get_tree().change_scene_to_file("res://scenes/camp.tscn")
		return
	actor.position = Game.expedition_world_position()
	var moved := actor.position - old_position
	actor.set("walking",moved.length_squared() > 0.001)
	if moved.length_squared() > 0.001:
		actor.set("facing",moved.normalized())
		queue_redraw()
	_follow_camera(delta)
	hint_time = maxf(0,hint_time - delta)
	_update_landmarks()
	refresh_state()

func _follow_camera(delta: float, instant := false) -> void:
	# Reserve the top/bottom HUD; center any axis smaller than the visible area.
	var half_view := MAP_VISIBLE_SIZE / zoom_level / 2.0
	var target := actor.position
	for axis in 2:
		if navigation.world_size[axis] <= half_view[axis] * 2.0:
			target[axis] = navigation.world_size[axis] / 2.0
		else:
			target[axis] = clampf(target[axis],half_view[axis],navigation.world_size[axis] - half_view[axis])
	camera.position = target if instant else camera.position.lerp(target,1.0 - exp(-9.0 * delta))
	camera.force_update_scroll()

func _set_zoom(value: float) -> void:
	_cancel_path_hold()
	var minimum := DEBUG_MIN_ZOOM if OS.is_debug_build() else NORMAL_MIN_ZOOM
	var maximum := DEBUG_MAX_ZOOM if OS.is_debug_build() else NORMAL_MAX_ZOOM
	zoom_level = clampf(value,minimum,maximum)
	camera.zoom = Vector2.ONE * zoom_level
	zoom_label.text = "%d%%" % roundi(zoom_level * 100)
	_follow_camera(1.0,true)

# Observe cancellation before GUI consumption, so release over HUD cannot leave a hold armed.
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: path_touches[event.index] = true
		else: path_touches.erase(event.index)
	if path_hold_pointer == -2: return
	if event is InputEventMouseButton and event.device != -1:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			_cancel_path_hold()
	elif event is InputEventMouseMotion and path_hold_pointer == -1:
		if event.position.distance_to(path_hold_screen) > PATH_HOLD_SLOP:
			_cancel_path_hold()
	elif event is InputEventScreenTouch:
		if event.index != path_hold_pointer or not event.pressed or event.canceled:
			_cancel_path_hold()
	elif event is InputEventScreenDrag and event.index == path_hold_pointer:
		if event.position.distance_to(path_hold_screen) > PATH_HOLD_SLOP:
			_cancel_path_hold()

func _begin_path_hold(pointer: int, screen: Vector2) -> void:
	if path_touches.size() > 1: return
	if path_hold_pointer != -2:
		_cancel_path_hold()
		return
	path_hold_pointer = pointer
	path_hold_elapsed = 0.0
	path_hold_screen = screen
	# Capture the world target now: camera following during the hold must not move it.
	path_hold_world = get_canvas_transform().affine_inverse() * screen

func _cancel_path_hold() -> void:
	path_hold_pointer = -2
	path_hold_elapsed = 0.0

func _process(delta: float) -> void:
	_update_actor_occlusion(delta)
	if path_hold_pointer == -2: return
	if not is_instance_valid(expedition_ui) or expedition_ui.call("_map_input_blocked") or edit_walkable or not held_directions.is_empty() or Input.get_vector("move_left","move_right","move_up","move_down").length_squared() > 0.01:
		_cancel_path_hold()
		return
	path_hold_elapsed += delta
	if path_hold_elapsed >= PATH_HOLD_SECONDS:
		var target := path_hold_world
		_cancel_path_hold()
		_request_path(target)

func _unhandled_input(event: InputEvent) -> void:
	if not is_instance_valid(expedition_ui) or expedition_ui.call("_map_input_blocked"):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			expedition_ui.call("request_return")
		elif event.keycode == KEY_TAB:
			show_routes = not show_routes
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom_level + 0.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom_level - 0.1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.device != -1:
				if edit_walkable:
					_edit_or_path(get_global_mouse_position(), event.shift_pressed)
				else:
					_begin_path_hold(-1, event.position)
	elif event is InputEventMouseMotion and edit_walkable and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		navigation.paint(get_global_mouse_position(), edit_radius, Input.is_key_pressed(KEY_SHIFT)); route.clear(); queue_redraw()
	elif event is InputEventScreenTouch and event.pressed and not event.canceled:
		_begin_path_hold(event.index, event.position)

func _edit_or_path(target: Vector2, erase := false) -> void:
	if edit_walkable and OS.is_debug_build():
		navigation.paint(target, edit_radius, erase)
		route.clear()
		_hint("已编辑：Shift 禁行，普通点击恢复原始通行范围")
		queue_redraw()
	else:
		_request_path(target)

func _save_walkable_edit() -> void:
	var file := FileAccess.open("user://map01_debug_restrictions.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(navigation.painted_walkable))
		_hint("已保存 Debug 可行走区域")

func _request_path(target: Vector2) -> void:
	route = navigation.path(actor.position,target)
	if route.is_empty():
		_hint("这里是山岩或断崖，请长按石路。")
	else:
		_hint("正在沿古道前行 · 按方向键可接管")
	queue_redraw()

func _hint(message: String) -> void:
	hint_label.text = message
	hint_time = 3.0

func _update_landmarks() -> void:
	var closest: Dictionary = {}
	var nearest := INF
	for landmark in definition["landmarks"]:
		var distance := actor.position.distance_to(Navigation.point(landmark["point"]))
		if distance < nearest:
			nearest = distance
			closest = landmark
	if nearest < 85:
		location_label.text = "万修古道 · " + str(closest["name"])
		if not visited.has(closest["name"]):
			visited[closest["name"]] = true
			_hint(str(closest["hint"]))
	else:
		location_label.text = "万修古道 · 山间石径"
	if hint_time <= 0:
		hint_label.text = "WASD / 方向键行走 · 长按古道寻路"

func _draw() -> void:
	if not is_instance_valid(actor):
		return
	if show_routes:
		# Show the same grid used by click navigation, not the retired corridor sketch.
		for y in navigation.graph.region.size.y:
			var start := -1
			for x in range(navigation.graph.region.size.x + 1):
				var walkable: bool = x < navigation.graph.region.size.x and not navigation.graph.is_point_solid(Vector2i(x, y))
				if walkable and start < 0:
					start = x
				elif not walkable and start >= 0:
					draw_rect(Rect2(Vector2(start - 0.5, y - 0.5) * navigation.step, Vector2(x - start, 1) * navigation.step), Color(0.4, 0.85, 0.7, 0.22))
					start = -1
	if not route.is_empty():
		var points := PackedVector2Array([actor.position])
		points.append_array(route)
		draw_polyline(points,Color(0.79,0.82,0.64,0.5),1.3,true)
		draw_arc(route[-1],7,0,TAU,24,Color("#d5d6ac"),1.4,true)

func _build_expedition() -> void:
	return_platform = Sprite2D.new()
	return_platform.set_script(load("res://scripts/maps/return_platform.gd"))
	return_platform.call("setup",definition.returnPoint)
	add_child(return_platform)
	fog = Node2D.new()
	fog.set_script(load("res://scripts/maps/map_fog.gd"))
	fog.set("definition", definition)
	fog.z_index = 8
	add_child(fog)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	expedition_ui = Control.new()
	expedition_ui.set_script(load("res://scripts/scenes/expedition_ui.gd"))
	expedition_ui.set("world",self)
	expedition_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(expedition_ui)
	stats_label = KWUI.label(expedition_ui,"",Rect2(12,47,300,22),11,Color("#e2dcc7"))
	stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pack := KWUI.button(expedition_ui,"背包",Rect2(714,48,90,28),12)
	pack.pressed.connect(func(): expedition_ui.call("_open_backpack"))
	interact_button = KWUI.button(expedition_ui,"互动",Rect2(312,286,192,36),12)
	interact_button.pressed.connect(_interact)
	for object in definition.objects:
		var host := Node2D.new()
		host.position = Vector2(object.x,object.y)
		host.z_index = 5
		var texture_path: String = definition.visual.markerTextures.get(object.kind, definition.visual.markerTextures.get("resource", ""))
		var sprite := Sprite2D.new()
		sprite.texture = load(texture_path)
		sprite.scale = Vector2.ONE * (22.0 / maxf(sprite.texture.get_width(),sprite.texture.get_height()))
		host.add_child(sprite)
		add_child(host)
		object_nodes[object.id] = host
		for endpoint in object.get("activationPoints",[]):
			var extra := sprite.duplicate() as Sprite2D
			extra.position = Vector2(endpoint[0],endpoint[1])
			extra.z_index = 5
			add_child(extra)
	refresh_state()

func refresh_state() -> void:
	if not is_instance_valid(stats_label) or Game.profile.get("expedition") == null: return
	var expedition: Dictionary = Game.profile.expedition
	stats_label.text = "灵粮 %d · 休整 %d · WASD行走" % [expedition.remainingGrain, expedition.restUsesRemaining]
	proximity_object = {}
	var nearest := INF
	for object in definition.objects:
		var point := Vector2(object.x,object.y)
		var completed := bool(Game.profile.completedMapObjects.get(Game.map_object_key("map_01",object.id),false))
		object_nodes[object.id].visible = Game.is_revealed(int(point.x),int(point.y)) and not completed
		var targets: Array = [[object.x,object.y]] + object.get("activationPoints",[])
		for target in targets:
			var at := Vector2(target[0],target[1])
			var distance := actor.position.distance_to(at)
			if not completed and distance < float(object.get("interactionRadius",24)) and distance < nearest and navigation.segment_clear(actor.position,at):
				nearest = distance
				proximity_object = object

	if actor.position.distance_to(return_platform.position) <= float(definition.returnPoint.radius):
		proximity_object = {"id":"__return_camp__","title":"归营阵 · 返回营地"}
	interact_button.visible = not proximity_object.is_empty() and not expedition_ui.call("_map_input_blocked")
	if interact_button.visible: interact_button.text = str(proximity_object.get("title","互动"))
	fog.queue_redraw()

func _interact() -> void:
	if proximity_object.is_empty(): return
	route.clear()
	held_directions.clear()
	if proximity_object.get("id","") == "__return_camp__":
		expedition_ui.call("request_return")
	else:
		expedition_ui.call("_show_object",proximity_object)
	refresh_state()

func sync_saved_position() -> void:
	route.clear()
	actor.position = Game.expedition_world_position()
	_follow_camera(1.0,true)
	refresh_state()

func _update_actor_occlusion(delta: float) -> void:
	if not is_instance_valid(actor) or navigation == null: return
	var target_alpha := 0.42 if navigation.is_in_adjust_region(actor.position) else 1.0
	actor.modulate.a = move_toward(actor.modulate.a, target_alpha, delta * 4.0)
