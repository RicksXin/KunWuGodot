extends "res://scripts/scenes/camp.gd"
## Formal landscape hall; all business commands remain in the original camp controller.
const CAMP_VIEW := Vector2i(1280,720)
const WORLD_AREA := Rect2(0,0,1280,720)
const MIN_PLAYER_ZOOM := 1.0
const DEFAULT_PLAYER_ZOOM := 1.1
const MAX_PLAYER_ZOOM := 1.35
# Visible world edges calibrated to the approved left/right/bottom reference views.
# Clamp the viewport edges, so zooming cannot expose more beyond these limits.
const PLAYER_VIEW_BOUNDS := Rect2(-720,-147,1750,1077)
var interaction_hint: Label
var nearby_interaction: Dictionary = {}
var portal_bottom := 0.0
var player: Sprite2D
var player_phase := 0.0
var player_row := 7
var follow_player := false
var original_top_hud: Control
var original_bottom_hud: Control
const MODULE_IDS := {
	"council":"yi_shi_dian", "garden":"ling_pu", "recruit":"zhao_xian_tai",
	"treasury":"bai_bao_ku", "forge":"lian_qi_fang", "market":"jiao_yi_hang",
	"revival":"huan_hun_tan", "portal":"portal"
}
var camp_world: Node2D
var world_host: Node2D
var exterior: Control
var modal_blocker: ColorRect
var fitted_modal: Control
var dragging_world := false
var moved_world := false
var pointer_start := Vector2.ZERO
var pan_start := Vector2.ZERO
var saved_content := Vector2i.ZERO
var saved_size := Vector2i.ZERO
var saved_position := Vector2i.ZERO
var saved_orientation := DisplayServer.SCREEN_PORTRAIT

func _enter_tree() -> void:
	saved_content = get_window().content_scale_size
	get_window().content_scale_size = CAMP_VIEW
	if OS.has_feature("mobile"):
		saved_orientation = DisplayServer.screen_get_orientation()
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_LANDSCAPE)
	elif DisplayServer.get_name() != "headless":
		saved_size = get_window().size
		saved_position = get_window().position
		if get_window().mode == Window.MODE_WINDOWED:
			var usable := DisplayServer.screen_get_usable_rect()
			var factor := minf(1.0,minf((usable.size.x-40.0)/1280.0,(usable.size.y-40.0)/720.0))
			get_window().size = Vector2i(Vector2(CAMP_VIEW)*factor)
			get_window().position = usable.position+(usable.size-get_window().size)/2

func _exit_tree() -> void:
	get_window().content_scale_size = saved_content
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(saved_orientation)
	elif DisplayServer.get_name() != "headless" and saved_size != Vector2i.ZERO:
		get_window().size = saved_size
		get_window().position = saved_position

