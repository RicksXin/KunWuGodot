extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		quit(1)
		return
	var game = root.get_node("Game")
	game.profile = game.default_profile.duplicate(true)
	game.start_expedition()
	var scene = load("res://scenes/map.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_physics_process(false)
	scene.set_process(false)
	var nav = scene.navigation
	assert(nav.external_adjust_polygons.size() == 17)
	assert(nav.external_collision_polygons.size() == 36)
	var inside := Vector2.ZERO
	var found := false
	for polygon in nav.external_adjust_polygons:
		var center := Vector2.ZERO
		for p in polygon: center += p
		center /= polygon.size()
		if nav.is_in_adjust_region(center): inside = center; found = true; break
	assert(found)
	scene.actor.position = inside
	scene._update_actor_occlusion(0.2)
	assert(is_equal_approx(scene.actor.modulate.a,0.42))
	scene.actor.position = Vector2(450,1890)
	assert(not nav.is_in_adjust_region(scene.actor.position))
	scene._update_actor_occlusion(0.2)
	assert(is_equal_approx(scene.actor.modulate.a,1.0))
	print("ADJUST_OCCLUSION_PASS: 17 adjust, 36 collision, fade and restore")
	quit()
