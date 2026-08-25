extends Node

signal state_changed
signal feedback(message: String, severity: int)

const PROFILE_PATH := "user://kunwu_profile.json"
const PROFILE_TMP_PATH := "user://kunwu_profile.tmp"
const DEFAULT_PROFILE_PATH := "res://data/config/default_profile.json"
const CONFIG_ROOT := "res://data/config/"
const LOCAL_MAP_LAYOUT_SCENES := {
	"map_01": "res://scenes/maps/map_01.tscn",
}

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
	# JSON 中显式的 null 不会被 Dictionary.get(key, default) 替换，
	# 旧存档若把这些容器写成 null，后续链式 .get() 就会落到 Nil。
	for key in ["wallet", "camp", "inventory", "storyFlags", "mapStates", "completedMapObjects"]:
		if not profile.get(key) is Dictionary:
			var default_value: Variant = defaults.get(key, {})
			profile[key] = default_value.duplicate(true) if default_value is Dictionary else {}
	if not profile.get("roster") is Array:
		var default_roster: Variant = defaults.get("roster", [])
		profile["roster"] = default_roster.duplicate(true) if default_roster is Array else []
	_merge_missing(profile, defaults)
	# 旧版本曾把入山队伍槽位保存成全 null。当前演示队伍是固定的四名修士，
	# 这种存档不能直接拿来构建入山面板或开始远征；仅在没有任何有效槽位时
	# 用默认队伍补齐，不覆盖用户已经做出的有效选择。
	_normalise_expedition_preparation(defaults)
	if not profile.get("camp", {}).has("workerCount"):
		profile["camp"]["workerCount"] = 6
	if not profile.get("camp", {}).has("resourceStorageLevels"):
		profile["camp"]["resourceStorageLevels"] = {"spiritGrain": 1, "spiritWood": 1, "darkIron": 1}
	if not profile.has("completedMapObjects"):
		profile["completedMapObjects"] = {}
	if not profile.has("mapStates") or not profile["mapStates"] is Dictionary:
		profile["mapStates"] = {}
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
		if not hero is Dictionary:
			continue
		if not hero.has("stamina"): hero["stamina"] = 100
		if not hero.has("isDead"): hero["isDead"] = false
		if int(hero.get("currentHp", hero.get("maxHp", 1))) <= 0:
			hero["currentHp"] = 0
			hero["isDead"] = true

func _normalise_expedition_preparation(defaults: Dictionary) -> void:
	var raw_preparation: Variant = profile.get("expeditionPreparation")
	var preparation: Dictionary = raw_preparation if raw_preparation is Dictionary else {}
	var default_preparation: Dictionary = defaults.get("expeditionPreparation", {}) if defaults.get("expeditionPreparation") is Dictionary else {}
	if preparation.is_empty():
		preparation = default_preparation.duplicate(true)
	if not preparation.has("loadout") or not preparation["loadout"] is Dictionary:
		preparation["loadout"] = {"spiritGrain": 60, "pickaxe": 0, "lens": 0}
	var raw_presets: Variant = preparation.get("partyPresets", [])
	var presets: Array = raw_presets if raw_presets is Array else []
	if presets.is_empty() and default_preparation.get("partyPresets") is Array:
		presets = default_preparation["partyPresets"].duplicate(true)
	var roster: Array = profile.get("roster", []) if profile.get("roster") is Array else []
	var fallback_ids: Array = []
	for hero in roster:
		if hero is Dictionary and not bool(hero.get("isDead", false)):
			fallback_ids.append(hero.get("instanceId", ""))
	var normalized_presets: Array = []
	for raw_preset in presets:
		if not raw_preset is Dictionary:
			continue
		var preset: Dictionary = raw_preset
		var raw_slots: Variant = preset.get("slots", [])
		var slots: Array = raw_slots if raw_slots is Array else []
		var has_valid_slot := false
		for slot in slots:
			if slot != null and not str(slot).is_empty():
				has_valid_slot = true
				break
		if not has_valid_slot:
			slots = fallback_ids.duplicate()
		elif slots.size() < fallback_ids.size():
			# 只补齐旧存档中缺失的尾部槽位；保留已有的选择顺序。
			for hero_id in fallback_ids:
				if slots.size() >= fallback_ids.size():
					break
				if hero_id not in slots:
					slots.append(hero_id)
		preset["slots"] = slots
		normalized_presets.append(preset)
	if normalized_presets.is_empty() and not fallback_ids.is_empty():
		normalized_presets.append({
			"presetId": "party_01",
			"name": "1队",
			"slots": fallback_ids.duplicate(),
		})
	preparation["partyPresets"] = normalized_presets
	if not preparation.has("activePresetId") and not normalized_presets.is_empty():
		preparation["activePresetId"] = str(normalized_presets[0].get("presetId", "party_01"))
	profile["expeditionPreparation"] = preparation

