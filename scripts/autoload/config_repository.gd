extends Node

signal configuration_changed(source: String, version: String)

const CLIENT_SCHEMA_VERSION := 1
const REQUIRED_MODULES := ["base", "progression", "combat", "economy", "expedition", "maps"]
const CACHE_ROOT := "user://kunwu_config_cache"
const CACHE_MANIFEST_PATH := CACHE_ROOT + "/manifest.json"

var source := "embedded"
var version := "embedded-d0"
var manifest: Dictionary = {}
var modules: Dictionary = {}
var runtime_tables: Dictionary = {}

func _ready() -> void:
	var embedded_manifest: Dictionary = _load_json("res://data/maps/map_01_manifest.json")
	version = str(embedded_manifest.get("embeddedVersion", "embedded-d0"))
	runtime_tables = _embedded_runtime_tables()
	if not OS.get_cmdline_user_args().has("--ignore-config-cache"): _load_cached_release()

func refresh_remote() -> Dictionary:
	var base_url := str(ProjectSettings.get_setting("kunwu/config_base_url", "")).strip_edges().trim_suffix("/")
	var environment_url := OS.get_environment("KUNWU_CONFIG_BASE_URL").strip_edges().trim_suffix("/")
	if not environment_url.is_empty(): base_url = environment_url
	if base_url.is_empty(): return {"ok": false, "source": source, "message": "未配置远端配置地址，使用本地配置"}
	var channel := str(ProjectSettings.get_setting("kunwu/config_channel", "development"))
	var environment_channel := OS.get_environment("KUNWU_CONFIG_CHANNEL").strip_edges()
	if not environment_channel.is_empty(): channel = environment_channel
	var manifest_result := await _request_bytes("%s/api/game-config/%s/manifest" % [base_url, channel])
	if not manifest_result.get("ok", false):
		return {"ok": false, "source": source, "message": "远端配置不可用，继续使用%s" % _source_label()}
	var parsed: Variant = JSON.parse_string(manifest_result.get("body", PackedByteArray()).get_string_from_utf8())
	if not parsed is Dictionary:
		return {"ok": false, "source": source, "message": "远端配置清单格式错误，继续使用%s" % _source_label()}
	var remote_manifest: Dictionary = parsed
	if int(remote_manifest.get("schemaVersion", 0)) > CLIENT_SCHEMA_VERSION:
		return {"ok": false, "source": source, "message": "远端配置版本高于客户端能力，继续使用%s" % _source_label()}
	if str(remote_manifest.get("releaseId", "")).is_empty():
		return {"ok": false, "source": source, "message": "远端配置清单缺少版本标识，继续使用%s" % _source_label()}
	var remote_modules: Dictionary = {}
	var remote_module_bytes: Dictionary = {}
	var module_manifest: Dictionary = remote_manifest.get("modules", {})
	for module_code in REQUIRED_MODULES:
		var metadata: Dictionary = module_manifest.get(module_code, {})
		if metadata.is_empty() or int(metadata.get("schemaVersion", 0)) > CLIENT_SCHEMA_VERSION:
			return {"ok": false, "source": source, "message": "远端配置模块不完整，继续使用%s" % _source_label()}
		var module_url := _absolute_url(base_url, str(metadata.get("url", "")))
		var module_result := await _request_bytes(module_url)
		if not module_result.get("ok", false):
			return {"ok": false, "source": source, "message": "远端配置下载中断，继续使用%s" % _source_label()}
		var body: PackedByteArray = module_result.get("body", PackedByteArray())
		if body.size() != int(metadata.get("byteSize", -1)) or _sha256_hex(body) != str(metadata.get("sha256", "")):
			return {"ok": false, "source": source, "message": "远端配置完整性校验失败，继续使用%s" % _source_label()}
		var module_value: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not module_value is Dictionary:
			return {"ok": false, "source": source, "message": "远端配置模块格式错误，继续使用%s" % _source_label()}
		remote_modules[module_code] = module_value
		remote_module_bytes[module_code] = body
	var adapted := _adapt_remote_modules(remote_modules)
	if adapted.is_empty():
		return {"ok": false, "source": source, "message": "远端配置无法适配，继续使用%s" % _source_label()}
	modules = remote_modules
	manifest = remote_manifest
	runtime_tables = adapted
	source = "remote"
	version = str(remote_manifest.get("version", remote_manifest.get("releaseId", "remote")))
	_save_cache(remote_manifest, remote_module_bytes)
	emit_signal("configuration_changed", source, version)
	return {"ok": true, "source": source, "version": version, "message": "配置已同步至 %s" % version}

