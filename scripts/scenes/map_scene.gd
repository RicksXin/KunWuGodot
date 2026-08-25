extends Control

const MAP_VIEW_RECT := Rect2(0, 156, 375, 519)
const MAP_ZOOM_MIN := 0.5
const MAP_ZOOM_MAX := 1.5
const MAP_ZOOM_STEP := 0.05
const MAP_DRAG_THRESHOLD := 5.0

var map_canvas: Control
var map_scroll: ScrollContainer
var map_content: Control
var map_base_size := Vector2.ZERO
var map_zoom := 1.0
var zoom_slider: HSlider
var zoom_value_label: Label
var map_dragging := false
var map_drag_moved := false
var map_drag_start := Vector2.ZERO
var map_drag_scroll_start := Vector2.ZERO
var map_touch_positions: Dictionary = {}
var map_touch_pan_index := -1
var map_touch_pan_start := Vector2.ZERO
var map_touch_scroll_start := Vector2.ZERO
var map_pinch_distance := 0.0
var title_position_label: Label
var burden_label: Label
var grain_label: Label
var objective_label: Label
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
var choice_buttons: Array[Button] = []
var current_action_choices: Array = []
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
	var active_map := Game.get_map_definition()
	var bg := ColorRect.new()
	bg.color = Color("#081217")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# Godot 正式 375×817 布局：顶部 156、世界 519、底部 142。
	var top := KWUI.panel(self, Rect2(0, 0, 375, 156), Color("#141b22f8"), Color("#607770"))
	var info := KWUI.panel(top, Rect2(8, 3, 157, 102), Color("#1c242afa"), Color("#607770"))
	var map_name := Game.text(str(active_map.get("nameKey", "")), str(active_map.get("name", Game.get_active_map_id())))
	title_position_label = KWUI.label(info, "%s（--,--）" % map_name, Rect2(8, 10, 141, 28), 15, Color("#e8e0be"), HORIZONTAL_ALIGNMENT_CENTER)
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
	objective_label = KWUI.label(task, _objective_text(active_map), Rect2(10, 5, 335, 30), 13, Color("#e8e0be"))
	KWUI.panel(self, Rect2(0, 156, 375, 519), Color("#111e22"), Color("#4c6e65"))
	map_scroll = ScrollContainer.new()
	map_scroll.position = Vector2(0, 156)
	map_scroll.size = Vector2(375, 519)
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	map_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	# Runtime owns panning so mouse drag, single-touch drag and pinch can share one
	# deterministic scroll path instead of competing with ScrollContainer's touch drag.
	map_scroll.scroll_deadzone = 1000000
	add_child(map_scroll)
	map_content = Control.new()
	map_content.name = "MapContent"
	map_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_scroll.add_child(map_content)
	map_canvas = Control.new()
	map_canvas.name = "MapCanvas"
	map_canvas.set_script(load("res://scripts/scenes/map_canvas.gd"))
	var logical_tile_size := float(active_map.get("visual", {}).get("logicalTileSize", 48))
	map_base_size = Vector2(int(active_map.get("activeWidth", 15)) * logical_tile_size, int(active_map.get("activeHeight", 15)) * logical_tile_size)
	# Keep a stable maximum-size scroll extent. Runtime panning is clamped to the
	# current scaled map bounds, so the unused extent can never be dragged into
	# view, while zooming no longer waits for a container layout refresh.
	var maximum_content_size := map_base_size * MAP_ZOOM_MAX
	map_content.custom_minimum_size = maximum_content_size
	map_content.size = maximum_content_size
	map_canvas.custom_minimum_size = map_base_size
	map_canvas.size = map_base_size
	map_content.add_child(map_canvas)
	map_canvas.cell_clicked.connect(_on_cell_clicked)
	call_deferred("_center_map")
	grain_warning = KWUI.panel(self, Rect2(15, 162.5, 345, 40), Color("#5b271ff5"), Color("#cf764aff"))
	grain_warning.z_index = 150
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
	zoom_value_label = KWUI.label(bottom, "缩放 100%", Rect2(184, 5, 76, 38), 11, Color("#99a9a2"), HORIZONTAL_ALIGNMENT_CENTER)
	zoom_slider = HSlider.new()
	zoom_slider.name = "MapZoomSlider"
	zoom_slider.position = Vector2(258, 4)
	zoom_slider.size = Vector2(108, 40)
	zoom_slider.min_value = MAP_ZOOM_MIN
	zoom_slider.max_value = MAP_ZOOM_MAX
	zoom_slider.step = MAP_ZOOM_STEP
	zoom_slider.value = map_zoom
	zoom_slider.focus_mode = Control.FOCUS_NONE
	zoom_slider.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	zoom_slider.add_theme_stylebox_override("slider", _zoom_track_style())
	bottom.add_child(zoom_slider)
	zoom_slider.value_changed.connect(_on_zoom_slider_changed)
	hint_label = KWUI.label(bottom, "归营符 0 · 休整 1", Rect2(192.5, 48, 174, 55), 13, Color("#99a9a2"), HORIZONTAL_ALIGNMENT_CENTER)
	_build_rest_overlay()
	_build_backpack_overlay()
	_build_entry_return_overlay()
	_build_event_overlay()
	toast_panel = KWUI.panel(self, Rect2(35, 612, 305, 52), Color("#182c31ee"), KWUI.TEAL)
	toast_panel.z_index = 300
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = KWUI.label(toast_panel, "", Rect2(8, 3, 289, 46), 12, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)

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
	for index in 6:
		var choice_button := KWUI.map_button(object_panel, "选择", Rect2(0, 280, 144, 46), 12)
		choice_button.visible = false
		choice_button.pressed.connect(_choose_object_action.bind(index))
		choice_buttons.append(choice_button)

