extends Node

const CAMP_SCENE = preload("res://scenes/camp.tscn")

var errors: Array[String] = []

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		_fail("validation requires --no-profile-write")
		_finish()
		return
	var game := get_tree().root.get_node_or_null("Game")
	if game == null:
		_fail("Game autoload is missing")
		_finish()
		return
	_validate_normal_revival(game)
	_validate_emergency_revival(game)
	await _validate_camp_entry(game)
	_finish()

func _validate_normal_revival(game: Node) -> void:
	var runtime_profile := _all_dead_profile(game, 1000)
	game.set("profile", runtime_profile)
	var dead: Array = game.call("dead_heroes")
	_check(dead.size() == 4, "all-dead fixture did not expose four dead cultivators")
	var ids: Array = dead.map(func(hero): return str(hero.get("instanceId", "")))
	var costs: Array = dead.map(func(hero): return int(game.call("revival_cost", hero)))
	_check(costs == [30, 30, 30, 30], "Lv.1 revival cost should round to 30 each, got %s" % [costs])
	var result: Dictionary = game.call("revive_cultivators", ids)
	_check(bool(result.get("ok", false)), "batch revival failed: %s" % result.get("message", ""))
	runtime_profile = game.get("profile")
	_check(int(runtime_profile.get("wallet", {}).get("soulCrystal", -1)) == 880, "batch revival did not deduct exactly 120 soul crystals")
	_check(game.call("dead_heroes").is_empty(), "batch revival left dead cultivators behind")
	for hero in runtime_profile.get("roster", []):
		_check(not bool(hero.get("isDead", true)) and int(hero.get("currentHp", 0)) == int(hero.get("maxHp", -1)), "revival did not restore full living state for %s" % hero.get("instanceId", ""))
	var restored_slots: Array = runtime_profile.get("expeditionPreparation", {}).get("partyPresets", [])[0].get("slots", [])
	var expected_slots: Array = game.get("default_profile").get("expeditionPreparation", {}).get("partyPresets", [])[0].get("slots", [])
	_check(restored_slots == expected_slots, "revival did not restore the fixed party slots: %s" % [restored_slots])
	var repeated: Dictionary = game.call("revive_cultivators", ids)
	_check(not bool(repeated.get("ok", true)) and int(game.get("profile").get("wallet", {}).get("soulCrystal", -1)) == 880, "repeated revival charged or succeeded twice")

	runtime_profile = _all_dead_profile(game, 25)
	game.set("profile", runtime_profile)
	var insufficient: Dictionary = game.call("revive_cultivators", [ids[0]])
	_check(not bool(insufficient.get("ok", true)), "insufficient soul crystals unexpectedly allowed normal revival")
	_check(int(game.get("profile").get("wallet", {}).get("soulCrystal", -1)) == 25 and game.call("dead_heroes").size() == 4, "failed normal revival changed profile state")

func _validate_emergency_revival(game: Node) -> void:
	var runtime_profile := _all_dead_profile(game, 0)
	game.set("profile", runtime_profile)
	var hero_id := str(runtime_profile.get("roster", [])[0].get("instanceId", ""))
	var result: Dictionary = game.call("emergency_revive_cultivator", hero_id)
	_check(bool(result.get("ok", false)), "emergency revival failed: %s" % result.get("message", ""))
	_check(game.call("living_heroes").size() == 1 and game.call("dead_heroes").size() == 3, "emergency revival did not restore exactly one cultivator")
	_check(int(game.get("profile").get("wallet", {}).get("soulCrystal", -1)) == 0, "emergency revival charged soul crystals")
	var slots: Array = game.get("profile").get("expeditionPreparation", {}).get("partyPresets", [])[0].get("slots", [])
	_check(slots.size() >= 1 and slots[0] == hero_id, "emergency revival did not restore the cultivator to the active party")
	var repeated: Dictionary = game.call("emergency_revive_cultivator", str(runtime_profile.get("roster", [])[1].get("instanceId", "")))
	_check(not bool(repeated.get("ok", true)), "emergency revival remained available after a living cultivator existed")

func _validate_camp_entry(game: Node) -> void:
	game.set("profile", _all_dead_profile(game, 1000))
	var camp := CAMP_SCENE.instantiate()
	add_child(camp)
	await get_tree().process_frame
	await get_tree().process_frame
	camp.call("_open_revive_hall")
	await get_tree().process_frame
	var capture_path := _argument_value("--capture-revival=")
	if not capture_path.is_empty():
		await _capture(capture_path)
	var revive_all := camp.find_child("ReviveAllButton", true, false) as Button
	_check(revive_all != null and not revive_all.disabled, "revive-all action is missing or disabled in the camp modal")
	if revive_all != null and not revive_all.disabled:
		revive_all.emit_signal("pressed")
		await get_tree().process_frame
		await get_tree().process_frame
		_check(game.call("dead_heroes").is_empty(), "camp revive-all action did not call the domain revival flow")
		_check(camp.find_child("PrepareAfterReviveButton", true, false) != null, "camp did not offer expedition preparation after revival")
	camp.queue_free()

func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.trim_prefix(prefix)
	return ""

func _capture(path: String) -> void:
	await get_tree().process_frame
	var preview: Image = get_viewport().get_texture().get_image()
	if preview == null or preview.is_empty():
		_fail("revival capture returned an empty image")
		return
	if preview.get_size() != Vector2i(375, 817):
		preview.resize(375, 817, Image.INTERPOLATE_NEAREST)
	var save_error := preview.save_png(path)
	if save_error != OK:
		_fail("could not save revival capture: %s" % error_string(save_error))
	else:
		print("REVIVAL_CAPTURE=%s" % path)

func _all_dead_profile(game: Node, soul_crystal: int) -> Dictionary:
	var runtime_profile: Dictionary = game.get("default_profile").duplicate(true)
	runtime_profile["wallet"]["soulCrystal"] = soul_crystal
	runtime_profile["expedition"] = null
	for hero in runtime_profile.get("roster", []):
		hero["currentHp"] = 0
		hero["isDead"] = true
	for preset in runtime_profile.get("expeditionPreparation", {}).get("partyPresets", []):
		# 实际全灭存档经过兼容归一化后会留下空 slots，而不只是四个 null。
		# 还魂必须能从这个真实软锁形态恢复固定队伍顺序。
		preset["slots"] = []
	return runtime_profile

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	if not errors.has(message):
		errors.append(message)
		push_error(message)

func _finish() -> void:
	if errors.is_empty():
		print("REVIVAL_FLOW_VALIDATION_OK")
		get_tree().quit(0)
		return
	print("REVIVAL_FLOW_VALIDATION_FAILED: %d error(s)" % errors.size())
	get_tree().quit(1)
