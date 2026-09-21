extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message); push_error(message)
func _run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"): quit(1); return
	var repository := root.get_node("ConfigRepository")
	var game := root.get_node("Game")
	var modules: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/fixtures/map01-full-modules.json"))
	var tables: Dictionary = repository.call("_adapt_remote_modules", modules)
	check(not tables.is_empty(), "full compiled package rejected")
	if tables.is_empty(): quit(1); return
	var map: Dictionary = tables["maps"]["map_01"]
	check(absf(float(map["worldSize"][1]) - 1938.5411681914145) < 0.000001, "world height truncated")
	check(map["objects"].size() == 31 and map["positionVersion"] == 2, "map objects / continuous metadata lost")
	check(map["dynamicBlockers"].size() > 0 and map["encounterVictoryRules"].size() > 0, "state transitions lost")
	var resource: Dictionary = map["objects"].filter(func(o): return o.id == "m1_res_wood_01")[0]
	check(resource["choices"][0]["effects"]["rewards"][0]["firstAmount"] == 18, "resource first reward lost")
	check(tables["default_profile"].get("roster", []).size() == 4, "disabled new-player draft replaced working profile")
	check(tables["ling_pu"].get("jobs", []).size() > 0, "production source cleared legacy jobs")
	var embedded: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/combat_d0.json"))
	for skill in embedded.get("skills", []): check(tables["combat"]["skills"].any(func(s): return s.id == skill.id), "disabled player skill flag removed existing skill")
	var prep: Dictionary = tables["expedition"]
	check(prep["field"]["healingPercent"] == 35, "document healing percentage lost")
	check(prep["items"].size() == 3, "food incorrectly offered as equipment loadout")
	check(prep["items"].filter(func(i): return i.id == "pickaxe")[0]["weight"] == 12, "pickaxe burden lost")
	check(prep["field"]["foodItems"].filter(func(i): return i.itemId == "beast_meat")[0]["weight"] == 2, "food burden lost")
	check(prep["maps"][0]["staminaCost"] == 10 and prep["maps"][0]["minimumCarriedGrain"] == 20, "map expedition fees lost")
	var navigation := KWMapNavigation.new()
	navigation.setup(map)
	check(navigation.external_collision_polygons.size() == 36 and navigation.external_adjust_polygons.size() == 17, "remote collision geometry lost")
	check(navigation.can_walk(Vector2(450,1890)), "entry blocked")
	var changed := map.duplicate(true)
	changed["regionsDocument"]["annotations"]["layers"] = [{"id":"collision","shapes":[{"points":[{"x":0,"y":0},{"x":2488,"y":0},{"x":2488,"y":5692},{"x":0,"y":5692}]}]}]
	navigation.setup(changed)
	check(not navigation.can_walk(Vector2(450,1890)), "navigation ignored remote geometry")
	var altered: Dictionary = modules["maps"].duplicate(true)
	altered["maps"][0]["placements"][0]["x"] = 432.125
	altered["maps"][0]["entryX"] = 450.25
	var precision: Dictionary = repository.call("_adapt_maps", altered, {}, {})
	check(precision["map_01"]["objects"].any(func(o): return float(o.x) == 432.125), "placement fractional coordinates truncated")
	check(float(precision["map_01"]["entryX"]) == 450.25, "entry fractional coordinates truncated")
	repository.set("runtime_tables", tables)
	game.set("map_definitions", tables["maps"])
	game.set("map_definition", map)
	game.set("combat_config", tables["combat"])
	game.set("expedition_config", prep)
	game.set("profile", tables["default_profile"].duplicate(true))
	game.call("_normalise_profile")
	var profile: Dictionary = game.get("profile")
	var started: Dictionary = game.call("start_expedition", {"spiritGrain":20,"pickaxe":0,"lens":0}, "map_01")
	check(started.get("ok", false), "remote expedition failed")
	var hero: Dictionary = game.call("party_heroes")[0]
	hero["maxHp"] = 101
	hero["currentHp"] = 1
	profile["expedition"]["isResting"] = true
	profile["expedition"]["restHealingUsed"] = false
	check(game.call("heal_rest").get("ok", false) and hero["currentHp"] == 36, "35 percent healing must round down")
	check(not game.call("heal_rest").get("ok", false), "healing allowed twice in same rest")
	profile["expedition"]["restHealingUsed"] = false
	for member in game.call("party_heroes"): member["currentHp"] = member["maxHp"]
	check(game.call("heal_rest").get("ok", false) and profile["expedition"]["restHealingUsed"], "full HP rest must consume healing use")
	game.call("continue_rest")
	var entered: Dictionary = game.call("begin_encounter", {"id":"m1_boss_gate_spirit","encounterId":"m1_boss_gate_spirit"})
	check(entered.get("ok", false), "remote boss entry failed")
	var boss: Dictionary = game.call("get_encounter", "m1_boss_gate_spirit")
	check(game.call("finish_encounter_victory", boss).get("ok", false), "remote boss settlement failed")
	check(profile["expedition"].get("pendingEquipment", []).size() == 2, "remote boss gear missing")
	check(game.call("take_pending_encounter_loot"), "remote reward pickup failed")
	game.call("clear_active_encounter")
	check(game.call("return_to_camp").get("ok", false), "remote return failed")
	var equipment: Dictionary = profile["equipment"]["instances"]
	check(equipment.size() == 2, "remote equipment not stored")
	var qualities: Array = equipment.values().map(func(i): return i.qualityCode)
	check("fa_qi" in qualities and "zhen_bao" in qualities, "confirmed boss grades lost")
	print("MAP01_REMOTE_OK coordinates regions loadout flags boss return" if failures.is_empty() else "MAP01_REMOTE_FAILED " + str(failures))
	quit(0 if failures.is_empty() else 1)
