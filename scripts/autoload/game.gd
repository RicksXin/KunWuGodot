extends Node

signal state_changed
signal feedback(message: String, severity: int)

const PROFILE_PATH := "user://kunwu_profile.json"
const PROFILE_TMP_PATH := "user://kunwu_profile.tmp"
const DEFAULT_PROFILE_PATH := "res://data/config/default_profile.json"
const CONFIG_ROOT := "res://data/config/"

var profile: Dictionary = {}
var localization: Dictionary = {}
var expedition_config: Dictionary = {}
var ling_pu_config: Dictionary = {}
var combat_config: Dictionary = {}
var default_profile: Dictionary = {}
var map_definitions: Dictionary = {}
var map_definition: Dictionary = {}
var asset_definitions: Dictionary = {}
var loaded_from_save := false
var suppress_profile_writes := false

func _ready() -> void:
	# Tool scripts and editor scans are validation contexts, never gameplay.
	# They must not settle elapsed production into the user's real save file.
	suppress_profile_writes = Engine.is_editor_hint() \
		or OS.get_cmdline_args().has("--script") \
		or OS.get_cmdline_user_args().has("--no-profile-write")
	_load_json_tables()
	_load_profile()
	map_definition = get_map_definition()
	settle_production()

func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("无法读取数据: " + path)
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}

func _load_json_tables() -> void:
	localization = ConfigRepository.table("localization").duplicate(true)
	expedition_config = ConfigRepository.table("expedition").duplicate(true)
	ling_pu_config = ConfigRepository.table("ling_pu").duplicate(true)
	combat_config = ConfigRepository.table("combat").duplicate(true)
	default_profile = ConfigRepository.table("default_profile").duplicate(true)
	map_definitions = ConfigRepository.table("maps").duplicate(true)
	asset_definitions = {}
	for asset in ConfigRepository.table("assets"):
		asset_definitions[str(asset.get("code", ""))] = asset
	map_definition = get_map_definition(get_active_map_id())

func refresh_remote_config() -> Dictionary:
	var result: Dictionary = await ConfigRepository.refresh_remote()
	if result.get("ok", false):
		_load_json_tables()
		if not loaded_from_save:
			profile = default_profile.duplicate(true)
		_normalise_profile()
	return result

func _load_profile() -> void:
	var source: Variant = null
	if FileAccess.file_exists(PROFILE_PATH):
		var file := FileAccess.open(PROFILE_PATH, FileAccess.READ)
		if file:
			source = JSON.parse_string(file.get_as_text())
	if source is Dictionary and source.has("profile"):
		source = source["profile"]
	if not source is Dictionary or source.is_empty():
		profile = default_profile.duplicate(true)
		loaded_from_save = false
	else:
		profile = source.duplicate(true)
		loaded_from_save = true
	_normalise_profile()

func _normalise_profile() -> void:
	var defaults: Dictionary = default_profile if not default_profile.is_empty() else _load_json(DEFAULT_PROFILE_PATH)
	_merge_missing(profile, defaults)
	if not profile.get("camp", {}).has("workerCount"):
		profile["camp"]["workerCount"] = 6
	if not profile.get("camp", {}).has("resourceStorageLevels"):
		profile["camp"]["resourceStorageLevels"] = {"spiritGrain": 1, "spiritWood": 1, "darkIron": 1}
	if not profile.has("completedMapObjects"):
		profile["completedMapObjects"] = {}
	if not profile.has("expeditionPreparation"):
		profile["expeditionPreparation"] = defaults["expeditionPreparation"].duplicate(true)
	if not profile["expeditionPreparation"].has("loadout"):
		profile["expeditionPreparation"]["loadout"] = {"spiritGrain": 60, "pickaxe": 0, "lens": 0}
	if not profile.has("expedition"):
		profile["expedition"] = null
	if profile["expedition"] is Dictionary:
		if not profile["expedition"].has("encounterId"): profile["expedition"]["encounterId"] = ""
		if not profile["expedition"].has("mapObjectId"): profile["expedition"]["mapObjectId"] = ""
	for hero in profile.get("roster", []):
		if not hero.has("stamina"): hero["stamina"] = 100
		if not hero.has("isDead"): hero["isDead"] = false

