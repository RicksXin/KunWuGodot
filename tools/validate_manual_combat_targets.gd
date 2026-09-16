extends Node

var errors: Array[String] = []
var combat: Control

func _ready() -> void:
	call_deferred("_run")

func _check(condition: bool, message: String) -> void:
	if not condition:
		errors.append(message)

func _prepare(actor: Dictionary, skills: Array) -> void:
	combat.call("_clear_target_selection")
	for unit in combat.get("units"):
		unit["auto"] = true
	actor["auto"] = false
	actor["timer"] = 0
	actor["cooldowns"] = {}
	actor["statuses"] = []
	actor["skills"] = skills
	combat.call("_refresh")

func _click_target(unit_id: int, on_name: bool = false) -> void:
	var button: Button = combat.get("target_buttons")[unit_id]
	var rect := button.get_global_rect()
	var click_position := rect.position + Vector2(rect.size.x * 0.5, 189) if on_name else rect.get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = click_position
		get_viewport().push_input(event, true)

func _run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		push_error("Requires --no-profile-write")
		get_tree().quit(1)
		return
	Game.profile = JSON.parse_string(FileAccess.get_file_as_string("res://data/config/default_profile.json"))
	Game.combat_config = Game.combat_config.duplicate(true)
	var encounter: Dictionary = Game.combat_config["encounters"][0]
	encounter["enemies"] = [encounter["enemies"][0].duplicate(true), encounter["enemies"][0].duplicate(true)]
	Game.profile["expedition"] = {
		"mapId": "map_01", "partyPresetId": "party_01",
		"partyMemberIds": ["hero_wu_xiu_01", "hero_fa_xiu_01", "hero_yi_xiu_01", "hero_qian_xiu_01"],
		"encounterId": encounter["id"], "temporaryLoot": {},
	}
	combat = load("res://scenes/combat.tscn").instantiate()
	add_child(combat)
	combat.set_process(false)
	await get_tree().process_frame
	var allies: Array = combat.call("_living_units", "ally")
	var enemies: Array = combat.call("_living_units", "enemy")
	if allies.size() < 4 or enemies.size() < 2:
		push_error("Target selection fixture requires four allies and two enemies")
		get_tree().quit(1)
		return
	var actor: Dictionary = allies[0]
	var victim: Dictionary = enemies[1]
	_prepare(actor, ["zhan_ji", "tiao_xin", "chong_zhuang"])
	var original_hp := int(victim["hp"])
	var other_hp := int(enemies[0]["hp"])
	combat.call("_choose_skill", 0)
	_check(int(victim["hp"]) == original_hp and int(actor["timer"]) == 0 and actor["cooldowns"].is_empty(), "Selecting a skill must not spend action/cooldown or cause damage")
	combat.call("_choose_target", int(allies[1]["unit_id"]))
	_check(int(actor["timer"]) == 0, "Attack cannot select ally")
	combat.call("_set_combat_paused", true)
	combat.call("_choose_target", int(victim["unit_id"]))
	_check(int(victim["hp"]) == original_hp, "Paused battle cannot confirm a target")
	combat.call("_set_combat_paused", false)
	# Exercise the actual card hit area, including interception above the unit UI.
	_click_target(int(victim["unit_id"]))
	_check(int(victim["hp"]) < original_hp and int(enemies[0]["hp"]) == other_hp, "Actual target click must damage only chosen enemy")
	_check(int(actor["timer"]) > 0 and combat.get("pending_skill_id") == "", "Confirmed skill must consume action and clear selection")
	var hp_after := int(victim["hp"])
	combat.call("_choose_target", int(victim["unit_id"]))
	_check(int(victim["hp"]) == hp_after, "Repeated target click must not cast twice")

	_prepare(actor, ["hui_chun_shu", "ning_shuang_hu"])
	allies[1]["hp"] = 1
	allies[2]["hp"] = int(allies[2]["max_hp"]) - 40
	var heal_hp := int(allies[2]["hp"])
	combat.call("_choose_skill", 0)
	_click_target(int(allies[2]["unit_id"]), true)
	_check(int(allies[2]["hp"]) > heal_hp and int(allies[1]["hp"]) == 1, "Manual heal must honor chosen ally instead of lowest HP")
	_check(bool(allies[2]["auto"]), "Clicking ally name during target selection must not toggle auto mode")
	_prepare(actor, ["ning_shuang_hu"])
	combat.call("_choose_skill", 0)
	combat.call("_choose_target", int(allies[2]["unit_id"]))
	_check(int(allies[2]["shield"]) > 0 and int(allies[1]["shield"]) == 0, "Shield must honor selected ally")

	_prepare(actor, ["zhan_ji", "tiao_xin"])
	combat.call("_choose_skill", 0)
	combat.call("_cancel_target_selection")
	_check(combat.get("pending_skill_id") == "" and int(actor["timer"]) == 0 and actor["cooldowns"].is_empty(), "Cancel must be free")
	combat.call("_choose_skill", 0)
	victim["dead"] = true
	combat.call("_choose_target", int(victim["unit_id"]))
	_check(int(actor["timer"]) == 0, "Dead target cannot consume action")
	victim["dead"] = false
	combat.call("_choose_skill", 1)
	_check(int(actor["timer"]) > 0 and combat.get("pending_skill_id") == "", "Self skill must release directly")

	_prepare(allies[2], ["zhan_ji"])
	combat.call("_choose_skill", 0)
	actor["auto"] = false
	actor["timer"] = 0
	combat.call("_refresh_skill_panel")
	_check(int(combat.get("pending_actor_id")) == int(allies[2]["unit_id"]), "A newly ready ally must not steal pending actor")
	combat.call("_toggle_auto", int(allies[2]["unit_id"]))
	_check(combat.get("pending_skill_id") == "", "Switching caster to auto must clear pending selection")
	_prepare(actor, ["ling_neng_zhen_dang"])
	combat.call("_choose_skill", 0)
	_check(int(actor["timer"]) > 0 and combat.get("pending_skill_id") == "", "Area skill must release directly")
	combat.queue_free()
	await get_tree().process_frame
	if errors.is_empty():
		print("MANUAL_COMBAT_TARGETS_OK")
	else:
		for message in errors:
			push_error(message)
	get_tree().quit(0 if errors.is_empty() else 1)