func _merge_missing(target: Dictionary, defaults: Dictionary) -> void:
	for key in defaults:
		if not target.has(key):
			target[key] = defaults[key].duplicate(true) if defaults[key] is Dictionary else defaults[key]
		elif defaults[key] is Dictionary and not target[key] is Dictionary:
			target[key] = defaults[key].duplicate(true)
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
		var expedition: Variant = profile.get("expedition")
		if expedition is Dictionary and not expedition.is_empty():
			target_id = str(expedition.get("partyPresetId", preparation.get("activePresetId", "")))
		else:
			target_id = str(preparation.get("activePresetId", ""))
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
			if not hero is Dictionary:
				continue
			if hero.get("instanceId") == id: result.append(hero)
	return result

func living_heroes() -> Array:
	var result: Array = []
	for hero in profile.get("roster", []):
		if hero is Dictionary and not bool(hero.get("isDead", false)) and int(hero.get("currentHp", 0)) > 0:
			result.append(hero)
	return result

func dead_heroes() -> Array:
	var result: Array = []
	for hero in profile.get("roster", []):
		if hero is Dictionary and (bool(hero.get("isDead", false)) or int(hero.get("currentHp", 0)) <= 0):
			result.append(hero)
	return result

func revival_cost(hero: Dictionary) -> int:
	var level := maxi(1, int(hero.get("level", 1)))
	var raw_cost := -1
	match str(hero.get("realmId", "")):
		"lian_qi": raw_cost = 20 + 8 * level
		"zhu_ji": raw_cost = 100 + 15 * (level - 10)
		"jie_dan": raw_cost = 300 + 25 * (level - 20)
	if raw_cost < 0:
		return -1
	return ceili(float(maxi(0, raw_cost)) / 5.0) * 5

func revive_cultivators(hero_ids: Array) -> Dictionary:
	if profile.get("expedition") != null:
		return {"ok": false, "message": "出征结算尚未完成，暂时不能还魂"}
	var unique_ids: Array[String] = []
	for raw_id in hero_ids:
		var hero_id := str(raw_id)
		if not hero_id.is_empty() and not unique_ids.has(hero_id):
			unique_ids.append(hero_id)
	if unique_ids.is_empty():
		return {"ok": false, "message": "没有选择待还魂修士"}
	var selected: Array[Dictionary] = []
	var total_cost := 0
	for hero_id in unique_ids:
		var hero := _roster_hero(hero_id)
		if hero.is_empty() or (not bool(hero.get("isDead", false)) and int(hero.get("currentHp", 0)) > 0):
			return {"ok": false, "message": "待还魂修士状态已经变化，请刷新后重试"}
		var cost := revival_cost(hero)
		if cost < 0:
			return {"ok": false, "message": "修士境界数据异常，无法计算还魂费用"}
		selected.append(hero)
		total_cost += cost
	if wallet_value("soulCrystal") < total_cost:
		return {"ok": false, "message": "魂晶不足，还需 %d" % (total_cost - wallet_value("soulCrystal"))}
	var previous_profile := profile.duplicate(true)
	profile["wallet"]["soulCrystal"] = wallet_value("soulCrystal") - total_cost
	for hero in selected:
		_restore_cultivator(hero)
	if not save_profile():
		profile = previous_profile
		return {"ok": false, "message": "还魂保存失败，请重试"}
	return {"ok": true, "message": "已还魂 %d 名修士，消耗魂晶 %d" % [selected.size(), total_cost], "cost": total_cost}

