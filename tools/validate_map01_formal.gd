extends SceneTree

const MAP_PATH := "res://data/maps/map_01_formal.json"
const COMBAT_PATH := "res://data/config/combat_map01_formal.json"
const MANIFEST_PATH := "res://data/maps/map_01_manifest.json"
const SCENE_PATH := "res://scenes/maps/map_01.tscn"
const SCRIPT_PATH := "res://scripts/maps/map01_runtime.gd"
const BACKGROUND_PATH := "res://assets/maps/map_01/map01_background.png"
const BACKGROUND_SHA256 := "9a7979e2bdd8beecbfc10705955ee4b5b96c4f7646e296c4d10ccd92c8ae0618"
const WIDTH := 28
const HEIGHT := 64
const TILE_SIZE := 48
const ENTRY := Vector2i(13, 6)

var failures: Array[String] = []


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(OS.get_cmdline_user_args().has("--no-profile-write"), "validation requires --no-profile-write")
	_check(OS.get_cmdline_user_args().has("--ignore-config-cache"), "validation requires --ignore-config-cache")
	var map_data := _load_json(MAP_PATH)
	var manifest := _load_json(MANIFEST_PATH)
	var repository := root.get_node_or_null("ConfigRepository")
	var game := root.get_node_or_null("Game")
	_check(repository != null and game != null, "required autoloads are missing")
	var combat: Dictionary = repository.call("_load_embedded_combat", COMBAT_PATH) if repository != null else {}
	_validate_manifest(manifest)
	_validate_map_data(map_data, combat)
	_validate_scene()
	if game != null:
		_validate_game_runtime(game, map_data)
	_finish()


func _validate_manifest(manifest: Dictionary) -> void:
	_check(str(manifest.get("mapId", "")) == "map_01", "manifest mapId is not map_01")
	_check(str(manifest.get("status", "")) == "formal", "manifest is not formal")
	_check(str(manifest.get("mapDataPath", "")) == MAP_PATH, "manifest map path changed")
	_check(str(manifest.get("combatDataPath", "")) == COMBAT_PATH, "manifest combat path changed")
	_check(str(manifest.get("layoutScenePath", "")) == SCENE_PATH, "manifest scene path changed")
	_check(str(manifest.get("backgroundPath", "")) == BACKGROUND_PATH, "manifest background path changed")
	_check(str(manifest.get("backgroundSha256", "")) == BACKGROUND_SHA256, "manifest background hash changed")
	_check(str(manifest.get("renderMode", "")) == "hd_background_json_grid", "manifest render mode changed")
	_check(int(manifest.get("width", 0)) == WIDTH and int(manifest.get("height", 0)) == HEIGHT, "manifest size is not 28x64")
	_check(int(manifest.get("logicalTileSize", 0)) == TILE_SIZE, "manifest logical tile size is not 48")


func _validate_map_data(map_data: Dictionary, combat: Dictionary) -> void:
	_check(str(map_data.get("id", "")) == "map_01" and str(map_data.get("mapId", "")) == "map_01", "formal map identity changed")
	_check(str(map_data.get("status", "")) == "formal", "map data is not formal")
	_check(int(map_data.get("width", 0)) == WIDTH and int(map_data.get("height", 0)) == HEIGHT, "map size is not 28x64")
	_check(int(map_data.get("activeWidth", 0)) == WIDTH and int(map_data.get("activeHeight", 0)) == HEIGHT, "active size is not 28x64")
	_check(Vector2i(int(map_data.get("entryX", -1)), int(map_data.get("entryY", -1))) == ENTRY, "entry is not (13,6)")
	var visual: Dictionary = map_data.get("visual", {})
	_check(str(visual.get("scenePath", "")) == SCENE_PATH, "map visual scene path changed")
	_check(str(visual.get("backgroundPath", "")) == BACKGROUND_PATH, "map visual background path changed")
	_check(str(visual.get("renderMode", "")) == "hd_background_json_grid", "map visual render mode changed")
	_check(int(visual.get("logicalTileSize", 0)) == TILE_SIZE, "map logical tile size is not 48")
	var rows: Array = map_data.get("terrainRows", [])
	_check(rows.size() == HEIGHT and rows.all(func(row): return str(row).length() == WIDTH), "terrainRows shape is invalid")
	var walkable := 0
	var blocked := 0
	var entries := 0
	for row in rows:
		walkable += str(row).count(".") + str(row).count("~")
		blocked += str(row).count("#")
		entries += str(row).count("E")
	_check(walkable + entries == 834 and blocked == 958 and entries == 1, "terrain counts changed")
	_check(_base_symbol(rows, ENTRY.x, ENTRY.y) == "E", "entry symbol is missing")
	var objects: Array = map_data.get("objects", [])
	_check(objects.size() == 31, "formal object count is not 31")
	var object_ids: Dictionary = {}
	var direct_encounters := 0
	var encounter_ids: Dictionary = {}
	for encounter in combat.get("encounters", []):
		encounter_ids[str(encounter.get("id", ""))] = true
	for raw_object in objects:
		var object: Dictionary = raw_object
		var object_id := str(object.get("id", ""))
		_check(not object_id.is_empty() and not object_ids.has(object_id), "object id is empty or duplicated: %s" % object_id)
		object_ids[object_id] = true
		var cell := Vector2i(int(object.get("x", -1)), int(object.get("y", -1)))
		_check(_base_symbol(rows, cell.x, cell.y) != "#", "object is outside walkable terrain: %s" % object_id)
		var encounter_id := str(object.get("encounterId", object.get("enemyId", "")))
		if not encounter_id.is_empty():
			direct_encounters += 1
			_check(encounter_ids.has(encounter_id), "object references missing encounter: %s" % encounter_id)
	_check(direct_encounters == 13, "direct battle marker count is not 13")
	_check(combat.get("encounters", []).size() == 14, "expanded encounter count is not 14")
	var blockers: Array = map_data.get("dynamicBlockers", [])
	_check(blockers.size() == 7, "dynamic blocker count is not 7")
	var blocker_cells: Dictionary = {}
	for blocker in blockers:
		var cell := Vector2i(int(blocker.get("x", -1)), int(blocker.get("y", -1)))
		blocker_cells[cell] = str(blocker.get("stateKey", ""))
		_check(_base_symbol(rows, cell.x, cell.y) != "#", "dynamic blocker is not on base walkable terrain")
	_check(str(blocker_cells.get(Vector2i(12, 25), "")) == "map_01.events.m1_dungeon_tunnel.resolved", "tunnel blocker changed")
	for x in range(10, 16):
		_check(str(blocker_cells.get(Vector2i(x, 57), "")) == "map_01.encounters.m1_boss_gate_spirit.defeated", "gate blocker changed at x=%d" % x)
	var serialized := JSON.stringify(map_data)
	for forbidden in ["scheme2", "candidate", "方案2", "preview", "demo"]:
		_check(not serialized.to_lower().contains(forbidden.to_lower()), "formal map still contains draft token: %s" % forbidden)


