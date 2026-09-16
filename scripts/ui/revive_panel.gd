extends "res://scripts/ui/treasury_panel.gd"

signal prepare_requested
signal emergency_requested(hero_id: String)
var heroes: Array = []
var selected_id := ""
var status_message := ""
var submit: Button
var rows: Array[Dictionary] = []

func _build() -> void:
	name = "ReviveHallBody"
	var shade := ColorRect.new()
	shade.color = Color(0.0392, 0.0588, 0.0549, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_crop("imgPanelLevel2", Rect2(20, 110, 335, 565), Rect2(-0.0714, -0.2803, 1.1429, 1.5657))
	_crop("imgPanelDecorationTop", Rect2(8, 78, 359, 65), Rect2(-0.1116, -1.652, 1.2239, 4.511))
	_crop("imgPanelDecorationBottom", Rect2(8, 628, 359, 55), Rect2(-0.1497, -2.15, 1.2995, 5.6889))
	_label(self, "还魂殿", Rect2(8, 110, 359, 24), 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_image(self, "img3", Rect2(44, 155, 24, 24))
	_label(self, "魂晶 %d" % Game.wallet_value("soulCrystal"), Rect2(76, 155, 140, 28), 14, Color("#b58a42"))
	var close := _button(self, "返回营地", Rect2(209, 718, 122, 44), "footer", false, 14)
	close.name = "ReturnToCampButton"
	close.pressed.connect(func(): closed.emit())
	if heroes.is_empty():
		_image(self, "img3", Rect2(155.5, 282, 64, 64))
		_label(self, "当前无人待还魂", Rect2(44, 354, 287, 30), 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
		_label(self, "可前往整备，继续入山。", Rect2(44, 394, 287, 24), 12, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
		var prepare := _button(self, "前往入山整备", Rect2(44, 718, 150, 44), "footer", false, 14)
		prepare.name = "PrepareAfterReviveButton"
		prepare.pressed.connect(func(): prepare_requested.emit())
	else:
		_label(self, "待还魂 %d 人" % heroes.size(), Rect2(225, 155, 106, 28), 12, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		_label(self, "魂晶不足", Rect2(44, 197, 287, 22), 15, Color("#be883a"))
		_label(self, "全员阵亡，可免费还魂一人。", Rect2(44, 229, 287, 18), 11, MUTED)
		for index in heroes.size(): _hero_row(heroes[index], index)
		_label(self, "免费还魂后，其余修士仍需消耗魂晶。", Rect2(44, 256 + heroes.size() * 68 + 8, 287, 24), 10, MUTED)
		submit = _button(self, "免费还魂", Rect2(44, 718, 150, 44), "footer", false, 14)
		submit.name = "EmergencyReviveButton"
		submit.pressed.connect(_submit)
		_select(selected_id)
	if not status_message.is_empty():
		_label(self, status_message, Rect2(44, 595, 287, 30), 11, Color("#be883a"), HORIZONTAL_ALIGNMENT_CENTER)

func _hero_row(hero: Dictionary, index: int) -> void:
	var id := str(hero.get("instanceId", ""))
	var row := Control.new()
	row.position = Vector2(44, 256 + index * 68)
	row.size = Vector2(287, 60)
	row.name = "RescueRow_" + id
	add_child(row)
	var bg := KWUI.texture(row, "res://assets/camp/ui/market/row.png", Rect2(0, 0, 287, 60))
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var select := Button.new()
	select.flat = true
	select.size = row.size
	select.focus_mode = Control.FOCUS_NONE
	select.disabled = Game.revival_cost(hero) < 0
	row.add_child(select)
	select.pressed.connect(_select.bind(id))
	var portrait_id := str(hero.get("nameKey", "")).trim_prefix("hero.")
	var offsets := {"shi_yan": Vector2(-21, -3), "lu_qing": Vector2(-16, -5), "bai_ling": Vector2(-14, 0), "mo_yan": Vector2(-15, -5)}
	var clip := Control.new()
	clip.position = Vector2(10, 12)
	clip.size = Vector2(30, 36)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(clip)
	var path := "res://assets/camp/ui/revive/%s.png" % portrait_id
	if ResourceLoader.exists(path):
		var portrait := KWUI.texture(clip, path, Rect2(offsets.get(portrait_id, Vector2(-21, -3)) + Vector2(-23.2512, 0), Vector2(110.7264, 153)))
		portrait.stretch_mode = TextureRect.STRETCH_SCALE
		portrait.modulate.a = 0.6
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label(row, "%s · %s" % [Game.text(hero.get("nameKey", "")), Game.text("career." + str(hero.get("careerId", "")))], Rect2(50, 14, 151, 18), 12)
	_label(row, "%s Lv%d · 阵亡" % [Game.text("realm." + str(hero.get("realmId", "")), "炼气"), int(hero.get("level", 1))], Rect2(50, 34, 151, 16), 10, MUTED)
	var badge := _label(row, "", Rect2(211, 22, 66, 16), 10, Color("#b58a42"), HORIZONTAL_ALIGNMENT_CENTER)
	rows.append({"id": id, "hero": hero, "bg": bg, "badge": badge})

func _select(id: String) -> void:
	selected_id = id
	var found := false
	for row in rows:
		var selected: bool = row.id == id
		row.bg.texture = load("res://assets/camp/ui/market/row_selected.png" if selected else "res://assets/camp/ui/market/row.png")
		var cost := Game.revival_cost(row.hero)
		row.badge.text = "已选" if selected else ("%d 魂晶" % cost if cost >= 0 else "数据异常")
		row.badge.add_theme_color_override("font_color", Color("#58b9b4") if selected else Color("#b58a42"))
		if selected:
			found = cost >= 0
			submit.text = "免费还魂 · " + Game.text(row.hero.get("nameKey", ""))
	submit.disabled = not found or Game.profile.get("expedition") != null

func _submit() -> void:
	if submit.disabled: return
	submit.disabled = true
	emergency_requested.emit(selected_id)

func _label(parent: Node, text: String, rect: Rect2, font_size := 12, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.add_theme_font_override("font", FONT)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.text = text
	label.clip_text = true
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = rect.size
	label.position = rect.position - Vector2(0, maxf(0, label.get_minimum_size().y - rect.size.y) / 2.0)
	parent.add_child(label)
	return label
