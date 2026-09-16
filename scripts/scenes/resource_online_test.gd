extends Control

const NAMES := {"spiritGrain": "灵粮", "spiritWood": "灵木", "darkIron": "玄铁", "spiritCrystal": "灵晶", "gengJing": "庚精"}
var repository: Node
var body: VBoxContainer
var status: Label
var confirmation: ConfirmationDialog
var selected_command: Dictionary = {}
var progress_rows: Array[Dictionary] = []

func _ready() -> void:
	DisplayServer.window_set_title("灵源院在线测试")
	add_theme_font_override("font", preload("res://assets/fonts/NotoSansSC.ttf"))
	repository = Game.get_resource_repository()
	repository.changed.connect(_render)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("101d21")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 18)
	add_child(margin)
	var scroll := ScrollContainer.new()
	margin.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 12)
	scroll.add_child(body)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "确认操作"
	confirmation.confirmed.connect(_confirm)
	add_child(confirmation)
	var timer := Timer.new()
	timer.wait_time = 10.0
	timer.autostart = true
	timer.timeout.connect(func():
		if repository.connected and not repository.busy and not confirmation.visible: repository.synchronize())
	add_child(timer)
	_render()
	repository.synchronize()

func _label(text: String, size := 14) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(label)
	return label

func _button(parent: Node, text: String, callback: Callable, disabled := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size.y = 34
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.disabled = disabled
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _render() -> void:
	if not is_instance_valid(body): return
	progress_rows.clear()
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_label("灵源院", 26)
	_label("在线独立测试 · 使用服务端库存", 12)
	status = _label(repository.message, 13)
	status.modulate = Color("83cdb2") if repository.connected else Color("e7bb7d")
	_button(body, "同步 / 恢复上次操作", func(): repository.synchronize(), repository.busy)
	var snapshot: Dictionary = repository.snapshot
	if snapshot.is_empty(): return
	var state: Dictionary = snapshot.state
	var workers: Array = state.workers
	var assigned := 0
	var allocations: Dictionary = {}
	for code in NAMES: allocations[code] = 0
	for worker in workers:
		var job: Variant = worker.get("job")
		if job is String and allocations.has(job):
			allocations[job] += 1
			assigned += 1
	var rules: Dictionary = snapshot.rulesSummary
	var cycle := int(rules.cyclesMs[int(state.dewLevel)]) / 1000
	_label("杂役 %d / 12 · 空闲 %d · 周期 %d 秒" % [workers.size(), workers.size() - assigned, cycle])
	var disabled: bool = repository.busy or not repository.connected
	for job in rules.jobs:
		var code: String = job.code
		var level := int(state.storageLevels[code])
		var locked := int(state.highestMap) < int(job.unlockMap)
		var stock := str(state.balances[code]).to_int()
		var cap := str(snapshot.capacities[code]).to_int()
		_label("%s  %d / %d" % [_resource_name(code), stock, cap], 17)
		var description := "地图 %d 解锁" % int(job.unlockMap) if locked else ("满仓停工 · 不耗粮" if stock >= cap else "每人 %s / %d 周期 · 维护 %s 灵粮" % [job.output, int(job.cycles), job.upkeep])
		_label(description, 11)
		var progress := ProgressBar.new()
		progress.custom_minimum_size.y = 8
		progress.show_percentage = false
		body.add_child(progress)
		var nearest := 0.0
		var progressing := false
		for worker in workers:
			if worker.job == code:
				var fraction: Array = worker.progress
				nearest = maxf(nearest, float(fraction[0]) / float(fraction[1]))
				if worker.ticket and (code == "spiritGrain" or worker.paid): progressing = true
		progress.value = nearest * 100.0
		progress_rows.append({"bar": progress, "base": nearest, "active": progressing and stock < cap and not locked, "cycle": cycle})
		var row := HBoxContainer.new()
		body.add_child(row)
		_button(row, "−", _allocate.bind(code, -1, allocations), disabled or locked or int(allocations[code]) <= 0)
		var count := Label.new()
		count.text = " %d 人 " % int(allocations[code])
		count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(count)
		_button(row, "+", _allocate.bind(code, 1, allocations), disabled or locked or assigned >= workers.size())
		var cost := "" if level >= 5 else str(job.storage[level].upgradeWood)
		_button(row, "储量满级" if level >= 5 else "升级 · " + cost + "木", _ask.bind({"type": "storage", "asset": code}, "消耗 %s 灵木升级%s储量？" % [cost, _resource_name(code)]), disabled or locked or level >= 5)
	var recruit_cost := "" if workers.size() >= 12 else str(rules.recruitCosts[workers.size() - 6])
	_button(body, "杂役已满" if workers.size() >= 12 else "招募一人 · " + recruit_cost + "灵粮", _ask.bind({"type": "recruit"}, "消耗 %s 灵粮招募一名杂役？" % recruit_cost), disabled or workers.size() >= 12)
	var settlement: Dictionary = snapshot.get("settlement", {})
	if not settlement.is_empty():
		_label("最近结算维护：%s 灵粮" % settlement.get("upkeep", {}).get("spiritGrain", "0"), 12)
		var gains: Array[String] = []
		for code in NAMES:
			var gained := str(settlement.get("stored", {}).get(code, "0"))
			var overflow := str(settlement.get("overflow", {}).get(code, "0"))
			if gained != "0" or overflow != "0": gains.append("%s +%s（溢出 %s）" % [_resource_name(code), gained, overflow])
		if not gains.is_empty(): _label("最近入库：" + "，".join(gains), 11)
	_label("满仓不累计隐藏产量；断网保留最后状态并暂停操作。", 11)

func _process(_delta: float) -> void:
	if not is_instance_valid(repository) or not repository.connected: return
	var elapsed := (Time.get_ticks_msec() - int(repository.received_ticks)) / 1000.0
	for row in progress_rows:
		if is_instance_valid(row.bar) and row.active:
			row.bar.value = minf(100.0, (float(row.base) + elapsed / float(row.cycle)) * 100.0)

func _allocate(code: String, delta: int, current: Dictionary) -> void:
	var next := current.duplicate(true)
	next[code] += delta
	repository.command({"type": "allocation", "allocations": next})

func _ask(command: Dictionary, text: String) -> void:
	selected_command = command
	confirmation.dialog_text = text
	confirmation.popup_centered(Vector2i(320, 170))

func _confirm() -> void:
	repository.command(selected_command)

func _resource_name(code: String) -> String:
	var rules: Dictionary = repository.snapshot.get("rulesSummary", {})
	var catalog: Variant = rules.get("catalog", [])
	if catalog is Array:
		for item in catalog:
			if item is Dictionary and item.get("code") == code and item.get("displayName") is String:
				return item.displayName
	return NAMES.get(code, code)