func _validate_scene() -> void:
	_check(FileAccess.file_exists(BACKGROUND_PATH), "formal background is missing")
	_check(FileAccess.get_sha256(BACKGROUND_PATH) == BACKGROUND_SHA256, "formal background hash changed")
	var packed := load(SCENE_PATH) as PackedScene
	_check(packed != null, "formal scene could not load")
	if packed == null:
		return
	var instance := packed.instantiate() as Node2D
	_check(instance != null, "formal scene could not instantiate")
	if instance == null:
		return
	_check(instance.name == "Map01", "formal scene root name changed")
	_check(int(instance.get("active_width")) == WIDTH and int(instance.get("active_height")) == HEIGHT, "formal scene size is not 28x64")
	_check(instance.get_script() != null and instance.get_script().resource_path == SCRIPT_PATH, "formal scene script changed")
	var background := instance.get_node_or_null("HDBackground") as Sprite2D
	_check(background != null and background.texture != null, "formal HD background node is missing")
	if background != null and background.texture != null:
		_check(background.texture.resource_path == BACKGROUND_PATH, "formal scene uses the wrong background")
		_check(background.texture.get_width() == WIDTH * TILE_SIZE and background.texture.get_height() == HEIGHT * TILE_SIZE, "formal background size is not 1344x3072")
	instance.free()


func _validate_game_runtime(game: Node, map_data: Dictionary) -> void:
	var original_profile: Dictionary = game.get("profile").duplicate(true)
	var original_definitions: Dictionary = game.get("map_definitions").duplicate(true)
	var original_definition: Dictionary = game.get("map_definition").duplicate(true)
	var original_suppress := bool(game.get("suppress_profile_writes"))
	var profile: Dictionary = game.get("default_profile").duplicate(true)
	profile["mapStates"] = {}
	profile["expedition"] = {
		"mapId": "map_01",
		"position": {"x": ENTRY.x, "y": ENTRY.y},
		"revealedTiles": [],
	}
	game.set("suppress_profile_writes", true)
	game.set("profile", profile)
	game.set("map_definitions", {"map_01": map_data})
	game.set("map_definition", map_data)
	var resolved: Dictionary = game.call("get_map_definition", "map_01")
	_check(int(resolved.get("activeWidth", 0)) == WIDTH and resolved.get("terrainRows", []).size() == HEIGHT, "Game did not load JSON terrainRows")
	_check(not resolved.has("layoutSource"), "Game still derives layout from an obsolete scene source")
	_check(bool(game.call("tile_at", ENTRY.x, ENTRY.y).get("walkable", false)), "entry is not walkable at runtime")
	_check(not bool(game.call("tile_at", 12, 25).get("walkable", true)), "unresolved tunnel blocker is passable")
	game.call("_set_map_state_in_profile", "map_01.events.m1_dungeon_tunnel.resolved", true)
	_check(bool(game.call("tile_at", 12, 25).get("walkable", false)), "resolved tunnel blocker did not open")
	_check(not bool(game.call("tile_at", 13, 57).get("walkable", true)), "undefeated Boss gate is passable")
	game.call("_set_map_state_in_profile", "map_01.encounters.m1_boss_gate_spirit.defeated", true)
	_check(bool(game.call("tile_at", 13, 57).get("walkable", false)), "defeated Boss gate did not open")
	game.set("profile", original_profile)
	game.set("map_definitions", original_definitions)
	game.set("map_definition", original_definition)
	game.set("suppress_profile_writes", original_suppress)


func _base_symbol(rows: Array, x: int, y: int) -> String:
	if x < 0 or x >= WIDTH or y < 0 or y >= HEIGHT or rows.size() != HEIGHT:
		return "#"
	return str(rows[HEIGHT - 1 - y]).substr(x, 1)


func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		_check(false, "missing JSON: %s" % path)
		return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not value is Dictionary:
		_check(false, "invalid JSON: %s" % path)
		return {}
	return value


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)


func _finish() -> void:
	if failures.is_empty():
		print("MAP01_FORMAL_VALIDATION_OK size=28x64 walkable=834 blocked=958 objects=31 encounters=14 blockers=7")
		quit(0)
		return
	for failure in failures:
		push_error(failure)
	print("MAP01_FORMAL_VALIDATION_FAILED errors=%d" % failures.size())
	quit(1)
