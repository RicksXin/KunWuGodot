extends SceneTree
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	assert(OS.get_cmdline_user_args().has("--no-profile-write"), "Requires --no-profile-write")
	var game := root.get_node("Game")
	var previous: Dictionary = game.profile.duplicate(true)
	var fixture: Dictionary = game.default_profile.duplicate(true)
	fixture["wallet"]["soulCrystal"] = 20
	fixture["expedition"] = null
	for hero in fixture["roster"]:
		hero["isDead"] = true
		hero["currentHp"] = 0
		hero["level"] = 10
	for preset in fixture["expeditionPreparation"]["partyPresets"]: preset["slots"] = []
	game.profile = fixture
	var camp = load("res://scenes/camp.tscn").instantiate()
	root.add_child(camp)
	await process_frame
	camp._open_revive_hall()
	await process_frame
	var panel = camp.modal
	assert(panel.rows.size() == 4)
	assert(not panel.submit.disabled)
	var first_id: String = panel.selected_id
	panel._select(str(fixture["roster"][1]["instanceId"]))
	assert(panel.submit.text.contains(game.text(fixture["roster"][1]["nameKey"])))
	panel._select(first_id)
	await _capture("emergency_godot.png")
	panel.submit.pressed.emit()
	await process_frame
	await process_frame
	assert(game.living_heroes().size() == 1 and game.dead_heroes().size() == 3)
	assert(game.wallet_value("soulCrystal") == 20)
	assert(camp.find_child("EmergencyReviveButton", true, false) == null)
	var repeated: Dictionary = game.emergency_revive_cultivator(str(fixture["roster"][1]["instanceId"]))
	assert(not repeated.get("ok", true))
	game.profile = game.default_profile.duplicate(true)
	game.profile["wallet"]["soulCrystal"] = 80
	camp._open_revive_hall()
	await process_frame
	assert(camp.modal.heroes.is_empty())
	await _capture("empty_godot.png")
	camp.find_child("PrepareAfterReviveButton", true, false).pressed.emit()
	await process_frame
	assert(camp.find_child("入山整备Title", true, false) != null)
	camp._close_modal()
	game.profile = previous
	print("REVIVE_DESIGN_OK: emergency selects/restores one, no charge, no repeat, empty state opens preparation")
	quit()
func _capture(file: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://Docs/Artifacts/figma-revive/" + file) == OK)
