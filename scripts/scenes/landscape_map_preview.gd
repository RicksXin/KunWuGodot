extends Control

# Explicit preload keeps the isolated landscape project self-contained when
# Godot scans it through landscape_preview_project/ symlinks; the main project
# also exposes this script as the global KWUI class.
const KWUI = preload("res://scripts/ui/ui.gd")

## Stand-alone landscape direction preview.
##
## This scene is intentionally not wired into the vertical boot/camp/map/combat
## chain. It is a visual and interaction prototype for the 16:9 map direction;
## the formal Map01 data remains owned by Game and the existing map scene.

const DESIGN_SIZE := Vector2(1280, 720)
const MAP_WIDTH := 965.0
const PANEL_WIDTH := 315.0
const MAP_CONTENT_HEIGHT := 2210.0
const MAP_TOP_OFFSET := -22.0
const GOLD := Color("#e6cf9d")
const TEXT := Color("#e8e5d6")
const MUTED := Color("#a9b0a6")
const PANEL := Color("#11161af2")

var detail_title: Label
var detail_kind: Label
var detail_body: Label
var objective_label: Label
var progress_label: Label
var toast_panel: Panel
var toast_label: Label
var selected_marker: Button
var map_frame: Control
var map_world: Control
var map_dragging := false
var map_drag_start := Vector2.ZERO
var map_world_start := Vector2.ZERO
var map_scrollbar: VScrollBar

func _ready() -> void:
	# If this scene was opened with F6 from the vertical project, rescue the
	# preview window where possible instead of silently rendering a 375×817
	# portrait canvas. The standalone project_landscape.godot remains the
	# canonical launch path and is unaffected by this guard.
	call_deferred("_ensure_landscape_window")
	_build_background()
	_build_map_layer()
	_build_top_bar()
	_build_detail_panel()
	_build_player_panel()
	_build_quick_actions()
	_build_toast()
	set_process_input(true)

func _ensure_landscape_window() -> void:
	var viewport_size := get_viewport_rect().size
	if viewport_size.y <= viewport_size.x:
		return
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_size(Vector2i(int(DESIGN_SIZE.x), int(DESIGN_SIZE.y)))

func _build_background() -> void:
	var background := ColorRect.new()
	background.color = Color("#070d11")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

