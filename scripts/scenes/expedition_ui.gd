extends Control

var world: Node2D
var title_position_label: Label
var burden_label: Label
var grain_label: Label
var objective_label: Label
var hint_label: Label
var rest_button: Button
var return_button: Button
var grain_warning: Panel
var grain_warning_label: Label
var rest_overlay: Control
var rest_chance_label: Label
var rest_food_label: Label
var rest_heal_label: Label
var replenish_button: Button
var heal_button: Button
var backpack_overlay: Control
var backpack_grid: Control
var backpack_empty_label: Label
var entry_return_overlay: Control
var event_overlay: Control
var object_panel: Panel
var object_kind_label: Label
var object_title_label: Label
var object_label: Label
var event_buttons: Dictionary = {}
var choice_buttons: Array[Button] = []
var current_action_choices: Array = []
var current_object: Dictionary = {}
var toast_panel: Panel
var toast_label: Label
var toast_serial := 0

func _make_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 200
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.visible = false
	add_child(overlay)
	var shade := ColorRect.new()
	shade.color = Color("#05080bb4")
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	return overlay

func _build_rest_overlay() -> void:
	rest_overlay = _make_overlay()
	var card := KWUI.panel(rest_overlay, Rect2(190, 52, 437, 270), Color("#1b191dfc"), Color("#607770"))
	KWUI.label(card, "野外休整", Rect2(18, 18, 401, 34), 20, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	rest_chance_label = KWUI.label(card, "剩余休整次数：--", Rect2(24, 63, 389, 25), 14, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	rest_food_label = KWUI.label(card, "野外食材：--", Rect2(24, 94, 389, 42), 13, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	rest_heal_label = KWUI.label(card, "运功疗伤：--", Rect2(24, 139, 389, 30), 13, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	replenish_button = KWUI.map_button(card, "补充灵粮", Rect2(42, 202, 108, 48), 13)
	replenish_button.pressed.connect(_replenish_rest)
	heal_button = KWUI.map_button(card, "运功疗伤", Rect2(164, 202, 108, 48), 13)
	heal_button.pressed.connect(_heal_rest)
	var continue_button := KWUI.map_button(card, "结束休整", Rect2(286, 202, 108, 48), 13)
	continue_button.pressed.connect(_continue_rest)

func _build_backpack_overlay() -> void:
	backpack_overlay = _make_overlay()
	var card := KWUI.panel(backpack_overlay, Rect2(180, 20, 457, 335), Color("#1b191dfc"), Color("#607770"))
	KWUI.label(card, "本次入山所得", Rect2(18, 15, 421, 36), 20, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	backpack_grid = Control.new()
	backpack_grid.position = Vector2(22, 55)
	backpack_grid.size = Vector2(413, 210)
	card.add_child(backpack_grid)
	backpack_empty_label = KWUI.label(card, "尚未获得临时战利品", Rect2(22, 55, 413, 210), 14, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var close := KWUI.map_button(card, "关闭", Rect2(165.5, 274, 126, 48), 14)
	close.pressed.connect(func(): backpack_overlay.visible = false)

func _build_entry_return_overlay() -> void:
	entry_return_overlay = _make_overlay()
	var card := KWUI.panel(entry_return_overlay, Rect2(220, 90, 377, 195), Color("#1b191dfc"), Color("#607770"))
	KWUI.label(card, "返回入口传送阵", Rect2(20, 23, 337, 34), 19, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(card, "是否结束本次入山并返回营地？", Rect2(20, 64, 337, 42), 14, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var confirm := KWUI.map_button(card, "确认归营", Rect2(45.5, 129, 132, 48), 14)
	confirm.pressed.connect(_return_camp)
	var cancel := KWUI.map_button(card, "取消", Rect2(199.5, 129, 132, 48), 14)
	cancel.pressed.connect(func(): entry_return_overlay.visible = false)

func _build_event_overlay() -> void:
	event_overlay = _make_overlay()
	object_panel = KWUI.panel(event_overlay, Rect2(117, 5, 583, 365), Color("#1b191dfc"), Color("#9b5b48"))
	object_kind_label = KWUI.label(object_panel, "奇遇", Rect2(20, 15, 543, 22), 12, Color("#aec0b1"), HORIZONTAL_ALIGNMENT_CENTER)
	object_title_label = KWUI.label(object_panel, "事件标题", Rect2(20, 36, 543, 34), 20, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	var object_info := KWUI.panel(object_panel, Rect2(20, 76, 543, 148), Color("#14161af5"), Color("#607770"))
	object_label = KWUI.label(object_info, "", Rect2(16, 11, 511, 126), 14, Color("#e0dac2"), HORIZONTAL_ALIGNMENT_LEFT)
	object_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	KWUI.label(object_panel, "可用行动", Rect2(20, 230, 543, 24), 13, Color("#aec0b1"), HORIZONTAL_ALIGNMENT_CENTER)
	var definitions := [
		["engage", "迎战", Callable(self, "_engage")],
		["inspect", "探灵", Callable(self, "_inspect_object")],
		["talk", "交谈", Callable(self, "_talk_object")],
		["operate", "处理", Callable(self, "_resolve_object")],
		["small_talk", "闲谈", Callable(self, "_small_talk_object")],
		["leave", "离开", Callable(self, "_close_event")]
	]
	for definition in definitions:
		var button := KWUI.map_button(object_panel, str(definition[1]), Rect2(0, 260, 92, 46), 14)
		button.visible = false
		button.pressed.connect(definition[2])
		event_buttons[str(definition[0])] = button
	for index in 6:
		var choice_button := KWUI.map_button(object_panel, "选择", Rect2(0, 260, 144, 46), 12)
		choice_button.visible = false
		choice_button.pressed.connect(_choose_object_action.bind(index))
		choice_buttons.append(choice_button)

func _map_input_blocked() -> bool:
	return (is_instance_valid(rest_overlay) and rest_overlay.visible) \
		or (is_instance_valid(backpack_overlay) and backpack_overlay.visible) \
		or (is_instance_valid(entry_return_overlay) and entry_return_overlay.visible) \
		or (is_instance_valid(event_overlay) and event_overlay.visible)

func _show_object(object: Dictionary) -> void:
	current_object = object
	event_overlay.visible = true
	var completed: bool = bool(Game.profile.get("completedMapObjects", {}).get(Game.map_object_key(Game.get_active_map_id(), str(object.get("id", ""))), false))
	object_kind_label.text = _event_kind(object)
	object_title_label.text = str(object.get("title", "地图事件"))
	object_label.text = str(object.get("description", ""))
	for choice_button in choice_buttons:
		choice_button.visible = false
		KWUI.set_map_button_disabled(choice_button, false)
	current_action_choices = []
	if not object.get("choices", []).is_empty() and not completed:
		for key in event_buttons:
			event_buttons[key].visible = false
		current_action_choices = Game.available_map_object_actions(object)
		var unavailable_notes: Array[String] = []
		var displayed_count := mini(current_action_choices.size(), choice_buttons.size() - 1)
		for index in displayed_count:
			var action: Dictionary = current_action_choices[index]
			var button: Button = choice_buttons[index]
			button.visible = true
			button.text = str(action.get("label", action.get("id", "行动")))
			KWUI.set_map_button_disabled(button, not bool(action.get("enabled", true)))
			if not bool(action.get("enabled", true)):
				unavailable_notes.append("%s：%s" % [button.text, str(action.get("unavailableText", "条件尚未满足"))])
		var leave_index := displayed_count
		choice_buttons[leave_index].visible = true
		choice_buttons[leave_index].text = "离开"
		current_action_choices.insert(leave_index, {"id": "__leave__", "enabled": true})
		_layout_action_buttons(choice_buttons.filter(func(button): return button.visible))
		if not unavailable_notes.is_empty():
			object_label.text = "%s\n\n%s" % [object_label.text, "\n".join(unavailable_notes)]
		return
	var actions: Array = object.get("eventActions", [])
	if actions.is_empty():
		if _is_combat_kind(str(object.get("kind", ""))): actions = ["engage", "inspect", "leave"]
		elif object.get("kind") == "treasure_chest": actions = ["operate", "leave"]
		else: actions = ["leave"]
	if completed: actions = ["leave"]
	var visible_buttons: Array[Button] = []
	for key in event_buttons:
		var event_button: Button = event_buttons[key]
		event_button.visible = false
		KWUI.set_map_button_disabled(event_button, false)
	for action in actions:
		var key := str(action)
		if not event_buttons.has(key): continue
		var event_button: Button = event_buttons[key]
		visible_buttons.append(event_button)
		event_button.visible = true
		if key == "operate": event_button.text = str(object.get("operationLabel", "处理"))
		elif key == "engage": event_button.text = "迎战"
		elif key == "inspect": event_button.text = "探灵"
		elif key == "talk": event_button.text = "交谈"
		elif key == "small_talk": event_button.text = "闲谈"
		elif key == "leave": event_button.text = "离开"
	_layout_action_buttons(visible_buttons)

func _layout_action_buttons(buttons: Array) -> void:
	var widest_button := 0.0
	for button: Button in buttons:
		widest_button = maxf(widest_button, button.size.x)
	var columns_per_row := 3
	for index in buttons.size():
		var button: Button = buttons[index]
		var row := floori(index / float(columns_per_row))
		var count := mini(columns_per_row, buttons.size() - row * columns_per_row)
		var column := index - row * columns_per_row
		var spacing := button.size.x + 10.0
		var total_width := count * button.size.x + (count - 1) * 10.0
		var x := (object_panel.size.x - total_width) * 0.5 + column * spacing
		var y := 260.0 + row * 51.0
		button.position = Vector2(x, y)

func _choose_object_action(index: int) -> void:
	if index < 0 or index >= current_action_choices.size():
		return
	var action: Dictionary = current_action_choices[index]
	if str(action.get("id", "")) == "__leave__":
		var leave_action: Variant = current_object.get("leaveAction", {})
		if leave_action is Dictionary and not leave_action.is_empty():
			var result := Game.resolve_map_object_action(current_object, str(leave_action.get("id", "")))
			_show_feedback(str(result.get("message", "")), 0 if bool(result.get("ok", false)) else 2)
			if not bool(result.get("ok", false)):
				return
			_refresh()
		_close_event()
		return
	if not bool(action.get("enabled", true)):
		_show_feedback(str(action.get("unavailableText", "条件尚未满足")), 1)
		return
	var result := Game.resolve_map_object_action(current_object, str(action.get("id", "")))
	_show_feedback(str(result.get("message", "")), 0 if bool(result.get("ok", false)) else 2)
	if not bool(result.get("ok", false)):
		return
	if bool(result.get("startEncounter", false)):
		_close_event()
		get_tree().change_scene_to_file("res://scenes/combat.tscn")
		return
	_refresh()
	if bool(result.get("positionChanged", false)):
		_center_map()
	if bool(result.get("completed", false)) or bool(action.get("closeAfter", false)):
		_close_event()
	else:
		_show_object(current_object)

func _event_kind(object: Dictionary) -> String:
	var kind := str(object.get("kind", ""))
	match kind:
		"enemy_group": return "敌情"
		"elite_enemy": return "精英敌情"
		"boss": return "首领敌情"
		"treasure_chest": return "遗物"
		"npc": return "人物"
		"resource", "resource_node": return "资源点"
		"landmark_event": return "地标事件"
		"story_event": return "剧情事件"
		"dungeon": return "局部副本"
		"shortcut": return "捷径"
		"map_exit": return "地图出口"
		_: return "奇遇"

func _is_combat_kind(kind: String) -> bool:
	return kind in ["enemy_group", "elite_enemy", "boss"] or kind.begins_with("boss_")

func _objective_text(active_map: Dictionary) -> String:
	var fallback := str(active_map.get("objectiveText", "探索地图并完成当前目标"))
	var objective := Game.text(str(active_map.get("objectiveTextKey", "")), fallback)
	return objective if objective.begins_with("主线：") else "主线：%s" % objective

func _close_event() -> void:
	if is_instance_valid(event_overlay): event_overlay.visible = false
	current_action_choices = []
	current_object = {}

func _resolve_object() -> void:
	if current_object.is_empty(): return
	var position: Dictionary = Game.profile["expedition"]["position"]
	var object := current_object if not current_object.is_empty() else Game.object_at(int(position["x"]), int(position["y"]))
	_show_feedback(Game.resolve_object(object), 0)
	_close_event()
	_refresh()

func _inspect_object() -> void:
	if current_object.is_empty(): return
	var lens := int(Game.profile.get("expedition", {}).get("carriedItems", {}).get("lens", 0))
	if lens <= 0:
		_show_feedback("未携带探灵镜，无法探查敌情", 1)
		return
	var result := str(current_object.get("inspectionText", "炼气后期傀物；护甲坚实，灵抗偏低，行动迟缓。"))
	object_label.text = "%s\n\n探灵结果：%s" % [str(current_object.get("description", "")), result]

func _talk_object() -> void:
	if current_object.is_empty(): return
	object_label.text = "%s\n\n%s" % [str(current_object.get("description", "")), str(current_object.get("dialogueText", "对方暂未回应，这段剧情尚待接入。"))]

func _small_talk_object() -> void:
	if current_object.is_empty(): return
	object_label.text = "%s\n\n%s" % [str(current_object.get("description", "")), str(current_object.get("smallTalkText", "你与对方闲谈片刻，并未获得新的线索。"))]

func _engage() -> void:
	var result := Game.begin_encounter(current_object)
	if not result.get("ok", false):
		_show_feedback(result.get("message", "当前无法进入战斗"), 2)
		return
	_close_event()
	get_tree().change_scene_to_file("res://scenes/combat.tscn")

func _open_rest() -> void:
	var result := Game.enter_rest()
	_show_feedback(result.get("message", ""), 0 if result.get("ok", false) else 1)
	_refresh()
	if result.get("ok", false): rest_overlay.visible = true

func _replenish_rest() -> void:
	var result := Game.replenish_rest()
	_show_feedback(result.get("message", ""), 0 if result.get("ok", false) else 1)
	_refresh()

func _heal_rest() -> void:
	var result := Game.heal_rest()
	_show_feedback(result.get("message", ""), 0 if result.get("ok", false) else 1)
	_refresh()

func _continue_rest() -> void:
	var result := Game.continue_rest()
	_show_feedback(result.get("message", ""), 0 if result.get("ok", false) else 1)
	_refresh()
	if result.get("ok", false): rest_overlay.visible = false

func _refresh_rest_overlay() -> void:
	if not is_instance_valid(rest_overlay) or not rest_overlay.visible: return
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var field: Dictionary = Game.expedition_config.get("field", {})
	rest_chance_label.text = "后续剩余休整：%d 次" % int(expedition.get("restUsesRemaining", 0))
	var food_text: Array[String] = []
	for food in field.get("foodItems", []):
		var food_id := str(food.get("itemId", ""))
		var amount := int(expedition.get("temporaryLoot", {}).get(food_id, 0))
		food_text.append("%s ×%d" % [Game.text(str(food.get("nameKey", food_id)), food_id), amount])
	rest_food_label.text = "野外食材：%s" % "  ·  ".join(food_text)
	var healing_percent := int(field.get("healingPercent", 25))
	rest_heal_label.text = "运功疗伤：本次已使用" if bool(expedition.get("restHealingUsed", false)) else "运功疗伤：恢复 %d%% 最大生命" % healing_percent
	KWUI.set_map_button_disabled(replenish_button, int(expedition.get("remainingGrain", 0)) >= int(expedition.get("grainCapacity", 0)) or not _has_rest_food(expedition, field))
	KWUI.set_map_button_disabled(heal_button, bool(expedition.get("restHealingUsed", false)))

func _has_rest_food(expedition: Dictionary, field: Dictionary) -> bool:
	for food in field.get("foodItems", []):
		if int(expedition.get("temporaryLoot", {}).get(str(food.get("itemId", "")), 0)) > 0: return true
	return false

func _open_backpack() -> void:
	_refresh_backpack_overlay()
	backpack_overlay.visible = true

func _refresh_backpack_overlay() -> void:
	if not is_instance_valid(backpack_grid): return
	for child in backpack_grid.get_children(): child.queue_free()
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var entries: Array = []
	for item_id in expedition.get("temporaryLoot", {}):
		var amount := int(expedition["temporaryLoot"][item_id])
		if amount > 0: entries.append([str(item_id), amount])
	backpack_empty_label.visible = entries.is_empty()
	var columns := 7
	for index in mini(21, entries.size()):
		var entry: Array = entries[index]
		var column := index % columns
		var row := floori(index / float(columns))
		var slot := KWUI.panel(backpack_grid, Rect2(6.5 + column * 56, 15 + row * 56, 48, 48), Color("#1f2225"), Color("#7e775b"))
		var item_id := str(entry[0])
		var icon_path := ""
		if item_id == "pickaxe": icon_path = "res://assets/camp/ui/expedition/icon_expedition_pickaxe.png"
		elif item_id == "lens": icon_path = "res://assets/camp/ui/expedition/icon_expedition_lens.png"
		if not icon_path.is_empty():
			var icon := KWUI.texture(slot, icon_path, Rect2(12, 7, 24, 24))
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		else:
			var symbol := "肉" if item_id == "beast_meat" else "饼" if item_id == "bigu_cake" else "物"
			KWUI.label(slot, symbol, Rect2(0, 7, 48, 26), 16, Color("#e0d3a8"), HORIZONTAL_ALIGNMENT_CENTER)
		var badge := KWUI.panel(slot, Rect2(14, 31, 25, 16), Color("#080a0cee"), Color("#c4b789"))
		KWUI.label(badge, "×%d" % int(entry[1]), Rect2(0, 0, 23, 14), 9, Color("#fff4cc"), HORIZONTAL_ALIGNMENT_CENTER)

func _return_camp() -> void:
	var result := Game.return_to_camp()
	if result.get("ok", false):
		entry_return_overlay.visible = false
		get_tree().change_scene_to_file("res://scenes/camp.tscn")
	else: _show_feedback(result.get("message", "请先返回入口"), 2)

func _return_with_talisman() -> void:
	var result := Game.return_with_talisman()
	if result.get("ok", false): get_tree().change_scene_to_file("res://scenes/camp.tscn")
	else: _show_feedback(result.get("message", "没有归营符"), 2)

func _show_feedback(message: String, severity: int = 0) -> void:
	toast_serial += 1
	var current := toast_serial
	toast_panel.visible = true
	toast_panel.add_theme_stylebox_override("panel", KWUI.style_box(Color("#182c31ee"), KWUI.RED if severity >= 2 else KWUI.TEAL, 6, 1))
	toast_label.text = message
	await get_tree().create_timer(2.4).timeout
	if current == toast_serial: toast_panel.visible = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_rest_overlay()
	_build_backpack_overlay()
	_build_entry_return_overlay()
	_build_event_overlay()
	toast_panel = KWUI.panel(self, Rect2(226, 274, 365, 46), Color("#182c31ee"), KWUI.TEAL)
	toast_panel.z_index = 300
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = KWUI.label(toast_panel, "", Rect2(8, 2, 349, 40), 12, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	_refresh()

func _refresh() -> void:
	_refresh_rest_overlay()
	_refresh_backpack_overlay()
	if is_instance_valid(world): world.call("refresh_state")

func _center_map() -> void:
	world.call("sync_saved_position")

func request_return() -> void:
	var pos: Vector2 = world.get("actor").position
	if pos.distance_to(Vector2(450,1890)) <= 28:
		entry_return_overlay.visible = true
	else:
		_return_with_talisman()
