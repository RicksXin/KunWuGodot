extends Node

signal changed

const CODES := ["spiritGrain", "spiritWood", "darkIron", "spiritCrystal", "gengJing"]
var snapshot: Dictionary = {}
var pending: Dictionary = {}
var busy := false
var connected := false
var message := "正在连接生产服务"
var base_url := ""
var received_ticks := 0
var _token := ""
var _scope := ""
var _http: HTTPRequest

func _ready() -> void:
	base_url = OS.get_environment("KUNWU_RESOURCE_API_URL").trim_suffix("/")
	if base_url.is_empty(): base_url = "http://127.0.0.1:3100"
	_token = OS.get_environment("KUNWU_RESOURCE_TOKEN")
	_scope = (base_url + "|" + _token).sha256_text()
	_http = HTTPRequest.new()
	_http.timeout = 12.0
	add_child(_http)
	var cached: Dictionary = Game.load_resource_test_cache(_scope)
	if cached.get("scope", "") == _scope:
		pending = cached.get("pending", {})
		var saved: Dictionary = cached.get("snapshot", {})
		if _valid_snapshot(saved): snapshot = saved
	if _token.is_empty(): message = "未配置测试身份，请通过在线测试启动器打开"

func _cache() -> void:
	Game.save_resource_test_cache({"scope": _scope, "pending": pending, "snapshot": snapshot})

func _valid_amount(value: Variant) -> bool:
	if not value is String: return false
	var number: String = value
	return number.is_valid_int() and number.to_int() >= 0 and str(number.to_int()) == number

func _valid_snapshot(value: Dictionary) -> bool:
	if int(value.get("schemaVersion", 0)) != 1 or not _valid_amount(value.get("stateVersion")): return false
	if not value.get("state") is Dictionary or not value.get("capacities") is Dictionary: return false
	var state: Dictionary = value["state"]
	if not state.get("balances") is Dictionary or not state.get("workers") is Array: return false
	if not state.get("storageLevels") is Dictionary or not value.get("rulesSummary") is Dictionary: return false
	var rules: Dictionary = value.rulesSummary
	if not rules.get("jobs") is Array or rules.jobs.size() != 5: return false
	if not rules.get("cyclesMs") is Array or rules.cyclesMs.size() != 3: return false
	if int(state.get("dewLevel", -1)) < 0 or int(state.get("dewLevel", -1)) > 2: return false
	if state.workers.size() < 6 or state.workers.size() > 12: return false
	for worker in state.workers:
		if not worker is Dictionary or not worker.get("progress") is Array or worker.progress.size() != 2: return false
		if not _valid_amount(worker.progress[0]) or not _valid_amount(worker.progress[1]) or str(worker.progress[1]) == "0": return false
		if worker.get("job") != null and not CODES.has(worker.job): return false
	for code in CODES:
		if not _valid_amount(state.balances.get(code)) or not _valid_amount(value.capacities.get(code)): return false
		if int(state.storageLevels.get(code, 0)) < 1 or int(state.storageLevels.get(code, 0)) > 5: return false
	return true

func _accept(value: Dictionary) -> void:
	if not _valid_snapshot(value): return
	var incoming := str(value.stateVersion).to_int()
	var current := str(snapshot.get("stateVersion", "0")).to_int()
	if incoming < current: return
	if incoming == current and float(value.get("serverTimeMs", 0)) < float(snapshot.get("serverTimeMs", 0)): return
	snapshot = value
	received_ticks = Time.get_ticks_msec()

func synchronize() -> bool:
	if busy: return false
	if not pending.is_empty():
		if not await _perform(): return false
	return await _new_request("sync", {})

func command(payload: Dictionary) -> bool:
	if busy or not connected or not pending.is_empty() or snapshot.is_empty(): return false
	var body := payload.duplicate(true)
	body["expectedVersion"] = snapshot.stateVersion
	return await _new_request("command", body)

func _new_request(endpoint: String, body: Dictionary) -> bool:
	pending = {"endpoint": endpoint, "body": body, "key": Crypto.new().generate_random_bytes(16).hex_encode()}
	_cache()
	return await _perform()

func _perform() -> bool:
	if _token.is_empty():
		message = "未配置测试身份，请使用启动器"
		changed.emit()
		return false
	busy = true
	message = "正在同步…"
	changed.emit()
	while true:
		var headers := PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + _token, "Idempotency-Key: " + str(pending.key)])
		var error := _http.request(base_url + "/api/game/v1/resources/" + str(pending.endpoint), headers, HTTPClient.METHOD_POST, JSON.stringify(pending.body))
		if error != OK: return _offline("无法发起请求，原操作已保留")
		var response: Array = await _http.request_completed
		if response[0] != HTTPRequest.RESULT_SUCCESS: return _offline("连接中断；可查看最后状态，重连后恢复原操作")
		var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
		if not parsed is Dictionary: return _offline("服务响应格式异常，原操作已保留")
		var data: Dictionary = parsed
		var status := int(response[1])
		if status == 202:
			message = "正在补算离线生产…"
			changed.emit()
			await get_tree().create_timer(0.15).timeout
			continue
		if status == 200 and _valid_snapshot(data):
			_accept(data)
			pending = {}
			connected = true
			busy = false
			message = "已同步服务端 · 满仓停工不耗粮"
			_cache()
			changed.emit()
			return true
		if status >= 500: return _offline("服务暂不可用，原操作已保留")
		if status == 200: return _offline("服务状态校验失败，原操作已保留")
		if data.get("latestSnapshot") is Dictionary: _accept(data.latestSnapshot)
		var failure: Dictionary = data.get("error", {})
		message = str(failure.get("message", "操作失败，请刷新状态"))
		pending = {}
		busy = false
		connected = false
		_cache()
		changed.emit()
		return false
	return false

func _offline(reason: String) -> bool:
	busy = false
	connected = false
	message = reason
	_cache()
	changed.emit()
	return false