func emergency_revive_cultivator(hero_id: String) -> Dictionary:
	if profile.get("expedition") != null:
		return {"ok": false, "message": "出征结算尚未完成，暂时不能还魂"}
	if not living_heroes().is_empty():
		return {"ok": false, "message": "仍有存活修士，当前不满足免费还魂条件"}
	var dead := dead_heroes()
	var minimum_cost := 2147483647
	for candidate in dead:
		var candidate_cost := revival_cost(candidate)
		if candidate_cost >= 0:
			minimum_cost = mini(minimum_cost, candidate_cost)
	if dead.is_empty() or wallet_value("soulCrystal") >= minimum_cost:
		return {"ok": false, "message": "当前魂晶足以正常还魂"}
	var hero := _roster_hero(hero_id)
	if hero.is_empty() or (not bool(hero.get("isDead", false)) and int(hero.get("currentHp", 0)) > 0):
		return {"ok": false, "message": "待还魂修士状态已经变化，请刷新后重试"}
	if revival_cost(hero) < 0:
		return {"ok": false, "message": "修士境界数据异常，无法执行免费还魂"}
	var previous_profile := profile.duplicate(true)
	_restore_cultivator(hero)
	if not save_profile():
		profile = previous_profile
		return {"ok": false, "message": "还魂保存失败，请重试"}
	return {"ok": true, "message": "%s 已免费还魂，可重新整备出战" % text(str(hero.get("nameKey", "")), "修士"), "cost": 0}

func _roster_hero(hero_id: String) -> Dictionary:
	for hero in profile.get("roster", []):
		if hero is Dictionary and str(hero.get("instanceId", "")) == hero_id:
			return hero
	return {}

func _restore_cultivator(hero: Dictionary) -> void:
	hero["isDead"] = false
	hero["currentHp"] = maxi(1, int(hero.get("maxHp", 1)))
	_restore_hero_to_party_presets(str(hero.get("instanceId", "")))

func _restore_hero_to_party_presets(hero_id: String) -> void:
	if hero_id.is_empty():
		return
	var preparation: Dictionary = profile.get("expeditionPreparation", {})
	var presets: Array = preparation.get("partyPresets", [])
	var default_preparation: Dictionary = default_profile.get("expeditionPreparation", {})
	for preset in presets:
		if not preset is Dictionary:
			continue
		var slots: Array = preset.get("slots", [])
		if hero_id in slots:
			continue
		var preferred_index := -1
		for default_preset in default_preparation.get("partyPresets", []):
			if not default_preset is Dictionary or str(default_preset.get("presetId", "")) != str(preset.get("presetId", "")):
				continue
			preferred_index = default_preset.get("slots", []).find(hero_id)
			break
		if preferred_index >= 0:
			while slots.size() <= preferred_index:
				slots.append(null)
			if slots[preferred_index] == null or str(slots[preferred_index]).is_empty():
				slots[preferred_index] = hero_id
				preset["slots"] = slots
				continue
		var empty_index := -1
		for index in slots.size():
			if slots[index] == null or str(slots[index]).is_empty():
				empty_index = index
				break
		if empty_index >= 0:
			slots[empty_index] = hero_id
		elif slots.size() < 4:
			slots.append(hero_id)
		preset["slots"] = slots
	preparation["partyPresets"] = presets
	profile["expeditionPreparation"] = preparation

func get_map_definition(map_id: String = "") -> Dictionary:
	var target_id := map_id if not map_id.is_empty() else get_active_map_id()
	var configured: Dictionary = map_definitions.get(target_id, {})
	if configured.is_empty():
		return {}
	var resolved := configured.duplicate(true)
	var configured_visual: Variant = configured.get("visual")
	var visual: Dictionary = configured_visual.duplicate(true) if configured_visual is Dictionary else {}
	var scene_path := str(visual.get("scenePath", LOCAL_MAP_LAYOUT_SCENES.get(target_id, "")))
	if not scene_path.is_empty():
		visual["scenePath"] = scene_path
	resolved["visual"] = visual
	return resolved

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

func map_state_value(state_key: String, fallback: Variant = null) -> Variant:
	var parts := state_key.split(".", false)
	if parts.size() < 2:
		return fallback
	var cursor: Variant = profile.get("mapStates", {})
	for part in parts:
		if not cursor is Dictionary or not cursor.has(part):
			return fallback
		cursor = cursor[part]
	return cursor

func set_map_state_value(state_key: String, value: Variant) -> bool:
	return apply_map_state_patch({state_key: value})

