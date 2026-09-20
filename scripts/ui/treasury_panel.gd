extends Control

## Figma 372:1396. Read-only first-pass inventory presentation.
const ART := "res://assets/camp/ui/treasury/"
const FONT = preload("res://assets/fonts/noto_sans_sc_medium.tres")
const INK := Color("#e8dcbb")
const MUTED := Color("#91a49e")
const ITEMS := [
	["darkIron", "玄铁", "imgIcon2", 0, "材料", 42],
	["spiritWood", "灵木", "imgIcon1", 0, "材料", 96],
	["spiritStone", "灵晶", "imgIcon3", 2, "材料", 12],
	["gengJing", "庚精", "imgIcon4", 2, "材料", 3],
	["spiritGrain", "灵粮", "imgIcon", 0, "材料", 168],
	["pickaxe", "开山镐", "img", 0, "材料", 6],
	["lens", "探灵镜", "img1", 1, "材料", 2],
	["bigu_cake", "辟谷饼", "img2", 0, "材料", 14],
	["soulCrystal", "魂晶", "img3", 1, "材料", 8],
	["immortalCoin", "灵石", "imgBottomRightCurrencyIconOnly", 2, "材料", 1280],
	["return_talisman", "归营符", "符", 1, "关键", 1],
	["heart_mirror", "护心镜", "甲", 2, "装备", 1]
]
signal closed
var preview := false
var category := "全部"
var quality := -1
var content: Control
var message: Label
var equipment_summary: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build()