func _build_map_layer() -> void:
	map_frame = Control.new()
	map_frame.name = "LandscapeMapViewport"
	map_frame.position = Vector2.ZERO
	map_frame.size = Vector2(MAP_WIDTH, DESIGN_SIZE.y)
	map_frame.clip_contents = true
	map_frame.mouse_filter = Control.MOUSE_FILTER_STOP
	map_frame.gui_input.connect(_on_map_gui_input)
	add_child(map_frame)

	# The approved Map01 art is tall. The landscape preview keeps the full art in
	# a clipped, pannable world layer instead of permanently cropping the upper
	# route. Dragging changes only this presentation offset; formal map data is
	# untouched.
	map_world = Control.new()
	map_world.name = "MapWorld"
	map_world.position = Vector2(0, MAP_TOP_OFFSET)
	map_world.size = Vector2(MAP_WIDTH, MAP_CONTENT_HEIGHT)
	map_world.mouse_filter = Control.MOUSE_FILTER_PASS
	map_frame.add_child(map_world)

	var background_art := TextureRect.new()
	background_art.name = "MapBackgroundFull"
	background_art.texture = load("res://assets/maps/map_01/map01_background.png")
	background_art.position = Vector2.ZERO
	background_art.size = Vector2(MAP_WIDTH, MAP_CONTENT_HEIGHT)
	background_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_art.stretch_mode = TextureRect.STRETCH_SCALE
	background_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	background_art.modulate = Color(0.82, 0.88, 0.86, 1.0)
	background_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(background_art)

	var art_overlay := Control.new()
	art_overlay.name = "RouteAndFog"
	art_overlay.position = Vector2.ZERO
	art_overlay.size = Vector2(MAP_WIDTH, MAP_CONTENT_HEIGHT)
	art_overlay.set_script(load("res://scripts/scenes/landscape_map_art.gd"))
	art_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_world.add_child(art_overlay)

	# Quiet vignette bands leave a readable edge for the fixed HUD while keeping
	# the world visible behind it.
	var left_fog := ColorRect.new()
	left_fog.position = Vector2.ZERO
	left_fog.size = Vector2(78, DESIGN_SIZE.y)
	left_fog.color = Color("#071016c8")
	left_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.add_child(left_fog)
	var right_fog := ColorRect.new()
	right_fog.position = Vector2(MAP_WIDTH - 120, 0)
	right_fog.size = Vector2(120, DESIGN_SIZE.y)
	right_fog.color = Color("#071016b8")
	right_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_frame.add_child(right_fog)

	map_scrollbar = VScrollBar.new()
	map_scrollbar.name = "MapScrollBar"
	map_scrollbar.position = Vector2(MAP_WIDTH - 22, 110)
	map_scrollbar.size = Vector2(14, DESIGN_SIZE.y - 172)
	map_scrollbar.min_value = 0.0
	# ScrollBar.max_value is the content extent; `page` subtracts the visible
	# viewport from the usable value range. The top offset keeps the art's first
	# 22 pixels aligned just above the viewport, so the bottom value is 1468.
	map_scrollbar.max_value = MAP_CONTENT_HEIGHT + MAP_TOP_OFFSET
	map_scrollbar.page = DESIGN_SIZE.y
	map_scrollbar.step = 1.0
	map_scrollbar.value = 0.0
	map_scrollbar.tooltip_text = "上下查看整张地图"
	map_scrollbar.mouse_filter = Control.MOUSE_FILTER_STOP
	map_scrollbar.value_changed.connect(_on_map_scroll_changed)
	map_frame.add_child(map_scrollbar)

	# Screen title and location labels are deliberately separate from the art so
	# they can later be driven by the formal object/marker data.
	_add_map_label("万修之门", Vector2(420, 58), Vector2(170, 34), 20, GOLD)
	_add_map_label("古道", Vector2(726, 250), Vector2(70, 30), 16, TEXT)
	_add_map_label("隐秘山洞", Vector2(118, 340), Vector2(118, 30), 15, TEXT)
	_add_map_label("残碑", Vector2(292, 188), Vector2(74, 28), 14, GOLD)
	_add_map_label("断垣营地", Vector2(92, 564), Vector2(122, 30), 14, TEXT)
	_add_map_label("一号阵灯", Vector2(738, 548), Vector2(112, 30), 14, GOLD)

	# Click targets give the prototype a useful interaction pass without making
	# any profile writes or changing the vertical map flow.
	_add_marker_button("万修之门", "门禁未开 · 先完成前置探索", Rect2(430, 78, 126, 90))
	_add_marker_button("残碑", "残碑：记录着失落的山门旧誓", Rect2(286, 188, 96, 82))
	_add_marker_button("古道", "古道：向东可抵压阵石阶", Rect2(710, 260, 112, 86))
	_add_marker_button("隐秘山洞", "隐秘山洞：需要探灵才能确认入口", Rect2(106, 350, 138, 90))

