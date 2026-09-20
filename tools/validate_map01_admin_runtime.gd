extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		push_error("Requires --no-profile-write")
		quit(1)
		return
	var game := root.get_node("Game")
	var repository := root.get_node("ConfigRepository")
	var module: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/map01-admin-runtime.json"))
	var packs := {"first": {"entries": [{"assetCode": "soulCrystal", "quantityMin": 24}, {"assetCode": "test_first", "quantityMin": 1}]}, "repeat": {"entries": [{"assetCode": "soulCrystal", "quantityMin": 12}, {"assetCode": "test_repeat", "quantityMin": 2}]}}
	var adapted: Dictionary = repository.call("_adapt_combat", module, {}, packs, {})
	_check(adapted.get("skills", []).size() == 14, "Database skill count")
	_check(bool(repository.call("has_formal_map_combat", adapted)), "Complete formal map combat coverage")
	var incomplete := adapted.duplicate(true)
	incomplete["encounters"].pop_back()
	_check(not bool(repository.call("has_formal_map_combat", incomplete)), "Partial tables must not replace formal combat")
	game.set("combat_config", adapted)
	game.set("map_definitions", {"map_01": {"positionVersion": 1}})
	game.call("get_map_definition", "map_01")
	_check(game.get("combat_config") == adapted, "Formal map migration overwrote remote combat")
	var encounter: Dictionary = game.call("get_encounter", "m1_g01")
	_check(encounter["enemies"][0]["initialActionTimer"] == 24, "Zero member timer overwrote template timing")
	var boss_encounter: Dictionary = game.call("get_encounter", "m1_boss_gate_spirit")
	_check(boss_encounter["enemies"][0]["mechanics"]["forcedShieldAmount"] == 900, "Boss passive lost in adaptation")
	var profile: Dictionary = game.get("default_profile").duplicate(true)
	profile["expedition"] = {"mapId": "map_01", "encounterId": "m1_g01", "mapObjectId": "m1_g01", "temporaryLoot": {}}
	game.set("profile", profile)
	var before: int = int(profile["wallet"].get("soulCrystal", 0))
	var first: Dictionary = game.call("finish_encounter_victory", encounter)
	_check(first.get("ok", false) and first.get("firstClear", false), "First victory settlement")
	_check(int(profile["wallet"]["soulCrystal"]) == before + 24, "First reward amount")
	_check(profile["expedition"]["pendingEncounterLoot"][0]["itemId"] == "test_first", "First-only item lost")
	var saved := profile.duplicate(true)
	game.set("profile", saved)
	var duplicate: Dictionary = game.call("finish_encounter_victory", encounter)
	_check(duplicate.get("alreadySettled", false), "Reloaded duplicate settlement not blocked")
	_check(int(saved["wallet"]["soulCrystal"]) == before + 24, "Duplicate soul reward")
	game.call("take_pending_encounter_loot")
	game.call("clear_active_encounter")
	_check(not game.call("begin_encounter", {"id": "m1_g01", "encounterId": "m1_g01"}).get("ok", true), "Same-expedition repeat allowed")
	# A new expedition retains persistent first-clear flags but clears transient completion.
	saved["completedMapObjects"] = {}
	saved["expedition"] = {"mapId": "map_01", "encounterId": "", "mapObjectId": "", "temporaryLoot": {}}
	_check(game.call("begin_encounter", {"id": "m1_g01", "encounterId": "m1_g01"}).get("ok", false), "New expedition blocked")
	var repeated: Dictionary = game.call("finish_encounter_victory", encounter)
	_check(repeated.get("ok", false) and not repeated.get("firstClear", true), "First clear flag lost across expeditions")
	_check(int(saved["wallet"]["soulCrystal"]) == before + 36, "Repeat reward amount")
	_check(saved["expedition"]["pendingEncounterLoot"][0]["itemId"] == "test_repeat", "Repeat-only loot not selected")
	# Exercise actual combat scene against the DB-derived enemy/skill payload.
	profile = game.get("default_profile").duplicate(true)
	profile["expedition"] = {"mapId": "map_01", "partyPresetId": "party_01", "partyMemberIds": ["hero_wu_xiu_01", "hero_fa_xiu_01", "hero_yi_xiu_01", "hero_qian_xiu_01"], "encounterId": "m1_boss_gate_spirit", "mapObjectId": "m1_boss_gate_spirit", "temporaryLoot": {}}
	game.set("profile", profile)
	var scene: Control = load("res://scenes/combat.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var units: Array = scene.get("units")
	var boss: Dictionary = units.filter(func(unit): return unit.get("side") == "enemy")[0]
	var ally: Dictionary = units[0]
	scene.call("_apply_damage", boss, 1700, ally, "magical", true)
	_check(boss.get("shield", 0) == 900, "Remote boss forced shield")
	for expected in [100, 60, 30, 30]:
		scene.call("_apply_skill_status", ally, boss, {"appliesStatus": {"kind": "stun", "durationTicks": 100}})
		var statuses: Array = boss.get("statuses", [])
		_check(statuses.back()["ticks"] == expected, "Boss stun diminishing returns")
	boss["statuses"] = []
	scene.call("_apply_skill_status", ally, boss, {"appliesStatus": {"kind": "root", "durationTicks": 100}})
	_check(boss.get("statuses", []).is_empty(), "Boss root immunity")
	boss["hp"] = 2000
	boss["cooldowns"] = {}
	scene.call("_resolve_command", boss, "m1_boss_rock_fist")
	_check(boss["action_max"] == 28, "Low phase incorrectly accelerates every skill")
	boss["cooldowns"] = {}
	var hp_before: int = int(ally["hp"])
	scene.call("_resolve_command", boss, "m1_boss_ground_quake")
	_check(boss.get("pending_enemy_skill", "") == "m1_boss_ground_quake" and boss["timer"] == 16, "Missing 0.8 second warning")
	_check(int(ally["hp"]) == hp_before, "Warning dealt damage before cast")
	boss.erase("pending_enemy_skill")
	scene.call("_resolve_command", boss, "m1_boss_ground_quake", -1, true)
	_check(boss["action_max"] == 30, "Low phase quake interval must be 80 percent")
	scene.queue_free()
	await process_frame
	if failures.is_empty(): print("MAP01_ADMIN_RUNTIME_OK skills=14 enemies=8 adaptation, boss mechanics, reward replay/revisit")
	quit(0 if failures.is_empty() else 1)