func _center_map() -> void:
	if not is_instance_valid(map_scroll):
		return
	_set_map_scroll(_player_map_center() - map_scroll.size / 2.0)

func _player_map_center() -> Vector2:
	var expedition: Dictionary = Game.profile.get("expedition", {})
	var position: Dictionary = expedition.get("position", {"x": 2, "y": 2})
	var active_map := Game.get_map_definition()
	var logical_tile_size := float(active_map.get("visual", {}).get("logicalTileSize", 48))
	var tile_center_x := (float(position.get("x", 2)) + 0.5) * logical_tile_size * map_zoom
	var screen_y := int(active_map.get("activeHeight", 15)) - 1 - int(position.get("y", 2))
	var tile_center_y := (float(screen_y) + 0.5) * logical_tile_size * map_zoom
	return Vector2(tile_center_x, tile_center_y)

func _input(event: InputEvent) -> void:
	if _map_input_blocked():
		_cancel_map_gesture()
		return
	if event is InputEventMagnifyGesture:
		if _map_view_has_point(event.position):
			_set_map_zoom(map_zoom * event.factor, _map_view_local(event.position))
			_cancel_canvas_click()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		if _map_view_has_point(event.position):
			_set_map_scroll(_current_map_scroll() + event.delta * 32.0)
			_cancel_canvas_click()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and _map_view_has_point(event.position):
			if event.ctrl_pressed or event.meta_pressed:
				var factor := 1.1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1
				_set_map_zoom(map_zoom * factor, _map_view_local(event.position))
			else:
				var wheel_direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
				_set_map_scroll(_current_map_scroll() + Vector2(0, wheel_direction * 96.0))
			_cancel_canvas_click()
			get_viewport().set_input_as_handled()
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and _map_view_has_point(event.position):
				map_dragging = true
				map_drag_moved = false
				map_drag_start = event.position
				map_drag_scroll_start = _current_map_scroll()
			elif not event.pressed:
				map_dragging = false
			return
	if event is InputEventMouseMotion and map_dragging:
		var drag_delta: Vector2 = event.position - map_drag_start
		if drag_delta.length() >= MAP_DRAG_THRESHOLD:
			map_drag_moved = true
		if map_drag_moved:
			_set_map_scroll(map_drag_scroll_start - drag_delta)
		return
	if event is InputEventScreenTouch:
		_handle_map_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_map_touch_drag(event)

func _handle_map_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if not _map_view_has_point(event.position):
			return
		map_touch_positions[event.index] = event.position
		if map_touch_positions.size() == 1:
			_start_touch_pan(event.index, event.position)
		elif map_touch_positions.size() == 2:
			map_touch_pan_index = -1
			map_pinch_distance = _touch_pair_distance()
			_cancel_canvas_click()
		return
	map_touch_positions.erase(event.index)
	if map_touch_positions.size() == 1:
		var remaining_index := int(map_touch_positions.keys()[0])
		_start_touch_pan(remaining_index, map_touch_positions[remaining_index])
	else:
		map_touch_pan_index = -1
		map_pinch_distance = 0.0