func _label(parent: Node, text: String, rect: Rect2, font_size := 12, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := KWUI.label(parent, text, rect, font_size, color, align)
	label.add_theme_font_override("font", FONT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _image(parent: Node, asset: String, rect: Rect2) -> TextureRect:
	var image := KWUI.texture(parent, ART + asset + ".png", rect)
	image.stretch_mode = TextureRect.STRETCH_SCALE
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return image

func _crop(asset: String, rect: Rect2, relative: Rect2) -> void:
	var clip := Control.new()
	clip.position = rect.position
	clip.size = rect.size
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	_image(clip, asset, Rect2(relative.position * rect.size, relative.size * rect.size))

func _build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.0392, 0.0588, 0.0549, 0.82)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_crop("imgPanelLevel2", Rect2(20, 128, 335, 540), Rect2(-0.0714, -0.2803, 1.1429, 1.5657))
	_crop("imgPanelDecorationTop", Rect2(8, 96, 359, 65), Rect2(-0.1116, -1.652, 1.2239, 4.511))
	_crop("imgPanelDecorationBottom", Rect2(8, 622, 359, 55), Rect2(-0.1497, -2.15, 1.2995, 5.6889))
	_label(self, "百宝库", Rect2(8, 129, 359, 24), 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
	equipment_summary = Control.new()
	equipment_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(equipment_summary)
	_label(equipment_summary, "容量" if preview else "装备", Rect2(32, 176, 28, 16), 12, MUTED)
	_label(equipment_summary, "12 / 40" if preview else "%d / %d" % [KWEquipment.ensure(Game.profile)["instances"].size(), int(Game.equipment_catalog().get("capacity", 100))], Rect2(64, 174, 65, 20), 14)
	_label(equipment_summary, "锁定 2 · 任务保护 1" if preview else "资源不占装备仓位", Rect2(132, 176, 120, 16), 10, Color("#b58a42"))
	var filter := _button(self, "筛选", Rect2(271, 170, 72, 28), "inline", false, 12)
	filter.pressed.connect(_filter)
	var line := ColorRect.new()
	line.position = Vector2(32, 206)
	line.size = Vector2(311, 1)
	line.color = Color("#80623a73")
	add_child(line)
	content = Control.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(content)
	message = _label(self, "", Rect2(32, 552, 311, 16), 10, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var batch := _button(self, "装备管理" if not preview else "批量处理", Rect2(43, 718, 132, 44), "footer", false, 14)
	batch.pressed.connect(func():
		if preview: message.text = "预览模式"
		else:
			var equipment := preload("res://scripts/ui/equipment_panel.gd").new()
			add_child(equipment)
			equipment.closed.connect(func(): equipment.queue_free(); _refresh()))
	var close := _button(self, "关闭", Rect2(200, 718, 132, 44), "footer", false, 14)
	close.pressed.connect(func(): closed.emit())
	_refresh()

func _quantity(item: Array) -> int:
	if preview: return int(item[5])
	var id := str(item[0])
	if Game.profile.get("wallet", {}).has(id): return Game.wallet_value(id)
	return int(Game.profile.get("inventory", {}).get(id, 0))

func _refresh() -> void:
	equipment_summary.visible = category == "装备"
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	var tabs := ["全部", "装备", "材料", "关键"]
	for i in tabs.size():
		var tab_name: String = tabs[i]
		var button := _button(content, tab_name, Rect2(32 + 79 * i, 216, 72, 28), "inline", category == tab_name, 12)
		button.pressed.connect(func(): category = tab_name; _refresh())
	var visible_items: Array = []
	for item in ITEMS:
		if not preview and item[4] == "装备": continue
		if _quantity(item) > 0 and (category == "全部" or item[4] == category) and (quality < 0 or item[3] == quality): visible_items.append(item)
	if not preview and category in ["全部", "材料", "关键"] and quality < 0:
		for id in Game.profile.get("inventory", {}):
			if ITEMS.any(func(item): return item[0] == id): continue
			var kind := "关键" if Game.is_protected_loot(str(id)) else "材料"
			if category != "全部" and category != kind: continue
			var amount := int(Game.profile["inventory"][id])
			if amount > 0: visible_items.append([id, Game.text("item." + str(id) + ".name", str(id)), "符", 0, kind, amount])
	for i in 16:
		var slot := Control.new()
		slot.position = Vector2(32 + (i % 4) * 79, 256 + (i / 4) * 68)
		slot.size = Vector2(72, 64)
		content.add_child(slot)
		var frame := _image(slot, "imgQuality", Rect2(16, 0, 40, 40))
		var q := 0 if i >= visible_items.size() else int(visible_items[i][3])
		var rim := KWUI.panel(slot, Rect2(19, 3, 34, 34), Color.TRANSPARENT, [INK, Color("#6f945f"), Color("#4b83b8"), Color("#B39BCF"), Color("#D5B26C"), Color("#DC897B")][clampi(q, 0, 5)])
		rim.add_theme_stylebox_override("panel", KWUI.style_box(Color.TRANSPARENT, [INK, Color("#6f945f"), Color("#4b83b8"), Color("#B39BCF"), Color("#D5B26C"), Color("#DC897B")][clampi(q, 0, 5)], 4, 1))
		rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if i >= visible_items.size():
			frame.modulate.a = 0.38
			rim.modulate.a = 0.38
			continue
		var item: Array = visible_items[i]
		var asset := str(item[2])
		if asset in ["符", "甲"]:
			_label(slot, asset, Rect2(22, 5, 28, 28), 18, Color("#58b9b4") if asset == "符" else Color("#b58a42"), HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var small := asset in ["img", "img1"]
			var art := _image(slot, asset, Rect2(24, 8, 24, 24) if small else Rect2(20, 4, 32, 32))
			art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Label's font minimum height exceeds the 12px Figma line box.
		# Draw against a fixed baseline so quantity stays inside the slot rim.
		var count := QuantityBadge.new()
		count.name = "Quantity"
		count.position = Vector2(17, 24)
		count.size = Vector2(34, 13)
		count.text = "×%s" % _quantity(item)
		count.mouse_filter = Control.MOUSE_FILTER_IGNORE
		count.clip_contents = true
		slot.add_child(count)
		_label(slot, str(item[1]), Rect2(0, 44, 72, 16), 10, INK, HORIZONTAL_ALIGNMENT_CENTER)
		if preview and item[0] in ["gengJing", "return_talisman"]: _image(slot, "imgStatusIconDisabledLock", Rect2(44, 2, 10, 10))
		slot.tooltip_text = "%s ×%d" % [item[1], _quantity(item)]
	if visible_items.is_empty():
		_label(content, "暂无物品" if quality < 0 else "暂无符合条件的物品", Rect2(42, 518, 291, 18), 11, MUTED, HORIZONTAL_ALIGNMENT_CENTER)

func _filter() -> void:
	quality = quality + 1 if quality < 5 else -1
	message.text = "品质：%s" % ["全部", "法器", "真宝", "法宝", "古宝", "通天灵宝", "玄天之宝"][quality + 1]
	_refresh()

class TreasuryButtonVisual extends KWCampButtonVisual:
	func _palette(button_kind: String, state: String) -> Dictionary:
		if button_kind == "inline" and state == "selected":
			return _colors(63, 95, 89, 111, 143, 133, 111, 143, 133, 20, 45, 39, 176, 232, 209)
		return super._palette(button_kind, state)

func _button(parent: Node, text: String, rect: Rect2, kind: String, selected: bool, font_size: int) -> Button:
	var touch_size := Vector2(rect.size.x, maxf(rect.size.y, 40))
	var button := KWUI.button(parent, text, Rect2(rect.position + (rect.size - touch_size) / 2, touch_size), font_size)
	button.add_theme_font_override("font", FONT)
	button.add_theme_color_override("font_color", INK)
	var visual := TreasuryButtonVisual.new()
	button.add_child(visual)
	visual.configure(button, kind, selected, rect.size)
	return button

class QuantityBadge extends Control:
	var text := ""

	func _draw() -> void:
		var font_size := 9
		var width := FONT.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		var baseline := Vector2(size.x - width, size.y - FONT.get_descent(font_size))
		draw_string_outline(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 2, Color("#07100f"))
		draw_string(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, INK)