func apply_map_state_patch(updates: Dictionary) -> bool:
	if updates.is_empty():
		return false
	var next_states: Dictionary = profile.get("mapStates", {}).duplicate(true)
	for state_key in updates:
		var parts := str(state_key).split(".", false)
		if parts.size() < 2 or not str(parts[0]).begins_with("map_"):
			return false
		var cursor := next_states
		for index in parts.size() - 1:
			var part := str(parts[index])
			if not cursor.has(part) or not cursor[part] is Dictionary:
				cursor[part] = {}
			cursor = cursor[part]
		cursor[str(parts[-1])] = updates[state_key]
	profile["mapStates"] = next_states
	return save_profile()

func available_map_object_actions(object: Dictionary) -> Array:
	var result: Array = []
	for raw_action in object.get("choices", []):
		if not raw_action is Dictionary:
			continue
		var action: Dictionary = raw_action.duplicate(true)
		var check := check_map_object_requirements(action.get("requirements", {}))
		if not bool(check.get("ok", false)) and bool(action.get("hideWhenUnavailable", false)):
			continue
		action["enabled"] = bool(check.get("ok", false))
		action["unavailableText"] = str(check.get("message", action.get("unavailableText", "条件尚未满足")))
		result.append(action)
	return result

func check_map_object_requirements(requirements: Dictionary) -> Dictionary:
	if requirements.is_empty():
		return {"ok": true, "message": ""}
	for state_key in requirements.get("mapStateEquals", {}):
		var expected: Variant = requirements["mapStateEquals"][state_key]
		if map_state_value(str(state_key), null) != expected:
			return {"ok": false, "message": str(requirements.get("failureText", "地图状态尚未满足"))}
	for state_key in requirements.get("mapStateNotEquals", {}):
		var rejected: Variant = requirements["mapStateNotEquals"][state_key]
		if map_state_value(str(state_key), null) == rejected:
			return {"ok": false, "message": str(requirements.get("failureText", "该选择已经处理"))}
	for flag_id in requirements.get("storyFlags", {}):
		if profile.get("storyFlags", {}).get(flag_id) != requirements["storyFlags"][flag_id]:
			return {"ok": false, "message": str(requirements.get("failureText", "剧情条件尚未满足"))}
	for object_id in requirements.get("completedObjects", []):
		if not bool(profile.get("completedMapObjects", {}).get(map_object_key(get_active_map_id(), str(object_id)), false)):
			return {"ok": false, "message": str(requirements.get("failureText", "前置目标尚未完成"))}
	var expedition: Dictionary = profile.get("expedition", {}) if profile.get("expedition") is Dictionary else {}
	var required_position: Variant = requirements.get("expeditionPositionEquals", {})
	if required_position is Dictionary and not required_position.is_empty():
		var current_position: Dictionary = expedition.get("position", {}) if expedition.get("position") is Dictionary else {}
		if int(current_position.get("x", -1)) != int(required_position.get("x", -2)) \
			or int(current_position.get("y", -1)) != int(required_position.get("y", -2)):
			return {"ok": false, "message": str(requirements.get("failureText", "队伍不在对应的地图位置"))}
	for item_id in requirements.get("minCarriedItems", {}):
		if int(expedition.get("carriedItems", {}).get(item_id, 0)) < int(requirements["minCarriedItems"][item_id]):
			return {"ok": false, "message": str(requirements.get("failureText", "本次入山未携带所需工具"))}
	var heroes := party_heroes()
	for attribute_id in requirements.get("partyMaxAttributes", {}):
		var maximum := 0
		for hero in heroes:
			maximum = maxi(maximum, int(hero.get("attributes", {}).get(attribute_id, 0)))
		if maximum < int(requirements["partyMaxAttributes"][attribute_id]):
			return {"ok": false, "message": str(requirements.get("failureText", "队伍最高属性不足"))}
	for attribute_id in requirements.get("partySumAttributes", {}):
		var total := 0
		for hero in heroes:
			total += int(hero.get("attributes", {}).get(attribute_id, 0))
		if total < int(requirements["partySumAttributes"][attribute_id]):
			return {"ok": false, "message": str(requirements.get("failureText", "队伍合计属性不足"))}
	return {"ok": true, "message": ""}

