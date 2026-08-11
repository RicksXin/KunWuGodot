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

static func heal_amount(attacker: Dictionary, target: Dictionary, skill: Dictionary) -> int:
	var attrs: Dictionary = attacker.get("attrs", {})
	var primary := int(attrs.get(str(skill.get("primaryAttribute", "magic")), 0))
	return maxi(1, int(round(primary * maxf(1.0, float(skill.get("primaryPercent", 100))) / 100.0)))
