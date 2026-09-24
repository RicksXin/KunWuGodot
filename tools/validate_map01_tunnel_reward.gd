extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
func run() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		quit(1)
		return
	var game := root.get_node("Game")
	var repository := root.get_node("ConfigRepository")
	game.combat_config = repository.formal_map_combat()
	game.profile = game.default_profile.duplicate(true)
	game._normalise_profile()
	check(game.start_expedition().get("ok",false),"start")
	check(game.begin_encounter({"id":"m1_dungeon_tunnel","encounterId":"m1_dungeon_rockfall"}).get("ok",false),"enter tunnel")
	var encounter: Dictionary = game.get_encounter("m1_dungeon_rockfall")
	check(game.finish_encounter_victory(encounter).get("ok",false),"settle tunnel")
	var equipment: Array = game.profile.expedition.get("pendingEquipment",[]).duplicate(true)
	check(equipment.size()==1,"one equipment reward")
	if equipment.size()==1: check(equipment[0].qualityCode=="fa_qi","fa qi quality")
	check(game.finish_encounter_victory(encounter).get("alreadySettled",false),"idempotent settlement")
	check(game.profile.expedition.pendingEquipment==equipment,"no duplicate equipment")
	check(game.take_pending_encounter_loot(),"claim loot")
	check(game.profile.expedition.get("temporaryEquipment",[]).size()==1,"equipment reaches expedition bag")
	if failures.is_empty(): print("MAP01_TUNNEL_REWARD: PASS")
	else:
		for message in failures: push_error(message)
	quit(0 if failures.is_empty() else 1)