func resolve_map_object_action(object: Dictionary, action_id: String) -> Dictionary:
	var selected: Dictionary = {}
	for raw_action in object.get("choices", []):
		if raw_action is Dictionary and str(raw_action.get("id", "")) == action_id:
			selected = raw_action
			break
	if selected.is_empty():
		var leave_action: Variant = object.get("leaveAction", {})
		if leave_action is Dictionary and str(leave_action.get("id", "")) == action_id:
			selected = leave_action
	if selected.is_empty():
		return {"ok": false, "message": "该地图行动不存在"}
	var requirement_result := check_map_object_requirements(selected.get("requirements", {}))
	if not bool(requirement_result.get("ok", false)):
		return requirement_result
	var previous_profile := profile.duplicate(true)
	var previous_position: Dictionary = {}
	if profile.get("expedition") is Dictionary:
		previous_position = profile["expedition"].get("position", {}).duplicate(true)
	var object_id := str(object.get("id", ""))
	var first_claim := true
	var claim_key := str(selected.get("claimKey", ""))
	if not claim_key.is_empty():
		first_claim = not bool(map_state_value(claim_key, false))
		_set_map_state_in_profile(claim_key, true)
	_apply_profile_effects(selected.get("effects", {}), object_id, first_claim)
	if first_claim:
		_apply_profile_effects(selected.get("firstClaimEffects", {}), object_id, true)
	else:
		_apply_profile_effects(selected.get("repeatEffects", {}), object_id, false)
	var encounter_id := str(selected.get("startEncounterId", ""))
	if not encounter_id.is_empty():
		var encounter := get_encounter(encounter_id)
		if encounter.is_empty():
			profile = previous_profile
			return {"ok": false, "message": "关联遭遇配置不存在"}
		var expedition: Variant = profile.get("expedition")
		if not expedition is Dictionary:
			profile = previous_profile
			return {"ok": false, "message": "当前没有探索进度"}
		expedition["encounterId"] = encounter_id
		expedition["mapObjectId"] = object_id
	if bool(selected.get("completeObject", false)):
		profile["completedMapObjects"][map_object_key(get_active_map_id(), object_id)] = true
	if not save_profile():
		profile = previous_profile
		return {"ok": false, "message": "状态保存失败，请重试"}
	var current_position: Dictionary = {}
	if profile.get("expedition") is Dictionary:
		current_position = profile["expedition"].get("position", {}).duplicate(true)
	return {
		"ok": true,
		"message": str(selected.get("resultText", "行动已经完成")),
		"startEncounter": not encounter_id.is_empty(),
		"encounterId": encounter_id,
		"completed": bool(selected.get("completeObject", false)),
		"positionChanged": previous_position != current_position,
		"position": current_position,
	}

