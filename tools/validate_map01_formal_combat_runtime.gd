extends SceneTree

const FORMAL_MAP_PATH := "res://data/maps/map_01_formal.json"
const FORMAL_COMBAT_PATH := "res://data/config/combat_map01_formal.json"
const FORMAL_SCENE := "res://scenes/maps/map_01.tscn"

var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	_check(OS.get_cmdline_user_args().has("--no-profile-write"), "validation requires --no-profile-write")
	var game := root.get_node_or_null("Game")
	var repository := root.get_node_or_null("ConfigRepository")
	_check(game != null and repository != null, "required autoloads are missing")
	if game == null or repository == null:
		_finish()
		return
	var original_profile: Dictionary = game.get("profile").duplicate(true)
	var original_definitions: Dictionary = game.get("map_definitions").duplicate(true)
	var original_map_definition: Dictionary = game.get("map_definition").duplicate(true)
	var original_combat: Dictionary = game.get("combat_config").duplicate(true)
	var formal_map: Dictionary = _load_json(FORMAL_MAP_PATH)
	formal_map["visual"]["scenePath"] = FORMAL_SCENE
	var formal_combat: Dictionary = repository.call("_load_embedded_combat", FORMAL_COMBAT_PATH)
	game.set("map_definitions", {"map_01": formal_map})
	game.set("combat_config", formal_combat)

	var combat: Control = await _spawn_combat(game, "m1_g04", "m1_g04")
	if combat != null:
		var units: Array = combat.get("units")
		var enemies: Array = units.filter(func(unit): return unit.get("side") == "enemy")
		_check(enemies.size() == 3, "multi-enemy encounter did not expand to three enemies")
		_check(combat.get("unit_hosts").has(100) and combat.get("unit_hosts").has(101) and combat.get("unit_hosts").has(102), "multi-enemy UI cards are missing")
		if enemies.size() == 3:
			var ally: Dictionary = units[0]
			combat.call("_apply_damage", enemies[0], 999999, ally, "physical", true)
			_check(not bool(combat.get("finished")), "combat ended after only one enemy died")
		combat.queue_free()
		await process_frame

	combat = await _spawn_combat(game, "m1_g02", "m1_g02")
	if combat != null:
		var wisp: Dictionary = combat.get("units").filter(func(unit): return unit.get("side") == "enemy")[0]
		combat.set("combat_ticks", 60)
		combat.call("_apply_periodic_mechanics", wisp)
		_check(int(wisp.get("shield", 0)) == 120, "碎岩灵 did not gain its periodic shield")
		combat.queue_free()
		await process_frame

	combat = await _spawn_combat(game, "m1_e01", "m1_e01")
	if combat != null:
		var units: Array = combat.get("units")
		var ally: Dictionary = units[0]
		var elite: Dictionary = units.filter(func(unit): return unit.get("side") == "enemy")[0]
		var hp_before: int = int(ally.get("hp", 0))
		for _hit in 3: combat.call("_apply_damage", elite, 1, ally, "physical", true)
		_check(int(ally.get("hp", 0)) < hp_before, "裂甲石卫 did not counter after three physical hits")
		combat.call("_apply_damage", elite, 1, ally, "physical", true)
		combat.call("_apply_damage", elite, 1, ally, "magical", true)
		_check(int(elite.get("physical_hit_count", -1)) == 0, "magical damage did not clear the elite counter")
		combat.queue_free()
		await process_frame

	combat = await _spawn_combat(game, "m1_e02", "m1_e02")
	if combat != null:
		var enemies: Array = combat.get("units").filter(func(unit): return unit.get("side") == "enemy")
		var banner: Dictionary = enemies[0]
		var corpse: Dictionary = enemies[1]
		_check(int(combat.call("_outgoing_damage_percent", corpse)) == 115, "banner aura did not increase ally damage")
		banner["dead"] = true
		banner["hp"] = 0
		_check(int(combat.call("_outgoing_damage_percent", corpse)) == 100, "banner aura remained after the banner died")
		combat.queue_free()
		await process_frame

	combat = await _spawn_combat(game, "m1_boss_gate_spirit", "m1_boss_gate_spirit")
	if combat != null:
		var units: Array = combat.get("units")
		var ally: Dictionary = units[0]
		var boss: Dictionary = units.filter(func(unit): return unit.get("side") == "enemy")[0]
		combat.call("_apply_damage", boss, 1700, ally, "magical", true)
		_check(int(boss.get("shield", 0)) == 900, "Boss did not force gold body at 75 percent")
		combat.call("_apply_damage", boss, 900, ally, "magical", true)
		_check(combat.call("_has_status", boss, "core_exposed"), "Boss core was not exposed after breaking gold body")
		combat.call("_apply_damage", boss, 300, ally, "magical", true)
		_check(bool(combat.call("_escape_available")), "Boss escape did not unlock at the 70 percent threshold")
		combat.queue_free()
		await process_frame

	game.set("profile", original_profile)
	game.set("map_definitions", original_definitions)
	game.set("map_definition", original_map_definition)
	game.set("combat_config", original_combat)
	_finish()

func _spawn_combat(game: Node, encounter_id: String, object_id: String) -> Control:
	var profile: Dictionary = game.get("default_profile").duplicate(true)
	profile["expedition"] = {
		"mapId": "map_01", "partyPresetId": "party_01",
		"partyMemberIds": ["hero_wu_xiu_01", "hero_fa_xiu_01", "hero_yi_xiu_01", "hero_qian_xiu_01"],
		"encounterId": encounter_id, "mapObjectId": object_id,
		"position": {"x": 24, "y": 2}, "remainingGrain": 100, "grainCapacity": 100,
		"grainDepletionSteps": 0, "carriedItems": {}, "restUsesRemaining": 1,
		"isResting": false, "restHealingUsed": false, "revealedTiles": [], "temporaryLoot": {},
		"pendingEncounterLoot": [], "pendingEncounterSoulCrystal": 0,
	}
	game.set("profile", profile)
	var packed := load("res://scenes/combat.tscn") as PackedScene
	_check(packed != null, "combat scene is missing")
	if packed == null: return null
	var combat := packed.instantiate() as Control
	_check(combat != null, "combat scene could not instantiate")
	if combat == null: return null
	root.add_child(combat)
	await process_frame
	await process_frame
	_check(str(combat.get("current_encounter").get("id", "")) == encounter_id, "combat loaded the wrong encounter")
	return combat

func _load_json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		_check(false, "invalid JSON: %s" % path)
		return {}
	return parsed

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _finish() -> void:
	if failures.is_empty():
		print("MAP01_FORMAL_COMBAT_RUNTIME_OK multi_enemy=ok slow_shield_poison_silence=bound elite_mechanics=ok boss_phases=ok")
		quit(0)
		return
	for failure in failures: push_error(failure)
	print("MAP01_FORMAL_COMBAT_RUNTIME_FAILED errors=%d" % failures.size())
	quit(1)