func _build_scene() -> void:
	var background := ColorRect.new()
	background.color = Color("18262c")
	background.size = Vector2(CAMP_VIEW)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	exterior = preload("res://scripts/prototypes/camp_exterior_preview.gd").new()
	add_child(exterior)
	exterior.position = Vector2.ZERO
	exterior.size = Vector2(CAMP_VIEW)
	exterior.set_cloudscape(true)
	world_host = Node2D.new()
	world_host.name = "CampWorldTransform"
	add_child(world_host)
	camp_world = preload("res://scripts/prototypes/camp_tile_rebuild.gd").new()
	camp_world.name = "CampWorld"
	world_host.add_child(camp_world)
	camp_world.actor.hide()
	camp_world.route_line.hide()
	camp_world.overlay.hide()
	var portal_image: Image = camp_world.portal.texture.get_image()
	portal_bottom = camp_world.portal.position.y+(camp_world.portal.get_rect().position.y+portal_image.get_used_rect().end.y)*camp_world.portal.scale.y
	player = Sprite2D.new()
	player.name = "CampPlayer"
	player.texture = preload("res://assets/debug/wuxia_characters/1787918845829-frames64-oldfix2.png")
	player.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player.hframes = 6
	player.vframes = 13
	player.frame = 60
	player.offset = Vector2(0,-19)
	player.scale = Vector2.ONE*1.5
	player.position = camp_world.actor.position
	camp_world.depth_sorted.add_child(player)
	fit_world()
	exterior.reference_camera = world_host.position
	exterior.reference_zoom = world_host.scale.x
	_build_landscape_hud()
	interaction_hint = Label.new()
	interaction_hint.name = "InteractionHint"
	interaction_hint.add_theme_font_size_override("font_size",18)
	interaction_hint.add_theme_color_override("font_outline_color",Color.BLACK)
	interaction_hint.add_theme_constant_override("outline_size",5)
	interaction_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interaction_hint.z_index = 110
	add_child(interaction_hint)
	_build_toast()
	toast_panel.position = Vector2(492,595)
	toast_panel.z_index = 300
	modal_blocker = ColorRect.new()
	modal_blocker.name = "LandscapeModalBlocker"
	modal_blocker.size = Vector2(CAMP_VIEW)
	modal_blocker.color = Color(0,0,0,0.68)
	modal_blocker.z_index = 200
	modal_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	modal_blocker.hide()
	add_child(modal_blocker)

func _build_landscape_hud() -> void:
	# Reuse the original art, hierarchy, icons, labels and callbacks without redesign.
	super._build_top_hud()
	original_top_hud = get_child(get_child_count()-1)
	original_top_hud.name = "OriginalTopHUD"
	original_top_hud.position = Vector2(18,10)
	original_top_hud.scale = Vector2.ONE*1.5
	original_top_hud.z_index = 100
	super._build_bottom_hud()
	original_bottom_hud = get_child(get_child_count()-1)
	original_bottom_hud.name = "OriginalBottomHUD"
	original_bottom_hud.position = Vector2(18,632)
	original_bottom_hud.scale = Vector2.ONE*1.5
	original_bottom_hud.z_index = 100

func world_input_at(point: Vector2) -> bool:
	return WORLD_AREA.has_point(point) and not original_top_hud.get_global_rect().has_point(point) and not original_bottom_hud.get_global_rect().has_point(point)

func _build_resource_notice() -> void:
	super._build_resource_notice()
	resource_notice_layer.position = Vector2(488,560)

func _process(delta: float) -> void:
	super._process(delta)
	camp_world.set_process(visible and not is_instance_valid(modal))
	if visible and not is_instance_valid(modal) and get_window().has_focus():
		var keys := Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
		keyboard_walk(keys,delta)
	_update_player(delta)
	_update_interaction()
	if is_instance_valid(exterior): exterior.sync_camera(world_host.position,true,world_host.scale.x)
	if is_instance_valid(modal):
		dragging_world = false
		modal_blocker.show()
		if fitted_modal != modal: _fit_modal()
	else:
		modal_blocker.hide()
		fitted_modal = null

func _fit_modal() -> void:
	# Keep established business-panel coordinates and fit the entire portrait canvas.
	modal.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	modal.size = Vector2(375,817)
	var factor := 0.84
	modal.scale = Vector2.ONE*factor
	modal.position = (Vector2(CAMP_VIEW)-modal.size*factor)*0.5
	modal.z_index = 210
	# The landscape blocker supplies one uniform shade across the entire viewport.
	for child in modal.get_children():
		if child is ColorRect and child.anchor_right == 1.0 and child.anchor_bottom == 1.0:
			child.hide()
	fitted_modal = modal

func _close_modal() -> void:
	super._close_modal()
	fitted_modal = null
	if is_instance_valid(modal_blocker): modal_blocker.hide()

func fit_world() -> void:
	world_host.scale = Vector2.ONE*DEFAULT_PLAYER_ZOOM
	world_host.position = Vector2(CAMP_VIEW)*0.5-Vector2(170,450)*DEFAULT_PLAYER_ZOOM
	_clamp_pan()