func _apply_profile_effects(effects: Dictionary, object_id: String, first_claim: bool) -> void:
	for state_key in effects.get("mapStatePatch", {}):
		_set_map_state_in_profile(str(state_key), effects["mapStatePatch"][state_key])
	for state_key in effects.get("incrementMapStates", {}):
		var next_value := int(map_state_value(str(state_key), 0)) + int(effects["incrementMapStates"][state_key])
		_set_map_state_in_profile(str(state_key), next_value)
	var encounter_victories := int(profile.get("statistics", {}).get("encounterVictories", 0))
	for capture in effects.get("captureEncounterVictoryDeadlines", []):
		if not capture is Dictionary:
			continue
		var deadline_key := str(capture.get("stateKey", ""))
		var victories_until := maxi(0, int(capture.get("victoriesUntil", 0)))
		if not deadline_key.is_empty() and victories_until > 0:
			_set_map_state_in_profile(deadline_key, encounter_victories + victories_until)
	var story_flags: Dictionary = profile.get("storyFlags", {})
	for flag_id in effects.get("storyFlagPatch", {}):
		story_flags[str(flag_id)] = effects["storyFlagPatch"][flag_id]
	for flag_id in effects.get("incrementStoryFlags", {}):
		story_flags[str(flag_id)] = int(story_flags.get(flag_id, 0)) + int(effects["incrementStoryFlags"][flag_id])
	profile["storyFlags"] = story_flags
	var expedition: Variant = profile.get("expedition")
	if expedition is Dictionary:
		var position_effect: Variant = effects.get("expeditionPosition", {})
		if position_effect is Dictionary and not position_effect.is_empty():
			var target_position := {
				"x": int(position_effect.get("x", -1)),
				"y": int(position_effect.get("y", -1)),
			}
			if bool(tile_at(int(target_position["x"]), int(target_position["y"])).get("walkable", false)):
				expedition["position"] = target_position
				expedition["revealedTiles"] = _reveal(
					expedition.get("revealedTiles", []),
					target_position,
					int(get_expedition_map_rule().get("discoveryRadius", 2))
				)
		var temporary_loot: Dictionary = expedition.get("temporaryLoot", {})
		for reward in effects.get("rewards", []):
			if not reward is Dictionary:
				continue
			var item_id := str(reward.get("itemId", ""))
			if item_id.is_empty():
				continue
			var amount := int(reward.get("firstAmount", reward.get("amount", 0))) if first_claim else int(reward.get("repeatAmount", reward.get("amount", 0)))
			if amount > 0:
				temporary_loot[item_id] = int(temporary_loot.get(item_id, 0)) + amount
		expedition["temporaryLoot"] = temporary_loot
		var carried_items: Dictionary = expedition.get("carriedItems", {})
		for item_id in effects.get("consumeCarriedItems", {}):
			carried_items[item_id] = maxi(0, int(carried_items.get(item_id, 0)) - int(effects["consumeCarriedItems"][item_id]))
		expedition["carriedItems"] = carried_items
	var healing_percent := int(effects.get("healPartyPercent", 0))
	if healing_percent > 0:
		for hero in party_heroes():
			if bool(hero.get("isDead", false)):
				continue
			var max_hp := int(hero.get("maxHp", 1))
			hero["currentHp"] = mini(max_hp, int(hero.get("currentHp", max_hp)) + ceili(max_hp * healing_percent / 100.0))
	for building_id in effects.get("campBuildingLevels", {}):
		var levels: Dictionary = profile.get("camp", {}).get("buildingLevels", {})
		levels[str(building_id)] = maxi(int(levels.get(building_id, 0)), int(effects["campBuildingLevels"][building_id]))
		profile["camp"]["buildingLevels"] = levels
	if bool(effects.get("completeObject", false)) and not object_id.is_empty():
		profile["completedMapObjects"][map_object_key(get_active_map_id(), object_id)] = true

func _set_map_state_in_profile(state_key: String, value: Variant) -> void:
	var parts := state_key.split(".", false)
	if parts.size() < 2 or not str(parts[0]).begins_with("map_"):
		return
	var states: Dictionary = profile.get("mapStates", {})
	var cursor := states
	for index in parts.size() - 1:
		var part := str(parts[index])
		if not cursor.has(part) or not cursor[part] is Dictionary:
			cursor[part] = {}
		cursor = cursor[part]
	cursor[str(parts[-1])] = value
	profile["mapStates"] = states

func finish_encounter_victory(encounter: Dictionary) -> Dictionary:
	var expedition: Variant = profile.get("expedition")
	if not expedition is Dictionary:
		return {"ok": false, "message": "当前没有探索进度"}
	var previous_profile := profile.duplicate(true)
	var map_id := get_active_map_id()
	var object_id := get_active_map_object_id()
	if object_id.is_empty():
		return {"ok": false, "message": "遭遇缺少地图对象ID"}
	var first_key := "%s.encounters.%s.firstClearClaimed" % [map_id, object_id]
	var first_clear := not bool(map_state_value(first_key, false))
	profile["completedMapObjects"][map_object_key(map_id, object_id)] = true
	_set_map_state_in_profile(first_key, true)
	var soul_reward := int(encounter.get("firstSoulCrystalReward", encounter.get("soulCrystalReward", 0))) if first_clear else int(encounter.get("repeatSoulCrystalReward", encounter.get("soulCrystalReward", 0)))
	profile["wallet"]["soulCrystal"] = int(profile["wallet"].get("soulCrystal", 0)) + soul_reward
	_apply_profile_effects(encounter.get("victoryEffects", {}), object_id, first_clear)
	if first_clear:
		_apply_profile_effects(encounter.get("firstVictoryEffects", {}), object_id, true)
	var progress_messages := _record_encounter_victory_and_apply_rules(map_id)
	var reward_loot: Array = encounter.get("loot", []).duplicate(true)
	if first_clear:
		reward_loot.append_array(encounter.get("firstLoot", []).duplicate(true))
	expedition["pendingEncounterLoot"] = reward_loot
	expedition["pendingEncounterSoulCrystal"] = soul_reward
	if not save_profile():
		profile = previous_profile
		return {"ok": false, "message": "战斗结算保存失败"}
	return {"ok": true, "firstClear": first_clear, "soulCrystal": soul_reward, "loot": reward_loot, "progressMessages": progress_messages}