func _merge_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults:
		if not target.has(key):
			target[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary else defaults[key]
		elif target[key] is Dictionary and defaults[key] is Dictionary:
			_merge_missing(target[key], defaults[key])

func save_profile() -> bool:
	if suppress_profile_writes:
		emit_signal("state_changed")
		return true
	var payload := JSON.stringify(profile, "\t")
	var tmp := FileAccess.open(PROFILE_TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		emit_signal("feedback", "存档写入失败", 3)
		return false
	tmp.store_string(payload)
	tmp.close()
	if FileAccess.file_exists(PROFILE_PATH):
		DirAccess.remove_absolute(PROFILE_PATH)
	DirAccess.rename_absolute(PROFILE_TMP_PATH, PROFILE_PATH)
	emit_signal("state_changed")
	return true

func reset_profile() -> void:
	profile = default_profile.duplicate(true)
	_normalise_profile()
	loaded_from_save = false
	save_profile()

func text(key: String, fallback: String = "") -> String:
	if localization.has(key): return str(localization[key])
	return fallback if not fallback.is_empty() else key

func now() -> int:
	return int(Time.get_unix_time_from_system())

func wallet_value(id: String) -> int:
	return int(profile.get("wallet", {}).get(id, 0))

func resource_label(id: String) -> String:
	return text("resource." + _resource_key(id), id)

func _resource_key(id: String) -> String:
	return {"spiritGrain": "spirit_grain", "spiritWood": "spirit_wood", "darkIron": "dark_iron", "spiritStone": "spirit_stone", "gengJing": "geng_jing", "soulCrystal": "soul_crystal", "immortalCoin": "immortal_coin"}.get(id, id)

func settle_production() -> void:
	var camp: Dictionary = profile.get("camp", {})
	var anchor := int(camp.get("lastSettledAtUtc", 0))
	var current := now()
	if anchor <= 0:
		camp["lastSettledAtUtc"] = current
		return
	var cycle_seconds := maxi(1, int(ling_pu_config.get("baseCycleSeconds", 30)))
	var cycles := clampi(int((current - anchor) / float(cycle_seconds)), 0, int(ling_pu_config.get("maxOfflineCycles", 960)))
	if cycles <= 0: return
	var assignment: Dictionary = camp.get("workerAssignments", {})
	var grain := wallet_value("spiritGrain")
	var jobs: Array = ling_pu_config.get("jobs", [])
	var jobs_by_id: Dictionary = {}
	for job in jobs: jobs_by_id[str(job.get("id", ""))] = job
	var grain_job: Dictionary = jobs_by_id.get("spiritGrain", {})
	var grain_produced := cycles * int(assignment.get("spiritGrain", 0)) * int(grain_job.get("outputPerWorker", 1))
	var available := grain + grain_produced
	var consumers: Array = jobs.filter(func(job): return int(job.get("upkeepPerWorker", 0)) > 0)
	consumers.sort_custom(func(left, right): return int(left.get("shutdownPriority", 0)) < int(right.get("shutdownPriority", 0)))
	var upkeep := 0
	for job in consumers: upkeep += int(assignment.get(str(job.get("id", "")), 0)) * int(job.get("upkeepPerWorker", 0))
	var shutdown: Array[String] = []
	for job in consumers:
		if upkeep * cycles <= available: break
		var job_id := str(job.get("id", ""))
		var workers := int(assignment.get(job_id, 0))
		if workers > 0:
			shutdown.append(job_id)
			upkeep -= workers * int(job.get("upkeepPerWorker", 0))
	for job in consumers:
		var job_id := str(job.get("id", ""))
		if not shutdown.has(job_id):
			var output_asset := str(job.get("outputAssetCode", job_id))
			var base_stock := wallet_value(output_asset)
			var next_stock := base_stock + cycles * int(assignment.get(job_id, 0)) * int(job.get("outputPerWorker", 1))
			profile["wallet"][output_asset] = maxi(base_stock, mini(resource_capacity(output_asset), next_stock))
	var next_grain := maxi(0, grain + grain_produced - upkeep * cycles)
	profile["wallet"]["spiritGrain"] = maxi(grain, mini(resource_capacity("spiritGrain"), next_grain))
	camp["lastSettledAtUtc"] = anchor + cycles * cycle_seconds
	profile["camp"] = camp
	_save_quietly()

func _save_quietly() -> void:
	if suppress_profile_writes:
		return
	var payload := JSON.stringify(profile, "\t")
	var file := FileAccess.open(PROFILE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(payload)
		file.close()

func resource_capacity(job: String) -> int:
	var levels: Dictionary = profile.get("camp", {}).get("resourceStorageLevels", {})
	var level := int(levels.get(job, 1))
	var resource: Dictionary = ling_pu_config.get("resources", {}).get(job, {})
	var capacities: Array = resource.get("capacities", [999999])
	return int(capacities[clampi(level - 1, 0, capacities.size() - 1)])

func adjust_workers(job: String, delta: int) -> bool:
	settle_production()
	var camp: Dictionary = profile["camp"]
	var assignments: Dictionary = camp["workerAssignments"]
	var current := int(assignments.get(job, 0))
	var total := 0
	for key in assignments: total += int(assignments[key])
	if delta < 0 and current <= 0: return false
	if delta > 0 and total >= int(camp["workerCount"]): return false
	assignments[job] = current + delta
	camp["workerAssignments"] = assignments
	profile["camp"] = camp
	save_profile()
	return true

func recruit_workers() -> bool:
	settle_production()
	var cost := int(ling_pu_config.get("recruitSpiritGrainCost", 50))
	if wallet_value("spiritGrain") < cost: return false
	profile["wallet"]["spiritGrain"] -= cost
	profile["camp"]["workerCount"] = int(profile["camp"].get("workerCount", 6)) + int(ling_pu_config.get("workersPerRecruit", 5))
	save_profile()
	return true

func upgrade_storage(job: String) -> bool:
	settle_production()
	var levels: Dictionary = profile["camp"].get("resourceStorageLevels", {})
	var resource: Dictionary = ling_pu_config.get("resources", {}).get(job, {})
	var level := int(levels.get(job, 1))
	var costs: Array = resource.get("upgradeSpiritWoodCosts", [])
	if level >= resource.get("capacities", []).size() or level - 1 >= costs.size(): return false
	var cost := int(costs[level - 1])
	if wallet_value("spiritWood") < cost: return false
	profile["wallet"]["spiritWood"] -= cost
	levels[job] = level + 1
	profile["camp"]["resourceStorageLevels"] = levels
	save_profile()
	return true

func get_party_preset(preset_id: String = "") -> Dictionary:
	var preparation: Dictionary = profile.get("expeditionPreparation", {})
	var target_id := preset_id
	if target_id.is_empty():
		target_id = str(profile.get("expedition", {}).get("partyPresetId", preparation.get("activePresetId", "")))
	for preset in preparation.get("partyPresets", []):
		if str(preset.get("presetId", "")) == target_id: return preset
	return {}

func party_heroes(preset_id: String = "") -> Array:
	var ids: Array = []
	var expedition: Variant = profile.get("expedition")
	if expedition is Dictionary and not expedition.is_empty() and preset_id.is_empty():
		ids = expedition.get("partyMemberIds", [])
	else:
		ids = get_party_preset(preset_id).get("slots", [])
	var result: Array = []
	for id in ids:
		for hero in profile.get("roster", []):
			if hero.get("instanceId") == id: result.append(hero)
	return result

func get_map_definition(map_id: String = "") -> Dictionary:
	var target_id := map_id if not map_id.is_empty() else get_active_map_id()
	return map_definitions.get(target_id, {})

func get_expedition_map_rule(map_id: String = "") -> Dictionary:
	var target_id := map_id if not map_id.is_empty() else get_active_map_id()
	for map_rule in expedition_config.get("maps", []):
		if str(map_rule.get("mapId", "")) == target_id: return map_rule
	return {}

func get_encounter(encounter_id: String = "") -> Dictionary:
	var target_id := encounter_id if not encounter_id.is_empty() else get_active_encounter_id()
	for encounter in combat_config.get("encounters", []):
		if str(encounter.get("id", "")) == target_id: return encounter
	return {}

func get_enemy(encounter_id: String, enemy_id: String = "") -> Dictionary:
	var encounter := get_encounter(encounter_id)
	for enemy in encounter.get("enemies", []):
		if enemy_id.is_empty() or str(enemy.get("id", "")) == enemy_id or str(enemy.get("definitionId", "")) == enemy_id:
			return enemy
	return {}

func get_active_map_id() -> String:
	var expedition: Variant = profile.get("expedition")
	if expedition is Dictionary and not expedition.is_empty(): return str(expedition.get("mapId", ""))
	return ConfigRepository.default_map_id()

func get_active_encounter_id() -> String:
	var expedition: Variant = profile.get("expedition")
	if not expedition is Dictionary: return ""
	var encounter_id := str(expedition.get("encounterId", ""))
	if not encounter_id.is_empty(): return encounter_id
	var candidates: Array[String] = []
	for object in get_map_definition().get("objects", []):
		var candidate := str(object.get("encounterId", object.get("enemyId", "")))
		if not candidate.is_empty() and not candidates.has(candidate): candidates.append(candidate)
	return candidates.front() if candidates.size() == 1 else ""

func get_active_map_object_id() -> String:
	var expedition: Variant = profile.get("expedition")
	if not expedition is Dictionary: return ""
	var object_id := str(expedition.get("mapObjectId", ""))
	if not object_id.is_empty(): return object_id
	var encounter_id := get_active_encounter_id()
	var candidates: Array[String] = []
	for object in get_map_definition().get("objects", []):
		if str(object.get("encounterId", object.get("enemyId", ""))) == encounter_id:
			candidates.append(str(object.get("id", "")))
	return candidates.front() if candidates.size() == 1 else ""

func map_object_key(map_id: String, object_id: String) -> String:
	return "%s.%s" % [map_id, object_id]

func item_weight(item_id: String) -> int:
	if asset_definitions.has(item_id): return int(asset_definitions[item_id].get("weight", 0))
	for item in expedition_config.get("items", []):
		if str(item.get("id", "")) == item_id or str(item.get("inventoryId", "")) == item_id: return int(item.get("weight", 0))
	for food in expedition_config.get("field", {}).get("foodItems", []):
		if str(food.get("itemId", "")) == item_id: return int(food.get("weight", expedition_config.get("field", {}).get("defaultLootWeight", 1)))
	return int(expedition_config.get("field", {}).get("defaultLootWeight", 1))

func expedition_burden_limit(heroes: Array) -> int:
	var limit := int(expedition_config.get("baseBurden", 60))
	var strength_factor := int(expedition_config.get("strengthBurdenFactor", 2))
	var constitution_factor := int(expedition_config.get("constitutionBurdenFactor", 1))
	for hero in heroes:
		var attributes: Dictionary = hero.get("attributes", {})
		limit += int(attributes.get("strength", 0)) * strength_factor + int(attributes.get("constitution", 0)) * constitution_factor
	return limit

func start_expedition(loadout: Dictionary = {}, map_id: String = "") -> Dictionary:
	if profile.get("expedition") != null: return {"ok": false, "message": "当前已有一段入山进度"}
	var prep: Dictionary = profile["expeditionPreparation"]
	var preset_id := str(prep.get("activePresetId", ""))
	var preset := get_party_preset(preset_id)
	if preset.is_empty(): return {"ok": false, "message": "当前队伍预设不存在"}
	var ids: Array = preset.get("slots", []).filter(func(v): return v != null)
	var heroes := party_heroes(preset_id)
	if ids.is_empty(): return {"ok": false, "message": "至少选择一名存活修士"}
	var target_map_id := map_id if not map_id.is_empty() else ConfigRepository.default_map_id()
	var target_map := get_map_definition(target_map_id)
	var map_rule := get_expedition_map_rule(target_map_id)
	if target_map.is_empty() or map_rule.is_empty(): return {"ok": false, "message": "所选地图配置不可用"}
	var unlock_value: Variant = map_rule.get("unlockFlag", "")
	var unlock_flag := "" if unlock_value == null else str(unlock_value)
	if not unlock_flag.is_empty() and not bool(profile.get("storyFlags", {}).get(unlock_flag, false)):
		return {"ok": false, "message": "所选地图尚未解锁"}
	var map_cost := int(map_rule.get("staminaCost", 0))
	for hero in heroes:
		if hero.get("isDead", false): return {"ok": false, "message": "队伍中有阵亡修士"}
		if int(hero.get("stamina", 0)) < map_cost: return {"ok": false, "message": "有修士灵息不足"}
	var grain := int(loadout.get("spiritGrain", prep.get("loadout", {}).get("spiritGrain", 60)))
	var minimum_grain := int(map_rule.get("minimumCarriedGrain", 0))
	grain = clampi(grain, minimum_grain, wallet_value("spiritGrain"))
	if wallet_value("spiritGrain") < grain: return {"ok": false, "message": "灵粮不足"}
	var pickaxe := clampi(int(loadout.get("pickaxe", prep.get("loadout", {}).get("pickaxe", 0))), 0, int(profile.get("inventory", {}).get("pickaxe", 0)))
	var lens := clampi(int(loadout.get("lens", prep.get("loadout", {}).get("lens", 0))), 0, int(profile.get("inventory", {}).get("lens", 0)))
	var burden_limit := expedition_burden_limit(heroes)
	var burden := grain * item_weight("spiritGrain") + pickaxe * item_weight("pickaxe") + lens * item_weight("lens")
	if burden > burden_limit: return {"ok": false, "message": "携带物资超过队伍负重上限"}
	profile["wallet"]["spiritGrain"] -= grain
	profile["inventory"]["pickaxe"] = int(profile["inventory"].get("pickaxe", 0)) - pickaxe
	profile["inventory"]["lens"] = int(profile["inventory"].get("lens", 0)) - lens
	prep["loadout"] = {"spiritGrain": grain, "pickaxe": pickaxe, "lens": lens}
	profile["expeditionPreparation"] = prep
	for hero in heroes: hero["stamina"] = int(hero.get("stamina", 100)) - map_cost
	# 每次新的入山只重置当前地图的普通遭遇，宝箱和剧情对象保持永久状态。
	for object in target_map.get("objects", []):
		if str(object.get("refreshType", "permanent")) == "per_expedition" or str(object.get("kind", "")) == "enemy_group":
			profile["completedMapObjects"].erase(map_object_key(target_map_id, str(object.get("id", ""))))
	var entry := {"x": int(target_map.get("entryX", 2)), "y": int(target_map.get("entryY", 2))}
	var discovery_radius := int(map_rule.get("discoveryRadius", 2))
	profile["expedition"] = {
		"mapId": target_map_id, "partyPresetId": preset_id, "partyMemberIds": ids,
		"encounterId": "", "mapObjectId": "",
		"position": entry, "remainingGrain": grain, "grainCapacity": grain,
		"grainDepletionSteps": 0, "carriedItems": {"pickaxe": pickaxe, "lens": lens}, "restUsesRemaining": int(map_rule.get("restCount", 1)),
		"isResting": false, "restHealingUsed": false,
		"revealedTiles": _reveal([], entry, discovery_radius), "temporaryLoot": {}
	}
	map_definition = target_map
	save_profile()
	return {"ok": true}

func tile_at(x: int, y: int) -> Dictionary:
	var active_map := get_map_definition()
	var rows: Array = active_map.get("terrainRows", [])
	var width := int(active_map.get("activeWidth", 15))
	var height := int(active_map.get("activeHeight", 15))
	if x < 0 or y < 0 or x >= width or y >= height: return {"walkable": false, "cost": 0, "symbol": "#"}
	var row_index := height - 1 - y
	if row_index < 0 or row_index >= rows.size(): return {"walkable": false, "cost": 0, "symbol": "#"}
	var row: String = str(rows[row_index])
	var symbol := row.substr(x, 1)
	if symbol == "#": return {"walkable": false, "cost": 0, "symbol": symbol}
	var grain_per_step := int(get_expedition_map_rule().get("grainPerStep", 1))
	return {"walkable": true, "cost": grain_per_step * 2 if symbol == "~" else 0 if symbol == "E" else grain_per_step, "symbol": symbol}

func move_expedition(dx: int, dy: int) -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if expedition == null: return {"ok": false, "message": "当前没有探索进度"}
	if bool(expedition.get("isResting", false)): return {"ok": false, "message": "请先结束休整"}
	var from: Dictionary = expedition["position"]
	if absi(dx) + absi(dy) != 1: return {"ok": false, "message": "只能移动到相邻格"}
	var to := {"x": int(from["x"]) + dx, "y": int(from["y"]) + dy}
	var tile := tile_at(to["x"], to["y"])
	if not tile["walkable"]: return {"ok": false, "message": "前方被残禁封锁"}
	var grain := int(expedition["remainingGrain"])
	var cost := int(tile["cost"])
	if grain > 0: grain = maxi(0, grain - mini(grain, cost))
	else:
		expedition["grainDepletionSteps"] = int(expedition.get("grainDepletionSteps", 0)) + 1
		var step_limit := int(expedition_config.get("field", {}).get("grainDepletionStepLimit", 4))
		if expedition["grainDepletionSteps"] >= step_limit:
			return {"ok": true, "position": to, "wiped": true, "message": "灵粮耗尽，队伍在断粮中覆灭"}
	expedition["position"] = to
	expedition["remainingGrain"] = grain
	expedition["revealedTiles"] = _reveal(expedition.get("revealedTiles", []), to, int(get_expedition_map_rule().get("discoveryRadius", 2)))
	save_profile()
	var object := object_at(to["x"], to["y"])
	return {"ok": true, "position": to, "wiped": false, "object": object}

func object_at(x: int, y: int) -> Dictionary:
	for object in get_map_definition().get("objects", []):
		if int(object.get("x", -1)) == x and int(object.get("y", -1)) == y: return object
	return {}

func _reveal(previous: Array, center: Dictionary, radius: int) -> Array:
	var result := previous.duplicate()
	var active_map := get_map_definition()
	var width := int(active_map.get("activeWidth", 15))
	var height := int(active_map.get("activeHeight", 15))
	for y in range(maxi(0, int(center["y"]) - radius), mini(height, int(center["y"]) + radius + 1)):
		for x in range(maxi(0, int(center["x"]) - radius), mini(width, int(center["x"]) + radius + 1)):
			if (x - int(center["x"])) * (x - int(center["x"])) + (y - int(center["y"])) * (y - int(center["y"])) <= radius * radius:
				var key := "%d:%d" % [x, y]
				if not result.has(key): result.append(key)
	return result

func is_visible(x: int, y: int) -> bool:
	var expedition: Variant = profile.get("expedition")
	if expedition == null: return false
	var center: Dictionary = expedition["position"]
	var radius := int(get_expedition_map_rule().get("discoveryRadius", 2))
	return (x - int(center["x"])) * (x - int(center["x"])) + (y - int(center["y"])) * (y - int(center["y"])) <= radius * radius

func is_revealed(x: int, y: int) -> bool:
	var expedition: Variant = profile.get("expedition")
	if expedition == null: return false
	return str("%d:%d" % [x, y]) in expedition.get("revealedTiles", [])

func begin_encounter(object: Dictionary) -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if not expedition is Dictionary or expedition.is_empty(): return {"ok": false, "message": "当前没有探索进度"}
	var encounter_id := str(object.get("encounterId", object.get("enemyId", "")))
	if encounter_id.is_empty() or get_encounter(encounter_id).is_empty(): return {"ok": false, "message": "该地图对象没有可用的遭遇配置"}
	expedition["encounterId"] = encounter_id
	expedition["mapObjectId"] = str(object.get("id", ""))
	save_profile()
	return {"ok": true, "encounterId": encounter_id}

func clear_active_encounter() -> void:
	var expedition: Variant = profile.get("expedition")
	if not expedition is Dictionary: return
	expedition["encounterId"] = ""
	expedition["mapObjectId"] = ""
	save_profile()

func resolve_object(object: Dictionary) -> String:
	var key := map_object_key(get_active_map_id(), str(object.get("id", "")))
	if profile["completedMapObjects"].get(key, false): return "这里已经没有可用的东西了"
	profile["completedMapObjects"][key] = true
	if object.get("reward") is Dictionary:
		var reward: Dictionary = object["reward"]
		var id := str(reward.get("itemId", ""))
		profile["expedition"]["temporaryLoot"][id] = int(profile["expedition"]["temporaryLoot"].get(id, 0)) + int(reward.get("amount", 1))
	save_profile()
	var reward_data: Dictionary = object.get("reward", {})
	return "获得 %s ×%d" % [text(str(reward_data.get("nameKey", "")), str(reward_data.get("itemName", "战利品"))), int(reward_data.get("amount", 1))]

func return_to_camp() -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if expedition == null: return {"ok": false, "message": "当前没有探索进度"}
	if bool(expedition.get("isResting", false)): return {"ok": false, "message": "请先结束休整"}
	var pos: Dictionary = expedition["position"]
	var active_map := get_map_definition()
	var entry := {"x": int(active_map.get("entryX", 2)), "y": int(active_map.get("entryY", 2))}
	if pos != entry: return {"ok": false, "message": "请先返回入口传送阵"}
	_finish_expedition(false)
	return {"ok": true}

func return_with_talisman() -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if expedition == null: return {"ok": false, "message": "当前没有探索进度"}
	if bool(expedition.get("isResting", false)): return {"ok": false, "message": "请先结束休整"}
	var inventory: Dictionary = profile.get("inventory", {})
	if int(inventory.get("return_talisman", 0)) <= 0:
		return {"ok": false, "message": "没有归营符，无法直接归营"}
	inventory["return_talisman"] = int(inventory.get("return_talisman", 0)) - 1
	profile["inventory"] = inventory
	_finish_expedition(false)
	return {"ok": true}

func enter_rest() -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if expedition == null: return {"ok": false, "message": "当前不在野外地图"}
	if bool(expedition.get("isResting", false)): return {"ok": true, "message": "正在休整"}
	if int(expedition.get("restUsesRemaining", 0)) <= 0:
		return {"ok": false, "message": "本次入山已没有休整机会"}
	expedition["restUsesRemaining"] = int(expedition.get("restUsesRemaining", 0)) - 1
	expedition["isResting"] = true
	expedition["restHealingUsed"] = false
	save_profile()
	return {"ok": true, "message": "队伍开始原地休整"}

func replenish_rest() -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if expedition == null or not bool(expedition.get("isResting", false)):
		return {"ok": false, "message": "当前不在休整状态"}
	var capacity := int(expedition.get("grainCapacity", 0))
	var current_grain := int(expedition.get("remainingGrain", 0))
	if current_grain >= capacity: return {"ok": false, "message": "灵粮已经达到本次携带上限"}
	var food_items: Array = expedition_config.get("field", {}).get("foodItems", [])
	# 优先消耗配置中排在前面的食材，保持冻结的野外休整规则。
	for food in food_items:
		var food_id := str(food.get("itemId", ""))
		var amount := int(expedition.get("temporaryLoot", {}).get(food_id, 0))
		if amount <= 0: continue
		var loot: Dictionary = expedition.get("temporaryLoot", {})
		if amount == 1: loot.erase(food_id)
		else: loot[food_id] = amount - 1
		expedition["temporaryLoot"] = loot
		var restored := mini(capacity - current_grain, int(food.get("grainRestored", 0)))
		expedition["remainingGrain"] = current_grain + restored
		expedition["grainDepletionSteps"] = 0
		save_profile()
		return {"ok": true, "message": "已补充 %d 灵粮" % restored}
	return {"ok": false, "message": "没有可用的野外食材"}

func heal_rest() -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if expedition == null or not bool(expedition.get("isResting", false)):
		return {"ok": false, "message": "当前不在休整状态"}
	if bool(expedition.get("restHealingUsed", false)):
		return {"ok": false, "message": "本次休整已经运功疗伤"}
	var healing_percent := int(expedition_config.get("field", {}).get("healingPercent", 25))
	var member_ids: Array = expedition.get("partyMemberIds", [])
	var healed := 0
	for hero in profile.get("roster", []):
		if hero.get("instanceId") not in member_ids or bool(hero.get("isDead", false)): continue
		var max_hp := int(hero.get("maxHp", 1))
		var current_hp := int(hero.get("currentHp", max_hp))
		if current_hp >= max_hp: continue
		var amount := maxi(1, ceili(float(max_hp) * float(healing_percent) / 100.0))
		hero["currentHp"] = mini(max_hp, current_hp + amount)
		healed += 1
	if healed <= 0: return {"ok": false, "message": "队伍当前无需疗伤"}
	expedition["restHealingUsed"] = true
	save_profile()
	return {"ok": true, "message": "全队恢复 %d%% 最大生命" % healing_percent}

func continue_rest() -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if expedition == null or not bool(expedition.get("isResting", false)):
		return {"ok": false, "message": "当前不在休整状态"}
	expedition["isResting"] = false
	save_profile()
	return {"ok": true, "message": "休整结束，继续探索"}

func _finish_expedition(defeated: bool) -> void:
	var expedition: Dictionary = profile.get("expedition", {})
	if defeated:
		for hero in party_heroes():
			hero["currentHp"] = 0
			hero["isDead"] = true
		# 冻结结算规则：战斗/断粮阵亡时，携带池的一半向下取整返还。
		var lost_pool: Dictionary = {}
		for source in [expedition.get("carriedItems", {}), expedition.get("temporaryLoot", {})]:
			for item_id in source:
				lost_pool[item_id] = int(lost_pool.get(item_id, 0)) + int(source[item_id])
		var retained_basis_points := 10000 - int(expedition_config.get("materialLossBasisPoints", 5000))
		for item_id in lost_pool:
			var retained := floori(float(int(lost_pool[item_id]) * retained_basis_points) / 10000.0)
			if retained > 0:
				profile["inventory"][item_id] = int(profile["inventory"].get(item_id, 0)) + retained
		var dead_ids: Array = expedition.get("partyMemberIds", [])
		for preset in profile.get("expeditionPreparation", {}).get("partyPresets", []):
			var slots: Array = preset.get("slots", [])
			for index in slots.size():
				if slots[index] in dead_ids: slots[index] = null
			preset["slots"] = slots
	else:
		profile["wallet"]["spiritGrain"] += int(expedition.get("remainingGrain", 0))
		for source in [expedition.get("carriedItems", {}), expedition.get("temporaryLoot", {})]:
			for id in source: profile["inventory"][id] = int(profile["inventory"].get(id, 0)) + int(source[id])
	profile["expedition"] = null
	save_profile()
