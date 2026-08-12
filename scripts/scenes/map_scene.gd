extends Control

var map_canvas: Control
var map_scroll: ScrollContainer
var title_position_label: Label
var burden_label: Label
var grain_label: Label
var hint_label: Label
var rest_button: Button
var return_button: Button
var movement_buttons: Dictionary = {}
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
var current_object: Dictionary = {}
var toast_panel: Panel
var toast_label: Label
var toast_serial := 0

func _ready() -> void:
	if Game.profile.get("expedition") == null:
		call_deferred("_go_camp")
		return
	_build_scene()
	_refresh()

func _go_camp() -> void:
	get_tree().change_scene_to_file("res://scenes/camp.tscn")

func _build_scene() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#081217")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Godot 正式 375×817 布局：顶部 156、世界 519、底部 142。
	var top := KWUI.panel(self, Rect2(0, 0, 375, 156), Color("#141b22f8"), Color("#607770"))
	var info := KWUI.panel(top, Rect2(8, 3, 157, 102), Color("#1c242afa"), Color("#607770"))
	title_position_label = KWUI.label(info, "破禁山麓（--,--）", Rect2(8, 10, 141, 28), 15, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	burden_label = KWUI.label(info, "负重 --/--", Rect2(8, 39, 141, 24), 13, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	grain_label = KWUI.label(info, "灵粮：---", Rect2(8, 66, 141, 24), 13, Color("#dbcb84"), HORIZONTAL_ALIGNMENT_CENTER)
	var actions := KWUI.panel(top, Rect2(174.5, 3, 192, 102), Color("#1c242afa"), Color("#607770"))
	rest_button = KWUI.map_button(actions, "休整", Rect2(9, 5, 54, 48), 12)
	rest_button.pressed.connect(_open_rest)
	return_button = KWUI.map_button(actions, "归营", Rect2(69, 5, 54, 48), 12)
	return_button.pressed.connect(_return_with_talisman)
	var party := KWUI.map_button(actions, "队伍", Rect2(129, 5, 54, 48), 12)
	party.pressed.connect(_show_feedback.bind("当前四人小队状态正常", 0))
	var backpack := KWUI.map_button(actions, "背包", Rect2(39, 55, 54, 48), 12)
	backpack.pressed.connect(_open_backpack)
	var settings := KWUI.map_button(actions, "设置", Rect2(99, 55, 54, 48), 12)
	settings.pressed.connect(_show_feedback.bind("地图设置尚未开放", 1))
	var task := KWUI.panel(top, Rect2(10, 113, 355, 40), Color("#1c242afa"), Color("#607770"))
	KWUI.label(task, "主线：探索东北残禁，击败石傀", Rect2(10, 5, 335, 30), 13, Color("#e8e0be"))
	KWUI.panel(self, Rect2(0, 156, 375, 519), Color("#111e22"), Color("#4c6e65"))
	map_scroll = ScrollContainer.new()
	map_scroll.position = Vector2(0, 156)
	map_scroll.size = Vector2(375, 519)
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(map_scroll)
	map_canvas = Control.new()
	map_canvas.set_script(load("res://scripts/scenes/map_canvas.gd"))
	var active_map := Game.get_map_definition()
	var logical_tile_size := float(active_map.get("visual", {}).get("logicalTileSize", 48))
	map_canvas.custom_minimum_size = Vector2(int(active_map.get("activeWidth", 15)) * logical_tile_size, int(active_map.get("activeHeight", 15)) * logical_tile_size)
	map_canvas.size = map_canvas.custom_minimum_size
	map_scroll.add_child(map_canvas)
	map_canvas.cell_clicked.connect(_on_cell_clicked)
	call_deferred("_center_map")
	grain_warning = KWUI.panel(self, Rect2(15, 162.5, 345, 40), Color("#5b271ff5"), Color("#cf764aff"))
	grain_warning.visible = false
	grain_warning_label = KWUI.label(grain_warning, "", Rect2(10, 5, 325, 30), 13, Color("#ffdca4"), HORIZONTAL_ALIGNMENT_CENTER)
	var bottom := KWUI.panel(self, Rect2(0, 675, 375, 142), Color("#05090ceb"), Color("#607770"))
	var up := KWUI.map_button(bottom, "↑", Rect2(51.5, 11, 48, 48), 16)
	up.pressed.connect(_move.bind(0, 1))
	movement_buttons["0:1"] = up
	var left := KWUI.map_button(bottom, "←", Rect2(0.5, 60, 48, 48), 16)
	left.pressed.connect(_move.bind(-1, 0))
	movement_buttons["-1:0"] = left
	var down := KWUI.map_button(bottom, "↓", Rect2(51.5, 60, 48, 48), 16)
	down.pressed.connect(_move.bind(0, -1))
	movement_buttons["0:-1"] = down
	var right := KWUI.map_button(bottom, "→", Rect2(102.5, 60, 48, 48), 16)
	right.pressed.connect(_move.bind(1, 0))
	movement_buttons["1:0"] = right
	hint_label = KWUI.label(bottom, "归营符 0 · 休整 1", Rect2(192.5, 43.5, 174, 55), 13, Color("#99a9a2"), HORIZONTAL_ALIGNMENT_CENTER)
	_build_rest_overlay()
	_build_backpack_overlay()
	_build_entry_return_overlay()
	_build_event_overlay()
	toast_panel = KWUI.panel(self, Rect2(35, 612, 305, 52), Color("#182c31ee"), KWUI.TEAL)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = KWUI.label(toast_panel, "", Rect2(8, 3, 289, 46), 12, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)

func _make_overlay() -> Control:
	var overlay := Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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
	var card := KWUI.panel(rest_overlay, Rect2(19, 273.5, 337, 270), Color("#1b191dfc"), Color("#607770"))
	KWUI.label(card, "野外休整", Rect2(18.5, 20, 300, 34), 20, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	rest_chance_label = KWUI.label(card, "剩余休整次数：--", Rect2(21, 64.5, 295, 25), 14, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	rest_food_label = KWUI.label(card, "野外食材：--", Rect2(21, 94, 295, 42), 13, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	rest_heal_label = KWUI.label(card, "运功疗伤：--", Rect2(21, 139, 295, 30), 13, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	replenish_button = KWUI.map_button(card, "补充灵粮", Rect2(10, 202, 100, 48), 13)
	replenish_button.pressed.connect(_replenish_rest)
	heal_button = KWUI.map_button(card, "运功疗伤", Rect2(118.5, 202, 100, 48), 13)
	heal_button.pressed.connect(_heal_rest)
	var continue_button := KWUI.map_button(card, "结束休整", Rect2(227, 202, 100, 48), 13)
	continue_button.pressed.connect(_continue_rest)

func _build_backpack_overlay() -> void:
	backpack_overlay = _make_overlay()
	var card := KWUI.panel(backpack_overlay, Rect2(22, 238.5, 331, 340), Color("#1b191dfc"), Color("#607770"))
	KWUI.label(card, "本次入山所得", Rect2(18, 15, 295, 36), 20, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	backpack_grid = Control.new()
	backpack_grid.position = Vector2(23, 57)
	backpack_grid.size = Vector2(285, 190)
	card.add_child(backpack_grid)
	backpack_empty_label = KWUI.label(card, "尚未获得临时战利品", Rect2(23, 57, 285, 190), 14, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var close := KWUI.map_button(card, "关闭", Rect2(102.5, 283, 126, 48), 14)
	close.pressed.connect(func(): backpack_overlay.visible = false)

func _build_entry_return_overlay() -> void:
	entry_return_overlay = _make_overlay()
	var card := KWUI.panel(entry_return_overlay, Rect2(28, 313.5, 319, 190), Color("#1b191dfc"), Color("#607770"))
	KWUI.label(card, "返回入口传送阵", Rect2(19.5, 23, 280, 34), 19, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(card, "是否结束本次入山并返回营地？", Rect2(20.5, 62, 278, 42), 14, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	var confirm := KWUI.map_button(card, "确认归营", Rect2(18.5, 126, 132, 48), 14)
	confirm.pressed.connect(_return_camp)
	var cancel := KWUI.map_button(card, "取消", Rect2(168.5, 126, 132, 48), 14)
	cancel.pressed.connect(func(): entry_return_overlay.visible = false)

func _build_event_overlay() -> void:
	event_overlay = _make_overlay()
	object_panel = KWUI.panel(event_overlay, Rect2(16, 201.5, 343, 414), Color("#1b191dfc"), Color("#9b5b48"))
	object_kind_label = KWUI.label(object_panel, "奇遇", Rect2(20, 27, 303, 22), 12, Color("#aec0b1"), HORIZONTAL_ALIGNMENT_CENTER)
	object_title_label = KWUI.label(object_panel, "事件标题", Rect2(20, 47, 303, 34), 20, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
	var object_info := KWUI.panel(object_panel, Rect2(17, 88, 309, 150), Color("#14161af5"), Color("#607770"))
	object_label = KWUI.label(object_info, "", Rect2(15, 12, 279, 126), 14, Color("#e0dac2"), HORIZONTAL_ALIGNMENT_LEFT)
	object_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	KWUI.label(object_panel, "可用行动", Rect2(20, 245, 303, 24), 13, Color("#aec0b1"), HORIZONTAL_ALIGNMENT_CENTER)
	var definitions := [
		["engage", "迎战", Callable(self, "_engage")],
		["inspect", "探灵", Callable(self, "_inspect_object")],
		["talk", "交谈", Callable(self, "_talk_object")],
		["operate", "处理", Callable(self, "_resolve_object")],
		["small_talk", "闲谈", Callable(self, "_small_talk_object")],
		["leave", "离开", Callable(self, "_close_event")]
	]
	for definition in definitions:
		var button := KWUI.map_button(object_panel, str(definition[1]), Rect2(0, 280, 92, 46), 14)
		button.visible = false
		button.pressed.connect(definition[2])
		event_buttons[str(definition[0])] = button

func _center_map() -> void:
	if not is_instance_valid(map_scroll): return
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var position: Dictionary = expedition.get("position", {"x": 2, "y": 2})
	var active_map := Game.get_map_definition()
	var logical_tile_size := float(active_map.get("visual", {}).get("logicalTileSize", 48))
	var tile_center_x := (float(position.get("x", 2)) + 0.5) * logical_tile_size
	var screen_y := int(active_map.get("activeHeight", 15)) - 1 - int(position.get("y", 2))
	var tile_center_y := (float(screen_y) + 0.5) * logical_tile_size
	var max_x := maxi(0, int(map_scroll.get_h_scroll_bar().max_value))
	var max_y := maxi(0, int(map_scroll.get_v_scroll_bar().max_value))
	map_scroll.scroll_horizontal = clampi(roundi(tile_center_x - map_scroll.size.x / 2.0), 0, max_x)
	map_scroll.scroll_vertical = clampi(roundi(tile_center_y - map_scroll.size.y / 2.0), 0, max_y)

func _unhandled_input(event: InputEvent) -> void:
	if _map_input_blocked(): return
	if event.is_action_pressed("move_up"): _move(0, 1)
	elif event.is_action_pressed("move_down"): _move(0, -1)
	elif event.is_action_pressed("move_left"): _move(-1, 0)
	elif event.is_action_pressed("move_right"): _move(1, 0)

func _move(dx: int, dy: int) -> void:
	if _map_input_blocked(): return
	var previous: Dictionary = Game.profile.get("expedition", {}).get("position", {}).duplicate(true)
	var result := Game.move_expedition(dx, dy)
	if not result.get("ok", false):
		_show_feedback(result.get("message", "当前无法移动"), 2)
		return
	if result.get("wiped", false):
		Game._finish_expedition(true)
		_show_feedback("断粮阵亡，队伍已返回营地", 3)
		await get_tree().create_timer(1.0).timeout
		get_tree().change_scene_to_file("res://scenes/camp.tscn")
		return
	_refresh()
	_center_map()
	var active_map := Game.get_map_definition()
	var entry := {"x": int(active_map.get("entryX", 2)), "y": int(active_map.get("entryY", 2))}
	var arrived: Dictionary = result.get("position", {})
	if arrived == entry and previous != entry:
		entry_return_overlay.visible = true
		return
	var object: Dictionary = result.get("object", {})
	if not object.is_empty():
		var object_key := Game.map_object_key(Game.get_active_map_id(), str(object.get("id", "")))
		var was_completed := bool(Game.profile.get("completedMapObjects", {}).get(object_key, false))
		if not was_completed and object.get("kind") == "story_event":
			Game.resolve_object(object)
		if not was_completed: _show_object(object)

func _on_cell_clicked(x: int, y: int) -> void:
	if _map_input_blocked(): return
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var pos: Dictionary = expedition.get("position", {})
	var dx := x - int(pos.get("x", x))
	var dy := y - int(pos.get("y", y))
	if absi(dx) + absi(dy) != 1:
		_show_feedback("请选择相邻格", 1)
		return
	_move(dx, dy)

func _refresh() -> void:
	if not is_instance_valid(map_canvas): return
	map_canvas.queue_redraw()
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var position: Dictionary = expedition.get("position", {})
	var x := int(position.get("x", 0))
	var y := int(position.get("y", 0))
	var active_map := Game.get_map_definition()
	title_position_label.text = "%s（%d,%d）" % [Game.text(str(active_map.get("nameKey", "")), str(active_map.get("name", Game.get_active_map_id()))), x, y]
	var carried: Dictionary = expedition.get("carriedItems", {})
	var burden := int(expedition.get("remainingGrain", 0)) * Game.item_weight("spiritGrain")
	for item_id in carried: burden += int(carried[item_id]) * Game.item_weight(str(item_id))
	var temporary_loot: Dictionary = expedition.get("temporaryLoot", {})
	for item_id in temporary_loot:
		burden += int(temporary_loot[item_id]) * Game.item_weight(str(item_id))
	var limit := Game.expedition_burden_limit(Game.party_heroes())
	burden_label.text = "负重 %d/%d" % [burden, limit]
	var grain := int(expedition.get("remainingGrain", 0))
	var depletion_steps := int(expedition.get("grainDepletionSteps", 0))
	if grain > 0:
		grain_label.text = "灵粮：%d" % grain
		grain_label.add_theme_color_override("font_color", Color("#dbcb84"))
		grain_warning.visible = false
	else:
		var stages := ["断粮", "气血亏空", "步履维艰", "生机将绝"]
		var stage_index := clampi(depletion_steps, 0, stages.size() - 1)
		var step_limit := int(Game.expedition_config.get("field", {}).get("grainDepletionStepLimit", 4))
		grain_label.text = stages[stage_index]
		grain_label.add_theme_color_override("font_color", Color("#ed895b"))
		grain_warning.visible = true
		grain_warning_label.text = "警告：灵粮已尽，护体灵息仅可支撑 %d 步" % maxi(0, step_limit - depletion_steps)
	hint_label.text = "归营符 %d · 休整 %d" % [int(Game.profile.get("inventory", {}).get("return_talisman", 0)), int(expedition.get("restUsesRemaining", 0))]
	var resting := bool(expedition.get("isResting", false))
	if is_instance_valid(rest_button): KWUI.set_map_button_disabled(rest_button, resting or int(expedition.get("restUsesRemaining", 0)) <= 0)
	if is_instance_valid(return_button): KWUI.set_map_button_disabled(return_button, resting)
	if is_instance_valid(rest_overlay): rest_overlay.visible = resting
	for key in movement_buttons:
		var move_button: Button = movement_buttons[key]
		var parts := str(key).split(":")
		var dx := int(parts[0])
		var dy := int(parts[1])
		KWUI.set_map_button_disabled(move_button, resting or not _can_move(dx, dy))
	_refresh_rest_overlay()
	_refresh_backpack_overlay()

func _can_move(dx: int, dy: int) -> bool:
	var expedition: Dictionary = Game.profile.get("expedition", {})
	if expedition.is_empty() or bool(expedition.get("isResting", false)): return false
	var position: Dictionary = expedition.get("position", {})
	var tile := Game.tile_at(int(position.get("x", 0)) + dx, int(position.get("y", 0)) + dy)
	if not bool(tile.get("walkable", false)): return false
	if int(expedition.get("remainingGrain", 0)) > 0: return true
	return int(expedition.get("grainDepletionSteps", 0)) < int(Game.expedition_config.get("field", {}).get("grainDepletionStepLimit", 4))

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
	var actions: Array = object.get("eventActions", [])
	if actions.is_empty():
		if object.get("kind") == "enemy_group": actions = ["engage", "inspect", "leave"]
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
	for index in visible_buttons.size():
		var row := floori(index / 3.0)
		var count := mini(3, visible_buttons.size() - row * 3)
		var column := index - row * 3
		var x := 171.5 + (column - (count - 1) / 2.0) * 103.0 - 46.0
		var y := 280.0 if row == 0 else 335.0
		visible_buttons[index].position = Vector2(x, y)

func _event_kind(object: Dictionary) -> String:
	var kind := str(object.get("kind", ""))
	if kind == "enemy_group" or kind.begins_with("boss_"): return "敌情"
	if kind == "treasure_chest": return "遗物"
	if kind == "npc": return "人物"
	if kind == "resource_node": return "资源点"
	return "奇遇"

func _close_event() -> void:
	if is_instance_valid(event_overlay): event_overlay.visible = false
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
	var columns := 5
	for index in mini(15, entries.size()):
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
