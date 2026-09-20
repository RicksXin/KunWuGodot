class_name KWEquipment
extends RefCounted

const ATTRIBUTES := ["strength", "magic", "technique", "speed", "constitution", "armor", "resistance"]
const SLOTS := ["weapon", "armor", "accessory_1", "accessory_2"]

static func ensure(profile: Dictionary) -> Dictionary:
	if not profile.get("equipment") is Dictionary:
		profile["equipment"] = {"instances": {}, "loadouts": {}, "pending": {}}
	var state: Dictionary = profile["equipment"]
	for key in ["instances", "loadouts", "pending"]:
		if not state.get(key) is Dictionary: state[key] = {}
	return state

static func stable_roll(seed_text: String, bound: int) -> int:
	# SHA-256 prefix avoids RNG-global state and Godot hash implementation changes.
	return int(seed_text.sha256_text().left(8).hex_to_int() % maxi(1, bound))

static func generate(catalog: Dictionary, seed_text: String, quality: String) -> Dictionary:
	var multipliers: Dictionary = catalog.get("qualityMultipliers", {})
	var pool: Array = catalog.get("pool", [])
	if not multipliers.has(quality) or pool.is_empty(): return {}
	var code := str(pool[stable_roll(seed_text + ":template", pool.size())])
	var definition: Dictionary = {}
	for entry in catalog.get("templates", []):
		if entry.get("code") == code: definition = entry
	if definition.is_empty(): return {}
	var allowed: Array = definition.get("allowedStats", [])
	if allowed.is_empty(): return {}
	var stats: Dictionary = {}
	var runes: Array = []
	for index in int(definition.get("runeSlots", 1)):
		var attribute := str(allowed[stable_roll(seed_text + ":rune:" + str(index), allowed.size())])
		if attribute not in ATTRIBUTES: return {}
		var amount := maxi(1, int(floor(float(definition.get("baseStatBudget", 1)) * int(multipliers[quality]) / 100.0)))
		stats[attribute] = int(stats.get(attribute, 0)) + amount
		runes.append({"attribute": attribute, "amount": amount})
	return {"seed": seed_text, "instanceId": "eq_" + seed_text.sha256_text().left(24), "templateCode": code, "name": definition.get("name", code), "qualityCode": quality, "slot": definition.get("slot", "armor"), "careers": definition.get("careers", []).duplicate(), "stats": stats, "runes": runes, "locked": false}

static func owner(state: Dictionary, instance_id: String) -> String:
	for hero_id in state.get("loadouts", {}):
		if instance_id in state["loadouts"][hero_id].values(): return str(hero_id)
	return ""

static func store(profile: Dictionary, items: Array, capacity: int) -> void:
	var state := ensure(profile)
	for item in items:
		var id := str(item.get("instanceId", ""))
		if id.is_empty() or state["instances"].has(id) or state["pending"].has(id): continue
		if state["instances"].size() < capacity: state["instances"][id] = item.duplicate(true)
		else: state["pending"][id] = item.duplicate(true)

static func claim_pending(profile: Dictionary, capacity: int) -> int:
	var state := ensure(profile)
	var claimed := 0
	for id in state["pending"].keys():
		if state["instances"].size() >= capacity: break
		state["instances"][id] = state["pending"][id]
		state["pending"].erase(id)
		claimed += 1
	return claimed

static func equip(profile: Dictionary, hero_id: String, instance_id: String, slot: String) -> Dictionary:
	if profile.get("expedition") is Dictionary: return {"ok": false, "message": "请归营后调整装备"}
	var state := ensure(profile)
	var item: Dictionary = state["instances"].get(instance_id, {})
	var hero: Dictionary = {}
	for candidate in profile.get("roster", []):
		if candidate.get("instanceId") == hero_id: hero = candidate
	if hero.is_empty() or item.is_empty() or slot not in SLOTS: return {"ok": false, "message": "装备或修士不存在"}
	var wanted := str(item.get("slot", ""))
	if (wanted == "accessory" and not slot.begins_with("accessory_")) or (wanted != "accessory" and wanted != slot): return {"ok": false, "message": "装备槽位不符"}
	var careers: Array = item.get("careers", [])
	if not careers.is_empty() and str(hero.get("careerId", "")) not in careers: return {"ok": false, "message": "职业不能使用此武器"}
	var current_owner := owner(state, instance_id)
	if not current_owner.is_empty() and current_owner != hero_id: return {"ok": false, "message": "已由其他修士装备"}
	var loadout: Dictionary = state["loadouts"].get(hero_id, {})
	for other_slot in loadout:
		var equipped: Dictionary = state["instances"].get(loadout[other_slot], {})
		if other_slot != slot and (loadout[other_slot] == instance_id or (wanted == "accessory" and equipped.get("templateCode") == item.get("templateCode"))): return {"ok": false, "message": "不可重复装备同一实例或同名饰品"}
	loadout[slot] = instance_id
	state["loadouts"][hero_id] = loadout
	return {"ok": true, "message": "已装备"}

static func bonuses(profile: Dictionary, hero_id: String) -> Dictionary:
	var state := ensure(profile)
	var result: Dictionary = {}
	var counted: Dictionary = {}
	for id in state["loadouts"].get(hero_id, {}).values():
		if counted.has(id): continue
		counted[id] = true
		var item: Dictionary = state["instances"].get(id, {})
		for attribute in ATTRIBUTES:
			result[attribute] = int(result.get(attribute, 0)) + int(item.get("stats", {}).get(attribute, 0))
	return result

static func retained_loot(items: Dictionary, protected_codes: Array, asset_definitions: Dictionary, loss_basis_points: int = 3000) -> Dictionary:
	var retained: Dictionary = {}
	for code in items:
		var amount := maxi(0, int(items[code]))
		var protected: bool = code in protected_codes or bool(asset_definitions.get(code, {}).get("isProtected", false))
		retained[code] = amount if protected else amount - ceili(amount * clampi(loss_basis_points, 0, 10000) / 10000.0)
	return retained

static func retained_equipment(items: Array, expedition_seed: String, loss_basis_points: int = 3000) -> Array:
	return items.filter(func(item): return bool(item.get("protected", false)) or stable_roll(expedition_seed + ":loss:" + str(item.get("instanceId", "")), 10000) >= clampi(loss_basis_points, 0, 10000))
