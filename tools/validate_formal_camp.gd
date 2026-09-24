extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(OS.get_cmdline_user_args().has("--no-profile-write"))
	var game = root.get_node("Game")
	var profile_path := "user://kunwu_profile.json"
	var disk_before := FileAccess.get_file_as_bytes(profile_path) if FileAccess.file_exists(profile_path) else PackedByteArray()
	var saved: Dictionary = game.profile.duplicate(true)
	game.profile = game.default_profile.duplicate(true)
	game._normalise_profile()
	# Isolate UI read-only assertions from wall-clock production/stamina ticks.
	game.profile.camp.lastSettledAtUtc = game.now()+3600
	game.profile.expeditionPreparation.lastStaminaSettledAtUtc = game.now()+3600
	var camp = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	await process_frame
	assert(root.content_scale_size == Vector2i(1280,720))
	assert(camp.camp_world.npcs.people.size() == 3)
	assert(not camp.camp_world.actor.visible and not camp.camp_world.overlay.visible)
	var module_profile: Dictionary = game.profile.duplicate(true)
	for id in camp.MODULE_IDS:
		var sprite: Sprite2D = camp.camp_world.portal if id == "portal" else camp.camp_world.buildings.get_node(id)
		camp.world_host.position = Vector2(640,380)-sprite.position*camp.world_host.scale.x
		camp._clamp_pan()
		var rect := sprite.get_rect()
		var hit := Vector2.ZERO
		var found := false
		for y in range(0,int(rect.size.y),12):
			for x in range(0,int(rect.size.x),12):
				var p := sprite.to_global(rect.position+Vector2(x,y))
				if camp.world_input_at(p) and camp.building_at(p) == id:
					hit = p
					found = true
					break
			if found: break
		assert(found,"No selectable opaque pixel for "+id)
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = hit
		click.pressed = true
		camp._input(click)
		click.pressed = false
		camp._input(click)
		await process_frame
		if id == "recruit": assert(camp.toast_panel.visible)
		else:
			assert(is_instance_valid(camp.modal),"Missing business panel for "+id)
			assert(camp.modal_blocker.visible)
			var bounds: Rect2 = camp.modal.get_global_rect()
			assert(bounds.position.x >= 0 and bounds.position.y >= 0)
			assert(bounds.end.x <= 1280.01 and bounds.end.y <= 720.01)
			var pan: Vector2 = camp.world_host.position
			var move := InputEventMouseMotion.new()
			move.position = hit+Vector2(180,30)
			camp._input(move)
			assert(camp.world_host.position == pan)
		camp._close_modal()
		await process_frame
	assert(game.profile.wallet == module_profile.wallet)
	assert(game.profile.inventory == module_profile.inventory)
	assert(game.profile.camp == module_profile.camp)
	assert(game.profile.roster == module_profile.roster)
	assert(game.profile.expedition == module_profile.expedition)
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(700,350)
	press.pressed = true
	camp._input(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(810,410)
	camp._input(motion)
	press.position = motion.position
	press.pressed = false
	camp._input(press)
	assert(not is_instance_valid(camp.modal) and camp.moved_world)
	assert(camp.original_top_hud.position == Vector2(18,10))
	assert(camp.original_bottom_hud.position == Vector2(18,632))
	camp.zoom_world(1.2,Vector2(640,360))
	assert(camp.world_host.scale.x >= camp.MIN_PLAYER_ZOOM)
	camp.zoom_world(0.001,Vector2(640,360))
	assert(camp.world_host.scale.x == camp.MIN_PLAYER_ZOOM)
	assert(832*camp.world_host.scale.x > camp.CAMP_VIEW.y)
	camp.zoom_world(1000,Vector2(640,360))
	assert(is_equal_approx(camp.world_host.scale.x,camp.MAX_PLAYER_ZOOM))
	camp.world_host.position = Vector2(99999,-99999)
	camp._clamp_pan()
	var centre: Vector2 = (Vector2(camp.CAMP_VIEW)*0.5-camp.world_host.position)/camp.world_host.scale.x
	assert(centre.x >= camp.camera_centre_bounds().position.x-0.01 and centre.x <= camp.camera_centre_bounds().end.x+0.01)
	assert(centre.y >= camp.camera_centre_bounds().position.y-0.01 and centre.y <= camp.camera_centre_bounds().end.y+0.01)
	# Every zoom must stop at the same approved world edges in all drag directions.
	for zoom in [camp.MIN_PLAYER_ZOOM,camp.DEFAULT_PLAYER_ZOOM,camp.MAX_PLAYER_ZOOM]:
		camp.world_host.scale = Vector2.ONE*zoom
		for target in [Vector2(-99999,-99999),Vector2(99999,99999)]:
			camp.world_host.position = target
			camp._clamp_pan()
			var top_left: Vector2 = -camp.world_host.position/zoom
			var bottom_right: Vector2 = (Vector2(camp.CAMP_VIEW)-camp.world_host.position)/zoom
			assert(top_left.x >= camp.PLAYER_VIEW_BOUNDS.position.x-0.01)
			assert(top_left.y >= camp.PLAYER_VIEW_BOUNDS.position.y-0.01)
			assert(bottom_right.x <= camp.PLAYER_VIEW_BOUNDS.end.x+0.01)
			assert(bottom_right.y <= camp.PLAYER_VIEW_BOUNDS.end.y+0.01)
		camp.world_host.position.y = -99999
		camp._clamp_pan()
		var portal_screen_bottom: float = camp.world_host.position.y+camp.portal_bottom*zoom
		assert(is_equal_approx(portal_screen_bottom,float(camp.CAMP_VIEW.y)-15.0))
	camp.fit_world()
	var start: Vector2 = camp.player.position
	var camera_start: Vector2 = camp.world_host.position
	var destination := -1
	for id in camp.camp_world.graph.get_point_ids():
		var path: PackedInt64Array = camp.camp_world.graph.get_id_path(camp.camp_world.current,id)
		if path.size() >= 4:
			destination = id
			break
	assert(destination >= 0)
	assert(camp.move_player_to(camp.world_host.to_global(camp.camp_world.graph.get_point_position(destination))))
	camp.camp_world.set_process(false)
	for step in range(120):
		camp.camp_world._process(1.0/60.0)
		camp._update_player(1.0/60.0)
	assert(camp.player.position.distance_to(start) > 30)
	assert(camp.world_host.position.distance_to(camera_start) > 1)
	assert(camp.player.frame >= 42 and camp.player.frame < 78)
	camp.camp_world.route.clear()
	camp._update_player(0.1)
	assert(camp.player.frame >= 60)
	camp.camp_world.set_process(true)
	camp._open_settings()
	await process_frame
	assert(camp.modal.find_child("OpenCampTileMapLabButton",true,false) != null)
	camp._open_camp_tilemap_lab()
	var lab = root.get_child(root.get_child_count()-1)
	await process_frame
	assert(not camp.visible)
	lab._return_to_camp()
	await process_frame
	assert(camp.visible and root.content_scale_size == Vector2i(1280,720))
	camp._open_character_demo()
	var demo = root.get_child(root.get_child_count()-1)
	await process_frame
	demo.close()
	await process_frame
	assert(camp.visible and root.content_scale_size == Vector2i(1280,720))
	camp._close_modal()
	camp._open_expedition()
	assert(camp.expedition_draft is Dictionary)
	camp._close_modal()
	camp.queue_free()
	await process_frame
	var result: Dictionary = game.start_expedition({},"map_01")
	assert(result.ok,"Departure failed: "+str(result))
	var map = load("res://scenes/map.tscn").instantiate()
	root.add_child(map)
	await process_frame
	assert(root.content_scale_size == Vector2i(817,375))
	assert(game.return_to_camp().ok)
	map.queue_free()
	await process_frame
	camp = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	await process_frame
	assert(root.content_scale_size == Vector2i(1280,720) and game.profile.expedition == null)
	camp.queue_free()
	await process_frame
	game.profile = saved
	var disk_after := FileAccess.get_file_as_bytes(profile_path) if FileAccess.file_exists(profile_path) else PackedByteArray()
	assert(game.suppress_profile_writes,"Validation must never enable profile writes")
	if disk_before != disk_after:
		push_warning("Save bytes changed externally during validation; concurrent gameplay may be saving. This process has profile writes disabled.")
	print("PASS formal landscape camp: 8 pixel-hit building entries, centered business panels, fixed HUD, drag-vs-click, zoom, modal blocks map input, 3 NPCs, expedition/map/return landscape restoration, profile writes disabled")
	quit()
