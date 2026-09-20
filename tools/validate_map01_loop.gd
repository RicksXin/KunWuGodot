extends SceneTree
var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value: failures.append(message); push_error(message)

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		quit(1)
		return
	var game := root.get_node("Game")
	var repository := root.get_node("ConfigRepository")
	var rules: Dictionary = game.call("loop_rules")
	check(rules.get("encounterBindings", {}).size() == 13, "13 design bindings")
	var formal: Dictionary = repository.call("formal_map_combat")
	check(formal.get("encounters", []).size() == 14, "14 formal encounters")
	for binding in rules.get("encounterBindings", {}).values():
		check(formal["encounters"].any(func(e): return e.get("id") == binding), "unbound map encounter")
	game.set("combat_config", formal)
	var profile: Dictionary = game.get("default_profile").duplicate(true)
	profile["lootSeed"] = "map01-loop-test"
	game.set("profile", profile)
	game.call("_normalise_profile")
	var first: Dictionary = game.call("get_encounter", "m1_g01")
	check(first["enemies"].size() == 1 and first["enemies"][0]["definitionId"] == "m1_rubble_rat", "new composition not applied")
	check(first["firstSoulCrystalReward"] == 24 and first["repeatSoulCrystalReward"] == 12, "new rewards not applied")
	var started: Dictionary = game.call("start_expedition", {"spiritGrain":20,"pickaxe":0,"lens":0}, "map_01")
	check(started.get("ok", false), "start expedition")
	var entered: Dictionary = game.call("begin_encounter", {"id":"m1_boss_gate_spirit","encounterId":"m1_boss_gate_spirit"})
	check(entered.get("ok", false), "begin boss")
	var boss: Dictionary = game.call("get_encounter", "m1_boss_gate_spirit")
	var result: Dictionary = game.call("finish_encounter_victory", boss)
	check(result.get("ok", false), "boss settlement")
	var expedition: Dictionary = profile["expedition"]
	var generated: Array = expedition.get("pendingEquipment", []).duplicate(true)
	check(generated.size() == 2, "must generate exactly two equipment instances")
	if generated.size() != 2:
		quit(1)
		return
	check(generated[0]["qualityCode"] == "fa_qi" and generated[1]["qualityCode"] == "zhen_bao", "confirmed grades")
	check(generated[0]["instanceId"] != generated[1]["instanceId"], "unique instances")
	check(not generated[0].has("level") and generated[0]["runes"].size() == 2, "runes/no equipment level")
	var duplicate: Dictionary = game.call("finish_encounter_victory", boss)
	check(duplicate.get("alreadySettled", false) and expedition["pendingEquipment"] == generated, "duplicate rerolled rewards")
	check(game.call("take_pending_encounter_loot"), "claim equipment")
	check(expedition["temporaryEquipment"].size() == 2, "temporary equipment bag")
	game.call("clear_active_encounter")
	check(game.call("return_to_camp").get("ok", false), "safe return")
	var state := KWEquipment.ensure(profile)
	check(state["instances"].size() == 2 and profile["expedition"] == null, "equipment warehouse after return")
	for item in generated:
		var eligible: Array = profile["roster"].filter(func(h): return item["careers"].is_empty() or h.get("careerId") in item["careers"])
		check(not eligible.is_empty(), "equipment has no eligible career")
		var hero: Dictionary = eligible[0]
		var before: Dictionary = hero["attributes"].duplicate()
		var equipped: Dictionary = game.call("equip_item", hero["instanceId"], item["instanceId"], item["slot"])
		check(equipped.get("ok", false), "equip generated reward")
		for attribute in item["stats"]: check(hero["attributes"][attribute] >= before[attribute], "attribute bonus missing")
		var once: Dictionary = hero["attributes"].duplicate()
		game.call("equip_item", hero["instanceId"], item["instanceId"], item["slot"])
		check(hero["attributes"] == once, "equip compounds bonuses")
		game.call("unequip_item", hero["instanceId"], item["slot"])
		for attribute in KWEquipment.ATTRIBUTES: check(int(hero["attributes"][attribute]) == int(before[attribute]), "unequip must restore base attributes")
	# Space overflow must be retained; repeated grants must not duplicate.
	var overflow := {"equipment":{"instances":{},"pending":{},"loadouts":{}}}
	KWEquipment.store(overflow, generated, 1)
	KWEquipment.store(overflow, generated, 1)
	check(overflow["equipment"]["instances"].size() == 1 and overflow["equipment"]["pending"].size() == 1, "overflow or duplicate grant")
	# Loss applies only to this trip's temporary ordinary loot; inputs from camp survive.
	profile["expedition"] = {"mapId":"map_01","partyMemberIds":[],"carriedItems":{"pickaxe":3},"temporaryLoot":{"beast_hide":4,"stone_spirit_core":1},"temporaryEquipment":generated,"settlementSeed":"loss-fixed"}
	var old_pickaxes := int(profile["inventory"].get("pickaxe", 0))
	var old_hide := int(profile["inventory"].get("beast_hide", 0))
	var old_core := int(profile["inventory"].get("stone_spirit_core", 0))
	check(game.call("_finish_expedition", true), "defeat settlement")
	check(profile["inventory"]["pickaxe"] == old_pickaxes + 3, "brought supplies were lost")
	check(profile["inventory"]["beast_hide"] == old_hide + 2, "ceil 30 percent material loss")
	check(profile["inventory"]["stone_spirit_core"] == old_core + 1, "quest core lost")
	check(KWEquipment.retained_equipment(generated, "loss-fixed") == KWEquipment.retained_equipment(generated, "loss-fixed"), "equipment loss rerolled")
	check(not game.call("_finish_expedition", true), "return reward duplicated")
	var failing: Node = load("res://tools/fixtures/failing_profile_game.gd").new()
	failing.profile = profile.duplicate(true)
	failing.profile["expedition"] = {"mapId":"map_01","partyMemberIds":[],"temporaryLoot":{"beast_hide":4},"temporaryEquipment":generated,"settlementSeed":"loss-fixed"}
	var prior: Dictionary = failing.profile.duplicate(true)
	check(not failing._finish_expedition(true), "write failure must fail settlement")
	check(failing.profile == prior, "failed save did not restore entire profile")
	failing.free()
	var panel: Control = load("res://scripts/ui/equipment_panel.gd").new()
	root.add_child(panel)
	await process_frame
	check(panel.get_child_count() > 0, "equipment UI did not build")
	panel.queue_free()
	await process_frame
	if failures.is_empty(): print("MAP01_LOOP_OK bindings=13 encounters=14 boss_grades=2 equip/unequip replay return loss overflow UI")
	quit(0 if failures.is_empty() else 1)
