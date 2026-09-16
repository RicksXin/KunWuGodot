extends "res://scripts/ui/treasury_panel.gd"

## Shares the reviewed camp panel visual primitives; replaces the inventory view.
## Figma 374:1538 is an older visual draft, never a transaction configuration.
const GOODS := [
	["灵粮包20", "入山补给 · 限购 2", "imgIcon", 40, "购买", 0],
	["开山镐", "探索工具 · 限购 2", "img", 90, "购买", 0],
	["探灵镜", "侦测隐秘 · 限购 1", "img1", 70, "购买", 1],
	["灵木20", "地图一材料 · 限购 2", "imgIcon1", 60, "已购", 0],
	["玄铁10", "地图一材料 · 限购 2", "imgIcon2", 80, "购买", 0],
	["归营符", "支线一或地图二后开放", "符", 120, "未开放", 1],
	["凡品护心镜", "当前章节保底 · 唯一", "甲", 100, "购买", 0]
]
var notice: Control
var purchase_buttons: Array[Button] = []

func _build() -> void:
	name = "MarketPanel"
	var shade := ColorRect.new()
	shade.color = Color(0.0392, 0.0588, 0.0549, 0.84)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_crop("imgPanelLevel2", Rect2(20, 110, 335, 565), Rect2(-0.0714, -0.2803, 1.1429, 1.5657))
	_crop("imgPanelDecorationTop", Rect2(8, 78, 359, 65), Rect2(-0.1116, -1.652, 1.2239, 4.511))
	_crop("imgPanelDecorationBottom", Rect2(8, 628, 359, 55), Rect2(-0.1497, -2.15, 1.2995, 5.6889))
	_label(self, "交易行", Rect2(8, 110, 359, 24), 20, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_image(self, "imgBottomRightCurrencyIconOnly", Rect2(42, 153, 24, 24))
	_label(self, "1,280" if preview else str(Game.wallet_value("immortalCoin")), Rect2(70, 155, 110, 20), 14, Color("#b58a42"))
	for i in 3:
		var title: String = ["购买", "出售", "回购"][i]
		var tab := _button(self, title, Rect2(69 + 79 * i, 182, 72, 28), "inline", i == 0, 12)
		tab.name = "Tab%d" % i
		tab.pressed.connect(_on_tab.bind(i))
	for i in GOODS.size():
		_build_row(i)
	_label(self, "剧情保底栏 · 不参与普通货物随机", Rect2(32, 544, 311, 16), 10, Color("#b58a42"))
	var close := _button(self, "关闭", Rect2(122, 718, 132, 44), "footer", false, 14)
	close.name = "Close"
	close.pressed.connect(func(): closed.emit())

func _build_row(index: int) -> void:
	var good: Array = GOODS[index]
	var special := index == 6
	var row := Control.new()
	row.name = "Product%d" % index
	row.position = Vector2(32, 564 if special else 232 + 51 * index)
	row.size = Vector2(311, 54 if special else 48)
	add_child(row)
	var background := KWUI.texture(row, "res://assets/camp/ui/market/row_selected.png" if special else "res://assets/camp/ui/market/row.png", Rect2(Vector2.ZERO, row.size))
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var offset_y := 3 if special else 0
	_image(row, "imgQuality", Rect2(6, 4 + offset_y, 40, 40))
	var rim_color := Color("#6f945f") if int(good[5]) == 1 else INK
	var rim := KWUI.panel(row, Rect2(9, 7 + offset_y, 34, 34), Color.TRANSPARENT, rim_color)
	rim.add_theme_stylebox_override("panel", KWUI.style_box(Color.TRANSPARENT, rim_color, 4, 1))
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon: String = good[2]
	if icon in ["符", "甲"]:
		_label(row, icon, Rect2(12, 9 + offset_y, 28, 28), 18, Color("#58b9b4") if icon == "符" else Color("#b58a42"), HORIZONTAL_ALIGNMENT_CENTER)
	else:
		var small := icon in ["img", "img1"]
		var art := _image(row, icon, Rect2(14, 12, 24, 24) if small else Rect2(10, 8, 32, 32))
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_label(row, good[0], Rect2(54, 5 if special else 4, 118, 16), 12)
	var description_color := Color("#b94a3e") if index == 5 else (Color("#b58a42") if special else MUTED)
	_label(row, good[1], Rect2(54, 24 if special else 22, 145, 14), 9, description_color)
	_image(row, "imgBottomRightCurrencyIconOnly", Rect2(196, 33 if special else 29, 12, 12))
	var price := PriceAmount.new()
	price.position = Vector2(210, 32 if special else 28)
	price.size = Vector2(38, 14)
	price.text = str(good[3])
	price.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(price)
	var button := _button(row, good[4], Rect2(235, 13 if special else 10, 72, 28), "inline", false, 12)
	button.name = "Purchase"
	button.disabled = good[4] != "购买"
	if button.disabled:
		# Disabled Figma buttons retain the subdued bronze rim.
		var old_visual := button.get_node("NativeVisual")
		button.remove_child(old_visual)
		old_visual.queue_free()
		var visual := MarketDisabledVisual.new()
		button.add_child(visual)
		visual.configure(button, "inline", false, Vector2(72, 28))
		button.add_theme_color_override("font_disabled_color", Color("#5e6a66"))
	button.pressed.connect(_on_purchase.bind(index))
	purchase_buttons.append(button)

func _on_tab(index: int) -> void:
	if index == 0: return
	_show_notice("当前交易规则不支持出售或回购。\n此标签仅保留设计稿外观。")

func _on_purchase(index: int) -> void:
	_show_notice("%s\n交易功能尚未开放，当前为设计预览。" % GOODS[index][0])

func _show_notice(text: String) -> void:
	if is_instance_valid(notice): notice.queue_free()
	notice = Control.new()
	notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(notice)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	notice.add_child(shade)
	var box := KWUI.panel(notice, Rect2(38, 315, 299, 164), Color("#202a27"), Color("#80623a"))
	_label(box, text, Rect2(12, 20, 275, 65), 12, INK, HORIZONTAL_ALIGNMENT_CENTER)
	var dismiss := _button(box, "知道了", Rect2(83, 107, 132, 36), "footer", false, 12)
	dismiss.pressed.connect(func(): notice.queue_free())

class MarketDisabledVisual extends KWCampButtonVisual:
	func _palette(button_kind: String, state: String) -> Dictionary:
		if state == "disabled":
			return _colors(16, 22, 20, 181, 138, 66, 94, 77, 43, 9, 15, 13, 83, 72, 49)
		return super._palette(button_kind, state)

func _label(parent: Node, text: String, rect: Rect2, font_size := 12, color := INK, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := super._label(parent, text, rect, font_size, color, align)
	# Match Figma's explicit line-height when Godot enforces a taller font box.
	label.position.y -= maxf(0, label.get_minimum_size().y - rect.size.y) / 2.0
	return label

class PriceAmount extends Control:
	var text := ""
	func _draw() -> void:
		var baseline := Vector2(0, size.y - FONT.get_descent(9))
		draw_string(FONT, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("#b58a42"))