func zoom_world(factor: float, at: Vector2) -> void:
	var local := world_host.to_local(at)
	var zoom := clampf(world_host.scale.x*factor,MIN_PLAYER_ZOOM,MAX_PLAYER_ZOOM)
	world_host.scale = Vector2.ONE*zoom
	world_host.position = at-local*zoom
	_clamp_pan()

func keyboard_walk(direction: Vector2, delta: float) -> void:
	if direction.is_zero_approx() or not visible or is_instance_valid(modal): return
	camp_world.route.clear()
	follow_player = true
	var step := direction.normalized()*110.0*minf(delta,0.05)
	# Small substeps prevent crossing a blocked cell during a slow frame.
	var count := maxi(1,ceili(step.length()/2.0))
	for i in count:
		var origin: Vector2 = camp_world.actor.position
		var candidate := origin+step/count
		if not _try_player_step(candidate):
			if not _try_player_step(origin+Vector2(step.x/count,0)):
				_try_player_step(origin+Vector2(0,step.y/count))

func _try_player_step(point: Vector2) -> bool:
	if camp_world.Collision.crosses(camp_world.actor.position,point,camp_world.footprints): return false
	var graph: AStar2D = camp_world.graph
	var current: int = camp_world.current
	# The entire stair width is traversable, including both landing mouths.
	for stair in camp_world.data.stairs:
		var cells := [Vector2i(stair.from[0],stair.from[1]),Vector2i(stair.cell[0],stair.cell[1]),Vector2i(stair.to[0],stair.to[1])]
		var nodes: Array[int] = []
		for cell in cells:
			if camp_world.ids.has(cell): nodes.append(camp_world.ids[cell])
		if nodes.size() != 3 or not nodes.has(current): continue
		if not graph.are_points_connected(nodes[0],nodes[1]) or not graph.are_points_connected(nodes[1],nodes[2]): continue
		var a := graph.get_point_position(nodes[0])
		var b := graph.get_point_position(nodes[2])
		var side := Vector2(-32,16) if stair.axis == "x" else Vector2(32,16)
		var extension := (b-a).normalized()*12.0
		var area := PackedVector2Array([a-extension-side,a-extension+side,b+extension+side,b+extension-side])
		if Geometry2D.is_point_in_polygon(point,area):
			var nearest := current
			for id in nodes:
				if point.distance_squared_to(graph.get_point_position(id)) < point.distance_squared_to(graph.get_point_position(nearest)): nearest = id
			camp_world.current = nearest
			camp_world.actor.position = point
			return true

	var adjacent := graph.get_point_connections(current)
	var candidates := adjacent.duplicate()
	candidates.append(current)
	var cell: Vector2i = camp_world.ids.find_key(current)
	# Screen-cardinal motion crosses diamond corners. Admit a diagonal only when
	# both intervening cells exist and connect on the same platform (no corner cut).
	for offset in [Vector2i(1,1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(-1,-1)]:
		var diagonal: Vector2i = cell+offset
		var x_cell := cell+Vector2i(offset.x,0)
		var y_cell := cell+Vector2i(0,offset.y)
		if not camp_world.ids.has(diagonal) or not camp_world.ids.has(x_cell) or not camp_world.ids.has(y_cell): continue
		var id: int = camp_world.ids[diagonal]
		var x_id: int = camp_world.ids[x_cell]
		var y_id: int = camp_world.ids[y_cell]
		if camp_world.heights[diagonal] != camp_world.heights[cell]: continue
		if adjacent.has(x_id) and adjacent.has(y_id) and graph.are_points_connected(x_id,id) and graph.are_points_connected(y_id,id): candidates.append(id)
	var best := -1
	var best_metric := INF
	for id in candidates:
		var offset := point-graph.get_point_position(id)
		var metric := absf(offset.x)/64.0+absf(offset.y)/32.0
		if metric <= 1.00001 and metric < best_metric:
			best = id
			best_metric = metric
	if best >= 0:
		camp_world.actor.position = point
		# Ownership follows the containing diamond, not Euclidean centre distance.
		camp_world.current = best
		return true
	# Stair transitions connect vertically displaced platform diamonds.
	for id in adjacent:
		var centre := graph.get_point_position(id)
		var origin := graph.get_point_position(current)
		var projection := Geometry2D.get_closest_point_to_segment(point,origin,centre)
		if point.distance_to(projection) < 10.0:
			camp_world.actor.position = point
			if point.distance_squared_to(centre) < point.distance_squared_to(origin): camp_world.current = id
			return true
	return false

func _reachable_near(point: Vector2, node: int) -> bool:
	if node < 0 or player.position.distance_to(point) > 88.0: return false
	var graph: AStar2D = camp_world.graph
	var path := graph.get_id_path(camp_world.current,node)
	if path.is_empty(): return false
	var distance := 0.0
	for i in range(1,path.size()):
		distance += graph.get_point_position(path[i-1]).distance_to(graph.get_point_position(path[i]))
	return distance <= 155.0

func _update_interaction() -> void:
	nearby_interaction = {}
	interaction_hint.hide()
	if not visible or is_instance_valid(modal): return
	var closest := INF
	for target in camp_world.targets:
		# Sprite position is the authored threshold after visual layout offsets.
		var point: Vector2 = target.visual.position
		var door_node: int = camp_world.graph.get_closest_point(point)
		var distance := player.position.distance_to(point)
		if distance < closest and _reachable_near(point,door_node):
			closest = distance
			nearby_interaction = {"kind":"building","id":str(target.visual.name),"name":target.name}
	var portal_node: int = camp_world.graph.get_closest_point(camp_world.portal.position)
	if player.position.distance_to(camp_world.portal.position) < closest and _reachable_near(camp_world.portal.position,portal_node):
		closest = player.position.distance_to(camp_world.portal.position)
		nearby_interaction = {"kind":"building","id":"portal","name":"传送阵"}
	var names := {"traveler":"青衣行脚者","elder":"白发长者","cultivator":"红衣女修"}
	for person in camp_world.npcs.people:
		var point: Vector2 = person.sprite.position
		var node: int = camp_world.graph.get_closest_point(point)
		var distance := player.position.distance_to(point)
		if distance < closest and _reachable_near(point,node):
			closest = distance
			nearby_interaction = {"kind":"npc","id":str(person.sprite.name),"name":names.get(str(person.sprite.name),"营地修士")}
	if nearby_interaction.is_empty(): return
	interaction_hint.text = "E  " + str(nearby_interaction.name)
	interaction_hint.position = (world_host.to_global(player.position)+Vector2(-55,-85)).clamp(Vector2(8,8),Vector2(1080,600))
	interaction_hint.show()

func interact_nearby() -> void:
	_update_interaction()
	if nearby_interaction.is_empty(): return
	camp_world.route.clear()
	if nearby_interaction.kind == "building": open_world_building(nearby_interaction.id)
	else:
		var lines := {"traveler":"山路险远，入山前记得备好行装。","elder":"修行莫急，平安归来才是要紧事。","cultivator":"我在营地巡视，道友一路小心。"}
		_show_feedback(str(nearby_interaction.name)+"："+str(lines.get(nearby_interaction.id,"道友好。")))

func move_player_to(screen_point: Vector2) -> bool:
	var local := world_host.to_local(screen_point)
	var id: int = camp_world.graph.get_closest_point(local)
	if id < 0 or local.distance_to(camp_world.graph.get_point_position(id)) > 48: return false
	if not camp_world.move_to_node(id): return false
	follow_player = true
	return true

func _update_player(delta: float) -> void:
	if not is_instance_valid(player) or not visible: return
	var direction: Vector2 = camp_world.actor.position-player.position
	player.position = camp_world.actor.position
	if direction.length_squared() > 0.0001:
		player.flip_h = false
		if absf(direction.x) > absf(direction.y):
			player_row = 8
			player.flip_h = direction.x > 0
		else: player_row = 9 if direction.y < 0 else 7
		player_phase += delta*8.0
		player.frame = player_row*6+int(player_phase)%6
	else: player.frame = (player_row+3)*6
	if follow_player and not dragging_world and not is_instance_valid(modal):
		var desired := Vector2(CAMP_VIEW)*0.5-player.position*world_host.scale.x
		world_host.position = world_host.position.lerp(desired,1.0-exp(-7.0*delta))
		_clamp_pan()
		if camp_world.route.is_empty() and direction.is_zero_approx(): follow_player = false

func camera_centre_bounds() -> Rect2:
	var half_view := Vector2(CAMP_VIEW)*0.5/world_host.scale.x
	var limits := PLAYER_VIEW_BOUNDS
	# 15 logical screen pixels below the visible portal base, at every zoom.
	limits.end.y = portal_bottom+15.0/world_host.scale.x
	return Rect2(limits.position+half_view,limits.size-half_view*2.0)

func _clamp_pan() -> void:
	var screen_centre := Vector2(CAMP_VIEW)*0.5
	var centre := (screen_centre-world_host.position)/world_host.scale.x
	var limits := camera_centre_bounds()
	centre = centre.clamp(limits.position,limits.end)
	world_host.position = screen_centre-centre*world_host.scale.x

func _input(event: InputEvent) -> void:
	if not visible: return
	if is_instance_valid(modal):
		dragging_world = false
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_close_modal()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.physical_keycode == KEY_E and event.pressed and not event.echo:
		interact_nearby()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMagnifyGesture and world_input_at(event.position):
		zoom_world(event.factor,event.position)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture and world_input_at(event.position):
		follow_player = false
		world_host.position -= event.delta*12.0
		_clamp_pan()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN] and world_input_at(event.position):
		zoom_world(1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0/1.1,event.position)
		get_viewport().set_input_as_handled()
		return
	var point := Vector2.ZERO
	var pressed := false
	var released := false
	var motion := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenTouch:
		point = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		point = event.position
		motion = true
	elif event is InputEventScreenDrag:
		point = event.position
		motion = true
	else: return
	if pressed and world_input_at(point):
		dragging_world = true
		moved_world = false
		pointer_start = point
		pan_start = world_host.position
	elif motion and dragging_world:
		if point.distance_to(pointer_start) > 6: moved_world = true
		if moved_world:
			follow_player = false
			world_host.position = pan_start+point-pointer_start
			_clamp_pan()
	elif released and dragging_world:
		dragging_world = false
		if not moved_world and world_input_at(point):
			var id := building_at(point)
			if not id.is_empty(): open_world_building(id)
			else: move_player_to(point)
	else: return
	get_viewport().set_input_as_handled()

func building_at(point: Vector2) -> String:
	var visuals: Array = camp_world.buildings.get_children().filter(func(node): return node is Sprite2D)
	visuals.sort_custom(func(a,b): return a.position.y > b.position.y)
	visuals.append(camp_world.portal)
	for sprite: Sprite2D in visuals:
		if not sprite.is_visible_in_tree(): continue
		var local := sprite.to_local(point)
		if sprite.get_rect().has_point(local) and sprite.is_pixel_opaque(local):
			return "portal" if sprite == camp_world.portal else str(sprite.name)
	return ""

func open_world_building(id: String) -> void:
	if not MODULE_IDS.has(id): return
	var module: String = MODULE_IDS[id]
	var level := 1 if module == "portal" else int(Game.profile.get("camp",{}).get("buildingLevels",{}).get(module,0))
	_on_building_pressed(module,level)
	if is_instance_valid(modal):
		modal_blocker.show()
		_fit_modal()
