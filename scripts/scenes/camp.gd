extends Control

const RESOURCE_IDS := ["spiritGrain", "spiritWood", "darkIron", "spiritStone", "gengJing"]
const RESOURCE_ICONS := {
	"spiritGrain": "spirit_grain", "spiritWood": "spirit_wood", "darkIron": "dark_iron",
	"spiritStone": "spirit_crystal", "gengJing": "geng_jing"
}
const VIEW_SIZE := Vector2(375, 817)
const TOP_HUD_RECT := Rect2(0, 44, 375, 132)
const BOTTOM_HUD_RECT := Rect2(0, 745, 375, 48)
const BUILDINGS := [
	# 名称牌和状态标记使用建筑中心为原点的 Godot 本地像素偏移。
	{"id": "yi_shi_dian", "name": "议事殿", "x": 426, "y": 153, "w": 247, "h": 165, "name_offset": Vector2(2.166667, 67.055556), "badge_offset": Vector2(33.409722, 57.197917)},
	{"id": "ling_pu", "name": "灵源院", "x": 724, "y": 514, "w": 247, "h": 165, "name_offset": Vector2(-2.5, 72.5), "badge_offset": Vector2(26.5, 72.5)},
	{"id": "zhao_xian_tai", "name": "招贤馆", "x": 252, "y": 358, "w": 247, "h": 165, "name_offset": Vector2(8.5, 67.5), "badge_offset": Vector2(38.409722, 57.197917)},
	{"id": "bai_bao_ku", "name": "百宝库", "x": 71, "y": 284, "w": 206, "h": 137, "name_offset": Vector2(-10, 58.5), "badge_offset": Vector2(18, 58.5)},
	{"id": "lian_qi_fang", "name": "炼器坊", "x": 571, "y": 339, "w": 247, "h": 165, "name_offset": Vector2(-27.5, 76.5), "badge_offset": Vector2(0.5, 76.5)},
	{"id": "jiao_yi_hang", "name": "交易行", "x": 748, "y": 271, "w": 206, "h": 137, "name_offset": Vector2(-13, 54.5), "badge_offset": Vector2(15, 54.5)},
	{"id": "huan_hun_tan", "name": "还魂殿", "x": 38, "y": 464, "w": 206, "h": 137, "name_offset": Vector2(7, 58.5), "badge_offset": Vector2(35, 58.5)},
	{"id": "portal", "name": "启程", "x": 421, "y": 535, "w": 206, "h": 139, "name_offset": Vector2(0, 49.5), "badge_offset": Vector2.ZERO}
]

var resource_labels: Dictionary = {}
var currency_label: Label
var modal: Control
var toast_panel: Panel
var toast_label: Label
var toast_serial := 0
var panorama_scroll: ScrollContainer
var panorama_dragging := false
var panorama_drag_moved := false
var panorama_drag_start := Vector2.ZERO
var panorama_scroll_start := 0
var ignore_building_until_msec := 0
var expedition_draft: Dictionary = {}
var animated_portraits: Array[Dictionary] = []

func _ready() -> void:
	Game.settle_production()
	_build_scene()
	_refresh_hud()
	Game.state_changed.connect(_refresh_hud)
	Game.feedback.connect(_show_feedback)
	set_process_input(true)

func _process(delta: float) -> void:
	# TextureRect 不会把 Sprite Sheet 自动当作动画播放。这里逐帧替换
	# AtlasTexture，确保显示的是 4×2 网格中的单个区域，而不是整张图。
	for index in range(animated_portraits.size() - 1, -1, -1):
		var animation: Dictionary = animated_portraits[index]
		var portrait_reference: Variant = animation.get("node")
		# 已释放的 Godot 对象不能先执行 `as TextureRect`，否则转换本身
		# 就会触发 "Trying to cast a freed object"。
		if not is_instance_valid(portrait_reference):
			animated_portraits.remove_at(index)
			continue
		var portrait := portrait_reference as TextureRect
		if portrait == null:
			animated_portraits.remove_at(index)
			continue
		var frames: Array = animation.get("frames", [])
		if frames.is_empty():
			animated_portraits.remove_at(index)
			continue
		var elapsed := float(animation.get("elapsed", 0.0)) + delta
		var frame_duration := maxf(float(animation.get("frame_duration", 0.25)), 0.001)
		var frame_index := int(animation.get("frame_index", 0))
		while elapsed >= frame_duration:
			elapsed -= frame_duration
			frame_index = (frame_index + 1) % frames.size()
		portrait.texture = frames[frame_index]
		animation["elapsed"] = elapsed
		animation["frame_index"] = frame_index
		animated_portraits[index] = animation

func _input(event: InputEvent) -> void:
	if is_instance_valid(modal): return
	var pointer_position := Vector2.ZERO
	var pressed := false
	var released := false
	var dragged := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_position = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		pointer_position = event.position
		dragged = event.relative.length() > 0.0
	elif event is InputEventScreenTouch:
		pointer_position = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		pointer_position = event.position
		dragged = event.relative.length() > 0.0
	if TOP_HUD_RECT.has_point(pointer_position) or BOTTOM_HUD_RECT.has_point(pointer_position) or not is_instance_valid(panorama_scroll): return
	if pressed:
		panorama_dragging = true
		panorama_drag_moved = false
		panorama_drag_start = pointer_position
		panorama_scroll_start = panorama_scroll.scroll_horizontal
	elif panorama_dragging and dragged:
		var delta_x := pointer_position.x - panorama_drag_start.x
		if absf(delta_x) > 4.0: panorama_drag_moved = true
		panorama_scroll.scroll_horizontal = clampi(panorama_scroll_start - int(delta_x), 0, int(panorama_scroll.get_h_scroll_bar().max_value))
		if panorama_drag_moved: ignore_building_until_msec = Time.get_ticks_msec() + 160
	elif released:
		panorama_dragging = false

func _build_scene() -> void:
	var background := ColorRect.new()
	background.color = KWUI.BG
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_build_panorama()
	_build_top_hud()
	_build_bottom_hud()
	_build_toast()

