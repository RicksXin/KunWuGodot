extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		quit(1)
		return
	var game := root.get_node("Game")
	var original: Dictionary = game.profile.duplicate(true)
	game.profile = game.default_profile.duplicate(true)
	game._normalise_profile()
	check(game.start_expedition().get("ok",false),"start expedition")
	var objects := {}
	for object in game.get_map_definition().objects: objects[object.id] = object
	var boss: Dictionary = objects.m1_boss_gate_spirit
	check(not game.check_map_object_requirements(boss.requirements).ok,"boss locked before repairs")
	var scene = load("res://scenes/map.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	check(scene.lamp_nodes.size()==3,"three actual lamp sprites")
	var first: Dictionary = objects.m1_event_lamp_01
	game.profile.expedition.carriedItems.pickaxe = 0
	var before: Dictionary = game.profile.duplicate(true)
	check(not game.resolve_map_object_action(first,"open_shell").ok,"missing tool rejected")
	check(game.profile==before,"failure leaves profile unchanged")
	for i in range(1,4):
		var id := "m1_event_lamp_%02d" % i
		var object: Dictionary = objects[id]
		game.profile.expedition.position = {"x":object.x,"y":object.y}
		game.profile.expedition.revealedTiles = game._reveal(game.profile.expedition.revealedTiles,game.profile.expedition.position,3)
		scene.actor.position = Vector2(object.x,object.y)
		game.profile.expedition.carriedItems.pickaxe = 1
		scene.refresh_state()
		check(scene.proximity_object.get("id","")==id,"lamp reachable for E interaction: "+id)
		var key := InputEventKey.new()
		key.keycode = KEY_E
		key.pressed = true
		scene._unhandled_input(key)
		var ui = scene.expedition_ui
		check(ui.event_overlay.visible and ui.current_object.get("id","")==id,"E opens actual choices")
		var chosen := -1
		var action_id := "open_shell" if i==1 else "repair"
		for index in ui.current_action_choices.size():
			if ui.current_action_choices[index].id==action_id: chosen=index
		check(chosen>=0,"existing repair action available")
		if chosen>=0: ui._choose_object_action(chosen)
		check(game.map_state_value("map_01.landmarks.%s.state"%id,"")=="LAMP_REPAIRED","saved repaired flag")
		check(not ui.event_overlay.visible,"dialog closes for animation")
		check(scene.lamp_nodes[id].animation==&"repair","successful business starts animation")
		check(scene.object_nodes[id].visible,"completed lamp remains visible")
		var saved: Dictionary = game.profile.duplicate(true)
		check(game.resolve_map_object_action(object,action_id).get("alreadyCompleted",false),"repeat repair rejected")
		check(game.profile==saved,"no duplicate ore or story increments")
		if i<3:
			check(scene.lamp_nodes["m1_event_lamp_%02d"%(i+1)].animation==&"broken","next lamp unaffected")
			check(not game.check_map_object_requirements(boss.requirements).ok,"boss remains locked until all three")
	await create_timer(2.1).timeout
	check(scene.lamp_nodes.m1_event_lamp_03.animation==&"active","transition completes")
	check(game.check_map_object_requirements(boss.requirements).ok,"all three unlock boss requirement")
	check("3/3" in scene.stats_label.text,"progress displayed")
	if OS.get_cmdline_user_args().has("--capture"):
		scene._follow_camera(1.0,true)
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://Docs/Artifacts/map01-rebuild/lamp-formal-interaction.png")
	# Exercise the save payload format without touching user://kunwu_profile.json.
	var persisted := JSON.stringify(game.profile)
	scene.queue_free()
	await process_frame
	game.profile = JSON.parse_string(persisted)
	game._normalise_profile()
	scene = load("res://scenes/map.tscn").instantiate()
	root.add_child(scene)
	scene.set_physics_process(false)
	await process_frame
	for id in scene.lamp_nodes:
		check(scene.lamp_nodes[id].animation==&"active","reentry restores active without repair replay")
		check(scene.object_nodes[id].visible,"repaired lamp persists in map")
	scene.queue_free()
	await process_frame
	game.profile = original
	if failures.is_empty(): print("MAP01_LAMP_INTERACTION: PASS")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
