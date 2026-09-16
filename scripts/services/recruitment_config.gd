extends Node

signal changed
var configuration: Dictionary = {}
var busy := false
var message := "正在加载招募配置"
var base_url := ""
var channel := "development"
var scope := ""

func _ready() -> void:
	base_url = OS.get_environment("KUNWU_RESOURCE_API_URL").strip_edges().trim_suffix("/")
	if base_url.is_empty(): base_url = OS.get_environment("KUNWU_CONFIG_BASE_URL").strip_edges().trim_suffix("/")
	if base_url.is_empty(): base_url = str(ProjectSettings.get_setting("kunwu/resource_config_base_url", "http://127.0.0.1:3100")).trim_suffix("/")
	channel = OS.get_environment("KUNWU_CONFIG_CHANNEL")
	if channel.is_empty(): channel = str(ProjectSettings.get_setting("kunwu/config_channel", "development"))
	scope = (base_url + "|" + channel).sha256_text()
	if OS.get_cmdline_user_args().has("--ignore-config-cache"): return
	var cached: Dictionary = Game.load_recruitment_cache(scope)
	if accept(cached): message = "使用已发布的缓存配置"
	var timer := Timer.new()
	timer.wait_time = 30.0
	timer.timeout.connect(refresh)
	add_child(timer)
	timer.start()
	call_deferred("refresh")

func accept(value: Dictionary) -> bool:
	if int(value.get("schemaVersion", 0)) != 1 or str(value.get("releaseId", "")).is_empty(): return false
	if int(value.get("initialWorkers", -1)) != 6 or int(value.get("maxWorkers", -1)) != 12: return false
	if int(value.get("workersPerRecruit", -1)) != 1: return false
	var costs: Variant = value.get("recruitCosts")
	if not costs is Array or costs.size() != 6: return false
	var previous := 0
	for cost in costs:
		if not cost is String or not cost.is_valid_int(): return false
		var amount: int = cost.to_int()
		if amount <= 0 or amount < previous or str(amount) != cost: return false
		previous = amount
	configuration = value.duplicate(true)
	changed.emit()
	return true

func refresh() -> bool:
	if busy: return false
	busy = true
	var http := HTTPRequest.new()
	http.timeout = 3.0
	add_child(http)
	var success := false
	if http.request("%s/api/game-config/%s/recruitment" % [base_url, channel], ["Accept: application/json"]) == OK:
		var response: Array = await http.request_completed
		if response[0] == HTTPRequest.RESULT_SUCCESS and int(response[1]) == 200:
			var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
			if parsed is Dictionary: success = accept(parsed)
	http.queue_free()
	busy = false
	message = "招募配置已同步" if success else ("使用已发布的缓存配置" if not configuration.is_empty() else "招募配置不可用，请稍后重试")
	if success: Game.save_recruitment_cache(scope, configuration)
	changed.emit()
	return success

func quote(worker_count: int) -> Dictionary:
	if configuration.is_empty(): return {"ok": false, "reason": message, "cost": 0, "grant": 0}
	if worker_count >= int(configuration.maxWorkers):
		return {"ok": false, "reason": "已达招募上限（%d 人）" % int(configuration.maxWorkers), "cost": 0, "grant": 0}
	var index := worker_count - int(configuration.initialWorkers)
	if index < 0: return {"ok": false, "reason": "当前杂役人数与招募配置不匹配", "cost": 0, "grant": 0}
	return {"ok": true, "cost": str(configuration.recruitCosts[index]).to_int(), "grant": 1,
		"workerCount": worker_count, "releaseId": configuration.releaseId, "reason": ""}