func _record_encounter_victory_and_apply_rules(map_id: String) -> Array[String]:
	var statistics: Dictionary = profile.get("statistics", {})
	statistics["encounterVictories"] = int(statistics.get("encounterVictories", 0)) + 1
	profile["statistics"] = statistics
	var victory_count := int(statistics["encounterVictories"])
	var messages: Array[String] = []
	for raw_rule in get_map_definition(map_id).get("encounterVictoryRules", []):
		if not raw_rule is Dictionary:
			continue
		var rule: Dictionary = raw_rule
		var once_key := str(rule.get("onceStateKey", ""))
		if not once_key.is_empty() and bool(map_state_value(once_key, false)):
			continue
		var requirement_result := check_map_object_requirements(rule.get("requirements", {}))
		if not bool(requirement_result.get("ok", false)):
			continue
		var deadline_key := str(rule.get("deadlineStateKey", ""))
		var deadline := int(map_state_value(deadline_key, 0))
		if deadline <= 0 or victory_count < deadline:
			continue
		var rule_object_id := str(rule.get("objectId", ""))
		_apply_profile_effects(rule.get("effects", {}), rule_object_id, true)
		if not once_key.is_empty():
			_set_map_state_in_profile(once_key, true)
		var message := str(rule.get("message", ""))
		if not message.is_empty():
			messages.append(message)
	return messages

func take_pending_encounter_loot() -> bool:
	var expedition: Variant = profile.get("expedition")
	if not expedition is Dictionary:
		return false
	var temporary_loot: Dictionary = expedition.get("temporaryLoot", {})
	for reward in expedition.get("pendingEncounterLoot", []):
		var item_id := str(reward.get("itemId", ""))
		var amount := int(reward.get("amount", 0))
		if not item_id.is_empty() and amount > 0:
			temporary_loot[item_id] = int(temporary_loot.get(item_id, 0)) + amount
	expedition["temporaryLoot"] = temporary_loot
	expedition["pendingEncounterLoot"] = []
	expedition["pendingEncounterSoulCrystal"] = 0
	return save_profile()

func discard_pending_encounter_loot() -> bool:
	var expedition: Variant = profile.get("expedition")
	if not expedition is Dictionary:
		return false
	expedition["pendingEncounterLoot"] = []
	expedition["pendingEncounterSoulCrystal"] = 0
	return save_profile()

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
	if ids.is_empty() or heroes.is_empty(): return {"ok": false, "message": "至少选择一名存活修士，请前往还魂殿处理阵亡状态"}
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
		if hero.get("isDead", false) or int(hero.get("currentHp", 0)) <= 0: return {"ok": false, "message": "队伍中有阵亡修士，请先前往还魂殿"}
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
		"revealedTiles": _reveal([], entry, discovery_radius), "temporaryLoot": {},
		"pendingEncounterLoot": [], "pendingEncounterSoulCrystal": 0
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
	for blocker in active_map.get("dynamicBlockers", []):
		if int(blocker.get("x", -1)) != x or int(blocker.get("y", -1)) != y:
			continue
		var state_value: Variant = map_state_value(str(blocker.get("stateKey", "")), null)
		if state_value != blocker.get("passValue", true):
			return {"walkable": false, "cost": 0, "symbol": symbol, "blockerId": str(blocker.get("id", ""))}
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
		if int(object.get("x", -1)) == x and int(object.get("y", -1)) == y:
			return object
		for raw_cell in object.get("activationCells", []):
			if raw_cell is Array and raw_cell.size() >= 2 \
				and int(raw_cell[0]) == x and int(raw_cell[1]) == y:
				return object
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
	var requirement_result := check_map_object_requirements(object.get("requirements", {}))
	if not bool(requirement_result.get("ok", false)):
		return requirement_result
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
			for id in source:
				_credit_returned_item(str(id), int(source[id]))
	profile["expedition"] = null
	save_profile()

func _credit_returned_item(item_id: String, amount: int) -> void:
	if amount <= 0:
		return
	if profile.get("wallet", {}).has(item_id):
		profile["wallet"][item_id] = int(profile["wallet"].get(item_id, 0)) + amount
	else:
		profile["inventory"][item_id] = int(profile["inventory"].get(item_id, 0)) + amount
