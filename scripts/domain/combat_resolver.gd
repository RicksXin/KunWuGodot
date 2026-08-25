class_name KWCombatResolver
extends RefCounted

static func skill_by_id(catalog: Dictionary, skill_id: String) -> Dictionary:
	for skill in catalog.get("skills", []):
		if str(skill.get("id", "")) == skill_id: return skill
	return {}

static func physical_damage(attacker: Dictionary, defender: Dictionary, skill: Dictionary, defense_constant: int) -> int:
	var attrs: Dictionary = attacker.get("attrs", {})
	var target_attrs: Dictionary = defender.get("attrs", {})
	var primary := int(attrs.get(str(skill.get("primaryAttribute", "strength")), 0))
	var secondary := int(attrs.get(str(skill.get("secondaryAttribute", "")), 0))
	var raw := float(primary * int(skill.get("primaryPercent", 100)) + secondary * int(skill.get("secondaryPercent", 0))) / 100.0
	var defense_key := "armor" if str(skill.get("damageKind", "physical")) == "physical" else "resistance"
	var defense := int(target_attrs.get(defense_key, 0))
	var multiplier := float(defense_constant) / float(defense_constant + defense)
	return maxi(1, int(round(raw * multiplier)))

static func damage_amount(attacker: Dictionary, defender: Dictionary, skill: Dictionary, defense_constant: int, outgoing_percent: int = 100, incoming_percent: int = 100) -> int:
	var base := physical_damage(attacker, defender, skill, defense_constant)
	return maxi(1, int(round(float(base) * float(outgoing_percent) * float(incoming_percent) / 10000.0)))

static func action_interval(base_ticks: int, statuses: Array, percent_modifier: int = 100) -> int:
	var interval := maxi(1, base_ticks)
	var slow_percent := 0
	var haste_percent := 0
	for status in statuses:
		match str(status.get("kind", "")):
			"slow": slow_percent = maxi(slow_percent, int(status.get("magnitude", 0)))
			"haste": haste_percent = maxi(haste_percent, int(status.get("magnitude", 0)))
	var status_percent := maxi(25, 100 + slow_percent - haste_percent)
	return maxi(1, int(round(float(interval) * float(status_percent) * float(percent_modifier) / 10000.0)))

static func counter_damage(counter_strength: int, percent: int, defender: Dictionary, defense_constant: int) -> int:
	var attacker := {"attrs": {"strength": counter_strength}}
	var skill := {"damageKind": "physical", "primaryAttribute": "strength", "primaryPercent": percent}
	return physical_damage(attacker, defender, skill, defense_constant)

static func heal_amount(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	var attrs: Dictionary = attacker.get("attrs", {})
	var primary := int(attrs.get(str(skill.get("primaryAttribute", "magic")), 0))
	return maxi(1, int(round(primary * maxf(1.0, float(skill.get("primaryPercent", 100))) / 100.0)))