func _handle_map_touch_drag(event: InputEventScreenDrag) -> void:
	if not map_touch_positions.has(event.index):
		return
	map_touch_positions[event.index] = event.position
	if map_touch_positions.size() >= 2:
		var distance := _touch_pair_distance()
		if map_pinch_distance > 0.0 and distance > 0.0:
			_set_map_zoom(map_zoom * distance / map_pinch_distance, _map_view_local(_touch_pair_center()))
		map_pinch_distance = distance
		_cancel_canvas_click()
		return
	if event.index == map_touch_pan_index:
		var drag_delta: Vector2 = event.position - map_touch_pan_start
		if drag_delta.length() >= MAP_DRAG_THRESHOLD:
			_set_map_scroll(map_touch_scroll_start - drag_delta)

func _start_touch_pan(index: int, position: Vector2) -> void:
	map_touch_pan_index = index
	map_touch_pan_start = position
	map_touch_scroll_start = _current_map_scroll()
	map_pinch_distance = 0.0

func _touch_pair_distance() -> float:
	var keys := map_touch_positions.keys()
	if keys.size() < 2:
		return 0.0
	return (map_touch_positions[keys[0]] as Vector2).distance_to(map_touch_positions[keys[1]] as Vector2)

func _touch_pair_center() -> Vector2:
	var keys := map_touch_positions.keys()
	if keys.size() < 2:
		return MAP_VIEW_RECT.get_center()
	return ((map_touch_positions[keys[0]] as Vector2) + (map_touch_positions[keys[1]] as Vector2)) * 0.5

func _on_zoom_slider_changed(value: float) -> void:
	_set_map_zoom(value, map_scroll.size * 0.5 if is_instance_valid(map_scroll) else Vector2.ZERO)

func _set_map_zoom(value: float, _focus_in_view: Vector2) -> void:
	if not is_instance_valid(map_canvas) or not is_instance_valid(map_content):
		return
	var next_zoom := clampf(snappedf(value, MAP_ZOOM_STEP), MAP_ZOOM_MIN, MAP_ZOOM_MAX)
	map_zoom = next_zoom
	map_canvas.scale = Vector2.ONE * map_zoom
	if is_instance_valid(zoom_slider):
		zoom_slider.set_value_no_signal(map_zoom)
	if is_instance_valid(zoom_value_label):
		zoom_value_label.text = "缩放 %d%%" % roundi(map_zoom * 100.0)
	# Zoom always follows the party rather than the cursor or slider. At map
	# edges ScrollContainer clamps the target, keeping the player visible while
	# centering as closely as the available content allows.
	_set_map_scroll(_player_map_center() - map_scroll.size / 2.0)

func _set_map_scroll(value: Vector2) -> void:
	if not is_instance_valid(map_scroll):
		return
	var scaled_map_size := map_base_size * map_zoom
	var max_x := maxi(0, ceili(scaled_map_size.x - map_scroll.size.x))
	var max_y := maxi(0, ceili(scaled_map_size.y - map_scroll.size.y))
	map_scroll.scroll_horizontal = clampi(roundi(value.x), 0, max_x)
	map_scroll.scroll_vertical = clampi(roundi(value.y), 0, max_y)

func _current_map_scroll() -> Vector2:
	if not is_instance_valid(map_scroll):
		return Vector2.ZERO
	return Vector2(map_scroll.scroll_horizontal, map_scroll.scroll_vertical)

func _map_view_has_point(position: Vector2) -> bool:
	return MAP_VIEW_RECT.has_point(position)

func _map_view_local(position: Vector2) -> Vector2:
	return position - MAP_VIEW_RECT.position

func _cancel_canvas_click() -> void:
	if is_instance_valid(map_canvas) and map_canvas.has_method("cancel_pending_click"):
		map_canvas.call("cancel_pending_click")

func _cancel_map_gesture() -> void:
	map_dragging = false
	map_touch_positions.clear()
	map_touch_pan_index = -1
	map_pinch_distance = 0.0
	_cancel_canvas_click()

func _zoom_track_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#263832")
	style.border_color = Color("#84977e")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	return style

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
		if not was_completed and object.get("kind") == "story_event" and object.get("choices", []).is_empty():
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
	map_canvas.call("refresh")
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
	var columns_per_row := 2 if widest_button > 100.0 else 3
	for index in buttons.size():
		var button: Button = buttons[index]
		var row := floori(index / float(columns_per_row))
		var count := mini(columns_per_row, buttons.size() - row * columns_per_row)
		var column := index - row * columns_per_row
		var spacing := 103.0 if button.size.x <= 100.0 else 151.0
		var x := 171.5 + (column - (count - 1) / 2.0) * spacing - button.size.x * 0.5
		var y := 280.0 if row == 0 else 335.0
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