func table(table_name: String) -> Variant:
	return runtime_tables.get(table_name, {})

func map_by_id(map_id: String) -> Dictionary:
	return runtime_tables.get("maps", {}).get(map_id, {})

func default_map_id() -> String:
	var available_maps: Dictionary = runtime_tables.get("maps", {})
	var expedition: Dictionary = runtime_tables.get("expedition", {})
	for map_rule in expedition.get("maps", []):
		var map_id := str(map_rule.get("mapId", ""))
		if available_maps.has(map_id): return map_id
	for map_id in available_maps: return str(map_id)
	return ""

func _embedded_runtime_tables() -> Dictionary:
	var map_manifest: Dictionary = _load_json("res://data/maps/map_01_manifest.json")
	var map_data_path := str(map_manifest.get("mapDataPath", "res://data/maps/map_01_formal.json"))
	var combat_data_path := str(map_manifest.get("combatDataPath", "res://data/config/combat_map01_formal.json"))
	var map_data: Dictionary = _load_json(map_data_path)
	return {
		"localization": _load_json("res://data/localization/zh_cn.json"),
		"expedition": _load_json("res://data/config/expedition_preparation.json").get("expedition_preparation", {}),
		"ling_pu": _load_json("res://data/config/ling_pu_config.json").get("ling_pu", {}),
		"combat": _load_embedded_combat(combat_data_path),
		"maps": {str(map_data.get("id", "")): map_data},
		"default_profile": _load_json("res://data/config/default_profile.json"),
		"assets": [],
	}

func _load_embedded_combat(path: String) -> Dictionary:
	var document: Dictionary = _load_json(path)
	var inherited_path := str(document.get("inherits", ""))
	if not inherited_path.is_empty():
		var inherited: Dictionary = _load_json(inherited_path)
		var combined_skills: Array = inherited.get("skills", []).duplicate(true)
		var skill_index: Dictionary = {}
		for index in combined_skills.size():
			skill_index[str(combined_skills[index].get("id", ""))] = index
		for skill in document.get("skills", []):
			var skill_id := str(skill.get("id", ""))
			if skill_index.has(skill_id):
				combined_skills[int(skill_index[skill_id])] = skill.duplicate(true)
			else:
				skill_index[skill_id] = combined_skills.size()
				combined_skills.append(skill.duplicate(true))
		document["skills"] = combined_skills
		for key in ["defenseLevelConstant", "partyInitialActionTimers"]:
			if not document.has(key) and inherited.has(key):
				document[key] = inherited[key]
	return _expand_embedded_encounters(document)

func _expand_embedded_encounters(document: Dictionary) -> Dictionary:
	var templates: Dictionary = {}
	for enemy in document.get("enemyTemplates", []):
		templates[str(enemy.get("id", ""))] = enemy
	if templates.is_empty():
		return document
	var encounters: Array = []
	for raw_encounter in document.get("encounters", []):
		var encounter: Dictionary = raw_encounter.duplicate(true)
		var enemies: Array = encounter.get("enemies", []).duplicate(true)
		for member in encounter.get("members", []):
			var template_id := str(member.get("enemyId", ""))
			var quantity := maxi(1, int(member.get("quantity", 1)))
			for copy_index in quantity:
				var enemy: Dictionary = templates.get(template_id, {}).duplicate(true)
				if enemy.is_empty():
					continue
				enemy["definitionId"] = template_id
				enemy["id"] = "%s_%d" % [template_id, copy_index + 1] if quantity > 1 else template_id
				if member.has("initialActionTimer"):
					enemy["initialActionTimer"] = int(member.get("initialActionTimer", 45))
				enemies.append(enemy)
		encounter["enemies"] = enemies
		encounter.erase("members")
		encounters.append(encounter)
	document["encounters"] = encounters
	return document