func _add_map_label(text: String, position: Vector2, label_size: Vector2, font_size: int, color: Color) -> Label:
	var label := KWUI.label(map_world, text, Rect2(position, label_size), font_size, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.add_theme_color_override("font_shadow_color", Color("#05090bdd"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label

func _add_marker_button(title: String, body: String, rect: Rect2) -> void:
	var button := Button.new()
	button.name = "Marker_%s" % title
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.modulate = Color(1, 1, 1, 0.03)
	button.pressed.connect(_select_marker.bind(title, body, button))
	map_world.add_child(button)

func _build_top_bar() -> void:
	var back := KWUI.button(self, "‹  返回", Rect2(22, 20, 116, 42), 15)
	back.pressed.connect(_show_toast.bind("横版视觉预览 · 返回入口尚未接入", 0))
	var title := KWUI.label(self, "破禁山麓 · 万修之门", Rect2(170, 19, 390, 34), 21, GOLD, HORIZONTAL_ALIGNMENT_LEFT)
	title.add_theme_color_override("font_shadow_color", Color("#05090bdd"))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 2)
	KWUI.label(self, "探索地图 01", Rect2(170, 51, 180, 20), 11, MUTED)
	KWUI.label(self, "拖动查看地图全貌", Rect2(420, 53, 190, 20), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

	var progress := KWUI.panel(self, Rect2(655, 18, 278, 64), Color("#10171ae8"), Color("#766e55"))
	KWUI.label(progress, "探索度", Rect2(14, 8, 64, 18), 11, MUTED)
	progress_label = KWUI.label(progress, "28%", Rect2(202, 7, 54, 20), 14, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	var bar := ProgressBar.new()
	bar.position = Vector2(14, 34)
	bar.size = Vector2(242, 10)
	bar.value = 28
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", KWUI.style_box(Color("#070b0d"), Color("#414944"), 2, 1))
	bar.add_theme_stylebox_override("fill", KWUI.style_box(Color("#b18c52"), Color("#e7cf91"), 2, 0))
	progress.add_child(bar)

func _build_detail_panel() -> void:
	var panel := KWUI.panel(self, Rect2(MAP_WIDTH, 0, PANEL_WIDTH, DESIGN_SIZE.y), PANEL, Color("#6f725f"))
	panel.name = "RegionDetailPanel"
	KWUI.label(panel, "破禁山麓 · 万修之门", Rect2(20, 22, PANEL_WIDTH - 40, 34), 19, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(panel, "地图 01", Rect2(20, 54, PANEL_WIDTH - 40, 20), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.divider(panel, Rect2(20, 82, PANEL_WIDTH - 40, 1), Color("#81745480"))
	detail_kind = KWUI.label(panel, "区域详情", Rect2(20, 104, PANEL_WIDTH - 40, 24), 13, Color("#d8d0ae"))
	detail_title = KWUI.label(panel, "雾锁山门", Rect2(20, 131, PANEL_WIDTH - 40, 32), 22, TEXT)
	detail_body = KWUI.label(panel, "破禁山麓，禁地前沿。\n古阵残留，灵气驳杂，险象环生。", Rect2(20, 175, PANEL_WIDTH - 40, 92), 14, TEXT)
	detail_body.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var task_card := KWUI.panel(panel, Rect2(18, 292, PANEL_WIDTH - 36, 166), Color("#171d20d9"), Color("#5f6c62"))
	KWUI.label(task_card, "当前任务", Rect2(16, 14, 180, 22), 13, Color("#d8d0ae"))
	objective_label = KWUI.label(task_card, "前往万修之门\n探索隐秘山洞\n调查残碑旧誓", Rect2(18, 48, PANEL_WIDTH - 72, 100), 14, TEXT)
	objective_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	var rest := KWUI.map_button(panel, "休整", Rect2(20, 488, 126, 48), 14)
	rest.pressed.connect(_show_toast.bind("队伍可在当前区域休整", 0))
	var backpack := KWUI.map_button(panel, "背包", Rect2(164, 488, 126, 48), 14)
	backpack.pressed.connect(_show_toast.bind("临时背包：灵粮 60 · 探灵镜 1", 0))
	var return_button := KWUI.map_button(panel, "归营", Rect2(20, 548, 270, 48), 14)
	return_button.pressed.connect(_show_toast.bind("尚未回到入口传送阵", 1))
	KWUI.label(panel, "横版方向预览 · 未接入正式运行链", Rect2(20, 655, PANEL_WIDTH - 40, 22), 10, Color("#84918a"), HORIZONTAL_ALIGNMENT_CENTER)

func _build_player_panel() -> void:
	var panel := KWUI.panel(self, Rect2(22, 566, 358, 132), Color("#0d1518e8"), Color("#6f725f"))
	KWUI.texture(panel, "res://assets/camp/ui/top/ui_camp_avatar_frame.png", Rect2(14, 18, 76, 92))
	var avatar := KWUI.texture(panel, "res://assets/camp/ui/top/portrait_player_placeholder.png", Rect2(14, 18, 76, 92))
	avatar.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	KWUI.label(panel, "道心凌云", Rect2(106, 16, 160, 24), 17, TEXT)
	KWUI.label(panel, "炼气初期", Rect2(106, 43, 120, 18), 11, MUTED)
	KWUI.label(panel, "生命", Rect2(106, 70, 34, 16), 10, Color("#d8b28e"))
	_add_status_bar(panel, Rect2(146, 73, 192, 9), 100.0, Color("#a85348"), Color("#e08f6d"))
	KWUI.label(panel, "329 / 329", Rect2(260, 92, 78, 16), 10, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	KWUI.label(panel, "灵息", Rect2(106, 96, 34, 16), 10, Color("#8db8c7"))
	_add_status_bar(panel, Rect2(146, 99, 192, 9), 82.0, Color("#356d83"), Color("#79c9cf"))
	KWUI.label(panel, "146 / 146", Rect2(260, 116, 78, 16), 10, TEXT, HORIZONTAL_ALIGNMENT_RIGHT)

func _add_status_bar(parent: Control, rect: Rect2, value: float, background: Color, fill: Color) -> void:
	var bar := ProgressBar.new()
	bar.position = rect.position
	bar.size = rect.size
	bar.value = value
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", KWUI.style_box(background.darkened(0.6), background, 2, 1))
	bar.add_theme_stylebox_override("fill", KWUI.style_box(fill, fill, 2, 0))
	parent.add_child(bar)

func _build_quick_actions() -> void:
	var entries := [
		["修行", "icon_camp_achievements.png"],
		["储物", "icon_camp_mail.png"],
		["功法", "icon_camp_daily_progress.png"],
		["设置", "icon_camp_settings.png"],
	]
	var start_x := 666.0
	for index in entries.size():
		var button := Button.new()
		button.position = Vector2(start_x + index * 72, 602)
		button.size = Vector2(62, 62)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = str(entries[index][0])
		button.add_theme_stylebox_override("normal", KWUI.style_box(Color("#11171ae6"), Color("#8b7650"), 31, 1))
		button.add_theme_stylebox_override("hover", KWUI.style_box(Color("#25352fe8"), Color("#e4c77e"), 31, 2))
		button.add_theme_stylebox_override("pressed", KWUI.style_box(Color("#3a4437ee"), Color("#e4c77e"), 31, 2))
		KWUI.texture(button, "res://assets/camp/ui/bottom/%s" % entries[index][1], Rect2(16, 12, 30, 30))
		KWUI.label(button, str(entries[index][0]), Rect2(2, 42, 58, 16), 9, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
		button.pressed.connect(_show_toast.bind("%s功能尚未接入横版预览" % entries[index][0], 0))
		add_child(button)

func _build_toast() -> void:
	toast_panel = KWUI.panel(self, Rect2(336, 516, 480, 42), Color("#162326f2"), Color("#9c8151"))
	toast_panel.visible = false
	toast_panel.z_index = 200
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = KWUI.label(toast_panel, "", Rect2(10, 4, 460, 32), 12, TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if is_instance_valid(map_scrollbar):
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			map_scrollbar.value = clampf(map_scrollbar.value + direction * 120.0, map_scrollbar.min_value, map_scrollbar.max_value - map_scrollbar.page)
			map_frame.accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			map_dragging = true
			map_drag_start = event.position
			map_world_start = map_world.position
			map_frame.accept_event()
		else:
			map_dragging = false
			map_frame.accept_event()
		return
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			map_dragging = true
			map_drag_start = event.position
			map_world_start = map_world.position
		else:
			map_dragging = false
		map_frame.accept_event()

		return
	if map_dragging and event is InputEventMouseMotion:
		_move_map_by(event.position - map_drag_start)
		map_frame.accept_event()
	elif map_dragging and event is InputEventScreenDrag and event.index == 0:
		_move_map_by(event.position - map_drag_start)
		map_frame.accept_event()
	elif map_dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		map_dragging = false

func _move_map_by(delta: Vector2) -> void:
	var next_position := map_world_start + delta
	var min_y := DESIGN_SIZE.y - MAP_CONTENT_HEIGHT
	map_world.position = Vector2(
		clampf(next_position.x, minf(MAP_WIDTH - map_world.size.x, 0.0), 0.0),
		clampf(next_position.y, min_y, MAP_TOP_OFFSET)
	)
	if is_instance_valid(map_scrollbar):
		map_scrollbar.set_value_no_signal(MAP_TOP_OFFSET - map_world.position.y)

func _on_map_scroll_changed(value: float) -> void:
	if not is_instance_valid(map_world):
		return
	map_world.position.y = clampf(MAP_TOP_OFFSET - value, DESIGN_SIZE.y - MAP_CONTENT_HEIGHT, MAP_TOP_OFFSET)

func _select_marker(title: String, body: String, button: Button) -> void:
	if is_instance_valid(selected_marker):
		selected_marker.modulate = Color(1, 1, 1, 0.03)
	selected_marker = button
	selected_marker.modulate = Color(1, 1, 1, 0.16)
	detail_kind.text = "地标详情"
	detail_title.text = title
	detail_body.text = body
	_show_toast("已查看：%s" % title, 0)

func _show_toast(message: String, _severity: int = 0) -> void:
	if not is_instance_valid(toast_panel):
		return
	toast_label.text = message
	toast_panel.visible = true
	var serial := Time.get_ticks_msec()
	toast_panel.set_meta("serial", serial)
	await get_tree().create_timer(2.2).timeout
	if is_instance_valid(toast_panel) and int(toast_panel.get_meta("serial", -1)) == serial:
		toast_panel.visible = false

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_show_toast("横版视觉预览 · 按钮仅用于查看布局", 0)
