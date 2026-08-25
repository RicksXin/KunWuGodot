extends SceneTree

var errors: Array[String] = []

func _initialize() -> void:
	call_deferred("_validate")

func _validate() -> void:
	if not OS.get_cmdline_user_args().has("--no-profile-write"):
		_fail("validation requires --no-profile-write")
		_finish()
		return
	var game: Node = root.get_node_or_null("Game")
	var repository: Node = root.get_node_or_null("ConfigRepository")
	if game == null or repository == null:
		_fail("configuration autoloads are missing")
		_finish()
		return
	if not OS.get_cmdline_user_args().has("--offline"):
		var result: Dictionary = await game.call("refresh_remote_config")
		_assert(result.get("ok", false), "远端配置未成功加载: %s" % result.get("message", ""))
	var expected_source := _argument_value("--expected-source=")
	if not expected_source.is_empty(): _assert(repository.get("source") == expected_source, "配置来源不符合预期")
	var expected_version := _argument_value("--expected-version=")
	if not expected_version.is_empty(): _assert(repository.get("version") == expected_version, "配置版本不符合预期")
	var loaded_modules: Dictionary = repository.get("modules")
	if repository.get("source") == "embedded": _assert(loaded_modules.is_empty(), "内置回退不应伪造发布模块")
	else: _assert(loaded_modules.size() == 6, "发布模块数量不完整")
	var map_definition: Dictionary = game.call("get_map_definition", "map_01")
	var formal_map: bool = map_definition.get("objects", []).size() == 31
	_assert(not map_definition.is_empty() and map_definition.get("objects", []).size() in [3, 31], "地图模块适配失败")
	var encounter_id: String = "m1_g01" if formal_map else "can_jin_shi_kui"
	var map_object_id: String = "m1_g01" if formal_map else "can_jin_shi_kui_01"
	var expected_enemy_count: int = 2 if formal_map else 1
	var encounter: Dictionary = game.call("get_encounter", encounter_id)
	_assert(not encounter.is_empty() and encounter.get("enemies", []).size() == expected_enemy_count, "战斗模块适配失败")
	var map_rule: Dictionary = game.call("get_expedition_map_rule", "map_01")
	_assert(int(map_rule.get("minimumCarriedGrain", 0)) == 20, "出征模块适配失败")
	_assert(game.call("item_weight", "pickaxe") == 12 and game.call("item_weight", "lens") == 4, "基础资源重量适配失败")
	var ling_pu: Dictionary = game.get("ling_pu_config")
	_assert(int(ling_pu.get("recruitSpiritGrainCost", 0)) == 50, "生产模块适配失败")
	_validate_runtime_state(game, map_definition, encounter_id, map_object_id)
	if errors.is_empty(): print("CONFIG_REPOSITORY_VALIDATION_OK source=%s version=%s modules=%d" % [repository.get("source"), repository.get("version"), loaded_modules.size()])
	_finish()

func _validate_runtime_state(game: Node, map_definition: Dictionary, encounter_id: String, map_object_id: String) -> void:
	var runtime_profile: Dictionary = game.get("default_profile").duplicate(true)
	runtime_profile["camp"]["lastSettledAtUtc"] = int(game.call("now")) - 31
	runtime_profile["camp"]["workerAssignments"] = {"spiritGrain": 0, "spiritWood": 1, "darkIron": 0, "spiritStone": 0, "gengJing": 0}
	runtime_profile["wallet"]["spiritGrain"] = 100
	runtime_profile["wallet"]["spiritWood"] = 0
	game.set("profile", runtime_profile)
	game.call("settle_production")
	runtime_profile = game.get("profile")
	_assert(int(runtime_profile["wallet"]["spiritGrain"]) == 100 and int(runtime_profile["wallet"]["spiritWood"]) == 1, "economy 岗位配置未驱动生产结算: grain=%s wood=%s jobs=%s" % [runtime_profile["wallet"]["spiritGrain"], runtime_profile["wallet"]["spiritWood"], game.get("ling_pu_config").get("jobs", [])])
	var shutdown_profile: Dictionary = game.get("default_profile").duplicate(true)
	shutdown_profile["camp"]["lastSettledAtUtc"] = int(game.call("now")) - 31
	shutdown_profile["camp"]["workerAssignments"] = {"spiritGrain": 0, "spiritWood": 1, "darkIron": 0, "spiritStone": 0, "gengJing": 0}
	shutdown_profile["wallet"]["spiritGrain"] = 0
	shutdown_profile["wallet"]["spiritWood"] = 0
	game.set("profile", shutdown_profile)
	game.call("settle_production")
	shutdown_profile = game.get("profile")
	_assert(int(shutdown_profile["wallet"]["spiritWood"]) == 0, "维护不足时岗位未按 economy 配置停工")
	game.set("profile", runtime_profile)
	var start_result: Dictionary = game.call("start_expedition", {"spiritGrain": 20, "pickaxe": 0, "lens": 0}, "map_01")
	_assert(start_result.get("ok", false), "按 mapId 开始出征失败: %s" % start_result.get("message", ""))
	if not start_result.get("ok", false): return
	runtime_profile = game.get("profile")
	var expedition: Dictionary = runtime_profile.get("expedition", {})
	_assert(expedition.get("mapId") == "map_01" and expedition.get("partyPresetId") == "party_01", "出征未记录地图或队伍稳定 ID")
	var encounter_object: Dictionary = {}
	for object in map_definition.get("objects", []):
		if str(object.get("encounterId", object.get("enemyId", ""))) == encounter_id: encounter_object = object
	var encounter_result: Dictionary = game.call("begin_encounter", encounter_object)
	_assert(encounter_result.get("ok", false), "按 encounterId 开始遭遇失败")
	expedition = game.get("profile").get("expedition", {})
	_assert(expedition.get("encounterId") == encounter_id and expedition.get("mapObjectId") == map_object_id, "遭遇未记录 encounterId 或 mapObjectId")

func _assert(condition: bool, message: String) -> void:
	if not condition: _fail(message)

func _argument_value(prefix: String) -> String:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with(prefix): return argument.trim_prefix(prefix)
	return ""

func _fail(message: String) -> void:
	errors.append(message)
	push_error(message)

func _finish() -> void:
	quit(0 if errors.is_empty() else 1)