func _adapt_remote_modules(remote_modules: Dictionary) -> Dictionary:
	for module_code in REQUIRED_MODULES:
		if not remote_modules.get(module_code) is Dictionary: return {}
	var base: Dictionary = remote_modules["base"]
	var progression: Dictionary = remote_modules["progression"]
	var localization: Dictionary = _load_json("res://data/localization/zh_cn.json")
	for entry in base.get("i18n", []):
		if str(entry.get("locale", "")) in ["zh-CN", "zh_cn"]:
			localization[str(entry.get("code", ""))] = str(entry.get("text", ""))
	var default_profile: Dictionary = _load_json("res://data/config/default_profile.json")
	for preset in progression.get("newPlayerPresets", []):
		if bool(preset.get("isDefault", false)) and preset.get("payload") is Dictionary:
			default_profile = preset["payload"].duplicate(true)
			break
	var assets_by_code := _index_by_code(base.get("assets", []))
	var reward_packs := _index_by_code(base.get("rewardPacks", []))
	var loot_pools := _index_by_code(base.get("lootPools", []))
	var combat := _adapt_combat(remote_modules["combat"], assets_by_code, reward_packs, loot_pools)
	var maps := _adapt_maps(remote_modules["maps"], assets_by_code, reward_packs)
	var expedition := _adapt_expedition(remote_modules["expedition"], maps, assets_by_code)
	var ling_pu := _adapt_economy(remote_modules["economy"])
	if combat.get("encounters", []).is_empty() or maps.is_empty() or expedition.is_empty(): return {}
	return {
		"localization": localization,
		"expedition": expedition,
		"ling_pu": ling_pu,
		"combat": combat,
		"maps": maps,
		"default_profile": default_profile,
		"assets": base.get("assets", []).duplicate(true),
	}

func _adapt_combat(module: Dictionary, assets: Dictionary, reward_packs: Dictionary, loot_pools: Dictionary) -> Dictionary:
	var skills: Array = []
	for row in module.get("skills", []):
		var skill: Dictionary = row.duplicate(true)
		skill["id"] = str(row.get("code", ""))
		var status := _adapt_skill_status(row.get("effects", []))
		if not status.is_empty(): skill["appliesStatus"] = status
		skills.append(skill)
	var enemies_by_code: Dictionary = {}
	for row in module.get("enemies", []):
		var enemy := {
			"id": str(row.get("code", "")), "nameKey": str(row.get("nameKey", "")),
			"raceKey": str(row.get("raceKey", "")), "maxHp": int(row.get("maxHp", 1)),
			"attributes": {
				"strength": int(row.get("strength", 0)), "magic": int(row.get("magic", 0)),
				"technique": int(row.get("technique", 0)), "speed": int(row.get("speed", 0)),
				"constitution": int(row.get("constitution", 0)), "armor": int(row.get("armor", 0)),
				"resistance": int(row.get("resistance", 0)),
			},
			"skillIds": row.get("skills", []).map(func(skill): return str(skill.get("skillCode", ""))),
		}
		enemies_by_code[enemy["id"]] = enemy
	var encounters: Array = []
	for row in module.get("encounters", []):
		var enemies: Array = []
		for member in row.get("members", []):
			var enemy_code := str(member.get("enemyCode", ""))
			var quantity := maxi(1, int(member.get("quantity", 1)))
			for copy_index in quantity:
				var enemy: Dictionary = enemies_by_code.get(enemy_code, {}).duplicate(true)
				if enemy.is_empty(): continue
				if quantity > 1: enemy["id"] = "%s_%d" % [enemy_code, copy_index + 1]
				enemy["definitionId"] = enemy_code
				enemy["initialActionTimer"] = int(member.get("initialActionTimer", 45))
				enemies.append(enemy)
		var encounter := {
			"id": str(row.get("code", "")),
			"escapeEnemyHpPercent": int(row.get("escapeEnemyHpPercent", 35)),
			"soulCrystalReward": _reward_amount(reward_packs.get(str(row.get("firstClearRewardPackCode", "")), {}), "soulCrystal"),
			"enemies": enemies,
			"loot": _loot_entries(loot_pools.get(str(row.get("lootPoolCode", "")), {}), assets),
		}
		encounters.append(encounter)
	var parameters: Dictionary = {}
	for row in module.get("parameters", []):
		if str(row.get("code", "")) == "default" or parameters.is_empty(): parameters = row
	return {
		"defenseLevelConstant": int(parameters.get("defenseBase", 100)),
		"partyInitialActionTimers": parameters.get("partyInitialActionTimers", [30, 40, 50, 60]),
		"skills": skills,
		"encounters": encounters,
	}

func _adapt_skill_status(effects: Array) -> Dictionary:
	for effect in effects:
		if str(effect.get("effectType", "")) not in ["status", "purify"]: continue
		var parameters: Dictionary = effect.get("parameterJson", {}) if effect.get("parameterJson") is Dictionary else {}
		return {
			"kind": str(parameters.get("statusCode", effect.get("effectType", ""))),
			"durationTicks": int(effect.get("durationTicks", 0)),
			"magnitude": int(effect.get("magnitudeInt", 0)),
		}
	return {}

