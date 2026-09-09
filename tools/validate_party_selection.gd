extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	assert(OS.get_cmdline_user_args().has("--no-profile-write"))
	assert(OS.get_cmdline_user_args().has("--ignore-config-cache"))
	var game := root.get_node("Game")
	game.set("profile",JSON.parse_string(FileAccess.get_file_as_string("res://data/config/default_profile.json")))
	var camp: Node = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	await process_frame
	camp.call("_open_hero_selection")
	await process_frame
	var id := "hero_wu_xiu_01"
	var toggle: Button = camp.find_child("ToggleParty_" + id,true,false)
	for pressed in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = toggle.get_global_rect().get_center()
		event.global_position = event.position
		root.push_input(event,true)
		await process_frame
	await process_frame
	assert(camp.get("party_selection_draft").size() == 3)
	assert(game.call("party_heroes").size() == 4)
	camp.find_child("ConfirmPartySelection",true,false).pressed.emit()
	await process_frame
	assert(game.call("party_heroes").size() == 3)
	assert(game.call("get_party_preset")["slots"].size() == 4)
	game.call("_normalise_profile")
	assert(game.call("party_heroes").size() == 3)
	camp.call("_open_hero_selection")
	await process_frame
	assert(camp.get("party_selection_draft").size() == 3)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/private/tmp/kunwu_party_cancel.png")
	camp.find_child("ToggleParty_" + id,true,false).pressed.emit()
	await process_frame
	assert(camp.get("party_selection_draft").size() == 4)
	camp.call("_open_hero_selection")
	await process_frame
	assert(camp.get("party_selection_draft").size() == 3)
	for member in camp.get("party_selection_draft").duplicate():
		camp.call("_toggle_party_member",member)
		await process_frame
	assert(camp.find_child("ConfirmPartySelection",true,false).disabled)
	assert(not game.call("update_party_members",[]).get("ok"))
	print("PARTY_SELECTION_PASS cancel save reopen reselect discard empty")
	quit()
