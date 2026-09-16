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
	current_scene = scene
	await process_frame
	scene.set_physics_process(false)
	scene.refresh_state()
	if scene.proximity_object.get("id","") != "__return_camp__": push_error("missing return interaction"); quit(1); return
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/return_platform_in_map.png")
	scene._interact()
	if not scene.expedition_ui.entry_return_overlay.visible: quit(1); return
	scene.expedition_ui.entry_return_overlay.visible = false
	if game.profile.expedition == null: quit(1); return
	scene._interact()
	await scene.expedition_ui._return_camp()
	await process_frame
	if game.profile.expedition != null: quit(1); return
	print("RETURN_PLATFORM_PASS cancel/confirm/animation/settlement")
	quit()