func _adapt_maps(module: Dictionary, assets: Dictionary, reward_packs: Dictionary) -> Dictionary:
	var prototypes := _index_by_code(module.get("prototypes", []))
	var result: Dictionary = {}
	for row in module.get("maps", []):
		if str(row.get("status", "active")) != "active" or row.get("terrainDocument") == null: continue
		var objects: Array = []
		for placement in row.get("placements", []):
			var prototype: Dictionary = prototypes.get(str(placement.get("prototypeCode", "")), {})
			if prototype.is_empty(): continue
			var object: Dictionary = prototype.get("interactionConfig", {}).duplicate(true) if prototype.get("interactionConfig") is Dictionary else {}
			object.merge({
				"id": str(placement.get("instanceCode", "")), "kind": str(prototype.get("kind", "")),
				"x": int(placement.get("x", 0)), "y": int(placement.get("y", 0)),
				"title": str(prototype.get("title", "")), "description": str(prototype.get("description", "")),
				"encounterId": str(prototype.get("encounterCode", "")), "refreshType": str(prototype.get("refreshType", "permanent")),
			}, true)
			var reward_code := str(placement.get("firstRewardPackCode", prototype.get("rewardPackCode", "")))
			var reward := _single_reward(reward_packs.get(reward_code, {}), assets)
			if not reward.is_empty(): object["reward"] = reward
			objects.append(object)
		var map_id := str(row.get("code", ""))
		var terrain: Dictionary = row.get("terrainDocument", {}) if row.get("terrainDocument") is Dictionary else {}
		result[map_id] = {
			"id": map_id, "name": str(row.get("displayName", row.get("nameKey", map_id))),
			"nameKey": str(row.get("nameKey", "")), "mapNumber": int(row.get("mapNumber", 0)),
			"activeWidth": int(row.get("activeWidth", 0)), "activeHeight": int(row.get("activeHeight", 0)),
			"entryX": int(row.get("entryX", 0)), "entryY": int(row.get("entryY", 0)),
			"terrainRows": terrain.get("rows", []), "objects": objects,
			"visual": row.get("visualConfig", {}).duplicate(true) if row.get("visualConfig") is Dictionary else {},
			"expeditionRule": row.get("expeditionRule", {}),
			"unlockCondition": row.get("unlockCondition", null),
		}
	return result

func _adapt_expedition(module: Dictionary, maps: Dictionary, assets: Dictionary) -> Dictionary:
	var rule: Dictionary = {}
	for row in module.get("rules", []):
		if str(row.get("code", "")) == "default" or rule.is_empty(): rule = row
	if rule.is_empty(): return {}
	var items: Array = []
	for row in module.get("items", []):
		var asset_code := str(row.get("assetCode", ""))
		var asset: Dictionary = assets.get(asset_code, {})
		items.append({
			"id": asset_code, "inventoryId": asset_code if str(asset.get("storageKind", "")) == "inventory" else null,
			"nameKey": str(asset.get("nameKey", asset_code)),
			"weight": int(row.get("weightOverride", asset.get("weight", 0))) if row.get("weightOverride") != null else int(asset.get("weight", 0)),
		})
	var food_items: Array = []
	for row in module.get("foodRest", []):
		var asset_code := str(row.get("assetCode", ""))
		var asset: Dictionary = assets.get(asset_code, {})
		food_items.append({
			"itemId": asset_code, "nameKey": str(asset.get("nameKey", asset_code)),
			"weight": int(asset.get("weight", rule.get("defaultLootWeight", 1))), "grainRestored": int(row.get("grainRestored", 0)),
		})
	var map_rules: Array = []
	for map_id in maps:
		var map_data: Dictionary = maps[map_id]
		var map_rule: Dictionary = map_data.get("expeditionRule", {})
		var unlock_condition: Dictionary = map_data.get("unlockCondition", {}) if map_data.get("unlockCondition") is Dictionary else {}
		map_rules.append({
			"mapId": map_id, "mapNumber": int(map_data.get("mapNumber", 0)), "nameKey": str(map_data.get("nameKey", "")),
			"staminaCost": int(map_rule.get("staminaCost", 0)), "grainPerStep": int(map_rule.get("grainPerStep", 1)),
			"minimumCarriedGrain": int(map_rule.get("minimumCarriedGrain", 0)), "unlockFlag": str(unlock_condition.get("flag", "")) if unlock_condition.has("flag") else "",
			"discoveryRadius": int(map_rule.get("discoveryRadiusOverride", 2)) if map_rule.get("discoveryRadiusOverride") != null else 2,
			"restCount": int(map_rule.get("restCountOverride", rule.get("baseRestCount", 1))) if map_rule.get("restCountOverride") != null else int(rule.get("baseRestCount", 1)),
		})
	return {
		"staminaMax": int(rule.get("staminaMax", 100)), "staminaRecoveryAmount": int(rule.get("staminaRecoveryAmount", 1)),
		"staminaRecoveryIntervalSeconds": int(rule.get("staminaRecoveryIntervalSeconds", 300)),
		"baseBurden": int(rule.get("baseBurden", 60)), "strengthBurdenFactor": int(rule.get("strengthBurdenFactor", 2)),
		"constitutionBurdenFactor": int(rule.get("constitutionBurdenFactor", 1)), "maxPartyPresets": int(rule.get("maxPartyPresets", 3)),
		"partyUnlockCosts": rule.get("partyUnlockCosts", []), "items": items, "maps": map_rules,
		"materialLossBasisPoints": int(rule.get("materialLossBasisPoints", 5000)),
		"equipmentLossBasisPoints": int(rule.get("equipmentLossBasisPoints", 5000)),
		"field": {
			"restUseLimitsByForgeLevel": [int(rule.get("baseRestCount", 1))],
			"grainDepletionStepLimit": int(rule.get("grainDepletionStepLimit", 4)),
			"healingPercent": int(rule.get("fieldHealingPercent", 25)), "defaultLootWeight": int(rule.get("defaultLootWeight", 1)),
			"foodItems": food_items, "returnTalismanItemId": str(rule.get("returnTalismanAssetCode", "return_talisman")),
		},
	}

