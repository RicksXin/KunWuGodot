extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"): quit(1); return
	var game = root.get_node("Game")
	game.profile = game.default_profile.duplicate(true)
	var camp = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	current_scene = camp
	await process_frame
	camp._open_settings()
	var button = camp.find_child("OpenCharacterDemoButton",true,false)
	assert(button != null)
	var before := JSON.stringify(game.profile)
	var size := root.content_scale_size
	button.pressed.emit()
	await process_frame
	var demo = root.get_node("CharacterDemo")
	assert(demo.people.size()==20 and not camp.visible)
	demo.set_physics_process(false)
	assert(demo.player == demo.people[0])
	var start: Vector2 = demo.player.host.position
	for i in 30: demo._physics_process(1.0/30.0)
	assert(demo.player.host.position == start, "Player must not wander autonomously")
	assert(demo.player.sprite.frame == 60, "Initial down-facing standing pose")
	Input.action_press("move_up")
	for i in 15: demo._physics_process(1.0/30.0)
	Input.action_release("move_up")
	assert(demo.player.host.position.distance_to(start)>1.0, "Player input must move the character")
	# Every stop direction must retain its facing and select the standing pose.
	for row in [7,8,9]:
		demo.player.row = row
		demo.player.sprite.flip_h = row == 8
		demo._physics_process(1.0/30.0)
		assert(demo.player.sprite.frame == (row+3)*6)
		assert(demo.player.sprite.flip_h == (row == 8))
	var min_y := INF
	var max_y := -INF
	for i in range(1,20):
		min_y = minf(min_y,demo.people[i].host.position.y)
		max_y = maxf(max_y,demo.people[i].host.position.y)
	assert(max_y-min_y > demo.nav.world_size.y*0.65, "NPCs must be distributed across the map")
	for step in 255:
		demo._physics_process(1.0/30.0)
		for i in 20:
			for j in range(i+1,20):
				assert(demo.people[i].host.position.distance_to(demo.people[j].host.position)>=9.99,"People must not overlap")
	var partner: Dictionary = demo.people[1]
	var placed := false
	for candidate in demo.pool:
		if demo._person_position_clear(demo.player,candidate) and demo._person_position_clear(partner,candidate+Vector2(20,0)) and demo.nav.segment_clear(candidate,candidate+Vector2(20,0)):
			demo.player.host.position = candidate
			partner.host.position = candidate+Vector2(20,0)
			placed = true
			break
	assert(placed)
	var blocked: Vector2 = demo._move_person(demo.player,Vector2(60,0))
	assert(blocked.x <= partner.host.position.x-9.99,"Player must not tunnel through NPC")
	demo._refresh_interaction()
	assert(demo.interact_button.visible)
	demo.interact_button.pressed.emit()
	assert(is_instance_valid(demo.dialogue))
	var held_position: Vector2 = demo.player.host.position
	Input.action_press("move_right")
	demo._physics_process(0.1)
	Input.action_release("move_right")
	assert(demo.player.host.position == held_position,"Dialogue blocks movement")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/character_demo_dialogue.png")
	demo.dialogue.find_child("EndConversation",true,false).pressed.emit()
	assert(demo.dialogue == null)
	# Interaction requires the authored line-of-sight check.
	for person in demo.people.slice(1):
		if not demo.nav.segment_clear(demo.player.host.position,person.host.position):
			assert(demo.nearby != person)

	assert(JSON.stringify(game.profile)==before)
	for person in demo.people: assert(demo.nav.can_walk(person.host.position))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/character_demo_live.png")
	demo.find_child("ReturnToSettings",true,false).pressed.emit()
	await process_frame
	assert(camp.visible and root.content_scale_size==size)
	assert(not root.has_node("CharacterDemo"))
	print("CHARACTER_DEMO_PASS settings entry, 1 controlled + 19 full-map NPCs, terrain/person collision, dialogue, profile unchanged, return")
	quit()
