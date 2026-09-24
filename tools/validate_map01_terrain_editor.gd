extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		quit(1)
		return
	var Model = load("res://addons/map01_terrain_editor/model.gd")
	var model = Model.new()
	check(model.load_data() == OK,"load")
	var original: Dictionary = model.cells.duplicate(true)
	check(model.placements.size()==31,"all formal objects placed")
	for placement in model.placements:
		var cell := Vector2i(placement.cell[0],placement.cell[1])
		check(model.objects.has(placement.objectId),"stable object reference")
		check(model.can_stand(Vector2(cell)),"landmark has safe approach: "+placement.objectId)
		check(not model.route_between(Vector2i(model.spawn),cell).is_empty(),"landmark reachable: "+placement.objectId)
		check(model.nearby_placement(Vector2(cell)).objectId==placement.objectId,"landmark proximity")

	var ids := {}
	for placement in model.placements:
		check(not ids.has(placement.objectId),"unique placement")
		ids[placement.objectId] = true
	check(ids.size()==model.objects.size(),"all existing IDs represented")
	check(model.rest_areas.size()==2,"two rest clearings")
	for area in model.rest_areas:
		var center := Vector2(area.cell[0],area.cell[1])
		check(model.can_stand(center),"rest center walkable")
		for placement in model.placements:
			if model.objects[placement.objectId].kind in ["enemy_group","elite_enemy","boss"]:
				check(center.distance_to(Vector2(placement.cell[0],placement.cell[1]))>float(area.radius)+1.5,"rest clearing separated from enemies")
	for cell in original:
		model.cells = {cell: original[cell]}
		check(model.pick(model.surface(Vector2(cell),cell)) == cell,"isolated height-aware pick")
	model.cells = original.duplicate(true)
	model.checkpoint()
	model.paint(Vector2i(0,0),3,"stairs")
	check(model.cells[Vector2i(0,0)].height == 3,"paint height")
	model.undo()
	check(model.cells == original,"undo")
	model.redo()
	check(model.cells.has(Vector2i(0,0)),"redo")
	model.paint(Vector2i(0,0),0,"ground",true)
	check(not model.cells.has(Vector2i(0,0)),"erase")
	model.paint(Vector2i(-1,0),0,"ground")
	check(not model.cells.has(Vector2i(-1,0)),"bounds")
	model.cells = original.duplicate(true)
	# Traverse the authored stair width and landings in both directions.
	for x in [15.0,16.0,17.0]:
		for lateral in [-0.3,0.0,0.3]:
			var lower := Vector2(x+lateral,54)
			var upper := Vector2(x+lateral,51)
			check(model.move_actor(lower,upper-lower).distance_to(upper)<0.001,"stair ascent across width")
			check(model.move_actor(upper,lower-upper).distance_to(lower)<0.001,"stair descent across width")
	check(not model.can_step(Vector2i(14,54),Vector2i(14,53)),"missing ground blocks")
	check(not model.can_stand(Vector2(12,58)),"mountain blocks")
	check(model.move_actor(Vector2(14,58),Vector2(-4,0)).x>13.5,"large move cannot cross mountain")
	check(not model.can_step(Vector2i(15,53),Vector2i(14,53)),"stair side blocks")
	var traversal: Array[Vector2] = model.route_between(Vector2i(16,67),Vector2i(16,47))
	check(not traversal.is_empty(),"entry reaches upper platform")
	var walker := Vector2(16,67)
	for waypoint in traversal:
		walker = model.move_actor(walker,waypoint-walker)
		check(walker.distance_to(waypoint)<0.001,"actual walker follows route")
	check(walker.distance_to(Vector2(16,47))<0.001,"upper platform reached")
	var seam_a: Vector2 = model.surface(Vector2(16,52.5),Vector2i(16,52))
	var seam_b: Vector2 = model.surface(Vector2(16,52.5),Vector2i(16,53))
	check(seam_a.distance_to(seam_b)<0.001,"visual and movement stair seam")
	check(model.extent == Vector2i(44,76),"expanded authoring extent")
	check(model.spawn == Vector2(16,67),"relocated entry")
	for region in model.regions:
		var target := Vector2i(region.cell[0],region.cell[1])
		var path: Array[Vector2] = model.route_between(Vector2i(model.spawn),target)
		check(target==Vector2i(model.spawn) or not path.is_empty(),"region reachable: "+region.name)
		var cursor: Vector2 = model.spawn
		for point in path:
			cursor = model.move_actor(cursor,point-cursor)
			check(cursor.distance_to(point)<0.001,"expanded route actual movement: "+region.name)
	# Reachability here does not imply a direct northern link from the left branch.
	for side in [Vector2i(12,30),Vector2i(26,30)]:
		check(not model.route_between(side,Vector2i(19,20)).is_empty(),"two routes reconnect")
	var temp := "user://map01_terrain_editor_validation.json"
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Model.PATH))
	var file := FileAccess.open(temp,FileAccess.WRITE)
	file.store_string(JSON.stringify(source, "", true, true))
	file.close()
	model.data_path = temp
	check(model.load_data() == OK,"temporary reload")
	model.paint(Vector2i(0,0),1,"road")
	check(model.save() == OK,"save")
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(temp))
	source.erase("terrainAuthoring")
	after.erase("terrainAuthoring")
	check(source == after,"gameplay fields preserved")
	var other = Model.new()
	other.data_path = temp
	check(other.load_data() == OK,"round trip load")
	check(other.cells == model.cells,"round trip cells")
	check(other.extent == model.extent and other.spawn == model.spawn and other.regions == model.regions,"expanded metadata survives save")
	other.paint(Vector2i(1,0),1,"ground")
	check(other.save() == OK,"external edit")
	check(model.save() == ERR_BUSY,"conflicting edit protected")
	DirAccess.remove_absolute(temp)
	# Reproduce editor startup: a nonzero but too-small allocation, then final size.
	var startup_canvas = load("res://addons/map01_terrain_editor/canvas.gd").new()
	startup_canvas.model = model
	startup_canvas.size = Vector2(900,40)
	root.add_child(startup_canvas)
	startup_canvas.fit()
	check(not startup_canvas.initial_fit_done,"tiny startup layout must not freeze initial view")
	startup_canvas.size = Vector2(1200,650)
	await process_frame
	await process_frame
	check(startup_canvas.initial_fit_done and startup_canvas.zoom>0,"final size automatically fits")
	startup_canvas.hide()
	startup_canvas.size = Vector2(950,450)
	startup_canvas.show()
	await process_frame
	await process_frame
	for cell in model.cells:
		for vertex in model.surface_polygon(cell):
			var screen: Vector2 = vertex*startup_canvas.zoom+startup_canvas.pan
			check(Rect2(Vector2.ZERO,startup_canvas.size).has_point(screen),"terrain visible after tab resize")
	startup_canvas.queue_free()
	var panel = load("res://addons/map01_terrain_editor/panel.gd").new()
	# Match the actual editor host: a Container, with the plugin initially hidden.
	root.content_scale_size = Vector2i(1440,1000)
	var host := VBoxContainer.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(host)
	host.add_child(panel)
	panel.hide()
	await process_frame
	panel.show()
	await process_frame
	await process_frame
	check(panel.canvas != null and panel.model.cells == original,"panel load")
	check(panel.size.y > 900 and panel.canvas.size.y > 600,"editor container expands canvas")
	check(panel.canvas.zoom > 0,"initial fit after layout")
	var zoom_anchor := Vector2(320,240)
	var anchored_world: Vector2 = (zoom_anchor-panel.canvas.pan)/panel.canvas.zoom
	var magnify := InputEventMagnifyGesture.new()
	magnify.position = zoom_anchor
	magnify.factor = 2.0
	var zoom_before: float = panel.canvas.zoom
	panel.canvas._gui_input(magnify)
	check(is_equal_approx(panel.canvas.zoom,zoom_before*2),"trackpad pinch zoom")
	check(((zoom_anchor-panel.canvas.pan)/panel.canvas.zoom).distance_to(anchored_world)<0.01,"zoom preserves pointer anchor")
	panel.zoom_slider.value = 300
	check(is_equal_approx(panel.canvas.zoom,3.0) and panel.zoom_label.text=="300%","visible zoom slider")
	panel.canvas._fit_when_ready()
	await process_frame
	check(is_equal_approx(panel.canvas.zoom,3.0),"manual zoom not reset by auto fit")
	var gesture := InputEventPanGesture.new()
	gesture.delta = Vector2(2,3)
	var previous_pan: Vector2 = panel.canvas.pan
	panel.canvas._gui_input(gesture)
	check(panel.canvas.pan!=previous_pan,"trackpad two finger pan")
	check(panel.model.cells==original,"view gestures do not paint terrain")
	panel.canvas.fit()
	panel.play_button.pressed.emit()
	check(panel.canvas.play_mode and panel.play_button.text == "返回编辑","play toggle")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = panel.canvas.pan+model.surface(Vector2(16,47),Vector2i(16,47))*panel.canvas.zoom
	panel.canvas._gui_input(click)
	check(not panel.canvas.route.is_empty(),"canvas click routes to upper platform")
	for tick in range(400): panel.canvas._process(0.05)
	check(panel.canvas.actor_position.distance_to(Vector2(16,47))<0.03,"canvas walking reaches upper platform")
	panel.play_button.pressed.emit()
	check(not panel.canvas.play_mode and panel.play_button.text == "试玩地形","return to editor")
	if OS.get_cmdline_user_args().has("--capture"):
		root.content_scale_size = Vector2i(1440,1000)
		root.size = Vector2i(1440,1000)
		await process_frame
		panel.canvas.fit()
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Docs/Artifacts/map01-rebuild/terrain-editor.png")
		if OS.get_cmdline_user_args().has("--capture-lamp"):
			panel.canvas.set_zoom(1.5,panel.canvas.size*0.5)
			panel.canvas.pan = panel.canvas.size*0.5-panel.model.surface(Vector2(16,45),Vector2i(16,45))*panel.canvas.zoom
			panel.canvas.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://Docs/Artifacts/map01-rebuild/lamp-candidate.png")
		if OS.get_cmdline_user_args().has("--capture-walk"):
			panel.play_button.pressed.emit()
			panel.canvas.actor_position = Vector2(19,19)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://Docs/Artifacts/map01-rebuild/terrain-walk.png")
	panel.queue_free()
	if failures.is_empty(): print("MAP01_TERRAIN_EDITOR: PASS")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