func _adapt_economy(module: Dictionary) -> Dictionary:
	var rule: Dictionary = {}
	for row in module.get("rules", []):
		if str(row.get("code", "")) == "default" or rule.is_empty(): rule = row
	var resources: Dictionary = {}
	for row in module.get("storageLevels", []):
		var asset_code := str(row.get("assetCode", ""))
		if not resources.has(asset_code): resources[asset_code] = {"initialLevel": 1, "capacities": [], "upgradeSpiritWoodCosts": []}
		resources[asset_code]["capacities"].append(int(row.get("capacity", 0)))
		if row.get("upgradeCostAssetCode") != null: resources[asset_code]["upgradeSpiritWoodCosts"].append(int(row.get("upgradeCostAmount", 0)))
	return {
		"baseCycleSeconds": int(rule.get("baseCycleSeconds", 30)),
		"maxOfflineCycles": int(rule.get("maxOfflineCycles", 960)),
		"initialWorkerCount": int(rule.get("initialWorkerCount", 6)),
		"workersPerRecruit": int(rule.get("workersPerRecruit", 5)),
		"recruitSpiritGrainCost": int(rule.get("recruitCostAmount", 50)),
		"jobs": module.get("jobs", []).map(func(job): return {
			"id": str(job.get("code", "")), "outputAssetCode": str(job.get("outputAssetCode", job.get("code", ""))),
			"outputPerWorker": int(job.get("outputPerWorker", 1)), "upkeepPerWorker": int(job.get("upkeepPerWorker", 0)),
			"shutdownPriority": job.get("shutdownPriority", null),
		}),
		"resources": resources,
	}

func _index_by_code(rows: Array) -> Dictionary:
	var result: Dictionary = {}
	for row in rows: result[str(row.get("code", ""))] = row
	return result

func _reward_amount(reward_pack: Dictionary, asset_code: String) -> int:
	var amount := 0
	for entry in reward_pack.get("entries", []):
		if str(entry.get("assetCode", "")) == asset_code: amount += int(entry.get("quantityMin", 0))
	return amount

func _single_reward(reward_pack: Dictionary, assets: Dictionary) -> Dictionary:
	var entries: Array = reward_pack.get("entries", [])
	if entries.is_empty(): return {}
	var entry: Dictionary = entries.front()
	var asset_code := str(entry.get("assetCode", ""))
	var asset: Dictionary = assets.get(asset_code, {})
	return {"itemId": asset_code, "itemName": str(asset.get("nameKey", asset_code)), "nameKey": str(asset.get("nameKey", asset_code)), "amount": int(entry.get("quantityMin", 1))}