func _build_top_hud() -> void:
	# 透明顶部 HUD 紧贴 44px 状态栏下沿。
	var hud := Control.new()
	hud.position = TOP_HUD_RECT.position
	hud.size = TOP_HUD_RECT.size
	add_child(hud)
	# 先画头像框，再画肖像；两张 PNG 都有不透明中心，反转顺序会遮住人物。
	KWUI.texture(hud, "res://assets/camp/ui/top/ui_camp_avatar_frame.png", Rect2(12, 12, 40, 40))
	KWUI.texture(hud, "res://assets/camp/ui/top/portrait_player_placeholder.png", Rect2(12, 12, 40, 40))
	var resource_centers := [92.0, 151.5, 211.0, 270.5, 330.0]
	for index in RESOURCE_IDS.size():
		var id: String = RESOURCE_IDS[index]
		var x := float(resource_centers[index])
		KWUI.texture(hud, "res://assets/camp/ui/top/icon_resource_%s.png" % RESOURCE_ICONS[id], Rect2(x - 11, 21.5, 22, 22))
		var value := KWUI.label(hud, "0", Rect2(x - 27, 35, 54, 17), 10, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
		value.add_theme_color_override("font_shadow_color", Color("#07100fe0"))
		value.add_theme_constant_override("shadow_offset_x", 1)
		value.add_theme_constant_override("shadow_offset_y", 1)
		resource_labels[id] = value
	var main_task := Button.new()
	main_task.position = Vector2(8, 62)
	main_task.size = Vector2(359, 42)
	main_task.flat = true
	main_task.focus_mode = Control.FOCUS_NONE
	hud.add_child(main_task)
	main_task.pressed.connect(_show_feedback.bind("主线：整备营地，准备首次入山", 0))
	KWUI.texture(main_task, "res://assets/camp/ui/top/icon_camp_main_task.png", Rect2(6, 5, 32, 32))
	var objective := KWUI.label(main_task, "主线：整备营地，准备首次入山", Rect2(45, 17, 274, 20), 11, Color("#e8dcbb"))
	objective.add_theme_color_override("font_shadow_color", Color.BLACK)
	objective.add_theme_constant_override("shadow_offset_x", 1)
	objective.add_theme_constant_override("shadow_offset_y", 1)

func _build_panorama() -> void:
	var viewport := ScrollContainer.new()
	panorama_scroll = viewport
	viewport.position = Vector2.ZERO
	viewport.size = VIEW_SIZE
	viewport.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	viewport.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	viewport.follow_focus = true
	add_child(viewport)
	var content := Control.new()
	content.custom_minimum_size = Vector2(1050, 817)
	content.size = Vector2(1050, 817)
	viewport.add_child(content)
	# 源节点为 3318×2580，内容画布为 3024×2353；两者都按 2.88 缩放并居中。
	var panorama := KWUI.texture(content, "res://assets/camp/env_camp_panorama_bg.png", Rect2(-51, -39.5, 1152, 896))
	panorama.stretch_mode = TextureRect.STRETCH_SCALE
	panorama.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for building in BUILDINGS:
		_add_building(content, building)
	await get_tree().process_frame
	viewport.scroll_horizontal = 338

func _add_building(parent: Control, info: Dictionary) -> void:
	var host := Control.new()
	host.position = Vector2(info["x"], info["y"])
	host.size = Vector2(info["w"], info["h"])
	parent.add_child(host)
	var id: String = info["id"]
	var level := 1 if id == "portal" else int(Game.profile.get("camp", {}).get("buildingLevels", {}).get(id, 0))
	var texture_path := "res://assets/camp/buildings/env_camp_%s.png" % ("portal" if id == "portal" else "building_" + id)
	if level <= 0 and id != "portal":
		var locked_path := texture_path.trim_suffix(".png") + "_locked.png"
		if ResourceLoader.exists(locked_path): texture_path = locked_path
	var image := KWUI.texture(host, texture_path, Rect2(0, 0, info["w"], info["h"]))
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var button := Button.new()
	button.position = Vector2.ZERO
	button.size = Vector2(info["w"], info["h"])
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	host.add_child(button)
	button.pressed.connect(_on_building_pressed.bind(id, level))
	var name_center := Vector2(float(info["w"]) / 2.0, float(info["h"]) / 2.0) + Vector2(info["name_offset"])
	var plate_size := Vector2(84, 20) if id == "portal" else Vector2(58, 20)
	var plate := KWUI.panel(host, Rect2(name_center - plate_size / 2.0, plate_size), Color("#202a27f5") if id == "portal" else (Color("#202a2799") if level <= 0 else Color("#241d18eb")), Color("#6f8f85") if id == "portal" else (Color("#5e6a66b3") if level <= 0 else Color("#80623af2")))
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title := KWUI.label(host, info["name"], Rect2(name_center - plate_size / 2.0, plate_size), 10 if id != "portal" else 11, Color("#abb2ab") if level <= 0 and id != "portal" else Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if level <= 0:
		var badge_center := Vector2(float(info["w"]) / 2.0, float(info["h"]) / 2.0) + Vector2(info["badge_offset"])
		# 锁定标记在 375×817 逻辑画布上固定显示为 12×12。
		var badge_size := Vector2(12, 12)
		var badge := KWUI.texture(host, "res://assets/camp/ui/common/icon_camp_building_lock.png", Rect2(badge_center - badge_size / 2.0, badge_size))
		badge.modulate = Color(1, 1, 1, 0.76)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif id == "huan_hun_tan":
		var has_dead_hero := false
		for hero in Game.profile.get("roster", []):
			if bool(hero.get("isDead", false)):
				has_dead_hero = true
				break
		if has_dead_hero:
			var badge_center := Vector2(float(info["w"]) / 2.0, float(info["h"]) / 2.0) + Vector2(info["badge_offset"])
			var badge := KWUI.texture(host, "res://assets/camp/ui/common/icon_camp_building_attention.png", Rect2(badge_center - Vector2(12, 12), Vector2(24, 24)))
			badge.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_bottom_hud() -> void:
	# 图标型底部快捷入口，没有大底板、文字标签或额外“入山”按钮。
	var hud := Control.new()
	hud.position = BOTTOM_HUD_RECT.position
	hud.size = BOTTOM_HUD_RECT.size
	add_child(hud)
	var entries := [
		["settings", "设置", "icon_camp_settings.png"], ["achievements", "成就", "icon_camp_achievements.png"],
		["leaderboard", "排行", "icon_camp_leaderboard.png"], ["mail", "邮件", "icon_camp_mail.png"],
		["daily", "日常", "icon_camp_daily_progress.png"]
	]
	for index in entries.size():
		var entry: Array = entries[index]
		var button := Button.new()
		# 五个入口中心位于 22、66、110、154、198，
		# 每个可见图标按钮宽 42；左边不能额外偏移 13px。
		button.position = Vector2(1 + index * 44, 8)
		button.size = Vector2(42, 32)
		button.flat = true
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = entry[1]
		hud.add_child(button)
		KWUI.texture(button, "res://assets/camp/ui/bottom/" + entry[2], Rect2(11, 6, 20, 20))
		button.pressed.connect(_on_system_pressed.bind(entry[0]))
	KWUI.texture(hud, "res://assets/camp/ui/bottom/icon_currency_spirit_stone.png", Rect2(304, 12, 24, 24))
	currency_label = KWUI.label(hud, "0", Rect2(333, 12, 42, 24), 12, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_RIGHT)

func _build_toast() -> void:
	toast_panel = KWUI.panel(self, Rect2(40, 676, 295, 54), Color("#182c31ee"), KWUI.TEAL)
	toast_panel.visible = false
	toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_label = KWUI.label(toast_panel, "", Rect2(10, 5, 275, 44), 12, KWUI.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _refresh_hud() -> void:
	Game.settle_production()
	for id in resource_labels:
		if is_instance_valid(resource_labels[id]): resource_labels[id].text = str(Game.wallet_value(id))
	if is_instance_valid(currency_label): currency_label.text = str(Game.wallet_value("immortalCoin"))

func _on_building_pressed(id: String, level: int) -> void:
	if Time.get_ticks_msec() < ignore_building_until_msec: return
	match id:
		"ling_pu": _open_ling_pu()
		"portal": _open_expedition()
		"yi_shi_dian": _open_council()
		_:
			_show_feedback("%s尚未开放" % Game.text("building." + id, id), 1 if level > 0 else 2)

func _on_system_pressed(id: String) -> void:
	if id == "settings": _open_settings()
	else: _show_feedback("该功能尚未开放", 1)

func _make_modal(title: String, background_path: String = "") -> Panel:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.72)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(blocker)
	var panel_rect := Rect2(8, 105, 359, 607)
	if background_path.contains("ling_pu_panel_body"):
		panel_rect = Rect2(0.5, 111.5, 374, 594)
	elif background_path.contains("council_npc_dialog_panel"):
		panel_rect = Rect2(24, 153.5, 327, 510)
	var body := KWUI.panel(modal, panel_rect, Color("#111917fa"), Color("#80623af2"))
	if not background_path.is_empty():
		# 导入的面板已包含本体和装饰；Godot 容器保持透明，避免叠出第二层圆角底板。
		body.add_theme_stylebox_override("panel", KWUI.style_box(Color(0, 0, 0, 0), Color.TRANSPARENT, 0, 0))
		var art_rect := Rect2(12, 32, 335, 506)
		if background_path.contains("ling_pu_panel_body"):
			# 内容坐标已是 Godot 逻辑像素；面板图按 359×570 交付框的准确位置摆放。
			art_rect = Rect2(19.5, 42.5, 335, 503)
		elif background_path.contains("council_npc_dialog_panel"):
			art_rect = Rect2(0, 0, 327, 510)
		var panel_art := KWUI.texture(body, background_path, art_rect)
		panel_art.stretch_mode = TextureRect.STRETCH_SCALE
		panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if background_path.contains("panel_body") and not background_path.contains("council_npc_dialog"):
			var top_decoration_rect := Rect2(0, 10, panel_rect.size.x, 65)
			if background_path.contains("ling_pu"):
				top_decoration_rect = Rect2(7.5, 10.5, 359, 65)
			var top_decoration := KWUI.texture(body, "res://assets/camp/ui/expedition/ui_expedition_panel_decoration_top.png", top_decoration_rect)
			top_decoration.stretch_mode = TextureRect.STRETCH_SCALE
			top_decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var bottom_decoration_rect := Rect2(0, 490, panel_rect.size.x, 55)
			if background_path.contains("ling_pu"):
				bottom_decoration_rect = Rect2(7.5, 491.5, 359, 55)
			var bottom_decoration := KWUI.texture(body, "res://assets/camp/ui/expedition/ui_expedition_panel_decoration_bottom.png", bottom_decoration_rect)
			bottom_decoration.stretch_mode = TextureRect.STRETCH_SCALE
			bottom_decoration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_rect := Rect2(0, 41, panel_rect.size.x, 24)
	var title_size := 20
	if background_path.contains("ling_pu"):
		title_rect = Rect2(0, 33, panel_rect.size.x, 25)
		title_size = 21
	elif background_path.contains("council_npc_dialog"):
		title_rect = Rect2(0, 36, panel_rect.size.x, 16)
		title_size = 12
	var title_label := KWUI.label(body, title, title_rect, title_size, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if title == "设置与存档":
		var close := KWUI.button(body, "×", Rect2(panel_rect.size.x - 48, 12, 42, 42), 22)
		close.pressed.connect(_close_modal)
	return body

func _close_modal() -> void:
	# 弹层中的动态立绘会与弹层一起释放，先清除动画更新列表，
	# 避免下一帧继续访问已经 queue_free 的 TextureRect。
	animated_portraits.clear()
	if is_instance_valid(modal): modal.queue_free()
	modal = null

func _camp_button(parent: Node, text: String, rect: Rect2, primary := false, font_size := 14) -> Button:
	var button := KWUI.button(parent, text, rect, font_size)
	var base := Color("#322518") if primary else Color("#241d18")
	var outer := Color("#cd9e4a") if primary else Color("#b58a42")
	var inner := Color("#b58a42") if primary else Color("#80623a")
	button.add_theme_stylebox_override("normal", KWUI.style_box(base, outer, 4, 1))
	button.add_theme_stylebox_override("hover", KWUI.style_box(Color("#46351f"), Color("#dbb052"), 4, 1))
	button.add_theme_stylebox_override("pressed", KWUI.style_box(Color("#211a13"), inner, 4, 1))
	button.add_theme_stylebox_override("disabled", KWUI.style_box(Color("#181816"), Color("#5e6a66"), 4, 1))
	return button

func _add_icon_button(parent: Node, rect: Rect2, path: String, disabled := false) -> Button:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.disabled = disabled
	parent.add_child(button)
	var icon_size := Vector2(25, 25)
	var icon := KWUI.texture(button, path, Rect2((rect.size - icon_size) / 2.0, icon_size))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if disabled: icon.modulate = Color(0.48, 0.48, 0.48, 0.72)
	return button

func _open_ling_pu() -> void:
	Game.settle_production()
	var body := _make_modal("灵源院", "res://assets/camp/ui/ling_pu/ui_ling_pu_panel_body.png")
	var camp: Dictionary = Game.profile["camp"]
	var assignments: Dictionary = camp["workerAssignments"]
	var assigned := 0
	for id in assignments: assigned += int(assignments[id])
	var idle := int(camp["workerCount"]) - assigned
	KWUI.label(body, "闲置杂役：%d" % idle, Rect2(251, 69, 78, 18), 12, Color("#b58a42"))
	var jobs := [
		{"id": "spiritGrain", "name": "灵粮", "open": true},
		{"id": "spiritWood", "name": "灵木", "open": true},
		{"id": "darkIron", "name": "玄铁", "open": true}
	]
	# 当前 Godot 页面只激活前三行；灵晶和庚精是后续版本预留节点，
	# 不能在迁移版中绘制成“尚未开放”的第四、第五行。
	var row_centers := [130.9, 212.1, 295.4]
	for index in jobs.size():
		var definition: Dictionary = jobs[index]
		var job: String = definition["id"]
		var opened: bool = definition["open"]
		var row_center: float = row_centers[index]
		var row_art := KWUI.texture(body, "res://assets/camp/ui/council/ui_council_npc_item_default.png", Rect2(45.5, row_center - 41.7, 283, 50))
		row_art.stretch_mode = TextureRect.STRETCH_SCALE
		row_art.modulate = Color.WHITE
		row_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var job_icon := KWUI.texture(body, "res://assets/camp/ui/top/icon_resource_%s.png" % RESOURCE_ICONS[job], Rect2(48.4, row_center - 33.4, 33.3, 33.3))
		job_icon.modulate = Color.WHITE if opened else Color(0.55, 0.55, 0.55, 0.72)
		job_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		KWUI.label(body, definition["name"], Rect2(93.4, row_center - 34.4, 31.3, 18.8), 14, Color("#e8dcbb"))
		var rate_text := "产量 +%d" % int(assignments.get(job, 0))
		KWUI.label(body, rate_text, Rect2(140.6, row_center - 33.3, 62.5, 16.7), 11, Color("#91a49e"), HORIZONTAL_ALIGNMENT_CENTER)
		var stock_text := "%d / %d" % [Game.wallet_value(job), Game.resource_capacity(job)]
		KWUI.label(body, stock_text, Rect2(82.3, row_center - 15.6, 114.6, 16.7), 11, Color("#91a49e"), HORIZONTAL_ALIGNMENT_CENTER)
		var upgrade := _camp_button(body, "升级", Rect2(250.5, row_center - 34.4, 75, 29), false, 12)
		upgrade.pressed.connect(_upgrade_storage.bind(job))
		var worker_count := int(assignments.get(job, 0)) if opened else 0
		var minus := _add_icon_button(body, Rect2(221.4, row_center - 1, 50, 50), "res://assets/camp/ui/ling_pu/icon_action_minus.png", worker_count <= 0)
		minus.pressed.connect(_adjust_worker.bind(job, -1))
		KWUI.label(body, "%d/%d" % [worker_count, int(camp["workerCount"])], Rect2(260.5, row_center + 15.6, 50, 16.7), 12, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
		var plus := _add_icon_button(body, Rect2(301, row_center - 1, 50, 50), "res://assets/camp/ui/ling_pu/icon_action_plus.png", assigned >= int(camp["workerCount"]))
		plus.pressed.connect(_adjust_worker.bind(job, 1))
		KWUI.label(body, "岗位运转", Rect2(51.6, row_center + 16.7, 114.6, 14.6), 10, Color("#91a49e"), HORIZONTAL_ALIGNMENT_CENTER)
	var recruit := _camp_button(body, "杂役招募", Rect2(39, 570, 137.5, 46), false, 14)
	recruit.pressed.connect(_open_recruit_confirmation)
	var close := _camp_button(body, "关闭", Rect2(197.5, 570, 137.5, 46), false, 14)
	close.pressed.connect(_close_modal)

func _adjust_worker(job: String, delta: int) -> void:
	if not Game.adjust_workers(job, delta): _show_feedback("没有可调整的杂役", 2)
	_open_ling_pu()

func _recruit_workers() -> void:
	var cost := int(Game.ling_pu_config.get("recruitSpiritGrainCost", 50))
	var granted := int(Game.ling_pu_config.get("workersPerRecruit", 5))
	if Game.recruit_workers(): _show_feedback("已招募 %d 名杂役" % granted, 0)
	else: _show_feedback("灵粮不足，需要 %d" % cost, 2)
	_open_ling_pu()

func _open_recruit_confirmation() -> void:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.86)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(blocker)
	var body := Control.new()
	body.position = Vector2(24, 275.5)
	body.size = Vector2(327, 266)
	modal.add_child(body)
	var art := KWUI.texture(body, "res://assets/camp/ui/ling_pu/ui_ling_pu_recruit_panel.png", Rect2(0, 0, 327, 266))
	art.stretch_mode = TextureRect.STRETCH_SCALE
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	KWUI.label(body, "招募杂役", Rect2(0, 18, 327, 28), 20, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.texture(body, "res://assets/camp/ui/top/icon_resource_spirit_grain.png", Rect2(139.5, 64, 32, 32))
	var recruit_cost := int(Game.ling_pu_config.get("recruitSpiritGrainCost", 50))
	var granted := int(Game.ling_pu_config.get("workersPerRecruit", 5))
	KWUI.label(body, "需要 %d 灵粮" % recruit_cost, Rect2(40, 104, 247, 24), 15, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(body, "杂役 +%d" % granted, Rect2(55, 139, 217, 24), 15, Color("#58b9b4"), HORIZONTAL_ALIGNMENT_CENTER)
	var confirm := _camp_button(body, "招募", Rect2(23, 196, 132, 44), true, 14)
	confirm.disabled = Game.wallet_value("spiritGrain") < recruit_cost
	confirm.pressed.connect(_recruit_workers)
	var cancel := _camp_button(body, "取消", Rect2(172, 196, 132, 44), false, 14)
	cancel.pressed.connect(_open_ling_pu)

func _upgrade_storage(job: String) -> void:
	if Game.upgrade_storage(job): _show_feedback("储量已升级", 0)
	else: _show_feedback("灵木不足或已达最高等级", 2)
	_open_ling_pu()

func _open_expedition() -> void:
	var body := _make_modal("入山整备", "res://assets/camp/ui/expedition/ui_expedition_panel_body.png")
	if Game.profile.get("expedition") != null:
		KWUI.label(body, "检测到未结束的探索进度", Rect2(30, 130, 299, 40), 16, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
		var resume := _camp_button(body, "继续探索 · 破禁山麓", Rect2(62, 220, 235, 50), true, 15)
		resume.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/map.tscn"))
		var close_resume := _camp_button(body, "返回营地", Rect2(113.5, 556, 132, 44), false, 14)
		close_resume.pressed.connect(_close_modal)
		return
	if expedition_draft.is_empty():
		expedition_draft = Game.profile.get("expeditionPreparation", {}).get("loadout", {"spiritGrain": 60, "pickaxe": 0, "lens": 0}).duplicate(true)
	KWUI.label(body, "传送阵 · 昆吾山外缘", Rect2(89.5, 76, 180, 16), 12, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	var portraits := ["shi_yan", "lu_qing", "bai_ling", "mo_yan"]
	var heroes: Array = Game.profile.get("roster", [])
	for index in portraits.size():
		var hero: Dictionary = heroes[index]
		_add_expedition_hero_card(body, Rect2(31 + index * 74.5, 98, 71, 163), portraits[index], hero)
	var edit_party := _camp_button(body, "编辑队伍", Rect2(48, 273, 72, 28), false, 10)
	edit_party.pressed.connect(_open_hero_selection)
	for index in 3:
		var tab := Button.new()
		tab.position = Vector2(135 + index * 32, 274)
		tab.size = Vector2(26, 26)
		tab.flat = true
		tab.focus_mode = Control.FOCUS_NONE
		body.add_child(tab)
		var tab_path := "res://assets/camp/ui/expedition/ui_expedition_party_tab_%s.png" % ("selected" if index == 0 else "default")
		var tab_art := KWUI.texture(tab, tab_path, Rect2(0, 0, 26, 26))
		tab_art.stretch_mode = TextureRect.STRETCH_SCALE
		tab_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		KWUI.label(tab, "%d队" % (index + 1), Rect2(0, 4, 26, 18), 9, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		tab.pressed.connect(_show_feedback.bind("该队伍栏尚未解锁" if index > 0 else "当前为 1 队", 1 if index > 0 else 0))
	var rest := _camp_button(body, "调息", Rect2(240, 273, 72, 28), false, 10)
	rest.disabled = true
	var burden_limit := _expedition_burden_limit(heroes)
	var burden := int(expedition_draft.get("spiritGrain", 0)) + int(expedition_draft.get("pickaxe", 0)) * 12 + int(expedition_draft.get("lens", 0)) * 4
	KWUI.label(body, "负重：", Rect2(128, 314, 43, 20), 12, Color("#91a49e"))
	KWUI.label(body, "%d / %d" % [burden, burden_limit], Rect2(171, 314, 76, 20), 12, Color("#e58b52") if burden > burden_limit else Color("#e8dcbb"))
	_add_expedition_loadout_row(body, "spiritGrain", "灵粮", "res://assets/camp/ui/top/icon_resource_spirit_grain.png", 366, Game.wallet_value("spiritGrain"), burden_limit)
	_add_expedition_loadout_row(body, "pickaxe", "开山镐", "res://assets/camp/ui/expedition/icon_expedition_pickaxe.png", 410, int(Game.profile.get("inventory", {}).get("pickaxe", 0)), burden_limit)
	_add_expedition_loadout_row(body, "lens", "探灵镜", "res://assets/camp/ui/expedition/icon_expedition_lens.png", 454, int(Game.profile.get("inventory", {}).get("lens", 0)), burden_limit)
	var depart := _camp_button(body, "传送", Rect2(30, 556, 132, 44), true, 14)
	depart.disabled = int(expedition_draft.get("spiritGrain", 0)) < 20 or burden > burden_limit
	depart.pressed.connect(_open_map_selection)
	var close := _camp_button(body, "返回", Rect2(185.5, 556, 132, 44), false, 14)
	close.pressed.connect(_close_modal)

func _add_expedition_hero_card(parent: Control, rect: Rect2, portrait_id: String, hero: Dictionary) -> void:
	var card := Control.new()
	card.position = rect.position
	card.size = rect.size
	card.clip_contents = true
	parent.add_child(card)
	var fill := ColorRect.new()
	fill.color = Color("#202a27")
	fill.position = Vector2.ZERO
	fill.size = rect.size
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fill)
	# The supplied frame intentionally contains an opaque card background.  It
	# is the base layer of the preparation card; portraits are rendered
	# after it and therefore remain visible inside the ornamental border.
	var card_frame := KWUI.texture(card, "res://assets/camp/ui/expedition/ui_expedition_hero_card_frame.png", Rect2(0, 0, 71, 163))
	card_frame.stretch_mode = TextureRect.STRETCH_SCALE
	card_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art_clip := Control.new()
	art_clip.position = Vector2(12.75, 12.4)
	art_clip.size = Vector2(45.5, 139.3)
	art_clip.clip_contents = true
	art_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(art_clip)
	var portrait := KWUI.texture(art_clip, "res://assets/camp/ui/expedition/portrait_hero_%s_expedition.png" % portrait_id, Rect2(-9.25, -7.2, 64, 153.2))
	if portrait_id == "shi_yan" or portrait_id == "lu_qing":
		var sheet_path := "res://assets/camp/ui/expedition/animations/%s/%s_idle_sheet.png" % [portrait_id, portrait_id]
		var sheet: Texture2D = load(sheet_path)
		if sheet:
			var frames := _sheet_frames(sheet, 4, 2)
			portrait.texture = frames[0]
			animated_portraits.append({
				"node": portrait,
				"frames": frames,
				"frame_duration": 1.0 / 4.0,
				"elapsed": 0.0,
				"frame_index": 0
			})
			portrait.position = Vector2(-28.25, -7.2)
			portrait.size = Vector2(102, 153.2)
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 卡面信息区从立绘底部向上渐暗，四行文字直接压在人物上。
	var fade := ColorRect.new()
	fade.color = Color("#0a0e0df0")
	fade.position = Vector2(6.5, 110)
	fade.size = Vector2(58, 48)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(fade)
	KWUI.label(card, "灵息 %d" % int(hero.get("stamina", 0)), Rect2(0, 109, 71, 14), 9, Color("#58b9b4"), HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(card, Game.text(hero.get("nameKey", "")), Rect2(0, 121, 71, 16), 10, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	var career_key := "career." + str(hero.get("careerId", ""))
	KWUI.label(card, "%s · %d级" % [Game.text(career_key, str(hero.get("careerId", ""))), int(hero.get("level", 1))], Rect2(0, 134, 71, 16), 9, Color("#b58a42"), HORIZONTAL_ALIGNMENT_CENTER)
	var realm_key := "realm." + str(hero.get("realmId", ""))
	KWUI.label(card, Game.text(realm_key, str(hero.get("realmId", ""))), Rect2(0, 147, 71, 16), 9, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)

func _sheet_frames(sheet: Texture2D, columns: int, rows: int) -> Array[Texture2D]:
	var frame_count := maxi(1, columns * rows)
	var frame_size := Vector2(floori(sheet.get_width() / float(columns)), floori(sheet.get_height() / float(rows)))
	var frames: Array[Texture2D] = []
	for index in frame_count:
		var frame := AtlasTexture.new()
		frame.atlas = sheet
		frame.region = Rect2(Vector2(index % columns, floori(index / columns)) * frame_size, frame_size)
		frames.append(frame)
	return frames

func _add_expedition_loadout_row(parent: Control, item_id: String, item_name: String, icon_path: String, center_y: float, available: int, burden_limit: int) -> void:
	var count := int(expedition_draft.get(item_id, 0))
	var icon := KWUI.texture(parent, icon_path, Rect2(59.5, center_y - 16, 32, 32))
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	KWUI.label(parent, item_name, Rect2(105.5, center_y - 10, 62, 20), 12, Color("#e8dcbb"))
	var minus := _add_icon_button(parent, Rect2(159.5, center_y - 24, 48, 48), "res://assets/camp/ui/ling_pu/icon_action_minus.png", count <= 0)
	minus.pressed.connect(_adjust_expedition_item.bind(item_id, -1, available, burden_limit))
	KWUI.label(parent, "%d / %d" % [count, available], Rect2(197.5, center_y - 9, 84, 18), 11, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	var item_weight: int = int({"spiritGrain": 1, "pickaxe": 12, "lens": 4}.get(item_id, 1))
	var current_burden := int(expedition_draft.get("spiritGrain", 0)) + int(expedition_draft.get("pickaxe", 0)) * 12 + int(expedition_draft.get("lens", 0)) * 4
	var plus := _add_icon_button(parent, Rect2(271.5, center_y - 24, 48, 48), "res://assets/camp/ui/ling_pu/icon_action_plus.png", count >= available or current_burden + int(item_weight) > burden_limit)
	plus.pressed.connect(_adjust_expedition_item.bind(item_id, 1, available, burden_limit))

func _adjust_expedition_item(item_id: String, delta: int, available: int, burden_limit: int) -> void:
	var current := int(expedition_draft.get(item_id, 0))
	var next := clampi(current + delta, 0, available)
	var draft := expedition_draft.duplicate(true)
	draft[item_id] = next
	var burden := int(draft.get("spiritGrain", 0)) + int(draft.get("pickaxe", 0)) * 12 + int(draft.get("lens", 0)) * 4
	if burden > burden_limit: return
	expedition_draft = draft
	_open_expedition()

func _expedition_burden_limit(heroes: Array) -> int:
	var limit := 60
	for hero in heroes:
		var attributes: Dictionary = hero.get("attributes", {})
		limit += int(attributes.get("strength", 0)) * 2 + int(attributes.get("constitution", 0))
	return limit

func _open_hero_selection() -> void:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var blocker := ColorRect.new()
	blocker.color = Color.BLACK
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(blocker)
	var panel := Control.new()
	panel.position = Vector2(16, 74)
	panel.size = Vector2(343, 553)
	modal.add_child(panel)
	var panel_art := KWUI.texture(panel, "res://assets/camp/ui/expedition/ui_expedition_hero_selection_panel.png", Rect2(0, 0, 343, 553))
	panel_art.stretch_mode = TextureRect.STRETCH_SCALE
	panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	KWUI.label(modal, "选择你的修士", Rect2(131.5, 116, 112, 16), 12, Color("#91a49e"), HORIZONTAL_ALIGNMENT_CENTER)
	KWUI.label(modal, "4 / 4", Rect2(286, 115, 42, 18), 14, Color("#b58a42"), HORIZONTAL_ALIGNMENT_CENTER)
	var portraits := ["shi_yan", "lu_qing", "bai_ling", "mo_yan"]
	var heroes: Array = Game.profile.get("roster", [])
	for index in mini(4, heroes.size()):
		var hero: Dictionary = heroes[index]
		var selected := true
		var row := Button.new()
		row.position = Vector2(43.5, 150 + index * 75)
		row.size = Vector2(288, 67)
		row.flat = true
		row.focus_mode = Control.FOCUS_NONE
		modal.add_child(row)
		var row_art_path := "res://assets/camp/ui/expedition/ui_expedition_hero_selection_row_%s.png" % ("selected" if selected else "default")
		var row_art := KWUI.texture(row, row_art_path, Rect2(0, 0, 288, 67))
		row_art.stretch_mode = TextureRect.STRETCH_SCALE
		row_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var avatar := Control.new()
		avatar.position = Vector2(4, 13.5)
		avatar.size = Vector2(40, 40)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(avatar)
		var portrait_fill := KWUI.panel(avatar, Rect2(0, 0, 40, 40), Color("#202a27"), Color("#3f5f59"))
		portrait_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var avatar_frame := KWUI.texture(avatar, "res://assets/camp/ui/top/ui_camp_avatar_frame.png", Rect2(0, 0, 40, 40))
		avatar_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var avatar_clip := Control.new()
		avatar_clip.position = Vector2(5, 4)
		avatar_clip.size = Vector2(30, 32)
		avatar_clip.clip_contents = true
		avatar_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		avatar.add_child(avatar_clip)
		# 头像裁切容器取同一张整身立绘的头肩安全区，
		# 不把整张人物缩成一枚小图标。
		var portrait := KWUI.texture(avatar_clip, "res://assets/camp/ui/expedition/portrait_hero_%s_expedition.png" % portraits[index], Rect2(-21, -3.5, 64, 153))
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var realm_key := "realm." + str(hero.get("realmId", ""))
		KWUI.label(row, Game.text(realm_key, str(hero.get("realmId", ""))), Rect2(-8, 46, 80, 16), 10, Color("#91a49e"), HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		KWUI.label(row, "%s · %s" % [Game.text(hero.get("nameKey", "")), Game.text("career." + str(hero.get("careerId", "")), str(hero.get("careerId", "")))], Rect2(64, 6, 132, 20), 13, Color("#e8dcbb")).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var rating := 0
		for value in hero.get("attributes", {}).values(): rating += int(value)
		KWUI.label(row, "Lv.%d · 战力%d" % [int(hero.get("level", 1)), rating], Rect2(64, 27, 132, 16), 10, Color("#91a49e")).mouse_filter = Control.MOUSE_FILTER_IGNORE
		KWUI.label(row, "灵息%d" % int(hero.get("stamina", 0)), Rect2(64, 46, 118, 14), 10, Color("#91a49e")).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var select := _camp_button(row, "取消 · %d" % (index + 1) if selected else "选择", Rect2(204, 17, 72, 28), selected, 10)
		select.pressed.connect(_show_feedback.bind("当前演示队伍固定为四名修士", 0))
		row.pressed.connect(_show_feedback.bind("当前演示队伍固定为四名修士", 0))
	var complete := _camp_button(modal, "完成  4/4", Rect2(121.5, 633, 132, 44), true, 14)
	complete.pressed.connect(_open_expedition)
	var back := _camp_button(modal, "返回", Rect2(121.5, 685, 132, 44), false, 14)
	back.pressed.connect(_open_expedition)

func _open_map_selection() -> void:
	_close_modal()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(modal)
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0, 0, 0.95)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(blocker)
	var panel := Control.new()
	panel.position = Vector2(16, 86)
	panel.size = Vector2(343, 622)
	modal.add_child(panel)
	var panel_art := KWUI.texture(panel, "res://assets/camp/ui/expedition/ui_expedition_map_selection_panel.png", Rect2(0, 0, 343, 622))
	panel_art.stretch_mode = TextureRect.STRETCH_SCALE
	panel_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	KWUI.label(modal, "选择本次入山的地图", Rect2(107.5, 136, 160, 16), 12, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER)
	var maps: Array = Game.expedition_config.get("maps", [])
	for index in maps.size():
		var map_info: Dictionary = maps[index]
		var unlock_flag := str(map_info.get("unlockFlag", ""))
		var unlocked := unlock_flag.is_empty() or bool(Game.profile.get("storyFlags", {}).get(unlock_flag, false))
		var row := Button.new()
		row.position = Vector2(51.5, 164 + index * 76)
		row.size = Vector2(272, 70)
		row.focus_mode = Control.FOCUS_NONE
		row.flat = true
		modal.add_child(row)
		var background := _map_selection_row_background(row)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var map_name := Game.text(str(map_info.get("nameKey", "")), str(map_info.get("mapId", "地图")))
		var map_number := int(map_info.get("mapNumber", index + 1))
		KWUI.label(row, "%d. %s" % [map_number, map_name], Rect2(14, 10, 244, 20), 15, Color("#e8dcbb"), HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		var map_rule := "灵息 %d · 每步灵粮 %d" % [int(map_info.get("staminaCost", 0)), int(map_info.get("grainPerStep", 0))] if unlocked else "尚未解锁"
		KWUI.label(row, map_rule, Rect2(21, 36, 230, 16), 11, Color("#91a49e"), HORIZONTAL_ALIGNMENT_CENTER).mouse_filter = Control.MOUSE_FILTER_IGNORE
		if unlocked:
			row.pressed.connect(_depart)
		else:
			var lock := KWUI.texture(row, "res://assets/camp/ui/expedition/icon_expedition_lock.png", Rect2(254.5, 15, 14, 14))
			lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.pressed.connect(_show_feedback.bind("该区域尚未解锁", 1))
	var back := _camp_button(modal, "返回", Rect2(116, 716, 132, 44), false, 14)
	back.pressed.connect(_open_expedition)

func _depart() -> void:
	var result := Game.start_expedition(expedition_draft)
	if result.get("ok", false): get_tree().change_scene_to_file("res://scenes/map.tscn")
	else: _show_feedback(result.get("message", "当前无法入山"), 2)

func _map_selection_row_background(parent: Control) -> Panel:
	var background := Panel.new()
	background.position = Vector2.ZERO
	background.size = Vector2(272, 70)
	background.add_theme_stylebox_override("panel", KWUI.style_box(Color.TRANSPARENT, Color("#665b48b8"), 3, 1))
	parent.add_child(background)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color("#162522"), Color("#081110")])
	var gradient_texture := GradientTexture2D.new()
	gradient_texture.gradient = gradient
	gradient_texture.width = 270
	gradient_texture.height = 68
	gradient_texture.fill_from = Vector2(0, 0.5)
	gradient_texture.fill_to = Vector2(1, 0.5)
	var fill := TextureRect.new()
	fill.position = Vector2(1, 1)
	fill.size = Vector2(270, 68)
	fill.texture = gradient_texture
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_child(fill)
	background.move_child(fill, 0)
	return background

func _open_council() -> void:
	var body := _make_modal("议事殿", "res://assets/camp/ui/expedition/ui_expedition_panel_body.png")
	KWUI.label(body, "营地人物 · 已入驻 1", Rect2(59.5, 77.5, 240, 18), 12, Color("#9a9684"), HORIZONTAL_ALIGNMENT_CENTER)
	var item := Button.new()
	item.position = Vector2(43.5, 112)
	item.size = Vector2(272, 48)
	item.flat = true
	item.focus_mode = Control.FOCUS_NONE
	body.add_child(item)
	var item_art := KWUI.texture(item, "res://assets/camp/ui/council/ui_council_npc_item_default.png", Rect2(0, 0, 272, 48))
	item_art.stretch_mode = TextureRect.STRETCH_SCALE
	item_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_slot := KWUI.panel(item, Rect2(4, 4, 40, 40), Color("#051411ea"), Color("#31463f"))
	portrait_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait := KWUI.texture(item, "res://assets/camp/ui/top/portrait_player_placeholder.png", Rect2(8, 8, 32, 32))
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	KWUI.label(item, "岑守一", Rect2(64, 11, 154, 24), 14, Color("#e8dcbb")).mouse_filter = Control.MOUSE_FILTER_IGNORE
	var attention := KWUI.texture(item, "res://assets/camp/ui/common/icon_camp_building_attention.png", Rect2(248, 3, 24, 24))
	attention.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.pressed.connect(_open_council_dialog)
	KWUI.label(body, "其他人物将随剧情入驻", Rect2(43.5, 395.5, 272, 18), 12, Color("#9a9684"), HORIZONTAL_ALIGNMENT_CENTER)
	var close := _camp_button(body, "返回营地", Rect2(113.5, 556, 132, 44), false, 14)
	close.pressed.connect(_close_modal)

func _open_council_dialog() -> void:
	var body := _make_modal("岑守一", "res://assets/camp/ui/council/ui_council_npc_dialog_panel.png")
	var text_frame := KWUI.panel(body, Rect2(27.5, 64, 272, 200), Color("#051411ea"), Color("#31463f"))
	text_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var dialogue := KWUI.label(text_frame, "山门外残禁未消。\n\n先带队去破禁山麓探查，\n营地虽小，却是诸位修士\n再入禁地的根基。", Rect2(12, 12, 248, 176), 12, Color("#e8dcbb"))
	dialogue.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	dialogue.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	dialogue.clip_text = true
	var talk := _camp_button(body, "交谈", Rect2(97.5, 294, 132, 44), false, 14)
	talk.pressed.connect(_show_feedback.bind("先去破禁山麓，查明残禁异动。", 0))
	var small_talk := _camp_button(body, "闲谈", Rect2(97.5, 350, 132, 44), false, 14)
	small_talk.pressed.connect(_show_feedback.bind("近来山雾渐浓，入山时多带些灵粮。", 0))
	var leave := _camp_button(body, "离开", Rect2(97.5, 406, 132, 44), false, 14)
	leave.pressed.connect(_open_council)

func _open_settings() -> void:
	var body := _make_modal("设置与存档")
	KWUI.label(body, "存档位置", Rect2(25, 72, 290, 30), 13, KWUI.MUTED)
	KWUI.label(body, "user://kunwu_profile.json", Rect2(25, 103, 290, 34), 12, KWUI.TEXT)
	KWUI.label(body, "Godot 会在生产、移动、结算和场景切换前后自动保存。", Rect2(25, 150, 290, 62), 12, KWUI.MUTED)
	var save := KWUI.button(body, "立即保存", Rect2(55, 245, 235, 48), 14)
	save.pressed.connect(func(): Game.save_profile(); _show_feedback("存档已写入", 0))
	var reset := KWUI.button(body, "重置新档", Rect2(55, 320, 235, 48), 14)
	reset.pressed.connect(func(): Game.reset_profile(); _close_modal(); get_tree().reload_current_scene())
	KWUI.label(body, "迁移版保留源项目内部资源 ID 与七维字段，存档采用可读 JSON。", Rect2(30, 410, 285, 80), 11, KWUI.MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _show_feedback(message: String, severity: int = 0) -> void:
	toast_serial += 1
	var current := toast_serial
	toast_panel.visible = true
	toast_panel.add_theme_stylebox_override("panel", KWUI.style_box(Color("#182c31ee"), KWUI.RED if severity >= 2 else KWUI.TEAL, 6, 1))
	toast_label.text = message
	await get_tree().create_timer(2.4).timeout
	if current == toast_serial: toast_panel.visible = false