func _loot_entries(loot_pool: Dictionary, assets: Dictionary) -> Array:
	var result: Array = []
	for entry in loot_pool.get("entries", []):
		var asset_code := str(entry.get("assetCode", ""))
		if asset_code.is_empty(): continue
		var asset: Dictionary = assets.get(asset_code, {})
		result.append({"itemId": asset_code, "nameKey": str(asset.get("nameKey", asset_code)), "amount": int(entry.get("quantityMin", 1))})
	return result

func _load_cached_release() -> void:
	if not FileAccess.file_exists(CACHE_MANIFEST_PATH): return
	var cached_manifest: Variant = _load_json(CACHE_MANIFEST_PATH)
	if not cached_manifest is Dictionary or int(cached_manifest.get("schemaVersion", 0)) > CLIENT_SCHEMA_VERSION: return
	var cached_modules: Dictionary = {}
	var module_manifest: Dictionary = cached_manifest.get("modules", {})
	for module_code in REQUIRED_MODULES:
		var metadata: Dictionary = module_manifest.get(module_code, {})
		var path := "%s/modules/%s.json" % [CACHE_ROOT, str(metadata.get("sha256", ""))]
		if metadata.is_empty() or not FileAccess.file_exists(path): return
		var body := FileAccess.get_file_as_bytes(path)
		if body.size() != int(metadata.get("byteSize", -1)) or _sha256_hex(body) != str(metadata.get("sha256", "")): return
		var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
		if not parsed is Dictionary: return
		cached_modules[module_code] = parsed
	var adapted := _adapt_remote_modules(cached_modules)
	if adapted.is_empty(): return
	modules = cached_modules
	manifest = cached_manifest
	runtime_tables = adapted
	source = "cache"
	version = str(cached_manifest.get("version", cached_manifest.get("releaseId", "cache")))

func _save_cache(remote_manifest: Dictionary, remote_module_bytes: Dictionary) -> void:
	var absolute_root := ProjectSettings.globalize_path(CACHE_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)
	for module_code in REQUIRED_MODULES:
		var metadata: Dictionary = remote_manifest.get("modules", {}).get(module_code, {})
		var module_path := "%s/modules/%s.json" % [CACHE_ROOT, str(metadata.get("sha256", ""))]
		var module_root := ProjectSettings.globalize_path(CACHE_ROOT + "/modules")
		DirAccess.make_dir_recursive_absolute(module_root)
		if not FileAccess.file_exists(module_path): _write_atomic_bytes(module_path, remote_module_bytes[module_code])
	_write_atomic(CACHE_MANIFEST_PATH, JSON.stringify(remote_manifest))

func _write_atomic_bytes(path: String, contents: PackedByteArray) -> void:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null: return
	file.store_buffer(contents)
	file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(absolute_path)
	DirAccess.rename_absolute(absolute_temporary_path, absolute_path)

func _write_atomic(path: String, contents: String) -> void:
	var temporary_path := path + ".tmp"
	var file := FileAccess.open(temporary_path, FileAccess.WRITE)
	if file == null: return
	file.store_string(contents)
	file.close()
	var absolute_path := ProjectSettings.globalize_path(path)
	var absolute_temporary_path := ProjectSettings.globalize_path(temporary_path)
	if FileAccess.file_exists(path): DirAccess.remove_absolute(absolute_path)
	DirAccess.rename_absolute(absolute_temporary_path, absolute_path)

func _request_bytes(url: String) -> Dictionary:
	if not url.begins_with("http://") and not url.begins_with("https://"): return {"ok": false}
	var request := HTTPRequest.new()
	request.timeout = float(ProjectSettings.get_setting("kunwu/config_request_timeout_seconds", 3.0))
	request.accept_gzip = true
	add_child(request)
	var start_error := request.request(url, ["Accept: application/json"])
	if start_error != OK:
		request.queue_free()
		return {"ok": false, "error": start_error}
	var response: Array = await request.request_completed
	request.queue_free()
	var result := int(response[0])
	var response_code := int(response[1])
	return {"ok": result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300, "status": response_code, "body": response[3]}

func _absolute_url(base_url: String, path: String) -> String:
	if path.begins_with("http://") or path.begins_with("https://"): return path
	return base_url + (path if path.begins_with("/") else "/" + path)

func _sha256_hex(bytes: PackedByteArray) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish().hex_encode()

func _load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed != null else {}

func _source_label() -> String:
	return "缓存配置" if source == "cache" else "内置配置"
